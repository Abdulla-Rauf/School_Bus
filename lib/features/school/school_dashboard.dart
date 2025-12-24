import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:school_bus2/features/school/profile/school_profile_screen.dart';
import 'package:school_bus2/features/school/schoolStudent/students_list_screen.dart';

import 'package:school_bus2/features/school/schoolCalender/Calender/calendar_screen.dart';
import 'package:school_bus2/features/school/school_config_screen.dart';
import 'package:school_bus2/features/school/schoolTeacher/teachers_list_screen.dart';
import 'package:school_bus2/features/school/schoolDriver/drivers_list_screen.dart';
import 'package:school_bus2/features/school/schoolVehicle/vehicles_list_screen.dart';
import '../../core/theme/premium_theme.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../models/calendar_model.dart';
import '../../core/widgets/auth_wrapper.dart';
import '../../models/vehicle_model.dart';
import '../../models/student_model.dart';
import '../../models/driver_model.dart';

class SchoolDashboard extends StatefulWidget {
  const SchoolDashboard({super.key});

  @override
  _SchoolDashboardState createState() => _SchoolDashboardState();
}

class _SchoolDashboardState extends State<SchoolDashboard> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardHome(),
    const StudentsListScreen(),
    const TeachersListScreen(),
    const DriversListScreen(),
    const VehiclesListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.black,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: PremiumTheme.black,
          boxShadow: [
            BoxShadow(
              color: PremiumTheme.neonLime.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            HapticFeedback.lightImpact();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: PremiumTheme.black,
          selectedItemColor: PremiumTheme.neonLime,
          unselectedItemColor: Colors.grey[600],
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_rounded),
              label: 'Students',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Teachers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.drive_eta_rounded),
              label: 'Drivers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_bus_rounded),
              label: 'Vehicles',
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  _DashboardHomeState createState() => _DashboardHomeState();
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final DateTime date;
  final IconData icon;
  final Color color;

  _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.color,
  });
}

