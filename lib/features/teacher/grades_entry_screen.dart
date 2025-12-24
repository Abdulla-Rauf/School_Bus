import 'package:flutter/material.dart';

import 'package:school_bus2/services/database_service.dart';
import 'package:school_bus2/models/student_model.dart';
import 'package:school_bus2/models/teacher_model.dart';
import 'package:school_bus2/models/grade_model.dart';

class GradesEntryScreen extends StatefulWidget {
  final Teacher teacher;
  final String selectedClass;
  final String selectedSubject;

  const GradesEntryScreen({
    super.key,
    required this.teacher,
    required this.selectedClass,
    required this.selectedSubject,
  });

  @override
  _GradesEntryScreenState createState() => _GradesEntryScreenState();
}

class _GradesEntryScreenState extends State<GradesEntryScreen> {
  final DatabaseService _db = DatabaseService();
  List<Student> _students = [];
  final Map<String, GradeEntry> _gradeEntries = {};
  final Map<String, Grade?> _existingGrades = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String _examType = 'Quiz';
  String _term = 'Term 1';
  int _maxMarks = 100;
  int _academicYear = DateTime.now().year;
  final TextEditingController _maxMarksController = TextEditingController();

  final List<String> _examTypes = [
    'Quiz',
    'Class Test',
    'Unit Test',
    'Midterm',
    'Final',
    'Assignment',
    'Project',
    'Practical',
  ];

  final List<String> _terms = ['Term 1', 'Term 2', 'Term 3', 'Annual'];

