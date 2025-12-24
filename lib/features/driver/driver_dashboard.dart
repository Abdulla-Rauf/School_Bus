// driver_dashboard_enhanced.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';
import '../../models/vehicle_model.dart';
import '../../models/driver_model.dart';
import '../../core/widgets/auth_wrapper.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  _DriverDashboardState createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  UserModel? _currentUser;
  Vehicle? _assignedVehicle;
  Driver? _driverDetails;
  List<VehicleStudent> _assignedStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user = await authService.getCurrentUserData();
    setState(() {
      _currentUser = user;
    });

    if (_currentUser != null) {
      await _loadDriverData();
    }
  }

  Future<void> _loadDriverData() async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();

    Driver? driver = await dbService.getDriverById(_currentUser!.uid);
    Vehicle? vehicle = await dbService.getVehicleByDriver(_currentUser!.uid);

    setState(() {
      _driverDetails = driver;
      _assignedVehicle = vehicle;
      _assignedStudents = vehicle?.assignedStudents ?? [];
      _isLoading = false;
    });
  }

  Widget _buildVehicleInfo() {
    if (_assignedVehicle == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.directions_bus, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No Vehicle Assigned',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please contact your school administrator to assign a vehicle',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    size: 32,
                    color: Colors.red,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _assignedVehicle!.vehicleName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _assignedVehicle!.vehicleNumber,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      Text(
                        '${_assignedVehicle!.vehicleType} • ${_assignedVehicle!.capacity} seats',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL STUDENTS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_assignedStudents.length}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'CAPACITY',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_assignedVehicle!.capacity}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    if (_assignedStudents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No Students Assigned',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
              Text(
                'Students will appear here when assigned by the school',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Assigned Students',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Text(
                '${_assignedStudents.length} students',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        ..._assignedStudents.map((student) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red[100],
                child: Icon(Icons.person, color: Colors.red),
              ),
              title: Text(
                student.studentName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Admission: ${student.admissionNumber}'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'PICKUP',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    student.pickupStop,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                'Time: Morning 7:30 AM',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'DROPOFF',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[800],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    student.dropoffStop,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                'Time: Afternoon 3:30 PM',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.school, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Class: ${student.className ?? 'N/A'}',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Assigned: ${student.assignedAt.day}/${student.assignedAt.month}/${student.assignedAt.year}',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDailyRoute() {
    if (_assignedVehicle == null || _assignedStudents.isEmpty) {
      return Container();
    }

    Map<String, List<VehicleStudent>> pickupGroups = {};
    for (var student in _assignedStudents) {
      if (!pickupGroups.containsKey(student.pickupStop)) {
        pickupGroups[student.pickupStop] = [];
      }
      pickupGroups[student.pickupStop]!.add(student);
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: Colors.blue, size: 24),
                SizedBox(width: 8),
                Text(
                  'Daily Route',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Morning Pickup Route:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            SizedBox(height: 8),
            ...pickupGroups.entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${entry.value.length} students',
                            style: TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.green[100],
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: entry.value.map((student) {
                        return Chip(
                          label: Text(
                            student.studentName.split(' ').first,
                            style: TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.white,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: 16),
            Text(
              'Afternoon Dropoff Route:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            SizedBox(height: 8),
            ...pickupGroups.entries.toList().reversed.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${entry.value.length} students',
                            style: TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.red[100],
                          padding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: entry.value.map((student) {
                        return Chip(
                          label: Text(
                            student.studentName.split(' ').first,
                            style: TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.white,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDriverData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = Provider.of<AuthService>(
                context,
                listen: false,
              );
              await authService.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
                (route) => false,
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDriverData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Card(
                    margin: const EdgeInsets.all(16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red[100],
                            ),
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${_currentUser?.name ?? 'Driver'}!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Driver ID: ${_currentUser?.specificId ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Email: ${_currentUser?.email ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                if (_driverDetails?.phone != null)
                                  Text(
                                    'Phone: ${_driverDetails!.phone}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildVehicleInfo(),
                  _buildDailyRoute(),
                  _buildStudentList(),
                  SizedBox(height: 20),
                ],
              ),
            ),
      floatingActionButton: _assignedVehicle != null
          ? FloatingActionButton.extended(
              onPressed: () {
                _showAttendanceDialog();
              },
              icon: Icon(Icons.qr_code_scanner),
              label: Text('Mark Attendance'),
              backgroundColor: Colors.red,
              elevation: 6,
            )
          : null,
    );
  }

  void _showAttendanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AttendanceScreen(
        students: _assignedStudents,
        onClose: () => Navigator.pop(context),
      ),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  final List<VehicleStudent> students;
  final VoidCallback onClose;

  const AttendanceScreen({
    required this.students,
    required this.onClose,
    super.key,
  });

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Map<String, String> studentStatus;
  late Map<String, String> studentNotes;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    studentStatus = {};
    studentNotes = {};
    for (var student in widget.students) {
      studentStatus[student.admissionNumber] = '';
      studentNotes[student.admissionNumber] = '';
    }
  }

  int get presentCount =>
      studentStatus.values.where((s) => s == 'present').length;
  int get absentCount =>
      studentStatus.values.where((s) => s == 'absent').length;
  int get lateCount => studentStatus.values.where((s) => s == 'late').length;

  void _markStatus(String admissionNumber, String status) {
    setState(() {
      studentStatus[admissionNumber] = status;
    });
  }

  void _saveAttendance() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attendance saved for $presentCount present students'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(Duration(seconds: 1), () {
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.red,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'SAVED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  number: presentCount,
                  label: 'PRESENT',
                  color: Colors.green,
                ),
                _buildStatCard(
                  number: absentCount,
                  label: 'ABSENT',
                  color: Colors.red,
                ),
                _buildStatCard(
                  number: lateCount,
                  label: 'LATE',
                  color: Colors.orange,
                ),
                _buildStatCard(
                  number: widget.students.length,
                  label: 'TOTAL',
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Student List',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  '${widget.students.length} Students',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.students.length,
              itemBuilder: (context, index) {
                var student = widget.students[index];
                var status = studentStatus[student.admissionNumber] ?? '';
                return _buildStudentCard(student, status);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'UPDATE ATTENDANCE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required int number,
    required String label,
    required Color color,
  }) {
    return Container(
      width: 75,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(
            number.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(VehicleStudent student, String status) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                ),
                alignment: Alignment.center,
                child: Text(
                  (widget.students.indexOf(student) + 1).toString(),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.studentName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Admission #${student.admissionNumber}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (status.isNotEmpty) _buildStatusBadge(status),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Mark Status',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              _buildStatusButton(
                label: 'PRESENT',
                color: Colors.green,
                icon: Icons.check,
                isSelected: status == 'present',
                onPressed: () =>
                    _markStatus(student.admissionNumber, 'present'),
              ),
              SizedBox(width: 8),
              _buildStatusButton(
                label: 'ABSENT',
                color: Colors.red,
                icon: Icons.close,
                isSelected: status == 'absent',
                onPressed: () => _markStatus(student.admissionNumber, 'absent'),
              ),
              SizedBox(width: 8),
              _buildStatusButton(
                label: 'LATE',
                color: Colors.orange,
                icon: Icons.schedule,
                isSelected: status == 'late',
                onPressed: () => _markStatus(student.admissionNumber, 'late'),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildStatusButton(
            label: 'EXCUSED',
            color: Colors.blue,
            icon: Icons.info,
            isSelected: status == 'excused',
            onPressed: () => _markStatus(student.admissionNumber, 'excused'),
          ),
          SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Add any notes here...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            maxLines: 2,
            style: TextStyle(fontSize: 12),
            onChanged: (value) {
              studentNotes[student.admissionNumber] = value;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required String label,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Material(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: isSelected ? Colors.white : color),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case 'present':
        bgColor = Colors.green;
        textColor = Colors.white;
        icon = Icons.check;
        label = 'PRESENT';
        break;
      case 'absent':
        bgColor = Colors.transparent;
        textColor = Colors.red;
        icon = Icons.close;
        label = 'ABSENT';
        break;
      case 'late':
        bgColor = Colors.transparent;
        textColor = Colors.orange;
        icon = Icons.schedule;
        label = 'LATE';
        break;
      case 'excused':
        bgColor = Colors.transparent;
        textColor = Colors.blue;
        icon = Icons.info;
        label = 'EXCUSED';
        break;
      default:
        return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: textColor, width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
