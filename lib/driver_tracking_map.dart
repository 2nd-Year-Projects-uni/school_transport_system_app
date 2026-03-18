import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  static const String _databaseUrl =
      'https://school-transport-system-6eb9f-default-rtdb.asia-southeast1.firebasedatabase.app';

  static const Color navy = Color(0xFF001F3F);
  static const Color blue = Color(0xFF005792);
  static const Color teal = Color(0xFF00B894);

  GoogleMapController? _mapController;
  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612); // Colombo
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );

  DateTime? _lastCameraMoveAt;
  bool _hasCenteredOnLivePoint = false;
  LatLng? _displayDriverLocation;
  LatLng? _targetDriverLocation;
  Timer? _smoothingTimer;

  static const Duration _smoothingTick = Duration(milliseconds: 120);
  static const double _smoothingFactor = 0.28;
  static const double _snapThreshold = 0.00002;
  static const double _headingMovementThreshold = 0.00001;
  static const double _headingSmoothingFactor = 0.22;
  static const double _headingSnapThreshold = 1.5;
  BitmapDescriptor _driverMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );
  double _driverHeading = 0;
  double _targetDriverHeading = 0;

  @override
  void initState() {
    super.initState();
    _loadDriverMarkerIcon();
  }

  Future<void> _loadDriverMarkerIcon() async {
    final icon = await _createBusMarkerIcon();
    if (!mounted) return;
    setState(() {
      _driverMarkerIcon = icon;
    });
  }

  Future<BitmapDescriptor> _createBusMarkerIcon() async {
    try {
      const double size = 120;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = const Offset(size / 2, size / 2);

      final bgPaint = Paint()..color = blue;
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8;

      canvas.drawCircle(center, size * 0.40, bgPaint);
      canvas.drawCircle(center, size * 0.40, borderPaint);

      final iconData = Icons.directions_bus_rounded;
      final textPainter = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: 64,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            color: Colors.white,
          ),
        )
        ..layout();

      textPainter.paint(
        canvas,
        Offset(
          center.dx - (textPainter.width / 2),
          center.dy - (textPainter.height / 2),
        ),
      );

      final image = await recorder.endRecording().toImage(
        size.toInt(),
        size.toInt(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();

      if (bytes == null || bytes.isEmpty) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      }

      return BitmapDescriptor.fromBytes(bytes);
    } catch (_) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  @override
  void dispose() {
    _smoothingTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    final result = <String, dynamic>{};
    value.forEach((key, val) {
      result[key.toString()] = val;
    });
    return result;
  }

  LatLng? _toLatLng(dynamic value) {
    if (value is GeoPoint) {
      return LatLng(value.latitude, value.longitude);
    }
    if (value is Map) {
      final map = _asMap(value);
      final lat =
          (map['latitude'] as num?)?.toDouble() ??
          (map['lat'] as num?)?.toDouble();
      final lng =
          (map['longitude'] as num?)?.toDouble() ??
          (map['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return null;
  }

  List<LatLng> _extractRoutePoints(dynamic rawRoute) {
    final route = rawRoute as List<dynamic>? ?? const <dynamic>[];
    final points = <LatLng>[];
    for (final point in route) {
      final latLng = _toLatLng(point);
      if (latLng != null) points.add(latLng);
    }
    return points;
  }

  String _statusLabel(String rawStatus, bool isStale) {
    final normalized = rawStatus.trim().toLowerCase();
    if (isStale && normalized == 'in_progress') {
      return 'Connection lost';
    }
    switch (normalized) {
      case 'in_progress':
        return 'On route';
      case 'paused':
        return 'Paused';
      case 'ended':
        return 'Journey ended';
      default:
        return 'Waiting';
    }
  }

  Color _statusColor(String rawStatus, bool isStale) {
    if (isStale) return const Color(0xFFD00000);
    switch (rawStatus.trim().toLowerCase()) {
      case 'in_progress':
        return teal;
      case 'paused':
        return const Color(0xFFFF8F00);
      case 'ended':
        return const Color(0xFF6C757D);
      default:
        return blue;
    }
  }

  String _formatLastUpdated(int? updatedAtMs) {
    if (updatedAtMs == null || updatedAtMs <= 0) return 'No updates yet';
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
    final seconds = DateTime.now().difference(updatedAt).inSeconds;
    if (seconds < 5) return 'Updated just now';
    if (seconds < 60) return 'Updated ${seconds}s ago';
    final minutes = DateTime.now().difference(updatedAt).inMinutes;
    return 'Updated ${minutes}m ago';
  }

  bool _isConnectionStale(int? updatedAtMs) {
    if (updatedAtMs == null || updatedAtMs <= 0) return true;
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
    return DateTime.now().difference(updatedAt).inSeconds > 20;
  }

  double _distanceAbs(LatLng a, LatLng b) {
    final latDiff = (a.latitude - b.latitude).abs();
    final lngDiff = (a.longitude - b.longitude).abs();
    return latDiff + lngDiff;
  }

  double _normalizeHeading(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearingDeg = math.atan2(y, x) * 180 / math.pi;
    return _normalizeHeading(bearingDeg);
  }

  double _shortestHeadingDelta(double from, double to) {
    return ((to - from + 540) % 360) - 180;
  }

  double _lerpHeading(double from, double to, double t) {
    final delta = _shortestHeadingDelta(from, to);
    return _normalizeHeading(from + (delta * t));
  }

  LatLng _lerpLatLng(LatLng from, LatLng to, double t) {
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  LatLng _consumeIncomingDriverLocation(LatLng incoming, {double? heading}) {
    final explicitHeading = heading == null ? null : _normalizeHeading(heading);

    if (_displayDriverLocation == null) {
      _displayDriverLocation = incoming;
      _targetDriverLocation = incoming;
      if (explicitHeading != null) {
        _driverHeading = explicitHeading;
        _targetDriverHeading = explicitHeading;
      }
      return incoming;
    }

    final previous = _targetDriverLocation ?? _displayDriverLocation!;
    if (explicitHeading != null) {
      _targetDriverHeading = explicitHeading;
    } else if (_distanceAbs(previous, incoming) >= _headingMovementThreshold) {
      _targetDriverHeading = _bearingBetween(previous, incoming);
    }

    _targetDriverLocation = incoming;
    _ensureSmoothingTimer();
    return _displayDriverLocation!;
  }

  void _ensureSmoothingTimer() {
    if (_smoothingTimer != null) return;
    _smoothingTimer = Timer.periodic(_smoothingTick, (_) {
      final current = _displayDriverLocation;
      final target = _targetDriverLocation;
      if (!mounted || current == null || target == null) {
        _smoothingTimer?.cancel();
        _smoothingTimer = null;
        return;
      }

      final distance = _distanceAbs(current, target);
      final headingDelta = _shortestHeadingDelta(
        _driverHeading,
        _targetDriverHeading,
      ).abs();

      if (distance <= _snapThreshold && headingDelta <= _headingSnapThreshold) {
        setState(() {
          _displayDriverLocation = target;
          _driverHeading = _targetDriverHeading;
        });
        _smoothingTimer?.cancel();
        _smoothingTimer = null;
        return;
      }

      setState(() {
        if (distance <= _snapThreshold) {
          _displayDriverLocation = target;
        } else {
          _displayDriverLocation = _lerpLatLng(
            current,
            target,
            _smoothingFactor,
          );
        }

        if (headingDelta <= _headingSnapThreshold) {
          _driverHeading = _targetDriverHeading;
        } else {
          _driverHeading = _lerpHeading(
            _driverHeading,
            _targetDriverHeading,
            _headingSmoothingFactor,
          );
        }
      });
    });
  }

  void _moveCameraIfNeeded(LatLng location) {
    if (_mapController == null) return;
    final now = DateTime.now();
    final shouldMove =
        !_hasCenteredOnLivePoint ||
        _lastCameraMoveAt == null ||
        now.difference(_lastCameraMoveAt!).inSeconds >= 10;

    if (!shouldMove) return;

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 15),
      ),
    );
    _lastCameraMoveAt = now;
    _hasCenteredOnLivePoint = true;
  }

  Widget _buildMessage(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: navy,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String driverName,
    required String vehicleLabel,
    required String status,
    required Color statusColor,
    required String speedLabel,
    required String updateLabel,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Driver: $driverName',
              style: const TextStyle(color: navy, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              'Vehicle: $vehicleLabel',
              style: TextStyle(
                color: navy.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Speed: $speedLabel',
              style: TextStyle(
                color: navy.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              updateLabel,
              style: TextStyle(
                color: navy.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers({
    required LatLng driverLocation,
    required double driverHeading,
    required String driverName,
    required String vehicleLabel,
    required LatLng? pickupLocation,
    required LatLng? destination,
    required String destinationLabel,
  }) {
    return {
      Marker(
        markerId: const MarkerId('driverLocation'),
        position: driverLocation,
        infoWindow: InfoWindow(
          title: driverName,
          snippet: 'Vehicle: $vehicleLabel',
        ),
        icon: _driverMarkerIcon,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        rotation: driverHeading,
      ),
      if (pickupLocation != null)
        Marker(
          markerId: const MarkerId('childPickup'),
          position: pickupLocation,
          infoWindow: const InfoWindow(title: 'Child pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      if (destination != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          infoWindow: InfoWindow(title: destinationLabel),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
    };
  }

  Polyline? _buildRoutePolyline(List<LatLng> routePoints) {
    if (routePoints.length < 2) return null;
    return Polyline(
      polylineId: const PolylineId('liveRoute'),
      points: routePoints,
      width: 5,
      color: blue,
      geodesic: true,
    );
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
            return _buildMessage('Unable to load child data.');
          }
          if (!childSnapshot.hasData || !childSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final childData = childSnapshot.data!.data();
          final vanId = (childData?['vanId'] as String?)?.trim();
          final pickupLocation = _toLatLng(childData?['pickupLocation']);

          if (vanId == null || vanId.isEmpty) {
            return _buildMessage('No vehicle assigned to this child yet.');
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('vehicles')
                .doc(vanId)
                .snapshots(),
            builder: (context, vehicleSnapshot) {
              if (vehicleSnapshot.hasError) {
                return _buildMessage('Unable to load vehicle details.');
              }
              if (!vehicleSnapshot.hasData || !vehicleSnapshot.data!.exists) {
                return _buildMessage('Vehicle data not found.');
              }

              final vehicleData = vehicleSnapshot.data!.data();
              final vehicleLabel =
                  (vehicleData?['registerNumber'] as String?)
                          ?.trim()
                          .isNotEmpty ==
                      true
                  ? (vehicleData!['registerNumber'] as String).trim()
                  : vanId;
              final startingLocation = _toLatLng(
                vehicleData?['startingLocation'],
              );

              return StreamBuilder<DatabaseEvent>(
                stream: _database.ref('liveTracking/$vanId').onValue,
                builder: (context, trackingSnapshot) {
                  final rawTracking = trackingSnapshot.data?.snapshot.value;
                  final trackingData = _asMap(rawTracking);

                  final liveLat = (trackingData['lat'] as num?)?.toDouble();
                  final liveLng = (trackingData['lng'] as num?)?.toDouble();
                  final rawDriverLocation = (liveLat != null && liveLng != null)
                      ? LatLng(liveLat, liveLng)
                      : (startingLocation ??
                            pickupLocation ??
                            _defaultLocation);
                  final headingRaw =
                      (trackingData['heading'] as num?)?.toDouble() ??
                      (trackingData['bearing'] as num?)?.toDouble() ??
                      (trackingData['course'] as num?)?.toDouble();
                  final driverLocation = _consumeIncomingDriverLocation(
                    rawDriverLocation,
                    heading: headingRaw,
                  );

                  final destinationMap = _asMap(trackingData['destination']);
                  final destination = _toLatLng(destinationMap);
                  final destinationLabel =
                      (destinationMap['label'] as String?)?.trim().isNotEmpty ==
                          true
                      ? (destinationMap['label'] as String).trim()
                      : 'Destination';

                  final routePoints = _extractRoutePoints(
                    trackingData['routeSnapshot'],
                  );
                  final routePolyline = _buildRoutePolyline(routePoints);
                  final routePolylines = routePolyline == null
                      ? <Polyline>{}
                      : <Polyline>{routePolyline};

                  final driverName =
                      (trackingData['driverName'] as String?)
                              ?.trim()
                              .isNotEmpty ==
                          true
                      ? (trackingData['driverName'] as String).trim()
                      : 'Driver';
                  final statusRaw =
                      (trackingData['journeyStatus'] as String?)?.trim() ??
                      'waiting';
                  final updatedAtMs = (trackingData['updatedAt'] as num?)
                      ?.toInt();
                  final isStale = _isConnectionStale(updatedAtMs);
                  final statusLabel = _statusLabel(statusRaw, isStale);
                  final statusColor = _statusColor(statusRaw, isStale);
                  final speed = (trackingData['speedKmph'] as num?)?.toDouble();
                  final speedLabel = speed == null
                      ? 'N/A'
                      : '${speed.toStringAsFixed(1)} km/h';
                  final updateLabel = _formatLastUpdated(updatedAtMs);

                  _moveCameraIfNeeded(driverLocation);

                  return Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: driverLocation,
                          zoom: 14,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        markers: _buildMarkers(
                          driverLocation: driverLocation,
                          driverHeading: _driverHeading,
                          driverName: driverName,
                          vehicleLabel: vehicleLabel,
                          pickupLocation: pickupLocation,
                          destination: destination,
                          destinationLabel: destinationLabel,
                        ),
                        polylines: routePolylines,
                        zoomControlsEnabled: true,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 16,
                        child: _buildInfoCard(
                          driverName: driverName,
                          vehicleLabel: vehicleLabel,
                          status: statusLabel,
                          statusColor: statusColor,
                          speedLabel: speedLabel,
                          updateLabel: updateLabel,
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
