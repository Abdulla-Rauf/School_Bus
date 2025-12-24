class AttendanceRecord {
  final String recordId;
  final DateTime date;
  final String dateString; // YYYY-MM-DD format for querying
  final String classId;
  final String className;
  final List<StudentAttendance> records;
  final String markedBy;
  final String teacherId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AttendanceRecord({
    required this.recordId,
    required this.date,
    required this.dateString,
    required this.classId,
    required this.className,
    required this.records,
    required this.markedBy,
    required this.teacherId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'recordId': recordId,
      'date': date.millisecondsSinceEpoch,
      'dateString': dateString,
      'classId': classId,
      'className': className,
      'records': records.map((record) => record.toMap()).toList(),
      'markedBy': markedBy,
      'teacherId': teacherId,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      recordId: map['recordId'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      dateString: map['dateString'] ?? '',
      classId: map['classId'] ?? '',
      className: map['className'] ?? '',
      records: List<dynamic>.from(map['records'] ?? [])
          .map((record) => StudentAttendance.fromMap(record))
          .toList(),
      markedBy: map['markedBy'] ?? '',
      teacherId: map['teacherId'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }
}

class StudentAttendance {
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String status; // 'present', 'absent', 'late', 'excused'
  final DateTime? markedAt;
  final String? notes;

  StudentAttendance({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.status,
    this.markedAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'admissionNumber': admissionNumber,
      'status': status,
      'markedAt': markedAt?.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  factory StudentAttendance.fromMap(Map<String, dynamic> map) {
    return StudentAttendance(
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      admissionNumber: map['admissionNumber'] ?? '',
      status: map['status'] ?? 'absent',
      markedAt: map['markedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['markedAt'])
          : null,
      notes: map['notes'],
    );
  }
}