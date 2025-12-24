import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:school_bus2/features/student/report_card_screen.dart';
import 'package:school_bus2/features/student/student_assignments_screen.dart';
import 'package:school_bus2/features/student/student_attendance_report.dart';
import 'package:school_bus2/features/student/student_leave_request_screen.dart';
import '../../models/assignment_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../models/student_model.dart';
import '../../core/widgets/auth_wrapper.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  UserModel? _currentUser;
  Student? _studentDetails;
  bool _isLoading = true;
  bool _showDetails = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final String _mapboxAccessToken =
      'pk.eyJ1IjoiYWJkdWxsYS1yYXVmLXBwIiwiYSI6ImNtajVpNXM2dzFibjgzcXI1ZnlubXJmaGIifQ.EOvDjx2LtzwyuPklnz4R1w';

  @override
  void initState() {
    super.initState();
    mapbox.MapboxOptions.setAccessToken(_mapboxAccessToken);

    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _loadStudentData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      bool loggedIn = await authService.isLoggedIn();
      if (!loggedIn) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      UserModel? user = await authService.getCurrentUserData();
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (user.role != 'student') {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      DatabaseService dbService = DatabaseService();
      Student? student;

      if (user.specificId != null && user.specificId!.isNotEmpty) {
        student = await dbService.getStudentById(user.specificId!);
      }

      if (student == null && user.uid.isNotEmpty) {
        student = await dbService.getStudentById(user.uid);
      }

      student ??= await dbService.getStudentByAuthUid(user.uid);

      student ??= await dbService.getStudentByEmail(user.email);

      if (student == null && user.specificId != null) {
        student = await dbService.getStudentByAdmissionNumber(user.specificId!);
      }

      setState(() {
        _currentUser = user;
        _studentDetails = student;
        _isLoading = false;
      });

      if (student == null) {
        _showErrorSnackbar('Student profile not found');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Error loading student data');
    }
  }

  // Add this method to _StudentDashboardState
  Future<List<Assignment>> _getStudentAssignments() async {
    try {
      if (_studentDetails == null) return [];

      DatabaseService dbService = DatabaseService();
      return await dbService.getAssignmentsByClass(_studentDetails!.className);
    } catch (e) {
      print('Error getting assignments: $e');
      return [];
    }
  }

  void _showErrorSnackbar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  void _toggleDetails() {
    if (_showDetails) {
      _animationController.reverse();
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _showDetails = false;
          });
        }
      });
    } else {
      setState(() {
        _showDetails = true;
      });
      _animationController.forward();
    }
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.black87, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  value.isNotEmpty ? value : 'Not provided',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard() {
    final fullName =
        (_studentDetails?.firstName ?? '') +
        (_studentDetails?.lastName != null
            ? ' ${_studentDetails!.lastName}'
            : '');
    final admissionNum =
        _studentDetails?.admissionNumber ?? _currentUser?.specificId ?? 'N/A';
    final className = _studentDetails?.className ?? 'Not assigned';
    final photoUrl = _studentDetails?.photoUrl;

    return GestureDetector(
      onTap: _toggleDetails,
      child: Container(
        width: double.infinity,
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
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back! 👋',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            fullName.isNotEmpty ? fullName : 'Student',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.8,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Spacer(),
                      if (photoUrl != null)
                        CircleAvatar(
                          radius: 44,
                          backgroundImage: NetworkImage(photoUrl),
                          backgroundColor: Colors.grey[300],
                        )
                      else
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[700],
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Container(height: 1.5, color: Colors.white.withOpacity(0.1)),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ADMISSION #',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            admissionNum,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'CLASS',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            className,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(),
                      Row(
                        children: [
                          Text(
                            'View all details',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[300],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.grey[300],
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String title,
    String subtitle, {
    Color? bgColor,
  }) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeView() {
    return FutureBuilder<List<Assignment>>(
      future: _getStudentAssignments(),
      builder: (context, snapshot) {
        List<Assignment> assignments = snapshot.data ?? [];
        List<Assignment> upcomingAssignments =
            assignments
                .where(
                  (assignment) => assignment.dueDate.isAfter(DateTime.now()),
                )
                .toList()
              ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickCard(),
                SizedBox(height: 40),

                // Quick Access
                Text(
                  'Quick Access',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentAssignmentsScreen(),
                          ),
                        );
                      },
                      child: _buildActionCard(
                        Icons.assignment,
                        'Assignments',
                        'View tasks',
                      ),
                    ),
                    // In student_dashboard.dart, update the Attendance card in the GridView:
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentAttendanceReport(),
                          ),
                        );
                      },
                      child: _buildActionCard(
                        Icons.calendar_today,
                        'Attendance',
                        'View report',
                        bgColor: Colors.grey[50],
                      ),
                    ),
                    _buildActionCard(
                      Icons.directions_bus,
                      'Transport',
                      'Bus routes',
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ReportCardScreen()),
                        );
                      },
                      child: _buildActionCard(
                        Icons.grade,
                        'Grades',
                        'Your marks',
                        bgColor: Colors.grey[50],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentLeaveRequestScreen(),
                          ),
                        );
                      },
                      child: _buildActionCard(
                        Icons.report_gmailerrorred_rounded,
                        'Leaves',
                        'Your Leave Report',
                        bgColor: Colors.grey[50],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 32),

                // Upcoming Assignments
                Text(
                  'Upcoming Assignments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 16),

                if (upcomingAssignments.isEmpty)
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No upcoming assignments',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                else
                  ...upcomingAssignments
                      .take(3)
                      .map((assignment) => _buildAssignmentCard(assignment)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.assignment, color: Colors.blue),
        ),
        title: Text(
          assignment.title,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              'Due: ${DateFormat('MMM d, yyyy').format(assignment.dueDate)}',
            ),
            if (assignment.description.isNotEmpty)
              Text(
                assignment.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Widget _buildDetailView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileSection(),
                _buildSection('Personal Information', [
                  _buildInfoCard(
                    'Full Name',
                    '${_studentDetails?.firstName ?? ''} ${_studentDetails?.lastName ?? ''}'
                        .trim(),
                    Icons.person,
                  ),
                  _buildInfoCard(
                    'Admission Number',
                    _studentDetails?.admissionNumber ?? 'N/A',
                    Icons.confirmation_number,
                  ),
                  _buildInfoCard(
                    'Email',
                    _studentDetails?.email ?? 'N/A',
                    Icons.email,
                  ),
                  _buildInfoCard(
                    'Class',
                    _studentDetails?.className ?? 'N/A',
                    Icons.class_,
                  ),
                  _buildInfoCard(
                    'Date of Birth',
                    _studentDetails?.dateOfBirth != null
                        ? '${_studentDetails!.dateOfBirth.day}/${_studentDetails!.dateOfBirth.month}/${_studentDetails!.dateOfBirth.year}'
                        : 'N/A',
                    Icons.cake,
                  ),
                  _buildInfoCard(
                    'Blood Group',
                    _studentDetails?.bloodGroup ?? 'N/A',
                    Icons.bloodtype,
                  ),
                ]),
                _buildSection('Contact Information', [
                  _buildInfoCard(
                    'Primary Phone',
                    _studentDetails?.primaryPhone ?? 'N/A',
                    Icons.phone,
                  ),
                  _buildInfoCard(
                    'Secondary Phone',
                    _studentDetails?.secondaryPhone ?? 'N/A',
                    Icons.phone_iphone,
                  ),
                  _buildInfoCard(
                    'Address',
                    _studentDetails?.address ?? 'N/A',
                    Icons.location_on,
                  ),
                ]),
                _buildSection('Parents & Guardians', [
                  _buildInfoCard(
                    "Father's Name",
                    _studentDetails?.fatherName ?? 'N/A',
                    Icons.person_outline,
                  ),
                  _buildInfoCard(
                    "Mother's Name",
                    _studentDetails?.motherName ?? 'N/A',
                    Icons.person_outline,
                  ),
                  if (_studentDetails?.guardianName.isNotEmpty ?? false)
                    _buildInfoCard(
                      "Guardian's Name",
                      _studentDetails!.guardianName,
                      Icons.person_outline,
                    ),
                ]),
                _buildMapSection(),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    if (_studentDetails?.latitude == null ||
        _studentDetails?.longitude == null) {
      return const SizedBox.shrink();
    }

    return _buildSection('Home Location', [
      SizedBox(
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: mapbox.MapWidget(
            key: ValueKey("dashboard_map_${_studentDetails?.studentId}"),

            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(
                coordinates: mapbox.Position(
                  _studentDetails!.longitude!,
                  _studentDetails!.latitude!,
                ),
              ),
              zoom: 13.0,
            ),
            onMapCreated: (mapbox.MapboxMap mapboxMap) {
              mapboxMap.annotations.createCircleAnnotationManager().then((
                manager,
              ) {
                var options = mapbox.CircleAnnotationOptions(
                  geometry: mapbox.Point(
                    coordinates: mapbox.Position(
                      _studentDetails!.longitude!,
                      _studentDetails!.latitude!,
                    ),
                  ),
                  circleColor: Colors.red.value,
                  circleRadius: 8.0,
                  circleStrokeColor: Colors.white.value,
                  circleStrokeWidth: 2.0,
                );
                manager.create(options);
              });
            },
          ),
        ),
      ),
    ]);
  }

  Widget _buildProfileSection() {
    final fullName =
        (_studentDetails?.firstName ?? '') +
        (_studentDetails?.lastName != null
            ? ' ${_studentDetails!.lastName}'
            : '');
    final photoUrl = _studentDetails?.photoUrl;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        children: [
          if (photoUrl != null)
            CircleAvatar(
              radius: 52,
              backgroundImage: NetworkImage(photoUrl),
              backgroundColor: Colors.grey[300],
            )
          else
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black87,
              ),
              child: Icon(Icons.person, color: Colors.white, size: 56),
            ),
          SizedBox(height: 20),
          Text(
            fullName.isNotEmpty ? fullName : 'Student',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            _studentDetails?.admissionNumber ?? 'N/A',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            _studentDetails?.className ?? 'Not assigned',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showDetails ? 'Profile Details' : 'Dashboard'),
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
          if (_showDetails)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleDetails,
              tooltip: 'Close',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() {
                      _isLoading = true;
                    });
                    await _loadStudentData();
                  },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = Provider.of<AuthService>(
                context,
                listen: false,
              );
              await authService.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
                (route) => false,
              );
            },
            tooltip: 'Logout',
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
                    'Loading your profile...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _currentUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.black38),
                  SizedBox(height: 16),
                  Text(
                    'Not authenticated',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please log in to continue',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _loadStudentData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _studentDetails == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.black38),
                  SizedBox(height: 16),
                  Text(
                    'Student profile not found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Contact administrator for assistance',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _loadStudentData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _showDetails
          ? _buildDetailView()
          : _buildHomeView(),
    );
  }
}
