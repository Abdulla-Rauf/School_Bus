// lib/screens/calendar/setup/widgets/academic_year_stats.dart
import 'package:flutter/material.dart';
import 'package:school_bus2/features/school/schoolCalender/setup/widgets/stat_card.dart';

import '../../../../../models/calendar_model.dart';
import '../utils/calculation_utils.dart';

class AcademicYearStats extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final List<WorkingDay> workingDays;

  const AcademicYearStats({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.workingDays,
  });

  @override
  Widget build(BuildContext context) {
    final stats = CalculationUtils.calculateAcademicYearStats(
      startDate: startDate,
      endDate: endDate,
      workingDays: workingDays,
    );

    final workingPercentage =
        (stats['workingDays']! / stats['totalDays']! * 100);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Year Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StatCard(
                  title: 'Total Days',
                  value: stats['totalDays'].toString(),
                  icon: Icons.calendar_today,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                StatCard(
                  title: 'Working Days',
                  value: stats['workingDays'].toString(),
                  icon: Icons.work,
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                StatCard(
                  title: 'Weekends/Holidays',
                  value: stats['holidays'].toString(),
                  icon: Icons.beach_access,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: workingPercentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                workingPercentage >= 50 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${workingPercentage.toStringAsFixed(1)}% of academic year are working days',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
