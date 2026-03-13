import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'services/vehicle_service.dart';
import 'vehicle_owner_vehicle_details.dart';
import 'vehicle_registration_page.dart';

final Color navy = const Color(0xFF001F3F);
final Color blue = const Color(0xFF005792);
final Color teal = const Color(0xFF00B894);

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

  Widget _approvalStamp({required bool isApproved}) {
    final Color stampColor = isApproved
        ? Colors.green.shade700
        : Colors.red.shade700;
    final String stampText = isApproved ? 'APPROVED' : 'PENDING';

    return Transform.rotate(
      angle: -42 * math.pi / 180,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: stampColor,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: stampColor.withOpacity(0.22),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          stampText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
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
                    final String vehicleType =
                        vehicle['vehicleType'] as String? ?? 'Vehicle';
                    final String registerNumber =
                        vehicle['registerNumber'] as String? ?? '';
                    final String startingLocation =
                        vehicle['startingLocation'] as String? ?? 'Unknown';
                    final String condition =
                        vehicle['condition'] as String? ?? 'Unknown';
                    final bool isApproved = vehicle['status'] as bool? ?? false;
                    final Color statusBorderColor = isApproved
                        ? Colors.green.shade600
                        : Colors.red.shade400;

                    return Card(
                      color: Colors.white,
                      elevation: 2.5,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: statusBorderColor, width: 1.4),
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
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned(
                              left: 0,
                              top: 16,
                              child: _approvalStamp(isApproved: isApproved),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                36,
                                14,
                                16,
                                14,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
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
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: blue.withOpacity(
                                            0.12,
                                          ),
                                          child: Icon(
                                            _vehicleIconForType(vehicleType),
                                            color: blue,
                                            size: 28,
                                          ),
                                        ),
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
                                            condition,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: teal,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
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
                          ],
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
