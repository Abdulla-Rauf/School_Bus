import 'package:flutter/material.dart';

class SchoolCalendar {
  final String schoolId;
  final String academicYear;
  final DateTime academicYearStart;
  final DateTime academicYearEnd;
  final List<CalendarEvent> events;
  final List<WorkingDay> workingDays;
  final DateTime createdAt;
  final DateTime updatedAt;

  SchoolCalendar({
    required this.schoolId,
    required this.academicYear,
    required this.academicYearStart,
    required this.academicYearEnd,
    required this.events,
    required this.workingDays,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'academicYear': academicYear,
      'academicYearStart': academicYearStart.millisecondsSinceEpoch,
      'academicYearEnd': academicYearEnd.millisecondsSinceEpoch,
      'events': events.map((event) => event.toMap()).toList(),
      'workingDays': workingDays.map((day) => day.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SchoolCalendar.fromMap(Map<String, dynamic> map) {
    return SchoolCalendar(
      schoolId: map['schoolId'] ?? '',
      academicYear: map['academicYear'] ?? '',
      academicYearStart: DateTime.fromMillisecondsSinceEpoch(map['academicYearStart'] ?? 0),
      academicYearEnd: DateTime.fromMillisecondsSinceEpoch(map['academicYearEnd'] ?? 0),
      events: List<CalendarEvent>.from(
        (map['events'] ?? []).map((x) => CalendarEvent.fromMap(x)),
      ),
      workingDays: List<WorkingDay>.from(
        (map['workingDays'] ?? []).map((x) => WorkingDay.fromMap(x)),
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }
}

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final EventType type;
  final DateTime startDate;
  final DateTime endDate;
  final bool isFullDay;
  final List<String> affectedClasses; // Empty means all classes
  final String createdBy; // 'school' or 'teacher'
  final String? creatorId; // Teacher ID if created by teacher
  final String? creatorName; // Creator's name
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.isFullDay = true,
    this.affectedClasses = const [],
    required this.createdBy,
    this.creatorId,
    this.creatorName,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'isFullDay': isFullDay,
      'affectedClasses': affectedClasses,
      'createdBy': createdBy,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'color': color,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: EventType.values.firstWhere(
            (e) => e.toString().split('.').last == map['type'],
        orElse: () => EventType.event,
      ),
      startDate: DateTime.fromMillisecondsSinceEpoch(map['startDate'] ?? 0),
      endDate: DateTime.fromMillisecondsSinceEpoch(map['endDate'] ?? 0),
      isFullDay: map['isFullDay'] ?? true,
      affectedClasses: List<String>.from(map['affectedClasses'] ?? []),
      createdBy: map['createdBy'] ?? 'school',
      creatorId: map['creatorId'],
      creatorName: map['creatorName'],
      color: map['color'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? DateTime.now().millisecondsSinceEpoch),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch),
    );
  }

  // Check if event affects all classes
  bool get isForAllClasses => affectedClasses.isEmpty;

  // Check if event affects specific classes
  bool affectsClass(String className) {
    if (isForAllClasses) return true;
    return affectedClasses.contains(className);
  }

  // Check if event affects any of the given classes
  bool affectsAnyClass(List<String> classes) {
    if (isForAllClasses) return true;
    return affectedClasses.any((ac) => classes.contains(ac));
  }

  // Rest of the methods remain the same...
  bool isDateInEvent(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    return normalizedDate.isAfter(normalizedStart.subtract(const Duration(days: 1))) &&
        normalizedDate.isBefore(normalizedEnd.add(const Duration(days: 1)));
  }

  Color getEventColor() {
    if (color != null && color!.isNotEmpty) {
      return Color(int.parse(color!.replaceFirst('#', '0xFF')));
    }

    switch (type) {
      case EventType.holiday:
        return const Color(0xFFEF5350);
      case EventType.exam:
        return const Color(0xFFFF9800);
      case EventType.vacation:
        return const Color(0xFF4CAF50);
      case EventType.event:
        return const Color(0xFF2196F3);
      case EventType.workingDay:
        return const Color(0xFF9E9E9E);
    }
  }

  Color getEventLightColor() {
    switch (type) {
      case EventType.holiday:
        return const Color(0xFFFFEBEE);
      case EventType.exam:
        return const Color(0xFFFFF3E0);
      case EventType.vacation:
        return const Color(0xFFE8F5E8);
      case EventType.event:
        return const Color(0xFFE3F2FD);
      case EventType.workingDay:
        return const Color(0xFFFAFAFA);
    }
  }

  IconData getEventIcon() {
    switch (type) {
      case EventType.holiday:
        return Icons.beach_access;
      case EventType.exam:
        return Icons.assignment;
      case EventType.vacation:
        return Icons.holiday_village;
      case EventType.event:
        return Icons.event;
      case EventType.workingDay:
        return Icons.work;
    }
  }

  String getTypeName() {
    return type.toString().split('.').last;
  }

  // Get creator badge text
  String get creatorBadge {
    if (createdBy == 'school') return 'School';
    if (createdBy == 'teacher' && creatorName != null) return 'By $creatorName';
    return 'Teacher';
  }

  // Get creator badge color
  Color get creatorBadgeColor {
    if (createdBy == 'school') return Colors.green;
    return Colors.blue;
  }

  // Get creator badge background color
  Color get creatorBadgeBackgroundColor {
    if (createdBy == 'school') return Colors.green.withOpacity(0.1);
    return Colors.blue.withOpacity(0.1);
  }
}

enum EventType {
  holiday,    // Government holidays
  exam,       // Exam periods
  vacation,   // Summer/winter vacations
  event,      // School events
  workingDay, // Special working days
}

class WorkingDay {
  final int dayOfWeek; // 1=Monday, 7=Sunday
  final bool isWorkingDay;
  final String? specialNote;

  WorkingDay({
    required this.dayOfWeek,
    required this.isWorkingDay,
    this.specialNote,
  });

  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'isWorkingDay': isWorkingDay,
      'specialNote': specialNote,
    };
  }

  factory WorkingDay.fromMap(Map<String, dynamic> map) {
    return WorkingDay(
      dayOfWeek: map['dayOfWeek'] ?? 1,
      isWorkingDay: map['isWorkingDay'] ?? true,
      specialNote: map['specialNote'],
    );
  }

  String getDayName() {
    switch (dayOfWeek) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Unknown';
    }
  }

  String getShortDayName() {
    switch (dayOfWeek) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return 'Unknown';
    }
  }


}