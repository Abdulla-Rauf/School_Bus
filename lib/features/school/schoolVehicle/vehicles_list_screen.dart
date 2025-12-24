import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_bus2/features/school/schoolVehicle/add_vehicle_screen.dart';
import 'package:school_bus2/features/school/schoolVehicle/vehicle_students_screen.dart';
import 'package:school_bus2/services/database_service.dart';
import '../../../services/auth_service.dart';
import 'package:school_bus2/core/theme/premium_theme.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/user_model.dart';
import 'assign_driver_screen.dart';

class VehiclesListScreen extends StatefulWidget {
  const VehiclesListScreen({super.key});

  @override
  _VehiclesListScreenState createState() => _VehiclesListScreenState();
}

class _VehiclesListScreenState extends State<VehiclesListScreen>
    with SingleTickerProviderStateMixin {
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  UserModel? _currentUser;
  late AnimationController _fabAnimationController;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    AuthService authService = Provider.of<AuthService>(context, listen: false);
    UserModel? user = await authService.getCurrentUserData();
    setState(() {
      _currentUser = user;
    });
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    if (_currentUser == null) return;

    DatabaseService dbService = DatabaseService();
    List<Vehicle> vehicles = await dbService.getVehicles(_currentUser!.uid);

    setState(() {
      _vehicles = vehicles;
      _isLoading = false;
    });
    _fabAnimationController.forward();
  }

  List<Vehicle> get _filteredVehicles {
    if (_searchQuery.isEmpty) return _vehicles;
    return _vehicles.where((vehicle) {
      return vehicle.vehicleName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          vehicle.vehicleNumber.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          vehicle.vehicleType.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          vehicle.vehicleId.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Vehicle',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${vehicle.vehicleName}? This action cannot be undone.',
          style: const TextStyle(fontSize: 15, color: Colors.white70),
        ),
        backgroundColor: PremiumTheme.darkGrey,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        contentTextStyle: const TextStyle(color: Colors.white70),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      DatabaseService dbService = DatabaseService();
      bool success = await dbService.deleteVehicle(vehicle.vehicleId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${vehicle.vehicleName} deleted successfully'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: PremiumTheme.neonLime,
          ),
        );
        _loadVehicles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Failed to delete vehicle'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editVehicle(Vehicle vehicle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleScreen(vehicleToEdit: vehicle),
      ),
    ).then((_) => _loadVehicles());
  }

  Widget _buildVehicleCard(Vehicle vehicle, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PremiumTheme.darkGrey,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            // TODO: Show vehicle details
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: PremiumTheme.darkGrey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: PremiumTheme.neonLime.withOpacity(0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PremiumTheme.neonLime.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.airport_shuttle_rounded,
                        color: PremiumTheme.neonLime,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.vehicleName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              letterSpacing: 0.3,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: PremiumTheme.neonLime.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.confirmation_number_rounded,
                                      size: 14,
                                      color: PremiumTheme.neonLime,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      vehicle.vehicleNumber,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: PremiumTheme.neonLime,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: Colors.grey[400],
                      ),
                      color: PremiumTheme.darkGrey,
                      offset: const Offset(0, 10),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editVehicle(vehicle);
                        } else if (value == 'delete') {
                          _deleteVehicle(vehicle);
                        } else if (value == 'students') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  VehicleStudentsScreen(vehicle: vehicle),
                            ),
                          ).then((_) => _loadVehicles());
                        } else if (value == 'assign_driver') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AssignDriverScreen(vehicle: vehicle),
                            ),
                          ).then((_) => _loadVehicles());
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_rounded,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Edit',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'students',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.people_outline_rounded,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'View Students',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'assign_driver',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_add_alt_rounded,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Assign Driver',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.directions_car_filled_rounded,
                      vehicle.vehicleType,
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.people_rounded,
                      '${vehicle.capacity} seats',
                      Colors.purple,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        Icons.model_training_rounded,
                        vehicle.modelNumber,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                if (vehicle.stops.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Stops (${vehicle.stops.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: vehicle.stops.take(4).map((stop) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: PremiumTheme.black,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                stop,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (vehicle.stops.length > 4)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+ ${vehicle.stops.length - 4} more',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.people_rounded, size: 18),
                        label: Text(
                          'Students (${vehicle.assignedStudents.length})',
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  VehicleStudentsScreen(vehicle: vehicle),
                            ),
                          ).then((_) => _loadVehicles());
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: PremiumTheme.neonLime,
                          side: BorderSide(color: PremiumTheme.neonLime),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (vehicle.driverId != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.person_rounded, size: 18),
                          label: const Text(
                            'Driver',
                            style: TextStyle(fontSize: 13),
                          ),
                          onPressed: () {
                            // TODO: Show driver details or assign driver
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: PremiumTheme.neonLime,
                            side: BorderSide(
                              color: PremiumTheme.neonLime.withOpacity(0.7),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PremiumTheme.darkGrey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.airport_shuttle_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No vehicles yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first vehicle to get started',
              style: TextStyle(fontSize: 15, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: PremiumTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: PremiumTheme.neonLime.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'FLEET',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Vehicles',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: PremiumTheme.black,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.airport_shuttle_rounded,
                    color: PremiumTheme.black,
                    size: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_vehicles.length}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 40, color: Colors.white24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'CAPACITY',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_vehicles.fold<int>(0, (sum, v) => sum + v.capacity)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final filteredVehicles = _filteredVehicles;

    return Scaffold(
      backgroundColor: PremiumTheme.black,
      appBar: AppBar(
        title: const Text(
          'Vehicles',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: PremiumTheme.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isSearching
                    ? PremiumTheme.neonLime.withOpacity(0.2)
                    : PremiumTheme.darkGrey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isSearching ? Icons.close_rounded : Icons.search_rounded,
                color: _isSearching ? PremiumTheme.neonLime : Colors.white,
                size: 20,
              ),
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                }
              });
            },
            tooltip: 'Search',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Colors.black87,
                size: 20,
              ),
            ),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadVehicles();
            },
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4ACFAC)),
            )
          : Column(
              children: [
                if (!_isSearching) _buildQuickCard(),
                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search vehicles...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey[400],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                Expanded(
                  child: _vehicles.isEmpty
                      ? _buildEmptyState()
                      : _filteredVehicles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 60,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No vehicles found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadVehicles,
                          color: const Color(0xFF4ACFAC),
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 100),
                            itemCount: _filteredVehicles.length,
                            itemBuilder: (context, index) {
                              return _buildVehicleCard(
                                _filteredVehicles[index],
                                index,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabAnimationController,
          curve: Curves.elasticOut,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4ACFAC), Color(0xFF43A08D)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4ACFAC).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () {
              // This was referencing AddVehicleScreen but might need args or not.
              // Previous code: Navigator.push(... AddVehicleScreen())
              // AddVehicleScreen(vehicleToEdit: null) usually
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddVehicleScreen(),
                ),
              ).then((_) => _loadVehicles());
            },
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Add Vehicle',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    );
  }
}
