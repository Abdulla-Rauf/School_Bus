// lib/screens/calendar/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../models/calendar_model.dart';
import '../../../../models/school_config_model.dart';
import '../../../../models/teacher_model.dart';
import '../../../../models/user_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/database_service.dart';
import '../setup/calendar_setup_screen.dart';
import 'add_event_dialog.dart';
import 'widgets/event_details_dialog.dart';
import 'widgets/setup_calendar_view.dart';
import 'widgets/filter_widget.dart';
import 'widgets/event_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  late Map<DateTime, List<CalendarEvent>> _events;
  SchoolCalendar? _schoolCalendar;
  bool _isLoading = true;
  UserModel? _currentUser;
  Teacher? _teacherDetails;
  SchoolConfig? _schoolConfig;
  List<String> _teacherClasses = [];
  List<String> _availableClasses = [];
  List<CalendarEvent> _filteredEvents = [];
  String? _classFilter;
  String? _schoolId;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _events = {};
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    AuthService authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user = await authService.getCurrentUserData();

    setState(() {
      _currentUser = user;
    });

    if (user != null) {
      _schoolId = user.schoolId;

      if (_schoolId == null || _schoolId!.isEmpty) {
        if (user.role == 'teacher') {
          await _getSchoolIdFromTeacherDocument(user);
        } else if (user.role == 'school') {
          _schoolId = user.uid;
        }
      }

      if (_schoolId != null && _schoolId!.isNotEmpty) {
        await _loadSchoolConfig();
        if (user.role == 'teacher') {
          await _loadTeacherDetails();
        }
        await _loadSchoolCalendar();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getSchoolIdFromTeacherDocument(UserModel user) async {
    try {
      DatabaseService dbService = DatabaseService();
      Teacher? teacher = await dbService.getTeacherById(
        user.specificId ?? user.uid,
      );

      if (teacher != null && teacher.schoolId.isNotEmpty) {
        setState(() {
          _schoolId = teacher.schoolId;
        });
      }
    } catch (e) {
      print('❌ Error getting school ID from teacher: $e');
    }
  }

  Future<void> _loadTeacherDetails() async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();
    Teacher? teacher = await dbService.getTeacherById(
      _currentUser!.specificId ?? _currentUser!.uid,
    );

    if (teacher != null) {
      setState(() {
        _teacherDetails = teacher;
        _teacherClasses = [
          teacher.primaryClass,
          ...teacher.secondaryClasses,
        ].where((c) => c.isNotEmpty).toList();
      });

      if ((_schoolId == null || _schoolId!.isEmpty) &&
          teacher.schoolId.isNotEmpty) {
        setState(() {
          _schoolId = teacher.schoolId;
        });
      }
    }
  }

  Future<void> _loadSchoolConfig() async {
    if (_schoolId == null || _schoolId!.isEmpty) return;

    DatabaseService dbService = DatabaseService();
    SchoolConfig? config = await dbService.getSchoolConfig(_schoolId!);

    if (config != null) {
      List<String> allClasses = await dbService.getAvailableClasses(_schoolId!);
      setState(() {
        _schoolConfig = config;
        _availableClasses = allClasses;
      });
    }
  }

  Future<void> _loadSchoolCalendar() async {
    if (_schoolId == null || _schoolId!.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    DatabaseService dbService = DatabaseService();
    SchoolCalendar? calendar = await dbService.getSchoolCalendar(_schoolId!);

    if (calendar != null) {
      List<CalendarEvent> filteredEvents;

      if (_currentUser?.role == 'teacher') {
        filteredEvents = await dbService.getEventsForTeacher(
          _schoolId!,
          _teacherClasses,
        );
      } else {
        filteredEvents = calendar.events;
      }

      if (_classFilter != null && _classFilter != 'All') {
        filteredEvents = filteredEvents.where((event) {
          return event.affectsClass(_classFilter!);
        }).toList();
      }

      setState(() {
        _schoolCalendar = calendar;
        _filteredEvents = filteredEvents;
        _updateEvents();
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _updateEvents() {
    _events = {};
    if (_schoolCalendar != null) {
      for (var event in _filteredEvents) {
        final days = _getDaysInRange(event.startDate, event.endDate);
        for (final day in days) {
          final key = DateTime(day.year, day.month, day.day);
          if (_events[key] == null) {
            _events[key] = [];
          }
          _events[key]!.add(event);
        }
      }
    }
  }

  List<DateTime> _getDaysInRange(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  List<CalendarEvent> _getEventsForMonth(DateTime month) {
    if (_schoolCalendar == null) return [];

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    final monthEvents = <CalendarEvent>[];
    final seenEventIds = <String>{};

    for (var event in _filteredEvents) {
      if (event.startDate.isBefore(monthEnd) &&
          event.endDate.isAfter(monthStart)) {
        if (!seenEventIds.contains(event.id)) {
          monthEvents.add(event);
          seenEventIds.add(event.id);
        }
      }
    }

    monthEvents.sort((a, b) => a.startDate.compareTo(b.startDate));
    return monthEvents;
  }

  void _showAddEventDialog() {
    if (_schoolId == null || _schoolId!.isEmpty) {
      _showSnackBar('Cannot add event: School ID not found', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddEventDialog(
        user: _currentUser!,
        teacher: _teacherDetails,
        schoolConfig: _schoolConfig,
        teacherClasses: _teacherClasses,
        onEventAdded: (event) => _addEvent(event),
        schoolCalendar: _schoolCalendar,
      ),
    );
  }

  void _showEventDetails(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (context) => EventDetailsDialog(
        event: event,
        currentUser: _currentUser!,
        onEdit: () => _editEvent(event),
        onDelete: () => _deleteEvent(event),
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _addEvent(CalendarEvent event) async {
    if (_currentUser == null || _schoolId == null || _schoolId!.isEmpty) {
      _showSnackBar(
        'Cannot add event: User or school ID not found',
        isError: true,
      );
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    DatabaseService dbService = DatabaseService();

    bool success = await dbService.addCalendarEventWithCreator(
      _schoolId!,
      event,
      createdBy: _currentUser!.role == 'teacher' ? 'teacher' : 'school',
      creatorId: _currentUser!.specificId,
      creatorName: _currentUser!.name,
    );

    if (success) {
      _showSnackBar('Event added successfully!');
      await _loadSchoolCalendar();
    } else {
      _showSnackBar('Failed to add event', isError: true);
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    if (_currentUser == null || _schoolCalendar == null || _schoolId == null) {
      _showSnackBar('Cannot delete event', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    DatabaseService dbService = DatabaseService();

    List<CalendarEvent> events = List.from(_schoolCalendar!.events)
      ..removeWhere((e) => e.id == event.id);

    SchoolCalendar updatedCalendar = SchoolCalendar(
      schoolId: _schoolCalendar!.schoolId,
      academicYear: _schoolCalendar!.academicYear,
      academicYearStart: _schoolCalendar!.academicYearStart,
      academicYearEnd: _schoolCalendar!.academicYearEnd,
      events: events,
      workingDays: _schoolCalendar!.workingDays,
      createdAt: _schoolCalendar!.createdAt,
      updatedAt: DateTime.now(),
    );

    bool success = await dbService.saveSchoolCalendar(updatedCalendar);

    if (success) {
      _showSnackBar('Event deleted successfully!');
      await _loadSchoolCalendar();
      Navigator.pop(context);
    } else {
      _showSnackBar('Failed to delete event', isError: true);
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _editEvent(CalendarEvent event) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AddEventDialog(
        user: _currentUser!,
        teacher: _teacherDetails,
        schoolConfig: _schoolConfig,
        teacherClasses: _teacherClasses,
        onEventAdded: (updatedEvent) => _updateEvent(event, updatedEvent),
        existingEvent: event,
        schoolCalendar: _schoolCalendar,
      ),
    );
  }

  Future<void> _updateEvent(
    CalendarEvent oldEvent,
    CalendarEvent updatedEvent,
  ) async {
    if (_currentUser == null || _schoolId == null || _schoolId!.isEmpty) {
      _showSnackBar('Cannot update event', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    DatabaseService dbService = DatabaseService();

    final event = CalendarEvent(
      id: oldEvent.id,
      title: updatedEvent.title,
      description: updatedEvent.description,
      type: updatedEvent.type,
      startDate: updatedEvent.startDate,
      endDate: updatedEvent.endDate,
      isFullDay: updatedEvent.isFullDay,
      affectedClasses: updatedEvent.affectedClasses,
      createdBy: oldEvent.createdBy,
      creatorId: oldEvent.creatorId,
      creatorName: oldEvent.creatorName,
      color: updatedEvent.color,
      createdAt: oldEvent.createdAt,
      updatedAt: DateTime.now(),
    );

    bool success = await dbService.addCalendarEventWithCreator(
      _schoolId!,
      event,
      createdBy: oldEvent.createdBy,
      creatorId: oldEvent.creatorId,
      creatorName: oldEvent.creatorName,
    );

    if (success) {
      _showSnackBar('Event updated successfully!');
      await _loadSchoolCalendar();
    } else {
      _showSnackBar('Failed to update event', isError: true);
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatMonth(DateTime date) {
    return '${_getMonthName(date.month)} ${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Widget _buildEventList() {
    final monthEvents = _getEventsForMonth(_focusedDay);

    if (monthEvents.isEmpty) {
      return _buildEmptyEventsView();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: monthEvents.length,
      itemBuilder: (context, index) {
        final event = monthEvents[index];
        return EventCard(
          event: event,
          currentUser: _currentUser!,
          onTap: () => _showEventDetails(event),
          onEdit: () => _editEvent(event),
          onDelete: () => _deleteEvent(event),
        );
      },
    );
  }

  Widget _buildEmptyEventsView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Icon(Icons.event_note_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No events for ${_formatMonth(_focusedDay)}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_classFilter != null && _classFilter != 'All')
            Text(
              'Filter: $_classFilter',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          if (_currentUser?.role == 'teacher' && _teacherClasses.isEmpty)
            Text(
              'No classes assigned to teacher',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _currentUser?.role == 'teacher' ? 'My Calendar' : 'School Calendar',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_availableClasses.isNotEmpty || _teacherClasses.isNotEmpty)
            FilterWidget(
              currentUser: _currentUser,
              availableClasses: _availableClasses,
              teacherClasses: _teacherClasses,
              classFilter: _classFilter,
              onFilterChanged: (newValue) {
                setState(() {
                  _classFilter = newValue;
                  _loadSchoolCalendar();
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddEventDialog,
            tooltip: 'Add Event',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchoolCalendar,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _schoolCalendar == null
          ? SetupCalendarView(
              currentUser: _currentUser,
              onSetupPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CalendarSetupScreen(),
                  ),
                ).then((_) => _loadSchoolCalendar());
              },
            )
          : _buildCalendarBody(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading calendar...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_schoolId != null)
            Text(
              'School ID: $_schoolId',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarBody() {
    return Column(
      children: [
        if (_classFilter != null) _buildFilterInfo(),

        _buildCalendarCard(),

        _buildMonthEventsHeader(),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _buildEventList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterInfo() {
    return Container(
      color: Colors.blue[50],
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing events for: $_classFilter',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _classFilter = null;
                _loadSchoolCalendar();
              });
            },
            child: const Text('Clear', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TableCalendar(
          firstDay: _schoolCalendar!.academicYearStart,
          lastDay: _schoolCalendar!.academicYearEnd,
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          eventLoader: _getEventsForDay,
          calendarStyle: CalendarStyle(
            defaultDecoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
            weekendDecoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            outsideDecoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            defaultTextStyle: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            weekendTextStyle: const TextStyle(color: Colors.black54),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            todayTextStyle: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
            outsideTextStyle: TextStyle(
              color: Colors.grey[400],
              fontWeight: FontWeight.w400,
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            formatButtonDecoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            formatButtonTextStyle: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
            titleTextStyle: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon: const Icon(
              Icons.chevron_left,
              color: Colors.black87,
            ),
            rightChevronIcon: const Icon(
              Icons.chevron_right,
              color: Colors.black87,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            weekendStyle: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return const SizedBox.shrink();

              final dayEvents = _getEventsForDay(date);
              if (dayEvents.isEmpty) return const SizedBox.shrink();

              return Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dayEvents.first.getEventColor(),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMonthEventsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Events for ${_formatMonth(_focusedDay)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_getEventsForMonth(_focusedDay).length} events',
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
