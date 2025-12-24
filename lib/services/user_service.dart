// user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore;

  UserService(this._firestore);

  Future<UserModel?> getUserById(String userId) async {
    try {
      var doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }

  Future<UserModel?> getUserByAuthUid(String authUid) async {
    try {
      var query = await _firestore
          .collection('users')
          .where('authUid', isEqualTo: authUid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return UserModel.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting user by auth UID: $e');
      return null;
    }
  }

  Future<UserModel?> getUserByEmail(String email) async {
    try {
      var query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return UserModel.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }
}