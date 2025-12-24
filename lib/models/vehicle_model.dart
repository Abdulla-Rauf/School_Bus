// class Vehicle {
//   final String vehicleId;
//   final String vehicleNumber;
//   final String vehicleType;
//   final String vehicleName;
//   final String modelNumber;
//   final int capacity;
//   final String schoolId;
//   final List<String> stops;
//   final DateTime createdAt;
//   final DateTime? updatedAt;
//
//   Vehicle({
//     required this.vehicleId,
//     required this.vehicleNumber,
//     required this.vehicleType,
//     required this.vehicleName,
//     required this.modelNumber,
//     required this.capacity,
//     required this.schoolId,
//     required this.stops,
//     required this.createdAt,
//     this.updatedAt,
//   });
//
//   // Update toMap and fromMap methods to include updatedAt
//   Map<String, dynamic> toMap() {
//     return {
//       'vehicleId': vehicleId,
//       'vehicleNumber': vehicleNumber,
//       'vehicleType': vehicleType,
//       'vehicleName': vehicleName,
//       'modelNumber': modelNumber,
//       'capacity': capacity,
//       'schoolId': schoolId,
//       'stops': stops,
//       'createdAt': createdAt.millisecondsSinceEpoch,
//       'updatedAt': updatedAt?.millisecondsSinceEpoch,
//     };
//   }
//
//   factory Vehicle.fromMap(Map<String, dynamic> map) {
//     return Vehicle(
//       vehicleId: map['vehicleId'],
//       vehicleNumber: map['vehicleNumber'],
//       vehicleType: map['vehicleType'],
//       vehicleName: map['vehicleName'],
//       modelNumber: map['modelNumber'],
//       capacity: map['capacity'],
//       schoolId: map['schoolId'],
//       stops: List<String>.from(map['stops']),
//       createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
//       updatedAt: map['updatedAt'] != null
//           ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
//           : null,
//     );
//   }
// }
// vehicle_model.dart - Update the Vehicle class
class Vehicle {
  final String vehicleId;
  final String vehicleNumber;
  final String vehicleType;
  final String vehicleName;
  final String modelNumber;
  final int capacity;
  final String schoolId;
  final List<String> stops;
  final List<VehicleStudent> assignedStudents; // NEW: Assigned students
  final String? driverId; // NEW: Assigned driver ID
  final DateTime createdAt;
  final DateTime? updatedAt;

  Vehicle({
    required this.vehicleId,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.vehicleName,
    required this.modelNumber,
    required this.capacity,
    required this.schoolId,
    required this.stops,
    this.assignedStudents = const [],
    this.driverId,
    required this.createdAt,
    this.updatedAt,
  });

  // Add toMap method update
  Map<String, dynamic> toMap() {
    return {
      'vehicleId': vehicleId,
      'vehicleNumber': vehicleNumber,
      'vehicleType': vehicleType,
      'vehicleName': vehicleName,
      'modelNumber': modelNumber,
      'capacity': capacity,
      'schoolId': schoolId,
      'stops': stops,
      'assignedStudents': assignedStudents.map((student) => student.toMap()).toList(),
      'driverId': driverId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  // Add fromMap method update
  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      vehicleId: map['vehicleId'] ?? '',
      vehicleNumber: map['vehicleNumber'] ?? '',
      vehicleType: map['vehicleType'] ?? '',
      vehicleName: map['vehicleName'] ?? '',
      modelNumber: map['modelNumber'] ?? '',
      capacity: map['capacity'] ?? 0,
      schoolId: map['schoolId'] ?? '',
      stops: List<String>.from(map['stops'] ?? []),
      assignedStudents: (map['assignedStudents'] as List<dynamic>?)
          ?.map((e) => VehicleStudent.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      driverId: map['driverId'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }
}

// NEW: VehicleStudent model to track student assignments
class VehicleStudent {
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String? className;
  final String pickupStop;
  final String dropoffStop;
  final bool isActive;
  final DateTime assignedAt;

  VehicleStudent({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    this.className,
    required this.pickupStop,
    required this.dropoffStop,
    this.isActive = true,
    required this.assignedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'admissionNumber': admissionNumber,
      'className': className,
      'pickupStop': pickupStop,
      'dropoffStop': dropoffStop,
      'isActive': isActive,
      'assignedAt': assignedAt.millisecondsSinceEpoch,
    };
  }

  factory VehicleStudent.fromMap(Map<String, dynamic> map) {
    return VehicleStudent(
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      admissionNumber: map['admissionNumber'] ?? '',
      className: map['className'],
      pickupStop: map['pickupStop'] ?? '',
      dropoffStop: map['dropoffStop'] ?? '',
      isActive: map['isActive'] ?? true,
      assignedAt: DateTime.fromMillisecondsSinceEpoch(map['assignedAt'] ?? 0),
    );
  }
}