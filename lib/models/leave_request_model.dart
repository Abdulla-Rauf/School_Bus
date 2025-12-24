class LeaveRequest {
  final String leaveId;
  final String studentId;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final String? teacherComments;
  final DateTime requestedAt;
  final String? handledBy;

  LeaveRequest({
    required this.leaveId,
    required this.studentId,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    this.status = 'pending',
    this.teacherComments,
    required this.requestedAt,
    this.handledBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'leaveId': leaveId,
      'studentId': studentId,
      'fromDate': fromDate.millisecondsSinceEpoch,
      'toDate': toDate.millisecondsSinceEpoch,
      'reason': reason,
      'status': status,
      'teacherComments': teacherComments,
      'requestedAt': requestedAt.millisecondsSinceEpoch,
      'handledBy': handledBy,
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      leaveId: map['leaveId'] ?? '',
      studentId: map['studentId'] ?? '',
      fromDate: DateTime.fromMillisecondsSinceEpoch(map['fromDate'] ?? 0),
      toDate: DateTime.fromMillisecondsSinceEpoch(map['toDate'] ?? 0),
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      teacherComments: map['teacherComments'],
      requestedAt: DateTime.fromMillisecondsSinceEpoch(map['requestedAt'] ?? 0),
      handledBy: map['handledBy'],
    );
  }
}