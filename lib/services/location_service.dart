import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static const String _databaseUrl =
      'https://school-transport-system-6eb9f-default-rtdb.asia-southeast1.firebasedatabase.app';

  Timer? _timer;
  bool _isTracking = false;
  bool _isJourneyActive = false;
  String? _activeVehicleId;
  String? _driverName;
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
    }
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

    // Upload immediately, then at a short interval for smoother live tracking.
    await _uploadLocation();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _uploadLocation();
    });
  }

  /// Call this when driver ends shift or logs out
  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
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
    }
  }

  Future<void> _uploadLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'currentLocation': GeoPoint(position.latitude, position.longitude),
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true), // won't overwrite other fields
      );

      final vehicleId = _activeVehicleId;
      if (_isJourneyActive && vehicleId != null && vehicleId.isNotEmpty) {
        final speedKmph = position.speed.isFinite
            ? (position.speed * 3.6).clamp(0, 220)
            : 0;
        await _database.ref('liveTracking/$vehicleId').update({
          'vehicleId': vehicleId,
          'driverId': uid,
          'driverName': _driverName ?? '',
          'lat': position.latitude,
          'lng': position.longitude,
          'speedKmph': double.parse(speedKmph.toStringAsFixed(1)),
          'heading': position.heading.isFinite
              ? double.parse(position.heading.toStringAsFixed(1))
              : 0,
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
