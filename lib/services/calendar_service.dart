// calendar_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_model.dart';
import '../models/user_model.dart';

class CalendarService {
  final FirebaseFirestore _firestore;

  CalendarService(this._firestore);

  Future<bool> saveSchoolCalendar(SchoolCalendar calendar) async {
    try {
      await _firestore
          .collection('school_calendars')
          .doc(calendar.schoolId)
          .set(calendar.toMap());
      return true;
    } catch (e) {
      print('Error saving school calendar: $e');
      return false;
    }
  }

  Future<SchoolCalendar?> getSchoolCalendar(String schoolId) async {
    try {
      var doc = await _firestore
          .collection('school_calendars')
          .doc(schoolId)
          .get();

      if (doc.exists) {
        return SchoolCalendar.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting school calendar: $e');
      return null;
    }
  }

  Future<bool> addCalendarEvent(String schoolId, CalendarEvent event) async {
    try {
      var calendar = await getSchoolCalendar(schoolId);
      if (calendar != null) {
        List<CalendarEvent> events = List.from(calendar.events);

        final newEvent = CalendarEvent(
          id: event.id,
          title: event.title,
          description: event.description,
          type: event.type,
          startDate: event.startDate,
          endDate: event.endDate,
          isFullDay: event.isFullDay,
          affectedClasses: event.affectedClasses,
          createdBy: 'school',
          creatorId: null,
          creatorName: 'School Administration',
          color: event.color,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        events.add(newEvent);

        SchoolCalendar updatedCalendar = SchoolCalendar(
          schoolId: calendar.schoolId,
          academicYear: calendar.academicYear,
          academicYearStart: calendar.academicYearStart,
          academicYearEnd: calendar.academicYearEnd,
          events: events,
          workingDays: calendar.workingDays,
          createdAt: calendar.createdAt,
          updatedAt: DateTime.now(),
        );

        return await saveSchoolCalendar(updatedCalendar);
      }
      return false;
    } catch (e) {
      print('Error adding calendar event: $e');
      return false;
    }
  }

  Future<bool> deleteCalendarEvent(String schoolId, String eventId) async {
    try {
      var calendar = await getSchoolCalendar(schoolId);
      if (calendar != null) {
        List<CalendarEvent> events = calendar.events
            .where((e) => e.id != eventId)
            .toList();

        SchoolCalendar updatedCalendar = SchoolCalendar(
          schoolId: calendar.schoolId,
          academicYear: calendar.academicYear,
          academicYearStart: calendar.academicYearStart,
          academicYearEnd: calendar.academicYearEnd,
          events: events,
          workingDays: calendar.workingDays,
          createdAt: calendar.createdAt,
          updatedAt: DateTime.now(),
        );

        return await saveSchoolCalendar(updatedCalendar);
      }
      return false;
    } catch (e) {
      print('Error deleting calendar event: $e');
      return false;
    }
  }

  Future<List<CalendarEvent>> getEventsForTeacher(
    String schoolId,
    List<String> teacherClasses,
  ) async {
    try {
      var calendar = await getSchoolCalendar(schoolId);
      if (calendar == null) return [];

      return calendar.events.where((event) {
        // Events for all classes
        if (event.affectedClasses.isEmpty) return true;

        // Events that affect teacher's classes
        return event.affectsAnyClass(teacherClasses);
      }).toList();
    } catch (e) {
      print('Error getting teacher events: $e');
      return [];
    }
  }

  Future<bool> addCalendarEventWithCreator(
    String schoolId,
    CalendarEvent event, {
    String createdBy = 'school',
    String? creatorId,
    String? creatorName,
  }) async {
    try {
      var calendar = await getSchoolCalendar(schoolId);
      if (calendar != null) {
        List<CalendarEvent> events = List.from(calendar.events);

        // Set creator information
        final newEvent = CalendarEvent(
          id: event.id,
          title: event.title,
          description: event.description,
          type: event.type,
          startDate: event.startDate,
          endDate: event.endDate,
          isFullDay: event.isFullDay,
          affectedClasses: event.affectedClasses,
          createdBy: createdBy,
          creatorId: creatorId,
          creatorName: creatorName,
          color: event.color,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        events.add(newEvent);

        SchoolCalendar updatedCalendar = SchoolCalendar(
          schoolId: calendar.schoolId,
          academicYear: calendar.academicYear,
          academicYearStart: calendar.academicYearStart,
          academicYearEnd: calendar.academicYearEnd,
          events: events,
          workingDays: calendar.workingDays,
          createdAt: calendar.createdAt,
          updatedAt: DateTime.now(),
        );

        return await saveSchoolCalendar(updatedCalendar);
      }
      return false;
    } catch (e) {
      print('Error adding calendar event with creator: $e');
      return false;
    }
  }

  bool canUserEditEvent(CalendarEvent event, UserModel user) {
    // School admin can edit everything
    if (user.role == 'school') return true;

    // Teachers can edit their own events
    if (user.role == 'teacher' &&
        event.createdBy == 'teacher' &&
        event.creatorId == user.specificId) {
      return true;
    }

    return false;
  }

  Future<List<CalendarEvent>> getUpcomingEventsForClasses(
    List<String> classNames,
  ) async {
    try {
      final now = DateTime.now();
      final thirtyDaysLater = now.add(Duration(days: 30));

      List<CalendarEvent> allEvents = [];

      // Get all school calendars
      var calendarsQuery = await _firestore
          .collection('school_calendars')
          .get();

      for (var calendarDoc in calendarsQuery.docs) {
        var calendarData = calendarDoc.data();
        if (calendarData['events'] != null) {
          List<dynamic> eventsData = calendarData['events'];

          for (var eventData in eventsData) {
            try {
              CalendarEvent event = CalendarEvent.fromMap(
                Map<String, dynamic>.from(eventData),
              );

              // Check if event is in the next 30 days
              if (event.startDate.isAfter(now.subtract(Duration(days: 1))) &&
                  event.startDate.isBefore(thirtyDaysLater)) {
                // Check if event affects any of the teacher's classes
                bool affectsTeacherClasses =
                    event.affectedClasses.isEmpty ||
                    event.affectedClasses.any(
                      (affectedClass) => classNames.contains(affectedClass),
                    );

                if (affectsTeacherClasses) {
                  allEvents.add(event);
                }
              }
            } catch (e) {
              print('Error parsing event data: $e');
            }
          }
        }
      }

      // Sort events by start date
      allEvents.sort((a, b) => a.startDate.compareTo(b.startDate));

      return allEvents;
    } catch (e) {
      print('Error getting upcoming events for classes: $e');
      return [];
    }
  }

  Future<List<CalendarEvent>> getUpcomingEventsForSchool(
    String schoolId,
    List<String> classNames,
  ) async {
    try {
      final now = DateTime.now();
      final thirtyDaysLater = now.add(Duration(days: 30));

      var calendarDoc = await _firestore
          .collection('school_calendars')
          .doc(schoolId)
          .get();

      if (!calendarDoc.exists) {
        return [];
      }

      var calendarData = calendarDoc.data();
      if (calendarData?['events'] == null) {
        return [];
      }

      List<CalendarEvent> events = [];
      List<dynamic> eventsData = calendarData!['events'];

      for (var eventData in eventsData) {
        try {
          CalendarEvent event = CalendarEvent.fromMap(
            Map<String, dynamic>.from(eventData),
          );

          // Check if event is in the next 30 days
          if (event.startDate.isAfter(now.subtract(Duration(days: 1))) &&
              event.startDate.isBefore(thirtyDaysLater)) {
            // Check if event affects any of the teacher's classes
            bool affectsTeacherClasses =
                event.affectedClasses.isEmpty ||
                event.affectedClasses.any(
                  (affectedClass) => classNames.contains(affectedClass),
                );

            if (affectsTeacherClasses) {
              events.add(event);
            }
          }
        } catch (e) {
          print('Error parsing event data: $e');
        }
      }

      // Sort events by start date
      events.sort((a, b) => a.startDate.compareTo(b.startDate));

      return events;
    } catch (e) {
      print('Error getting upcoming events for school: $e');
      return [];
    }
  }

  // --- Working Day Logic ---

  bool isDateWorkingDay(DateTime date, SchoolCalendar calendar) {
    // 1. Check if it's a regular working day (e.g. Mon-Fri)
    // Find the WorkingDay config for this day of week (1=Mon, 7=Sun)
    try {
      final workingDayConfig = calendar.workingDays.firstWhere(
        (wd) => wd.dayOfWeek == date.weekday,
        orElse: () => WorkingDay(
          dayOfWeek: date.weekday,
          isWorkingDay: true,
        ), // Default to true if missing? Or should be false?
      );

      if (!workingDayConfig.isWorkingDay) {
        // It's a weekend or configured regular off day
        return false;
      }

      // 2. Check for Holidays in Events
      // Normalize date to remove time
      final normalizedDate = DateTime(date.year, date.month, date.day);

      bool isHoliday = calendar.events.any((event) {
        if (event.type != EventType.holiday) return false;

        // Check date range
        // Normalize event dates
        final start = DateTime(
          event.startDate.year,
          event.startDate.month,
          event.startDate.day,
        );
        final end = DateTime(
          event.endDate.year,
          event.endDate.month,
          event.endDate.day,
        );

        return !normalizedDate.isBefore(start) && !normalizedDate.isAfter(end);
      });

      if (isHoliday) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking working day: $e');
      return true; // Fail safe
    }
  }

  Future<int> getWorkingDaysCount(
    DateTime start,
    DateTime end,
    String schoolId,
  ) async {
    try {
      final calendar = await getSchoolCalendar(schoolId);
      if (calendar == null) {
        // Fallback: simple difference excluding weekends?
        // Or return 0/difference? Let's return difference for now if no calendar found
        // But better to return 0 or difference?
        // Let's assume M-F are working if no calendar
        return _calculateDefaultWorkingDays(start, end);
      }

      int count = 0;
      DateTime currentDate = start;
      // Normalize end date to ensure we include it if times match roughly or loop correctly
      // We'll iterate day by day
      final normalizedEnd = DateTime(end.year, end.month, end.day);

      while (!DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      ).isAfter(normalizedEnd)) {
        if (isDateWorkingDay(currentDate, calendar)) {
          count++;
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      return count;
    } catch (e) {
      print('Error calculating working days count: $e');
      return 0;
    }
  }

  Future<List<DateTime>> getWorkingDays(
    DateTime start,
    DateTime end,
    String schoolId,
  ) async {
    try {
      final calendar = await getSchoolCalendar(schoolId);
      if (calendar == null) return [];

      List<DateTime> workingDays = [];
      DateTime currentDate = start;
      final normalizedEnd = DateTime(end.year, end.month, end.day);

      while (!DateTime(
        currentDate.year,
        currentDate.month,
        currentDate.day,
      ).isAfter(normalizedEnd)) {
        if (isDateWorkingDay(currentDate, calendar)) {
          workingDays.add(currentDate);
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }

      return workingDays;
    } catch (e) {
      print('Error getting working days list: $e');
      return [];
    }
  }

  int _calculateDefaultWorkingDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime currentDate = start;
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    while (!DateTime(
      currentDate.year,
      currentDate.month,
      currentDate.day,
    ).isAfter(normalizedEnd)) {
      if (currentDate.weekday >= 1 && currentDate.weekday <= 5) {
        count++;
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }
    return count;
  }
}
