import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverInfoPage extends StatefulWidget {
  final String childId;
  final String childName;

  const DriverInfoPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<DriverInfoPage> createState() => _DriverInfoPageState();
}

class _DriverInfoPageState extends State<DriverInfoPage> {
  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);
  static const Color teal = Color(0xFF00B894);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _vehicleData;
  List<Map<String, dynamic>> _driverDetails = [];

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    try {
      final childDoc = await FirebaseFirestore.instance
          .collection('Children')
          .doc(widget.childId)
          .get();

      if (!childDoc.exists) {
        setState(() {
          _error = 'Child data not found.';
          _loading = false;
        });
        return;
      }

      final vanId = childDoc.data()?['vanId'];
      if (vanId == null || vanId.toString().isEmpty) {
        setState(() {
          _error = 'This child is not yet linked to a vehicle.';
          _loading = false;
        });
        return;
      }

      final vehicleDoc = await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(vanId)
          .get();

      if (!vehicleDoc.exists) {
        setState(() {
          _error = 'Vehicle data not found.';
          _loading = false;
        });
        return;
      }

      final vData = vehicleDoc.data()!;
      
      final driversArray = vData['drivers'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> driversList = [];

      for (var d in driversArray) {
        if (d is Map<String, dynamic>) {
          final uid = d['uid'];
          String phone = '';
          if (uid != null) {
            // Check users collection for phone number
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
            if (userDoc.exists) {
              phone = userDoc.data()?['phone'] ?? '';
            }
          }
          driversList.add({
            'name': d['name'] ?? 'Unknown',
            'phone': phone,
          });
        }
      }

      if (mounted) {
        setState(() {
          _vehicleData = vData;
          _driverDetails = driversList;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load details.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    
    // Normalize string to just + and digits
    final String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    
    try {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open dialer.')),
        );
      }
    }
  }

  Future<void> _handleResign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFD62828).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD62828), size: 44),
            ),
            const SizedBox(height: 24),
            const Text(
              'Resign from Vehicle',
              style: TextStyle(color: navy, fontSize: 22, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to completely disconnect your child from this vehicle? You will lose all live location tracking immediately.',
              style: TextStyle(color: navy.withOpacity(0.7), fontSize: 15, fontWeight: FontWeight.w500, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD62828),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Disconnect', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    try {
      // Securely fetch the live child doc exactly at the moment of resignation 
      // This prevents hot-reload state glitches and stops double-clicks.
      final liveChildDoc = await FirebaseFirestore.instance.collection('Children').doc(widget.childId).get();
      final liveVanId = liveChildDoc.data()?['vanId'];

      if (liveVanId == null || liveVanId.toString().isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Child is already not linked to any vehicle.')));
        Navigator.pop(context); // Go back out
        return;
      }

      final batch = FirebaseFirestore.instance.batch();

      final childRef = FirebaseFirestore.instance.collection('Children').doc(widget.childId);
      batch.update(childRef, {'vanId': '', 'code': ''});

      final vanRef = FirebaseFirestore.instance.collection('vehicles').doc(liveVanId.toString());
      batch.update(vanRef, {
        'linkedChildren': FieldValue.arrayRemove([widget.childId]),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully disconnected from vehicle.')),
      );
      
      // Navigate all the way back to the Select Child screen, clearing history so they don't land on a broken dashboard
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resign from vehicle. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FCFF),
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Driver & Vehicle Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      bottomNavigationBar: _loading || _error != null ? null : _buildResignButton(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: blue))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 50),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(color: navy.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(Icons.directions_bus_rounded, 'Vehicle Details'),
                      const SizedBox(height: 16),
                      _buildVehicleCard(),
                      const SizedBox(height: 32),
                      _buildSectionHeader(Icons.person_pin_circle_rounded, 'Assigned Drivers'),
                      const SizedBox(height: 16),
                      if (_driverDetails.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: blue.withOpacity(0.15)),
                          ),
                          child: const Center(
                            child: Text(
                              "No drivers directly assigned to this vehicle.",
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ),
                        )
                      else
                        ..._driverDetails.map((drv) => _buildDriverCard(drv)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildResignButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FCFF),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: _handleResign,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD62828),
              side: const BorderSide(color: Color(0xFFD62828), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              backgroundColor: Colors.white,
            ),
            icon: const Icon(Icons.exit_to_app_rounded, size: 22),
            label: const Text(
              "Resign from Vehicle",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: blue, size: 28),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: navy,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard() {
    final v = _vehicleData!;
    final photoUrl = v['vehiclePhotoUrl'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: blue.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          if (photoUrl != null && photoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                photoUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackImage(),
              ),
            )
          else
            _buildFallbackImage(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildInfoRow('Registration', v['registerNumber'] ?? 'N/A'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: blue.withOpacity(0.1), thickness: 1.5),
                ),
                _buildInfoRow('Vehicle Type', v['vehicleType'] ?? 'N/A'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: blue.withOpacity(0.1), thickness: 1.5),
                ),
                _buildInfoRow('Condition', v['condition'] == 'AC' ? 'A/C Available' : 'Non A/C'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: BoxDecoration(
        color: blue.withOpacity(0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Icon(
          Icons.directions_bus,
          size: 60,
          color: blue.withOpacity(0.35),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: navy.withOpacity(0.6), fontSize: 15, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: const TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final name = driver['name'] ?? 'Unknown';
    final phone = driver['phone'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: blue.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: teal.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: teal, size: 30),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 16, color: navy.withOpacity(0.5)),
                      const SizedBox(width: 6),
                      Text(
                        phone.isNotEmpty ? phone : 'No number',
                        style: TextStyle(color: navy.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (phone.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: const Icon(Icons.call),
                  color: teal,
                  iconSize: 26,
                  onPressed: () => _makePhoneCall(phone),
                  tooltip: 'Call Driver',
                ),
              ),
          ],
        ),
      ),
    );
  }
}