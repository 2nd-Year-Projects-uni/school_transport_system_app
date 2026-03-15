import 'package:flutter/material.dart';

import 'services/vehicle_service.dart';
import 'vehicle_owner_vehicle_details.dart';
import 'vehicle_registration_page.dart';

final Color navy = const Color(0xFF001F3F);
final Color blue = const Color(0xFF005792);
final Color teal = const Color(0xFF00B894);

String _placeNameOrFallback(dynamic value, {String fallback = 'Unknown'}) {
  if (value is String) {
    final String trimmed = value.trim();
    return trimmed.isNotEmpty ? trimmed : fallback;
  }
  if (value is Map) {
    final dynamic candidate = value['name'];
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return fallback;
}

class VehicleOwnerHomePage extends StatefulWidget {
  const VehicleOwnerHomePage({super.key});

  @override
  State<VehicleOwnerHomePage> createState() => _VehicleOwnerHomePageState();
}

class _VehicleOwnerHomePageState extends State<VehicleOwnerHomePage>
    with SingleTickerProviderStateMixin {
  final VehicleService _vehicleService = VehicleService();
  late final AnimationController _fabHighlightController;
  late final Animation<double> _fabScaleAnimation;
  late final Animation<double> _fabGlowAnimation;

  @override
  void initState() {
    super.initState();
    _fabHighlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _fabScaleAnimation = Tween<double>(begin: 1, end: 1.08).animate(
      CurvedAnimation(parent: _fabHighlightController, curve: Curves.easeInOut),
    );
    _fabGlowAnimation = Tween<double>(begin: 0.18, end: 0.36).animate(
      CurvedAnimation(parent: _fabHighlightController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fabHighlightController.dispose();
    super.dispose();
  }

  Future<void> _openVehicleRegistrationPage() async {
    final String? vehicleId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const VehicleRegistrationPage()),
    );

    if (!mounted || vehicleId == null || vehicleId.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Vehicle registered successfully. ID: $vehicleId'),
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

  Widget _modernVehicleIcon(String vehicleType) {
    final Color ringColor = blue.withOpacity(0.24);

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: ringColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: blue.withOpacity(0.20),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Icon(_vehicleIconForType(vehicleType), color: navy, size: 30),
      ),
    );
  }

  Widget _approvalBadge({required bool isApproved}) {
    final Color accentColor = isApproved
        ? Colors.green.shade700
        : Colors.red.shade700;
    final Color badgeBackground = isApproved
        ? Colors.green.shade50
        : Colors.red.shade50;
    final IconData badgeIcon = isApproved
        ? Icons.verified_rounded
        : Icons.hourglass_top_rounded;
    final String badgeText = isApproved ? 'Approved' : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeBackground,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: accentColor.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            badgeText,
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _vehicleService.vehicleStream(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final bool isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null;
        final bool hasVehicles = docs.isNotEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F9FC),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            centerTitle: true,
            title: const Text('My Vehicles'),
            backgroundColor: navy,
            foregroundColor: Colors.white,
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : !hasVehicles
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_bus_outlined,
                        size: 64,
                        color: Colors.blueGrey.shade300,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No vehicles added yet',
                        style: TextStyle(
                          fontSize: 17,
                          color: Colors.blueGrey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final vehicle = docs[index].data() as Map<String, dynamic>;
                    vehicle['id'] = docs[index].id;
                    final String vehicleType =
                        vehicle['vehicleType'] as String? ?? 'Vehicle';
                    final String registerNumber =
                        vehicle['registerNumber'] as String? ?? '';
                    final String startingLocation = _placeNameOrFallback(
                      vehicle['startingLocation'],
                    );
                    final String condition =
                        vehicle['condition'] as String? ?? 'Unknown';
                    final String normalizedCondition = condition
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^a-z]'), '');
                    final bool showAcCondition = normalizedCondition == 'ac';
                    final bool isApproved = vehicle['status'] as bool? ?? false;
                    final Color statusShadowColor = isApproved
                        ? Colors.green.shade600.withOpacity(0.34)
                        : Colors.red.shade300.withOpacity(0.24);

                    return Card(
                      color: Colors.white,
                      elevation: 6,
                      shadowColor: statusShadowColor,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  VehicleOwnerVehicleDetailsPage(
                                    vehicle: vehicle,
                                  ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 120,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      vehicleType,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: navy,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _modernVehicleIcon(vehicleType),
                                    if (showAcCondition) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: teal.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          'AC',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: teal,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _approvalBadge(isApproved: isApproved),
                                      const SizedBox(height: 8),
                                      Text(
                                        registerNumber,
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: navy,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        startingLocation,
                                        textAlign: TextAlign.right,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.blueGrey.shade700,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: AnimatedBuilder(
            animation: _fabHighlightController,
            builder: (context, child) {
              if (hasVehicles) {
                return child!;
              }

              return Transform.scale(
                scale: _fabScaleAnimation.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: teal.withOpacity(_fabGlowAnimation.value),
                        blurRadius: 18,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            child: FloatingActionButton(
              onPressed: _openVehicleRegistrationPage,
              tooltip: 'Add Vehicle',
              backgroundColor: teal,
              foregroundColor: Colors.white,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.directions_bus_filled, size: 24),
                  Positioned(
                    right: -5,
                    top: -5,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.add, size: 12, color: navy),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
