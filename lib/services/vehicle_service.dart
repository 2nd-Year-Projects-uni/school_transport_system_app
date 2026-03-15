import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class VehicleService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> vehicleStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('vehicles')
        .where('ownerId', isEqualTo: user.uid)
        .snapshots();
  }

  Future<String> registerVehicle({
    required String registerNumber,
    required String vehicleType,
    required String condition,
    required DateTime insuranceExpiryDate,
    required Map<String, dynamic> startingLocation,
    required List<Map<String, dynamic>> schools,
    required XFile vehiclePhoto,
    List<Map<String, dynamic>>? routePoints,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated vehicle owner found.');
    }

    final String code = await _generateUniqueVehicleCode();

    final vehicleRef = _firestore.collection('vehicles').doc();
    final imageRef = _storage.ref().child(
      'vehicle_owners/${user.uid}/vehicles/${vehicleRef.id}.jpg',
    );
    final uploadTask = await imageRef.putData(await vehiclePhoto.readAsBytes());
    final photoUrl = await uploadTask.ref.getDownloadURL();

    await vehicleRef.set({
      'ownerId': user.uid,
      'registerNumber': registerNumber.trim().toUpperCase(),
      'vehicleType': vehicleType.trim(),
      'condition': condition,
      'insuranceExpiryDate': Timestamp.fromDate(insuranceExpiryDate),
      'startingLocation': startingLocation,
      'schools': schools,
      'routePoints': routePoints ?? [],
      'vehiclePhotoUrl': photoUrl,
      'status': false,
      'createdAt': FieldValue.serverTimestamp(),
      'code': code,
      'drivers': <Map<String, dynamic>>[],
    });

    return vehicleRef.id;
  }

  Future<String> _generateUniqueVehicleCode({int length = 4}) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    final vehicles = _firestore.collection('vehicles');
    String code;
    bool exists = true;
    do {
      code = List.generate(
        length,
        (index) => chars[rand.nextInt(chars.length)],
      ).join();
      final query = await vehicles
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      exists = query.docs.isNotEmpty;
    } while (exists);
    return code;
  }
}
