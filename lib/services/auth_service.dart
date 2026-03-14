import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AuthService {
  Future<void> resetPassword({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .set({'email': email.trim(), 'userType': 'parent'});
    return userCredential;
  }

  Future<UserCredential> signUpDriver({
    required String name,
    required String email,
    required String phone,
    required String password,
    required XFile licenseFront,
    required XFile licenseBack,
  }) async {
    // 1. Register user
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final uid = userCredential.user!.uid;

    // 2. Upload images to Firebase Storage
    final storage = FirebaseStorage.instance;
    final frontRef = storage.ref().child('drivers/$uid/license_front.jpg');
    final backRef = storage.ref().child('drivers/$uid/license_back.jpg');
    final frontTask = await frontRef.putData(await licenseFront.readAsBytes());
    final backTask = await backRef.putData(await licenseBack.readAsBytes());
    final frontUrl = await frontTask.ref.getDownloadURL();
    final backUrl = await backTask.ref.getDownloadURL();

    // 3. Save user info in Firestore
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'userType': 'driver',
      'licenseFrontUrl': frontUrl,
      'licenseBackUrl': backUrl,
      'approved': false, // admin approval required
      'createdAt': FieldValue.serverTimestamp(),
      'vehicleId': null, // Field for vehicle assignment
    });
    return userCredential;
  }

  Future<UserCredential> signUpVehicleOwner({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .set({
          'name': name.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'userType': 'vehicle_owner',
          'createdAt': FieldValue.serverTimestamp(),
        });

    return userCredential;
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }
}
