import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_bus2/models/user_model.dart';
import 'package:school_bus2/services/auth_service.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/role_selection_screen.dart';
import '../../features/school/school_dashboard.dart';
import '../../features/teacher/teacher_dashboard.dart';
import '../../features/student/student_dashboard.dart';
import '../../features/driver/driver_dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingAuth = true;
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _determineInitialScreen();
  }

  Future<void> _determineInitialScreen() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if user has existing session
    final hasSession = await authService.hasExistingSession();

    if (hasSession) {
      // User has existing session, get their data and determine dashboard
      final userData = await authService.getCurrentUserData();
      if (userData != null) {
        setState(() {
          _initialScreen = _buildDashboardBasedOnRole(userData);
          _isCheckingAuth = false;
        });
        return;
      }
    }

    // No session or couldn't get user data, show splash then role selection
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _initialScreen = const RoleSelectionScreen();
      _isCheckingAuth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // If we're still checking initial auth, show splash
        if (_isCheckingAuth) {
          return const SplashScreen();
        }

        // If user is logged out, show role selection
        if (snapshot.data == null) {
          return const RoleSelectionScreen();
        }

        // If user is logged in, show the initial screen we determined
        // or if we don't have one, determine it now
        if (_initialScreen == null) {
          return FutureBuilder<UserModel?>(
            future: authService.getCurrentUserData(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              final UserModel? user = userSnapshot.data;

              if (user != null) {
                return _buildDashboardBasedOnRole(user);
              }

              return const RoleSelectionScreen();
            },
          );
        }

        return _initialScreen!;
      },
    );
  }

  Widget _buildDashboardBasedOnRole(UserModel user) {
    switch (user.role) {
      case 'school':
        return const SchoolDashboard();
      case 'teacher':
        return const TeacherDashboard();
      case 'student':
        return const StudentDashboard();
      case 'driver':
        return const DriverDashboard();
      default:
        return const RoleSelectionScreen();
    }
  }
}
