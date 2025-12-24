import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/driver_model.dart';
import '../../../models/user_model.dart';
import '../../../models/vehicle_model.dart';
import 'package:school_bus2/core/theme/premium_theme.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key, this.driver});

  final Driver? driver;

  @override
  _AddDriverScreenState createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  File? _selectedImage;
  bool _isLoading = false;
  UserModel? _currentUser;
  String? _selectedVehicleType;
  String? _selectedVehicleId;
  String? _selectedVehicleNumber;
  List<Vehicle> _availableVehicles = [];

  final ImagePicker _picker = ImagePicker();
  final List<String> _vehicleTypes = ['Auto', 'Van', 'Mini Bus', 'Bus'];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool get _isEditing => widget.driver != null;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    _loadCurrentUser();
    if (_isEditing) {
      _populateDriverData();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _populateDriverData() {
    final driver = widget.driver!;
    _nameController.text = driver.name;
    _emailController.text = driver.email;
    _phoneController.text = driver.phone;
    _addressController.text = driver.address;
    _selectedVehicleType = driver.vehicleType;
    _selectedVehicleNumber = driver.vehicleNumber;
    _selectedVehicleId = driver.vehicleId;

    if (_selectedVehicleType != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAvailableVehicles(_selectedVehicleType!);
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    AuthService authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user = await authService.getCurrentUserData();
    setState(() {
      _currentUser = user;
    });
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
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _loadAvailableVehicles(String vehicleType) async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();
    List<Vehicle> vehicles = await dbService.getAvailableVehicles(
      _currentUser!.uid,
      vehicleType,
    );

    setState(() {
      _availableVehicles = vehicles;
      if (!_isEditing || _selectedVehicleType != vehicleType) {
        _selectedVehicleId = null;
        _selectedVehicleNumber = null;
      }
    });
  }

  String _generateDriverId() {
    if (_currentUser?.name == null) {
      return 'DRV${DateTime.now().millisecondsSinceEpoch}';
    }

    String schoolCode = _currentUser!.name
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .join();

    String timestamp = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(7);

    return '$schoolCode$timestamp';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.white : Colors.black,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: isError ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[700] : PremiumTheme.neonLime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleType == null) {
      _showSnackBar('Please select vehicle type', isError: true);
      return;
    }
    if (_selectedVehicleId == null) {
      _showSnackBar('Please select a vehicle', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      DatabaseService dbService = DatabaseService();
      bool success;

      if (_isEditing) {
        Driver updatedDriver = Driver(
          driverId: widget.driver!.driverId,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          vehicleType: _selectedVehicleType!,
          vehicleId: _selectedVehicleId!,
          vehicleNumber: _selectedVehicleNumber ?? '',
          schoolId: _currentUser!.uid,
          createdAt: widget.driver!.createdAt,
          photoUrl: widget.driver!.photoUrl,
        );

        success = await dbService.updateDriver(updatedDriver, _selectedImage);
      } else {
        String driverId = _generateDriverId();
        String? email = _emailController.text.trim();

        Driver newDriver = Driver(
          driverId: driverId,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          vehicleType: _selectedVehicleType!,
          vehicleId: _selectedVehicleId!,
          vehicleNumber: _selectedVehicleNumber ?? '',
          schoolId: _currentUser!.uid,
          createdAt: DateTime.now(),
        );

        success = await dbService.addDriver(newDriver, _selectedImage);

        if (success) {
          _showCredentialsDialog(driverId, email);
        }
      }

      if (success) {
        _showSnackBar(
          'Driver ${_isEditing ? 'updated' : 'added'} successfully!',
        );

        if (!_isEditing) {
          _formKey.currentState!.reset();
          setState(() {
            _selectedImage = null;
            _selectedVehicleType = null;
            _selectedVehicleId = null;
            _selectedVehicleNumber = null;
            _availableVehicles.clear();
            _nameController.clear();
            _emailController.clear();
            _phoneController.clear();
            _addressController.clear();
          });
        } else {
          Navigator.pop(context, true);
        }
      } else {
        _showSnackBar(
          'Failed to ${_isEditing ? 'update' : 'add'} driver',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCredentialsDialog(String driverId, String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: PremiumTheme.darkGrey,
        surfaceTintColor: PremiumTheme.darkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PremiumTheme.neonLime.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: PremiumTheme.neonLime,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Driver Added!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PremiumTheme.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Login Credentials',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              _buildCredentialRow('Email:', email),
              const SizedBox(height: 8),
              _buildCredentialRow('Password:', driverId),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: PremiumTheme.neonLime.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: PremiumTheme.neonLime,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Please share these credentials with the driver.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Got it',
              style: TextStyle(fontSize: 16, color: PremiumTheme.neonLime),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        SelectableText(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PremiumTheme.darkGrey,
                border: Border.all(color: PremiumTheme.neonLime, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: PremiumTheme.neonLime.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: PremiumTheme.darkGrey,
                  shape: BoxShape.circle,
                  border: Border.all(color: PremiumTheme.darkGrey, width: 4),
                ),
                child: ClipOval(
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : _isEditing && widget.driver!.photoUrl != null
                      ? Image.network(
                          widget.driver!.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        )
                      : _buildPlaceholder(),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PremiumTheme.neonLime,
                  shape: BoxShape.circle,
                  border: Border.all(color: PremiumTheme.darkGrey, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _isEditing && widget.driver!.photoUrl != null
              ? 'Tap to change photo'
              : 'Add driver photo',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: PremiumTheme.darkGrey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            size: 50,
            color: PremiumTheme.neonLime.withOpacity(0.3),
          ),
          const SizedBox(height: 4),
          Text(
            'No Photo',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: PremiumTheme.neonLime),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PremiumTheme.neonLime, width: 2),
        ),
        filled: true,
        fillColor: PremiumTheme.darkGrey,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildVehicleSelection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PremiumTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.directions_car,
                color: PremiumTheme.neonLime,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Vehicle Assignment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vehicle Type Selection
          DropdownButtonFormField<String>(
            initialValue: _selectedVehicleType,
            dropdownColor: PremiumTheme.darkGrey,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Vehicle Type',
              labelStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: PremiumTheme.neonLime,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: PremiumTheme.darkGrey,
              prefixIcon: Icon(Icons.category, color: PremiumTheme.neonLime),
            ),
            items: _vehicleTypes.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedVehicleType = value;
                _selectedVehicleId = null;
                _selectedVehicleNumber = null;
              });
              if (value != null) {
                _loadAvailableVehicles(value);
              }
            },
            validator: (value) {
              if (value == null) {
                return 'Please select vehicle type';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Vehicle Selection
          if (_selectedVehicleType != null)
            DropdownButtonFormField<String>(
              initialValue: _selectedVehicleId,
              dropdownColor: PremiumTheme.darkGrey,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Select Vehicle',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: PremiumTheme.neonLime,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: PremiumTheme.darkGrey,
                prefixIcon: Icon(
                  Icons.airport_shuttle,
                  color: PremiumTheme.neonLime,
                ),
              ),
              isExpanded: true,
              items: _availableVehicles.map((vehicle) {
                return DropdownMenuItem(
                  value: vehicle.vehicleId,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        vehicle.vehicleName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      // const SizedBox(height: 2),
                      // Text(
                      //   '${vehicle.vehicleNumber} • ${vehicle.vehicleType} • ${vehicle.capacity} seats',
                      //   style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      // ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedVehicleId = value;
                  if (value != null) {
                    var selectedVehicle = _availableVehicles.firstWhere(
                      (v) => v.vehicleId == value,
                    );
                    _selectedVehicleNumber = selectedVehicle.vehicleNumber;
                  }
                });
              },
              validator: (value) {
                if (value == null && _selectedVehicleType != null) {
                  return 'Please select a vehicle';
                }
                return null;
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.black,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Driver' : 'Add New Driver',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: PremiumTheme.black,
        foregroundColor: Colors.white,
      ),
      body: _currentUser == null
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  PremiumTheme.neonLime,
                ),
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Photo Picker
                    _buildImagePicker(),
                    const SizedBox(height: 30),

                    // Personal Information Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: PremiumTheme.darkGrey,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: PremiumTheme.neonLime,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Personal Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Name Field
                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter driver name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email Field
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Address',
                            icon: Icons.email,
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
                          const SizedBox(height: 16),

                          // Phone Field
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter phone number';
                              }
                              if (value.length < 10) {
                                return 'Please enter a valid phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Address Field
                          _buildTextField(
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Vehicle Selection Section
                    _buildVehicleSelection(),
                    const SizedBox(height: 30),

                    // Submit Button
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                PremiumTheme.neonLime,
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _saveDriver,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PremiumTheme.neonLime,
                                foregroundColor: PremiumTheme.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                shadowColor: PremiumTheme.neonLime.withOpacity(
                                  0.4,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isEditing
                                        ? Icons.update
                                        : Icons.add_circle_outline,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isEditing ? 'Update Driver' : 'Add Driver',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
