import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/student_model.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

class StudentDetailsScreen extends StatelessWidget {
  final Student student;
  final String _mapboxAccessToken =
      'pk.eyJ1IjoiYWJkdWxsYS1yYXVmLXBwIiwiYSI6ImNtajVpNXM2dzFibjgzcXI1ZnlubXJmaGIifQ.EOvDjx2LtzwyuPklnz4R1w';

  const StudentDetailsScreen({super.key, required this.student});

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
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
      padding: EdgeInsets.symmetric(vertical: 24),
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

  @override
  Widget build(BuildContext context) {
    mapbox.MapboxOptions.setAccessToken(_mapboxAccessToken);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Details',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Profile Section
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black87, Colors.black54],
                ),
              ),
              child: Column(
                children: [
                  Hero(
                    tag: 'student_avatar_${student.studentId}',
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: ClipOval(
                        child: student.photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: student.photoUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              )
                            : Icon(Icons.person, color: Colors.white, size: 40),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '${student.firstName} ${student.lastName}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    student.admissionNumber,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Class ${student.className}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSection('Personal Information', [
                    _buildInfoCard(
                      'Full Name',
                      '${student.firstName} ${student.lastName}',
                      Icons.person,
                    ),
                    _buildInfoCard(
                      'Admission Number',
                      student.admissionNumber,
                      Icons.confirmation_number,
                    ),
                    _buildInfoCard('Email', student.email, Icons.email),
                    _buildInfoCard('Class', student.className, Icons.class_),
                    _buildInfoCard(
                      'Date of Birth',
                      DateFormat('dd/MM/yyyy').format(student.dateOfBirth),
                      Icons.cake,
                    ),
                    _buildInfoCard(
                      'Blood Group',
                      student.bloodGroup,
                      Icons.bloodtype,
                    ),
                    _buildInfoCard(
                      'Gender',
                      student.gender,
                      Icons.person_outline,
                    ),
                  ]),

                  _buildSection('Contact Information', [
                    _buildInfoCard(
                      'Primary Phone',
                      student.primaryPhone,
                      Icons.phone,
                    ),
                    _buildInfoCard(
                      'Secondary Phone',
                      student.secondaryPhone,
                      Icons.phone_iphone,
                    ),
                    _buildInfoCard(
                      'Address',
                      student.address,
                      Icons.location_on,
                    ),
                  ]),
                  _buildMapSection(),

                  _buildSection('Parents & Guardians', [
                    _buildInfoCard(
                      "Father's Name",
                      student.fatherName,
                      Icons.person_outline,
                    ),
                    _buildInfoCard(
                      "Mother's Name",
                      student.motherName,
                      Icons.person_outline,
                    ),
                    if (student.guardianName.isNotEmpty ?? false)
                      _buildInfoCard(
                        "Guardian's Name",
                        student.guardianName,
                        Icons.person_outline,
                      ),
                    // _buildInfoCard(
                    //   "Father's Occupation",
                    //   student.fatherOccupation,
                    //   Icons.work,
                    // ),
                    // _buildInfoCard(
                    //   "Mother's Occupation",
                    //   student.motherOccupation,
                    //   Icons.work,
                    // ),
                  ]),

                  _buildSection('Academic Information', [
                    // _buildInfoCard(
                    //   'Roll Number',
                    //   student.rollNumber?.toString() ?? 'N/A',
                    //   Icons.numbers,
                    // ),
                    // _buildInfoCard(
                    //   'Academic Year',
                    //   student.academicYear,
                    //   Icons.school,
                    // ),
                    // _buildInfoCard(
                    //   'Section',
                    //   student.section,
                    //   Icons.groups,
                    // ),
                  ]),

                  SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    if (student.latitude == null || student.longitude == null) {
      return const SizedBox.shrink();
    }

    return _buildSection('Home Location', [
      SizedBox(
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: mapbox.MapWidget(
            key: ValueKey("details_map_${student.studentId}"),
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(
                coordinates: mapbox.Position(
                  student.longitude!,
                  student.latitude!,
                ),
              ),
              zoom: 13.0,
            ),
            onMapCreated: (mapbox.MapboxMap mapboxMap) {
              mapboxMap.annotations.createCircleAnnotationManager().then((
                manager,
              ) {
                var options = mapbox.CircleAnnotationOptions(
                  geometry: mapbox.Point(
                    coordinates: mapbox.Position(
                      student.longitude!,
                      student.latitude!,
                    ),
                  ),
                  circleColor: Colors.red.value,
                  circleRadius: 8.0,
                  circleStrokeColor: Colors.white.value,
                  circleStrokeWidth: 2.0,
                );
                manager.create(options);
              });
            },
          ),
        ),
      ),
    ]);
  }
}
