import 'package:flutter/material.dart';

import 'services/vehicle_service.dart';
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
    final bool? registered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const VehicleRegistrationPage()),
    );

    if (!mounted || registered != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vehicle registered successfully.')),
    );
  }

  IconData _vehicleIconForType(String vehicleType) {
    final String normalized = vehicleType.toLowerCase();
    if (normalized.contains('van')) {
      return Icons.airport_shuttle_outlined;
    }
    return Icons.directions_bus_filled;
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
                    final List<String> schools =
                        (vehicle['schools'] as List<dynamic>? ?? [])
                            .whereType<String>()
                            .toList();
                    final String vehicleType =
                        vehicle['vehicleType'] as String? ?? 'Vehicle';
                    final String registerNumber =
                        vehicle['registerNumber'] as String? ?? '';
                    final String condition =
                        vehicle['condition'] as String? ?? 'Unknown';

                    return Card(
                      color: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: blue.withOpacity(0.15)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: blue.withOpacity(0.12),
                          child: Icon(
                            _vehicleIconForType(vehicleType),
                            color: blue,
                          ),
                        ),
                        title: Text(
                          registerNumber,
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$vehicleType • ${schools.length} school${schools.length == 1 ? '' : 's'}',
                            style: TextStyle(color: Colors.blueGrey.shade700),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: teal.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            condition,
                            style: TextStyle(
                              color: teal,
                              fontWeight: FontWeight.w600,
                            ),
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
