// grade_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_bus2/services/auth_service.dart';
import 'package:school_bus2/services/database_service.dart';
import 'package:school_bus2/models/teacher_model.dart';
import 'package:school_bus2/models/school_config_model.dart';
import 'grades_entry_screen.dart';

class GradeSelectionScreen extends StatefulWidget {
  const GradeSelectionScreen({super.key});

  @override
  _GradeSelectionScreenState createState() => _GradeSelectionScreenState();
}

class _GradeSelectionScreenState extends State<GradeSelectionScreen> {
  final DatabaseService _db = DatabaseService();
  Teacher? _teacher;
  SchoolConfig? _schoolConfig;
  List<String> _availableClasses = [];
  final Map<String, List<String>> _classSubjects = {};
  String? _selectedClass;
  String? _selectedSubject;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = await auth.getCurrentUserData();

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      _teacher = await _db.getTeacherById(user.specificId ?? user.uid);

      if (_teacher != null) {
        _schoolConfig = await _db.getSchoolConfig(_teacher!.schoolId);

        if (_schoolConfig != null) {
          _availableClasses = [];

          if (_teacher!.primaryClass.isNotEmpty) {
            _availableClasses.add(_teacher!.primaryClass);
          }

          _availableClasses.addAll(
            _teacher!.secondaryClasses.where((c) => c.isNotEmpty),
          );
          _availableClasses = _availableClasses.toSet().toList()..sort();

          for (var className in _availableClasses) {
            final subjects = await _getSubjectsForClass(className);
            _classSubjects[className] = subjects;
          }

          if (_availableClasses.isNotEmpty) {
            _selectedClass = _availableClasses.first;
            if (_classSubjects[_selectedClass]!.isNotEmpty) {
              _selectedSubject = _classSubjects[_selectedClass]!.first;
            }
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading teacher data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data'),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<List<String>> _getSubjectsForClass(String className) async {
    try {
      if (_teacher == null || _schoolConfig == null) return [];

      final baseClassName = className.replaceAll(RegExp(r'[A-Z]$'), '');

      for (var schoolClass in _schoolConfig!.classes) {
        if (schoolClass.className == baseClassName) {
          Set<String> allSubjects = {};
          for (var division in schoolClass.divisions) {
            allSubjects.addAll(division.subjects);
          }
          return allSubjects.toList()..sort();
        }
      }
    } catch (e) {
      print('Error getting subjects for class: $e');
    }
    return [];
  }

  Widget _buildClassCard(String className) {
    final isSelected = _selectedClass == className;
    final subjects = _classSubjects[className] ?? [];

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
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
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _selectedClass = className;
              if (subjects.isNotEmpty) {
                _selectedSubject = subjects.first;
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black87 : Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          className,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Class $className',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: Colors.black87, size: 24),
                  ],
                ),
                if (subjects.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(height: 1, color: Color(0xFFEEEEEE)),
                  SizedBox(height: 12),
                  Text(
                    'Available Subjects:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF757575),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: subjects.map((subject) {
                      final isSubjectSelected =
                          isSelected && _selectedSubject == subject;
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSubjectSelected
                              ? Colors.black87
                              : Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSubjectSelected
                                ? Colors.black87
                                : Color(0xFFE0E0E0),
                            width: isSubjectSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          subject,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSubjectSelected
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: isSubjectSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectGrid() {
    if (_selectedClass == null || _classSubjects[_selectedClass] == null) {
      return Container();
    }

    final subjects = _classSubjects[_selectedClass]!;

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        final isSelected = _selectedSubject == subject;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() => _selectedSubject = subject);
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black87 : Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getSubjectIcon(subject),
                        size: 24,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      subject,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isSelected ? Colors.black87 : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isSelected) SizedBox(height: 6),
                    if (isSelected)
                      Icon(Icons.check_circle, color: Colors.black87, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getSubjectIcon(String subject) {
    final subjectLower = subject.toLowerCase();

    if (subjectLower.contains('math')) return Icons.calculate;
    if (subjectLower.contains('science')) return Icons.science;
    if (subjectLower.contains('english')) return Icons.language;
    if (subjectLower.contains('history') || subjectLower.contains('social')) {
      return Icons.history_edu;
    }
    if (subjectLower.contains('geography')) return Icons.public;
    if (subjectLower.contains('computer')) return Icons.computer;
    if (subjectLower.contains('art') || subjectLower.contains('drawing')) {
      return Icons.brush;
    }
    if (subjectLower.contains('music')) return Icons.music_note;
    if (subjectLower.contains('physical') || subjectLower.contains('pe')) {
      return Icons.sports;
    }

    return Icons.book;
  }

  void _navigateToGradeEntry() {
    if (_teacher == null ||
        _selectedClass == null ||
        _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a class and subject'),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradesEntryScreen(
          teacher: _teacher!,
          selectedClass: _selectedClass!,
          selectedSubject: _selectedSubject!,
        ),
      ),
    );
  }

  Widget _buildTeacherCard() {
    if (_teacher == null) return SizedBox();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Icon(Icons.person, size: 28, color: Colors.white),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TEACHER',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _teacher!.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Grades Management',
                    style: TextStyle(fontSize: 13, color: Colors.grey[300]),
                  ),
                ],
              ),
            ),
          ],
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
          'Grades Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
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
                    'Loading your classes...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _teacher == null || _availableClasses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.class_outlined, size: 64, color: Colors.black38),
                  SizedBox(height: 16),
                  Text(
                    'No classes assigned',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Contact school administration',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadTeacherData,
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
          : Column(
              children: [
                SizedBox(height: 8),
                _buildTeacherCard(),
                SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Class',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Choose a class to enter grades',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF757575),
                          ),
                        ),
                        SizedBox(height: 20),

                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _availableClasses.length,
                          itemBuilder: (context, index) {
                            return _buildClassCard(_availableClasses[index]);
                          },
                        ),

                        if (_selectedClass != null) ...[
                          SizedBox(height: 32),

                          Text(
                            'Select Subject',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose subject for Class $_selectedClass',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF757575),
                            ),
                          ),
                          SizedBox(height: 20),

                          _buildSubjectGrid(),

                          SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _navigateToGradeEntry,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black87,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_forward, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Enter Grades',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 40),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
