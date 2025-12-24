// school_model.dart
class School {
  final String schoolId;
  final String name;
  final String type;
  final String location;
  final double? latitude;
  final double? longitude;
  final String address;
  final String curriculum;
  final String email;
  final String phone;
  final int? establishmentYear;
  final int? totalStudents;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? logoUrl;

  School({
    required this.schoolId,
    required this.name,
    required this.type,
    required this.location,
    this.latitude,
    this.longitude,
    required this.address,
    required this.curriculum,
    required this.email,
    required this.phone,
    this.establishmentYear,
    this.totalStudents,
    required this.createdAt,
    this.updatedAt,
    this.logoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'name': name,
      'type': type,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'curriculum': curriculum,
      'email': email,
      'phone': phone,
      'establishmentYear': establishmentYear,
      'totalStudents': totalStudents,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
      'logoUrl': logoUrl,
    };
  }

  factory School.fromMap(Map<String, dynamic> map) {
    return School(
      schoolId: map['schoolId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'High School',
      location: map['location'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      address: map['address'] ?? '',
      curriculum: map['curriculum'] ?? 'CBSE',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      establishmentYear: map['establishmentYear'],
      totalStudents: map['totalStudents'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
      logoUrl: map['logoUrl'],
    );
  }

  School copyWith({
    String? name,
    String? type,
    String? location,
    double? latitude,
    double? longitude,
    String? address,
    String? curriculum,
    String? email,
    String? phone,
    int? establishmentYear,
    int? totalStudents,
    DateTime? updatedAt,
    String? logoUrl,
  }) {
    return School(
      schoolId: schoolId,
      name: name ?? this.name,
      type: type ?? this.type,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      curriculum: curriculum ?? this.curriculum,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      establishmentYear: establishmentYear ?? this.establishmentYear,
      totalStudents: totalStudents ?? this.totalStudents,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}