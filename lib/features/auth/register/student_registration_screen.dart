// student_registration_screen.dart
import 'package:flutter/material.dart';

import '../../../models/school_config_model.dart';
import '../../../models/school_model.dart';
import '../../../models/student_model.dart';
import '../../../services/database_service.dart';
import '../../common/location_picker_screen.dart';

class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  _StudentRegistrationScreenState createState() =>
      _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _admissionNumberController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _primaryPhoneController = TextEditingController();
  final _secondaryPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Location Variables
  double? _selectedLat;
  double? _selectedLng;
  String? _selectedLocationAddress;

  String? _selectedSchoolId;
  String? _selectedGender;
  String? _selectedClass;
  String? _selectedBloodGroup;
  DateTime? _selectedDateOfBirth;

  List<School> _schools = [];
  final List<String> _genders = ['Male', 'Female', 'Other'];
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
  List<String> _availableClasses = [];

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  // ... (previous loadSchools code)

  void _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLat: _selectedLat,
          initialLng: _selectedLng,
          initialAddress: _selectedLocationAddress,
          title: 'Select Home Location',
        ),
      ),
    );

    if (result != null && result is LocationResult) {
      setState(() {
        _selectedLat = result.latitude;
        _selectedLng = result.longitude;
        _selectedLocationAddress = result.address;

        String addressText = result.address ?? '';
        if (result.landmark != null && result.landmark!.isNotEmpty) {
          addressText += '\n(Landmark: ${result.landmark})';
        }
        _addressController.text = addressText;
      });
    }
  }

  Future<void> _registerStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    if (_selectedSchoolId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a school')));
      return;
    }
    if (_selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select gender')));
      return;
    }
    if (_selectedClass == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select class')));
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

      // Check if admission number already exists
      bool admissionExists = await dbService.checkAdmissionNumberExists(
        _admissionNumberController.text.trim(),
      );

      if (admissionExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admission number already exists')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Check if email already exists
      bool emailExists = await dbService.checkEmailExists(
        _emailController.text.trim(),
      );

      if (emailExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email already registered')),
        );
        setState(() => _isLoading = false);
        return;
      }

      String studentId = dbService.generateId(prefix: 'STU');
      School selectedSchool = _schools.firstWhere(
        (school) => school.schoolId == _selectedSchoolId,
      );

      Student newStudent = Student(
        studentId: studentId,
        admissionNumber: _admissionNumberController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        primaryPhone: _primaryPhoneController.text.trim(),
        secondaryPhone: _secondaryPhoneController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        motherName: _motherNameController.text.trim(),
        guardianName: _guardianNameController.text.trim(),
        address: _addressController.text.trim(),
        bloodGroup: _selectedBloodGroup ?? '',
        schoolId: _selectedSchoolId!,
        schoolName: selectedSchool.name,
        gender: _selectedGender!,
        className: _selectedClass!,
        dateOfBirth: _selectedDateOfBirth!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        latitude: _selectedLat,
        longitude: _selectedLng,
      );

      bool success = await dbService.addStudentWithPassword(
        newStudent,
        _passwordController.text.trim(),
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! You can now login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration failed. Please try again.'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ...

  // In build method, add the Location Picker button next to Address field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
    );
  }

  Future<void> _loadSchools() async {
    try {
      DatabaseService dbService = DatabaseService();
      List<School> schools = await dbService.getAllSchools();

      setState(() {
        _schools = schools;
      });
    } catch (e) {
      print('Error loading schools: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading schools: $e')));
    }
  }

  Future<void> _loadSchoolClasses(String schoolId) async {
    try {
      DatabaseService dbService = DatabaseService();
      SchoolConfig? config = await dbService.getSchoolConfig(schoolId);

      setState(() {
        _availableClasses =
            config?.classes
                .expand((schoolClass) => schoolClass.getFullClassNames())
                .toList() ??
            [];
        _availableClasses.sort();
      });
    } catch (e) {
      print('Error loading classes: $e');
      setState(() {
        _availableClasses = [];
      });
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Registration'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Personal Information
                    _buildSectionHeader('Personal Information'),
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name *',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name *',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _admissionNumberController,
                      label: 'Admission Number *',
                      icon: Icons.confirmation_number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter admission number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Gender Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender *',
                        prefixIcon: const Icon(
                          Icons.transgender,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
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

                    // Date of Birth
                    InkWell(
                      onTap: _selectDateOfBirth,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Date of Birth *',
                          prefixIcon: const Icon(
                            Icons.calendar_today,
                            color: Colors.blue,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
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
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Blood Group
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBloodGroup,
                      decoration: InputDecoration(
                        labelText: 'Blood Group',
                        prefixIcon: const Icon(
                          Icons.bloodtype,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
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
                    const SizedBox(height: 20),

                    // School Information
                    _buildSectionHeader('School Information'),

                    // School Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSchoolId,
                      decoration: InputDecoration(
                        labelText: 'School *',
                        prefixIcon: const Icon(
                          Icons.school,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _schools.map((school) {
                        return DropdownMenuItem(
                          value: school.schoolId,
                          child: Text(school.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSchoolId = value;
                          _selectedClass = null;
                        });
                        if (value != null) {
                          _loadSchoolClasses(value);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select school';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),

                    // Class Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedClass,
                      decoration: InputDecoration(
                        labelText: 'Class *',
                        prefixIcon: const Icon(
                          Icons.class_,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      items: _availableClasses.map((className) {
                        return DropdownMenuItem(
                          value: className,
                          child: Text(className),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedClass = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select class';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Parent/Guardian Information
                    _buildSectionHeader('Parent/Guardian Information'),
                    _buildTextField(
                      controller: _fatherNameController,
                      label: "Father's Name *",
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter father's name";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _motherNameController,
                      label: "Mother's Name *",
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Please enter mother's name";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _guardianNameController,
                      label: "Guardian's Name",
                      icon: Icons.supervised_user_circle,
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _primaryPhoneController,
                      label: 'Primary Phone *',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter primary phone';
                        }
                        if (value.length < 10) {
                          return 'Please enter valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _secondaryPhoneController,
                      label: 'Secondary Phone',
                      icon: Icons.phone_iphone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),

                    // Contact Information
                    _buildSectionHeader('Contact Information'),
                    _buildTextField(
                      controller: _addressController,
                      label: 'Address *',
                      icon: Icons.location_on,
                      maxLines: 3,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.map, color: Colors.blue),
                        onPressed: _openLocationPicker,
                        tooltip: 'Pick Location on Map',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address *',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Account Information
                    _buildSectionHeader('Account Information'),
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password *',
                      icon: Icons.lock,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password *',
                      icon: Icons.lock_outline,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _registerStudent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Already have an account?'),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}

// ... (Rest of existing imports are fine, but I'll add the new classes at the bottom)
