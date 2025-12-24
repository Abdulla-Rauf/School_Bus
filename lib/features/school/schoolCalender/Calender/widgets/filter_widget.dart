// lib/screens/calendar/widgets/filter_widget.dart
import 'package:flutter/material.dart';

import '../../../../../models/user_model.dart';

class FilterWidget extends StatelessWidget {
  final UserModel? currentUser;
  final List<String> availableClasses;
  final List<String> teacherClasses;
  final String? classFilter;
  final ValueChanged<String?> onFilterChanged;

  const FilterWidget({
    super.key,
    required this.currentUser,
    required this.availableClasses,
    required this.teacherClasses,
    required this.classFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    List<String> filterOptions;

    if (currentUser?.role == 'school') {
      filterOptions = ['All', ...availableClasses];
    } else if (currentUser?.role == 'teacher') {
      filterOptions = ['All', ...teacherClasses];
    } else {
      return const SizedBox();
    }

    if (filterOptions.length <= 1) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: classFilter ?? 'All',
          icon: const Icon(Icons.filter_list, size: 16),
          elevation: 2,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          onChanged: onFilterChanged,
          items: filterOptions.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }
}
