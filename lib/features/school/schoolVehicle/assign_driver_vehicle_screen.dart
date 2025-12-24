// assign_driver_vehicle_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/driver_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/user_model.dart';

class AssignDriverVehicleScreen extends StatefulWidget {
  final Driver driver;
  final Vehicle? currentVehicle;

  const AssignDriverVehicleScreen({
    super.key,
    required this.driver,
    this.currentVehicle,
  });

  @override
  _AssignDriverVehicleScreenState createState() =>
      _AssignDriverVehicleScreenState();
}

class _AssignDriverVehicleScreenState extends State<AssignDriverVehicleScreen> {
  List<Vehicle> _availableVehicles = [];
  Vehicle? _selectedVehicle;
  bool _isLoading = true;
  UserModel? _currentUser;

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
    _loadAvailableVehicles();
  }

  Future<void> _loadAvailableVehicles() async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();
    // Get unassigned vehicles
    List<Vehicle> unassignedVehicles = await dbService.getUnassignedVehicles(
      _currentUser!.uid,
    );

    // If driver already has a vehicle, include it in the list
    if (widget.currentVehicle != null) {
      unassignedVehicles.add(widget.currentVehicle!);
    }

    setState(() {
      _availableVehicles = unassignedVehicles;
      _selectedVehicle = widget.currentVehicle;
      _isLoading = false;
    });
  }

  Future<void> _assignVehicle() async {
    if (_selectedVehicle == null) return;

    DatabaseService dbService = DatabaseService();
    bool success = await dbService.assignDriverToVehicle(
      vehicleId: _selectedVehicle!.vehicleId,
      driverId: widget.driver.driverId,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.driver.name} assigned to ${_selectedVehicle!.vehicleName}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign vehicle'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeAssignment() async {
    if (widget.currentVehicle == null) return;

    bool confirmed =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Remove Assignment'),
            content: Text(
              'Remove ${widget.driver.name} from ${widget.currentVehicle!.vehicleName}?',
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
      bool success = await dbService.removeDriverFromVehicle(
        widget.currentVehicle!.vehicleId,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment removed'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Assign Vehicle to ${widget.driver.name}')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            child: widget.driver.photoUrl != null
                                ? Image.network(widget.driver.photoUrl!)
                                : Icon(Icons.person),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.driver.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(widget.driver.driverId),
                                Text(widget.driver.phone),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Select Vehicle:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: _availableVehicles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_bus,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No vehicles available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add vehicles first to assign drivers',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _availableVehicles.length,
                            itemBuilder: (context, index) {
                              Vehicle vehicle = _availableVehicles[index];
                              bool isCurrentVehicle =
                                  widget.currentVehicle?.vehicleId ==
                                  vehicle.vehicleId;

                              return Card(
                                margin: EdgeInsets.symmetric(vertical: 4),
                                child: RadioListTile<Vehicle>(
                                  title: Text(vehicle.vehicleName),
                                  subtitle: Text(
                                    '${vehicle.vehicleNumber} • ${vehicle.vehicleType} • ${vehicle.capacity} seats',
                                  ),
                                  value: vehicle,
                                  groupValue: _selectedVehicle,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedVehicle = value;
                                    });
                                  },
                                  secondary: isCurrentVehicle
                                      ? Chip(
                                          label: Text('Current'),
                                          backgroundColor: Colors.blue.shade100,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                  SizedBox(height: 20),
                  if (widget.currentVehicle != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _removeAssignment,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                        ),
                        child: Text('Remove Current Assignment'),
                      ),
                    ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedVehicle != null
                          ? _assignVehicle
                          : null,
                      child: Text(
                        _selectedVehicle == widget.currentVehicle
                            ? 'Update Assignment'
                            : 'Assign Vehicle',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
