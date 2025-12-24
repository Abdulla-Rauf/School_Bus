// teacher_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/teacher_model.dart';

class TeacherService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  TeacherService(this._firestore, this._storage, this._auth);

  Future<bool> addTeacher(Teacher teacher, File? imageFile) async {
    FirebaseApp? secondaryApp;
    try {
      String? photoUrl;

      // 1. Initialize secondary Firebase App to create user without signing out admin
      FirebaseApp defaultApp = Firebase.app();
      secondaryApp = await Firebase.initializeApp(
        name: 'secondaryApp',
        options: defaultApp.options,
      );

      // 2. Create Firebase Authentication user using secondary app
      // This ensures the main auth instance (admin session) is untouched
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      UserCredential userCredential = await secondaryAuth
          .createUserWithEmailAndPassword(
            email: teacher.email,
            password: teacher.teacherId,
          );

      String authUid = userCredential.user!.uid;

      // Upload image if provided (using main storage instance - admin has permissions)
      if (imageFile != null) {
        final ref = _storage.ref().child(
          'teachers/${teacher.teacherId}/profile.jpg',
        );
        final uploadTask = ref.putFile(imageFile);
        final snapshot = await uploadTask.whenComplete(() {});
        photoUrl = await snapshot.ref.getDownloadURL();
      }

      // Create teacher document (using main firestore instance - admin has permissions)
      final teacherData = teacher.toMap();
      if (photoUrl != null) {
        teacherData['photoUrl'] = photoUrl;
      }
      teacherData['authUid'] = authUid;

      await _firestore
          .collection('teachers')
          .doc(teacher.teacherId)
          .set(teacherData);

      // Create user account for teacher
      await _firestore.collection('users').doc(teacher.teacherId).set({
        'uid': teacher.teacherId,
        'authUid': authUid,
        'email': teacher.email,
        'name': teacher.name,
        'role': 'teacher',
        'schoolId': teacher.schoolId,
        'specificId': teacher.teacherId,
        'photoUrl': photoUrl,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Cleanup secondary app
      await secondaryApp.delete();

      return true;
    } catch (e) {
      print('Error adding teacher: $e');
      // Cleanup
      if (secondaryApp != null) {
        try {
          // If user was created but other steps failed, we might want to delete the user?
          // For now, just deleting the app instance closes the connection.
          await secondaryApp.delete();
        } catch (deleteError) {
          print('Error cleaning up secondary app: $deleteError');
        }
      }
      return false;
    }
  }

  Future<List<Teacher>> getTeachers(String schoolId) async {
    try {
      var query = await _firestore
          .collection('teachers')
          .where('schoolId', isEqualTo: schoolId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => Teacher.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting teachers: $e');
      return [];
    }
  }

  Future<bool> deleteTeacher(String teacherId) async {
    try {
      // Get teacher data first
      var teacherDoc = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .get();

      if (teacherDoc.exists) {
        final teacherData = teacherDoc.data();
        String? authUid = teacherData?['authUid'];

        // Delete from teachers collection
        await _firestore.collection('teachers').doc(teacherId).delete();

        // Delete from users collection
        await _firestore.collection('users').doc(teacherId).delete();

        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error deleting teacher: $e');
      return false;
    }
  }

  Future<bool> verifyTeacherDeletion(String teacherId) async {
    try {
      var teacherDoc = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .get();
      var userDoc = await _firestore.collection('users').doc(teacherId).get();

      bool teacherExists = teacherDoc.exists;
      bool userExists = userDoc.exists;

      return !teacherExists && !userExists;
    } catch (e) {
      print('Error verifying deletion: $e');
      return false;
    }
  }

  Future<bool> updateTeacher(Teacher teacher, File? imageFile) async {
    try {
      String? photoUrl;

      // Upload new image if provided
      if (imageFile != null) {
        final ref = _storage.ref().child(
          'teachers/${teacher.teacherId}/profile.jpg',
        );
        final uploadTask = ref.putFile(imageFile);
        final snapshot = await uploadTask.whenComplete(() {});
        photoUrl = await snapshot.ref.getDownloadURL();
      }

      // Update teacher document
      final teacherData = teacher.toMap();
      if (photoUrl != null) {
        teacherData['photoUrl'] = photoUrl;
      } else {
        // Keep existing photo URL
        var existingTeacher = await _firestore
            .collection('teachers')
            .doc(teacher.teacherId)
            .get();
        if (existingTeacher.exists &&
            existingTeacher.data()?['photoUrl'] != null) {
          teacherData['photoUrl'] = existingTeacher.data()?['photoUrl'];
        }
      }

      await _firestore
          .collection('teachers')
          .doc(teacher.teacherId)
          .set(teacherData, SetOptions(merge: true));

      // Update user account
      await _firestore.collection('users').doc(teacher.teacherId).set({
        'email': teacher.email,
        'name': teacher.name,
        'photoUrl': teacherData['photoUrl'],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error updating teacher: $e');
      return false;
    }
  }

  Future<Teacher?> getTeacherById(String teacherId) async {
    try {
      var doc = await _firestore.collection('teachers').doc(teacherId).get();
      if (doc.exists) {
        return Teacher.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting teacher by ID: $e');
      return null;
    }
  }

  Future<bool> isPrimaryTeacherForClass(
    String teacherId,
    String className,
  ) async {
    try {
      var query = await _firestore
          .collection('teachers')
          .where('teacherId', isEqualTo: teacherId)
          .where('primaryClass', isEqualTo: className)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking primary teacher: $e');
      return false;
    }
  }
}
