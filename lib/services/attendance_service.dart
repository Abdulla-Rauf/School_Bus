// attendance_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  final FirebaseFirestore _firestore;

  AttendanceService(this._firestore);

  Future<bool> markAttendance(AttendanceRecord attendance) async {
    try {
      await _firestore.collection('attendance').doc(attendance.recordId).set(attendance.toMap());
      return true;
    } catch (e) {
      print('Error marking attendance: $e');
      return false;
    }
  }

  Future<AttendanceRecord?> getAttendanceByClassAndDate(String classId, DateTime date) async {
    try {
      String dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      var query = await _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('dateString', isEqualTo: dateString)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return AttendanceRecord.fromMap(query.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting attendance: $e');
      return null;
    }
  }

  Future<List<AttendanceRecord>> getClassAttendance(String classId, {int? limit}) async {
    try {
      var query = _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .orderBy('date', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      var snapshot = await query.get();
      return snapshot.docs.map((doc) => AttendanceRecord.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting class attendance: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getStudentAttendanceSummary(String studentId, String classId) async {
    try {
      var query = await _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .where('records', arrayContains: {'studentId': studentId})
          .get();

      int totalDays = query.docs.length;
      Map<String, int> statusCount = {
        'present': 0,
        'absent': 0,
        'late': 0,
        'excused': 0,
      };

      for (var doc in query.docs) {
        var record = AttendanceRecord.fromMap(doc.data());
        var studentRecord = record.records.firstWhere(
              (r) => r.studentId == studentId,
          orElse: () => StudentAttendance(
            studentId: '',
            studentName: '',
            admissionNumber: '',
            status: 'absent',
          ),
        );

        if (statusCount.containsKey(studentRecord.status)) {
          statusCount[studentRecord.status] = statusCount[studentRecord.status]! + 1;
        }
      }

      return {
        'totalDays': totalDays,
        'statusCount': statusCount,
        'attendancePercentage': totalDays > 0 ? (statusCount['present']! / totalDays * 100).round() : 0,
      };
    } catch (e) {
      print('Error getting student attendance summary: $e');
      return {'totalDays': 0, 'statusCount': {}, 'attendancePercentage': 0};
    }
  }

  Future<List<AttendanceRecord>> getAttendanceByClass(
      String classId, {
        DateTime? startDate,
        DateTime? endDate,
      }) async {
    try {
      Query query = _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .orderBy('date', descending: true);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: endDate);
      }

      var snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AttendanceRecord.fromMap(data);
      }).toList();
    } catch (e) {
      print('Error getting attendance by class: $e');
      return [];
    }
  }

  Future<List<AttendanceRecord>> getAttendanceByStudent(
      String studentId,
      String classId, {
        DateTime? startDate,
        DateTime? endDate,
      }) async {
    try {
      Query query = _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .orderBy('date', descending: true);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: endDate);
      }

      var snapshot = await query.get();

      List<AttendanceRecord> studentRecords = [];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

          // Convert timestamp to DateTime
          dynamic dateData = data['date'];
          DateTime recordDate;

          if (dateData is Timestamp) {
            recordDate = dateData.toDate();
          } else if (dateData is int) {
            recordDate = DateTime.fromMillisecondsSinceEpoch(dateData);
          } else {
            continue;
          }

          // Check if records exist
          if (data['records'] == null) {
            continue;
          }

          List<dynamic> recordsData = data['records'] as List<dynamic>;

          // Look for the specific student
          for (var recordData in recordsData) {
            if (recordData is Map<String, dynamic>) {
              if (recordData['studentId'] == studentId) {
                // Create student attendance object
                StudentAttendance studentAttendance = StudentAttendance(
                  studentId: recordData['studentId'] ?? '',
                  studentName: recordData['studentName'] ?? '',
                  admissionNumber: recordData['admissionNumber'] ?? '',
                  status: recordData['status'] ?? 'absent',
                  markedAt: recordData['markedAt'] != null
                      ? (recordData['markedAt'] is Timestamp
                      ? (recordData['markedAt'] as Timestamp).toDate()
                      : DateTime.fromMillisecondsSinceEpoch(recordData['markedAt']))
                      : recordDate,
                  notes: recordData['notes'],
                );

                // Create attendance record
                AttendanceRecord record = AttendanceRecord(
                  recordId: doc.id,
                  date: recordDate,
                  dateString: data['dateString'] ?? '',
                  classId: data['classId'] ?? '',
                  className: data['className'] ?? '',
                  records: [studentAttendance],
                  markedBy: data['markedBy'] ?? '',
                  teacherId: data['teacherId'] ?? '',
                  createdAt: data['createdAt'] != null
                      ? (data['createdAt'] is Timestamp
                      ? (data['createdAt'] as Timestamp).toDate()
                      : DateTime.fromMillisecondsSinceEpoch(data['createdAt']))
                      : recordDate,
                  updatedAt: data['updatedAt'] != null
                      ? (data['updatedAt'] is Timestamp
                      ? (data['updatedAt'] as Timestamp).toDate()
                      : DateTime.fromMillisecondsSinceEpoch(data['updatedAt']))
                      : recordDate,
                );

                studentRecords.add(record);
                break;
              }
            }
          }
        } catch (e) {
          print('❌ Error processing document: $e');
        }
      }

      return studentRecords;
    } catch (e) {
      print('❌ Error getting attendance by student: $e');
      return [];
    }
  }

  Future<List<AttendanceRecord>> getStudentAttendanceSimple(
      String studentId,
      String classId,
      ) async {
    try {
      // Get all attendance records for the class
      var query = await _firestore
          .collection('attendance')
          .where('classId', isEqualTo: classId)
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      List<AttendanceRecord> studentRecords = [];

      for (var doc in query.docs) {
        try {
          final data = doc.data();

          // Check if records field exists and is a list
          if (data['records'] != null && data['records'] is List) {
            List<dynamic> records = data['records'];

            // Look for this student in the records
            for (var record in records) {
              if (record is Map<String, dynamic>) {
                String recordStudentId = record['studentId']?.toString() ?? '';

                if (recordStudentId == studentId) {
                  // Create the attendance record
                  AttendanceRecord attendanceRecord = AttendanceRecord(
                    recordId: doc.id,
                    date: data['date'] is Timestamp
                        ? (data['date'] as Timestamp).toDate()
                        : DateTime.now(),
                    dateString: data['dateString'] ?? '',
                    classId: data['classId'] ?? '',
                    className: data['className'] ?? '',
                    records: [StudentAttendance.fromMap(record)],
                    markedBy: data['markedBy'] ?? '',
                    teacherId: data['teacherId'] ?? '',
                    createdAt: data['createdAt'] is Timestamp
                        ? (data['createdAt'] as Timestamp).toDate()
                        : DateTime.now(),
                    updatedAt: data['updatedAt'] is Timestamp
                        ? (data['updatedAt'] as Timestamp).toDate()
                        : DateTime.now(),
                  );

                  studentRecords.add(attendanceRecord);
                  break;
                }
              }
            }
          }
        } catch (e) {
          print('   ❌ Error processing document: $e');
        }
      }

      return studentRecords;
    } catch (e) {
      print('❌ Error in getStudentAttendanceSimple: $e');
      return [];
    }
  }
}