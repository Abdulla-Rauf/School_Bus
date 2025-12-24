import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math' as math;

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialLandmark;
  final String? initialAddress;
  final String title;
  final double? centerLat;
  final double? centerLng;
  final double? radiusInKm;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialLandmark,
    this.initialAddress,
    this.title = 'Select Location',
    this.centerLat,
    this.centerLng,
    this.radiusInKm,
  });

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.CircleAnnotationManager? _circleAnnotationManager;
  mapbox.PolygonAnnotationManager? _polygonAnnotationManager;
  final String _mapboxAccessToken =
      'pk.eyJ1IjoiYWJkdWxsYS1yYXVmLXBwIiwiYSI6ImNtajVpNXM2dzFibjgzcXI1ZnlubXJmaGIifQ.EOvDjx2LtzwyuPklnz4R1w';

  double? _selectedLat;
  double? _selectedLng;
  String? _selectedAddress;
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _placeNameController = TextEditingController();
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    mapbox.MapboxOptions.setAccessToken(_mapboxAccessToken);

    _selectedLat = widget.initialLat ?? widget.centerLat ?? 20.5937;
    _selectedLng = widget.initialLng ?? widget.centerLng ?? 78.9629;
    _landmarkController.text = widget.initialLandmark ?? '';
    _selectedAddress = widget.initialAddress;
  }

  @override
  void dispose() {
    _landmarkController.dispose();
    _placeNameController.dispose();
    super.dispose();
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    // Create Circle Manager
    _mapboxMap?.annotations.createCircleAnnotationManager().then((manager) {
      _circleAnnotationManager = manager;
      if (_selectedLat != null &&
          _selectedLng != null &&
          widget.initialLat != null) {
        _updateMarker(_selectedLat!, _selectedLng!);
      }
    });

    // Create Polygon Manager
    _mapboxMap?.annotations.createPolygonAnnotationManager().then((manager) {
      _polygonAnnotationManager = manager;
      _drawSchoolZone();
    });
  }

  void _drawSchoolZone() async {
    if (widget.centerLat != null &&
        widget.centerLng != null &&
        widget.radiusInKm != null &&
        _polygonAnnotationManager != null) {
      // Draw 5km radius circle
      List<mapbox.Position> polygonCoords = _createCirclePolygon(
        widget.centerLat!,
        widget.centerLng!,
        widget.radiusInKm!,
      );

      // Create polygon
      var options = mapbox.PolygonAnnotationOptions(
        geometry: mapbox.Polygon(coordinates: [polygonCoords]),
        fillColor: Colors.blue.withOpacity(0.15).value,
        fillOutlineColor: Colors.blue.value,
      );

      await _polygonAnnotationManager!.create(options);

      // Draw center marker (School)
      if (_circleAnnotationManager != null) {
        var schoolMarker = mapbox.CircleAnnotationOptions(
          geometry: mapbox.Point(
            coordinates: mapbox.Position(widget.centerLng!, widget.centerLat!),
          ),
          circleColor: Colors.blue.value,
          circleRadius: 6.0,
          circleStrokeColor: Colors.white.value,
          circleStrokeWidth: 2.0,
        );
        await _circleAnnotationManager!.create(schoolMarker);
      }
    }
  }

  List<mapbox.Position> _createCirclePolygon(
    double centerLat,
    double centerLng,
    double radiusInKm, {
    int points = 64,
  }) {
    List<mapbox.Position> coordinates = [];
    double distanceX =
        radiusInKm / (111.320 * math.cos(centerLat * math.pi / 180));
    double distanceY = radiusInKm / 110.574;

    for (int i = 0; i < points; i++) {
      double theta = (i / points) * (2 * math.pi);
      double x = distanceX * math.cos(theta);
      double y = distanceY * math.sin(theta);

      coordinates.add(mapbox.Position(centerLng + x, centerLat + y));
    }
    coordinates.add(coordinates[0]); // Close the ring
    return coordinates;
  }

  void _onMapTap(mapbox.MapContentGestureContext context) async {
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

    // Redraw School Marker if exists
    if (widget.centerLat != null && widget.centerLng != null) {
      var schoolMarker = mapbox.CircleAnnotationOptions(
        geometry: mapbox.Point(
          coordinates: mapbox.Position(widget.centerLng!, widget.centerLat!),
        ),
        circleColor: Colors.blue.value,
        circleRadius: 6.0,
        circleStrokeColor: Colors.white.value,
        circleStrokeWidth: 2.0,
      );
      await _circleAnnotationManager!.create(schoolMarker);
    }

    var options = mapbox.CircleAnnotationOptions(
      geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
      circleColor: Colors.red.value,
      circleRadius: 8.0,
      circleStrokeColor: Colors.white.value,
      circleStrokeWidth: 2.0,
    );

    await _circleAnnotationManager!.create(options);
  }

  Future<void> _getAddressFromLocation(double lat, double lng) async {
    setState(() => _isLoadingAddress = true);
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

        if (_placeNameController.text.isEmpty) {
          // Try to get a meaningful name
          String name = placemark.name ?? '';
          // Avoid using name if it's just 'India' or just the street
          bool isGeneric =
              name == placemark.isoCountryCode || name == placemark.country;
          if (isGeneric || name.isEmpty) {
            name =
                placemark.subLocality ??
                placemark.locality ??
                'Selected Location';
          }
          _placeNameController.text = name;
        }
      } else {
        _selectedAddress =
            '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      }
    } catch (e) {
      _selectedAddress = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

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
            center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
            zoom: 15.0,
          ),
          mapbox.MapAnimationOptions(duration: 1000),
        );
      }
      await _getAddressFromLocation(lat, lng);
    } catch (e) {
      print('Error: $e');
    }
  }

  void _saveLocation() {
    if (_selectedLat == null || _selectedLng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a location')));
      return;
    }
    Navigator.pop(
      context,
      LocationResult(
        latitude: _selectedLat!,
        longitude: _selectedLng!,
        landmark: _landmarkController.text.trim(),
        address: _selectedAddress,
        placeName: _placeNameController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _useCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextFormField(
                  controller: _placeNameController,
                  decoration: InputDecoration(
                    labelText: 'Place Name (e.g. School Gate, Home)',
                    prefixIcon: const Icon(Icons.label, color: Colors.blue),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _landmarkController,
                  decoration: InputDecoration(
                    labelText: 'Nearest Landmark',
                    prefixIcon: const Icon(Icons.place, color: Colors.green),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isLoadingAddress
                      ? 'Loading...'
                      : (_selectedAddress ?? 'Tap map to select'),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                mapbox.MapWidget(
                  onMapCreated: _onMapCreated,
                  cameraOptions: mapbox.CameraOptions(
                    center: mapbox.Point(
                      coordinates: mapbox.Position(
                        _selectedLng ?? 78.9629,
                        _selectedLat ?? 20.5937,
                      ),
                    ),
                    zoom: 13.0,
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
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text('Save Location'),
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

class LocationResult {
  final double latitude;
  final double longitude;
  final String? landmark;
  final String? address;
  final String? placeName;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.landmark,
    this.address,
    this.placeName,
  });
}
