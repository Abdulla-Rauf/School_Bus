class Teacher {
  final String teacherId;
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime dateOfBirth;
  final String bloodGroup;
  final String phone;
  final String? alternatePhone;
  final String email;
  final String address;
  final String qualification;
  final int experience;
  final String specialization;
  final String schoolId;
  final String schoolName;
  final DateTime joiningDate;
  final String primaryClass;
  final List<String> secondaryClasses;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Teacher({
    required this.teacherId,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.bloodGroup,
    required this.phone,
    this.alternatePhone,
    required this.email,
    required this.address,
    required this.qualification,
    required this.experience,
    required this.specialization,
    required this.schoolId,
    required this.schoolName,
    required this.joiningDate,
    required this.primaryClass,
    required this.secondaryClasses,
    this.photoUrl,

    required this.createdAt,
    required this.updatedAt,
  });

  // Get full name
  String get name => '$firstName $lastName';

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'dateOfBirth': dateOfBirth.millisecondsSinceEpoch,
      'bloodGroup': bloodGroup,
      'phone': phone,
      'alternatePhone': alternatePhone,
      'email': email,
      'address': address,
      'qualification': qualification,
      'experience': experience,
      'specialization': specialization,
      'schoolId': schoolId,
      'schoolName': schoolName,
      'joiningDate': joiningDate.millisecondsSinceEpoch,
      'primaryClass': primaryClass,
      'secondaryClasses': secondaryClasses,
      'photoUrl': photoUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      teacherId: map['teacherId'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      gender: map['gender'] ?? '',
      dateOfBirth: DateTime.fromMillisecondsSinceEpoch(map['dateOfBirth'] ?? 0),
      bloodGroup: map['bloodGroup'] ?? '',
      phone: map['phone'] ?? '',
      alternatePhone: map['alternatePhone'],
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      qualification: map['qualification'] ?? '',
      experience: map['experience'] ?? 0,
      specialization: map['specialization'] ?? '',
      schoolId: map['schoolId'] ?? '',
      schoolName: map['schoolName'] ?? '',
      joiningDate: DateTime.fromMillisecondsSinceEpoch(map['joiningDate'] ?? 0),
      primaryClass: map['primaryClass'] ?? '',
      secondaryClasses: List<String>.from(map['secondaryClasses'] ?? []),
      photoUrl: map['photoUrl'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? map['createdAt'] ?? 0),
    );
  }
}