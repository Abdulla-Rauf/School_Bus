import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:school_bus2/models/leave_request_model.dart';
import 'package:school_bus2/models/student_model.dart';
import 'package:school_bus2/models/teacher_model.dart';
import 'package:school_bus2/models/user_model.dart';
import 'package:school_bus2/services/auth_service.dart';
import 'package:school_bus2/services/database_service.dart';

class TeacherLeaveRequestsScreen extends StatefulWidget {
  const TeacherLeaveRequestsScreen({super.key});

  @override
  _TeacherLeaveRequestsScreenState createState() =>
      _TeacherLeaveRequestsScreenState();
}

class _TeacherLeaveRequestsScreenState
    extends State<TeacherLeaveRequestsScreen> {
  final DatabaseService _dbService = DatabaseService();

  // Data
  UserModel? _currentUser;
  Teacher? _teacherDetails;
  List<LeaveRequest> _pendingRequests = [];
  List<LeaveRequest> _approvedRequests = [];
  List<LeaveRequest> _rejectedRequests = [];
  final Map<String, Student> _studentCache = {};

  // UI State
  bool _isLoading = true;
  bool _showPending = true;
  bool _showApproved = false;
  bool _showRejected = false;

  // Filter
  String _filterClass = 'All Classes';
  List<String> _availableClasses = [];
  final String _filterStatus = 'pending';

  // Approve/Reject Dialog
  String _teacherComments = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (user == null || user.role != 'teacher') {
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _currentUser = user);

      // Load teacher details
      final teacher = await _dbService.getTeacherById(
        user.specificId ?? user.uid,
      );
      if (teacher == null) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _teacherDetails = teacher);

      // Get teacher's classes
      _availableClasses = [
        'All Classes',
        teacher.primaryClass,
        ...teacher.secondaryClasses.where((c) => c.isNotEmpty),
      ].where((c) => c.isNotEmpty).toSet().toList();

      // Load leave requests
      await _loadLeaveRequests(teacher);
    } catch (e) {
      print('Error loading leave requests: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLeaveRequests(Teacher teacher) async {
    try {
      // Get all class IDs for this teacher
      List<String> teacherClassIds = [
        teacher.primaryClass,
        ...teacher.secondaryClasses,
      ].where((c) => c.isNotEmpty).toList();

      if (teacherClassIds.isEmpty) {
        print('⚠️ Teacher has no classes assigned');
        return;
      }

      // Load pending requests
      final pendingRequests = await _dbService.getPendingLeaveRequestsByTeacher(
        teacher.teacherId,
        teacherClassIds,
      );

      // Load all requests for each class separately for history
      List<LeaveRequest> allRequests = [];

      // For each class, get all students and their leave requests
      for (var classId in teacherClassIds) {
        final students = await _dbService.getStudentsByClass(classId);

        // Cache students for quick lookup
        for (var student in students) {
          _studentCache[student.studentId] = student;
        }

        // Get leave requests for each student
        for (var student in students) {
          final studentRequests = await _dbService.getLeaveRequestsByStudent(
            student.studentId,
          );
          allRequests.addAll(studentRequests);
        }
      }

      // Remove duplicates and sort
      allRequests = allRequests.toSet().toList()
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

      // Separate by status
      setState(() {
        _pendingRequests = pendingRequests
          ..sort((a, b) => a.fromDate.compareTo(b.fromDate));

        _approvedRequests =
            allRequests.where((req) => req.status == 'approved').toList()
              ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

        _rejectedRequests =
            allRequests.where((req) => req.status == 'rejected').toList()
              ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      });

      print(
        '✅ Loaded ${_pendingRequests.length} pending, ${_approvedRequests.length} approved, ${_rejectedRequests.length} rejected requests',
      );
    } catch (e) {
      print('❌ Error loading leave requests: $e');
    }
  }

  Future<void> _handleRequest(LeaveRequest request, String status) async {
    if (_teacherDetails == null) return;

    final comments = status == 'approved'
        ? 'Leave approved by ${_teacherDetails!.name}'
        : 'Leave rejected by ${_teacherDetails!.name}';

    setState(() => _isSubmitting = true);

    try {
      final success = await _dbService.updateLeaveRequestStatus(
        request.leaveId,
        status,
        _teacherDetails!.teacherId,
        _teacherComments.isNotEmpty ? _teacherComments : comments,
      );

      if (success) {
        // Reload data
        await _loadLeaveRequests(_teacherDetails!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Leave request ${status == 'approved' ? 'approved' : 'rejected'} successfully',
            ),
            backgroundColor: status == 'approved'
                ? Colors.green
                : Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update leave request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
        _teacherComments = '';
      });
      Navigator.pop(context); // Close dialog
    }
  }

  void _showApproveDialog(LeaveRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('Approve Leave Request'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRequestSummary(request),
              SizedBox(height: 16),
              Text('Comments (optional):'),
              SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Add any comments for student...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => _teacherComments = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () => _handleRequest(request, 'approved'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text('APPROVE'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(LeaveRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 12),
            Text('Reject Leave Request'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRequestSummary(request),
              SizedBox(height: 16),
              Text('Reason for rejection:'),
              SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Please provide reason for rejection...',
                  border: OutlineInputBorder(),
                  errorText: _teacherComments.isEmpty
                      ? 'Reason is required'
                      : null,
                ),
                maxLines: 3,
                onChanged: (value) => setState(() => _teacherComments = value),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: (_teacherComments.isEmpty || _isSubmitting)
                ? null
                : () => _handleRequest(request, 'rejected'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text('REJECT'),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSummary(LeaveRequest request) {
    final student = _studentCache[request.studentId];
    final days = request.toDate.difference(request.fromDate).inDays + 1;

    return Container(
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
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue[100],
                child: Icon(Icons.person, color: Colors.blue),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student?.fullName ?? 'Student ${request.studentId}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      student?.className ?? 'Class: N/A',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy').format(request.fromDate),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Icon(Icons.arrow_forward, color: Colors.grey),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'To',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy').format(request.toDate),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          FutureBuilder<int>(
            future: _dbService.calendarService.getWorkingDaysCount(
              request.fromDate,
              request.toDate,
              student?.schoolId ?? '',
            ),
            builder: (context, snapshot) {
              final workingDays = snapshot.data ?? days;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Duration',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '$days days ($workingDays working)',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.blue,
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 12),
          Text(
            'Reason',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(request.reason, style: TextStyle(fontSize: 14)),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              Text(
                'Requested: ${DateFormat('MMM d, h:mm a').format(request.requestedAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;

    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestCard(
    LeaveRequest request, {
    bool showActions = true,
  }) {
    final student = _studentCache[request.studentId];
    final days = request.toDate.difference(request.fromDate).inDays + 1;
    final isPending = request.status == 'pending';

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPending ? Colors.orange[100]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isPending
                      ? Colors.orange[100]
                      : Colors.grey[200],
                  child: Icon(
                    isPending ? Icons.pending_actions : Icons.person,
                    color: isPending ? Colors.orange : Colors.grey[600],
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              student?.fullName ??
                                  'Student ${request.studentId}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          _buildStatusChip(request.status),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${student?.className ?? 'Class: N/A'} • Adm: ${student?.admissionNumber ?? 'N/A'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Dates and Duration
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'START DATE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            DateFormat('EEE, MMM d').format(request.fromDate),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: FutureBuilder<int>(
                          future: _dbService.calendarService
                              .getWorkingDaysCount(
                                request.fromDate,
                                request.toDate,
                                student?.schoolId ?? '',
                              ),
                          builder: (context, snapshot) {
                            final workingDays = snapshot.data ?? days;
                            return Text(
                              '$workingDays working day${workingDays > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.blue[700],
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'END DATE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            DateFormat('EEE, MMM d').format(request.toDate),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Divider(),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey),
                      SizedBox(width: 6),
                      Text(
                        'Requested: ${DateFormat('MMM d, h:mm a').format(request.requestedAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Reason
            Text(
              'Reason for Leave',
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
              child: Text(request.reason, style: TextStyle(fontSize: 14)),
            ),

            if (request.teacherComments != null) ...[
              SizedBox(height: 12),
              Text(
                'Your Comments',
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
                  color: request.status == 'approved'
                      ? Colors.green[50]
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: request.status == 'approved'
                        ? Colors.green[100]!
                        : Colors.red[100]!,
                  ),
                ),
                child: Text(
                  request.teacherComments!,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],

            if (showActions && isPending) ...[
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRejectDialog(request),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'REJECT',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showApproveDialog(request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'APPROVE',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (!isPending && request.handledBy != null) ...[
              SizedBox(height: 12),
              Divider(),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Text(
                    'Processed by ${request.handledBy}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.black87 : Colors.grey[300]!,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterClass,
          icon: Icon(Icons.arrow_drop_down, color: Colors.black87),
          isDense: true,
          style: TextStyle(color: Colors.black87, fontSize: 14),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _filterClass = newValue;
              });
              // TODO: Implement filtering by class
            }
          },
          items: _availableClasses.map<DropdownMenuItem<String>>((
            String value,
          ) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRequests = _showPending
        ? _pendingRequests
        : _showApproved
        ? _approvedRequests
        : _rejectedRequests;

    return Scaffold(
      appBar: AppBar(
        title: Text('Leave Requests'),
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
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading leave requests...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _teacherDetails == null
          ? _buildEmptyState(
              'Teacher profile not found',
              'Please check your account settings',
              Icons.person_off,
            )
          : _availableClasses.length <= 1
          ? _buildEmptyState(
              'No Classes Assigned',
              'You need to be assigned to classes to manage leave requests',
              Icons.class_,
            )
          : Column(
              children: [
                // Tabs
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTabButton(
                        'Pending (${_pendingRequests.length})',
                        _showPending,
                        () => setState(() {
                          _showPending = true;
                          _showApproved = false;
                          _showRejected = false;
                        }),
                      ),
                      SizedBox(width: 12),
                      _buildTabButton(
                        'Approved (${_approvedRequests.length})',
                        _showApproved,
                        () => setState(() {
                          _showPending = false;
                          _showApproved = true;
                          _showRejected = false;
                        }),
                      ),
                      SizedBox(width: 12),
                      _buildTabButton(
                        'Rejected (${_rejectedRequests.length})',
                        _showRejected,
                        () => setState(() {
                          _showPending = false;
                          _showApproved = false;
                          _showRejected = true;
                        }),
                      ),
                    ],
                  ),
                ),

                // Filters
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: _buildFilterDropdown()),
                      SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.filter_list),
                        onPressed: () {
                          // TODO: Implement advanced filtering
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Filter options coming soon'),
                            ),
                          );
                        },
                        tooltip: 'Advanced filters',
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Stats
                if (_showPending && _pendingRequests.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[100]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_pendingRequests.length} Pending Request${_pendingRequests.length > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[800],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Please review and approve/reject these requests',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: 16),

                // List
                Expanded(
                  child: activeRequests.isEmpty
                      ? _buildEmptyState(
                          _showPending
                              ? 'No Pending Requests'
                              : _showApproved
                              ? 'No Approved Requests'
                              : 'No Rejected Requests',
                          _showPending
                              ? 'All leave requests have been processed'
                              : 'No ${_showApproved ? 'approved' : 'rejected'} requests found',
                          _showPending
                              ? Icons.check_circle_outline
                              : Icons.history,
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: Colors.black87,
                          child: ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: activeRequests.length,
                            itemBuilder: (context, index) {
                              return _buildLeaveRequestCard(
                                activeRequests[index],
                                showActions: _showPending,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
