import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/attendance_model.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';

class StudentAttendanceReport extends StatefulWidget {
  const StudentAttendanceReport({super.key});

  @override
  _StudentAttendanceReportState createState() =>
      _StudentAttendanceReportState();
}

class _StudentAttendanceReportState extends State<StudentAttendanceReport>
    with TickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  Student? _student;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<AttendanceRecord> _attendanceRecords = [];
  Map<String, int> _attendanceSummary = {
    'present': 0,
    'absent': 0,
    'late': 0,
    'excused': 0,
    'total': 0,
  };
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedFilter = 'month';

  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _loadStudentData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      UserModel? user = await authService.getCurrentUserData();

      if (user != null && user.role == 'student') {
        Student? student;

        if (user.specificId != null && user.specificId!.isNotEmpty) {
          student = await _dbService.getStudentById(user.specificId!);
        }

        if (student == null && user.uid.isNotEmpty) {
          student = await _dbService.getStudentById(user.uid);
        }

        if (student == null && user.authUid != null) {
          student = await _dbService.getStudentByAuthUid(user.authUid!);
        }

        student ??= await _dbService.getStudentByEmail(user.email);

        if (student == null && user.specificId != null) {
          student = await _dbService.getStudentByAdmissionNumber(
            user.specificId!,
          );
        }

        if (student != null) {
          setState(() {
            _student = student;
          });
          await _loadAttendanceData();
        } else {
          _setError('Student profile not found');
        }
      } else {
        _setError('Please login as a student');
      }
    } catch (e) {
      _setError('Error loading data: $e');
    }
  }

  void _setError(String message) {
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _isLoading = false;
    });
  }

  Future<void> _loadAttendanceData() async {
    if (_student == null) return;

    try {
      List<AttendanceRecord> studentRecords = await _dbService
          .getStudentAttendanceSimple(_student!.studentId, _student!.className);

      if (studentRecords.isEmpty) {
        studentRecords = await _dbService.getAttendanceByStudent(
          _student!.studentId,
          _student!.className,
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      studentRecords.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _attendanceRecords = studentRecords;
        _isLoading = false;
        _hasError = false;
      });

      await _calculateSummary();
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      _setError('Error loading attendance: $e');
    }
  }

  Future<void> _calculateSummary() async {
    if (_student == null) return;

    // Get actual working days count for the period
    int workingDaysCount = 0;
    try {
      workingDaysCount = await _dbService.calendarService.getWorkingDaysCount(
        _startDate,
        _endDate,
        _student!.schoolId,
      );
    } catch (e) {
      print('Error getting working days count: $e');
      // Fallback to records length if calculation fails, but ideally we show total possible days
    }

    // If workingDaysCount is 0 (e.g. no calendar), use the number of weekdays in range + records
    // Actually, let's trust the service or fallback to records length if it returns 0 and we have records
    if (workingDaysCount == 0 && _attendanceRecords.isNotEmpty) {
      workingDaysCount = _attendanceRecords.length;
    }

    Map<String, int> summary = {
      'present': 0,
      'absent': 0,
      'late': 0,
      'excused': 0,
      'total': workingDaysCount, // Use calculated working days
    };

    for (var record in _attendanceRecords) {
      if (record.records.isNotEmpty) {
        String status = record.records.first.status;
        if (summary.containsKey(status)) {
          summary[status] = summary[status]! + 1;
        }
      }
    }

    setState(() {
      _attendanceSummary = summary;
    });
  }

  void _changeFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      DateTime now = DateTime.now();

      switch (filter) {
        case 'week':
          _startDate = now.subtract(Duration(days: 7));
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'quarter':
          _startDate = DateTime(now.year, now.month - 3, now.day);
          break;
        case 'year':
          _startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        case 'all':
          _startDate = DateTime(2020, 1, 1);
          break;
      }
      _endDate = now;
      _isLoading = true;
    });

    _fadeController.reset();
    _slideController.reset();
    _loadAttendanceData();
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Attendance',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (_student != null)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              '${_student!.fullName} • ${_student!.className}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[300],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Period',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_attendanceSummary['total']} Days',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceChart() {
    if (_attendanceRecords.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 54, color: Colors.grey[300]),
                SizedBox(height: 16),
                Text(
                  'No attendance data',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    int totalDays = _attendanceSummary['total']!;
    int presentDays = _attendanceSummary['present']!;
    int attendancePercentage = totalDays > 0
        ? (presentDays / totalDays * 100).round()
        : 0;

    Color progressColor = attendancePercentage >= 75
        ? Color(0xFF10b981)
        : attendancePercentage >= 50
        ? Color(0xFFf59e0b)
        : Color(0xFFef4444);

    return FadeTransition(
      opacity: _fadeController,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Attendance Percentage',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: attendancePercentage / 100,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '$attendancePercentage%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: progressColor,
                        ),
                      ),
                      Text(
                        'Present',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                '$presentDays out of $totalDays days',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceRecordCard(AttendanceRecord record, int index) {
    if (record.records.isEmpty) return SizedBox();

    StudentAttendance studentRecord = record.records.first;
    Color statusColor = _getStatusColor(studentRecord.status);
    IconData statusIcon = _getStatusIcon(studentRecord.status);

    return SlideTransition(
      position: Tween<Offset>(begin: Offset(0.3, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _slideController,
          curve: Interval(index * 0.05, 1, curve: Curves.easeOut),
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _slideController,
            curve: Interval(index * 0.05, 1, curve: Curves.easeOut),
          ),
        ),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.2),
                            statusColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('d').format(record.date),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE').format(record.date),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d, yyyy').format(record.date),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          SizedBox(width: 6),
                          Text(
                            studentRecord.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    List<String> filters = ['week', 'month', 'quarter', 'year', 'all'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: filters.map((filter) {
          bool isSelected = _selectedFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                filter.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) => _changeFilter(filter),
              backgroundColor: Colors.white,
              selectedColor: Color(0xFF1a1a2e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isSelected ? Color(0xFF1a1a2e) : Colors.grey[300]!,
                ),
              ),
              elevation: isSelected ? 4 : 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return Color(0xFF10b981);
      case 'absent':
        return Color(0xFFef4444);
      case 'late':
        return Color(0xFFf59e0b);
      case 'excused':
        return Color(0xFF3b82f6);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present':
        return Icons.check_circle_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'late':
        return Icons.access_time_rounded;
      case 'excused':
        return Icons.info_rounded;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterChips(),
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
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF1a1a2e),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Loading attendance data...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.0,
                            children: [
                              _buildSummaryCard(
                                'Present',
                                _attendanceSummary['present'].toString(),
                                Color(0xFF10b981),
                                Icons.check_circle_rounded,
                              ),
                              _buildSummaryCard(
                                'Absent',
                                _attendanceSummary['absent'].toString(),
                                Color(0xFFef4444),
                                Icons.cancel_rounded,
                              ),
                              _buildSummaryCard(
                                'Late',
                                _attendanceSummary['late'].toString(),
                                Color(0xFFf59e0b),
                                Icons.access_time_rounded,
                              ),
                              _buildSummaryCard(
                                'Excused',
                                _attendanceSummary['excused'].toString(),
                                Color(0xFF3b82f6),
                                Icons.info_rounded,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildAttendanceChart(),
                        SizedBox(height: 24),
                        if (_attendanceRecords.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Text(
                                  'Recent Records',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  '${_attendanceRecords.length} records',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(height: 12),
                        if (_attendanceRecords.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'No records found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._attendanceRecords.asMap().entries.map(
                            (e) => _buildAttendanceRecordCard(e.value, e.key),
                          ),
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
