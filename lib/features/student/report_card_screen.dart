import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../models/user_model.dart';
import '../../../models/student_model.dart';
import '../../../models/grade_model.dart';

class ReportCardScreen extends StatefulWidget {
  const ReportCardScreen({super.key});

  @override
  _ReportCardScreenState createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends State<ReportCardScreen> {
  final DatabaseService _db = DatabaseService();
  UserModel? _currentUser;
  Student? _studentDetails;
  List<Grade> _allGrades = [];
  Map<String, List<Grade>> _gradesByTerm = {};
  Map<String, Map<String, List<Grade>>> _gradesByTermAndSubject = {};
  List<String> _allSubjects = [];
  List<String> _allTerms = [];
  String? _selectedTerm;
  String? _selectedSubject;
  bool _isLoading = true;
  final int _academicYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = await auth.getCurrentUserData();

      if (user == null || user.role != 'student') {
        setState(() => _isLoading = false);
        return;
      }

      _currentUser = user;

      // Load student details
      Student? student;
      if (user.specificId != null && user.specificId!.isNotEmpty) {
        student = await _db.getStudentById(user.specificId!);
      }

      student ??= await _db.getStudentByAuthUid(user.uid);

      if (student == null) {
        setState(() => _isLoading = false);
        return;
      }

      _studentDetails = student;

      // Load all grades for this student
      _allGrades = await _db.getGradesByStudent(student.studentId);

      // Organize data
      _organizeGrades();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading report card data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading report card: $e')));
      setState(() => _isLoading = false);
    }
  }

  void _organizeGrades() {
    // Group by term
    _gradesByTerm = {};
    for (var grade in _allGrades) {
      if (!_gradesByTerm.containsKey(grade.term)) {
        _gradesByTerm[grade.term] = [];
      }
      _gradesByTerm[grade.term]!.add(grade);
    }

    // Group by term and subject
    _gradesByTermAndSubject = {};
    for (var grade in _allGrades) {
      if (!_gradesByTermAndSubject.containsKey(grade.term)) {
        _gradesByTermAndSubject[grade.term] = {};
      }
      if (!_gradesByTermAndSubject[grade.term]!.containsKey(grade.subject)) {
        _gradesByTermAndSubject[grade.term]![grade.subject] = [];
      }
      _gradesByTermAndSubject[grade.term]![grade.subject]!.add(grade);
    }

    // Get unique subjects and terms
    _allSubjects = _allGrades.map((g) => g.subject).toSet().toList()..sort();
    _allTerms = _gradesByTerm.keys.toList()..sort();

    // Set selected term to the latest one
    if (_allTerms.isNotEmpty) {
      _selectedTerm = _allTerms.last;
    }

    if (_allSubjects.isNotEmpty) {
      _selectedSubject = _allSubjects.first;
    }
  }

  Map<String, double> _calculateTermSummary(String term) {
    final termGrades = _gradesByTerm[term] ?? [];
    if (termGrades.isEmpty) return {'average': 0.0, 'total': 0.0, 'count': 0.0};

    double totalPercentage = 0;
    int totalExams = 0;

    for (var grade in termGrades) {
      totalPercentage += grade.percentage;
      totalExams++;
    }

    final averagePercentage = totalExams > 0
        ? totalPercentage / totalExams
        : 0.0;

    return {
      'average': averagePercentage,
      'total': totalPercentage,
      'count': totalExams.toDouble(),
    };
  }

  Map<String, double> _calculateSubjectPerformance(String subject) {
    final subjectGrades = _allGrades
        .where((g) => g.subject == subject)
        .toList();
    if (subjectGrades.isEmpty) {
      return {'average': 0.0, 'best': 0.0, 'worst': 0.0};
    }

    double totalPercentage = 0;
    double bestPercentage = 0;
    double worstPercentage = 100;

    for (var grade in subjectGrades) {
      totalPercentage += grade.percentage;
      if (grade.percentage > bestPercentage) bestPercentage = grade.percentage;
      if (grade.percentage < worstPercentage) {
        worstPercentage = grade.percentage;
      }
    }

    final averagePercentage = subjectGrades.isNotEmpty
        ? totalPercentage / subjectGrades.length
        : 0.0;

    return {
      'average': averagePercentage,
      'best': bestPercentage,
      'worst': worstPercentage,
    };
  }

  Widget _buildReportCardHeader() {
    final studentName = _studentDetails?.fullName ?? 'Student';
    final admissionNo = _studentDetails?.admissionNumber ?? 'N/A';
    final className = _studentDetails?.className ?? 'N/A';

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[900]!, Colors.blue[700]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACADEMIC TRANSCRIPT',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      studentName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: _studentDetails?.photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _studentDetails!.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 40,
                            );
                          },
                        ),
                      )
                    : Icon(Icons.person, color: Colors.white, size: 40),
              ),
            ],
          ),
          SizedBox(height: 20),
          Container(height: 1, color: Colors.white.withOpacity(0.2)),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADMISSION NUMBER',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    admissionNo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'CLASS',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    className,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'ACADEMIC YEAR',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    _academicYear.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermSelector() {
    if (_allTerms.isEmpty) return SizedBox();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Term',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _allTerms.map((term) {
                final isSelected = _selectedTerm == term;
                final summary = _calculateTermSummary(term);

                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTerm = term);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue[50] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            term,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.blue[800]
                                  : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${summary['average']?.toStringAsFixed(1) ?? '0.0'}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.blue[600]
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallPerformance() {
    final termGrades = _gradesByTerm[_selectedTerm] ?? [];
    final termSummary = _calculateTermSummary(_selectedTerm ?? '');
    final averagePercentage = termSummary['average'] ?? 0.0;
    final overallGrade = Grade.calculateGrade(averagePercentage);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Term Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getGradeColor(overallGrade),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  overallGrade,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Average Score',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${averagePercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _getPercentageColor(averagePercentage),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Total Exams',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${termGrades.length}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (termGrades.isNotEmpty) ...[
            Divider(color: Colors.grey[200]),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subjects',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '${_allSubjects.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectPerformanceList() {
    final termGrades = _gradesByTerm[_selectedTerm] ?? [];
    if (termGrades.isEmpty) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 60, color: Colors.grey[300]),
            SizedBox(height: 12),
            Text(
              'No grades available for this term',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Group by subject and calculate average
    Map<String, List<Grade>> gradesBySubject = {};
    for (var grade in termGrades) {
      if (!gradesBySubject.containsKey(grade.subject)) {
        gradesBySubject[grade.subject] = [];
      }
      gradesBySubject[grade.subject]!.add(grade);
    }

    List<Map<String, dynamic>> subjectData = [];
    gradesBySubject.forEach((subject, grades) {
      double total = 0;
      for (var grade in grades) {
        total += grade.percentage;
      }
      double average = grades.isNotEmpty ? total / grades.length : 0;

      subjectData.add({
        'subject': subject,
        'percentage': average,
        'grade': Grade.calculateGrade(average),
        'count': grades.length,
      });
    });

    // Sort by percentage descending
    subjectData.sort((a, b) => b['percentage'].compareTo(a['percentage']));

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subject-wise Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          ...subjectData.map((data) {
            final percentage = data['percentage'] as double;
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getPercentageColor(percentage).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        _getSubjectIcon(data['subject']),
                        color: _getPercentageColor(percentage),
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['subject'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${data['count']} exam(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _getPercentageColor(percentage),
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getGradeColor(data['grade']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          data['grade'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
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
  }

  Widget _buildSubjectGradesTable() {
    final termGrades = _gradesByTerm[_selectedTerm] ?? [];
    if (termGrades.isEmpty) return SizedBox();

    // Get unique subjects for this term
    final subjects = termGrades.map((g) => g.subject).toSet().toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Detailed Grades - $_selectedTerm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: subjects.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final subjectGrades = termGrades
                  .where((g) => g.subject == subject)
                  .toList();
              final subjectPerformance = _calculateSubjectPerformance(subject);

              return ExpansionTile(
                tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getSubjectIcon(subject),
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '${subjectGrades.length} exam(s) | Avg: ${subjectPerformance['average']?.toStringAsFixed(1) ?? '0.0'}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getPercentageColor(
                          subjectPerformance['average'] ?? 0.0,
                        ).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getPercentageColor(
                            subjectPerformance['average'] ?? 0.0,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        Grade.calculateGrade(
                          subjectPerformance['average'] ?? 0.0,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _getPercentageColor(
                            subjectPerformance['average'] ?? 0.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      children: subjectGrades.map((grade) {
                        return Container(
                          margin: EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      grade.examType,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(grade.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${grade.obtainedMarks}/${grade.maxMarks}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getPercentageColor(
                                            grade.percentage,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '${grade.percentage.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _getPercentageColor(
                                              grade.percentage,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    grade.grade,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _getGradeColor(grade.grade),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicSummary() {
    if (_allTerms.isEmpty) return SizedBox();

    List<Map<String, dynamic>> termData = [];
    for (var term in _allTerms) {
      final summary = _calculateTermSummary(term);
      termData.add({
        'term': term,
        'average': summary['average'] ?? 0.0,
        'grade': Grade.calculateGrade(summary['average'] ?? 0.0),
      });
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic Year Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: termData.length,
            itemBuilder: (context, index) {
              final data = termData[index];
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          (index + 1).toString(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
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
                            data['term'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${data['average'].toStringAsFixed(1)}% Average',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _getGradeColor(data['grade']),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data['grade'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getSubjectIcon(String subject) {
    final subjectLower = subject.toLowerCase();
    if (subjectLower.contains('math')) return Icons.calculate;
    if (subjectLower.contains('science')) return Icons.science;
    if (subjectLower.contains('english')) return Icons.language;
    if (subjectLower.contains('malayalam')) return Icons.translate;
    if (subjectLower.contains('hindi')) return Icons.translate;
    if (subjectLower.contains('history') || subjectLower.contains('social')) {
      return Icons.history_edu;
    }
    if (subjectLower.contains('geography')) return Icons.public;
    if (subjectLower.contains('computer')) return Icons.computer;
    if (subjectLower.contains('art')) return Icons.brush;
    if (subjectLower.contains('music')) return Icons.music_note;
    if (subjectLower.contains('physical') || subjectLower.contains('pe')) {
      return Icons.sports;
    }
    if (subjectLower.contains('biology')) return Icons.psychology;
    if (subjectLower.contains('chemistry')) return Icons.science;
    if (subjectLower.contains('physics')) return Icons.biotech;
    return Icons.book;
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 90) return Colors.green[800]!;
    if (percentage >= 80) return Colors.green;
    if (percentage >= 70) return Colors.blue;
    if (percentage >= 60) return Colors.orange;
    if (percentage >= 50) return Colors.orange[800]!;
    if (percentage >= 40) return Colors.red[300]!;
    return Colors.red;
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return Colors.green[800]!;
      case 'B+':
      case 'B':
        return Colors.blue;
      case 'C+':
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.red[300]!;
      case 'F':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.grade_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No grades available',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Your grades will appear here once\nteachers start entering them',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loadStudentData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Refresh',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
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
          'Report Card',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadStudentData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // Share functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Share feature coming soon!')),
              );
            },
            tooltip: 'Share',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading report card...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : _studentDetails == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Student profile not found',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                ],
              ),
            )
          : _allGrades.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadStudentData,
              color: Colors.blue,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildReportCardHeader(),
                    SizedBox(height: 24),
                    _buildTermSelector(),
                    SizedBox(height: 16),
                    _buildOverallPerformance(),
                    SizedBox(height: 16),
                    _buildSubjectPerformanceList(),
                    SizedBox(height: 16),
                    _buildSubjectGradesTable(),
                    SizedBox(height: 16),
                    _buildAcademicSummary(),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
