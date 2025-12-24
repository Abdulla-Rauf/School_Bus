// lib/screens/teacher/widgets/quick_info_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../models/teacher_model.dart';

class QuickInfoCard extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback onTap;

  const QuickInfoCard({super.key, required this.teacher, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fullName = "${teacher.firstName} ${teacher.lastName ?? ''}".trim();
    final photoUrl = teacher.photoUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black87, Colors.black54],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(right: -30, top: -30, child: Circle(150, 0.05)),
            Positioned(left: -50, bottom: -50, child: Circle(180, 0.03)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            fullName.isEmpty ? 'Teacher' : fullName,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (photoUrl != null)
                      CircleAvatar(
                        radius: 44,
                        backgroundImage: CachedNetworkImageProvider(photoUrl),
                      )
                    else
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(height: 1.5, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _InfoColumn('TEACHER ID', teacher.teacherId ?? 'N/A'),
                    _InfoColumn(
                      'PRIMARY CLASS',
                      teacher.primaryClass ?? 'Not assigned',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _InfoColumn(
                      'SUBJECTS',
                      teacher.specialization ?? 'Not specified',
                      width: 180,
                    ),
                    Row(
                      children: [
                        Text(
                          'View all details',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward,
                          color: Colors.grey,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const Circle(this.size, this.opacity, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final double? width;
  const _InfoColumn(this.label, this.value, {this.width});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey[400],
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: width,
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
