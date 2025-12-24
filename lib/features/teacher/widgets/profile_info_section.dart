// lib/screens/teacher/widgets/profile_info_section.dart
import 'package:flutter/material.dart';

class ProfileInfoSection extends StatelessWidget {
  final String title;
  final List<(String, String, IconData)> items;

  const ProfileInfoSection({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey),
            ),
            child: Column(
              children: items
                  .map(
                    (e) => ListTile(
                      leading: Icon(e.$3, color: Colors.black87),
                      title: Text(
                        e.$1,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      subtitle: Text(
                        e.$2,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
