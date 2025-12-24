// lib/screens/calendar/setup/calendar_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/database_service.dart';
import '../../../../services/auth_service.dart';
import '../../../../models/calendar_model.dart';
import '../../../../models/user_model.dart';
import 'widgets/academic_year_form.dart';
import 'widgets/date_range_section.dart';
import 'widgets/academic_year_stats.dart';
import 'widgets/working_days_section.dart';

class CalendarSetupScreen extends StatefulWidget {
  const CalendarSetupScreen({super.key});

  @override
  _CalendarSetupScreenState createState() => _CalendarSetupScreenState();
}

class _CalendarSetupScreenState extends State<CalendarSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _academicYearController = TextEditingController();

  DateTime _academicYearStart = DateTime.now();
  DateTime _academicYearEnd = DateTime.now().add(const Duration(days: 365));
  final List<WorkingDay> _workingDays = [];
  bool _isLoading = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _initializeWorkingDays();
  }

  @override
  void dispose() {
    _academicYearController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    AuthService authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user = await authService.getCurrentUserData();
    setState(() {
      _currentUser = user;
    });
  }

  void _initializeWorkingDays() {
    _workingDays.clear();
    for (int i = 1; i <= 7; i++) {
      _workingDays.add(WorkingDay(dayOfWeek: i, isWorkingDay: i <= 5));
    }
  }

  void _toggleWorkingDay(int dayOfWeek) {
    setState(() {
      int index = _workingDays.indexWhere((day) => day.dayOfWeek == dayOfWeek);
      if (index != -1) {
        _workingDays[index] = WorkingDay(
          dayOfWeek: dayOfWeek,
          isWorkingDay: !_workingDays[index].isWorkingDay,
        );
      }
    });
  }

  void _updateStartDate(DateTime date) {
    setState(() {
      _academicYearStart = date;
    });
  }

  void _updateEndDate(DateTime date) {
    setState(() {
      _academicYearEnd = date;
    });
  }

  Future<void> _saveCalendar() async {
    if (_formKey.currentState!.validate() && _currentUser != null) {
      setState(() => _isLoading = true);

      try {
        DatabaseService dbService = DatabaseService();

        SchoolCalendar calendar = SchoolCalendar(
          schoolId: _currentUser!.uid,
          academicYear: _academicYearController.text.trim(),
          academicYearStart: _academicYearStart,
          academicYearEnd: _academicYearEnd,
          events: [],
          workingDays: _workingDays,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        bool success = await dbService.saveSchoolCalendar(calendar);

        if (success) {
          _showSuccessSnackBar();
          Navigator.pop(context);
        } else {
          _showErrorSnackBar('Failed to setup calendar');
        }
      } catch (e) {
        _showErrorSnackBar('Error: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Academic calendar setup successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Academic Calendar')),
      body: _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : _buildSetupBody(),
    );
  }

  Widget _buildSetupBody() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Academic Year Form
              AcademicYearForm(controller: _academicYearController),
              const SizedBox(height: 16),

              // Date Range
              DateRangeSection(
                startDate: _academicYearStart,
                endDate: _academicYearEnd,
                onStartDateChanged: _updateStartDate,
                onEndDateChanged: _updateEndDate,
              ),
              const SizedBox(height: 16),

              // Academic Year Statistics
              AcademicYearStats(
                startDate: _academicYearStart,
                endDate: _academicYearEnd,
                workingDays: _workingDays,
              ),
              const SizedBox(height: 16),

              // Working Days
              WorkingDaysSection(
                workingDays: _workingDays,
                onToggleWorkingDay: _toggleWorkingDay,
              ),
              const SizedBox(height: 20),

              // Save Button
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveCalendar,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Save Academic Calendar',
                style: TextStyle(fontSize: 16),
              ),
      ),
    );
  }
}
