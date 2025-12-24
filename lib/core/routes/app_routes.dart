import 'package:flutter/material.dart';
import '../../features/auth/role_selection_screen.dart';
import '../../features/auth/school_auth_screen.dart';
import '../../features/auth/teacher_login_screen.dart';
import '../../features/auth/student_login_screen.dart';
import '../../features/auth/driver_login_screen.dart';
import '../../features/school/school_dashboard.dart';
import '../../features/teacher/teacher_dashboard.dart';
import '../../features/student/student_dashboard.dart';
import '../../features/driver/driver_dashboard.dart';
import '../../features/school/schoolTeacher/add_teacher_screen.dart';

class AppRoutes {
  // Route names
  static const String roleSelection = '/';
  static const String schoolAuth = '/school-auth';
  static const String teacherLogin = '/teacher-login';
  static const String studentLogin = '/student-login';
  static const String driverLogin = '/driver-login';
  static const String schoolDashboard = '/school-dashboard';
  static const String teacherDashboard = '/teacher-dashboard';
  static const String studentDashboard = '/student-dashboard';
  static const String driverDashboard = '/driver-dashboard';
  static const String addTeacher = '/add-teacher';

  // Route map for MaterialApp
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      roleSelection: (context) => const RoleSelectionScreen(),
      schoolAuth: (context) => const SchoolAuthScreen(),
      teacherLogin: (context) => const TeacherLoginScreen(),
      studentLogin: (context) => const StudentLoginScreen(),
      driverLogin: (context) => const DriverLoginScreen(),
      schoolDashboard: (context) => const SchoolDashboard(),
      teacherDashboard: (context) => const TeacherDashboard(),
      studentDashboard: (context) => const StudentDashboard(),
      driverDashboard: (context) => const DriverDashboard(),
      addTeacher: (context) => const AddTeacherScreen(),
    };
  }
}