  @override
  void initState() {
    super.initState();
    _maxMarksController.text = _maxMarks.toString();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _students = await _db.getStudentsByClass(widget.selectedClass);

      final existingGrades = await _db.getGradesByClassAndSubject(
        widget.selectedClass,
        widget.selectedSubject,
      );

      for (var grade in existingGrades) {
        _existingGrades[grade.studentId] = grade;

        if (!_gradeEntries.containsKey(grade.studentId)) {
          _gradeEntries[grade.studentId] = GradeEntry(
            obtainedMarks: grade.obtainedMarks,
            maxMarks: grade.maxMarks,
            comments: grade.comments ?? '',
          );
        }
      }

      for (var student in _students) {
        if (!_gradeEntries.containsKey(student.studentId)) {
          _gradeEntries[student.studentId] = GradeEntry(
            obtainedMarks: 0,
            maxMarks: _maxMarks,
            comments: '',
          );
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading data: $e');
      _showErrorSnackbar('Error loading students');
      setState(() => _isLoading = false);
    }
  }

  void _updateMaxMarksForAll() {
    final newMaxMarks = int.tryParse(_maxMarksController.text) ?? 100;
    if (newMaxMarks > 0) {
      setState(() {
        _maxMarks = newMaxMarks;
        for (var entry in _gradeEntries.entries) {
          entry.value.maxMarks = _maxMarks;
          if (entry.value.obtainedMarks > _maxMarks) {
            entry.value.obtainedMarks = _maxMarks;
          }
        }
      });
    }
  }

  Future<void> _saveGrades() async {
    setState(() => _isSaving = true);

    try {
      int savedCount = 0;
      int skippedCount = 0;

      for (var student in _students) {
        final entry = _gradeEntries[student.studentId];

        if (entry == null || entry.obtainedMarks == 0) {
          skippedCount++;
          continue;
        }

        final existingGrade = _existingGrades[student.studentId];
        final isNewEntry =
            existingGrade == null ||
            existingGrade.examType != _examType ||
            existingGrade.term != _term;

        if (isNewEntry) {
          final grade = Grade.create(
            studentId: student.studentId,
            studentName: student.fullName,
            admissionNumber: student.admissionNumber,
            classId: widget.selectedClass,
            className: widget.selectedClass,
            subject: widget.selectedSubject,
            teacherId: widget.teacher.teacherId,
            teacherName: widget.teacher.name,
            schoolId: widget.teacher.schoolId,
            examType: _examType,
            term: _term,
            academicYear: _academicYear,
            maxMarks: entry.maxMarks,
            obtainedMarks: entry.obtainedMarks,
            comments: entry.comments.isNotEmpty ? entry.comments : null,
          );

          await _db.saveGrade(grade);
          savedCount++;
        } else {
          final updatedGrade = existingGrade.updateMarks(
            entry.obtainedMarks,
            entry.maxMarks,
            newComments: entry.comments.isNotEmpty
                ? entry.comments
                : existingGrade.comments,
          );

          await _db.saveGrade(updatedGrade);
          savedCount++;
        }
      }

      _showSuccessSnackbar(
        '✅ $savedCount grades saved successfully${skippedCount > 0 ? ', $skippedCount skipped' : ''}',
      );
      await _loadData();
    } catch (e) {
      print('Error saving grades: $e');
      _showErrorSnackbar('❌ Error saving grades');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildStudentGradeRow(Student student, int index) {
    final entry = _gradeEntries[student.studentId];
    final existingGrade = _existingGrades[student.studentId];
    final hasExistingGrade =
        existingGrade != null &&
        existingGrade.examType == _examType &&
        existingGrade.term == _term;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasExistingGrade ? Colors.black87 : Color(0xFFE0E0E0),
          width: hasExistingGrade ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            student.admissionNumber,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF757575),
                            ),
                          ),
                          if (hasExistingGrade) ...[
                            SizedBox(width: 12),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.black87,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${existingGrade.obtainedMarks}/${existingGrade.maxMarks}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: TextEditingController(
                              text: entry?.obtainedMarks.toString() ?? '0',
                            ),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '0',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            onChanged: (value) {
                              final marks = int.tryParse(value) ?? 0;
                              setState(() {
                                _gradeEntries[student.studentId]
                                    ?.obtainedMarks = marks > _maxMarks
                                    ? _maxMarks
                                    : marks;
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 70,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFF5F5F5),
                            border: Border(
                              left: BorderSide(color: Color(0xFFE0E0E0)),
                            ),
                          ),
                          child: Text(
                            '/$_maxMarks',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF757575),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Container(
                  width: 100,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Color(0xFFE0E0E0)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        entry != null && entry.maxMarks > 0
                            ? '${((entry.obtainedMarks / entry.maxMarks) * 100).toStringAsFixed(1)}%'
                            : '0%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getPercentageColor(
                            entry?.obtainedMarks ?? 0,
                            entry?.maxMarks ?? 1,
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _calculateGrade(
                          entry?.obtainedMarks ?? 0,
                          entry?.maxMarks ?? 1,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF616161),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPercentageColor(int obtained, int max) {
    if (max == 0) return Color(0xFF9E9E9E);
    final percentage = (obtained / max) * 100;

    if (percentage >= 90) return Colors.black;
    if (percentage >= 80) return Color(0xFF424242);
    if (percentage >= 70) return Color(0xFF616161);
    if (percentage >= 60) return Color(0xFF757575);
    if (percentage >= 50) return Color(0xFF9E9E9E);
    return Color(0xFFBDBDBD);
  }

  String _calculateGrade(int obtained, int max) {
    if (max == 0) return 'N/A';
    final percentage = (obtained / max) * 100;
    return Grade.calculateGrade(percentage);
  }

  Widget _buildHeaderCard() {
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
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GRADES ENTRY',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              widget.selectedClass,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.8,
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.selectedSubject,
              style: TextStyle(fontSize: 16, color: Colors.grey[300]),
            ),
            SizedBox(height: 16),
            Container(height: 1, color: Colors.white.withOpacity(0.1)),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
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
                      widget.teacher.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'STUDENTS',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_students.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exam Type',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _examType,
                            isExpanded: true,
                            icon: Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: Colors.black87,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            items: _examTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(type),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _examType = value);
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Term',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _term,
                            isExpanded: true,
                            icon: Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: Colors.black87,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                            items: _terms.map((term) {
                              return DropdownMenuItem(
                                value: term,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(term),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _term = value);
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Max Marks',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _maxMarksController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  hintText: '100',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFBDBDBD),
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                onSubmitted: (_) => _updateMaxMarksForAll(),
                              ),
                            ),
                            Container(
                              width: 50,
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: Color(0xFFE0E0E0)),
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.check,
                                  size: 20,
                                  color: Colors.black87,
                                ),
                                onPressed: _updateMaxMarksForAll,
                                padding: EdgeInsets.zero,
                                tooltip: 'Apply to all',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Academic Year',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: TextEditingController(
                            text: _academicYear.toString(),
                          ),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            hintText: '2025',
                            hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          onChanged: (value) {
                            final year = int.tryParse(value);
                            if (year != null) {
                              setState(() => _academicYear = year);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalStudents = _students.length;
    final gradedStudents = _gradeEntries.values
        .where((e) => e.obtainedMarks > 0)
        .length;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE0E0E0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GRADE ENTRY SUMMARY',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF757575),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Enter marks for all students',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$gradedStudents/$totalStudents',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  void _showSuccessSnackbar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  @override
  // grades_entry_screen.dart - Updated build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Grades Entry',
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
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                  ),
                ),
              ),
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
          : _students.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.black38),
                  SizedBox(height: 16),
                  Text(
                    'No students found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add students to this class first',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadData,
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
              // Added SingleChildScrollView
              child: Column(
                children: [
                  SizedBox(height: 8),
                  _buildHeaderCard(),
                  _buildFilterCard(),
                  _buildSummaryCard(),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Student List',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '${_students.length} Students',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  ListView.builder(
                    // Changed to ListView.builder instead of nested in RefreshIndicator
                    shrinkWrap:
                        true, // Important: makes ListView take only needed height
                    physics:
                        NeverScrollableScrollPhysics(), // Disables scrolling of inner ListView
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      return _buildStudentGradeRow(_students[index], index);
                    },
                  ),
                  SizedBox(height: 100), // Extra space for FAB
                ],
              ),
            ),
      floatingActionButton: _isLoading || _isSaving
          ? null
          : Container(
              margin: EdgeInsets.only(bottom: 20, right: 20),
              child: FloatingActionButton.extended(
                onPressed: _saveGrades,
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                icon: Icon(Icons.save),
                label: Text(
                  'Save Grades',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
    );
  }
}
