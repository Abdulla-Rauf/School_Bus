import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/attendance_model.dart';
import '../../models/student_model.dart';
import '../../models/teacher_model.dart';
import '../../models/user_model.dart';

class AttendanceScreen extends StatefulWidget {
  final String classId;
  final String className;

  const AttendanceScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final DatabaseService _dbService = DatabaseService();
  final List<Student> _students = [];
  final Map<String, String> _attendanceStatus = {};
  final Map<String, TextEditingController> _notesControllers = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPrimaryTeacher = false;
  Teacher? _teacher;
  AttendanceRecord? _existingAttendance;
  Map<String, String> _attendanceSummary = {};
  bool _isWorkingDay = true;
  String? _workingDayNote;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      UserModel? user = await authService.getCurrentUserData();

      if (user != null) {
        // Check if teacher is primary teacher for this class
        _isPrimaryTeacher = await _dbService.isPrimaryTeacherForClass(
          user.specificId!,
          widget.classId,
        );

        // Load teacher details
        _teacher = await _dbService.getTeacherById(user.specificId!);

        // Load students for the class
        List<Student> students = await _dbService.getStudentsByClass(
          widget.classId,
        );

        // Load existing attendance for today
        AttendanceRecord? existing = await _dbService
            .getAttendanceByClassAndDate(widget.classId, _selectedDate);

        setState(() {
          _students.clear();
          _students.addAll(students);
          _existingAttendance = existing;
          _isLoading = false;
        });

        // Initialize attendance status
        _initializeAttendanceStatus();
        _calculateAttendanceSummary();

        // Check if selected date is a working day
        final schoolId = _students.isNotEmpty
            ? _students.first.schoolId
            : (user.schoolId ?? '');
        if (schoolId.isNotEmpty) {
          final calendar = await _dbService.calendarService.getSchoolCalendar(
            schoolId,
          );
          if (calendar != null) {
            final isWorking = _dbService.calendarService.isDateWorkingDay(
              _selectedDate,
              calendar,
            );
            setState(() {
              _isWorkingDay = isWorking;
              if (!isWorking) {
                // Determine why - Holiday or Weekend?
                if (_selectedDate.weekday > 5 && !_hasWeekendWork(calendar)) {
                  // Assuming basic check
                  _workingDayNote = 'Weekend';
                } else {
                  _workingDayNote = 'Holiday / Non-working Day';
                }
              } else {
                _workingDayNote = null;
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error loading attendance data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _hasWeekendWork(dynamic calendar) {
    // Helper just for this check, ideally logic in service
    return false; // prompt logic simplified
  }

  void _initializeAttendanceStatus() {
    if (_existingAttendance != null) {
      for (var record in _existingAttendance!.records) {
        _attendanceStatus[record.studentId] = record.status;
        _notesControllers[record.studentId] = TextEditingController(
          text: record.notes,
        );
      }
    }

    // Initialize remaining students with default status
    for (var student in _students) {
      if (!_attendanceStatus.containsKey(student.studentId)) {
        _attendanceStatus[student.studentId] = 'present';
        _notesControllers[student.studentId] = TextEditingController();
      }
    }
  }

  void _calculateAttendanceSummary() {
    Map<String, int> summary = {
      'present': 0,
      'absent': 0,
      'late': 0,
      'excused': 0,
    };

    for (var status in _attendanceStatus.values) {
      if (summary.containsKey(status)) {
        summary[status] = summary[status]! + 1;
      }
    }

    setState(() {
      _attendanceSummary = {
        'present': summary['present'].toString(),
        'absent': summary['absent'].toString(),
        'late': summary['late'].toString(),
        'excused': summary['excused'].toString(),
        'total': _students.length.toString(),
      };
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black87,
              onPrimary: Colors.white,
            ),
            dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      await _loadData();
    }
  }

  Future<void> _saveAttendance() async {
    if (!_isPrimaryTeacher) {
      _showSnackbar(
        'Only primary teacher can mark attendance for this class',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      UserModel? user = await authService.getCurrentUserData();

      if (user == null || _teacher == null) {
        _showSnackbar('User not authenticated', isError: true);
        return;
      }

      List<StudentAttendance> records = _students.map((student) {
        return StudentAttendance(
          studentId: student.studentId,
          studentName: student.fullName,
          admissionNumber: student.admissionNumber,
          status: _attendanceStatus[student.studentId] ?? 'present',
          markedAt: DateTime.now(),
          notes: _notesControllers[student.studentId]?.text,
        );
      }).toList();

      String dateString =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      AttendanceRecord attendance = AttendanceRecord(
        recordId: _dbService.generateId(prefix: 'attn_'),
        date: _selectedDate,
        dateString: dateString,
        classId: widget.classId,
        className: widget.className,
        records: records,
        markedBy: _teacher!.name,
        teacherId: _teacher!.teacherId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool success = await _dbService.markAttendance(attendance);

      if (success) {
        _showSnackbar('Attendance saved successfully!');
        setState(() {
          _existingAttendance = attendance;
        });
        _calculateAttendanceSummary();
      } else {
        _showSnackbar('Failed to save attendance', isError: true);
      }
    } catch (e) {
      print('Error saving attendance: $e');
      _showSnackbar('Error saving attendance', isError: true);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'excused':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.access_time;
      case 'excused':
        return Icons.beach_access;
      default:
        return Icons.help;
    }
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black87, Colors.black54],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: Colors.white),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.className,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[300],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _selectDate(context),
                icon: Icon(Icons.calendar_today, color: Colors.white),
                tooltip: 'Select Date',
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.date_range, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_existingAttendance != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'SAVED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAttendanceCard(Student student, int index) {
    String currentStatus = _attendanceStatus[student.studentId] ?? 'present';
    Color statusColor = _getStatusColor(currentStatus);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Admission #${student.admissionNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(currentStatus),
                        size: 14,
                        color: statusColor,
                      ),
                      SizedBox(width: 4),
                      Text(
                        currentStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Status Selection
            Text(
              'Mark Status',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['present', 'absent', 'late', 'excused'].map((status) {
                bool isSelected = currentStatus == status;
                Color statusColor = _getStatusColor(status);

                return GestureDetector(
                  onTap: _isPrimaryTeacher
                      ? () {
                          setState(() {
                            _attendanceStatus[student.studentId] = status;
                          });
                          _calculateAttendanceSummary();
                        }
                      : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? statusColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? statusColor : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          size: 14,
                          color: isSelected ? Colors.white : statusColor,
                        ),
                        SizedBox(width: 6),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 16),

            // Notes Field
            Text(
              'Notes (Optional)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: _notesControllers[student.studentId],
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Add any notes here...',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  maxLines: 2,
                  enabled: _isPrimaryTeacher,
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionNotice() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lock, color: Colors.orange[800], size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'View Only Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Only the primary teacher can mark attendance for this class.',
                  style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildDateHeader(),

          if (!_isPrimaryTeacher) _buildPermissionNotice(),
          if (!_isWorkingDay)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This is a ${_workingDayNote ?? "Non-working Day"}. Attendance marking is generally not required.',
                      style: TextStyle(
                        color: Colors.red[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black87,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Loading attendance data...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Summary Cards
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                          children: [
                            _buildSummaryCard(
                              'Present',
                              _attendanceSummary['present'] ?? '0',
                              Colors.green,
                            ),
                            _buildSummaryCard(
                              'Absent',
                              _attendanceSummary['absent'] ?? '0',
                              Colors.red,
                            ),
                            _buildSummaryCard(
                              'Late',
                              _attendanceSummary['late'] ?? '0',
                              Colors.orange,
                            ),
                            _buildSummaryCard(
                              'Total',
                              _attendanceSummary['total'] ?? '0',
                              Colors.black87,
                            ),
                          ],
                        ),
                      ),

                      // Student List Header
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Text(
                              'Student List',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Spacer(),
                            Text(
                              '${_students.length} Students',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 12),

                      // Student List
                      Expanded(
                        child: ListView.builder(
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            return _buildStudentAttendanceCard(
                              _students[index],
                              index,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),

          // Save Button (Only for primary teacher)
          if (_isPrimaryTeacher && !_isLoading)
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  minimumSize: Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _existingAttendance != null
                                ? 'UPDATE ATTENDANCE'
                                : 'SAVE ATTENDANCE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
