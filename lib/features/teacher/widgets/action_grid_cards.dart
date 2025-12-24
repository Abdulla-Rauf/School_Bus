// lib/screens/teacher/widgets/action_grid_cards.dart
import 'package:flutter/material.dart';

import '../../../models/teacher_model.dart';

class ActionGridCards extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback onStudentsTap;
  final VoidCallback onAttendanceTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onGradeTap;
  final VoidCallback onAssignmentTap;
  final VoidCallback onLeaveTap;

  const ActionGridCards({
    super.key,
    required this.teacher,
    required this.onStudentsTap,
    required this.onAttendanceTap,
    required this.onCalendarTap,
    required this.onGradeTap,
    required this.onAssignmentTap,
    required this.onLeaveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _card(
              Icons.people,
              'My Students',
              'View class students',
              onStudentsTap,
            ),
            _card(
              Icons.assignment,
              'Mark Attendance',
              'Take daily attendance',
              onAttendanceTap,
              bg: Colors.grey[50],
            ),
            _card(
              Icons.calendar_today,
              'School Calendar',
              'View all events',
              onCalendarTap,
            ),
            _card(
              Icons.grade,
              'Enter Grades',
              'Update student marks',
              onGradeTap,
              bg: Colors.grey[50],
            ),
            _card(
              Icons.assignment,
              'Create Assignment',
              'Create Assignment',
              onAssignmentTap,
              bg: Colors.grey[50],
            ),
            _card(
              Icons.report_gmailerrorred_rounded,
              'Leave Requests',
              'Students Leaves',
              onLeaveTap,
              bg: Colors.grey[50],
            ),
          ],
        ),
      ],
    );
  }

  Widget _card(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color? bg,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bg ?? Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
