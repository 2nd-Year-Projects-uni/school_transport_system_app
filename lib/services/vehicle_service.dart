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
        .collection('users')
        .doc(user.uid)
        .collection('vehicles')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> registerVehicle({
    required String registerNumber,
    required String vehicleType,
    required String condition,
    required DateTime insuranceExpiryDate,
    required String startingLocation,
    required List<String> schools,
    required XFile vehiclePhoto,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated vehicle owner found.');
    }

    final vehicleRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vehicles')
        .doc();

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
      'startingLocation': startingLocation.trim(),
      'schools': schools,
      'vehiclePhotoUrl': photoUrl,
      'status': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return vehicleRef.id;
  }
}
