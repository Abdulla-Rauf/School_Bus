// lib/screens/calendar/widgets/setup_calendar_view.dart
import 'package:flutter/material.dart';

import '../../../../../models/user_model.dart';

class SetupCalendarView extends StatelessWidget {
  final UserModel? currentUser;
  final VoidCallback onSetupPressed;

  const SetupCalendarView({
    super.key,
    required this.currentUser,
    required this.onSetupPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today,
                size: 40,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Academic Calendar Not Setup',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              currentUser?.role == 'school'
                  ? 'Setup your academic calendar with working days, holidays, and events for the entire academic year.'
                  : 'The school calendar has not been setup yet. Please contact your school administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            if (currentUser?.role == 'school')
              ElevatedButton(
                onPressed: onSetupPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.settings, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Setup Academic Calendar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
