// school_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:school_bus2/models/school_model.dart';
import 'package:school_bus2/models/user_model.dart';
import 'package:school_bus2/services/auth_service.dart';
import 'package:school_bus2/services/database_service.dart';

class SchoolProfileScreen extends StatefulWidget {
  const SchoolProfileScreen({super.key});

  @override
  _SchoolProfileScreenState createState() => _SchoolProfileScreenState();
}

class _SchoolProfileScreenState extends State<SchoolProfileScreen> {
  School? _school;
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _showDetails = false;
  bool _isGettingLocation = false;
  bool _showMapPicker = false;
  File? _logoImage;
  final ImagePicker _picker = ImagePicker();

  // Map variables
  mapbox.MapboxMap? _mapboxMap;
  mapbox.CircleAnnotationManager? _circleAnnotationManager;
  // LatLng? _selectedLocation; // Removed in favor of lat/lng doubles
  // We can keep using LatLng from mapbox or manually define if needed. Mapbox v1 uses its own Position or Point.
  // actually mapbox_maps_flutter uses `Position` (lng, lat) or `Point`.
  // But wait, geocoding might behave differently.
  // Let's use `Position` from mapbox directly or convert.
  // The provided code uses google_maps_flutter's LatLng. Mapbox has a Position class but in v2/v1 structure it might be different.
  // Checking typical usage: `Point.fromJson({'coordinates': [lng, lat]})` or similar.
  // Actually, let's keep a simple customized LatLng or just use the one from Geolocator or define one.
  // Google Maps LatLng is (lat, lng). Mapbox Position is usually (lng, lat).
  // I will use a local helper for selectedLocation to store (lat, lng) to avoid confusion.

  // Let's define:
  double? _selectedLat;
  double? _selectedLng;
  // We don't need CameraPosition like Google Maps

  // Access Token (Placeholder)
  final String _mapboxAccessToken =
      'pk.eyJ1IjoiYWJkdWxsYS1yYXVmLXBwIiwiYSI6ImNtajVpNXM2dzFibjgzcXI1ZnlubXJmaGIifQ.EOvDjx2LtzwyuPklnz4R1w';

  // Statistics
  int _studentsCount = 0;
  int _teachersCount = 0;
  int _vehiclesCount = 0; // Changed from _busesCount
  int _classesCount = 0;

