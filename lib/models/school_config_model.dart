// school_config_model.dart
class SchoolConfig {
  final String schoolId;
  final List<SchoolClass> classes;
  final List<String> subjects;
  final DateTime updatedAt;

  SchoolConfig({
    required this.schoolId,
    required this.classes,
    required this.subjects,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'classes': classes.map((classItem) => classItem.toMap()).toList(),
      'subjects': subjects,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory SchoolConfig.fromMap(Map<String, dynamic> map) {
    return SchoolConfig(
      schoolId: map['schoolId'] ?? '',
      classes: List<SchoolClass>.from(
        (map['classes'] ?? []).map((x) => SchoolClass.fromMap(x)),
      ),
      subjects: List<String>.from(map['subjects'] ?? []),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }
}

class ClassDivision {
  final String className; // e.g., "1", "2", "3"
  final String division; // e.g., "A", "B", "C"
  final List<String> subjects; // Subjects specific to this class-division
  final List<String> teachers; // Teachers assigned to this class-division

  ClassDivision({
    required this.className,
    required this.division,
    required this.subjects,
    this.teachers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'className': className,
      'division': division,
      'subjects': subjects,
      'teachers': teachers,
    };
  }

  factory ClassDivision.fromMap(Map<String, dynamic> map) {
    return ClassDivision(
      className: map['className'] ?? '',
      division: map['division'] ?? '',
      subjects: List<String>.from(map['subjects'] ?? []),
      teachers: List<String>.from(map['teachers'] ?? []),
    );
  }

  String get fullClassName => '$className$division';

  // Check if a specific subject exists
  bool hasSubject(String subject) {
    return subjects.contains(subject);
  }

  // Check if a specific teacher is assigned
  bool hasTeacher(String teacherId) {
    return teachers.contains(teacherId);
  }

  // Add subject to this division
  void addSubject(String subject) {
    if (!subjects.contains(subject)) {
      subjects.add(subject);
    }
  }

  // Remove subject from this division
  void removeSubject(String subject) {
    subjects.remove(subject);
  }

  // Add teacher to this division
  void addTeacher(String teacherId) {
    if (!teachers.contains(teacherId)) {
      teachers.add(teacherId);
    }
  }

  // Remove teacher from this division
  void removeTeacher(String teacherId) {
    teachers.remove(teacherId);
  }
}

class SchoolClass {
  final String className; // e.g., "1", "2", "3"
  final List<ClassDivision> divisions; // List of divisions with their subjects

  SchoolClass({
    required this.className,
    required this.divisions,
  });

  Map<String, dynamic> toMap() {
    return {
      'className': className,
      'divisions': divisions.map((div) => div.toMap()).toList(),
    };
  }

  factory SchoolClass.fromMap(Map<String, dynamic> map) {
    return SchoolClass(
      className: map['className'] ?? '',
      divisions: List<ClassDivision>.from(
        (map['divisions'] ?? []).map((x) => ClassDivision.fromMap(x)),
      ),
    );
  }

  // Get all division names
  List<String> getDivisionNames() {
    return divisions.map((div) => div.division).toList();
  }

  // Get full class names
  List<String> getFullClassNames() {
    return divisions.map((div) => div.fullClassName).toList();
  }

  // Get a specific division
  ClassDivision? getDivision(String division) {
    try {
      return divisions.firstWhere((div) => div.division == division);
    } catch (e) {
      return null;
    }
  }

  // Add a new division
  void addDivision(String division) {
    if (!getDivisionNames().contains(division)) {
      divisions.add(ClassDivision(
        className: className,
        division: division,
        subjects: [],
      ));
    }
  }

  // Remove a division
  void removeDivision(String division) {
    divisions.removeWhere((div) => div.division == division);
  }

  // Check if a specific division exists
  bool hasDivision(String division) {
    return divisions.any((div) => div.division == division);
  }

  // Get all subjects across all divisions
  List<String> getAllSubjects() {
    Set<String> allSubjects = {};
    for (var division in divisions) {
      allSubjects.addAll(division.subjects);
    }
    return allSubjects.toList();
  }

  // Get all teachers across all divisions
  List<String> getAllTeachers() {
    Set<String> allTeachers = {};
    for (var division in divisions) {
      allTeachers.addAll(division.teachers);
    }
    return allTeachers.toList();
  }
}