class _DashboardHomeState extends State<DashboardHome>
    with SingleTickerProviderStateMixin {
  UserModel? _currentUser;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Restored events variables
  List<CalendarEvent> _upcomingEvents = [];
  bool _isLoadingEvents = true;

  List<Vehicle> _vehicles = [];
  bool _isLoadingVehicles = true;
  List<_ActivityItem> _recentActivity = [];
  bool _isLoadingActivity = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user = await authService.getCurrentUserData();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
      _loadUpcomingEvents();
      _loadVehicles();
      _loadRecentActivity();
    }
  }

  Future<void> _loadUpcomingEvents() async {
    if (_currentUser == null) return;
    if (mounted) setState(() => _isLoadingEvents = true);

    try {
      DatabaseService dbService = DatabaseService();
      SchoolCalendar? calendar = await dbService.getSchoolCalendar(
        _currentUser!.uid,
      );

      if (calendar != null) {
        final now = DateTime.now();
        final upcoming =
            calendar.events
                .where((event) => event.endDate.isAfter(now))
                .toList()
              ..sort((a, b) => a.startDate.compareTo(b.startDate));

        if (mounted) {
          setState(() {
            _upcomingEvents = upcoming.take(3).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading upcoming events: $e');
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _loadVehicles() async {
    if (_currentUser == null) return;
    if (mounted) setState(() => _isLoadingVehicles = true);
    try {
      DatabaseService dbService = DatabaseService();
      List<Vehicle> vehicles = await dbService.getVehicles(_currentUser!.uid);
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
        });
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    } finally {
      if (mounted) setState(() => _isLoadingVehicles = false);
    }
  }

  Future<void> _loadRecentActivity() async {
    if (_currentUser == null) return;
    if (mounted) setState(() => _isLoadingActivity = true);

    try {
      DatabaseService dbService = DatabaseService();
      String schoolId = _currentUser!.uid;

      List<Student> students = await dbService.getStudents(schoolId);
      List<Driver> drivers = await dbService.getDrivers(schoolId);
      List<Vehicle> vehicles = await dbService.getVehicles(schoolId);

      List<_ActivityItem> activity = [];

      for (var s in students) {
        activity.add(
          _ActivityItem(
            title: 'New Student',
            subtitle: '${s.firstName} ${s.lastName}',
            date: s.createdAt,
            icon: Icons.person_add_rounded,
            color: const Color(0xFF4ACFAC), // Mint green
          ),
        );
      }

      for (var d in drivers) {
        activity.add(
          _ActivityItem(
            title: 'New Driver',
            subtitle: d.name,
            date: d.createdAt,
            icon: Icons.drive_eta_rounded,
            color: const Color(0xFF6C63FF), // Purple
          ),
        );
      }

      for (var v in vehicles) {
        activity.add(
          _ActivityItem(
            title: 'New Vehicle',
            subtitle: '${v.vehicleName} (${v.vehicleNumber})',
            date: v.createdAt,
            icon: Icons.directions_bus_rounded,
            color: const Color(0xFFFF6B6B), // Coral Red
          ),
        );
      }

      activity.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _recentActivity = activity.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recent activity: $e');
    } finally {
      if (mounted) setState(() => _isLoadingActivity = false);
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Now';
  }

  Future<void> _refreshData() async {
    HapticFeedback.mediumImpact();
    await _loadCurrentUser();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout, color: Colors.red[400], size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to end your session?',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final authService = Provider.of<AuthService>(
                  context,
                  listen: false,
                );
                await authService.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AuthWrapper(),
                    ),
                    (route) => false,
                  );
                }
              },
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: PremiumTheme.darkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 30,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              gradient: PremiumTheme.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      Icons.school_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _currentUser?.name ?? 'School Admin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.dashboard_rounded,
                  title: 'Dashboard',
                  onTap: () => Navigator.pop(context),
                  isSelected: true,
                ),
                _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  title: 'Configuration',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SchoolConfigScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.calendar_today_rounded,
                  title: 'Calendar',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CalendarScreen(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'School Profile',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SchoolProfileScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          const SizedBox(height: 12),
          _buildDrawerItem(
            icon: Icons.logout_rounded,
            title: 'Logout',
            textColor: Colors.red[400],
            iconColor: Colors.red[400],
            onTap: _showLogoutDialog,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    Color? textColor,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? PremiumTheme.neonLime.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color:
              iconColor ??
              (isSelected ? PremiumTheme.neonLime : Colors.grey[400]),
        ),
        title: Text(
          title,
          style: TextStyle(
            color:
                textColor ??
                (isSelected ? PremiumTheme.neonLime : Colors.white),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      ),
    );
  }

  Widget _buildVehicleStatusCard() {
    if (_isLoadingVehicles) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    int activeVehicles = _vehicles
        .where((v) => v.assignedStudents.isNotEmpty)
        .length;
    int totalVehicles = _vehicles.length;
    int runningVehicles = (activeVehicles * 0.7).round(); // Mock
    int idleVehicles = totalVehicles - runningVehicles;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: PremiumTheme.darkGrey,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: PremiumTheme.neonLime.withOpacity(0.3)),
        boxShadow: PremiumTheme.neonShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fleet Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: PremiumTheme.neonLime),
                    SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$runningVehicles',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: PremiumTheme.neonLime,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'On Route',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$idleVehicles',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Parked',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: PremiumTheme.darkGrey,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    if (_isLoadingActivity) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    if (_recentActivity.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: PremiumTheme.darkGrey,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history_rounded, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No recent activity',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentActivity.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final activity = _recentActivity[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PremiumTheme.darkGrey,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: activity.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(activity.icon, size: 20, color: activity.color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _timeAgo(activity.date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUpcomingEventsSection() {
    if (_isLoadingEvents) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    if (_upcomingEvents.isEmpty) {
      return Container(); // Hide if empty to save space
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'Upcoming Events',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = _upcomingEvents[index];
              return Container(
                width: 240,
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: index % 2 == 0
                        ? [
                            const Color(0xFFFF9F69),
                            const Color(0xFFFF6B6B),
                          ] // Orange-Red
                        : [
                            const Color(0xFF4ACFAC),
                            const Color(0xFF43A08D),
                          ], // Mint-Teal
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (index % 2 == 0
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFF4ACFAC))
                              .withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            event.type.toString().split('.').last.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.event_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'MMM d, h:mm a',
                              ).format(event.startDate),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.black,
      appBar: AppBar(
        title: const Text(
          'DASHBOARD',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: PremiumTheme.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PremiumTheme.darkGrey,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 20),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF6C63FF),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Hello, ',
                        style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                      ),
                      Text(
                        _currentUser?.name ?? 'Admin',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildVehicleStatusCard(),

                  const SizedBox(height: 32),

                  _buildUpcomingEventsSection(),

                  if (_upcomingEvents.isNotEmpty) const SizedBox(height: 32),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildGridActionCard(
                        title: 'Students',
                        icon: Icons.school_rounded,
                        color: const Color(0xFF4ACFAC), // Mint
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StudentsListScreen(),
                            ),
                          );
                        },
                      ),
                      _buildGridActionCard(
                        title: 'Teachers',
                        icon: Icons.person_rounded,
                        color: const Color(0xFF6C63FF), // Purple
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TeachersListScreen(),
                          ),
                        ),
                      ),
                      _buildGridActionCard(
                        title: 'Drivers',
                        icon: Icons.drive_eta_rounded,
                        color: const Color(0xFFFF9F69), // Orange
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DriversListScreen(),
                          ),
                        ),
                      ),
                      _buildGridActionCard(
                        title: 'Vehicles',
                        icon: Icons.directions_bus_rounded,
                        color: const Color(0xFFFF6B6B), // Red
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VehiclesListScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  _buildRecentActivitySection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
