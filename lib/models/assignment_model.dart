class Assignment {
  final String assignmentId;
  final String title;
  final String description;
  final String classId;
  final String createdBy;
  final DateTime dueDate;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  Assignment({
    required this.assignmentId,
    required this.title,
    required this.description,
    required this.classId,
    required this.createdBy,
    required this.dueDate,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'assignmentId': assignmentId,
      'title': title,
      'description': description,
      'classId': classId,
      'createdBy': createdBy,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'attachments': attachments,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      assignmentId: map['assignmentId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      classId: map['classId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['dueDate'] ?? 0),
      attachments: List<String>.from(map['attachments'] ?? []),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  bool get isUrgent => dueDate.difference(DateTime.now()).inHours <= 48;
}