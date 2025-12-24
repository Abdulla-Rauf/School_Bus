import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/teacher_model.dart';
import '../../../models/user_model.dart';
import 'package:school_bus2/core/theme/premium_theme.dart';
import '../../../models/school_config_model.dart';

class AddTeacherScreen extends StatefulWidget {
  final Teacher? teacher;

  const AddTeacherScreen({super.key, this.teacher});

  @override
  _AddTeacherScreenState createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends State<AddTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alternatePhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _experienceController = TextEditingController();
  final _specializationController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;
  UserModel? _currentUser;
  SchoolConfig? _schoolConfig;

  String _selectedGender = 'Male';
  DateTime _selectedDob = DateTime.now().subtract(
    const Duration(days: 365 * 25),
  );
  DateTime _selectedJoiningDate = DateTime.now();
  String _selectedBloodGroup = 'A+';
  String _selectedPrimaryClass = '';
  final List<String> _selectedSecondaryClasses = [];
  final List<String> _selectedSubjects = [];
  String? _existingPhotoUrl;

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
  final List<String> _qualifications = [
    'B.Ed',
    'M.Ed',
    'B.Sc',
    'M.Sc',
    'B.A',
    'M.A',
    'Ph.D',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  void _initializeFormData() {
    if (widget.teacher != null) {
      _firstNameController.text = widget.teacher!.firstName;
      _lastNameController.text = widget.teacher!.lastName;
      _selectedGender = widget.teacher!.gender;
      _selectedDob = widget.teacher!.dateOfBirth;
      _selectedBloodGroup = widget.teacher!.bloodGroup;
      _phoneController.text = widget.teacher!.phone;
      _alternatePhoneController.text = widget.teacher!.alternatePhone ?? '';
      _emailController.text = widget.teacher!.email;
      _addressController.text = widget.teacher!.address;
      _qualificationController.text = widget.teacher!.qualification;
      _experienceController.text = widget.teacher!.experience.toString();
      _specializationController.text = widget.teacher!.specialization;
      _selectedJoiningDate = widget.teacher!.joiningDate;
      _selectedPrimaryClass = widget.teacher!.primaryClass;
      _selectedSecondaryClasses.addAll(widget.teacher!.secondaryClasses);
      _selectedSubjects.addAll(
        widget.teacher!.specialization
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
      _existingPhotoUrl = widget.teacher!.photoUrl;
    }
  }

  Future<void> _loadCurrentUser() async {
    AuthService authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user = await authService.getCurrentUserData();
    setState(() {
      _currentUser = user;
    });
    await _loadSchoolConfiguration();
    _initializeFormData();
  }

  Future<void> _loadSchoolConfiguration() async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();
    SchoolConfig? config = await dbService.getSchoolConfig(_currentUser!.uid);

    setState(() {
      _schoolConfig = config;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
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
      _showErrorSnackbar('Error picking image: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isDob) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDob ? _selectedDob : _selectedJoiningDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isDob) {
          _selectedDob = picked;
        } else {
          _selectedJoiningDate = picked;
        }
      });
    }
  }

  void _showClassSelectionDialog() {
    if (_schoolConfig == null || _schoolConfig!.classes.isEmpty) {
      _showErrorSnackbar('No classes configured. Please set up classes first.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _ClassSelectionDialog(
        schoolConfig: _schoolConfig!,
        selectedPrimaryClass: _selectedPrimaryClass,
        selectedSecondaryClasses: _selectedSecondaryClasses,
        onSelectionChanged: (primaryClass, secondaryClasses) {
          setState(() {
            _selectedPrimaryClass = primaryClass;
            _selectedSecondaryClasses.clear();
            _selectedSecondaryClasses.addAll(secondaryClasses);
          });
        },
      ),
    );
  }

  void _showSubjectSelectionDialog() {
    if (_schoolConfig == null) {
      _showErrorSnackbar('School configuration not loaded.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _SubjectSelectionDialog(
        availableSubjects: _getAvailableSubjects(),
        selectedSubjects: _selectedSubjects,
        onSelectionChanged: (subjects) {
          setState(() {
            _selectedSubjects.clear();
            _selectedSubjects.addAll(subjects);
            _specializationController.text = subjects.join(', ');
          });
        },
      ),
    );
  }

  List<String> _getAvailableSubjects() {
    if (_schoolConfig == null) return [];
    return _schoolConfig!.subjects;
  }

