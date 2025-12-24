// assignment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/assignment_model.dart';
import '../models/submission_model.dart';

class AssignmentService {
  final FirebaseFirestore _firestore;

  AssignmentService(this._firestore);

  Future<bool> createAssignment(Assignment assignment) async {
    try {
      await _firestore.collection('assignments').doc(assignment.assignmentId).set(assignment.toMap());
      return true;
    } catch (e) {
      print('Error creating assignment: $e');
      return false;
    }
  }

  Future<List<Assignment>> getAssignmentsByClass(String classId) async {
    try {
      var query = await _firestore
          .collection('assignments')
          .where('classId', isEqualTo: classId)
          .orderBy('dueDate')
          .get();

      return query.docs.map((doc) => Assignment.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting assignments by class: $e');
      return [];
    }
  }

  Future<List<Assignment>> getAssignmentsByTeacher(String teacherId) async {
    try {
      var query = await _firestore
          .collection('assignments')
          .where('createdBy', isEqualTo: teacherId)
          .orderBy('dueDate')
          .get();

      return query.docs.map((doc) => Assignment.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting assignments by teacher: $e');
      return [];
    }
  }

  Future<bool> submitAssignment(Submission submission) async {
    try {
      await _firestore.collection('submissions').doc(submission.submissionId).set(submission.toMap());
      return true;
    } catch (e) {
      print('Error submitting assignment: $e');
      return false;
    }
  }

  Future<Submission?> getSubmission(String assignmentId, String studentId) async {
    try {
      var query = await _firestore
          .collection('submissions')
          .where('assignmentId', isEqualTo: assignmentId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return Submission.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting submission: $e');
      return null;
    }
  }

  Future<List<Submission>> getSubmissionsByAssignment(String assignmentId) async {
    try {
      var query = await _firestore
          .collection('submissions')
          .where('assignmentId', isEqualTo: assignmentId)
          .get();

      return query.docs.map((doc) => Submission.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting submissions: $e');
      return [];
    }
  }
}