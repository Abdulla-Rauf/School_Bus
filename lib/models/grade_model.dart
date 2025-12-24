import 'dart:convert';

class Grade {
  final String gradeId;
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String classId;
  final String className;
  final String subject;
  final String teacherId;
  final String teacherName;
  final String schoolId;
  final String examType; // e.g., "Quiz", "Midterm", "Final"
  final String term; // e.g., "Term 1", "Term 2", "Term 3"
  final int academicYear;
  final int maxMarks;
  final int obtainedMarks;
  final double percentage;
  final String grade; // e.g., "A+", "B", "C"
  final String? comments;
  final DateTime createdAt;
  final DateTime updatedAt;

  Grade({
    required this.gradeId,
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.classId,
    required this.className,
    required this.subject,
    required this.teacherId,
    required this.teacherName,
    required this.schoolId,
    required this.examType,
    required this.term,
    required this.academicYear,
    required this.maxMarks,
    required this.obtainedMarks,
    required this.percentage,
    required this.grade,
    this.comments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Grade.fromMap(Map<String, dynamic> map) {
    return Grade(
      gradeId: map['gradeId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      admissionNumber: map['admissionNumber'] ?? '',
      classId: map['classId'] ?? '',
      className: map['className'] ?? '',
      subject: map['subject'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      schoolId: map['schoolId'] ?? '',
      examType: map['examType'] ?? 'Quiz',
      term: map['term'] ?? 'Term 1',
      academicYear: map['academicYear'] ?? DateTime.now().year,
      maxMarks: map['maxMarks'] ?? 100,
      obtainedMarks: map['obtainedMarks'] ?? 0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0, // FIXED: Convert num to double
      grade: map['grade'] ?? 'N/A',
      comments: map['comments'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gradeId': gradeId,
      'studentId': studentId,
      'studentName': studentName,
      'admissionNumber': admissionNumber,
      'classId': classId,
      'className': className,
      'subject': subject,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'schoolId': schoolId,
      'examType': examType,
      'term': term,
      'academicYear': academicYear,
      'maxMarks': maxMarks,
      'obtainedMarks': obtainedMarks,
      'percentage': percentage,
      'grade': grade,
      'comments': comments,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Calculate grade based on percentage
  static String calculateGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B+';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C+';
    if (percentage >= 40) return 'C';
    if (percentage >= 33) return 'D';
    return 'F';
  }

  // Calculate percentage
  static double calculatePercentage(int obtainedMarks, int maxMarks) {
    if (maxMarks == 0) return 0.0;
    return (obtainedMarks / maxMarks) * 100;
  }

  // Create a new grade entry
  static Grade create({
    required String studentId,
    required String studentName,
    required String admissionNumber,
    required String classId,
    required String className,
    required String subject,
    required String teacherId,
    required String teacherName,
    required String schoolId,
    required String examType,
    required String term,
    required int academicYear,
    required int maxMarks,
    required int obtainedMarks,
    String? comments,
  }) {
    final double percentage = calculatePercentage(obtainedMarks, maxMarks);
    final String grade = calculateGrade(percentage);
    final String gradeId = 'grade_${DateTime.now().millisecondsSinceEpoch}_${studentId}_$subject';

    return Grade(
      gradeId: gradeId,
      studentId: studentId,
      studentName: studentName,
      admissionNumber: admissionNumber,
      classId: classId,
      className: className,
      subject: subject,
      teacherId: teacherId,
      teacherName: teacherName,
      schoolId: schoolId,
      examType: examType,
      term: term,
      academicYear: academicYear,
      maxMarks: maxMarks,
      obtainedMarks: obtainedMarks,
      percentage: percentage,
      grade: grade,
      comments: comments,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Update marks
  Grade updateMarks(int newObtainedMarks, int newMaxMarks, {String? newComments}) {
    final double newPercentage = calculatePercentage(newObtainedMarks, newMaxMarks);
    final String newGrade = calculateGrade(newPercentage);

    return Grade(
      gradeId: gradeId,
      studentId: studentId,
      studentName: studentName,
      admissionNumber: admissionNumber,
      classId: classId,
      className: className,
      subject: subject,
      teacherId: teacherId,
      teacherName: teacherName,
      schoolId: schoolId,
      examType: examType,
      term: term,
      academicYear: academicYear,
      maxMarks: newMaxMarks,
      obtainedMarks: newObtainedMarks,
      percentage: newPercentage,
      grade: newGrade,
      comments: newComments ?? comments,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());
  factory Grade.fromJson(String source) => Grade.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Grade(gradeId: $gradeId, student: $studentName, subject: $subject, marks: $obtainedMarks/$maxMarks, grade: $grade)';
  }
}

class GradeSummary {
  final String studentId;
  final String studentName;
  final String className;
  final String subject;
  final double averagePercentage;
  final String averageGrade;
  final List<Grade> allGrades;
  final int totalExams;
  final int totalMarksObtained;
  final int totalMaxMarks;

  GradeSummary({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.subject,
    required this.averagePercentage,
    required this.averageGrade,
    required this.allGrades,
    required this.totalExams,
    required this.totalMarksObtained,
    required this.totalMaxMarks,
  });

  static GradeSummary fromGrades(List<Grade> grades) {
    if (grades.isEmpty) {
      return GradeSummary(
        studentId: '',
        studentName: '',
        className: '',
        subject: '',
        averagePercentage: 0.0,
        averageGrade: 'N/A',
        allGrades: [],
        totalExams: 0,
        totalMarksObtained: 0,
        totalMaxMarks: 0,
      );
    }

    final totalMarksObtained = grades.fold(0, (sum, grade) => sum + grade.obtainedMarks);
    final totalMaxMarks = grades.fold(0, (sum, grade) => sum + grade.maxMarks);
    final averagePercentage = totalMaxMarks > 0 ? (totalMarksObtained / totalMaxMarks) * 100 : 0.0;
    final averageGrade = Grade.calculateGrade(averagePercentage);

    return GradeSummary(
      studentId: grades.first.studentId,
      studentName: grades.first.studentName,
      className: grades.first.className,
      subject: grades.first.subject,
      averagePercentage: averagePercentage,
      averageGrade: averageGrade,
      allGrades: grades,
      totalExams: grades.length,
      totalMarksObtained: totalMarksObtained,
      totalMaxMarks: totalMaxMarks,
    );
  }
}

class GradeEntry {
  int obtainedMarks;
  int maxMarks;
  String comments;

  GradeEntry({
    required this.obtainedMarks,
    required this.maxMarks,
    required this.comments,
  });
}