  // Form controllers
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _locationController = TextEditingController();
  final _curriculumController = TextEditingController();
  final _establishmentYearController = TextEditingController();
  final _totalStudentsController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set Access Token
    mapbox.MapboxOptions.setAccessToken(_mapboxAccessToken);
    _loadSchoolData();
  }

  Future<void> _loadSchoolData() async {
    print('🔄 Loading school profile data...');
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = DatabaseService();

      // Get current user
      UserModel? user = await authService.getCurrentUserData();
      print('📋 Current user: ${user?.name} (${user?.role})');
      print('📋 User school ID: ${user?.schoolId}');

      if (user != null) {
        setState(() {
          _currentUser = user;
        });

        // For school admin, schoolId is usually their own user ID
        String schoolId = user.schoolId ?? user.uid;
        print('🔍 Looking for school with ID: $schoolId');

        School? school = await dbService.getSchoolById(schoolId);

        if (school != null) {
          print('✅ School found: ${school.name}');

          // Fetch statistics
          final studentsCount = await dbService.getStudentsCount(schoolId);
          final teachersCount = await dbService.getTeachersCount(schoolId);
          // Changed to getVehiclesCount
          final vehiclesCount = await dbService.getVehiclesCount(schoolId);
          final classesCount = await dbService.getClassesCount(schoolId);

          setState(() {
            _school = school;
            _studentsCount = studentsCount;
            _teachersCount = teachersCount;
            _vehiclesCount = vehiclesCount;
            _classesCount = classesCount;

            _populateFormFields(school);

            // Initialize map location if available
            if (school.latitude != null && school.longitude != null) {
              _selectedLat = school.latitude;
              _selectedLng = school.longitude;

              // If map is already initialized (e.g. reload), update marker
              if (_circleAnnotationManager != null) {
                _updateMarker(_selectedLat!, _selectedLng!);
              }
            }
          });
        } else {
          print('❌ No school found. Showing empty state.');
        }
      } else {
        print('❌ No user logged in');
      }
    } catch (e) {
      print('❌ Error loading school data: $e');
      _showErrorSnackbar('Error loading school data');
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('✅ Finished loading');
    }
  }

  void _populateFormFields(School school) {
    _nameController.text = school.name;
    _typeController.text = school.type;
    _emailController.text = school.email;
    _phoneController.text = school.phone;
    _addressController.text = school.address;
    _locationController.text = school.location;
    _curriculumController.text = school.curriculum;
    _establishmentYearController.text =
        school.establishmentYear?.toString() ?? '';
    _totalStudentsController.text = school.totalStudents?.toString() ?? '';
    _latitudeController.text = school.latitude?.toString() ?? '';
    _longitudeController.text = school.longitude?.toString() ?? '';
  }

  Future<void> _pickLogoImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logoImage = File(pickedFile.path);
      });
      _showInfoSnackbar('Logo selected. Save profile to update.');
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackbar('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackbar('Location permission permanently denied');
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String address = [
          if (placemark.street != null) placemark.street,
          if (placemark.subLocality != null) placemark.subLocality,
          if (placemark.locality != null) placemark.locality,
          if (placemark.postalCode != null) placemark.postalCode,
          if (placemark.country != null) placemark.country,
        ].where((part) => part != null && part.isNotEmpty).join(', ');

        setState(() {
          _selectedLat = position.latitude;
          _selectedLng = position.longitude;

          _latitudeController.text = position.latitude.toString();
          _longitudeController.text = position.longitude.toString();

          // Update address and location fields
          if (_addressController.text.isEmpty) {
            _addressController.text = address;
          }
          if (_locationController.text.isEmpty && placemark.locality != null) {
            _locationController.text = placemark.locality!;
          }

          // Update map marker
          _updateMarker(_selectedLat!, _selectedLng!);

          // Move camera to current location
          if (_mapboxMap != null) {
            _mapboxMap!.flyTo(
              mapbox.CameraOptions(
                center: mapbox.Point(
                  coordinates: mapbox.Position(_selectedLng!, _selectedLat!),
                ), // No .toJson()
                zoom: 15.0,
                // Note: animation options can be added but defaults are fine
              ),
              mapbox.MapAnimationOptions(duration: 1000), // 1 second animation
            );
          }
        });

        _showSuccessSnackbar('Location obtained successfully!');
      }
    } catch (e) {
      print('Error getting location: $e');
      _showErrorSnackbar('Failed to get current location: $e');
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  // Pick location from map
  Widget _buildMapPicker() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select School Location',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Use current location',
          ),
        ],
      ),
      body: Stack(
        children: [
          mapbox.MapWidget(
            key: ValueKey("mapWidget"),
            // resourceOptions removed as it seems invalid for this version
            // Access token should be configured in AndroidManifest/Info.plist
            // or we set it globally using MapboxOptions.setAccessToken if available.
            // For now, assuming mapbox_maps_flutter v1 reads from native config
            // or we use just cameraOptions.
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(
                coordinates: mapbox.Position(
                  _selectedLng ?? 0.0,
                  _selectedLat ?? 0.0,
                ),
              ), // No .toJson()
              zoom: 14.0,
            ),
            onMapCreated: _onMapCreated,
            onTapListener: _onMapTap,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Location',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  if (_selectedLat != null)
                    Text(
                      'Lat: ${_selectedLat!.toStringAsFixed(6)}\nLng: ${_selectedLng!.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _showMapPicker = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedLat != null
                              ? () {
                                  setState(() {
                                    _showMapPicker = false;
                                  });
                                  _showSuccessSnackbar('Location selected');
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('Confirm Location'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    if (_mapboxMap == null) return;

    final point = context.point;

    double lat = point.coordinates.lat.toDouble();
    double lng = point.coordinates.lng.toDouble();

    setState(() {
      _selectedLat = lat;
      _selectedLng = lng;

      _latitudeController.text = _selectedLat.toString();
      _longitudeController.text = _selectedLng.toString();
    });
    _updateMarker(_selectedLat!, _selectedLng!);
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

  Future<void> _saveProfile() async {
    if (_school == null) return;

    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackbar('School name is required');
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showErrorSnackbar('Email is required');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      _showErrorSnackbar('Phone is required');
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      _showErrorSnackbar('Address is required');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dbService = DatabaseService();

      // Get latitude and longitude from controllers
      double? latitude = _latitudeController.text.trim().isNotEmpty
          ? double.tryParse(_latitudeController.text.trim())
          : null;
      double? longitude = _longitudeController.text.trim().isNotEmpty
          ? double.tryParse(_longitudeController.text.trim())
          : null;

      // Create updated school object
      School updatedSchool = _school!.copyWith(
        name: _nameController.text.trim(),
        type: _typeController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        location: _locationController.text.trim(),
        curriculum: _curriculumController.text.trim(),
        establishmentYear: _establishmentYearController.text.trim().isNotEmpty
            ? int.tryParse(_establishmentYearController.text.trim())
            : null,
        totalStudents: _totalStudentsController.text.trim().isNotEmpty
            ? int.tryParse(_totalStudentsController.text.trim())
            : null,
        latitude: latitude,
        longitude: longitude,
        updatedAt: DateTime.now(),
      );

      // Upload logo image if selected
      String? logoUrl = _school!.logoUrl;
      if (_logoImage != null) {
        logoUrl = await dbService.uploadSchoolLogo(
          _logoImage!,
          updatedSchool.schoolId,
        );
        if (logoUrl != null) {
          updatedSchool = updatedSchool.copyWith(logoUrl: logoUrl);
        }
      }

      // Update school in database
      bool success = await dbService.updateSchool(updatedSchool);

      if (success) {
        setState(() {
          _school = updatedSchool;
          _isEditing = false;
          _logoImage = null;
        });
        _showSuccessSnackbar('Profile updated successfully!');
      } else {
        _showErrorSnackbar('Failed to update profile');
      }
    } catch (e) {
      print('Error saving profile: $e');
      _showErrorSnackbar('Error saving profile: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showErrorSnackbar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  void _showSuccessSnackbar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  void _showInfoSnackbar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    });
  }

  void _enterEditMode() {
    if (_school != null) {
      _populateFormFields(_school!);
      setState(() {
        _isEditing = true;
        _showDetails = true;
      });
    }
  }

  void _cancelEditMode() {
    setState(() {
      _isEditing = false;
      _logoImage = null;
      if (_school != null) {
        _populateFormFields(_school!);
      }
    });
  }

  Widget _buildLocationPickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Coordinates',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latitudeController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                readOnly: true,
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Latitude',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  suffixIcon: Icon(Icons.location_on, size: 20),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _longitudeController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                readOnly: true,
                style: TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Longitude',
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  suffixIcon: Icon(Icons.location_on, size: 20),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: _isGettingLocation
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(Icons.my_location, size: 20),
                label: Text(
                  _isGettingLocation
                      ? 'Getting Location...'
                      : 'Use Current Location',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showMapPicker = true;
                  });
                },
                icon: Icon(Icons.map, size: 20),
                label: Text('Pick from Map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.black87, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  value.isNotEmpty ? value : 'Not provided',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard() {
    final schoolName = _school?.name ?? 'School';
    final schoolType = _school?.type ?? 'Not specified';
    final photoUrl = _school?.logoUrl;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showDetails = true;
          _isEditing = false;
        });
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black87, Colors.black54],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              left: -50,
              bottom: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back! 👋',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            schoolName,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.8,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Spacer(),
                      if (photoUrl != null)
                        CircleAvatar(
                          radius: 44,
                          backgroundImage: NetworkImage(photoUrl),
                          backgroundColor: Colors.grey[300],
                        )
                      else
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[700],
                          ),
                          child: Icon(
                            Icons.school,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Container(height: 1.5, color: Colors.white.withOpacity(0.1)),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SCHOOL TYPE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            schoolType,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ESTABLISHED',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _school?.establishmentYear?.toString() ?? 'N/A',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(),
                      Row(
                        children: [
                          Text(
                            'View all details',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[300],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.grey[300],
                            size: 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String title,
    String subtitle, {
    Color? bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor ?? Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeView() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickCard(),
            SizedBox(height: 40),

            // Quick Access
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildActionCard(
                  Icons.edit,
                  'Edit Profile',
                  'Update school info',
                  onTap: _enterEditMode,
                ),
                _buildActionCard(
                  Icons.photo_camera,
                  'Change Logo',
                  'Upload new logo',
                  onTap: _pickLogoImage,
                ),
                _buildActionCard(
                  Icons.refresh,
                  'Reload Data',
                  'Refresh information',
                  onTap: _loadSchoolData,
                ),
                _buildActionCard(
                  Icons.download,
                  'Export Data',
                  'Download records',
                  onTap: () {
                    _showInfoSnackbar('Export feature coming soon!');
                  },
                ),
              ],
            ),

            SizedBox(height: 32),

            // School Stats
            Text(
              'School Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  Icons.people,
                  'Total Students',
                  _studentsCount.toString(),
                  Colors.black87,
                ),
                _buildStatCard(
                  Icons.class_,
                  'Classes',
                  _classesCount.toString(),
                  Colors.black54,
                ),
                _buildStatCard(
                  Icons.person,
                  'Teachers',
                  _teachersCount.toString(),
                  Colors.black87,
                ),
                _buildStatCard(
                  Icons.directions_car, // Changed icon to car/vehicle
                  'Vehicles', // Changed label
                  _vehiclesCount.toString(),
                  Colors.black54,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSection(),
            SizedBox(height: 20),

            // Action buttons in detail view
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _enterEditMode,
                    icon: Icon(Icons.edit, size: 20),
                    label: Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showDetails = false;
                      });
                    },
                    icon: Icon(Icons.arrow_back, size: 20),
                    label: Text('Back to Dashboard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            _buildSection('School Information', [
              _buildInfoCard(
                'School Name',
                _school?.name ?? 'N/A',
                Icons.school,
              ),
              _buildInfoCard(
                'School Type',
                _school?.type ?? 'N/A',
                Icons.category,
              ),
              _buildInfoCard('Email', _school?.email ?? 'N/A', Icons.email),
              _buildInfoCard('Phone', _school?.phone ?? 'N/A', Icons.phone),
              _buildInfoCard(
                'Establishment Year',
                _school?.establishmentYear?.toString() ?? 'N/A',
                Icons.calendar_today,
              ),
              _buildInfoCard(
                'Curriculum',
                _school?.curriculum ?? 'N/A',
                Icons.book,
              ),
            ]),
            _buildSection('Location Details', [
              _buildInfoCard(
                'Address',
                _school?.address ?? 'N/A',
                Icons.location_on,
              ),
              _buildInfoCard('Location', _school?.location ?? 'N/A', Icons.map),
              if (_school?.latitude != null && _school?.longitude != null)
                _buildInfoCard(
                  'Coordinates',
                  '${_school!.latitude!.toStringAsFixed(4)}, ${_school!.longitude!.toStringAsFixed(4)}',
                  Icons.gps_fixed,
                ),
            ]),
            _buildSection('System Information', [
              _buildInfoCard(
                'Total Students',
                _studentsCount.toString(),
                Icons.people,
              ),
              _buildInfoCard(
                'Created On',
                DateFormat('MMM d, yyyy').format(_school!.createdAt),
                Icons.date_range,
              ),
              if (_school?.updatedAt != null)
                _buildInfoCard(
                  'Last Updated',
                  DateFormat('MMM d, yyyy').format(_school!.updatedAt!),
                  Icons.update,
                ),
            ]),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    final schoolName = _school?.name ?? 'School';
    final photoUrl = _school?.logoUrl;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        children: [
          if (photoUrl != null)
            CircleAvatar(
              radius: 52,
              backgroundImage: NetworkImage(photoUrl),
              backgroundColor: Colors.grey[300],
            )
          else
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black87,
              ),
              child: Icon(Icons.school, color: Colors.white, size: 56),
            ),
          SizedBox(height: 20),
          Text(
            schoolName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            _school?.type ?? 'Not specified',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Est. ${_school?.establishmentYear ?? 'N/A'}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            children: isRequired
                ? [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ]
                : [],
          ),
        ),
        SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          style: TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.black87, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEditView() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Section
          Center(
            child: GestureDetector(
              onTap: _pickLogoImage,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                    ),
                    child: ClipOval(
                      child: _logoImage != null
                          ? Image.file(_logoImage!, fit: BoxFit.cover)
                          : _school!.logoUrl != null
                          ? Image.network(
                              _school!.logoUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.school,
                                  size: 50,
                                  color: Colors.grey,
                                );
                              },
                            )
                          : Icon(Icons.school, size: 50, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          Text(
            'Edit School Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20),

          _buildEditableField(
            label: 'School Name',
            controller: _nameController,
            isRequired: true,
          ),
          _buildEditableField(
            label: 'School Type',
            controller: _typeController,
          ),
          _buildEditableField(
            label: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            isRequired: true,
          ),
          _buildEditableField(
            label: 'Phone',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            isRequired: true,
          ),
          _buildEditableField(
            label: 'Address',
            controller: _addressController,
            maxLines: 2,
            isRequired: true,
          ),
          _buildEditableField(
            label: 'Location (City/Town)',
            controller: _locationController,
          ),
          _buildEditableField(
            label: 'Curriculum',
            controller: _curriculumController,
          ),

          // Location Picker Section
          _buildLocationPickerField(),

          Row(
            children: [
              Expanded(
                child: _buildEditableField(
                  label: 'Establishment Year',
                  controller: _establishmentYearController,
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildEditableField(
                  label: 'Total Students',
                  controller: _totalStudentsController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          SizedBox(height: 30),

          SizedBox(height: 30),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _cancelEditMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('Cancel'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text('Save Changes'),
                ),
              ),
            ],
          ),

          SizedBox(height: 40),

          Divider(height: 1),
          SizedBox(height: 30),

          // Danger Zone
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red),
                    SizedBox(width: 10),
                    Text(
                      'Danger Zone',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Deleting the school will permanently remove all related data including teachers, drivers, students, vehicles, and records. This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red[800],
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _deleteSchool,
                    icon: Icon(Icons.delete_forever),
                    label: Text('Delete School Permanently'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _deleteSchool() async {
    // Show confirmation dialog
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete School?'),
            content: Text(
              'Are you sure you want to delete this school? ALL data will be lost permanently. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('Delete Immediately'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    // Show double confirmation
    bool doubleConfirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Final Confirmation'),
            content: Text(
              'Please confirm again. This will wipe everything related to ${_school?.name}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('I Understand, DELETE'),
              ),
            ],
          ),
        ) ??
        false;

    if (!doubleConfirm) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dbService = DatabaseService();
      final authService = Provider.of<AuthService>(context, listen: false);

      if (_school != null) {
        // 1. Delete all school data from Firestore
        bool success = await dbService.deleteSchool(_school!.schoolId);

        if (success) {
          // 2. Delete the Admin Auth Account
          await authService.deleteCurrentAccount();

          // 3. Navigate to Auth Wrapper / Role Selection
          // Use pushNamedAndRemoveUntil to clear stack
          if (mounted) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/', (route) => false);
          }
        } else {
          _showErrorSnackbar('Failed to delete school data. Please try again.');
        }
      }
    } catch (e) {
      print('Error deleting school: $e');
      _showErrorSnackbar('An error occurred during deletion: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showMapPicker) {
      return _buildMapPicker();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Edit Profile'
              : (_showDetails ? 'School Profile' : 'Dashboard'),
          style: TextStyle(
            color: Colors.black87,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelEditMode,
              tooltip: 'Cancel Edit',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() {
                      _isLoading = true;
                    });
                    await _loadSchoolData();
                  },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Loading school profile...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _school == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.black38),
                  SizedBox(height: 16),
                  Text(
                    'School profile not found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Contact administrator for assistance',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _loadSchoolData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : _isEditing
          ? _buildEditView()
          : _showDetails
          ? _buildDetailView()
          : _buildHomeView(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _locationController.dispose();
    _curriculumController.dispose();
    _establishmentYearController.dispose();
    _totalStudentsController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }
}
