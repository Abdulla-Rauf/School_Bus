import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:school_bus2/models/leave_request_model.dart';
import 'package:school_bus2/services/auth_service.dart';
import 'package:school_bus2/services/database_service.dart';
import 'package:school_bus2/models/user_model.dart';
import 'package:school_bus2/models/student_model.dart';

class StudentLeaveRequestScreen extends StatefulWidget {
  const StudentLeaveRequestScreen({super.key});

  @override
  _StudentLeaveRequestScreenState createState() =>
      _StudentLeaveRequestScreenState();
}

class _StudentLeaveRequestScreenState extends State<StudentLeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  // Form fields
  DateTime? _fromDate;
  DateTime? _toDate;
  String _reason = '';
  String _reasonType = 'illness'; // Default reason type
  String _additionalDetails = '';
  bool _isSubmitting = false;
  bool _showHistory = false;

  // User data
  UserModel? _currentUser;
  Student? _studentDetails;

  // Reason types with icons and descriptions
  final List<Map<String, dynamic>> _reasonTypes = [
    {
      'id': 'illness',
      'title': 'Illness',
      'description': 'Medical appointment or sickness',
      'icon': Icons.medical_services,
      'color': Colors.red,
      'examples': [
        'Fever',
        'Flu/Cold',
        'Doctor appointment',
        'Hospital visit',
        'Medical emergency',
      ],
    },
    {
      'id': 'family',
      'title': 'Family',
      'description': 'Family event or emergency',
      'icon': Icons.family_restroom,
      'color': Colors.blue,
      'examples': [
        'Family function',
        'Family emergency',
        'Marriage in family',
        'Relative visiting',
        'Parent-teacher meeting',
      ],
    },
    {
      'id': 'personal',
      'title': 'Personal',
      'description': 'Personal reasons',
      'icon': Icons.person,
      'color': Colors.purple,
      'examples': [
        'Personal appointment',
        'Mental health day',
        'Personal emergency',
        'Religious observance',
        'Exam preparation',
      ],
    },
    {
      'id': 'travel',
      'title': 'Travel',
      'description': 'Out of town travel',
      'icon': Icons.flight_takeoff,
      'color': Colors.green,
      'examples': [
        'Family vacation',
        'Outstation trip',
        'Going to hometown',
        'International travel',
        'Long weekend trip',
      ],
    },
    {
      'id': 'other',
      'title': 'Other',
      'description': 'Other valid reasons',
      'icon': Icons.more_horiz,
      'color': Colors.grey,
      'examples': [
        'Sports competition',
        'Cultural event',
        'Educational trip',
        'Community service',
        'Other valid reason',
      ],
    },
  ];

  // Pre-defined common reasons
  final List<Map<String, dynamic>> _commonReasons = [
    {
      'text': 'Fever and cold symptoms',
      'type': 'illness',
      'days': '1-2',
      'requires_doctor': true,
    },
    {
      'text': 'Family function/marriage',
      'type': 'family',
      'days': '1-3',
      'requires_doctor': false,
    },
    {
      'text': 'Medical appointment',
      'type': 'illness',
      'days': '1',
      'requires_doctor': true,
    },
    {
      'text': 'Family emergency',
      'type': 'family',
      'days': '1-2',
      'requires_doctor': false,
    },
    {
      'text': 'Out of town travel',
      'type': 'travel',
      'days': '2-5',
      'requires_doctor': false,
    },
    {
      'text': 'Personal reasons',
      'type': 'personal',
      'days': '1',
      'requires_doctor': false,
    },
    {
      'text': 'Sports competition',
      'type': 'other',
      'days': '1-2',
      'requires_doctor': false,
    },
    {
      'text': 'Cultural event participation',
      'type': 'other',
      'days': '1',
      'requires_doctor': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      UserModel? user = await authService.getCurrentUserData();

      if (user != null && user.role == 'student') {
        setState(() {
          _currentUser = user;
        });

        // Load student details
        Student? student;
        if (user.specificId != null && user.specificId!.isNotEmpty) {
          student = await _dbService.getStudentById(user.specificId!);
        }

        if (student == null && user.uid.isNotEmpty) {
          student = await _dbService.getStudentById(user.uid);
        }

        setState(() {
          _studentDetails = student;
        });
      }
    } catch (e) {
      print('Error loading student data: $e');
    }
  }

  Future<void> _selectFromDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.black87,
            colorScheme: ColorScheme.light(primary: Colors.black87),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) {
          _toDate = null;
        }
      });
    }
  }

  Future<void> _selectToDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.black87,
            colorScheme: ColorScheme.light(primary: Colors.black87),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _toDate = picked;
      });
    }
  }

  int _calculateDays() {
    if (_fromDate == null || _toDate == null) return 0;
    return _toDate!.difference(_fromDate!).inDays + 1;
  }

  Future<int> _calculateWorkingDays() async {
    if (_fromDate == null || _toDate == null || _studentDetails == null) {
      return 0;
    }
    try {
      return await _dbService.calendarService.getWorkingDaysCount(
        _fromDate!,
        _toDate!,
        _studentDetails!.schoolId,
      );
    } catch (e) {
      return _calculateDays();
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentUser == null || _studentDetails == null) {
      _showError('Please login as a student to submit leave request');
      return;
    }

    if (_fromDate == null || _toDate == null) {
      _showError('Please select both from and to dates');
      return;
    }

    // Validate date range (max 30 days)
    final days = _calculateDays();
    if (days > 30) {
      _showError('Leave cannot be requested for more than 30 days at once');
      return;
    }

    // Check if from date is not in the past
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_fromDate!.isBefore(today)) {
      _showError('Leave cannot be requested for past dates');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Create leave request
      final leaveRequest = LeaveRequest(
        leaveId: _dbService.generateId(prefix: 'leave_'),
        studentId: _studentDetails!.studentId,
        fromDate: _fromDate!,
        toDate: _toDate!,
        reason:
            '${_getReasonTypeTitle()}: $_reason${_additionalDetails.isNotEmpty ? '\n\nAdditional Details:\n$_additionalDetails' : ''}',
        status: 'pending',
        requestedAt: DateTime.now(),
      );

      // Save to database
      final success = await _dbService.createLeaveRequest(leaveRequest);

      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        _showSuccess('Leave request submitted successfully!');
        _resetForm();
      } else {
        _showError('Failed to submit leave request. Please try again.');
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showError('Error submitting leave request: $e');
    }
  }

  void _resetForm() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _reason = '';
      _additionalDetails = '';
      _reasonType = 'illness';
    });
    _formKey.currentState?.reset();
  }

  String _getReasonTypeTitle() {
    final type = _reasonTypes.firstWhere(
      (type) => type['id'] == _reasonType,
      orElse: () => _reasonTypes.first,
    );
    return type['title'];
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _useCommonReason(Map<String, dynamic> reason) {
    setState(() {
      _reasonType = reason['type'];
      _reason = reason['text'];
    });
  }

  Widget _buildDateField(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  label.toLowerCase().contains('from')
                      ? Icons.calendar_today
                      : Icons.calendar_today_outlined,
                  color: Colors.black54,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('EEE, MMM d, yyyy').format(date)
                        : 'Select $label',
                    style: TextStyle(
                      fontSize: 16,
                      color: date != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
        if (_fromDate != null && _toDate != null && label.contains('To'))
          FutureBuilder<int>(
            future: _calculateWorkingDays(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final calendarDays = _calculateDays();
                final workingDays = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.blue),
                      SizedBox(width: 6),
                      Text(
                        'Total Duration: $calendarDays days ($workingDays working days)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Widget _buildReasonTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reason Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _reasonTypes.map((type) {
            final isSelected = _reasonType == type['id'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _reasonType = type['id'];
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? type['color'].withOpacity(0.1)
                      : Colors.grey[50],
                  border: Border.all(
                    color: isSelected ? type['color'] : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type['icon'], color: type['color'], size: 20),
                    SizedBox(width: 8),
                    Text(
                      type['title'],
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? type['color'] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExamplesSection() {
    final currentType = _reasonTypes.firstWhere(
      (type) => type['id'] == _reasonType,
      orElse: () => _reasonTypes.first,
    );

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: currentType['color'].withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: currentType['color'].withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: currentType['color'],
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Examples for ${currentType['title']}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: currentType['color'],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...currentType['examples']
              .map<Widget>(
                (example) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_right,
                        size: 16,
                        color: currentType['color'],
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          example,
                          style: TextStyle(color: Colors.black87, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildCommonReasons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Common Reasons',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _commonReasons.map((reason) {
            return GestureDetector(
              onTap: () => _useCommonReason(reason),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _reasonTypes
                                .firstWhere(
                                  (t) => t['id'] == reason['type'],
                                )['color']
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            reason['type'].toString().toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _reasonTypes.firstWhere(
                                (t) => t['id'] == reason['type'],
                              )['color'],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${reason['days']} day(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      reason['text'],
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    if (reason['requires_doctor'] == true) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.medical_services,
                            size: 12,
                            color: Colors.red,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Doctor certificate required',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLeaveHistory() {
    return FutureBuilder<List<LeaveRequest>>(
      future: _studentDetails != null
          ? _dbService.getLeaveRequestsByStudent(_studentDetails!.studentId)
          : Future.value([]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final leaveRequests = snapshot.data ?? [];

        if (leaveRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  'No leave history',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: leaveRequests.length,
          separatorBuilder: (context, index) => Divider(height: 1),
          itemBuilder: (context, index) {
            final request = leaveRequests[index];
            final days = request.toDate.difference(request.fromDate).inDays + 1;

            Color statusColor;
            IconData statusIcon;
            switch (request.status) {
              case 'approved':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                break;
              case 'rejected':
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
                break;
              default:
                statusColor = Colors.orange;
                statusIcon = Icons.pending;
            }

            return ListTile(
              contentPadding: EdgeInsets.symmetric(vertical: 8),
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Icon(statusIcon, color: statusColor),
              ),
              title: Text(
                '${DateFormat('MMM d').format(request.fromDate)} - ${DateFormat('MMM d, yyyy').format(request.toDate)}',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  Text(
                    '$days day${days > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 4),
                  Text(
                    request.reason.split(':').first,
                    style: TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: Chip(
                label: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: statusColor,
                side: BorderSide.none,
              ),
              onTap: () {
                _showLeaveDetails(request);
              },
            );
          },
        );
      },
    );
  }

  void _showLeaveDetails(LeaveRequest request) {
    final days = request.toDate.difference(request.fromDate).inDays + 1;

    Color statusColor;
    switch (request.status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text('Leave Request Details'),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                request.status.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dates
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FROM',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          DateFormat(
                            'EEE, MMM d, yyyy',
                          ).format(request.fromDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward, color: Colors.grey),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'TO',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          DateFormat('EEE, MMM d, yyyy').format(request.toDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Duration
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Duration',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$days day${days > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Reason
              Text(
                'Reason',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(request.reason),
              ),

              if (request.teacherComments != null) ...[
                SizedBox(height: 16),
                Text(
                  'Teacher Comments',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Text(request.teacherComments!),
                ),
              ],

              SizedBox(height: 16),

              // Timeline
              Text(
                'Timeline',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('Requested on '),
                  Text(
                    DateFormat('MMM d, yyyy').format(request.requestedAt),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showHistory ? 'Leave History' : 'Request Leave'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        actions: [
          IconButton(
            icon: Icon(_showHistory ? Icons.add : Icons.history),
            onPressed: () {
              setState(() {
                _showHistory = !_showHistory;
              });
            },
            tooltip: _showHistory ? 'New Request' : 'View History',
          ),
        ],
      ),
      body: _showHistory
          ? Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Leave History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Track all your previous leave requests',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  SizedBox(height: 24),
                  Expanded(child: _buildLeaveHistory()),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Request Leave',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Submit a formal request for absence from school',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 32),

                    // Student Info
                    if (_studentDetails != null)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.school, color: Colors.black54),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_studentDetails!.firstName} ${_studentDetails!.lastName ?? ''}'
                                        .trim(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Class: ${_studentDetails!.className} | Admission: ${_studentDetails!.admissionNumber}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 24),

                    // Date Selection
                    Text(
                      'Select Dates',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From Date',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              _buildDateField(
                                'From',
                                _fromDate,
                                _selectFromDate,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'To Date',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              _buildDateField('To', _toDate, _selectToDate),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_fromDate != null && _toDate != null) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${_calculateDays()} day${_calculateDays() > 1 ? 's' : ''} leave requested',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 32),

                    // Reason Type
                    _buildReasonTypeSelector(),
                    SizedBox(height: 20),

                    // Examples
                    _buildExamplesSection(),
                    SizedBox(height: 24),

                    // Common Reasons
                    _buildCommonReasons(),
                    SizedBox(height: 24),

                    // Reason Details
                    Text(
                      'Reason Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Brief reason for leave',
                        hintText:
                            'E.g., Attending family wedding in another city',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a reason for leave';
                        }
                        if (value.length < 10) {
                          return 'Please provide more details (at least 10 characters)';
                        }
                        return null;
                      },
                      onChanged: (value) => setState(() => _reason = value),
                    ),

                    SizedBox(height: 20),

                    // Additional Details
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Additional details (optional)',
                        hintText:
                            'Any additional information for the teacher...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note_add),
                      ),
                      maxLines: 4,
                      onChanged: (value) =>
                          setState(() => _additionalDetails = value),
                    ),

                    SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitLeaveRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send, size: 20),
                                  SizedBox(width: 12),
                                  Text(
                                    'SUBMIT LEAVE REQUEST',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Guidelines
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.black54),
                              SizedBox(width: 8),
                              Text(
                                'Important Guidelines',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          ...[
                            'Submit requests at least 2 days in advance for planned absences',
                            'Emergency requests will be reviewed on a case-by-case basis',
                            'Medical leave of more than 3 days requires a doctor\'s certificate',
                            'Multiple consecutive leaves may require parent meeting',
                            'Check leave history for approval status updates',
                          ].map(
                            (guideline) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.arrow_right,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      guideline,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
