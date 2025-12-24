// lib/screens/calendar/widgets/event_card.dart
import 'package:flutter/material.dart';
import '../../../../../models/calendar_model.dart';
import '../../../../../models/user_model.dart';
import '../../../../../services/database_service.dart';

class EventCard extends StatelessWidget {
  final CalendarEvent event;
  final UserModel currentUser;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EventCard({
    super.key,
    required this.event,
    required this.currentUser,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    DatabaseService dbService = DatabaseService();
    final canEdit = dbService.canUserEditEvent(event, currentUser);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 4,
          decoration: BoxDecoration(
            color: event.getEventColor(),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: event.creatorBadgeBackgroundColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                event.creatorBadge,
                style: TextStyle(
                  color: event.creatorBadgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${event.type.toString().split('.').last} • ${_formatDate(event.startDate)} - ${_formatDate(event.endDate)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (event.isForAllClasses) ...[
              const SizedBox(height: 4),
              const Text(
                'For: All Classes',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ] else if (event.affectedClasses.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'For: ${event.affectedClasses.join(', ')}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event.description,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.black54, size: 20),
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            } else if (value == 'view') {
              onTap();
            }
          },
          itemBuilder: (BuildContext context) {
            final items = <PopupMenuItem<String>>[
              const PopupMenuItem<String>(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.black54),
                    SizedBox(width: 8),
                    Text(
                      'View Details',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ];

            if (canEdit) {
              items.addAll([
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('Edit', style: TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ]);
            }

            return items;
          },
        ),
        onTap: onTap,
      ),
    );
  }
}
