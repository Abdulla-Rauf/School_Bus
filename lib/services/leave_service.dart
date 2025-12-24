// leave_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_request_model.dart';

class LeaveService {
  final FirebaseFirestore _firestore;

  LeaveService(this._firestore);

  Future<bool> createLeaveRequest(LeaveRequest leaveRequest) async {
    try {
      await _firestore.collection('leave_requests').doc(leaveRequest.leaveId).set(leaveRequest.toMap());
      return true;
    } catch (e) {
      print('Error creating leave request: $e');
      return false;
    }
  }

  Future<List<LeaveRequest>> getLeaveRequestsByStudent(String studentId) async {
    try {
      var query = await _firestore
          .collection('leave_requests')
          .where('studentId', isEqualTo: studentId)
          .orderBy('requestedAt', descending: true)
          .get();

      return query.docs.map((doc) => LeaveRequest.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting student leave requests: $e');
      return [];
    }
  }

  Future<List<LeaveRequest>> getPendingLeaveRequestsByTeacher(String teacherId, List<String> classIds) async {
    try {
      // Note: This method requires StudentService dependency
      // For now, we'll return an empty list
      // In a real implementation, you would need to inject StudentService
      return [];
    } catch (e) {
      print('Error getting pending leave requests: $e');
      return [];
    }
  }

  Future<bool> updateLeaveRequestStatus(String leaveId, String status, String teacherId, String comments) async {
    try {
      await _firestore.collection('leave_requests').doc(leaveId).update({
        'status': status,
        'handledBy': teacherId,
        'teacherComments': comments,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e) {
      print('Error updating leave request: $e');
      return false;
    }
  }
}