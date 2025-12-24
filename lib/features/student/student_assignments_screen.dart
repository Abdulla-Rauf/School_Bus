// features/student/student_assignments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:school_bus2/models/assignment_model.dart';
import 'package:school_bus2/models/student_assignment_model.dart';
import 'package:school_bus2/models/student_model.dart';
import 'package:school_bus2/services/database_service.dart';
import 'package:school_bus2/services/auth_service.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  _StudentAssignmentsScreenState createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  List<StudentAssignment> _assignments = [];
  List<StudentAssignment> _filteredAssignments = [];
  Student? _student;
  bool _isLoading = true;
  TabController? _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(() {
      setState(() {
        _currentTabIndex = _tabController!.index;
        _filterAssignments();
      });
    });
    _loadAssignments();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (user != null && user.specificId != null) {
        final db = DatabaseService();
        _student = await db.getStudentById(user.specificId!);

        if (_student != null) {
          _assignments = await db.getStudentAssignments(
            _student!.studentId,
            _student!.className,
          );
          _filterAssignments();
        }
      }
    } catch (e) {
      print('Error loading assignments: $e');
      _showErrorSnackbar('Error loading assignments');
    }

    setState(() => _isLoading = false);
  }

  void _filterAssignments() {
    switch (_currentTabIndex) {
      case 0: // All
        _filteredAssignments = List.from(_assignments);
        break;
      case 1: // Upcoming
        _filteredAssignments = _assignments.where((a) => a.isUpcoming).toList();
        break;
      case 2: // Submitted
        _filteredAssignments = _assignments
            .where((a) => a.isSubmitted)
            .toList();
        break;
    }

    // Sort by due date (earliest first)
    _filteredAssignments.sort(
      (a, b) => a.assignment.dueDate.compareTo(b.assignment.dueDate),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildAssignmentCard(StudentAssignment studentAssignment, int index) {
    final assignment = studentAssignment.assignment;
    final isOverdue = studentAssignment.isOverdue;
    final isSubmitted = studentAssignment.isSubmitted;
    final isGroup = studentAssignment.isGroupAssignment;
    final daysUntilDue = assignment.dueDate.difference(DateTime.now()).inDays;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _getAssignmentBorderColor(studentAssignment),
          width: 2,
        ),
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
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getAssignmentIconColor(studentAssignment),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isGroup ? Icons.groups : Icons.person,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        isGroup ? 'Class Assignment' : 'Individual Assignment',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSubmitted)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'SUBMITTED',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else if (isOverdue)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'OVERDUE',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Divider(height: 1, color: Color(0xFFEEEEEE)),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DUE DATE',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy').format(assignment.dueDate),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        DateFormat('hh:mm a').format(assignment.dueDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _getStatusText(studentAssignment),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(studentAssignment),
                        ),
                      ),
                      SizedBox(height: 2),
                      if (daysUntilDue >= 0 && !isSubmitted)
                        Text(
                          daysUntilDue == 0
                              ? 'Due today'
                              : '$daysUntilDue days left',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF757575),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (assignment.description.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  assignment.description,
                  style: TextStyle(fontSize: 13, color: Color(0xFF616161)),
                ),
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                if (studentAssignment.canSubmit) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _submitAssignment(studentAssignment),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.black87, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('Submit'),
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _viewAssignmentDetails(studentAssignment),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      studentAssignment.isSubmitted
                          ? 'View Details'
                          : 'View Assignment',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getAssignmentBorderColor(StudentAssignment sa) {
    if (sa.isSubmitted) return Colors.black87;
    if (sa.isOverdue) return Colors.red;
    if (sa.isUpcoming) return Colors.green;
    return Color(0xFFE0E0E0);
  }

  Color _getAssignmentIconColor(StudentAssignment sa) {
    if (sa.isSubmitted) return Colors.black87;
    if (sa.isOverdue) return Colors.red;
    if (sa.isUpcoming) return Colors.green;
    return Colors.black87;
  }

  String _getStatusText(StudentAssignment sa) {
    if (sa.isSubmitted) return 'Submitted';
    if (sa.isOverdue) return 'Overdue';
    if (sa.isUpcoming) return 'Upcoming';
    return 'Active';
  }

  Color _getStatusColor(StudentAssignment sa) {
    if (sa.isSubmitted) return Colors.black87;
    if (sa.isOverdue) return Colors.red;
    if (sa.isUpcoming) return Colors.green;
    return Colors.black87;
  }

  void _submitAssignment(StudentAssignment studentAssignment) {
    showDialog(
      context: context,
      builder: (context) => AssignmentSubmissionDialog(
        assignment: studentAssignment.assignment,
        onSubmitted: () async {
          // In a real app, you would upload files and submit to backend
          _showErrorSnackbar('Submission feature coming soon!');
          await _loadAssignments();
        },
      ),
    );
  }

  void _viewAssignmentDetails(StudentAssignment studentAssignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssignmentDetailsSheet(
        studentAssignment: studentAssignment,
        student: _student,
      ),
    );
  }

  Widget _buildHeaderCard() {
    final upcomingCount = _assignments.where((a) => a.isUpcoming).length;
    final submittedCount = _assignments.where((a) => a.isSubmitted).length;
    final overdueCount = _assignments.where((a) => a.isOverdue).length;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black87, Colors.black54],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MY ASSIGNMENTS',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${_assignments.length} Assignments',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.8,
              ),
            ),
            SizedBox(height: 16),
            Container(height: 1, color: Colors.white.withOpacity(0.1)),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UPCOMING',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$upcomingCount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'SUBMITTED',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$submittedCount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'OVERDUE',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$overdueCount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE0E0E0)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black87,
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          Tab(text: 'All (${_assignments.length})'),
          Tab(
            text:
                'Upcoming (${_assignments.where((a) => a.isUpcoming).length})',
          ),
          Tab(
            text:
                'Submitted (${_assignments.where((a) => a.isSubmitted).length})',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = '';
    String subtitle = '';

    switch (_currentTabIndex) {
      case 0:
        message = 'No Assignments';
        subtitle = 'You don\'t have any assignments yet';
        break;
      case 1:
        message = 'No Upcoming Assignments';
        subtitle = 'All assignments are submitted or overdue';
        break;
      case 2:
        message = 'No Submitted Assignments';
        subtitle = 'Submit your assignments to see them here';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.black38),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadAssignments,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Refresh',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'My Assignments',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black87),
            onPressed: _isLoading ? null : _loadAssignments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading your assignments...',
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
                SizedBox(height: 8),
                _buildHeaderCard(),
                SizedBox(height: 16),
                _buildTabBar(),
                SizedBox(height: 16),
                Expanded(
                  child: _filteredAssignments.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadAssignments,
                          color: Colors.black87,
                          backgroundColor: Colors.white,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            itemCount: _filteredAssignments.length,
                            itemBuilder: (context, index) {
                              return _buildAssignmentCard(
                                _filteredAssignments[index],
                                index,
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

class AssignmentSubmissionDialog extends StatefulWidget {
  final Assignment assignment;
  final VoidCallback onSubmitted;

  const AssignmentSubmissionDialog({
    super.key,
    required this.assignment,
    required this.onSubmitted,
  });

  @override
  _AssignmentSubmissionDialogState createState() =>
      _AssignmentSubmissionDialogState();
}

class _AssignmentSubmissionDialogState
    extends State<AssignmentSubmissionDialog> {
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.upload, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Submit Assignment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              widget.assignment.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Due: ${DateFormat('dd MMM yyyy, hh:mm a').format(widget.assignment.dueDate)}',
              style: TextStyle(fontSize: 13, color: Color(0xFF757575)),
            ),
            SizedBox(height: 24),

            // File Upload Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Color(0xFFE0E0E0), width: 2),
                borderRadius: BorderRadius.circular(10),
                color: Color(0xFFF5F5F5),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload, size: 40, color: Colors.black87),
                  SizedBox(height: 12),
                  Text(
                    'Click to upload files',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'PDF, Word, Excel, Images (Max 10MB)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
                  ),
                  SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      // TODO: Implement file picker
                      _showErrorSnackbar('File upload coming soon!');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.black87),
                    ),
                    child: Text('Browse Files'),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Notes Section
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.black87, width: 2),
                ),
              ),
              maxLines: 3,
            ),

            SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.black87),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Cancel'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() => _isSubmitting = true);
                            Future.delayed(Duration(seconds: 2), () {
                              Navigator.pop(context);
                              widget.onSubmitted();
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text('Submit Assignment'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class AssignmentDetailsSheet extends StatelessWidget {
  final StudentAssignment studentAssignment;
  final Student? student;

  const AssignmentDetailsSheet({
    super.key,
    required this.studentAssignment,
    this.student,
  });

  @override
  Widget build(BuildContext context) {
    final assignment = studentAssignment.assignment;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: studentAssignment.isGroupAssignment
                        ? Colors.black87
                        : Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    studentAssignment.isGroupAssignment
                        ? Icons.groups
                        : Icons.person,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        studentAssignment.isGroupAssignment
                            ? 'Class Assignment'
                            : 'Individual Assignment',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(studentAssignment).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(studentAssignment),
                    ),
                  ),
                  child: Text(
                    _getStatusText(studentAssignment).toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(studentAssignment),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Details Grid
                _buildDetailRow(
                  'Class',
                  student?.className ?? assignment.classId,
                ),
                _buildDetailRow('Assigned By', 'Teacher'),
                _buildDetailRow(
                  'Due Date',
                  DateFormat('dd MMM yyyy').format(assignment.dueDate),
                ),
                _buildDetailRow(
                  'Due Time',
                  DateFormat('hh:mm a').format(assignment.dueDate),
                ),

                if (assignment.description.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      assignment.description,
                      style: TextStyle(fontSize: 14, color: Color(0xFF616161)),
                    ),
                  ),
                ],

                if (studentAssignment.isSubmitted) ...[
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 16),
                  Text(
                    'Submission Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildDetailRow(
                    'Submitted On',
                    studentAssignment.submittedAt != null
                        ? DateFormat(
                            'dd MMM yyyy, hh:mm a',
                          ).format(studentAssignment.submittedAt!)
                        : 'N/A',
                  ),
                  if (studentAssignment.grade != null)
                    _buildDetailRow('Grade', studentAssignment.grade!),
                  if (studentAssignment.teacherFeedback != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'Teacher Feedback',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      studentAssignment.teacherFeedback!,
                      style: TextStyle(fontSize: 13, color: Color(0xFF616161)),
                    ),
                  ],
                ],
              ],
            ),
          ),
          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(StudentAssignment sa) {
    if (sa.isSubmitted) return 'Submitted';
    if (sa.isOverdue) return 'Overdue';
    if (sa.isUpcoming) return 'Upcoming';
    return 'Active';
  }

  Color _getStatusColor(StudentAssignment sa) {
    if (sa.isSubmitted) return Colors.black87;
    if (sa.isOverdue) return Colors.red;
    if (sa.isUpcoming) return Colors.green;
    return Colors.black87;
  }
}
