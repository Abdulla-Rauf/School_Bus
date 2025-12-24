class ClassAssignment {
  final String className; // e.g., "1A", "3C", "5A"
  final List<String> subjects; // e.g., ["Physics", "Mathematics"]

  ClassAssignment({
    required this.className,
    required this.subjects,
  });

  @override
  String toString() {
    return '$className - ${subjects.join(", ")}';
  }

  Map<String, dynamic> toMap() {
    return {
      'className': className,
      'subjects': subjects,
    };
  }
}