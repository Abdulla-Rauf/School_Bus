// grade_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grade_model.dart';

class GradeService {
  final FirebaseFirestore _firestore;

  GradeService(this._firestore);

  Future<bool> saveGrade(Grade grade) async {
    try {
      await _firestore
          .collection('grades')
          .doc(grade.gradeId)
          .set(grade.toMap());
      return true;
    } catch (e) {
      print('Error saving grade: $e');
      return false;
    }
  }

  Future<List<Grade>> getGradesByTeacher(
    String teacherId, {
    String? subject,
    String? classId,
  }) async {
    try {
      Query query = _firestore
          .collection('grades')
          .where('teacherId', isEqualTo: teacherId);

      if (subject != null && subject.isNotEmpty) {
        query = query.where('subject', isEqualTo: subject);
      }

      if (classId != null && classId.isNotEmpty) {
        query = query.where('classId', isEqualTo: classId);
      }

      query = query.orderBy('createdAt', descending: true);

      var snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Grade.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting grades by teacher: $e');
      return [];
    }
  }

  Future<List<Grade>> getGradesByStudent(
    String studentId, {
    String? subject,
  }) async {
    try {
      Query query = _firestore
          .collection('grades')
          .where('studentId', isEqualTo: studentId);

      if (subject != null && subject.isNotEmpty) {
        query = query.where('subject', isEqualTo: subject);
      }

      query = query.orderBy('createdAt', descending: true);

      var snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Grade.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting grades by student: $e');
      return [];
    }
  }

  Future<List<Grade>> getGradesByClassAndSubject(
    String classId,
    String subject,
  ) async {
    try {
      var snapshot = await _firestore
          .collection('grades')
          .where('classId', isEqualTo: classId)
          .where('subject', isEqualTo: subject)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Grade.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting grades by class and subject: $e');
      return [];
    }
  }

  Future<Grade?> getGradeById(String gradeId) async {
    try {
      var doc = await _firestore.collection('grades').doc(gradeId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Grade.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting grade by ID: $e');
      return null;
    }
  }

  Future<bool> deleteGrade(String gradeId) async {
    try {
      await _firestore.collection('grades').doc(gradeId).delete();
      return true;
    } catch (e) {
      print('Error deleting grade: $e');
      return false;
    }
  }

  Future<Map<String, GradeSummary>> getGradeSummariesByClassAndSubject(
    String classId,
    String subject,
  ) async {
    try {
      var grades = await getGradesByClassAndSubject(classId, subject);

      Map<String, List<Grade>> groupedByStudent = {};

      for (var grade in grades) {
        if (!groupedByStudent.containsKey(grade.studentId)) {
          groupedByStudent[grade.studentId] = [];
        }
        groupedByStudent[grade.studentId]!.add(grade);
      }

      Map<String, GradeSummary> summaries = {};

      for (var entry in groupedByStudent.entries) {
        summaries[entry.key] = GradeSummary.fromGrades(entry.value);
      }

      return summaries;
    } catch (e) {
      print('Error getting grade summaries: $e');
      return {};
    }
  }
}
