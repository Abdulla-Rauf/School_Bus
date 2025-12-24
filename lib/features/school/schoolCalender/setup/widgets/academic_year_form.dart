// lib/screens/calendar/setup/widgets/academic_year_form.dart
import 'package:flutter/material.dart';

class AcademicYearForm extends StatelessWidget {
  final TextEditingController controller;

  const AcademicYearForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Year',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Academic Year (e.g., 2024-2025)',
                border: OutlineInputBorder(),
                hintText: '2024-2025',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter academic year';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
