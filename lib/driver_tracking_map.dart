import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DriverTrackingMapPage extends StatefulWidget {
  final String childId;
  final String childName;

  const DriverTrackingMapPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<DriverTrackingMapPage> createState() => _DriverTrackingMapPageState();
}

class _DriverTrackingMapPageState extends State<DriverTrackingMapPage> {
  GoogleMapController? _mapController;
  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612); // Colombo

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  LatLng _toLatLngFromMap(Map<String, dynamic>? map) {
    if (map == null) return _defaultLocation;
    final latitude = (map['latitude'] as num?)?.toDouble();
    final longitude = (map['longitude'] as num?)?.toDouble();
    if (latitude != null && longitude != null) {
      return LatLng(latitude, longitude);
    }
    return _defaultLocation;
  }

  LatLng _getDriverLocationFromDocument(
    Map<String, dynamic>? driverData,
    Map<String, dynamic>? vehicleData,
  ) {
    if (driverData != null) {
      final currentLocation = driverData['currentLocation'];
      if (currentLocation is GeoPoint) {
        return LatLng(currentLocation.latitude, currentLocation.longitude);
      }
      if (currentLocation is Map<String, dynamic>) {
        return _toLatLngFromMap(currentLocation);
      }
    }

    final startingLocation =
        vehicleData?['startingLocation'] as Map<String, dynamic>?;
    if (startingLocation != null) {
      return _toLatLngFromMap(startingLocation);
    }

    return _defaultLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Children')
            .doc(widget.childId)
            .snapshots(),
        builder: (context, childSnapshot) {
          if (childSnapshot.hasError) {
            return Center(child: Text('Error: ${childSnapshot.error}'));
          }
          if (!childSnapshot.hasData || !childSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final childData = childSnapshot.data!.data();
          final vanId = (childData?['vanId'] as String?)?.trim();

          if (vanId == null || vanId.isEmpty) {
            return const Center(
              child: Text('No vehicle assigned to this child yet.'),
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('vehicles')
                .doc(vanId)
                .snapshots(),
            builder: (context, vehicleSnapshot) {
              if (vehicleSnapshot.hasError) {
                return Center(child: Text('Error: ${vehicleSnapshot.error}'));
              }
              if (!vehicleSnapshot.hasData || !vehicleSnapshot.data!.exists) {
                return const Center(child: Text('Vehicle data not found.'));
              }

              final vehicleData = vehicleSnapshot.data!.data();
              final drivers = (vehicleData?['drivers'] as List<dynamic>?) ?? [];

              if (drivers.isEmpty) {
                return const Center(
                  child: Text('No driver assigned to the vehicle yet.'),
                );
              }

              final firstDriver = drivers.firstWhere(
                (item) => item is Map && item['uid'] != null,
                orElse: () => null,
              );

              if (firstDriver == null || firstDriver is! Map<String, dynamic>) {
                return const Center(
                  child: Text('Driver information is not available.'),
                );
              }

              final driverUid = (firstDriver['uid'] as String?)?.trim();
              final driverName =
                  (firstDriver['name'] as String?)?.trim() ?? 'Unknown Driver';

              if (driverUid == null || driverUid.isEmpty) {
                return const Center(
                  child: Text('Driver UID is missing in vehicle data.'),
                );
              }

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(driverUid)
                    .snapshots(),
                builder: (context, driverSnapshot) {
                  if (driverSnapshot.hasError) {
                    return Center(
                      child: Text('Error: ${driverSnapshot.error}'),
                    );
                  }
                  if (!driverSnapshot.hasData || !driverSnapshot.data!.exists) {
                    return const Center(
                      child: Text('Driver account not found.'),
                    );
                  }

                  final driverData = driverSnapshot.data!.data();
                  final driverLocation = _getDriverLocationFromDocument(
                    driverData,
                    vehicleData,
                  );
                  final marker = Marker(
                    markerId: const MarkerId('driverLocation'),
                    position: driverLocation,
                    infoWindow: InfoWindow(
                      title: driverName,
                      snippet:
                          'Vehicle: ${vehicleData?['registerNumber'] ?? vanId}',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    ),
                  );

                  final CameraPosition cameraPosition = CameraPosition(
                    target: driverLocation,
                    zoom: 15,
                  );

                  return Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: cameraPosition,
                        markers: {marker},
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        zoomControlsEnabled: true,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 16,
                        child: Card(
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Text(
                              'Tracking driver: $driverName\nVehicle code: ${vehicleData?['code'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
