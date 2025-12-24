// assignment_creation_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:school_bus2/models/teacher_model.dart';
import 'package:school_bus2/models/student_model.dart';
import 'package:school_bus2/models/assignment_model.dart';
import 'package:school_bus2/services/database_service.dart';
import 'assignment_summary_screen.dart';

class AssignmentCreationScreen extends StatefulWidget {
  final Teacher teacher;
  final String selectedClass;

  const AssignmentCreationScreen({
    super.key,
    required this.teacher,
    required this.selectedClass,
  });

  @override
  State<AssignmentCreationScreen> createState() =>
      _AssignmentCreationScreenState();
}

class _AssignmentCreationScreenState extends State<AssignmentCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _dueTimeController = TextEditingController();

  List<Student> _students = [];
  List<Student> _selectedStudents = [];
  bool _isLoading = true;
  bool _assignToAll = true;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseService();
      _students = await db.getStudentsByClass(widget.selectedClass);

      final schoolConfig = await db.getSchoolConfig(widget.teacher.schoolId);
      if (schoolConfig != null) {
        for (var schoolClass in schoolConfig.classes) {
          if (widget.selectedClass.startsWith(schoolClass.className)) {
            final division = widget.selectedClass.replaceAll(
              schoolClass.className,
              '',
            );
            final classDivision = schoolClass.getDivision(division);
            if (classDivision != null && classDivision.subjects.isNotEmpty) {
              _selectedSubject ??= classDivision.subjects.first;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading students: $e');
      _showErrorSnackbar('Error loading students');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _dueDate ?? now.add(const Duration(days: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black87,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _dueDate = pickedDate;
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  Future<void> _selectDueTime(BuildContext context) async {
    final initialTime = _dueTime ?? const TimeOfDay(hour: 23, minute: 59);

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.black87,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _dueTime = pickedTime;
        _dueTimeController.text = pickedTime.format(context);
      });
    }
  }

  void _toggleStudentSelection(Student student) {
    setState(() {
      if (_selectedStudents.contains(student)) {
        _selectedStudents.remove(student);
      } else {
        _selectedStudents.add(student);
      }
    });
  }

  void _selectAllStudents() {
    setState(() {
      _selectedStudents = List.from(_students);
    });
  }

  void _deselectAllStudents() {
    setState(() {
      _selectedStudents.clear();
    });
  }

  Future<void> _createAssignment() async {
    // First validate the form
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackbar('Please fill in all required fields');
      return;
    }

    // Check if due date and time are selected
    if (_dueDate == null || _dueTime == null) {
      _showErrorSnackbar('Please select due date and time');
      return;
    }

    // Check if specific students are selected when needed
    if (!_assignToAll && _selectedStudents.isEmpty) {
      _showErrorSnackbar('Please select at least one student');
      return;
    }

    // Create dueDateTime
    final dueDateTime = DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      _dueTime!.hour,
      _dueTime!.minute,
    );

    // Validate due date is in the future
    if (dueDateTime.isBefore(DateTime.now())) {
      _showErrorSnackbar('Due date must be in the future');
      return;
    }

    try {
      final db = DatabaseService();
      final assignmentId = db.generateId(prefix: 'assign_');

      final studentIds = _assignToAll
          ? _students.map((s) => s.studentId).toList()
          : _selectedStudents.map((s) => s.studentId).toList();

      final assignment = Assignment(
        assignmentId: assignmentId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        classId: widget.selectedClass,
        createdBy: widget.teacher.teacherId,
        dueDate: dueDateTime,
        attachments: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await db.createAssignment(assignment);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AssignmentSummaryScreen(
            assignment: assignment,
            studentCount: studentIds.length,
            assignedToAll: _assignToAll,
          ),
        ),
      );
    } catch (e) {
      print('Error creating assignment: $e');
      _showErrorSnackbar('Error creating assignment');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildAssignmentTypeSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assignment Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AssignmentTypeCard(
                  title: 'Entire Class',
                  subtitle: 'Assign to all students',
                  icon: Icons.groups,
                  isSelected: _assignToAll,
                  onTap: () => setState(() => _assignToAll = true),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _AssignmentTypeCard(
                  title: 'Specific Students',
                  subtitle: 'Select individual students',
                  icon: Icons.person,
                  isSelected: !_assignToAll,
                  onTap: () => setState(() => _assignToAll = false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentDetailsSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assignment Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),

          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Assignment Title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Color(0xFFE0E0E0)),
              ),
              prefixIcon: Icon(Icons.title, color: Colors.black87),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.black87, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter assignment title';
              }
              return null;
            },
            maxLength: 100,
          ),
          SizedBox(height: 16),

          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Color(0xFFE0E0E0)),
              ),
              prefixIcon: Icon(Icons.description, color: Colors.black87),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.black87, width: 2),
              ),
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter assignment description';
              }
              return null;
            },
            maxLines: 4,
            maxLength: 1000,
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dueDateController,
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    prefixIcon: Icon(
                      Icons.calendar_today,
                      color: Colors.black87,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.black87, width: 2),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _selectDueDate(context),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select due date';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _dueTimeController,
                  decoration: InputDecoration(
                    labelText: 'Due Time',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    prefixIcon: Icon(Icons.access_time, color: Colors.black87),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.black87, width: 2),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _selectDueTime(context),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select due time';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          if (_dueDate != null && _dueTime != null) _buildUrgentWarning(),
        ],
      ),
    );
  }

  Widget _buildUrgentWarning() {
    final dueDateTime = DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      _dueTime!.hour,
      _dueTime!.minute,
    );
    final hoursUntilDue = dueDateTime.difference(DateTime.now()).inHours;

    if (hoursUntilDue <= 48) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'This assignment is due in less than 48 hours!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildStudentSelectionSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Students (${_selectedStudents.length}/${_students.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _selectAllStudents,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                    ),
                    child: Text(
                      'Select All',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(width: 8),
                  TextButton(
                    onPressed: _deselectAllStudents,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                    ),
                    child: Text(
                      'Deselect All',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),

          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.builder(
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                final isSelected = _selectedStudents.contains(student);

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black87 : Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.person,
                        color: isSelected ? Colors.white : Colors.black87,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      student.fullName,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      student.admissionNumber,
                      style: TextStyle(
                        color: isSelected ? Colors.black87 : Color(0xFF757575),
                      ),
                    ),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black87 : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? Colors.black87
                              : Color(0xFFE0E0E0),
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    onTap: () => _toggleStudentSelection(student),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          // Call the method directly instead of passing the reference
          _createAssignment();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Create Assignment',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Create Assignment',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
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
                  SizedBox(height: 20),
                  Text(
                    'Loading students...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Form(
                key: _formKey, // Add the form key here
                child: Column(
                  children: [
                    SizedBox(height: 8),
                    _buildAssignmentTypeSection(),
                    _buildAssignmentDetailsSection(),
                    if (!_assignToAll) _buildStudentSelectionSection(),
                    _buildCreateButton(),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    _dueTimeController.dispose();
    super.dispose();
  }
}

class _AssignmentTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AssignmentTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.black87 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? Colors.black87 : Color(0xFFE0E0E0),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: isSelected ? Colors.black87 : Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.grey[300] : Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
