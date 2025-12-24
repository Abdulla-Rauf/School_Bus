// lib/screens/calendar/widgets/event_details_dialog.dart
import 'package:flutter/material.dart';

import '../../../../../models/calendar_model.dart';
import '../../../../../models/user_model.dart';

class EventDetailsDialog extends StatelessWidget {
  final CalendarEvent event;
  final UserModel currentUser;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const EventDetailsDialog({
    super.key,
    required this.event,
    required this.currentUser,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Row(
        children: [
          Expanded(
            child: Text(
              event.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: event.creatorBadgeBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: event.creatorBadgeColor.withOpacity(0.3),
              ),
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Type', event.type.toString().split('.').last),
          _buildDetailRow('Description', event.description),
          _buildDetailRow('From', _formatDate(event.startDate)),
          _buildDetailRow('To', _formatDate(event.endDate)),
          if (event.createdBy == 'teacher' && event.creatorName != null)
            _buildDetailRow('Created by', event.creatorName!),
          _buildDetailRow(
            'For',
            event.isForAllClasses
                ? 'All Classes'
                : event.affectedClasses.join(', '),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          child: const Text('Close', style: TextStyle(color: Colors.black87)),
        ),
        if (currentUser.role == 'school' ||
            (currentUser.role == 'teacher' &&
                event.creatorId == currentUser.specificId)) ...[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onEdit();
            },
            child: const Text('Edit', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ],
    );
  }
}
