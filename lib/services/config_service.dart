// config_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/school_config_model.dart';
import '../models/teacher_model.dart';

class ConfigService {
  final FirebaseFirestore _firestore;

  ConfigService(this._firestore);

  Future<bool> saveSchoolConfig(SchoolConfig config) async {
    try {
      print('💾 Saving school configuration:');
      print('   School ID: ${config.schoolId}');

      Map<String, dynamic> configMap = config.toMap();
      await _firestore
          .collection('school_configs')
          .doc(config.schoolId)
          .set(configMap, SetOptions(merge: true));

      print('✅ School configuration saved successfully!');
      return true;
    } catch (e) {
      print('❌ Error saving school config: $e');
      return false;
    }
  }

  Future<SchoolConfig?> getSchoolConfig(String schoolId) async {
    try {
      print('📖 Loading school configuration for: $schoolId');

      var doc = await _firestore
          .collection('school_configs')
          .doc(schoolId)
          .get();

      if (doc.exists) {
        print('✅ School config found');
        return SchoolConfig.fromMap(doc.data()!);
      } else {
        print('ℹ️ No school config found for: $schoolId');
        return null;
      }
    } catch (e) {
      print('❌ Error getting school config: $e');
      return null;
    }
  }

  Future<List<String>> getAvailableClasses(String schoolId) async {
    try {
      var config = await getSchoolConfig(schoolId);
      if (config != null) {
        List<String> allClasses = [];
        for (var schoolClass in config.classes) {
          allClasses.addAll(schoolClass.getFullClassNames());
        }
        return allClasses..sort();
      }
    } catch (e) {
      print('Error getting available classes: $e');
    }
    return [];
  }

  Future<List<String>> getDivisionsForClass(String schoolId, String className) async {
    try {
      SchoolConfig? config = await getSchoolConfig(schoolId);
      if (config == null) return [];

      for (var schoolClass in config.classes) {
        if (schoolClass.className == className) {
          return schoolClass.getDivisionNames();
        }
      }
      return [];
    } catch (e) {
      print('Error getting divisions for class: $e');
      return [];
    }
  }

  Future<List<Teacher>> getTeachersForClassDivision(String schoolId, String className, String division) async {
    try {
      SchoolConfig? config = await getSchoolConfig(schoolId);
      if (config == null) return [];

      // Find the specific class-division
      for (var schoolClass in config.classes) {
        if (schoolClass.className == className) {
          ClassDivision? classDivision = schoolClass.getDivision(division);
          if (classDivision != null && classDivision.teachers.isNotEmpty) {
            // Get teacher details for each teacher ID
            List<Teacher> teachers = [];
            for (var teacherId in classDivision.teachers) {
              // Note: This requires TeacherService - you might need to inject it
              // For now, we'll return empty list and handle this differently
            }
            return teachers;
          }
        }
      }
      return [];
    } catch (e) {
      print('Error getting teachers for class-division: $e');
      return [];
    }
  }

  Future<List<String>> getSubjectsForClassDivision(String schoolId, String className, String division) async {
    try {
      SchoolConfig? config = await getSchoolConfig(schoolId);
      if (config == null) return [];

      for (var schoolClass in config.classes) {
        if (schoolClass.className == className) {
          ClassDivision? classDivision = schoolClass.getDivision(division);
          if (classDivision != null) {
            return classDivision.subjects;
          }
        }
      }
      return [];
    } catch (e) {
      print('Error getting subjects for class-division: $e');
      return [];
    }
  }

  Future<List<String>> getClassesForTeacher(String schoolId, String teacherId) async {
    try {
      SchoolConfig? config = await getSchoolConfig(schoolId);
      if (config == null) return [];

      List<String> classes = [];
      for (var schoolClass in config.classes) {
        for (var division in schoolClass.divisions) {
          if (division.teachers.contains(teacherId)) {
            classes.add('${schoolClass.className}${division.division}');
          }
        }
      }
      return classes..sort();
    } catch (e) {
      print('Error getting classes for teacher: $e');
      return [];
    }
  }
}