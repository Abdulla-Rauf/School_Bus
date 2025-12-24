// vehicle_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle_model.dart';

class VehicleService {
  final FirebaseFirestore _firestore;

  VehicleService(this._firestore);

  Future<bool> addVehicle(Vehicle vehicle) async {
    try {
      await _firestore.collection('vehicles').doc(vehicle.vehicleId).set(vehicle.toMap());
      return true;
    } catch (e) {
      print('Error adding vehicle: $e');
      return false;
    }
  }

  Future<List<Vehicle>> getVehicles(String schoolId) async {
    try {
      var query = await _firestore
          .collection('vehicles')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      var vehicles = query.docs.map((doc) => Vehicle.fromMap(doc.data())).toList();
      vehicles.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return vehicles;
    } catch (e) {
      print('Error getting vehicles: $e');
      return [];
    }
  }

  Future<bool> deleteVehicle(String vehicleId) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).delete();
      return true;
    } catch (e) {
      print('Error deleting vehicle: $e');
      return false;
    }
  }

  Future<List<Vehicle>> getAvailableVehicles(String schoolId, String vehicleType) async {
    try {
      var query = await _firestore
          .collection('vehicles')
          .where('schoolId', isEqualTo: schoolId)
          .where('vehicleType', isEqualTo: vehicleType)
          .get();

      return query.docs.map((doc) => Vehicle.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting available vehicles: $e');
      return [];
    }
  }

  Future<bool> updateVehicle(Vehicle vehicle) async {
    try {
      await _firestore.collection('vehicles').doc(vehicle.vehicleId).set(
        vehicle.toMap(),
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      print('Error updating vehicle: $e');
      return false;
    }
  }

  Future<List<Vehicle>> getVehiclesByDriver(String driverId) async {
    try {
      var query = await _firestore
          .collection('vehicles')
          .where('driverId', isEqualTo: driverId)
          .get();

      return query.docs.map((doc) => Vehicle.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting vehicles by driver: $e');
      return [];
    }
  }

  Future<bool> assignDriverToVehicle({
    required String vehicleId,
    required String driverId,
  }) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'driverId': driverId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      print('Error assigning driver to vehicle: $e');
      return false;
    }
  }

  Future<List<Vehicle>> getUnassignedVehicles(String schoolId) async {
    try {
      var query = await _firestore
          .collection('vehicles')
          .where('schoolId', isEqualTo: schoolId)
          .where('driverId', isEqualTo: null)
          .get();

      return query.docs.map((doc) => Vehicle.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting unassigned vehicles: $e');
      return [];
    }
  }

  Future<bool> removeDriverFromVehicle(String vehicleId) async {
    try {
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'driverId': FieldValue.delete(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      print('Error removing driver from vehicle: $e');
      return false;
    }
  }

  Future<Vehicle?> getVehicleByDriver(String driverId) async {
    try {
      var query = await _firestore
          .collection('vehicles')
          .where('driverId', isEqualTo: driverId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Vehicle.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting vehicle by driver: $e');
      return null;
    }
  }

  // Vehicle student assignment methods
  Future<bool> assignStudentToVehicle({
    required String vehicleId,
    required VehicleStudent student,
  }) async {
    try {
      DocumentSnapshot vehicleDoc = await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .get();

      if (!vehicleDoc.exists) {
        return false;
      }

      var vehicleData = vehicleDoc.data() as Map<String, dynamic>;
      List<dynamic> assignedStudents = vehicleData['assignedStudents'] ?? [];

      // Check if student is already assigned
      bool alreadyAssigned = assignedStudents.any((s) {
        var studentMap = s as Map<String, dynamic>;
        return studentMap['studentId'] == student.studentId;
      });

      if (alreadyAssigned) {
        return false;
      }

      // Add the student
      assignedStudents.add(student.toMap());

      // Update the vehicle
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'assignedStudents': assignedStudents,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      print('Error assigning student to vehicle: $e');
      return false;
    }
  }

  Future<bool> removeStudentFromVehicle({
    required String vehicleId,
    required String studentId,
  }) async {
    try {
      DocumentSnapshot vehicleDoc = await _firestore
          .collection('vehicles')
          .doc(vehicleId)
          .get();

      if (!vehicleDoc.exists) {
        return false;
      }

      var vehicleData = vehicleDoc.data() as Map<String, dynamic>;
      List<dynamic> assignedStudents = vehicleData['assignedStudents'] ?? [];

      // Remove the student
      assignedStudents.removeWhere((s) {
        var studentMap = s as Map<String, dynamic>;
        return studentMap['studentId'] == studentId;
      });

      // Update the vehicle
      await _firestore.collection('vehicles').doc(vehicleId).update({
        'assignedStudents': assignedStudents,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return true;
    } catch (e) {
      print('Error removing student from vehicle: $e');
      return false;
    }
  }

  Future<bool> updateStudentVehicleAssignment({
    required String oldVehicleId,
    required String newVehicleId,
    required VehicleStudent student,
  }) async {
    try {
      // Remove from old vehicle
      await removeStudentFromVehicle(
        vehicleId: oldVehicleId,
        studentId: student.studentId,
      );

      // Add to new vehicle
      return await assignStudentToVehicle(
        vehicleId: newVehicleId,
        student: student,
      );
    } catch (e) {
      print('Error updating student vehicle assignment: $e');
      return false;
    }
  }
}