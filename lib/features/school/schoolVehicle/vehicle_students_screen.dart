// vehicle_students_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/student_model.dart';
import '../../../models/user_model.dart';

class VehicleStudentsScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleStudentsScreen({super.key, required this.vehicle});

  @override
  _VehicleStudentsScreenState createState() => _VehicleStudentsScreenState();
}

class _VehicleStudentsScreenState extends State<VehicleStudentsScreen> {
  List<Student> _allStudents = [];
  List<VehicleStudent> _assignedStudents = [];
  List<Student> _availableStudents = [];
  bool _isLoading = true;
  UserModel? _currentUser;
  final String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    AuthService authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user = await authService.getCurrentUserData();
    setState(() {
      _currentUser = user;
    });
    _loadData();
  }

  Future<void> _loadData() async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();

    // Load all students from school
    List<Student> students = await dbService.getStudentsBySchoolId(
      _currentUser!.uid,
    );

    // Get vehicle with updated data
    Vehicle? vehicle = await _getVehicleWithStudents(widget.vehicle.vehicleId);

    setState(() {
      _allStudents = students;
      _assignedStudents = vehicle?.assignedStudents ?? [];

      // Filter available students (not already assigned to this vehicle)
      _availableStudents = students.where((student) {
        return !_assignedStudents.any(
          (assigned) => assigned.studentId == student.studentId,
        );
      }).toList();

      _isLoading = false;
    });
  }

  Future<Vehicle?> _getVehicleWithStudents(String vehicleId) async {
    try {
      DatabaseService dbService = DatabaseService();
      // Get all vehicles and find the specific one
      List<Vehicle> vehicles = await dbService.getVehicles(_currentUser!.uid);
      return vehicles.firstWhere((v) => v.vehicleId == vehicleId);
    } catch (e) {
      print('Error loading vehicle: $e');
      return null;
    }
  }

  Future<void> _assignStudent(Student student) async {
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

    DatabaseService dbService = DatabaseService();
    bool success = await dbService.assignStudentToVehicle(
      vehicleId: widget.vehicle.vehicleId,
      student: vehicleStudent,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.firstName} assigned to vehicle'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign student'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            itemCount: widget.vehicle.stops.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(widget.vehicle.stops[index]),
                onTap: () =>
                    Navigator.pop(context, widget.vehicle.stops[index]),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _removeStudent(VehicleStudent student) async {
    bool confirmed =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Remove Student'),
            content: Text(
              'Are you sure you want to remove ${student.studentName} from this vehicle?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      DatabaseService dbService = DatabaseService();
      bool success = await dbService.removeStudentFromVehicle(
        vehicleId: widget.vehicle.vehicleId,
        studentId: student.studentId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.studentName} removed from vehicle'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    }
  }

  Widget _buildAssignedStudentCard(VehicleStudent student) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Icon(Icons.person)),
        title: Text(student.studentName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admission: ${student.admissionNumber}'),
            if (student.className != null) Text('Class: ${student.className}'),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 12),
                SizedBox(width: 4),
                Text('Pickup: ${student.pickupStop}'),
              ],
            ),
            Row(
              children: [
                Icon(Icons.location_on, size: 12),
                SizedBox(width: 4),
                Text('Dropoff: ${student.dropoffStop}'),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.remove_circle, color: Colors.red),
          onPressed: () => _removeStudent(student),
        ),
      ),
    );
  }

  Widget _buildAvailableStudentCard(Student student) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          onPressed: () => _assignStudent(student),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.vehicle.vehicleName} - Students'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Assigned (${_assignedStudents.length})'),
              Tab(text: 'Available (${_availableStudents.length})'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Assigned Students Tab
                  _assignedStudents.isEmpty
                      ? Center(
                          child: Text('No students assigned to this vehicle'),
                        )
                      : ListView.builder(
                          itemCount: _assignedStudents.length,
                          itemBuilder: (context, index) =>
                              _buildAssignedStudentCard(
                                _assignedStudents[index],
                              ),
                        ),

                  // Available Students Tab
                  _availableStudents.isEmpty
                      ? Center(child: Text('No available students to assign'))
                      : ListView.builder(
                          itemCount: _availableStudents.length,
                          itemBuilder: (context, index) =>
                              _buildAvailableStudentCard(
                                _availableStudents[index],
                              ),
                        ),
                ],
              ),
      ),
    );
  }
}
