import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

///////////////////////////////////////////////////////////////
/// COLOR SYSTEM
///////////////////////////////////////////////////////////////
class AppColors {
  static const primary = Color(0xFF1A237E);
  static const secondary = Color(0xFF0D47A1);
  static const accent = Color(0xFF2962FF);
  static const background = Color(0xFFF5F7FA);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF263238);
  static const textSecondary = Color(0xFF546E7A);
  static const divider = Color(0xFFE0E0E0);
  static const success = Color(0xFF00C853);
  static const error = Color(0xFFD32F2F);
  static const warning = Color(0xFFFFA000);
  static const info = Color(0xFF1976D2);
}

///////////////////////////////////////////////////////////////
/// VEHICLE MENU PAGE
///////////////////////////////////////////////////////////////
class VehicleMenuPage extends StatelessWidget {
  const VehicleMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Vehicle Management",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Center(
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            _menuButton(
              context,
              "Verify Vehicles",
              Icons.verified_outlined,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VerifyVehiclesPage()),
              ),
            ),
            _menuButton(
              context,
              "Vehicle Records",
              Icons.directions_bus_outlined,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VehicleRecordsPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.info),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////
/// VERIFY VEHICLES PAGE
///////////////////////////////////////////////////////////////
class VerifyVehiclesPage extends StatelessWidget {
  const VerifyVehiclesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Verify Vehicles",
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by register number or code...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vehicles')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading vehicles',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No vehicles found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final vehicles = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final doc = vehicles[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildVehicleCard(context, doc, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildVehicleCard(
    BuildContext context,
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
  ) {
    final isVerified = data['verified'] ?? false;
    final registerNumber = data['registerNumber'] ?? 'Unknown';
    final vehicleCode = data['code'] ?? 'N/A';
    final vehicleType = data['vehicleType'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VehicleDetailsPage(doc: doc),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.info],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          vehicleType.isNotEmpty ? vehicleType[0].toUpperCase() : 'V',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            registerNumber,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$vehicleType • Code: $vehicleCode',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (data['drivers'] != null && data['drivers'].isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Driver: ${data['drivers'][0]['name'] ?? 'Not Assigned'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isVerified
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isVerified ? 'Verified' : 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isVerified
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ),
                      ],
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
}

///////////////////////////////////////////////////////////////
/// VEHICLE DETAILS PAGE (for verification)
///////////////////////////////////////////////////////////////
class VehicleDetailsPage extends StatefulWidget {
  final QueryDocumentSnapshot<Object?> doc;

  const VehicleDetailsPage({super.key, required this.doc});

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  bool _isLoading = false;
  bool _isVerified = false;
  Map<String, dynamic>? _vehicleData;
  bool _isLoadingData = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }

  Future<void> _loadVehicleData() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.doc.id)
          .get();

      if (docSnapshot.exists) {
        setState(() {
          _vehicleData = docSnapshot.data() as Map<String, dynamic>;
          _isVerified = _vehicleData?['verified'] ?? false;
          _isLoadingData = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Vehicle document not found';
          _isLoadingData = false;
        });
      }
    } catch (e) {
      print('Error loading vehicle data: $e');
      setState(() {
        _errorMessage = 'Error loading vehicle data: ${e.toString()}';
        _isLoadingData = false;
      });
    }
  }

  Future<void> _updateVerification(bool value) async {
    setState(() => _isLoading = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.doc.id)
          .update({'verified': value, 'status': value});

      if (mounted) {
        setState(() {
          _isVerified = value;
          if (_vehicleData != null) {
            _vehicleData!['verified'] = value;
            _vehicleData!['status'] = value;
          }
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value ? "✓ Vehicle has been verified" : "✗ Vehicle verification revoked",
            ),
            backgroundColor: value ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Vehicle Details"),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("Vehicle Details"),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadVehicleData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _vehicleData ?? (widget.doc.data() as Map<String, dynamic>);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Vehicle Details",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVehicleData,
            tooltip: 'Refresh',
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isVerified 
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isVerified ? 'Verified' : 'Pending',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _isVerified ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle Photo Header
                  if (data['vehiclePhotoUrl'] != null)
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(
                          image: NetworkImage(data['vehiclePhotoUrl']),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['registerNumber'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              data['vehicleType'] ?? 'Unknown Type',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.info],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.directions_bus,
                              size: 80,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              data['registerNumber'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              data['vehicleType'] ?? 'Unknown Type',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Basic Information Section
                  _buildInfoSection(
                    title: "Basic Information",
                    icon: Icons.info_outline,
                    children: [
                      _buildInfoRow("Register Number", data['registerNumber']),
                      _buildInfoRow("Vehicle Code", data['code'] ?? 'N/A'),
                      _buildInfoRow("Vehicle Type", data['vehicleType'] ?? 'N/A'),
                      _buildInfoRow("Condition", data['condition'] ?? 'N/A'),
                      _buildInfoRow("Status", data['status'] == true ? 'Active' : 'Inactive'),
                      _buildInfoRow("Registered Date", _formatDate(data['createdAt'])),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Owner Information
                  if (data['ownerId'] != null)
                    _buildInfoSection(
                      title: "Owner Information",
                      icon: Icons.person_outline,
                      children: [
                        _buildInfoRow("Owner ID", data['ownerId']),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Driver Information
                  if (data['drivers'] != null && data['drivers'].isNotEmpty)
                    _buildInfoSection(
                      title: "Assigned Drivers",
                      icon: Icons.group_outlined,
                      children: [
                        ...List.generate(data['drivers'].length, (index) {
                          final driver = data['drivers'][index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (index > 0) const Divider(height: 20),
                              Text(
                                'Driver ${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.info,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _buildInfoRow("Name", driver['name']),
                              _buildInfoRow("UID", driver['uid']),
                              if (driver['insuranceExpiryDate'] != null)
                                _buildInfoRow("Insurance Expiry", _formatDate(driver['insuranceExpiryDate'])),
                            ],
                          );
                        }),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Starting Location
                  if (data['startingLocation'] != null)
                    _buildInfoSection(
                      title: "Starting Location",
                      icon: Icons.location_on_outlined,
                      children: [
                        _buildInfoRow("Location", data['startingLocation']['name']),
                        _buildInfoRow("Latitude", data['startingLocation']['latitude']?.toString()),
                        _buildInfoRow("Longitude", data['startingLocation']['longitude']?.toString()),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Schools
                  if (data['schools'] != null && data['schools'].isNotEmpty)
                    _buildInfoSection(
                      title: "Associated Schools (${data['schools'].length})",
                      icon: Icons.school_outlined,
                      children: [
                        const SizedBox(height: 8),
                        ...List.generate(data['schools'].length, (index) {
                          final school = data['schools'][index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  school['name'] ?? 'Unknown School',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lat: ${school['latitude']?.toStringAsFixed(6) ?? 'N/A'}, Long: ${school['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Route Points
                  if (data['routePoints'] != null && data['routePoints'].isNotEmpty)
                    _buildInfoSection(
                      title: "Route Points (${data['routePoints'].length})",
                      icon: Icons.route_outlined,
                      children: [
                        const SizedBox(height: 8),
                        ...List.generate(data['routePoints'].length, (index) {
                          final point = data['routePoints'][index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Stop ${index + 1}: ${point['name'] ?? 'Unknown'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lat: ${point['latitude']?.toStringAsFixed(6) ?? 'N/A'}, Long: ${point['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Linked Children
                  if (data['linkedChildren'] != null && data['linkedChildren'].isNotEmpty)
                    _buildInfoSection(
                      title: "Linked Children (${data['linkedChildren'].length})",
                      icon: Icons.child_care_outlined,
                      children: [
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(data['linkedChildren'].length, (index) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Text(
                                data['linkedChildren'][index],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // Insurance Expiry (from first driver if available)
                  if (data['drivers'] != null && 
                      data['drivers'].isNotEmpty && 
                      data['drivers'][0]['insuranceExpiryDate'] != null)
                    _buildInfoSection(
                      title: "Insurance Information",
                      icon: Icons.security_outlined,
                      children: [
                        _buildInfoRow(
                          "Insurance Expiry", 
                          _formatDate(data['drivers'][0]['insuranceExpiryDate'])
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isVerified ? null : () => _updateVerification(true),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text("Verify"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[300],
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isVerified ? () => _updateVerification(false) : null,
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text("Revoke"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[300],
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isVerified 
                              ? "✓ Vehicle is verified and active"
                              : "⚠ Vehicle is pending verification. Review all details before approving.",
                          style: TextStyle(
                            fontSize: 12,
                            color: _isVerified ? AppColors.success : AppColors.warning,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////////
/// VEHICLE RECORDS PAGE (View Only)
///////////////////////////////////////////////////////////////
class VehicleRecordsPage extends StatefulWidget {
  const VehicleRecordsPage({super.key});

  @override
  State<VehicleRecordsPage> createState() => _VehicleRecordsPageState();
}

class _VehicleRecordsPageState extends State<VehicleRecordsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Vehicle Records",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by register number or vehicle code...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vehicles')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading vehicles',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No vehicles found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          // Filter vehicles based on search query (register number)
          var allVehicles = snapshot.data!.docs;
          List<QueryDocumentSnapshot> filteredVehicles;

          if (_searchQuery.isEmpty) {
            filteredVehicles = allVehicles;
          } else {
            filteredVehicles = allVehicles.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final registerNumber = data['registerNumber']?.toString().toLowerCase() ?? '';
              final vehicleCode = data['code']?.toString().toLowerCase() ?? '';
              
              return registerNumber.contains(_searchQuery) ||
                     vehicleCode.contains(_searchQuery);
            }).toList();
          }

          if (filteredVehicles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No vehicles match your search',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredVehicles.length,
            itemBuilder: (context, index) {
              final doc = filteredVehicles[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildVehicleRecordCard(context, doc, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildVehicleRecordCard(
    BuildContext context,
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
  ) {
    final isVerified = data['verified'] ?? false;
    final registerNumber = data['registerNumber'] ?? 'Unknown';
    final vehicleCode = data['code'] ?? 'N/A';
    final vehicleType = data['vehicleType'] ?? 'Unknown';
    final status = data['status'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VehicleRecordDetailPage(doc: doc),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: data['vehiclePhotoUrl'] != null
                      ? Image.network(
                          data['vehiclePhotoUrl'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary.withOpacity(0.8),
                                    AppColors.info.withOpacity(0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  vehicleType.isNotEmpty ? vehicleType[0].toUpperCase() : 'V',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withOpacity(0.8),
                                AppColors.info.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              vehicleType.isNotEmpty ? vehicleType[0].toUpperCase() : 'V',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              registerNumber,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: status ? AppColors.success : AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$vehicleType • Code: $vehicleCode',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (data['drivers'] != null && data['drivers'].isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 12,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Driver: ${data['drivers'][0]['name'] ?? 'Not Assigned'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isVerified ? 'Verified' : 'Pending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isVerified
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

///////////////////////////////////////////////////////////////
/// VEHICLE RECORD DETAIL PAGE (View Only)
///////////////////////////////////////////////////////////////
class VehicleRecordDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot<Object?> doc;

  const VehicleRecordDetailPage({super.key, required this.doc});

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final isVerified = data['verified'] ?? false;
    final status = data['status'] ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Vehicle Record",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isVerified
                  ? AppColors.success.withOpacity(0.2)
                  : AppColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isVerified ? 'Verified' : 'Pending',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isVerified ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Photo Header
            if (data['vehiclePhotoUrl'] != null)
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(data['vehiclePhotoUrl']),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['registerNumber'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        data['vehicleType'] ?? 'Unknown Type',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.info],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.directions_bus,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        data['registerNumber'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        data['vehicleType'] ?? 'Unknown Type',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Basic Information Section
            _buildInfoSection(
              title: "Basic Information",
              icon: Icons.info_outline,
              children: [
                _buildInfoRow("Register Number", data['registerNumber']),
                _buildInfoRow("Vehicle Code", data['code'] ?? 'N/A'),
                _buildInfoRow("Vehicle Type", data['vehicleType'] ?? 'N/A'),
                _buildInfoRow("Condition", data['condition'] ?? 'N/A'),
                _buildInfoRow("Status", status ? 'Active' : 'Inactive'),
                _buildInfoRow("Registered Date", _formatDate(data['createdAt'])),
              ],
            ),

            const SizedBox(height: 20),

            // Owner Information
            if (data['ownerId'] != null)
              _buildInfoSection(
                title: "Owner Information",
                icon: Icons.person_outline,
                children: [
                  _buildInfoRow("Owner ID", data['ownerId']),
                ],
              ),

            const SizedBox(height: 20),

            // Driver Information
            if (data['drivers'] != null && data['drivers'].isNotEmpty)
              _buildInfoSection(
                title: "Assigned Drivers",
                icon: Icons.group_outlined,
                children: [
                  ...List.generate(data['drivers'].length, (index) {
                    final driver = data['drivers'][index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index > 0) const Divider(height: 20),
                        Text(
                          'Driver ${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.info,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildInfoRow("Name", driver['name']),
                        _buildInfoRow("UID", driver['uid']),
                        if (driver['insuranceExpiryDate'] != null)
                          _buildInfoRow("Insurance Expiry", _formatDate(driver['insuranceExpiryDate'])),
                      ],
                    );
                  }),
                ],
              ),

            const SizedBox(height: 20),

            // Starting Location
            if (data['startingLocation'] != null)
              _buildInfoSection(
                title: "Starting Location",
                icon: Icons.location_on_outlined,
                children: [
                  _buildInfoRow("Location", data['startingLocation']['name']),
                  _buildInfoRow("Latitude", data['startingLocation']['latitude']?.toString()),
                  _buildInfoRow("Longitude", data['startingLocation']['longitude']?.toString()),
                ],
              ),

            const SizedBox(height: 20),

            // Schools
            if (data['schools'] != null && data['schools'].isNotEmpty)
              _buildInfoSection(
                title: "Associated Schools (${data['schools'].length})",
                icon: Icons.school_outlined,
                children: [
                  const SizedBox(height: 8),
                  ...List.generate(data['schools'].length, (index) {
                    final school = data['schools'][index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            school['name'] ?? 'Unknown School',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lat: ${school['latitude']?.toStringAsFixed(6) ?? 'N/A'}, Long: ${school['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),

            const SizedBox(height: 20),

            // Route Points
            if (data['routePoints'] != null && data['routePoints'].isNotEmpty)
              _buildInfoSection(
                title: "Route Points (${data['routePoints'].length})",
                icon: Icons.route_outlined,
                children: [
                  const SizedBox(height: 8),
                  ...List.generate(data['routePoints'].length, (index) {
                    final point = data['routePoints'][index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stop ${index + 1}: ${point['name'] ?? 'Unknown'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lat: ${point['latitude']?.toStringAsFixed(6) ?? 'N/A'}, Long: ${point['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),

            const SizedBox(height: 20),

            // Linked Children
            if (data['linkedChildren'] != null && data['linkedChildren'].isNotEmpty)
              _buildInfoSection(
                title: "Linked Children (${data['linkedChildren'].length})",
                icon: Icons.child_care_outlined,
                children: [
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(data['linkedChildren'].length, (index) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          data['linkedChildren'][index],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Insurance Information
            if (data['drivers'] != null && 
                data['drivers'].isNotEmpty && 
                data['drivers'][0]['insuranceExpiryDate'] != null)
              _buildInfoSection(
                title: "Insurance Information",
                icon: Icons.security_outlined,
                children: [
                  _buildInfoRow(
                    "Insurance Expiry", 
                    _formatDate(data['drivers'][0]['insuranceExpiryDate'])
                  ),
                ],
              ),

            const SizedBox(height: 8),
            Center(
              child: Text(
                'View Only Mode • No Edit Options',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}