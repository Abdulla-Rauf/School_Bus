class Driver {
  final String driverId;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String vehicleType;
  final String vehicleId;
  final String vehicleNumber;
  final String schoolId;
  final String? photoUrl;
  final DateTime createdAt;

  Driver({
    required this.driverId,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.vehicleType,
    required this.vehicleId,
    required this.vehicleNumber,
    required this.schoolId,
    this.photoUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'vehicleType': vehicleType,
      'vehicleId': vehicleId,
      'vehicleNumber': vehicleNumber,
      'schoolId': schoolId,
      'photoUrl': photoUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      driverId: map['driverId'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      vehicleType: map['vehicleType'] ?? '',
      vehicleId: map['vehicleId'] ?? '',
      vehicleNumber: map['vehicleNumber'] ?? '',
      schoolId: map['schoolId'] ?? '',
      photoUrl: map['photoUrl'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
    );
  }
}