// add_vehicle_screen.dart - UPDATED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/user_model.dart';
import '../../../models/student_model.dart';
import 'vehicle_students_screen.dart';
import '../../../models/school_model.dart';
import 'package:geolocator/geolocator.dart';
import '../../common/location_picker_screen.dart';
import 'package:school_bus2/core/theme/premium_theme.dart';

class AddVehicleScreen extends StatefulWidget {
  final Vehicle? vehicleToEdit;

  const AddVehicleScreen({super.key, this.vehicleToEdit});

  @override
  _AddVehicleScreenState createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _vehicleNameController = TextEditingController();
  final _modelNumberController = TextEditingController();
  final _capacityController = TextEditingController();
  final _stopController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  UserModel? _currentUser;
  String? _selectedVehicleType;
  final List<String> _stops = [];
  List<Student> _availableStudents = [];
  List<VehicleStudent> _assignedStudents = [];
  List<Student> _nearbyStudents = [];
  School? _school;
  late AnimationController _animationController;

  final List<Map<String, dynamic>> _vehicleTypes = [
    {'name': 'Auto', 'icon': Icons.airport_shuttle},
    {'name': 'Van', 'icon': Icons.directions_car},
    {'name': 'Mini Bus', 'icon': Icons.directions_bus},
    {'name': 'Bus', 'icon': Icons.directions_bus_filled},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    _isEditing = widget.vehicleToEdit != null;
    _loadCurrentUser();

    if (_isEditing) {
      _populateFormWithVehicleData();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _vehicleNumberController.dispose();
    _vehicleNameController.dispose();
    _modelNumberController.dispose();
    _capacityController.dispose();
    _stopController.dispose();
    super.dispose();
  }

  void _populateFormWithVehicleData() {
    final vehicle = widget.vehicleToEdit!;
    _vehicleNumberController.text = vehicle.vehicleNumber;
    _vehicleNameController.text = vehicle.vehicleName;
    _modelNumberController.text = vehicle.modelNumber;
    _capacityController.text = vehicle.capacity.toString();
    _selectedVehicleType = vehicle.vehicleType;
    _stops.addAll(vehicle.stops);
    _assignedStudents = vehicle.assignedStudents;
  }

  Future<void> _loadCurrentUser() async {
    AuthService authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user = await authService.getCurrentUserData();
    setState(() {
      _currentUser = user;
    });

    if (_currentUser != null) {
      await _loadAvailableStudents();
      await _loadSchoolData();
    }
  }

  Future<void> _loadSchoolData() async {
    if (_currentUser == null) return;
    try {
      DatabaseService dbService = DatabaseService();
      School? school = await dbService.getSchoolById(_currentUser!.uid);
      if (school != null) {
        setState(() {
          _school = school;
        });
      }
    } catch (e) {
      print('Error loading school data: $e');
    }
  }

  Future<void> _loadAvailableStudents() async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();
    List<Student> students = await dbService.getStudentsBySchoolId(
      _currentUser!.uid,
    );

    setState(() {
      _availableStudents = students.where((student) {
        // Filter out students already assigned to this vehicle
        if (_isEditing) {
          return !_assignedStudents.any(
            (assigned) => assigned.studentId == student.studentId,
          );
        }
        return true;
      }).toList();
    });
  }

  String _generateVehicleId() {
    return 'VHL${DateTime.now().millisecondsSinceEpoch}';
  }

  void _addStop() {
    if (_stopController.text.trim().isNotEmpty) {
      setState(() {
        _stops.add(_stopController.text.trim());
        _stopController.clear();
      });
    }
  }

  void _removeStop(int index) {
    setState(() {
      _stops.removeAt(index);
    });
  }

