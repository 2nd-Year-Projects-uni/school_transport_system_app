import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Timer? _timer;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

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
      throw Exception('Location permission permanently denied. Enable in settings.');
    }

    _isTracking = true;

    // 2. Upload immediately, then every 10 seconds
    await _uploadLocation();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) async {
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'currentLocation': FieldValue.delete()});
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
    } catch (e) {
      // silently fail — don't crash driver app if GPS blips
      print('Location upload error: $e');
    }
  }
}