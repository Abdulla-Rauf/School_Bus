import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/student_model.dart';
import '../../../models/user_model.dart';
import 'package:school_bus2/core/theme/premium_theme.dart';
import '../../../models/school_config_model.dart';

class AddStudentScreen extends StatefulWidget {
  final Student? student; // Optional student for editing mode

  const AddStudentScreen({super.key, this.student});

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _primaryPhoneController = TextEditingController();
  final _secondaryPhoneController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _admissionNumberController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;
  UserModel? _currentUser;
  SchoolConfig? _schoolConfig;
  final ImagePicker _picker = ImagePicker();
  String? _existingPhotoUrl;

  String? _selectedClassName;
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  String? _selectedBloodGroup;

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  final List<String> _genders = ['Male', 'Female', 'Other'];

  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _initializeFormData();
  }

  void _initializeFormData() {
    if (widget.student != null) {
      _firstNameController.text = widget.student!.firstName;
      _lastNameController.text = widget.student!.lastName;
      _emailController.text = widget.student!.email;
      _primaryPhoneController.text = widget.student!.primaryPhone;
      _secondaryPhoneController.text = widget.student!.secondaryPhone;
      _fatherNameController.text = widget.student!.fatherName;
      _motherNameController.text = widget.student!.motherName;
      _guardianNameController.text = widget.student!.guardianName;
      _addressController.text = widget.student!.address;
      _admissionNumberController.text = widget.student!.admissionNumber;
      _selectedClassName = widget.student!.className;
      _selectedGender = widget.student!.gender;
      _selectedDateOfBirth = widget.student!.dateOfBirth;
      _selectedBloodGroup = widget.student!.bloodGroup;
      _existingPhotoUrl = widget.student!.photoUrl;
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      AuthService authService = Provider.of<AuthService>(
        context,
        listen: false,
      );
      if (!mounted) return;

      UserModel? user = await authService
          .getCurrentUserData(); // Error handling is now inside getCurrentUserData

      if (!mounted) return;

      if (user == null) {
        setState(() => _hasLoadError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load user data. Check connection.'),
          ),
        );
        return;
      }

      setState(() {
        _currentUser = user;
        _hasLoadError = false;
      });
      _loadSchoolConfiguration();
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasLoadError = true);
      print('Error in _loadCurrentUser: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading user: $e')));
    }
  }

  Future<void> _loadSchoolConfiguration() async {
    if (_currentUser == null) return;

    try {
      DatabaseService dbService = DatabaseService();
      SchoolConfig? config = await dbService.getSchoolConfig(_currentUser!.uid);

      if (!mounted) return;
      setState(() {
        _schoolConfig = config;
      });
    } catch (e) {
      print('Error loading school config: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _existingPhotoUrl = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDateOfBirth ??
          DateTime.now().subtract(const Duration(days: 365 * 5)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a class'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    if (_selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select gender')));
      return;
    }
    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      DatabaseService dbService = DatabaseService();
      String firstName = _firstNameController.text.trim();
      String lastName = _lastNameController.text.trim();
      String fullName = '$firstName $lastName';

      if (widget.student == null) {
        // ADD NEW STUDENT
        String studentId = dbService.generateId(prefix: 'STU');
        String admissionNumber = _admissionNumberController.text.trim().isEmpty
            ? 'LF${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
            : _admissionNumberController.text.trim();

        Student newStudent = Student(
          studentId: studentId,
          admissionNumber: admissionNumber,
          firstName: firstName,
          lastName: lastName,
          email: _emailController.text.trim(),
          primaryPhone: _primaryPhoneController.text.trim(),
          secondaryPhone: _secondaryPhoneController.text.trim(),
          fatherName: _fatherNameController.text.trim(),
          motherName: _motherNameController.text.trim(),
          guardianName: _guardianNameController.text.trim(),
          address: _addressController.text.trim(),
          bloodGroup: _selectedBloodGroup ?? '',
          schoolId: _currentUser!.uid,
          schoolName: _currentUser?.schoolId ?? '',
          gender: _selectedGender!,
          className: _selectedClassName!,
          dateOfBirth: _selectedDateOfBirth!,
          photoUrl: null,
          authUid: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        bool success = await dbService.addStudent(newStudent, _selectedImage);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Student $fullName added successfully!',
                style: const TextStyle(color: Colors.black),
              ),
              backgroundColor: PremiumTheme.neonLime,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          _showCredentialsDialog(admissionNumber, fullName);

          // Clear form
          _formKey.currentState!.reset();
          setState(() {
            _selectedClassName = null;
            _selectedGender = null;
            _selectedDateOfBirth = null;
            _selectedBloodGroup = null;
            _selectedImage = null;
            _existingPhotoUrl = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add student')),
          );
        }
      } else {
        // UPDATE EXISTING STUDENT
        Student updatedStudent = Student(
          studentId: widget.student!.studentId,
          admissionNumber: _admissionNumberController.text.trim(),
          firstName: firstName,
          lastName: lastName,
          email: _emailController.text.trim(),
          primaryPhone: _primaryPhoneController.text.trim(),
          secondaryPhone: _secondaryPhoneController.text.trim(),
          fatherName: _fatherNameController.text.trim(),
          motherName: _motherNameController.text.trim(),
          guardianName: _guardianNameController.text.trim(),
          address: _addressController.text.trim(),
          bloodGroup: _selectedBloodGroup ?? '',
          schoolId: _currentUser!.uid,
          schoolName: _currentUser?.schoolId ?? widget.student!.schoolName,
          gender: _selectedGender!,
          className: _selectedClassName!,
          dateOfBirth: _selectedDateOfBirth!,
          photoUrl: _existingPhotoUrl,
          authUid: widget.student!.authUid,
          createdAt: widget.student!.createdAt,
          updatedAt: DateTime.now(),
        );

        bool success = await dbService.updateStudent(
          updatedStudent,
          _selectedImage,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Student $fullName updated successfully!',
                style: const TextStyle(color: Colors.black),
              ),
              backgroundColor: PremiumTheme.neonLime,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );

          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update student')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCredentialsDialog(String admissionNumber, String studentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PremiumTheme.darkGrey,
        surfaceTintColor: PremiumTheme.darkGrey,
        title: const Text(
          'Student Added Successfully!',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Student login credentials:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Text(
              'Admission Number: $admissionNumber',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Password: $studentName',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please share these credentials with the student.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Note: Student should use their name as password during login.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: PremiumTheme.neonLime)),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        const Text(
          'Student Photo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: PremiumTheme.neonLime,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: PremiumTheme.darkGrey,
              borderRadius: BorderRadius.circular(60),
              border: Border.all(color: PremiumTheme.neonLime, width: 2),
              boxShadow: [
                BoxShadow(
                  color: PremiumTheme.neonLime.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  )
                : _existingPhotoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.network(_existingPhotoUrl!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: PremiumTheme.neonLime.withOpacity(0.5),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Add Photo',
                        style: TextStyle(
                          fontSize: 12,
                          color: PremiumTheme.neonLime,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  List<String> get _availableClasses {
    if (_schoolConfig == null) return [];
    List<String> allClasses = [];
    for (var schoolClass in _schoolConfig!.classes) {
      allClasses.addAll(schoolClass.getFullClassNames());
    }
    return allClasses..sort();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.student != null;

    return Scaffold(
      backgroundColor: PremiumTheme.black,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Student' : 'Add Student',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: PremiumTheme.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _currentUser == null
          ? Center(
              child: _hasLoadError
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load user data',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCurrentUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PremiumTheme.neonLime,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Photo Picker
                      _buildImagePicker(),
                      const SizedBox(height: 20),

                      // Admission Number (Optional for new students)
                      TextFormField(
                        controller: _admissionNumberController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: isEditing
                              ? 'Admission Number *'
                              : 'Admission Number (Optional)',
                          prefixIcon: const Icon(
                            Icons.confirmation_number,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        validator: isEditing
                            ? (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter admission number';
                                }
                                return null;
                              }
                            : null,
                      ),
                      const SizedBox(height: 15),

                      // First Name Field
                      TextFormField(
                        controller: _firstNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'First Name *',
                          prefixIcon: const Icon(
                            Icons.person,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter first name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Last Name Field
                      TextFormField(
                        controller: _lastNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Last Name *',
                          prefixIcon: const Icon(
                            Icons.person,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter last name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email *',
                          prefixIcon: const Icon(
                            Icons.email,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Gender Selection
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        dropdownColor: PremiumTheme.darkGrey,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Gender *',
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        items: _genders.map((gender) {
                          return DropdownMenuItem(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select gender';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Primary Phone Field
                      TextFormField(
                        controller: _primaryPhoneController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Primary Phone *',
                          prefixIcon: const Icon(
                            Icons.phone,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter primary phone number';
                          }
                          if (value.length < 10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Secondary Phone Field
                      TextFormField(
                        controller: _secondaryPhoneController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Secondary Phone',
                          prefixIcon: const Icon(
                            Icons.phone_iphone,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 15),

                      // Father Name Field
                      TextFormField(
                        controller: _fatherNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Father's Name *",
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Please enter father's name";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Mother Name Field
                      TextFormField(
                        controller: _motherNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Mother's Name *",
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Please enter mother's name";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Guardian Name Field
                      TextFormField(
                        controller: _guardianNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Guardian's Name",
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Address Field
                      TextFormField(
                        controller: _addressController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Address *',
                          prefixIcon: const Icon(
                            Icons.location_on,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Class Selection
                      DropdownButtonFormField<String>(
                        initialValue: _selectedClassName,
                        dropdownColor: PremiumTheme.darkGrey,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Class *',
                          prefixIcon: const Icon(
                            Icons.class_,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        items: _availableClasses.map((className) {
                          return DropdownMenuItem(
                            value: className,
                            child: Text(className),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedClassName = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a class';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      // Date of Birth
                      InkWell(
                        onTap: _selectDateOfBirth,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date of Birth *',
                            prefixIcon: const Icon(
                              Icons.calendar_today,
                              color: PremiumTheme.neonLime,
                            ),
                            filled: true,
                            fillColor: PremiumTheme.darkGrey,
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: PremiumTheme.neonLime,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDateOfBirth != null
                                    ? '${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.year}'
                                    : 'Select Date',
                                style: TextStyle(
                                  color: _selectedDateOfBirth != null
                                      ? Colors.white
                                      : Colors.grey[400],
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Blood Group
                      DropdownButtonFormField<String>(
                        initialValue: _bloodGroups.contains(_selectedBloodGroup)
                            ? _selectedBloodGroup
                            : null,
                        dropdownColor: PremiumTheme.darkGrey,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Blood Group',
                          prefixIcon: const Icon(
                            Icons.bloodtype,
                            color: PremiumTheme.neonLime,
                          ),
                          filled: true,
                          fillColor: PremiumTheme.darkGrey,
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: PremiumTheme.neonLime,
                            ),
                          ),
                        ),
                        items: _bloodGroups.map((bloodGroup) {
                          return DropdownMenuItem(
                            value: bloodGroup,
                            child: Text(bloodGroup),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedBloodGroup = value;
                          });
                        },
                      ),

                      const SizedBox(height: 30),

                      // Submit Button
                      _isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _saveStudent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PremiumTheme.neonLime,
                                  foregroundColor: PremiumTheme.black,
                                  elevation: 5,
                                  shadowColor: PremiumTheme.neonLime
                                      .withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  isEditing ? 'Update Student' : 'Add Student',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