  Future<void> _saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPrimaryClass.isEmpty) {
      _showErrorSnackbar('Please select a primary class');
      return;
    }

    if (_selectedSubjects.isEmpty) {
      _showErrorSnackbar('Please select at least one subject');
      return;
    }

    setState(() => _isLoading = true);

    try {
      DatabaseService dbService = DatabaseService();

      if (widget.teacher == null) {
        // ADD NEW TEACHER
        String teacherId = dbService.generateId(prefix: 'TCH');

        Teacher newTeacher = Teacher(
          teacherId: teacherId,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          gender: _selectedGender,
          dateOfBirth: _selectedDob,
          bloodGroup: _selectedBloodGroup,
          phone: _phoneController.text.trim(),
          alternatePhone: _alternatePhoneController.text.trim().isEmpty
              ? null
              : _alternatePhoneController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          qualification: _qualificationController.text.trim(),
          experience: int.tryParse(_experienceController.text.trim()) ?? 0,
          specialization: _selectedSubjects.join(', '),
          schoolId: _currentUser!.uid,
          schoolName: _currentUser!.name ?? 'Unknown School',
          joiningDate: _selectedJoiningDate,
          primaryClass: _selectedPrimaryClass,
          secondaryClasses: _selectedSecondaryClasses,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        bool success = await dbService.addTeacher(newTeacher, _selectedImage);

        if (success) {
          _showSuccessSnackbar(
            'Teacher ${newTeacher.name} added successfully!',
          );
          _showCredentialsDialog(teacherId);
          _resetForm();
        } else {
          _showErrorSnackbar('Failed to add teacher');
        }
      } else {
        // UPDATE EXISTING TEACHER
        Teacher updatedTeacher = Teacher(
          teacherId: widget.teacher!.teacherId,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          gender: _selectedGender,
          dateOfBirth: _selectedDob,
          bloodGroup: _selectedBloodGroup,
          phone: _phoneController.text.trim(),
          alternatePhone: _alternatePhoneController.text.trim().isEmpty
              ? null
              : _alternatePhoneController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          qualification: _qualificationController.text.trim(),
          experience: int.tryParse(_experienceController.text.trim()) ?? 0,
          specialization: _selectedSubjects.join(', '),
          schoolId: _currentUser!.uid,
          schoolName: _currentUser!.name ?? 'Unknown School',
          joiningDate: _selectedJoiningDate,
          primaryClass: _selectedPrimaryClass,
          secondaryClasses: _selectedSecondaryClasses,
          photoUrl: _existingPhotoUrl,
          createdAt: widget.teacher!.createdAt,
          updatedAt: DateTime.now(),
        );

        bool success = await dbService.updateTeacher(
          updatedTeacher,
          _selectedImage,
        );

        if (success) {
          _showSuccessSnackbar(
            'Teacher ${updatedTeacher.name} updated successfully!',
          );
          Navigator.pop(context);
        } else {
          _showErrorSnackbar('Failed to update teacher');
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCredentialsDialog(String teacherId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PremiumTheme.darkGrey,
        surfaceTintColor: PremiumTheme.darkGrey,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teacher login credentials:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            _buildCredentialRow('Email:', _emailController.text),
            _buildCredentialRow('Password:', teacherId),
            const SizedBox(height: 12),
            Text(
              'Please share these credentials with the teacher.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
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

  Widget _buildCredentialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedImage = null;
      _existingPhotoUrl = null;
      _selectedGender = 'Male';
      _selectedDob = DateTime.now().subtract(const Duration(days: 365 * 25));
      _selectedJoiningDate = DateTime.now();
      _selectedBloodGroup = 'A+';
      _selectedPrimaryClass = '';
      _selectedSecondaryClasses.clear();
      _selectedSubjects.clear();
    });
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.black)),
        backgroundColor: PremiumTheme.neonLime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        const Text(
          'Teacher Photo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
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
                      const SizedBox(height: 8),
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

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLines,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: PremiumTheme.neonLime),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PremiumTheme.neonLime),
        ),
        filled: true,
        fillColor: PremiumTheme.darkGrey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PremiumTheme.darkGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: PremiumTheme.darkGrey,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: PremiumTheme.neonLime),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value, style: const TextStyle(color: Colors.white)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateField({
    required DateTime value,
    required String label,
    required IconData icon,
    required bool isDob,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PremiumTheme.darkGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: PremiumTheme.neonLime),
        title: Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        subtitle: Text(
          '${value.day}/${value.month}/${value.year}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        trailing: Icon(Icons.calendar_today, color: Colors.grey[400]),
        onTap: () => _selectDate(context, isDob),
      ),
    );
  }

  Widget _buildClassAssignmentSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PremiumTheme.darkGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Class Assignment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (_schoolConfig == null || _schoolConfig!.classes.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  const Text(
                    'No classes configured! Please set up classes in School Configuration first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // Primary Class
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PremiumTheme.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.class_,
                      color: PremiumTheme.neonLime,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Primary Class',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    _selectedPrimaryClass.isEmpty
                        ? 'Not selected'
                        : _selectedPrimaryClass,
                    style: TextStyle(
                      color: _selectedPrimaryClass.isEmpty
                          ? Colors.grey
                          : Colors.white70,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: _showClassSelectionDialog,
                ),
                const SizedBox(height: 8),

                // Secondary Classes
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PremiumTheme.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(
                      Icons.class_outlined,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Secondary Classes',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    _selectedSecondaryClasses.isEmpty
                        ? 'No additional classes'
                        : '${_selectedSecondaryClasses.length} classes selected',
                    style: TextStyle(
                      color: _selectedSecondaryClasses.isEmpty
                          ? Colors.grey
                          : Colors.white70,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: _showClassSelectionDialog,
                ),

                if (_selectedSecondaryClasses.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedSecondaryClasses
                        .map(
                          (className) => Chip(
                            label: Text(
                              className,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: PremiumTheme.black,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelectionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PremiumTheme.darkGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subject Specialization',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (_schoolConfig == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  const Text(
                    'School configuration not loaded.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else if (_schoolConfig!.subjects.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  const Text(
                    'No subjects configured! Please set up subjects in School Configuration first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                _buildFormField(
                  controller: _specializationController,
                  label: 'Selected Subjects',
                  icon: Icons.subject,
                  readOnly: true,
                  onTap: _showSubjectSelectionDialog,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select subjects';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (_selectedSubjects.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedSubjects
                        .map(
                          (subject) => Chip(
                            label: Text(
                              subject,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: PremiumTheme.black,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.1),
                            ),
                            deleteIcon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white54,
                            ),
                            onDeleted: () {
                              setState(() {
                                _selectedSubjects.remove(subject);
                                _specializationController.text =
                                    _selectedSubjects.join(', ');
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_selectedSubjects.length} subjects selected',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.teacher != null;

    return Scaffold(
      backgroundColor: PremiumTheme.black,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Teacher' : 'Add Teacher',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: PremiumTheme.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: _currentUser == null
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  PremiumTheme.neonLime,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Photo Picker
                      _buildImagePicker(),
                      const SizedBox(height: 24),

                      // Personal Details Section
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Personal Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // First Name & Last Name
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              controller: _firstNameController,
                              label: 'First Name',
                              icon: Icons.person,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter first name';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              controller: _lastNameController,
                              label: 'Last Name',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter last name';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Gender & Blood Group
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              value: _selectedGender,
                              items: _genders,
                              label: 'Gender',
                              icon: Icons.transgender,
                              onChanged: (value) {
                                setState(() {
                                  _selectedGender = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdownField(
                              value: _selectedBloodGroup,
                              items: _bloodGroups,
                              label: 'Blood Group',
                              icon: Icons.bloodtype,
                              onChanged: (value) {
                                setState(() {
                                  _selectedBloodGroup = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Date of Birth & Joining Date
                      _buildDateField(
                        value: _selectedDob,
                        label: 'Date of Birth',
                        icon: Icons.cake,
                        isDob: true,
                      ),
                      const SizedBox(height: 16),
                      _buildDateField(
                        value: _selectedJoiningDate,
                        label: 'Joining Date',
                        icon: Icons.date_range,
                        isDob: false,
                      ),
                      const SizedBox(height: 16),

                      // Phone & Alternate Phone
                      _buildFormField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter phone number';
                          }
                          if (value.length < 10) {
                            return 'Please enter valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _buildFormField(
                        controller: _alternatePhoneController,
                        label: 'Alternate Phone (Optional)',
                        icon: Icons.phone_iphone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      _buildFormField(
                        controller: _emailController,
                        label: 'Email Address',
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
                      const SizedBox(height: 16),

                      // Address
                      _buildFormField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.location_on,
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Professional Details Section
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Professional Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Qualification & Experience
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdownField(
                              value: _qualificationController.text.isEmpty
                                  ? 'B.Ed'
                                  : _qualificationController.text,
                              items: _qualifications,
                              label: 'Qualification',
                              icon: Icons.school,
                              onChanged: (value) {
                                setState(() {
                                  _qualificationController.text = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              controller: _experienceController,
                              label: 'Experience (Years)',
                              icon: Icons.work_history,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter experience';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Please enter valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Subject Selection Section
                      _buildSubjectSelectionSection(),
                      const SizedBox(height: 24),

                      // Class Assignment Section
                      _buildClassAssignmentSection(),
                      const SizedBox(height: 32),

                      // Submit Button
                      _isLoading
                          ? SizedBox(
                              height: 56,
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black87,
                                  ),
                                ),
                              ),
                            )
                          : SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _saveTeacher,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PremiumTheme.neonLime,
                                  foregroundColor: PremiumTheme.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 5,
                                  shadowColor: PremiumTheme.neonLime
                                      .withOpacity(0.4),
                                ),
                                child: Text(
                                  isEditing ? 'Update Teacher' : 'Add Teacher',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
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

// Class Selection Dialog
class _ClassSelectionDialog extends StatefulWidget {
  final SchoolConfig schoolConfig;
  final String selectedPrimaryClass;
  final List<String> selectedSecondaryClasses;
  final Function(String, List<String>) onSelectionChanged;

  const _ClassSelectionDialog({
    required this.schoolConfig,
    required this.selectedPrimaryClass,
    required this.selectedSecondaryClasses,
    required this.onSelectionChanged,
  });

  @override
  __ClassSelectionDialogState createState() => __ClassSelectionDialogState();
}

class __ClassSelectionDialogState extends State<_ClassSelectionDialog> {
  String _primaryClass = '';
  final List<String> _secondaryClasses = [];

  @override
  void initState() {
    super.initState();
    _primaryClass = widget.selectedPrimaryClass;
    _secondaryClasses.addAll(widget.selectedSecondaryClasses);
  }

  List<String> get _availableClasses {
    List<String> allClasses = [];
    for (var schoolClass in widget.schoolConfig.classes) {
      allClasses.addAll(schoolClass.getFullClassNames());
    }
    return allClasses..sort();
  }

  void _saveSelection() {
    if (_primaryClass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a primary class')),
      );
      return;
    }
    widget.onSelectionChanged(_primaryClass, _secondaryClasses);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final availableClasses = _availableClasses;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Class Assignment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Primary Class Selection
            const Text(
              'Primary Class (Class Teacher):',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: PremiumTheme.darkGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButton<String>(
                value: _primaryClass.isEmpty ? null : _primaryClass,
                isExpanded: true,
                dropdownColor: PremiumTheme.darkGrey,
                style: const TextStyle(color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                underline: const SizedBox(),
                hint: Text(
                  'Select Primary Class',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                items: availableClasses.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _primaryClass = value!;
                    // Remove from secondary if selected as primary
                    _secondaryClasses.remove(value);
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            // Secondary Classes Selection
            const Text(
              'Secondary Classes (Additional Subjects):',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select additional classes this teacher will teach',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),

            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableClasses
                      .where((c) => c != _primaryClass)
                      .map((className) {
                        bool isSelected = _secondaryClasses.contains(className);
                        return FilterChip(
                          label: Text(className),
                          selected: isSelected,
                          backgroundColor: Colors.black54,
                          selectedColor: PremiumTheme.neonLime,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _secondaryClasses.add(className);
                              } else {
                                _secondaryClasses.remove(className);
                              }
                            });
                          },
                        );
                      })
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selected: ${_secondaryClasses.length} classes',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.neonLime,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: PremiumTheme.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Subject Selection Dialog
class _SubjectSelectionDialog extends StatefulWidget {
  final List<String> availableSubjects;
  final List<String> selectedSubjects;
  final Function(List<String>) onSelectionChanged;

  const _SubjectSelectionDialog({
    required this.availableSubjects,
    required this.selectedSubjects,
    required this.onSelectionChanged,
  });

  @override
  __SubjectSelectionDialogState createState() =>
      __SubjectSelectionDialogState();
}

class __SubjectSelectionDialogState extends State<_SubjectSelectionDialog> {
  final List<String> _selectedSubjects = [];

  @override
  void initState() {
    super.initState();
    _selectedSubjects.addAll(widget.selectedSubjects);
  }

  void _saveSelection() {
    if (_selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one subject')),
      );
      return;
    }
    widget.onSelectionChanged(_selectedSubjects);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Subjects',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose subjects from school configuration',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.availableSubjects.map((subject) {
                    bool isSelected = _selectedSubjects.contains(subject);
                    return FilterChip(
                      label: Text(subject),
                      selected: isSelected,
                      backgroundColor: Colors.black54,
                      selectedColor: PremiumTheme.neonLime,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSubjects.add(subject);
                          } else {
                            _selectedSubjects.remove(subject);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Selected: ${_selectedSubjects.length} subjects',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.neonLime,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: PremiumTheme.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
