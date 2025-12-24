import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/school_model.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream for auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Save user session
  Future<void> _saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', user.role);
    await prefs.setString('user_uid', user.uid);
    await prefs.setString('user_specific_id', user.specificId ?? '');
  }

  // Clear user session
  Future<void> _clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await prefs.remove('user_uid');
    await prefs.remove('user_specific_id');
  }

  // Get saved user session
  Future<Map<String, String>?> getSavedUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    final uid = prefs.getString('user_uid');
    final specificId = prefs.getString('user_specific_id');

    if (role != null && uid != null) {
      return {'role': role, 'uid': uid, 'specificId': specificId ?? ''};
    }
    return null;
  }

  // SCHOOL REGISTRATION
  Future<UserModel?> registerSchool({
    required String email,
    required String password,
    required String schoolName,
    required String address,
    required String phone,
    required String type,
    required String location,
    required String curriculum,
    required double latitude,
    required double longitude,
  }) async {
    try {
      print('🔄 Starting school registration...');
      print('   School Name: $schoolName');
      print('   Email: $email');
      print('   Type: $type');
      print('   Location: $location');
      print('   Curriculum: $curriculum');
      print('   Coordinates: $latitude, $longitude');

      // 1. Create Firebase Authentication user
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String schoolId = generateSchoolId();
      print('✅ Auth user created with UID: ${credential.user!.uid}');
      print('✅ Generated School ID: $schoolId');

      // 2. Create UserModel for the school admin
      UserModel schoolUser = UserModel(
        uid: schoolId,
        authUid: credential.user!.uid,
        email: email,
        name: schoolName,
        role: 'school',
        schoolId: schoolId,
        specificId: schoolId,
        createdAt: DateTime.now(),
      );

      // 3. Save user to users collection
      await _firestore
          .collection('users')
          .doc(schoolId)
          .set(schoolUser.toMap());

      print('✅ School user saved to users collection');

      // 4. Create school document with all fields including coordinates
      School school = School(
        schoolId: schoolId,
        name: schoolName,
        type: type,
        location: location, // Address string
        address: address, // Full address
        curriculum: curriculum,
        email: email,
        phone: phone,
        latitude: latitude,
        longitude: longitude,
        createdAt: DateTime.now(),
        establishmentYear: null,
        totalStudents: null,
        updatedAt: null,
        logoUrl: null,
      );

      await _firestore.collection('schools').doc(schoolId).set(school.toMap());
      print('✅ School document created with coordinates');

      // 5. Create initial school configuration
      await _firestore.collection('school_configs').doc(schoolId).set({
        'schoolId': schoolId,
        'classes': [],
        'subjects': [],
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      print('✅ Initial school configuration created');

      // 6. Save session
      await _saveUserSession(schoolUser);
      print('✅ User session saved');

      return schoolUser;
    } catch (e) {
      print('❌ Error registering school: $e');

      // Cleanup: If registration fails, delete the auth user
      try {
        User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          await currentUser.delete();
          print('🧹 Cleaned up auth user after failure');
        }
      } catch (deleteError) {
        print('⚠️ Error cleaning up auth user: $deleteError');
      }

      return null;
    }
  }

  String generateSchoolId() {
    return 'SCH${DateTime.now().millisecondsSinceEpoch}';
  }

  // SCHOOL LOGIN
  Future<UserModel?> loginSchool({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      var userDoc = await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (userDoc.exists) {
        var userData = UserModel.fromMap(userDoc.data()!);
        if (userData.role == 'school') {
          // Save session
          await _saveUserSession(userData);
          return userData;
        } else {
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'invalid-role',
            message: 'This account is not a school account',
          );
        }
      }
      return null;
    } catch (e) {
      print('Error logging in school: $e');
      return null;
    }
  }

  // TEACHER LOGIN - UPDATED VERSION
  Future<UserModel?> loginTeacher({
    required String email,
    required String password, // password is teacher ID
  }) async {
    try {
      print('🔄 Attempting teacher login: $email');

      // First, verify the teacher exists with this email
      var teacherQuery = await _firestore
          .collection('teachers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (teacherQuery.docs.isEmpty) {
        print('❌ Teacher email not found: $email');
        throw FirebaseAuthException(
          code: 'teacher-not-found',
          message: 'Teacher email not found',
        );
      }

      var teacherDoc = teacherQuery.docs.first;
      var teacherData = teacherDoc.data();
      String teacherId = teacherData['teacherId'];
      String actualTeacherId =
          teacherData['teacherId']; // This should match the password

      print('✅ Teacher found: ${teacherData['name']}');
      print('   Teacher ID: $teacherId');

      // Validate password (teacher ID)
      if (password != actualTeacherId) {
        print('❌ Incorrect teacher ID');
        throw FirebaseAuthException(
          code: 'wrong-password',
          message: 'Incorrect teacher ID',
        );
      }

      // IMPORTANT: Sign in with the actual email and teacher ID as password
      print('🔄 Signing in with Firebase Auth...');
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: actualTeacherId, // Use teacher ID as password
      );

      print('✅ Firebase Auth successful: ${credential.user!.uid}');

      // Get user data from users collection using teacherId
      var userDoc = await _firestore.collection('users').doc(teacherId).get();

      if (userDoc.exists) {
        var userData = UserModel.fromMap(userDoc.data()!);
        print('✅ User data loaded: ${userData.name}');

        // Save session
        await _saveUserSession(userData);
        return userData;
      } else {
        print('❌ User document not found in users collection');
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'user-data-missing',
          message: 'User data not found',
        );
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Unexpected error during teacher login: $e');
      throw FirebaseAuthException(
        code: 'login-failed',
        message: 'Login failed. Please try again.',
      );
    }
  }

  // Add this method to your AuthService class in auth_service.dart

  // UPDATE createTeacherAccount method in auth_service.dart
  Future<UserCredential?> createTeacherAccount({
    required String email,
    required String password,
    required String teacherId,
  }) async {
    try {
      print('🔄 Creating teacher account: $email');

      // Store the current user before creating teacher
      User? currentUser = _auth.currentUser;

      // Create the user in Firebase Auth
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('✅ Teacher Firebase Auth account created: ${credential.user!.uid}');

      // Update user display name
      await credential.user?.updateDisplayName(teacherId);

      // Create user document in Firestore with proper structure
      UserModel teacherUser = UserModel(
        uid: credential.user!.uid,
        email: email,
        name: teacherId, // Using teacherId as name initially
        role: 'teacher',
        specificId: teacherId,
        authUid: credential.user!.uid, // Store auth UID for lookup
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(teacherId) // Use teacherId as document ID
          .set(teacherUser.toMap());

      print('✅ Teacher user document created in Firestore');

      // IMPORTANT: Switch back to the original school admin user
      if (currentUser != null) {
        await _auth.signOut(); // Sign out the teacher account
        await _auth.signInWithEmailAndPassword(
          email: currentUser.email!,
          password:
              'your_school_admin_password', // You need to store this securely
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      print(
        '❌ Firebase Auth Error creating teacher account: ${e.code} - ${e.message}',
      );
      return null;
    } catch (e) {
      print('❌ Unexpected error creating teacher account: $e');
      return null;
    }
  }

  // STUDENT LOGIN - UPDATED TO USE ACTUAL PASSWORD
  Future<UserModel?> loginStudent({
    required String email,
    required String password, // Use actual password, not admission number
  }) async {
    try {
      print('🔄 Attempting student login: $email');

      // First, verify the student exists with this email
      var studentQuery = await _firestore
          .collection('students')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (studentQuery.docs.isEmpty) {
        print('❌ Student email not found: $email');
        throw FirebaseAuthException(
          code: 'student-not-found',
          message: 'Student email not found. Please register first.',
        );
      }

      var studentDoc = studentQuery.docs.first;
      var studentData = studentDoc.data();
      String studentId = studentData['studentId'];
      String authUid = studentData['authUid'] ?? '';

      print(
        '✅ Student found: ${studentData['firstName']} ${studentData['lastName']}',
      );
      print('   Student ID: $studentId');
      print('   Auth UID: $authUid');

      // IMPORTANT: Sign in with the actual email and password provided during registration
      print('🔄 Signing in with Firebase Auth...');
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password, // Use the actual password, not admission number
      );

      print('✅ Firebase Auth successful: ${credential.user!.uid}');

      // Get user data from users collection
      var userDoc = await _firestore.collection('users').doc(studentId).get();

      if (userDoc.exists) {
        var userData = UserModel.fromMap(userDoc.data()!);
        print('✅ User data loaded: ${userData.name}');

        // Save session
        await _saveUserSession(userData);
        return userData;
      } else {
        print('❌ User document not found in users collection');
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'user-data-missing',
          message: 'User data not found',
        );
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');

      // Provide more specific error messages
      if (e.code == 'wrong-password') {
        throw FirebaseAuthException(
          code: 'wrong-password',
          message:
              'Incorrect password. Please use the password you created during registration.',
        );
      } else if (e.code == 'user-not-found') {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No account found with this email. Please register first.',
        );
      }

      rethrow;
    } catch (e) {
      print('❌ Unexpected error during student login: $e');
      throw FirebaseAuthException(
        code: 'login-failed',
        message: 'Login failed. Please try again.',
      );
    }
  }

  // DRIVER LOGIN - UPDATED VERSION
  Future<UserModel?> loginDriver({
    required String email,
    required String password, // password is driver ID
  }) async {
    try {
      print('🔄 Attempting driver login: $email');

      // First, verify the driver exists with this email
      var driverQuery = await _firestore
          .collection('drivers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (driverQuery.docs.isEmpty) {
        print('❌ Driver email not found: $email');
        throw FirebaseAuthException(
          code: 'driver-not-found',
          message: 'Driver email not found',
        );
      }

      var driverDoc = driverQuery.docs.first;
      var driverData = driverDoc.data();
      String driverId = driverData['driverId'];
      String actualDriverId =
          driverData['driverId']; // This should match the password

      print('✅ Driver found: ${driverData['name']}');
      print('   Driver ID: $driverId');

      // Validate password (driver ID)
      if (password != actualDriverId) {
        print('❌ Incorrect driver ID');
        throw FirebaseAuthException(
          code: 'wrong-password',
          message: 'Incorrect driver ID',
        );
      }

      // IMPORTANT: Sign in with the actual email and driver ID as password
      print('🔄 Signing in with Firebase Auth...');
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: actualDriverId, // Use driver ID as password
      );

      print('✅ Firebase Auth successful: ${credential.user!.uid}');

      // Get user data from users collection using driverId
      var userDoc = await _firestore.collection('users').doc(driverId).get();

      if (userDoc.exists) {
        var userData = UserModel.fromMap(userDoc.data()!);
        print('✅ User data loaded: ${userData.name}');

        // Save session
        await _saveUserSession(userData);
        return userData;
      } else {
        print('❌ User document not found in users collection');
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'user-data-missing',
          message: 'User data not found',
        );
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Unexpected error during driver login: $e');
      throw FirebaseAuthException(
        code: 'login-failed',
        message: 'Login failed. Please try again.',
      );
    }
  }

  // LOGOUT
  Future<void> signOut() async {
    try {
      await _clearUserSession();
      await _auth.signOut();

      // Force clear any cached data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      print('✅ User signed out successfully');
    } catch (e) {
      print('❌ Error during sign out: $e');
    }
  }

  // GET CURRENT USER DATA - CORRECTED VERSION
  Future<UserModel?> getCurrentUserData() async {
    try {
      User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        print('❌ No Firebase user logged in');
        return null;
      }

      print('🔄 Getting current user data...');
      print('   Firebase UID: ${firebaseUser.uid}');
      print('   Firebase Email: ${firebaseUser.email}');

      // Method 1: Try to get user data by Firebase UID (for schools)
      print('   Checking users collection for UID: ${firebaseUser.uid}');
      var userDocByUid = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (userDocByUid.exists) {
        print('✅ Found user document by Firebase UID');
        UserModel user = UserModel.fromMap(userDocByUid.data()!);
        return user;
      }

      // Method 2: Try to find user by authUid field (for students, teachers, drivers)
      print('   Checking users collection for authUid: ${firebaseUser.uid}');
      var queryByAuthUid = await _firestore
          .collection('users')
          .where('authUid', isEqualTo: firebaseUser.uid)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (queryByAuthUid.docs.isNotEmpty) {
        print('✅ Found user document by authUid field');
        UserModel user = UserModel.fromMap(queryByAuthUid.docs.first.data());
        return user;
      }

      // Method 3: Try to find user by email (fallback)
      if (firebaseUser.email != null) {
        print('   Checking users collection for email: ${firebaseUser.email}');
        var queryByEmail = await _firestore
            .collection('users')
            .where('email', isEqualTo: firebaseUser.email)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5));

        if (queryByEmail.docs.isNotEmpty) {
          print('✅ Found user document by email');
          UserModel user = UserModel.fromMap(queryByEmail.docs.first.data());
          return user;
        }
      }

      print('❌ No user document found for current Firebase user');
      return null;
    } catch (e) {
      print('❌ Error getting current user data: $e');
      return null;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  // Get current user role
  Future<String?> getCurrentUserRole() async {
    UserModel? user = await getCurrentUserData();
    return user?.role;
  }

  // Quick check for existing session
  Future<bool> hasExistingSession() async {
    final session = await getSavedUserSession();
    return session != null && _auth.currentUser != null;
  }

  // Delete current user account
  Future<void> deleteCurrentAccount() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _clearUserSession();
        await user.delete();
        print('✅ User account deleted successfully');
      }
    } catch (e) {
      print('❌ Error deleting user account: $e');
      rethrow;
    }
  }

  // Get user by specific ID (studentId, teacherId, etc.)
  Future<UserModel?> getUserBySpecificId(String specificId) async {
    try {
      var userDoc = await _firestore.collection('users').doc(specificId).get();

      if (userDoc.exists) {
        return UserModel.fromMap(userDoc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user by specific ID: $e');
      return null;
    }
  }
}
