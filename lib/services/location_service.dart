import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const String _databaseUrl =
      'https://school-transport-system-6eb9f-default-rtdb.asia-southeast1.firebasedatabase.app';

  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  bool _isJourneyActive = false;
  String? _activeVehicleId;
  String? _driverName;
  final List<Map<String, dynamic>> _routeHistory = <Map<String, dynamic>>[];
  Position? _lastRoutePoint;
  DateTime? _lastRoutePointAt;
  static const int _maxRouteHistoryPoints = 180;
  static const double _minRoutePointDistanceMeters = 8;
  static const Duration _maxRoutePointInterval = Duration(seconds: 8);
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );

  bool get isTracking => _isTracking;
  bool get isJourneyActive => _isJourneyActive;

  void setActiveVehicle({String? vehicleId, String? driverName}) {
    _activeVehicleId = vehicleId;
    _driverName = driverName;
  }

  Future<void> publishJourneyMetadata({
    required String vehicleId,
    required Map<String, dynamic> metadata,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _activeVehicleId = vehicleId;
    _isJourneyActive = true;
    _routeHistory.clear();
    _lastRoutePoint = null;
    _lastRoutePointAt = null;
    final ref = _database.ref('liveTracking/$vehicleId');

    await ref.update({
      'vehicleId': vehicleId,
      'driverId': uid,
      'driverName': _driverName ?? '',
      ...metadata,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Future<void> markJourneyEnded() async {
    final vehicleId = _activeVehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;

    try {
      await _database.ref('liveTracking/$vehicleId').update({
        'journeyStatus': 'ended',
        'endedAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (_) {
      // Ignore cleanup failures.
    } finally {
      _isJourneyActive = false;
      _routeHistory.clear();
      _lastRoutePoint = null;
      _lastRoutePointAt = null;
    }
  }

  bool _shouldAppendRoutePoint(Position current) {
    final previous = _lastRoutePoint;
    final previousAt = _lastRoutePointAt;
    if (previous == null || previousAt == null) return true;

    final distance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );
    if (distance >= _minRoutePointDistanceMeters) return true;

    return DateTime.now().difference(previousAt) >= _maxRoutePointInterval;
  }

  void _appendRoutePoint(Position current) {
    if (!_shouldAppendRoutePoint(current)) return;

    _routeHistory.add({
      'lat': current.latitude,
      'lng': current.longitude,
      'heading': current.heading.isFinite
          ? double.parse(current.heading.toStringAsFixed(1))
          : 0,
      'speedKmph': current.speed.isFinite
          ? double.parse(
              ((current.speed * 3.6).clamp(0, 220)).toStringAsFixed(1),
            )
          : 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    if (_routeHistory.length > _maxRouteHistoryPoints) {
      _routeHistory.removeRange(
        0,
        _routeHistory.length - _maxRouteHistoryPoints,
      );
    }

    _lastRoutePoint = current;
    _lastRoutePointAt = DateTime.now();
  }

  Future<bool> isJourneyInProgress(String vehicleId) async {
    try {
      final snapshot = await _database.ref('liveTracking/$vehicleId').get();
      final data = snapshot.value;
      if (data is! Map) return false;
      final status = data['journeyStatus']?.toString().trim().toLowerCase();
      return status == 'in_progress';
    } catch (_) {
      return false;
    }
  }

  /// Call this when driver starts their shift / opens the app
  Future<void> startTracking() async {
    if (_isTracking) return;

    // 1. Check & request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable in settings.',
      );
    }

    _isTracking = true;

    // Upload one immediate fix, then consume live stream for low-latency updates.
    await _uploadLocation();
    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
        ).listen(
          (position) async {
            await _uploadLocation(position: position);
          },
          onError: (_) {
            // Keep service alive even if stream emits intermittent errors.
          },
        );
  }

  /// Call this when driver ends shift or logs out
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;

    // Optional: clear location so parents see no stale marker
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'currentLocation': FieldValue.delete(),
      });

      if (_isJourneyActive &&
          _activeVehicleId != null &&
          _activeVehicleId!.isNotEmpty) {
        try {
          await _database.ref('liveTracking/${_activeVehicleId!}').update({
            'journeyStatus': 'paused',
            'updatedAt': ServerValue.timestamp,
          });
        } catch (_) {
          // Ignore RTDB cleanup failures.
        }
      }

      _isJourneyActive = false;
      _routeHistory.clear();
      _lastRoutePoint = null;
      _lastRoutePointAt = null;
    }
  }

  Future<void> _uploadLocation({Position? position}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final currentPosition =
          position ??
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
          );

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'currentLocation': GeoPoint(
            currentPosition.latitude,
            currentPosition.longitude,
          ),
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true), // won't overwrite other fields
      );

      final vehicleId = _activeVehicleId;
      if (_isJourneyActive && vehicleId != null && vehicleId.isNotEmpty) {
        _appendRoutePoint(currentPosition);
        final speedKmph = currentPosition.speed.isFinite
            ? (currentPosition.speed * 3.6).clamp(0, 220)
            : 0;
        await _database.ref('liveTracking/$vehicleId').update({
          'vehicleId': vehicleId,
          'driverId': uid,
          'driverName': _driverName ?? '',
          'lat': currentPosition.latitude,
          'lng': currentPosition.longitude,
          'speedKmph': double.parse(speedKmph.toStringAsFixed(1)),
          'heading': currentPosition.heading.isFinite
              ? double.parse(currentPosition.heading.toStringAsFixed(1))
              : 0,
          'routeHistory': _routeHistory,
          'journeyStatus': 'in_progress',
          'updatedAt': ServerValue.timestamp,
        });
      }
    } catch (e) {
      // silently fail — don't crash driver app if GPS blips
      print('Location upload error: $e');
    }
  }
}
