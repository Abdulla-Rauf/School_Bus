import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/school_config_model.dart';
import '../../models/user_model.dart';
import '../../models/teacher_model.dart';

class SchoolConfigScreen extends StatefulWidget {
  const SchoolConfigScreen({super.key});

  @override
  _SchoolConfigScreenState createState() => _SchoolConfigScreenState();
}

class _SchoolConfigScreenState extends State<SchoolConfigScreen> {
  final List<TextEditingController> _subjectControllers = [];
  final List<SchoolClass> _classes = [];
  List<Teacher> _teachers = [];
  final _newSubjectController = TextEditingController();
  final _newClassNameController = TextEditingController();
  final _newDivisionController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _newSubjectController.dispose();
    _newClassNameController.dispose();
    _newDivisionController.dispose();
    for (var controller in _subjectControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    AuthService authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user = await authService.getCurrentUserData();
    setState(() {
      _currentUser = user;
    });
    await _loadSchoolConfig();
    await _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();
    List<Teacher> teachers = await dbService.getTeachers(_currentUser!.uid);
    setState(() {
      _teachers = teachers;
    });
  }

  Future<void> _loadSchoolConfig() async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();
    SchoolConfig? config = await dbService.getSchoolConfig(_currentUser!.uid);

    setState(() {
      if (config != null) {
        // Load existing configuration
        _classes.clear();
        _classes.addAll(config.classes);

        _subjectControllers.clear();
        _subjectControllers.addAll(
          config.subjects.map(
            (subject) => TextEditingController(text: subject),
          ),
        );
      } else {
        // Initialize with empty configuration
        _classes.clear();
        _subjectControllers.clear();
      }
      _isLoading = false;
    });
  }

  void _addSubject() {
    String newSubject = _newSubjectController.text.trim();
    if (newSubject.isNotEmpty) {
      setState(() {
        _subjectControllers.add(TextEditingController(text: newSubject));
        _newSubjectController.clear();
      });
    }
  }

  void _removeSubject(int index) {
    if (index >= 0 && index < _subjectControllers.length) {
      setState(() {
        _subjectControllers.removeAt(index);
      });
    }
  }

  void _addClass() {
    String className = _newClassNameController.text.trim();
    String division = _newDivisionController.text.trim().toUpperCase();

    if (className.isNotEmpty && division.isNotEmpty) {
      setState(() {
        // Check if class already exists
        int existingIndex = _classes.indexWhere(
          (c) => c.className == className,
        );

        if (existingIndex != -1) {
          // Check if division already exists
          if (!_classes[existingIndex].hasDivision(division)) {
            _classes[existingIndex].addDivision(division);
          }
        } else {
          // Create new class
          _classes.add(
            SchoolClass(
              className: className,
              divisions: [
                ClassDivision(
                  className: className,
                  division: division,
                  subjects: [],
                ),
              ],
            ),
          );
        }

        _newClassNameController.clear();
        _newDivisionController.clear();
      });
    }
  }

  void _removeClass(int index) {
    if (index >= 0 && index < _classes.length) {
      setState(() {
        _classes.removeAt(index);
      });
    }
  }

  void _removeDivision(int classIndex, String division) {
    if (classIndex >= 0 && classIndex < _classes.length) {
      setState(() {
        _classes[classIndex].removeDivision(division);
        // If class has no more divisions, remove the class
        if (_classes[classIndex].divisions.isEmpty) {
          _removeClass(classIndex);
        }
      });
    }
  }

  Future<void> _addSubjectToClassDivision(
    int classIndex,
    String division,
  ) async {
    if (_subjectControllers.isEmpty) {
      _showSnackbar('Please add some school subjects first', isError: true);
      return;
    }

    final availableSubjects = _subjectControllers
        .map((controller) => controller.text.trim())
        .where((subject) => subject.isNotEmpty)
        .toList();

    final currentDivision = _classes[classIndex].getDivision(division);
    final currentSubjects = currentDivision?.subjects ?? [];

    final selectedSubjects = await showDialog<List<String>>(
      context: context,
      builder: (context) => MultiSelectDialog(
        title: 'Select Subjects for ${_classes[classIndex].className}$division',
        items: availableSubjects,
        initialSelectedItems: currentSubjects,
      ),
    );

    if (selectedSubjects != null) {
      setState(() {
        final divisionIndex = _classes[classIndex].divisions.indexWhere(
          (div) => div.division == division,
        );

        if (divisionIndex != -1) {
          _classes[classIndex].divisions[divisionIndex] = ClassDivision(
            className: _classes[classIndex].className,
            division: division,
            subjects: selectedSubjects,
            teachers: _classes[classIndex].divisions[divisionIndex].teachers,
          );
        }
      });
    }
  }

  Future<void> _assignTeacherToClassDivision(
    int classIndex,
    String division,
  ) async {
    if (_teachers.isEmpty) {
      _showSnackbar(
        'No teachers available. Please add teachers first.',
        isError: true,
      );
      return;
    }

    final currentDivision = _classes[classIndex].getDivision(division);
    final currentTeacherIds = currentDivision?.teachers ?? [];

    // Get teacher names with IDs for display
    List<String> teacherDisplayNames = _teachers
        .map(
          (teacher) =>
              '${teacher.firstName} ${teacher.lastName} (${teacher.teacherId})',
        )
        .toList();

    // Get initial selected display names
    List<String> initialSelectedNames = currentTeacherIds.map((teacherId) {
      final teacher = _teachers.firstWhere(
        (t) => t.teacherId == teacherId,
        orElse: () => Teacher(
          teacherId: teacherId,
          firstName: 'Unknown',
          lastName: 'Teacher',
          gender: '',
          dateOfBirth: DateTime.now(),
          bloodGroup: '',
          phone: '',
          email: '',
          address: '',
          qualification: '',
          experience: 0,
          specialization: '',
          schoolId: '',
          schoolName: '',
          joiningDate: DateTime.now(),
          primaryClass: '',
          secondaryClasses: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      return '${teacher.firstName} ${teacher.lastName} (${teacher.teacherId})';
    }).toList();

    final selectedTeacherNames = await showDialog<List<String>>(
      context: context,
      builder: (context) => MultiSelectDialog(
        title: 'Assign Teachers to ${_classes[classIndex].className}$division',
        items: teacherDisplayNames,
        initialSelectedItems: initialSelectedNames,
      ),
    );

    if (selectedTeacherNames != null) {
      setState(() {
        final divisionIndex = _classes[classIndex].divisions.indexWhere(
          (div) => div.division == division,
        );

        if (divisionIndex != -1) {
          // Extract teacher IDs from selection
          List<String> teacherIds = selectedTeacherNames.map((teacherStr) {
            // Extract teacher ID from string like "John Doe (T001)"
            final match = RegExp(r'\((.*?)\)').firstMatch(teacherStr);
            return match?.group(1) ?? teacherStr;
          }).toList();

          _classes[classIndex].divisions[divisionIndex] = ClassDivision(
            className: _classes[classIndex].className,
            division: division,
            subjects: _classes[classIndex].divisions[divisionIndex].subjects,
            teachers: teacherIds,
          );
        }
      });
    }
  }

  void _removeSubjectFromClassDivision(
    int classIndex,
    String division,
    String subject,
  ) {
    setState(() {
      final divisionIndex = _classes[classIndex].divisions.indexWhere(
        (div) => div.division == division,
      );

      if (divisionIndex != -1) {
        final updatedSubjects = List<String>.from(
          _classes[classIndex].divisions[divisionIndex].subjects,
        )..remove(subject);

        _classes[classIndex].divisions[divisionIndex] = ClassDivision(
          className: _classes[classIndex].className,
          division: division,
          subjects: updatedSubjects,
          teachers: _classes[classIndex].divisions[divisionIndex].teachers,
        );
      }
    });
  }

  void _removeTeacherFromClassDivision(
    int classIndex,
    String division,
    String teacherId,
  ) {
    setState(() {
      final divisionIndex = _classes[classIndex].divisions.indexWhere(
        (div) => div.division == division,
      );

      if (divisionIndex != -1) {
        final updatedTeachers = List<String>.from(
          _classes[classIndex].divisions[divisionIndex].teachers,
        )..remove(teacherId);

        _classes[classIndex].divisions[divisionIndex] = ClassDivision(
          className: _classes[classIndex].className,
          division: division,
          subjects: _classes[classIndex].divisions[divisionIndex].subjects,
          teachers: updatedTeachers,
        );
      }
    });
  }

  Future<void> _saveConfiguration() async {
    if (_currentUser == null) return;

    setState(() => _isSaving = true);

    try {
      DatabaseService dbService = DatabaseService();

      // Extract subjects from controllers
      List<String> allSubjects = _subjectControllers
          .map((controller) => controller.text.trim())
          .where((subject) => subject.isNotEmpty)
          .toList();

      // Create school config
      SchoolConfig config = SchoolConfig(
        schoolId: _currentUser!.uid,
        classes: _classes,
        subjects: allSubjects,
        updatedAt: DateTime.now(),
      );

      bool success = await dbService.saveSchoolConfig(config);

      if (success) {
        _showSnackbar('School configuration saved successfully!');
      } else {
        _showSnackbar('Failed to save configuration', isError: true);
      }
    } catch (e) {
      _showSnackbar('Error: $e', isError: true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Helper method to get teacher name by ID
  String _getTeacherName(String teacherId) {
    final teacher = _teachers.firstWhere(
      (t) => t.teacherId == teacherId,
      orElse: () => Teacher(
        teacherId: teacherId,
        firstName: 'Unknown',
        lastName: 'Teacher',
        gender: '',
        dateOfBirth: DateTime.now(),
        bloodGroup: '',
        phone: '',
        email: '',
        address: '',
        qualification: '',
        experience: 0,
        specialization: '',
        schoolId: '',
        schoolName: '',
        joiningDate: DateTime.now(),
        primaryClass: '',
        secondaryClasses: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return '${teacher.firstName} ${teacher.lastName}';
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.black87, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  value.isNotEmpty ? value : 'Not provided',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard() {
    int totalDivisions = _classes.fold(
      0,
      (sum, schoolClass) => sum + schoolClass.divisions.length,
    );
    int totalAssignedTeachers = _classes.fold(
      0,
      (sum, schoolClass) => sum + schoolClass.getAllTeachers().length,
    );
    int uniqueAssignedSubjects = _classes
        .expand((c) => c.getAllSubjects())
        .toSet()
        .length;

    return GestureDetector(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black87, Colors.black54],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SCHOOL CONFIGURATION',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Class & Subject Setup',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.8,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Configure subjects and teachers per class division',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[300],
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[700],
                        ),
                        child: Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Container(height: 1.5, color: Colors.white.withOpacity(0.1)),
                  SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildStatCard(
                        'Classes',
                        '${_classes.length}',
                        Icons.class_,
                      ),
                      _buildStatCard(
                        'Divisions',
                        '$totalDivisions',
                        Icons.account_balance,
                      ),
                      _buildStatCard(
                        'Subjects',
                        '${_subjectControllers.length}',
                        Icons.menu_book,
                      ),
                      _buildStatCard(
                        'Teachers',
                        '${_teachers.length}',
                        Icons.people,
                      ),
                      _buildStatCard(
                        'Assigned\nSubjects',
                        '$uniqueAssignedSubjects',
                        Icons.assignment,
                      ),
                      _buildStatCard(
                        'Assigned\nTeachers',
                        '$totalAssignedTeachers',
                        Icons.group_add,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      // 1. Wrap the Column in a FittedBox
      child: FittedBox(
        fit: BoxFit.scaleDown, // Only shrinks if necessary
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsSection() {
    return _buildSection('School Subjects', [
      SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _newSubjectController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g., Mathematics, Science',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                  ),
                  onSubmitted: (_) => _addSubject(),
                  style: TextStyle(color: Colors.black87, fontSize: 15),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _addSubject,
              icon: Icon(Icons.add, color: Colors.white, size: 24),
              tooltip: 'Add Subject',
            ),
          ),
        ],
      ),
      SizedBox(height: 16),
      if (_subjectControllers.isEmpty)
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info, color: Colors.grey[600], size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No subjects added yet. Add some subjects for your school.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _subjectControllers.asMap().entries.map((entry) {
            int index = entry.key;
            TextEditingController controller = entry.value;
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.text,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _removeSubject(index),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      SizedBox(height: 8),
    ]);
  }

  Widget _buildClassesSection() {
    return _buildSection('Classes & Divisions', [
      SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _newClassNameController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Class number',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                  ),
                  keyboardType: TextInputType.text,
                  style: TextStyle(color: Colors.black87, fontSize: 15),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _newDivisionController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Division letter',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                  ),
                  keyboardType: TextInputType.text,
                  style: TextStyle(color: Colors.black87, fontSize: 15),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _addClass,
              icon: Icon(Icons.add, color: Colors.white, size: 24),
              tooltip: 'Add Class Division',
            ),
          ),
        ],
      ),
      SizedBox(height: 16),
      if (_classes.isEmpty)
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info, color: Colors.grey[600], size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No classes added yet. Add classes and divisions for your school.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        )
      else
        ..._classes.asMap().entries.map((entry) {
          int classIndex = entry.key;
          SchoolClass schoolClass = entry.value;

          return Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.class_,
                        color: Colors.black87,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Class ${schoolClass.className}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '${schoolClass.divisions.length} divisions',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.delete,
                          color: Colors.black87,
                          size: 20,
                        ),
                        onPressed: () => _removeClass(classIndex),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),

                // Each Division
                SizedBox(height: 20),
                ...schoolClass.divisions.map((division) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Division Header
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  division.division,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${schoolClass.className}${division.division}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                  fontSize: 16,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.black87,
                                ),
                                onPressed: () => _removeDivision(
                                  classIndex,
                                  division.division,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Subjects for this division
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'SUBJECTS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Spacer(),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => _addSubjectToClassDivision(
                                      classIndex,
                                      division.division,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            if (division.subjects.isEmpty)
                              Text(
                                'No subjects assigned',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: division.subjects.map((subject) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          subject,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () =>
                                              _removeSubjectFromClassDivision(
                                                classIndex,
                                                division.division,
                                                subject,
                                              ),
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),

                        SizedBox(height: 16),

                        // Teachers for this division
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'ASSIGNED TEACHERS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Spacer(),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    onPressed: () =>
                                        _assignTeacherToClassDivision(
                                          classIndex,
                                          division.division,
                                        ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            if (division.teachers.isEmpty)
                              Text(
                                'No teachers assigned',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: division.teachers.map((teacherId) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _getTeacherName(teacherId),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () =>
                                              _removeTeacherFromClassDivision(
                                                classIndex,
                                                division.division,
                                                teacherId,
                                              ),
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      SizedBox(height: 8),
    ]);
  }

  Widget _buildActionCard(
    IconData icon,
    String title,
    String subtitle, {
    Color? bgColor,
  }) {
    return Container(
      // REMOVED: height: 70,
      width: double.infinity, // Optional: Makes card take full width
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Important: Wraps height to content
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('School Configuration'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() {
                      _isLoading = true;
                    });
                    await _loadSchoolConfig();
                  },
            tooltip: 'Refresh',
          ),
        ],
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
                    'Loading configuration...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _currentUser == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.black38),
                  SizedBox(height: 16),
                  Text(
                    'Not authenticated',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please log in to continue',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _loadCurrentUser();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickCard(),
                    SizedBox(height: 40),

                    // Quick Info
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                      childAspectRatio: .8,
                      children: [
                        _buildActionCard(
                          Icons.menu_book,
                          'Subjects',
                          'Manage subjects',
                        ),
                        _buildActionCard(
                          Icons.class_,
                          'Classes',
                          'Add classes',
                        ),
                        _buildActionCard(
                          Icons.account_balance,
                          'Divisions',
                          'Create divisions',
                        ),
                        _buildActionCard(
                          Icons.people,
                          'Teachers',
                          'Assign teachers',
                        ),
                        _buildActionCard(
                          Icons.assignment,
                          'Assign',
                          'Subjects & Teachers',
                        ),
                        _buildActionCard(
                          Icons.save,
                          'Save',
                          'Save configuration',
                        ),
                      ],
                    ),

                    SizedBox(height: 32),
                    _buildSubjectsSection(),
                    SizedBox(height: 20),
                    _buildClassesSection(),

                    SizedBox(height: 32),

                    // Save Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Icon(Icons.save, color: Colors.white, size: 22),
                        label: _isSaving
                            ? Text(
                                'SAVING...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              )
                            : Text(
                                'SAVE CONFIGURATION',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                        onPressed: _isSaving ? null : _saveConfiguration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Info Box
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.lightbulb,
                              color: Colors.black87,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Tip: Add subjects first, then assign them to specific class divisions. Teachers can be assigned to multiple divisions.',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

class MultiSelectDialog extends StatefulWidget {
  final String title;
  final List<String> items;
  final List<String> initialSelectedItems;

  const MultiSelectDialog({
    super.key,
    required this.title,
    required this.items,
    this.initialSelectedItems = const [],
  });

  @override
  _MultiSelectDialogState createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  late List<String> _selectedItems;

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.initialSelectedItems);
  }

  Widget _buildListItem(String item) {
    bool isSelected = _selectedItems.contains(item);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedItems.remove(item);
          } else {
            _selectedItems.add(item);
          }
        });
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.grey[300]!,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 14, color: Colors.black87)
                  : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Icon(Icons.list, color: Colors.black87, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.items.map(_buildListItem).toList(),
                ),
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text('CANCEL'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _selectedItems),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('SAVE'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
