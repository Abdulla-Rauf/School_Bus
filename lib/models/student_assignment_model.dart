// models/student_assignment_model.dart
import 'package:school_bus2/models/assignment_model.dart';

class StudentAssignment {
  final Assignment assignment;
  final bool isGroupAssignment;
  final bool isSubmitted;
  final DateTime? submittedAt;
  final String? submissionUrl;
  final String? grade;
  final String? teacherFeedback;

  StudentAssignment({
    required this.assignment,
    required this.isGroupAssignment,
    this.isSubmitted = false,
    this.submittedAt,
    this.submissionUrl,
    this.grade,
    this.teacherFeedback,
  });

  bool get isOverdue => assignment.dueDate.isBefore(DateTime.now()) && !isSubmitted;
  bool get isUpcoming => assignment.dueDate.isAfter(DateTime.now());
  bool get canSubmit => !isSubmitted && !isOverdue;

  Map<String, dynamic> toMap() {
    return {
      'assignment': assignment.toMap(),
      'isGroupAssignment': isGroupAssignment,
      'isSubmitted': isSubmitted,
      'submittedAt': submittedAt?.toIso8601String(),
      'submissionUrl': submissionUrl,
      'grade': grade,
      'teacherFeedback': teacherFeedback,
    };
  }

  static StudentAssignment fromMap(Map<String, dynamic> map) {
    return StudentAssignment(
      assignment: Assignment.fromMap(map['assignment']),
      isGroupAssignment: map['isGroupAssignment'] ?? false,
      isSubmitted: map['isSubmitted'] ?? false,
      submittedAt: map['submittedAt'] != null ? DateTime.parse(map['submittedAt']) : null,
      submissionUrl: map['submissionUrl'],
      grade: map['grade'],
      teacherFeedback: map['teacherFeedback'],
    );
  }
}