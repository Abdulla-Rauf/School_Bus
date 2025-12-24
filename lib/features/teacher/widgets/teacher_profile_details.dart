// lib/screens/teacher/widgets/teacher_profile_details.dart
import 'package:flutter/material.dart';
import 'package:school_bus2/features/teacher/widgets/profile_info_section.dart';

import '../../../models/teacher_model.dart';

class TeacherProfileDetails extends StatelessWidget {
  final Teacher teacher;
  const TeacherProfileDetails({super.key, required this.teacher});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          ProfileInfoSection(
            title: 'Personal Information',
            items: [
              (
                'Full Name',
                '${teacher.firstName} ${teacher.lastName ?? ''}'.trim(),
                Icons.person,
              ),
              ('Teacher ID', teacher.teacherId ?? 'N/A', Icons.badge),
              ('Email', teacher.email ?? 'N/A', Icons.email),
              ('Phone', teacher.phone ?? 'N/A', Icons.phone),
              ('Blood Group', teacher.bloodGroup ?? 'N/A', Icons.bloodtype),
            ],
          ),
          ProfileInfoSection(
            title: 'Professional Information',
            items: [
              ('Primary Class', teacher.primaryClass ?? 'N/A', Icons.class_),
              (
                'Secondary Classes',
                teacher.secondaryClasses.join(', '),
                Icons.class_outlined,
              ),
              ('Subjects', teacher.specialization ?? 'N/A', Icons.subject),
              (
                'Experience',
                '${teacher.experience ?? 0} years',
                Icons.work_history,
              ),
            ],
          ),
          ProfileInfoSection(
            title: 'Contact',
            items: [('Address', teacher.address ?? 'N/A', Icons.location_on)],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final photoUrl = teacher.photoUrl;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        children: [
          if (photoUrl != null)
            CircleAvatar(radius: 52, backgroundImage: NetworkImage(photoUrl))
          else
            const CircleAvatar(
              radius: 52,
              backgroundColor: Colors.black87,
              child: Icon(Icons.person, size: 56, color: Colors.white),
            ),
          const SizedBox(height: 20),
          Text(
            "${teacher.firstName} ${teacher.lastName ?? ''}".trim(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            teacher.teacherId ?? '',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            teacher.primaryClass ?? 'Not assigned',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
