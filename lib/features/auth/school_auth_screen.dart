// school_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/auth_service.dart';
import '../school/school_dashboard.dart';

class SchoolAuthScreen extends StatefulWidget {
  const SchoolAuthScreen({super.key});

  @override
  _SchoolAuthScreenState createState() => _SchoolAuthScreenState();
}

class _SchoolAuthScreenState extends State<SchoolAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _curriculumController = TextEditingController();
  final _locationController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _schoolNameLocationController =
      TextEditingController(); // For location screen
  final _landmarkController = TextEditingController(); // For location screen

  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _selectedType = 'High School';
  final List<String> _schoolTypes = [
    'High School',
    'Primary School',
    'Secondary School',
    'International School',
    'Public School',
    'Private School',
    'Boarding School',
  ];

  // Location variables
  double? _selectedLat;
  double? _selectedLng;
  String? _selectedAddress;
  String? _selectedSchoolNameForLocation;
  String? _selectedLandmark;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _schoolNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _curriculumController.dispose();
    _locationController.dispose();
    _confirmPasswordController.dispose();
    _schoolNameLocationController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check location permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackbar(
          'Location services are disabled. Please enable them.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          _showErrorSnackbar(
            'Location permission is required to select your school location',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackbar(
          'Location permissions are permanently denied. Please enable them in settings.',
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      );

      // Get address from coordinates
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark placemark = placemarks.first;
          String address = [
            placemark.street,
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country,
          ].where((part) => part != null && part.isNotEmpty).join(', ');

          setState(() {
            _selectedLat = position.latitude;
            _selectedLng = position.longitude;
            _selectedAddress = address;
            _locationController.text = address;
          });

          _showSuccessSnackbar('Location found!');
        }
      } catch (e) {
        // If geocoding fails, use coordinates as address
        String address =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        setState(() {
          _selectedLat = position.latitude;
          _selectedLng = position.longitude;
          _selectedAddress = address;
          _locationController.text = address;
        });
        _showSuccessSnackbar('Location found!');
      }
    } catch (e) {
      print('Error getting location: $e');
      _showErrorSnackbar(
        'Error getting location. Please try again or select manually.',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      // Clear form when switching modes
      if (_isLogin) {
        _schoolNameController.clear();
        _addressController.clear();
        _phoneController.clear();
        _curriculumController.clear();
        _locationController.clear();
        _selectedLat = null;
        _selectedLng = null;
        _selectedAddress = null;
        _selectedSchoolNameForLocation = null;
        _selectedLandmark = null;
        _schoolNameLocationController.clear();
        _landmarkController.clear();
        _confirmPasswordController.clear();
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields for registration
    if (!_isLogin) {
      if (_selectedLat == null || _selectedLng == null) {
        _showErrorSnackbar('Please select school location');
        return;
      }
      if (_selectedSchoolNameForLocation == null ||
          _selectedSchoolNameForLocation!.isEmpty) {
        _showErrorSnackbar('Please enter school name in location details');
        return;
      }
    }

    // Validate password match for registration
    if (!_isLogin &&
        _passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackbar('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      AuthService authService = Provider.of<AuthService>(
        context,
        listen: false,
      );

      if (_isLogin) {
        final user = await authService.loginSchool(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (user != null) {
          _showSuccessSnackbar('Login successful!');
          await Future.delayed(Duration(milliseconds: 500));
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SchoolDashboard()),
            (route) => false,
          );
        } else {
          _showErrorSnackbar('Login failed. Please check your credentials.');
        }
      } else {
        // Build full location string with school name and landmark
        String fullLocation = _selectedSchoolNameForLocation!;
        if (_selectedLandmark != null && _selectedLandmark!.isNotEmpty) {
          fullLocation += ' (Near $_selectedLandmark)';
        }
        if (_selectedAddress != null) {
          fullLocation += ' - $_selectedAddress';
        }

        final user = await authService.registerSchool(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          schoolName: _schoolNameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          type: _selectedType!,
          location: fullLocation,
          curriculum: _curriculumController.text.trim(),
          latitude: _selectedLat!,
          longitude: _selectedLng!,
        );

        if (user != null) {
          _showSuccessSnackbar('School registered successfully!');
          await Future.delayed(Duration(milliseconds: 500));
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SchoolDashboard()),
            (route) => false,
          );
        } else {
          _showErrorSnackbar('Registration failed. Please try again.');
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred';
      if (e.code == 'user-not-found') {
        errorMessage = 'No school found with this email';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already registered';
      } else if (e.code == 'invalid-role') {
        errorMessage = 'This account is not a school account';
      }
      _showErrorSnackbar(errorMessage);
    } catch (e) {
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openLocationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLat: _selectedLat,
          initialLng: _selectedLng,
          initialSchoolName: _selectedSchoolNameForLocation,
          initialLandmark: _selectedLandmark,
          initialAddress: _selectedAddress,
        ),
      ),
    );

    if (result != null && result is LocationSelectionResult) {
      setState(() {
        _selectedLat = result.latitude;
        _selectedLng = result.longitude;
        _selectedSchoolNameForLocation = result.schoolName;
        _selectedLandmark = result.landmark;
        _selectedAddress = result.address;

        // Build display text for location field
        String displayText = result.schoolName;
        if (result.landmark != null && result.landmark!.isNotEmpty) {
          displayText += ' (Near ${result.landmark})';
        }
        if (result.address != null) {
          displayText += '\n${result.address}';
        }
        _locationController.text = displayText;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool isRequired = true,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: maxLines,
        enabled: enabled,
        readOnly: onTap != null,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: '$label${isRequired ? ' *' : ''}',
          prefixIcon: Icon(icon, color: Colors.blue),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue),
                SizedBox(width: 10),
                Text(
                  'School Location Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 10),

            // Selected location display
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedSchoolNameForLocation != null &&
                      _selectedSchoolNameForLocation!.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.school, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedSchoolNameForLocation!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (_selectedSchoolNameForLocation != null &&
                      _selectedSchoolNameForLocation!.isNotEmpty)
                    SizedBox(height: 8),

                  if (_selectedLandmark != null &&
                      _selectedLandmark!.isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.place, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Near $_selectedLandmark',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (_selectedLandmark != null &&
                      _selectedLandmark!.isNotEmpty)
                    SizedBox(height: 8),

                  if (_selectedAddress != null && _selectedAddress!.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_pin, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedAddress!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (_selectedLat != null && _selectedLng != null) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.map, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Coordinates: ${_selectedLat!.toStringAsFixed(6)}, ${_selectedLng!.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (_selectedLat == null &&
                      _selectedSchoolNameForLocation == null)
                    Text(
                      'No location details selected',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getCurrentLocation,
                    icon: Icon(Icons.my_location, size: 20),
                    label: Text('Current Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openLocationPicker,
                    icon: Icon(Icons.map, size: 20),
                    label: Text('Select Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'School Login' : 'School Registration'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Container(
              margin: EdgeInsets.only(bottom: 30),
              child: Column(
                children: [
                  Icon(Icons.school, size: 60, color: Colors.blue),
                  SizedBox(height: 10),
                  Text(
                    _isLogin ? 'Welcome Back' : 'Register Your School',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text(
                    _isLogin
                        ? 'Sign in to manage your school'
                        : 'Create your school account',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (!_isLogin) ...[
                    // School Information for registration
                    _buildTextField(
                      controller: _schoolNameController,
                      label: 'School Name',
                      icon: Icons.school,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter school name';
                        }
                        return null;
                      },
                    ),

                    // School Type Dropdown
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'School Type *',
                          prefixIcon: Icon(Icons.category, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _schoolTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select school type';
                          }
                          return null;
                        },
                      ),
                    ),

                    // Location Card
                    _buildLocationCard(),

                    _buildTextField(
                      controller: _addressController,
                      label: 'Full Address',
                      icon: Icons.home,
                      maxLines: 2,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter address';
                        }
                        return null;
                      },
                    ),

                    _buildTextField(
                      controller: _curriculumController,
                      label: 'Curriculum',
                      icon: Icons.book,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter curriculum';
                        }
                        return null;
                      },
                    ),

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
                          return 'Please enter valid phone number';
                        }
                        return null;
                      },
                    ),
                  ],

                  // Common fields for both login and registration
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
                        return 'Please enter valid email';
                      }
                      return null;
                    },
                  ),

                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
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

                  if (!_isLogin)
                    _buildTextField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
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

                  SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(_isLogin ? 'Sign In' : 'Register School'),
                    ),
                  ),

                  SizedBox(height: 15),

                  // Toggle button
                  TextButton(
                    onPressed: _toggleAuthMode,
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign Up"
                          : "Already have an account? Sign In",
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Location Picker Screen with School Name and Landmark
class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialSchoolName;
  final String? initialLandmark;
  final String? initialAddress;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialSchoolName,
    this.initialLandmark,
    this.initialAddress,
  });

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // Mapbox variables
  mapbox.MapboxMap? _mapboxMap;
  mapbox.CircleAnnotationManager? _circleAnnotationManager;
  final String _mapboxAccessToken =
      'pk.eyJ1IjoiYWJkdWxsYS1yYXVmLXBwIiwiYSI6ImNtajVpNXM2dzFibjgzcXI1ZnlubXJmaGIifQ.EOvDjx2LtzwyuPklnz4R1w';

  double? _selectedLat;
  double? _selectedLng;
  String? _selectedAddress;
  final TextEditingController _schoolNameController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    mapbox.MapboxOptions.setAccessToken(_mapboxAccessToken);

    // Default to India center if not provided
    // 20.5937, 78.9629
    _selectedLat = widget.initialLat ?? 20.5937;
    _selectedLng = widget.initialLng ?? 78.9629;

    _schoolNameController.text = widget.initialSchoolName ?? '';
    _landmarkController.text = widget.initialLandmark ?? '';
    _selectedAddress = widget.initialAddress;
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _mapboxMap?.annotations.createCircleAnnotationManager().then((manager) {
      _circleAnnotationManager = manager;
      if (_selectedLat != null && _selectedLng != null) {
        _updateMarker(_selectedLat!, _selectedLng!);
      }
    });
  }

  void _onMapTap(mapbox.MapContentGestureContext context) async {
    // In v2, context usually contains the point directly
    final point = context.point;

    double lat = point.coordinates.lat.toDouble();
    double lng = point.coordinates.lng.toDouble();

    setState(() {
      _selectedLat = lat;
      _selectedLng = lng;
    });
    _updateMarker(lat, lng);
    _getAddressFromLocation(lat, lng);
  }

  Future<void> _updateMarker(double lat, double lng) async {
    if (_circleAnnotationManager == null) return;
    await _circleAnnotationManager!.deleteAll();

    var options = mapbox.CircleAnnotationOptions(
      geometry: mapbox.Point(
        coordinates: mapbox.Position(lng, lat),
      ), // No .toJson()
      circleColor: Colors.red.value,
      circleRadius: 8.0,
      circleStrokeColor: Colors.white.value,
      circleStrokeWidth: 2.0,
    );

    await _circleAnnotationManager!.create(options);
  }

  Future<void> _getAddressFromLocation(double lat, double lng) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        _selectedAddress = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
      } else {
        _selectedAddress =
            '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      }
    } catch (e) {
      print('Error getting address: $e');
      _selectedAddress = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enable location services')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Location permission denied')));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permissions are permanently denied'),
          ),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      double lat = position.latitude;
      double lng = position.longitude;

      setState(() {
        _selectedLat = lat;
        _selectedLng = lng;
      });

      _updateMarker(lat, lng);

      if (_mapboxMap != null) {
        _mapboxMap!.flyTo(
          mapbox.CameraOptions(
            center: mapbox.Point(
              coordinates: mapbox.Position(lng, lat),
            ), // No .toJson()
            zoom: 15.0,
          ),
          mapbox.MapAnimationOptions(duration: 1000),
        );
      }

      await _getAddressFromLocation(lat, lng);
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
    }
  }

  void _saveLocation() {
    if (_selectedLat == null || _selectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a location on the map')),
      );
      return;
    }

    if (_schoolNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter school name')));
      return;
    }

    Navigator.pop(
      context,
      LocationSelectionResult(
        latitude: _selectedLat!,
        longitude: _selectedLng!,
        schoolName: _schoolNameController.text.trim(),
        landmark: _landmarkController.text.trim(),
        address: _selectedAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select School Location'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _useCurrentLocation,
            tooltip: 'Use Current Location',
          ),
        ],
      ),
      body: Column(
        children: [
          // Form Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // School Name Field
                TextFormField(
                  controller: _schoolNameController,
                  decoration: InputDecoration(
                    labelText: 'School Name at this Location *',
                    prefixIcon: Icon(Icons.school, color: Colors.blue),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 1,
                ),
                SizedBox(height: 12),

                // Landmark Field
                TextFormField(
                  controller: _landmarkController,
                  decoration: InputDecoration(
                    labelText: 'Nearest Landmark',
                    prefixIcon: Icon(Icons.place, color: Colors.green),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                    hintText: 'e.g., Near Metro Station, Behind Mall, etc.',
                  ),
                  maxLines: 1,
                ),
                SizedBox(height: 12),

                // Address Display
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Location:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _isLoadingAddress
                                  ? 'Loading address...'
                                  : (_selectedAddress ??
                                        'Tap on map to select location'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_selectedLat != null &&
                                _selectedLng != null) ...[
                              SizedBox(height: 4),
                              Text(
                                'Coordinates: ${_selectedLat!.toStringAsFixed(6)}, ${_selectedLng!.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map Section
          Expanded(
            child: Stack(
              children: [
                mapbox.MapWidget(
                  key: ValueKey("auth_map"),
                  onMapCreated: _onMapCreated,
                  cameraOptions: mapbox.CameraOptions(
                    center: mapbox.Point(
                      coordinates: mapbox.Position(
                        _selectedLng ?? 78.9629,
                        _selectedLat ?? 20.5937,
                      ),
                    ), // No .toJson()
                    zoom: 15.0,
                  ),
                  onTapListener: _onMapTap,
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: _saveLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Save Location Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Result class for location selection
class LocationSelectionResult {
  final double latitude;
  final double longitude;
  final String schoolName;
  final String? landmark;
  final String? address;

  LocationSelectionResult({
    required this.latitude,
    required this.longitude,
    required this.schoolName,
    this.landmark,
    this.address,
  });
}
