import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

final Color _detailsNavy = const Color(0xFF001F3F);
final Color _detailsBlue = const Color(0xFF005792);
final Color _detailsTeal = const Color(0xFF00B894);

class VehicleOwnerVehicleDetailsPage extends StatelessWidget {
  const VehicleOwnerVehicleDetailsPage({super.key, required this.vehicle});

  final Map<String, dynamic> vehicle;

  @override
  Widget build(BuildContext context) {
    final String vehicleType = vehicle['vehicleType'] as String? ?? 'Vehicle';
    final String registerNumber =
        vehicle['registerNumber'] as String? ?? 'Not available';
    final String startingLocation =
        vehicle['startingLocation'] as String? ?? 'Not available';
    final String condition = vehicle['condition'] as String? ?? 'Not available';
    final String photoUrl = vehicle['vehiclePhotoUrl'] as String? ?? '';
    final bool isApproved = vehicle['status'] as bool? ?? false;
    final List<String> schools = (vehicle['schools'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final String insuranceExpiryDate = _formatDate(
      vehicle['insuranceExpiryDate'],
    );
    final String createdAt = _formatDate(vehicle['createdAt']);
    final Color statusColor = isApproved
        ? Colors.green.shade700
        : Colors.red.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F9FC),
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        backgroundColor: _detailsNavy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: photoUrl.isEmpty
                          ? Container(
                              color: _detailsBlue.withOpacity(0.08),
                              alignment: Alignment.center,
                              child: Icon(
                                _vehicleIconForType(vehicleType),
                                size: 80,
                                color: _detailsBlue,
                              ),
                            )
                          : Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  color: _detailsBlue.withOpacity(0.08),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    _vehicleIconForType(vehicleType),
                                    size: 80,
                                    color: _detailsBlue,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    registerNumber,
                                    style: TextStyle(
                                      color: _detailsNavy,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    vehicleType,
                                    style: TextStyle(
                                      color: _detailsBlue,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isApproved ? 'Approved' : 'Pending Approval',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          startingLocation,
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Registration Information',
              children: [
                _InfoRow(
                  icon: Icons.directions_bus_rounded,
                  label: 'Vehicle Type',
                  value: vehicleType,
                ),
                _InfoRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Register Number',
                  value: registerNumber,
                ),
                _InfoRow(
                  icon: Icons.ac_unit_outlined,
                  label: 'Air Conditioning',
                  value: condition,
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Starting Location',
                  value: startingLocation,
                ),
                _InfoRow(
                  icon: Icons.shield_outlined,
                  label: 'Insurance Expiry',
                  value: insuranceExpiryDate,
                ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Submitted On',
                  value: createdAt,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Schools',
              children: [
                if (schools.isEmpty)
                  Text(
                    'No schools added.',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: schools
                        .map(
                          (school) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _detailsTeal.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              school,
                              style: TextStyle(
                                color: _detailsTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _vehicleIconForType(String vehicleType) {
    final String normalized = vehicleType.toLowerCase();
    if (normalized.contains('van')) {
      return Icons.airport_shuttle_outlined;
    }
    return Icons.directions_bus_filled;
  }

  String _formatDate(dynamic value) {
    DateTime? dateTime;
    if (value is Timestamp) {
      dateTime = value.toDate();
    } else if (value is DateTime) {
      dateTime = value;
    }

    if (dateTime == null) {
      return 'Not available';
    }

    final String day = dateTime.day.toString().padLeft(2, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String year = dateTime.year.toString();
    return '$day/$month/$year';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _detailsNavy,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _detailsBlue.withOpacity(0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _detailsBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.blueGrey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: _detailsNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
