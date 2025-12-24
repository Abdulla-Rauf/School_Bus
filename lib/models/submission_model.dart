class Submission {
  final String submissionId;
  final String assignmentId;
  final String studentId;
  final DateTime submittedAt;
  final String? fileUrl;
  final String status; // 'pending', 'submitted', 'graded'

  Submission({
    required this.submissionId,
    required this.assignmentId,
    required this.studentId,
    required this.submittedAt,
    this.fileUrl,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'submissionId': submissionId,
      'assignmentId': assignmentId,
      'studentId': studentId,
      'submittedAt': submittedAt.millisecondsSinceEpoch,
      'fileUrl': fileUrl,
      'status': status,
    };
  }

  factory Submission.fromMap(Map<String, dynamic> map) {
    return Submission(
      submissionId: map['submissionId'] ?? '',
      assignmentId: map['assignmentId'] ?? '',
      studentId: map['studentId'] ?? '',
      submittedAt: DateTime.fromMillisecondsSinceEpoch(map['submittedAt'] ?? 0),
      fileUrl: map['fileUrl'],
      status: map['status'] ?? 'pending',
    );
  }
}