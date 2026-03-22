import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class VanDetailsPage extends StatefulWidget {
  final String vanId;
  final Map<String, dynamic> vanData;
  final String childId;
  final String childName;

  const VanDetailsPage({
    super.key,
    required this.vanId,
    required this.vanData,
    required this.childId,
    required this.childName,
  });

  @override
  State<VanDetailsPage> createState() => _VanDetailsPageState();
}

class _VanDetailsPageState extends State<VanDetailsPage> {
  static const Color teal = Color(0xFF00B894);
  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);

  bool _linking = false;

  Future<void> _linkVan() async {
    setState(() => _linking = true);
    try {
      final code = widget.vanData['code'] as String? ?? '';
      final batch = FirebaseFirestore.instance.batch();

      // Write vanId + code to child doc
      final childRef = FirebaseFirestore.instance
          .collection('Children')
          .doc(widget.childId);
      batch.update(childRef, {
        'vanId': widget.vanId,
        'code': code,
      });

      // Add childId to van's linkedChildren array
      final vanRef = FirebaseFirestore.instance
          .collection('vehicles')
          .doc(widget.vanId);
      batch.update(vanRef, {
        'linkedChildren': FieldValue.arrayUnion([widget.childId]),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Van linked successfully!')),
      );

      // Go back to home screen clearing the stack
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SelectChildPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to link van. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: blue.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.vanData;
    final registerNumber = data['registerNumber'] as String? ?? '';
    final vehicleType = data['vehicleType'] as String? ?? '';
    final condition = data['condition'] as String? ?? '';
    final code = data['code'] as String? ?? '';
    final photoUrl = data['vehiclePhotoUrl'] as String?;

    final startingLocation =
        data['startingLocation'] as Map<String, dynamic>?;
    final startName = startingLocation?['name'] as String? ?? '';

    final routePoints = data['routePoints'] as List<dynamic>? ?? [];
    final schools = data['schools'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: teal,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Van Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── VEHICLE PHOTO ─────────────────────────────
            if (photoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  photoUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Icon(Icons.directions_bus,
                          size: 64, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // ── CODE BADGE ────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: teal,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  registerNumber,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── DETAILS CARD ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: blue.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: blue.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: [
                  _infoRow(Icons.directions_bus_outlined,
                      'Vehicle Type', vehicleType),
                  const Divider(height: 1),
                  _infoRow(Icons.ac_unit_outlined,
                      'Condition', condition),
                  const Divider(height: 1),
                  _infoRow(Icons.location_on_outlined,
                      'Starting Location', startName),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── ROUTE POINTS ──────────────────────────────
            if (routePoints.isNotEmpty) ...[
              const Text(
                'Route Points',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
              const SizedBox(height: 10),
              ...routePoints.map((p) {
                final point = p as Map<String, dynamic>;
                final name = point['name'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_checked,
                          color: teal, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontSize: 14, color: navy),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // ── SCHOOLS ───────────────────────────────────
            if (schools.isNotEmpty) ...[
              const Text(
                'Schools',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
              const SizedBox(height: 10),
              ...schools.map((s) {
                final school = s as Map<String, dynamic>;
                final name = school['name'] as String? ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined,
                          color: blue, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              fontSize: 14, color: navy),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 12),

            // ── LINK BUTTON ───────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _linking ? null : _linkVan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                ),
                icon: _linking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.link, color: Colors.white),
                label: Text(
                  _linking ? 'Linking...' : 'Select This Van',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}