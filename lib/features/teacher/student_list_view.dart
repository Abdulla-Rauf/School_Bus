import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:school_bus2/features/teacher/student_details_screen.dart';

import 'package:school_bus2/core/theme/premium_theme.dart';
import '../../models/student_model.dart';

class StudentListView extends StatefulWidget {
  final String primaryClass;
  final List<String> secondaryClasses;
  final List<Student> primaryClassStudents;
  final List<Student> secondaryClassStudents;

  const StudentListView({
    super.key,
    required this.primaryClass,
    required this.secondaryClasses,
    required this.primaryClassStudents,
    required this.secondaryClassStudents,
  });

  @override
  _StudentListViewState createState() => _StudentListViewState();
}

class _StudentListViewState extends State<StudentListView> {
  String _selectedFilter = 'All Classes';
  String _sortOrder = 'Ascending';
  String _searchQuery = '';

  List<String> get _availableClasses {
    List<String> classes = ['All Classes', 'Primary Class'];
    classes.addAll(widget.secondaryClasses);
    return classes;
  }

  List<Student> get _filteredStudents {
    List<Student> allStudents = [];

    if (_selectedFilter == 'All Classes') {
      allStudents.addAll(widget.primaryClassStudents);
      allStudents.addAll(widget.secondaryClassStudents);
    } else if (_selectedFilter == 'Primary Class') {
      allStudents.addAll(widget.primaryClassStudents);
    } else {
      allStudents.addAll(
        widget.secondaryClassStudents
            .where((student) => student.className == _selectedFilter)
            .toList(),
      );
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      allStudents = allStudents.where((student) {
        final fullName = '${student.firstName} ${student.lastName}'
            .toLowerCase();
        final admissionNumber = student.admissionNumber.toLowerCase();
        return fullName.contains(_searchQuery.toLowerCase()) ||
            admissionNumber.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply sorting
    allStudents.sort((a, b) {
      int comparison = a.firstName.compareTo(b.firstName);
      return _sortOrder == 'Ascending' ? comparison : -comparison;
    });

    return allStudents;
  }

  Map<String, List<Student>> get _groupedStudents {
    Map<String, List<Student>> grouped = {};

    for (var student in _filteredStudents) {
      if (!grouped.containsKey(student.className)) {
        grouped[student.className] = [];
      }
      grouped[student.className]!.add(student);
    }

    return grouped;
  }

  Widget _buildFilterChip(
    String label,
    String currentValue,
    VoidCallback onTap,
  ) {
    bool isSelected = currentValue == label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? PremiumTheme.primaryGradient : null,
          color: isSelected ? null : PremiumTheme.darkGrey,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? PremiumTheme.neonShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? PremiumTheme.black : Colors.grey[400],
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Student student, bool isPrimaryClass, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      decoration: BoxDecoration(
        color: PremiumTheme.darkGrey,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDetailsScreen(student: student),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Student Number
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: index % 2 == 0
                        ? const Color(0xFF4ACFAC).withOpacity(0.2)
                        : const Color(0xFFFF9F69).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Student Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${student.firstName} ${student.lastName}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPrimaryClass) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6C63FF),
                                    Color(0xFF484598),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Admission Number
                      Row(
                        children: [
                          Icon(
                            Icons.badge_rounded,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            student.admissionNumber,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Class Info
                      Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Class ${student.className}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Contact Info
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            student.primaryPhone,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Avatar
                Hero(
                  tag: 'student_avatar_${student.studentId}',
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PremiumTheme.darkGrey,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: PremiumTheme.neonLime.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: student.photoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: student.photoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    PremiumTheme.neonLime,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.person_rounded,
                                color: Colors.grey[400],
                                size: 30,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.person_rounded,
                                color: Colors.grey[400],
                                size: 30,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassSection(String className, List<Student> students) {
    final isPrimaryClass = className == widget.primaryClass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: PremiumTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: PremiumTheme.neonShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Class $className',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (isPrimaryClass) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ACFAC),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${students.length} Students',
                        style: TextStyle(
                          fontSize: 14,
                          color: PremiumTheme.black.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${students.length}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: PremiumTheme.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        ...students.asMap().entries.map(
          (entry) => _buildStudentCard(entry.value, isPrimaryClass, entry.key),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: PremiumTheme.darkGrey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 60,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No students found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFilter == 'All Classes'
                  ? 'Try adjusting your search or filters'
                  : 'No students in $_selectedFilter',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (_searchQuery.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.neonLime,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Clear Search',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PremiumTheme.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalStudents =
        widget.primaryClassStudents.length +
        widget.secondaryClassStudents.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      decoration: const BoxDecoration(color: PremiumTheme.black),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Directory',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage all students',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: PremiumTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: PremiumTheme.neonShadow,
                ),
                child: Text(
                  '$totalStudents TOTAL',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: PremiumTheme.black,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: PremiumTheme.darkGrey,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search students...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey[400],
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      color: PremiumTheme.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ..._availableClasses.map((className) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(className, _selectedFilter, () {
                      setState(() {
                        _selectedFilter = className;
                      });
                    }),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredStudents.length} Students found',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: PremiumTheme.darkGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sort_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Sort:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _sortOrder,
                    underline: Container(),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                    ),
                    dropdownColor: PremiumTheme.darkGrey,
                    items: ['Ascending', 'Descending']
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _sortOrder = newValue!;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedStudents = _groupedStudents;
    final hasStudents = _filteredStudents.isNotEmpty;
    // ignore: unused_local_variable
    final totalStudents =
        widget.primaryClassStudents.length +
        widget.secondaryClassStudents.length;

    return Scaffold(
      backgroundColor: PremiumTheme.black,
      body: Column(
        children: [
          _buildHeader(),
          _buildFiltersSection(),

          // Students List
          Expanded(
            child: hasStudents
                ? RefreshIndicator(
                    onRefresh: () async {
                      setState(() {});
                    },
                    color: PremiumTheme.neonLime,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: _selectedFilter == 'All Classes'
                            ? groupedStudents.entries
                                  .map(
                                    (entry) => _buildClassSection(
                                      entry.key,
                                      entry.value,
                                    ),
                                  )
                                  .toList()
                            : [
                                _buildClassSection(
                                  _selectedFilter == 'Primary Class'
                                      ? widget.primaryClass
                                      : _selectedFilter,
                                  _filteredStudents,
                                ),
                              ],
                      ),
                    ),
                  )
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }
}
