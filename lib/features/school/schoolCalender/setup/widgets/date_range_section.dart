// lib/screens/calendar/setup/widgets/date_range_section.dart
import 'package:flutter/material.dart';

class DateRangeSection extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime) onStartDateChanged;
  final Function(DateTime) onEndDateChanged;

  const DateRangeSection({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? startDate : endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      if (isStartDate) {
        onStartDateChanged(picked);
      } else {
        onEndDateChanged(picked);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Year Dates',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date'),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: () => _selectDate(context, true),
                        child: Text(_formatDate(startDate)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Date'),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: () => _selectDate(context, false),
                        child: Text(_formatDate(endDate)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
