import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:school_bus2/features/teacher/grade_selection_screen.dart';
import 'package:school_bus2/features/teacher/teacher_leave_requests_screen.dart';
import '../../core/widgets/auth_wrapper.dart';

import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../models/teacher_model.dart';
import '../../models/student_model.dart';
import '../../models/calendar_model.dart';
import 'assignment_selection_screen.dart';
import 'widgets/quick_info_card.dart';
import 'widgets/upcoming_events_section.dart';
import 'widgets/action_grid_cards.dart';
import 'widgets/teacher_profile_details.dart';
import '../student/attendance_screen.dart';
import '../school/schoolCalender/Calender/calendar_screen.dart';
import 'student_list_view.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with SingleTickerProviderStateMixin {
  UserModel? _currentUser;
  Teacher? _teacherDetails;
  List<Student> _primaryStudents = [];
  List<Student> _secondaryStudents = [];
  List<CalendarEvent> _upcomingEvents = [];
  bool _isLoading = true;
  int _currentTab = 0;
  bool _showDetails = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
  }

  void _setupAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = await auth.getCurrentUserData();
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final db = DatabaseService();
      final teacher = await db.getTeacherById(user.specificId ?? user.uid);

      if (teacher == null) {
        setState(() => _isLoading = false);
        return;
      }

      String schoolId = teacher.schoolId.isNotEmpty
          ? teacher.schoolId
          : user.uid;
      print('🎯 Using School ID for teacher: $schoolId');
      print(
        '👨‍🫖 Teacher classes: Primary: ${teacher.primaryClass}, Secondary: ${teacher.secondaryClasses}',
      );

      List<Student> primary = [], secondary = [];
      List<CalendarEvent> events = [];

      if (teacher.primaryClass.isNotEmpty) {
        primary = await db.getStudentsByClass(teacher.primaryClass);
      }
      for (var cls in teacher.secondaryClasses.where((c) => c.isNotEmpty)) {
        final students = await db.getStudentsByClass(cls);
        secondary.addAll(students);
      }
      secondary = secondary.toSet().toList();

      final calendar = await db.getSchoolCalendar(schoolId);
      if (calendar != null) {
        print('📅 Calendar found with ${calendar.events.length} total events');

        final teacherClasses = [
          teacher.primaryClass,
          ...teacher.secondaryClasses,
        ].where((c) => c.isNotEmpty).toList();

        print('🔍 Filtering events for classes: $teacherClasses');

        events = calendar.events.where((event) {
          if (event.isForAllClasses) return true;
          return event.affectedClasses.any(
            (affectedClass) => teacherClasses.contains(affectedClass),
          );
        }).toList();

        print('✅ Found ${events.length} events for teacher');

        final now = DateTime.now();
        events = events.where((e) => e.endDate.isAfter(now)).toList();
        events.sort((a, b) => a.startDate.compareTo(b.startDate));

        print('📅 ${events.length} upcoming events');
      } else {
        print('⚠️ No calendar found for school ID: $schoolId');
      }

      setState(() {
        _currentUser = user;
        _teacherDetails = teacher;
        _primaryStudents = primary;
        _secondaryStudents = secondary;
        _upcomingEvents = events;
        _isLoading = false;
      });

      _animController.forward();
    } catch (e) {
      print('❌ Error loading teacher dashboard: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading data: $e")));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    HapticFeedback.mediumImpact();
    await _loadData();
  }

  void _toggleDetails() {
    if (_showDetails) {
      _animController.reverse().then(
        (_) => setState(() => _showDetails = false),
      );
    } else {
      setState(() => _showDetails = true);
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _showDetails
              ? 'Profile'
              : _currentTab == 0
              ? 'Dashboard'
              : 'Students',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        actions: [
          if (_showDetails || _currentTab != 0)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black87),
              onPressed: _showDetails
                  ? _toggleDetails
                  : () => setState(() => _currentTab = 0),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _isLoading ? null : _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              Provider.of<AuthService>(context, listen: false).signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
                (route) => false,
              );
            },
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
                  const SizedBox(height: 16),
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _currentUser == null
          ? const Center(child: Text("Not authenticated"))
          : _teacherDetails == null
          ? const Center(child: Text("Teacher profile not found"))
          : _showDetails
          ? FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: TeacherProfileDetails(teacher: _teacherDetails!),
              ),
            )
          : _currentTab == 1
          ? StudentListView(
              primaryClass: _teacherDetails!.primaryClass,
              secondaryClasses: _teacherDetails!.secondaryClasses,
              primaryClassStudents: _primaryStudents,
              secondaryClassStudents: _secondaryStudents,
            )
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: Colors.black87,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        QuickInfoCard(
                          teacher: _teacherDetails!,
                          onTap: _toggleDetails,
                        ),
                        const SizedBox(height: 24),
                        UpcomingEventsSection(events: _upcomingEvents),
                        const SizedBox(height: 24),
                        ActionGridCards(
                          teacher: _teacherDetails!,
                          onStudentsTap: () => setState(() => _currentTab = 1),
                          onAttendanceTap: () {
                            if (_teacherDetails!.primaryClass.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AttendanceScreen(
                                    classId: _teacherDetails!.primaryClass,
                                    className: _teacherDetails!.primaryClass,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("No primary class assigned"),
                                ),
                              );
                            }
                          },
                          onCalendarTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CalendarScreen(),
                            ),
                          ),
                          onGradeTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GradeSelectionScreen(),
                            ),
                          ),
                          onAssignmentTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AssignmentSelectionScreen(),
                            ),
                          ),
                          onLeaveTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const TeacherLeaveRequestsScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
