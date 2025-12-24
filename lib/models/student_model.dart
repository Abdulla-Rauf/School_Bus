// student_model.dart
class Student {
  final String studentId;
  final String admissionNumber;
  final String firstName;
  final String lastName;
  final String email;
  final String primaryPhone;
  final String secondaryPhone;
  final String fatherName;
  final String motherName;
  final String guardianName;
  final String address;
  final String bloodGroup;
  final String schoolId;
  final String schoolName;
  final String gender;
  final String className;
  final DateTime dateOfBirth;
  final String? photoUrl;
  final String? authUid;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? latitude;
  final double? longitude;

  Student({
    required this.studentId,
    required this.admissionNumber,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.primaryPhone,
    required this.secondaryPhone,
    required this.fatherName,
    required this.motherName,
    required this.guardianName,
    required this.address,
    required this.bloodGroup,
    required this.schoolId,
    required this.schoolName,
    required this.gender,
    required this.className,
    required this.dateOfBirth,
    this.photoUrl,
    this.authUid,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'admissionNumber': admissionNumber,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'primaryPhone': primaryPhone,
      'secondaryPhone': secondaryPhone,
      'fatherName': fatherName,
      'motherName': motherName,
      'guardianName': guardianName,
      'address': address,
      'bloodGroup': bloodGroup,
      'schoolId': schoolId,
      'schoolName': schoolName,
      'gender': gender,
      'className': className,
      'dateOfBirth': dateOfBirth.millisecondsSinceEpoch,
      'photoUrl': photoUrl,
      'authUid': authUid,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      studentId: map['studentId'] ?? '',
      admissionNumber: map['admissionNumber'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      email: map['email'] ?? '',
      primaryPhone: map['primaryPhone'] ?? '',
      secondaryPhone: map['secondaryPhone'] ?? '',
      fatherName: map['fatherName'] ?? '',
      motherName: map['motherName'] ?? '',
      guardianName: map['guardianName'] ?? '',
      address: map['address'] ?? '',
      bloodGroup: map['bloodGroup'] ?? '',
      schoolId: map['schoolId'] ?? '',
      schoolName: map['schoolName'] ?? '',
      gender: map['gender'] ?? '',
      className: map['className'] ?? '',
      dateOfBirth: DateTime.fromMillisecondsSinceEpoch(map['dateOfBirth'] ?? 0),
      photoUrl: map['photoUrl'],
      authUid: map['authUid'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updatedAt'] ?? map['createdAt'] ?? 0,
      ),
      latitude: map['latitude'],
      longitude: map['longitude'],
    );
  }
}
