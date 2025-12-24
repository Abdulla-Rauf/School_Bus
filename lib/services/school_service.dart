// school_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/school_model.dart';

class SchoolService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  SchoolService(this._firestore, this._storage, this._auth);

  Future<List<School>> getAllSchools() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('schools')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return School(
          schoolId: doc.id,
          name: data['name'] ?? '',
          type: data['type'] ?? 'High School',
          location: data['location'] ?? '',
          address: data['address'] ?? '',
          curriculum: data['curriculum'] ?? 'CBSE',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          latitude: data['latitude']?.toDouble(),
          longitude: data['longitude']?.toDouble(),
          establishmentYear: data['establishmentYear'],
          totalStudents: data['totalStudents'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            data['createdAt'] ?? 0,
          ),
          logoUrl: data['logoUrl'],
        );
      }).toList();
    } catch (e) {
      print('Error loading schools: $e');
      return [];
    }
  }

  Future<School?> getSchoolById(String schoolId) async {
    try {
      print('🔍 Getting school by ID: $schoolId');

      if (schoolId.isEmpty) {
        print('⚠️ School ID is empty');
        return null;
      }

      DocumentSnapshot doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .get();

      print('📄 Document exists: ${doc.exists}');

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        print('📋 School data: $data');

        School school = School(
          schoolId: doc.id,
          name: data['name'] ?? '',
          type: data['type'] ?? 'High School',
          location: data['location'] ?? '',
          address: data['address'] ?? '',
          curriculum: data['curriculum'] ?? 'CBSE',
          email: data['email'] ?? '',
          phone: data['phone'] ?? '',
          latitude: data['latitude']?.toDouble(),
          longitude: data['longitude']?.toDouble(),
          establishmentYear: data['establishmentYear'],
          totalStudents: data['totalStudents'],
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            data['createdAt'] ?? 0,
          ),
          logoUrl: data['logoUrl'],
        );

        print('✅ School created: ${school.name}');
        return school;
      } else {
        print('❌ School document does not exist for ID: $schoolId');
        return null;
      }
    } catch (e) {
      print('❌ Error getting school by ID: $e');
      print('❌ Stack trace: ${e.toString()}');
      return null;
    }
  }

  Future<bool> createSchool(School school, String password) async {
    try {
      print('🔄 Starting school creation process...');

      // 1. Create Firebase Authentication user
      UserCredential? userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: school.email,
            password: password,
          );

      String authUid = userCredential.user!.uid;

      // 2. Create school document
      await _firestore
          .collection('schools')
          .doc(school.schoolId)
          .set(school.toMap());

      // 3. Create school admin user account
      await _firestore.collection('users').doc(school.schoolId).set({
        'uid': school.schoolId,
        'authUid': authUid,
        'email': school.email,
        'name': school.name,
        'role': 'school',
        'schoolId': school.schoolId,
        'specificId': school.schoolId,
        'photoUrl': school.logoUrl,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // 4. Create initial school configuration
      await _firestore.collection('school_configs').doc(school.schoolId).set({
        'schoolId': school.schoolId,
        'classes': [],
        'subjects': [],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      print('❌ Error creating school: $e');

      // Cleanup
      try {
        User? currentUser = _auth.currentUser;
        if (currentUser != null && currentUser.uid == _auth.currentUser?.uid) {
          await currentUser.delete();
        }
      } catch (deleteError) {
        print('⚠️ Error cleaning up auth user: $deleteError');
      }

      return false;
    }
  }

  Future<bool> updateSchool(School school) async {
    try {
      Map<String, dynamic> updateData = school.toMap();
      updateData['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      await _firestore
          .collection('schools')
          .doc(school.schoolId)
          .set(updateData, SetOptions(merge: true));

      // Also update the user account
      await _firestore.collection('users').doc(school.schoolId).set({
        'email': school.email,
        'name': school.name,
        'photoUrl': school.logoUrl,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('❌ Error updating school: $e');
      return false;
    }
  }

  Future<bool> deleteSchool(String schoolId) async {
    try {
      // 1. Get school data first
      DocumentSnapshot schoolDoc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .get();
      if (!schoolDoc.exists) {
        return false;
      }

      School school = School.fromMap(schoolDoc.data() as Map<String, dynamic>);

      // 2. Delete all related data
      await _deleteCollection('users', 'schoolId', schoolId);
      await _deleteCollection('students', 'schoolId', schoolId);
      await _deleteCollection('teachers', 'schoolId', schoolId);
      await _deleteCollection('drivers', 'schoolId', schoolId);
      await _deleteCollection('vehicles', 'schoolId', schoolId);

      await _firestore.collection('school_calendars').doc(schoolId).delete();
      await _firestore.collection('school_configs').doc(schoolId).delete();
      await _deleteCollection('assignments', 'schoolId', schoolId);
      await _deleteCollection('attendance', 'schoolId', schoolId);
      await _deleteCollection('grades', 'schoolId', schoolId);
      await _deleteCollection('submissions', 'schoolId', schoolId);
      await _deleteCollection('leave_requests', 'schoolId', schoolId);

      // 3. Delete school document
      await _firestore.collection('schools').doc(schoolId).delete();

      return true;
    } catch (e) {
      print('❌ Error deleting school: $e');
      return false;
    }
  }

  Future<String?> uploadSchoolLogo(File image, String schoolId) async {
    try {
      final ref = _storage.ref().child('schools/$schoolId/logo.jpg');
      final uploadTask = ref.putFile(image);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading school logo: $e');
      return null;
    }
  }

  Future<void> _deleteCollection(
    String collectionName,
    String fieldName,
    String schoolId,
  ) async {
    try {
      var query = await _firestore
          .collection(collectionName)
          .where(fieldName, isEqualTo: schoolId)
          .get();

      if (query.docs.isNotEmpty) {
        WriteBatch batch = _firestore.batch();
        for (var doc in query.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      print('   ⚠️ Error deleting $collectionName: $e');
    }
  }
}
