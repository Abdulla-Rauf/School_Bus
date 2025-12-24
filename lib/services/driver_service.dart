// driver_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/driver_model.dart';

class DriverService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  DriverService(this._firestore, this._storage, this._auth);

  Future<bool> addDriver(Driver driver, File? imageFile) async {
    FirebaseApp? secondaryApp;
    try {
      String? photoUrl;

      // 1. Initialize secondary Firebase App
      FirebaseApp defaultApp = Firebase.app();
      secondaryApp = await Firebase.initializeApp(
        name: 'secondaryApp',
        options: defaultApp.options,
      );

      // 2. Create Firebase Authentication user using secondary app
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      UserCredential userCredential = await secondaryAuth
          .createUserWithEmailAndPassword(
            email: driver.email,
            password: driver.driverId,
          );

      String authUid = userCredential.user!.uid;

      // Upload image (using primary app storage)
      if (imageFile != null) {
        final ref = _storage.ref().child(
          'drivers/${driver.driverId}/profile.jpg',
        );
        final uploadTask = ref.putFile(imageFile);
        final snapshot = await uploadTask.whenComplete(() {});
        photoUrl = await snapshot.ref.getDownloadURL();
      }

      // Create driver document (using primary app firestore)
      final driverData = driver.toMap();
      if (photoUrl != null) {
        driverData['photoUrl'] = photoUrl;
      }
      driverData['authUid'] = authUid;

      await _firestore
          .collection('drivers')
          .doc(driver.driverId)
          .set(driverData);

      // Create user account for driver (using primary app firestore)
      await _firestore.collection('users').doc(driver.driverId).set({
        'uid': driver.driverId,
        'authUid': authUid,
        'email': driver.email,
        'name': driver.name,
        'role': 'driver',
        'schoolId': driver.schoolId,
        'specificId': driver.driverId,
        'photoUrl': photoUrl,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Cleanup
      await secondaryApp.delete();

      return true;
    } catch (e) {
      print('Error adding driver: $e');
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (deleteError) {
          print('Error cleaning up secondary app: $deleteError');
        }
      }
      return false;
    }
  }

  Future<bool> updateDriver(Driver driver, File? imageFile) async {
    try {
      String? photoUrl;

      // Upload new image if provided
      if (imageFile != null) {
        final ref = _storage.ref().child(
          'drivers/${driver.driverId}/profile.jpg',
        );
        final uploadTask = ref.putFile(imageFile);
        final snapshot = await uploadTask.whenComplete(() {});
        photoUrl = await snapshot.ref.getDownloadURL();
      }

      // Update driver document
      final driverData = driver.toMap();
      if (photoUrl != null) {
        driverData['photoUrl'] = photoUrl;
      } else {
        // Keep existing photo URL
        var existingDriver = await _firestore
            .collection('drivers')
            .doc(driver.driverId)
            .get();
        if (existingDriver.exists &&
            existingDriver.data()?['photoUrl'] != null) {
          driverData['photoUrl'] = existingDriver.data()?['photoUrl'];
        }
      }

      await _firestore
          .collection('drivers')
          .doc(driver.driverId)
          .set(driverData, SetOptions(merge: true));

      // Update user account
      await _firestore.collection('users').doc(driver.driverId).set({
        'email': driver.email,
        'name': driver.name,
        'photoUrl': driverData['photoUrl'],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Error updating driver: $e');
      return false;
    }
  }

  Future<List<Driver>> getDrivers(String schoolId) async {
    try {
      var query = await _firestore
          .collection('drivers')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      // Manual sorting
      var drivers = query.docs
          .map((doc) => Driver.fromMap(doc.data()))
          .toList();
      drivers.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return drivers;
    } catch (e) {
      print('Error getting drivers: $e');
      return [];
    }
  }

  Future<bool> deleteDriver(String driverId) async {
    try {
      await _firestore.collection('drivers').doc(driverId).delete();
      await _firestore.collection('users').doc(driverId).delete();
      return true;
    } catch (e) {
      print('Error deleting driver: $e');
      return false;
    }
  }

  Future<Driver?> getDriverById(String driverId) async {
    try {
      var doc = await _firestore.collection('drivers').doc(driverId).get();
      if (doc.exists) {
        return Driver.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting driver by ID: $e');
      return null;
    }
  }
}
