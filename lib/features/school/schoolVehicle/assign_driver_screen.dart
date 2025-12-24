// assign_driver_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/driver_model.dart';
import '../../../models/user_model.dart';

class AssignDriverScreen extends StatefulWidget {
  final Vehicle vehicle;

  const AssignDriverScreen({super.key, required this.vehicle});

  @override
  _AssignDriverScreenState createState() => _AssignDriverScreenState();
}

class _AssignDriverScreenState extends State<AssignDriverScreen> {
  List<Driver> _availableDrivers = [];
  bool _isLoading = true;
  UserModel? _currentUser;
  String? _selectedDriverId;

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
    _loadAvailableDrivers();
  }

  Future<void> _loadAvailableDrivers() async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();
    List<Driver> drivers = await dbService.getDrivers(_currentUser!.uid);

    setState(() {
      _availableDrivers = drivers;
      _selectedDriverId = widget.vehicle.driverId;
      _isLoading = false;
    });
  }

  Future<void> _assignDriver(String driverId) async {
    DatabaseService dbService = DatabaseService();
    bool success = await dbService.assignDriverToVehicle(
      vehicleId: widget.vehicle.vehicleId,
      driverId: driverId,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Driver assigned successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign driver'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Assign Driver to ${widget.vehicle.vehicleName}'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select a driver for this vehicle:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _availableDrivers.length,
                    itemBuilder: (context, index) {
                      Driver driver = _availableDrivers[index];
                      return RadioListTile<String>(
                        title: Text(driver.name),
                        subtitle: Text(driver.driverId),
                        value: driver.driverId,
                        groupValue: _selectedDriverId,
                        onChanged: (value) {
                          setState(() {
                            _selectedDriverId = value;
                          });
                        },
                        secondary: CircleAvatar(child: Icon(Icons.person)),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedDriverId != null
                          ? () => _assignDriver(_selectedDriverId!)
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text('Assign Driver'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
