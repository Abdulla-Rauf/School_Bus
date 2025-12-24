// user_model.dart
class UserModel {
  final String uid;
  final String? authUid;
  final String email;
  final String name;
  final String role;
  final String? schoolId;
  final String? specificId;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    this.authUid,
    required this.email,
    required this.name,
    required this.role,
    this.schoolId,
    this.specificId,
    this.photoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'authUid': authUid,
      'email': email,
      'name': name,
      'role': role,
      'schoolId': schoolId,
      'specificId': specificId,
      'photoUrl': photoUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      authUid: map['authUid'],
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      schoolId: map['schoolId'],
      specificId: map['specificId'],
      photoUrl: map['photoUrl'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : null,
    );
  }
}