  Future<void> _pickStopLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          title: 'Pick Stop Location',
          centerLat: _school?.latitude,
          centerLng: _school?.longitude,
          radiusInKm: 5.0,
        ),
      ),
    );

    if (result != null && result is LocationResult) {
      if (result.address != null) {
        String formattedAddress = result.address!;
        if (result.placeName != null && result.placeName!.isNotEmpty) {
          formattedAddress = '${result.placeName}|${result.address}';
        }
        setState(() {
          _stops.add(formattedAddress);
        });
        _findNearbyStudents(result.latitude, result.longitude);
      }
    }
  }

  Future<void> _findNearbyStudents(double lat, double lng) async {
    List<Student> nearby = [];
    for (var student in _availableStudents) {
      if (student.latitude != null && student.longitude != null) {
        double distanceInMeters = Geolocator.distanceBetween(
          lat,
          lng,
          student.latitude!,
          student.longitude!,
        );
        if (distanceInMeters <= 200) {
          nearby.add(student);
        }
      }
    }

    setState(() {
      _nearbyStudents = nearby;
    });

    if (nearby.isNotEmpty) {
      _showSnackBar(
        'Found ${nearby.length} students within 200m',
        Icons.check_circle,
        Colors.green,
      );
    } else {
      _showSnackBar('No students found within 200m', Icons.info, Colors.orange);
    }
  }

  Future<void> _assignStudent(Student student) async {
    if (_stops.isEmpty) {
      _showSnackBar(
        'Please add stops first before assigning students',
        Icons.warning,
        Colors.orange,
      );
      return;
    }

    // Show dialog to select pickup and dropoff stops
    String? pickupStop = await _showStopSelectionDialog('Select Pickup Stop');
    if (pickupStop == null) return;

    String? dropoffStop = await _showStopSelectionDialog('Select Dropoff Stop');
    if (dropoffStop == null) return;

    VehicleStudent vehicleStudent = VehicleStudent(
      studentId: student.studentId,
      studentName: '${student.firstName} ${student.lastName}',
      admissionNumber: student.admissionNumber,
      className: student.className,
      pickupStop: pickupStop,
      dropoffStop: dropoffStop,
      assignedAt: DateTime.now(),
    );

    setState(() {
      _assignedStudents.add(vehicleStudent);
      _availableStudents.removeWhere((s) => s.studentId == student.studentId);
    });

    _showSnackBar(
      '${student.firstName} assigned to vehicle',
      Icons.check_circle,
      Colors.green,
    );
  }

  Future<String?> _showStopSelectionDialog(String title) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _stops.length,
            itemBuilder: (context, index) {
              String stopRaw = _stops[index];
              String stopName = stopRaw;
              String? stopAddress;

              if (stopRaw.contains('|')) {
                final parts = stopRaw.split('|');
                stopName = parts[0];
                stopAddress = parts.length > 1 ? parts[1] : null;
              }

              return ListTile(
                title: Text(
                  stopName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: stopAddress != null ? Text(stopAddress) : null,
                leading: const Icon(Icons.place, color: Colors.purple),
                onTap: () => Navigator.pop(
                  context,
                  _stops[index],
                ), // Return raw string for internal consistency
              );
            },
          ),
        ),
      ),
    );
  }

  // In the _removeAssignedStudent method, update the Student constructor:
  void _removeAssignedStudent(VehicleStudent student) {
    setState(() {
      _assignedStudents.removeWhere((s) => s.studentId == student.studentId);
      // Add back to available students if we can find the original student
      var originalStudent = _availableStudents.firstWhere(
        (s) => s.studentId == student.studentId,
        orElse: () => Student(
          studentId: student.studentId,
          admissionNumber: student.admissionNumber,
          firstName: student.studentName.split(' ').first,
          lastName: student.studentName.split(' ').last,
          email: '', // Default email
          primaryPhone: '', // Default phone
          secondaryPhone: '', // Default secondary phone
          fatherName: '', // Default father name
          motherName: '', // Default mother name
          guardianName: '', // Default guardian name
          address: '', // Default address
          bloodGroup: '', // Default blood group
          schoolId: _currentUser?.uid ?? '',
          schoolName: '', // Default school name
          gender: 'male', // Default gender
          className: student.className ?? '',
          dateOfBirth: DateTime.now(), // Default date of birth
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      _availableStudents.add(originalStudent);
    });

    _showSnackBar(
      '${student.studentName} removed from vehicle',
      Icons.info,
      Colors.blue,
    );
  }

  Future<void> _saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleType == null) {
      _showSnackBar(
        'Please select vehicle type',
        Icons.warning_amber_rounded,
        Colors.orange,
      );
      return;
    }
    if (_stops.isEmpty) {
      _showSnackBar(
        'Please add at least one stop',
        Icons.info_outline,
        Colors.blue,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      DatabaseService dbService = DatabaseService();
      bool success;

      if (_isEditing) {
        Vehicle updatedVehicle = Vehicle(
          vehicleId: widget.vehicleToEdit!.vehicleId,
          vehicleNumber: _vehicleNumberController.text.trim(),
          vehicleType: _selectedVehicleType!,
          vehicleName: _vehicleNameController.text.trim(),
          modelNumber: _modelNumberController.text.trim(),
          capacity: int.parse(_capacityController.text),
          schoolId: _currentUser!.uid,
          stops: _stops,
          assignedStudents: _assignedStudents,
          driverId: widget.vehicleToEdit!.driverId,
          createdAt: widget.vehicleToEdit!.createdAt,
          updatedAt: DateTime.now(),
        );

        success = await dbService.updateVehicle(updatedVehicle);
      } else {
        String vehicleId = _generateVehicleId();

        Vehicle newVehicle = Vehicle(
          vehicleId: vehicleId,
          vehicleNumber: _vehicleNumberController.text.trim(),
          vehicleType: _selectedVehicleType!,
          vehicleName: _vehicleNameController.text.trim(),
          modelNumber: _modelNumberController.text.trim(),
          capacity: int.parse(_capacityController.text),
          schoolId: _currentUser!.uid,
          stops: _stops,
          assignedStudents: _assignedStudents,
          createdAt: DateTime.now(),
        );

        success = await dbService.addVehicle(newVehicle);
      }

      if (success) {
        _showSnackBar(
          'Vehicle ${_vehicleNameController.text} ${_isEditing ? 'updated' : 'added'} successfully!',
          Icons.check_circle,
          Colors.green,
        );

        if (!_isEditing) {
          _formKey.currentState!.reset();
          setState(() {
            _selectedVehicleType = null;
            _stops.clear();
            _assignedStudents.clear();
            _availableStudents.clear();
            _loadAvailableStudents();
          });
        } else {
          Navigator.pop(context);
        }
      } else {
        _showSnackBar(
          'Failed to ${_isEditing ? 'update' : 'add'} vehicle',
          Icons.error_outline,
          Colors.red,
        );
      }
    } catch (e) {
      _showSnackBar('Error: $e', Icons.error_outline, Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.black),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.black)),
            ),
          ],
        ),
        backgroundColor: color == Colors.red
            ? Colors.red
            : PremiumTheme.neonLime,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildVehicleTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
          ),
          itemCount: _vehicleTypes.length,
          itemBuilder: (context, index) {
            final type = _vehicleTypes[index];
            final isSelected = _selectedVehicleType == type['name'];

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedVehicleType = type['name'];
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: PremiumTheme.darkGrey,
                  border: Border.all(
                    color: isSelected
                        ? PremiumTheme.neonLime
                        : Colors.white.withOpacity(0.1),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: PremiumTheme.neonLime.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type['icon'],
                      color: isSelected ? PremiumTheme.neonLime : Colors.grey,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type['name'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? PremiumTheme.neonLime
                            : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PremiumTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: PremiumTheme.neonLime, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: PremiumTheme.neonLime,
              width: 1,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: PremiumTheme.darkGrey,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildStopsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PremiumTheme.darkGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: PremiumTheme.neonLime,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Vehicle Stops',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextFormField(
                    controller: _stopController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter stop name',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(
                        Icons.add_location_alt,
                        color: PremiumTheme.neonLime,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onFieldSubmitted: (_) => _addStop(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: PremiumTheme.neonLime,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: PremiumTheme.neonLime.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _addStop,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.add, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _pickStopLocation,
              icon: const Icon(Icons.map, color: PremiumTheme.neonLime),
              label: const Text(
                'Pick from Map',
                style: TextStyle(color: PremiumTheme.neonLime),
              ),
            ),
          ),
          if (_stops.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _stops.asMap().entries.map((entry) {
                int index = entry.key;
                String stopRaw = entry.value;
                String stopName = stopRaw;
                String? stopAddress;

                if (stopRaw.contains('|')) {
                  final parts = stopRaw.split('|');
                  stopName = parts[0];
                  stopAddress = parts.length > 1 ? parts[1] : null;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: PremiumTheme.neonLime,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stopName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (stopAddress != null)
                            Text(
                              stopAddress.length > 20
                                  ? '${stopAddress.substring(0, 20)}...'
                                  : stopAddress,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => _removeStop(index),
                        borderRadius: BorderRadius.circular(10),
                        child: Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentsAssignmentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Student Assignment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nearby Students Section
          if (_nearbyStudents.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.near_me, color: Colors.green[800], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Nearby Students (within 200m)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._nearbyStudents.map((student) {
                    bool isAssigned = _assignedStudents.any(
                      (s) => s.studentId == student.studentId,
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(student.fullName),
                        subtitle: Text(student.address),
                        trailing: isAssigned
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : ElevatedButton(
                                onPressed: () => _assignStudent(student),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('Assign'),
                              ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Assigned Students
          if (_assignedStudents.isNotEmpty) ...[
            const Text(
              'Assigned Students:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ..._assignedStudents.map((student) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text(student.studentName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admission: ${student.admissionNumber}'),
                      if (student.className != null)
                        Text('Class: ${student.className}'),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            size: 12,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Text('Pickup: ${student.pickupStop}'),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            size: 12,
                            color: Colors.red,
                          ),
                          SizedBox(width: 4),
                          Text('Dropoff: ${student.dropoffStop}'),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeAssignedStudent(student),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Available Students
          const Text(
            'Available Students:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          if (_availableStudents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  _stops.isEmpty
                      ? 'Add stops first to assign students'
                      : 'No students available to assign',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ..._availableStudents.map((student) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person_add)),
                  title: Text('${student.firstName} ${student.lastName}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admission: ${student.admissionNumber}'),
                      Text('Class: ${student.className}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.green),
                    onPressed: _stops.isEmpty
                        ? null
                        : () => _assignStudent(student),
                    tooltip: _stops.isEmpty
                        ? 'Add stops first'
                        : 'Assign student',
                  ),
                ),
              );
            }),
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
        backgroundColor: PremiumTheme.black,
        foregroundColor: Colors.white,
        title: Text(
          _isEditing ? 'Edit Vehicle' : 'Add Vehicle',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: _isEditing
            ? [
                IconButton(
                  icon: Icon(Icons.people),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleStudentsScreen(
                          vehicle: widget.vehicleToEdit!,
                        ),
                      ),
                    );
                  },
                  tooltip: 'Manage Students',
                ),
              ]
            : null,
      ),
      body: _currentUser == null
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  PremiumTheme.neonLime,
                ),
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: FadeTransition(
                  opacity: _animationController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVehicleTypeSelector(),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _vehicleNumberController,
                        label: 'Vehicle Number',
                        icon: Icons.confirmation_number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter vehicle number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _vehicleNameController,
                        label: 'Vehicle Name',
                        icon: Icons.airport_shuttle,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter vehicle name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _modelNumberController,
                        label: 'Model Number',
                        icon: Icons.model_training,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter model number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _capacityController,
                        label: 'Total Capacity',
                        icon: Icons.people,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter capacity';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          if (int.parse(value) < _assignedStudents.length) {
                            return 'Capacity cannot be less than assigned students (${_assignedStudents.length})';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildStopsSection(),
                      const SizedBox(height: 24),
                      _buildStudentsAssignmentSection(),
                      const SizedBox(height: 32),
                      _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.purple[600]!,
                                ),
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _saveVehicle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PremiumTheme.neonLime,
                                  foregroundColor: PremiumTheme.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 5,
                                  shadowColor: PremiumTheme.neonLime
                                      .withOpacity(0.4),
                                ),
                                child: Text(
                                  _isEditing ? 'Update Vehicle' : 'Add Vehicle',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
