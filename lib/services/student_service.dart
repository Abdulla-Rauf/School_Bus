// student_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/student_model.dart';
import '../models/student_assignment_model.dart';

class StudentService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  StudentService(this._firestore, this._storage, this._auth);

  Future<bool> addStudentWithPassword(Student student, String password) async {
    try {
      // 1. Create Firebase Authentication user
      UserCredential? userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: student.email,
            password: password,
          );

      String authUid = userCredential.user!.uid;

      // 2. Create student document
      final studentData = student.toMap();
      studentData['authUid'] = authUid;

      await _firestore
          .collection('students')
          .doc(student.studentId)
          .set(studentData);

      // 3. Create user account
      await _firestore.collection('users').doc(student.studentId).set({
        'uid': student.studentId,
        'authUid': authUid,
        'email': student.email,
        'name': student.fullName,
        'role': 'student',
        'schoolId': student.schoolId,
        'specificId': student.studentId,
        'admissionNumber': student.admissionNumber,
        'photoUrl': student.photoUrl,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      print('❌ Error registering student: $e');

      // Cleanup
      try {
        User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          await currentUser.delete();
        }
      } catch (deleteError) {
        print('⚠️ Error cleaning up auth user: $deleteError');
      }

      rethrow;
    }
  }

  Future<bool> checkAdmissionNumberExists(String admissionNumber) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('students')
          .where('admissionNumber', isEqualTo: admissionNumber)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking admission number: $e');
      return false;
    }
  }

  Future<bool> checkEmailExists(String email) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('students')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  Future<List<Student>> getStudentsBySchoolId(String schoolId) async {
    try {
      var query = await _firestore
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => Student.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting students by school: $e');
      return [];
    }
  }

  Future<Student?> getStudentById(String studentId) async {
    try {
      var doc = await _firestore.collection('students').doc(studentId).get();
      if (doc.exists) {
        return Student.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting student by ID: $e');
      return null;
    }
  }

  Future<Student?> getStudentByAuthUid(String authUid) async {
    try {
      var query = await _firestore
          .collection('students')
          .where('authUid', isEqualTo: authUid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Student.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting student by auth UID: $e');
      return null;
    }
  }

  Future<Student?> getStudentByEmail(String email) async {
    try {
      var query = await _firestore
          .collection('students')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Student.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting student by email: $e');
      return null;
    }
  }

  Future<Student?> getStudentByAdmissionNumber(String admissionNumber) async {
    try {
      var query = await _firestore
          .collection('students')
          .where('admissionNumber', isEqualTo: admissionNumber)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Student.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting student by admission number: $e');
      return null;
    }
  }

  Future<bool> addStudent(Student student, File? imageFile) async {
    try {
      String? photoUrl;

      // 1. Create Firebase Authentication user
      UserCredential? userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: student.email,
            password: student.admissionNumber,
          );

      String authUid = userCredential.user!.uid;

      // 2. Upload image if provided
      if (imageFile != null) {
        final ref = _storage.ref().child(
          'students/${student.studentId}/profile.jpg',
        );
        final uploadTask = ref.putFile(imageFile);
        final snapshot = await uploadTask.whenComplete(() {});
        photoUrl = await snapshot.ref.getDownloadURL();
      }

      // 3. Create student document
      final studentData = student.toMap();
      if (photoUrl != null) {
        studentData['photoUrl'] = photoUrl;
      }
      studentData['authUid'] = authUid;

      await _firestore
          .collection('students')
          .doc(student.studentId)
          .set(studentData);

      // 4. Create user account
      await _firestore.collection('users').doc(student.studentId).set({
        'uid': student.studentId,
        'authUid': authUid,
        'email': student.email,
        'name': student.fullName,
        'role': 'student',
        'schoolId': student.schoolId,
        'specificId': student.studentId,
        'admissionNumber': student.admissionNumber,
        'photoUrl': photoUrl,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      print('❌ Error adding student: $e');

      // Cleanup
      try {
        User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          await currentUser.delete();
        }
      } catch (deleteError) {
        print('⚠️ Error cleaning up auth user: $deleteError');
      }

      rethrow;
    }
  }

  Future<bool> updateStudent(Student student, File? imageFile) async {
    try {
      String? photoUrl;

      // Upload new image if provided
      if (imageFile != null) {
        final ref = _storage.ref().child(
          'students/${student.studentId}/profile.jpg',
        );
        final uploadTask = ref.putFile(imageFile);
        final snapshot = await uploadTask.whenComplete(() {});
        photoUrl = await snapshot.ref.getDownloadURL();
      }

      // Update student document
      final studentData = student.toMap();
      if (photoUrl != null) {
        studentData['photoUrl'] = photoUrl;
      } else {
        // Keep existing photo URL if no new image is provided
        var existingStudent = await _firestore
            .collection('students')
            .doc(student.studentId)
            .get();
        if (existingStudent.exists &&
            existingStudent.data()?['photoUrl'] != null) {
          studentData['photoUrl'] = existingStudent.data()?['photoUrl'];
        }
      }

      await _firestore
          .collection('students')
          .doc(student.studentId)
          .set(studentData, SetOptions(merge: true));

      // Update user account for student
      await _firestore.collection('users').doc(student.studentId).set({
        'email': student.email,
        'name': student.fullName,
        'admissionNumber': student.admissionNumber,
        'photoUrl': studentData['photoUrl'],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error updating student: $e');
      return false;
    }
  }

  Future<List<Student>> getStudents(String schoolId) async {
    try {
      var query = await _firestore
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => Student.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting students: $e');
      return [];
    }
  }

  Future<bool> deleteStudent(String studentId) async {
    try {
      await _firestore.collection('students').doc(studentId).delete();
      await _firestore.collection('users').doc(studentId).delete();
      return true;
    } catch (e) {
      print('Error deleting student: $e');
      return false;
    }
  }

  Future<List<Student>> getStudentsByClass(String className) async {
    try {
      var query = await _firestore
          .collection('students')
          .where('className', isEqualTo: className)
          .orderBy('firstName')
          .get();

      return query.docs.map((doc) => Student.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting students by class: $e');
      return [];
    }
  }

  Future<List<StudentAssignment>> getStudentAssignments(
    String studentId,
    String className,
  ) async {
    try {
      // This is a simplified version - you'll need to implement the actual logic
      // For now, returning an empty list
      return [];
    } catch (e) {
      print('Error getting student assignments: $e');
      return [];
    }
  }
}
