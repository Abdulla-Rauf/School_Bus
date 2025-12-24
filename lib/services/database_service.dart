// database_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

// Import models
import '../models/assignment_model.dart';
import '../models/attendance_model.dart';
import '../models/calendar_model.dart';
import '../models/driver_model.dart';
import '../models/grade_model.dart';
import '../models/leave_request_model.dart';
import '../models/student_assignment_model.dart';
import '../models/student_model.dart';
import '../models/submission_model.dart';
import '../models/vehicle_model.dart';
import '../models/teacher_model.dart';
import '../models/school_config_model.dart';
import '../models/school_model.dart';
import '../models/user_model.dart';

// Import service files
import 'school_service.dart';
import 'student_service.dart';
import 'teacher_service.dart';
import 'driver_service.dart';
import 'vehicle_service.dart';
import 'calendar_service.dart';
import 'config_service.dart';
import 'assignment_service.dart';
import 'attendance_service.dart';
import 'grade_service.dart';
import 'user_service.dart';
import 'leave_service.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Service instances
  late final SchoolService _schoolService;
  late final StudentService _studentService;
  late final TeacherService _teacherService;
  late final DriverService _driverService;
  late final VehicleService _vehicleService;
  late final CalendarService _calendarService;
  late final ConfigService _configService;
  late final AssignmentService _assignmentService;
  late final AttendanceService _attendanceService;
  late final GradeService _gradeService;
  late final UserService _userService;
  late final LeaveService _leaveService;

  DatabaseService() {
    // Initialize all services with dependencies
    _schoolService = SchoolService(_firestore, _storage, _auth);
    _studentService = StudentService(_firestore, _storage, _auth);
    _teacherService = TeacherService(_firestore, _storage, _auth);
    _driverService = DriverService(_firestore, _storage, _auth);
    _vehicleService = VehicleService(_firestore);
    _calendarService = CalendarService(_firestore);
    _configService = ConfigService(_firestore);
    _assignmentService = AssignmentService(_firestore);
    _attendanceService = AttendanceService(_firestore);
    _gradeService = GradeService(_firestore);
    _userService = UserService(_firestore);
    _leaveService = LeaveService(_firestore);
  }

  // --- Common utility methods ---

  String generateId({required String prefix}) {
    return '$prefix${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String?> uploadImage(File image, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(image);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<UserCredential?> _createAuthUser(
    String email,
    String password,
    String name,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await userCredential.user!.updateDisplayName(name);
      return userCredential;
    } catch (e) {
      print('Error creating auth user: $e');
      return null;
    }
  }

  Future<void> _deleteCollection(
    String collectionName,
    String fieldName,
    String schoolId,
  ) async {
    try {
      print('   Deleting $collectionName for school: $schoolId');

      var query = await _firestore
          .collection(collectionName)
          .where(fieldName, isEqualTo: schoolId)
          .get();

      if (query.docs.isNotEmpty) {
        WriteBatch batch = _firestore.batch();
        for (var doc in query.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print(
          '   ✅ Deleted ${query.docs.length} documents from $collectionName',
        );
      }
    } catch (e) {
      print('   ⚠️ Error deleting $collectionName: $e');
    }
  }

  // --- DELEGATE METHODS FOR BACKWARD COMPATIBILITY ---

  // School Service Delegates
  Future<List<School>> getAllSchools() => _schoolService.getAllSchools();
  Future<School?> getSchoolById(String schoolId) =>
      _schoolService.getSchoolById(schoolId);
  Future<bool> createSchool(School school, String password) =>
      _schoolService.createSchool(school, password);
  Future<bool> updateSchool(School school) =>
      _schoolService.updateSchool(school);
  Future<bool> deleteSchool(String schoolId) =>
      _schoolService.deleteSchool(schoolId);
  Future<String?> uploadSchoolLogo(File image, String schoolId) =>
      _schoolService.uploadSchoolLogo(image, schoolId);

  // Statistics
  Future<int> getClassesCount(String schoolId) async {
    // Classes are derived from unique values in 'students' collection or 'config'
    // For now, simpler to count unique classes from students if no direct class collection
    // Better: use ConfigService to get available classes
    try {
      List<String> classes = await _configService.getAvailableClasses(schoolId);
      return classes.length;
    } catch (e) {
      print('Error getting classes count: $e');
      return 0;
    }
  }

  Future<int> getTeachersCount(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('teachers')
          .where('schoolId', isEqualTo: schoolId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting teachers count: $e');
      return 0;
    }
  }

  Future<int> getBusesCount(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('vehicles')
          .where('schoolId', isEqualTo: schoolId)
          .where(
            'type',
            isEqualTo: 'Bus',
          ) // Assuming 'Bus' is the type, or just count all vehicles
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      // Fallback if 'type' query fails or simple count
      try {
        final snapshot = await _firestore
            .collection('vehicles')
            .where('schoolId', isEqualTo: schoolId)
            .count()
            .get();
        return snapshot.count ?? 0;
      } catch (e2) {
        print('Error getting buses count: $e2');
        return 0;
      }
    }
  }

  Future<int> getVehiclesCount(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('vehicles')
          .where('schoolId', isEqualTo: schoolId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting vehicles count: $e');
      return 0;
    }
  }

  Future<int> getStudentsCount(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting students count: $e');
      return 0;
    }
  }

  // Student Service Delegates
  Future<bool> addStudentWithPassword(Student student, String password) =>
      _studentService.addStudentWithPassword(student, password);
  Future<bool> checkAdmissionNumberExists(String admissionNumber) =>
      _studentService.checkAdmissionNumberExists(admissionNumber);
  Future<bool> checkEmailExists(String email) =>
      _studentService.checkEmailExists(email);
  Future<List<Student>> getStudentsBySchoolId(String schoolId) =>
      _studentService.getStudentsBySchoolId(schoolId);
  Future<Student?> getStudentById(String studentId) =>
      _studentService.getStudentById(studentId);
  Future<Student?> getStudentByAuthUid(String authUid) =>
      _studentService.getStudentByAuthUid(authUid);
  Future<Student?> getStudentByEmail(String email) =>
      _studentService.getStudentByEmail(email);
  Future<Student?> getStudentByAdmissionNumber(String admissionNumber) =>
      _studentService.getStudentByAdmissionNumber(admissionNumber);
  Future<bool> addStudent(Student student, File? imageFile) =>
      _studentService.addStudent(student, imageFile);
  Future<bool> updateStudent(Student student, File? imageFile) =>
      _studentService.updateStudent(student, imageFile);
  Future<List<Student>> getStudents(String schoolId) =>
      _studentService.getStudents(schoolId);
  Future<bool> deleteStudent(String studentId) =>
      _studentService.deleteStudent(studentId);
  Future<List<Student>> getStudentsByClass(String className) =>
      _studentService.getStudentsByClass(className);
  Future<List<StudentAssignment>> getStudentAssignments(
    String studentId,
    String className,
  ) => _studentService.getStudentAssignments(studentId, className);

  // Teacher Service Delegates
  Future<bool> addTeacher(Teacher teacher, File? imageFile) =>
      _teacherService.addTeacher(teacher, imageFile);
  Future<List<Teacher>> getTeachers(String schoolId) =>
      _teacherService.getTeachers(schoolId);
  Future<bool> deleteTeacher(String teacherId) =>
      _teacherService.deleteTeacher(teacherId);
  Future<bool> verifyTeacherDeletion(String teacherId) =>
      _teacherService.verifyTeacherDeletion(teacherId);
  Future<bool> updateTeacher(Teacher teacher, File? imageFile) =>
      _teacherService.updateTeacher(teacher, imageFile);
  Future<Teacher?> getTeacherById(String teacherId) =>
      _teacherService.getTeacherById(teacherId);
  Future<bool> isPrimaryTeacherForClass(String teacherId, String className) =>
      _teacherService.isPrimaryTeacherForClass(teacherId, className);

  // Driver Service Delegates
  Future<bool> addDriver(Driver driver, File? imageFile) =>
      _driverService.addDriver(driver, imageFile);
  Future<bool> updateDriver(Driver driver, File? imageFile) =>
      _driverService.updateDriver(driver, imageFile);
  Future<List<Driver>> getDrivers(String schoolId) =>
      _driverService.getDrivers(schoolId);
  Future<bool> deleteDriver(String driverId) =>
      _driverService.deleteDriver(driverId);
  Future<Driver?> getDriverById(String driverId) =>
      _driverService.getDriverById(driverId);

  // Vehicle Service Delegates
  Future<bool> addVehicle(Vehicle vehicle) =>
      _vehicleService.addVehicle(vehicle);
  Future<List<Vehicle>> getVehicles(String schoolId) =>
      _vehicleService.getVehicles(schoolId);
  Future<bool> deleteVehicle(String vehicleId) =>
      _vehicleService.deleteVehicle(vehicleId);
  Future<List<Vehicle>> getAvailableVehicles(
    String schoolId,
    String vehicleType,
  ) => _vehicleService.getAvailableVehicles(schoolId, vehicleType);
  Future<bool> updateVehicle(Vehicle vehicle) =>
      _vehicleService.updateVehicle(vehicle);
  Future<List<Vehicle>> getVehiclesByDriver(String driverId) =>
      _vehicleService.getVehiclesByDriver(driverId);
  Future<bool> assignDriverToVehicle({
    required String vehicleId,
    required String driverId,
  }) => _vehicleService.assignDriverToVehicle(
    vehicleId: vehicleId,
    driverId: driverId,
  );
  Future<List<Vehicle>> getUnassignedVehicles(String schoolId) =>
      _vehicleService.getUnassignedVehicles(schoolId);
  Future<bool> removeDriverFromVehicle(String vehicleId) =>
      _vehicleService.removeDriverFromVehicle(vehicleId);
  Future<Vehicle?> getVehicleByDriver(String driverId) =>
      _vehicleService.getVehicleByDriver(driverId);
  Future<bool> assignStudentToVehicle({
    required String vehicleId,
    required VehicleStudent student,
  }) => _vehicleService.assignStudentToVehicle(
    vehicleId: vehicleId,
    student: student,
  );
  Future<bool> removeStudentFromVehicle({
    required String vehicleId,
    required String studentId,
  }) => _vehicleService.removeStudentFromVehicle(
    vehicleId: vehicleId,
    studentId: studentId,
  );
  Future<bool> updateStudentVehicleAssignment({
    required String oldVehicleId,
    required String newVehicleId,
    required VehicleStudent student,
  }) => _vehicleService.updateStudentVehicleAssignment(
    oldVehicleId: oldVehicleId,
    newVehicleId: newVehicleId,
    student: student,
  );

  // Calendar Service Delegates
  Future<bool> saveSchoolCalendar(SchoolCalendar calendar) =>
      _calendarService.saveSchoolCalendar(calendar);
  Future<SchoolCalendar?> getSchoolCalendar(String schoolId) =>
      _calendarService.getSchoolCalendar(schoolId);
  Future<bool> addCalendarEvent(String schoolId, CalendarEvent event) =>
      _calendarService.addCalendarEvent(schoolId, event);
  Future<bool> deleteCalendarEvent(String schoolId, String eventId) =>
      _calendarService.deleteCalendarEvent(schoolId, eventId);
  Future<List<CalendarEvent>> getEventsForTeacher(
    String schoolId,
    List<String> teacherClasses,
  ) => _calendarService.getEventsForTeacher(schoolId, teacherClasses);
  Future<bool> addCalendarEventWithCreator(
    String schoolId,
    CalendarEvent event, {
    String createdBy = 'school',
    String? creatorId,
    String? creatorName,
  }) => _calendarService.addCalendarEventWithCreator(
    schoolId,
    event,
    createdBy: createdBy,
    creatorId: creatorId,
    creatorName: creatorName,
  );
  bool canUserEditEvent(CalendarEvent event, UserModel user) =>
      _calendarService.canUserEditEvent(event, user);
  Future<List<CalendarEvent>> getUpcomingEventsForClasses(
    List<String> classNames,
  ) => _calendarService.getUpcomingEventsForClasses(classNames);
  Future<List<CalendarEvent>> getUpcomingEventsForSchool(
    String schoolId,
    List<String> classNames,
  ) => _calendarService.getUpcomingEventsForSchool(schoolId, classNames);

  // Config Service Delegates
  Future<bool> saveSchoolConfig(SchoolConfig config) =>
      _configService.saveSchoolConfig(config);
  Future<SchoolConfig?> getSchoolConfig(String schoolId) =>
      _configService.getSchoolConfig(schoolId);
  Future<List<String>> getAvailableClasses(String schoolId) =>
      _configService.getAvailableClasses(schoolId);
  Future<List<String>> getDivisionsForClass(
    String schoolId,
    String className,
  ) => _configService.getDivisionsForClass(schoolId, className);
  Future<List<Teacher>> getTeachersForClassDivision(
    String schoolId,
    String className,
    String division,
  ) =>
      _configService.getTeachersForClassDivision(schoolId, className, division);
  Future<List<String>> getSubjectsForClassDivision(
    String schoolId,
    String className,
    String division,
  ) =>
      _configService.getSubjectsForClassDivision(schoolId, className, division);
  Future<List<String>> getClassesForTeacher(
    String schoolId,
    String teacherId,
  ) => _configService.getClassesForTeacher(schoolId, teacherId);

  // Assignment Service Delegates
  Future<bool> createAssignment(Assignment assignment) =>
      _assignmentService.createAssignment(assignment);
  Future<List<Assignment>> getAssignmentsByClass(String classId) =>
      _assignmentService.getAssignmentsByClass(classId);
  Future<List<Assignment>> getAssignmentsByTeacher(String teacherId) =>
      _assignmentService.getAssignmentsByTeacher(teacherId);
  Future<bool> submitAssignment(Submission submission) =>
      _assignmentService.submitAssignment(submission);
  Future<Submission?> getSubmission(String assignmentId, String studentId) =>
      _assignmentService.getSubmission(assignmentId, studentId);
  Future<List<Submission>> getSubmissionsByAssignment(String assignmentId) =>
      _assignmentService.getSubmissionsByAssignment(assignmentId);

  // Attendance Service Delegates
  Future<bool> markAttendance(AttendanceRecord attendance) =>
      _attendanceService.markAttendance(attendance);
  Future<AttendanceRecord?> getAttendanceByClassAndDate(
    String classId,
    DateTime date,
  ) => _attendanceService.getAttendanceByClassAndDate(classId, date);
  Future<List<AttendanceRecord>> getClassAttendance(
    String classId, {
    int? limit,
  }) => _attendanceService.getClassAttendance(classId, limit: limit);
  Future<Map<String, dynamic>> getStudentAttendanceSummary(
    String studentId,
    String classId,
  ) => _attendanceService.getStudentAttendanceSummary(studentId, classId);
  Future<List<AttendanceRecord>> getAttendanceByClass(
    String classId, {
    DateTime? startDate,
    DateTime? endDate,
  }) => _attendanceService.getAttendanceByClass(
    classId,
    startDate: startDate,
    endDate: endDate,
  );
  Future<List<AttendanceRecord>> getAttendanceByStudent(
    String studentId,
    String classId, {
    DateTime? startDate,
    DateTime? endDate,
  }) => _attendanceService.getAttendanceByStudent(
    studentId,
    classId,
    startDate: startDate,
    endDate: endDate,
  );
  Future<List<AttendanceRecord>> getStudentAttendanceSimple(
    String studentId,
    String classId,
  ) => _attendanceService.getStudentAttendanceSimple(studentId, classId);

  // Grade Service Delegates
  Future<bool> saveGrade(Grade grade) => _gradeService.saveGrade(grade);
  Future<List<Grade>> getGradesByTeacher(
    String teacherId, {
    String? subject,
    String? classId,
  }) => _gradeService.getGradesByTeacher(
    teacherId,
    subject: subject,
    classId: classId,
  );
  Future<List<Grade>> getGradesByStudent(String studentId, {String? subject}) =>
      _gradeService.getGradesByStudent(studentId, subject: subject);
  Future<List<Grade>> getGradesByClassAndSubject(
    String classId,
    String subject,
  ) => _gradeService.getGradesByClassAndSubject(classId, subject);
  Future<Grade?> getGradeById(String gradeId) =>
      _gradeService.getGradeById(gradeId);
  Future<bool> deleteGrade(String gradeId) =>
      _gradeService.deleteGrade(gradeId);
  Future<Map<String, GradeSummary>> getGradeSummariesByClassAndSubject(
    String classId,
    String subject,
  ) => _gradeService.getGradeSummariesByClassAndSubject(classId, subject);

  // User Service Delegates
  Future<UserModel?> getUserById(String userId) =>
      _userService.getUserById(userId);
  Future<UserModel?> getUserByAuthUid(String authUid) =>
      _userService.getUserByAuthUid(authUid);
  Future<UserModel?> getUserByEmail(String email) =>
      _userService.getUserByEmail(email);

  // Leave Service Delegates
  Future<bool> createLeaveRequest(LeaveRequest leaveRequest) =>
      _leaveService.createLeaveRequest(leaveRequest);
  Future<List<LeaveRequest>> getLeaveRequestsByStudent(String studentId) =>
      _leaveService.getLeaveRequestsByStudent(studentId);
  Future<List<LeaveRequest>> getPendingLeaveRequestsByTeacher(
    String teacherId,
    List<String> classIds,
  ) => _leaveService.getPendingLeaveRequestsByTeacher(teacherId, classIds);
  Future<bool> updateLeaveRequestStatus(
    String leaveId,
    String status,
    String teacherId,
    String comments,
  ) => _leaveService.updateLeaveRequestStatus(
    leaveId,
    status,
    teacherId,
    comments,
  );

  // --- GETTERS FOR DIRECT SERVICE ACCESS (optional) ---
  SchoolService get schoolService => _schoolService;
  StudentService get studentService => _studentService;
  TeacherService get teacherService => _teacherService;
  DriverService get driverService => _driverService;
  VehicleService get vehicleService => _vehicleService;
  CalendarService get calendarService => _calendarService;
  ConfigService get configService => _configService;
  AssignmentService get assignmentService => _assignmentService;
  AttendanceService get attendanceService => _attendanceService;
  GradeService get gradeService => _gradeService;
  UserService get userService => _userService;
  LeaveService get leaveService => _leaveService;
}
