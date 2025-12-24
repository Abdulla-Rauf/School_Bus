// lib/screens/calendar/setup/widgets/working_days_section.dart
import 'package:flutter/material.dart';

import '../../../../../models/calendar_model.dart';
import '../utils/calculation_utils.dart';

class WorkingDaysSection extends StatelessWidget {
  final List<WorkingDay> workingDays;
  final Function(int) onToggleWorkingDay;

  const WorkingDaysSection({
    super.key,
    required this.workingDays,
    required this.onToggleWorkingDay,
  });

  @override
  Widget build(BuildContext context) {
    final workingDaysCount = workingDays
        .where((day) => day.isWorkingDay)
        .length;
    final percentage = CalculationUtils.calculateWorkingDaysPercentage(
      workingDays,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Working Days',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('Select which days are working days:'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: workingDays.map((workingDay) {
                return FilterChip(
                  label: Text(workingDay.getDayName()),
                  selected: workingDay.isWorkingDay,
                  onSelected: (_) => onToggleWorkingDay(workingDay.dayOfWeek),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildWorkingDaysStats(workingDaysCount, percentage),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingDaysStats(int workingDaysCount, double percentage) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Working Days: $workingDaysCount/7',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Weekly: ${percentage.toStringAsFixed(1)}% working',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          CircleAvatar(
            backgroundColor: Colors.blue[50],
            child: Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
