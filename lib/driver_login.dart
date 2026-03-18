import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'services/auth_service.dart';
import 'driver_home.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Color scheme (copied from login/signup pages)
final Color navy = const Color(0xFF001F3F);
final Color blue = const Color(0xFF005792);
final Color teal = const Color(0xFF00B894);
final Color subtitleColor = blue.withOpacity(0.7);

class DriverLoginPage extends StatefulWidget {
  @override
  _DriverLoginPageState createState() => _DriverLoginPageState();
}

class _DriverLoginPageState extends State<DriverLoginPage>
    with SingleTickerProviderStateMixin {
  void _showForgotPasswordDialog() {
    final TextEditingController _emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Enter your email'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final email = _emailController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter your email.')),
                  );
                  return;
                }
                try {
                  await _authService.resetPassword(email: email);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset email sent!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  bool _registerObscurePassword = true;
  bool _loginObscurePassword = true;
  late TabController _tabController;

  // Registration controllers
  final TextEditingController _regNameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPhoneController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();
  XFile? _licenseFront;
  XFile? _licenseBack;

  // Login controllers
  final TextEditingController _loginEmailPhoneController =
      TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();
  bool _isRegisterLoading = false;
  bool _isLoginLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    _loginEmailPhoneController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickLicenseImage(bool isFront) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        if (isFront) {
          _licenseFront = pickedFile;
        } else {
          _licenseBack = pickedFile;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Driver',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Register'),
            Tab(text: 'Login'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _buildRegisterTab(context),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _buildLoginTab(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Text(
          'Register as Driver',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: navy,
            letterSpacing: 0.2,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        // Full Name
        TextField(
          controller: _regNameController,
          keyboardType: TextInputType.name,
          decoration: _inputDecoration('Full Name', Icons.person_outline),
        ),
        const SizedBox(height: 16),
        // Email
        TextField(
          controller: _regEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDecoration('Email', Icons.email_outlined),
        ),
        const SizedBox(height: 16),
        // Phone
        TextField(
          controller: _regPhoneController,
          keyboardType: TextInputType.phone,
          decoration: _inputDecoration('Phone Number', Icons.phone_outlined),
        ),
        const SizedBox(height: 16),
        // Password
        TextField(
          controller: _regPasswordController,
          obscureText: _registerObscurePassword,
          decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _registerObscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: blue,
              ),
              onPressed: () {
                setState(() {
                  _registerObscurePassword = !_registerObscurePassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        // License upload
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Upload Driver License Photos',
            style: TextStyle(
              color: blue,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _licenseFront == null ? blue : teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _pickLicenseImage(true),
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _licenseFront == null ? 'Front Side' : 'Front Uploaded',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _licenseBack == null ? blue : teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _pickLicenseImage(false),
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _licenseBack == null ? 'Back Side' : 'Back Uploaded',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.yellow[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'For the safety of children, we require photos of your driver’s license. All registrations are reviewed and approved by an admin before you can log in.',
                  style: TextStyle(fontSize: 14, color: navy),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 6,
              shadowColor: navy.withOpacity(0.18),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: _isRegisterLoading ? null : _registerDriver,
            child: _isRegisterLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Text('Register', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Future<void> _registerDriver() async {
    setState(() => _isRegisterLoading = true);
    String name = _regNameController.text.trim();
    String email = _regEmailController.text.trim();
    String phone = _regPhoneController.text.trim();
    String password = _regPasswordController.text;
    // Validations
    String? error;
    if (name.isEmpty ||
        name.length < 3 ||
        !RegExp(r'^[a-zA-Z ]+$').hasMatch(name)) {
      error = 'Enter a valid name (min 3 letters).';
    } else if (email.isEmpty ||
        !RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      error = 'Enter a valid email.';
    } else if (phone.isEmpty || !RegExp(r'^\d{10}$').hasMatch(phone)) {
      error = 'Phone must be exactly 10 digits.';
    } else if (password.length < 6 ||
        !RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{6,}$').hasMatch(password)) {
      error =
          'Password must be at least 6 characters, include a letter and a number.';
    } else if (_licenseFront == null || _licenseBack == null) {
      error = 'Please upload both license images.';
    }
    if (error != null) {
      setState(() => _isRegisterLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    try {
      await _authService.signUpDriver(
        name: name,
        email: email,
        phone: phone,
        password: password,
        licenseFront: _licenseFront!,
        licenseBack: _licenseBack!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration submitted! Await admin approval.'),
        ),
      );
      _tabController.animateTo(1);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed:  ')));
    } finally {
      if (mounted) setState(() => _isRegisterLoading = false);
    }
  }

  Widget _buildLoginTab(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Driver Login',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: navy,
              letterSpacing: 0.2,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _loginEmailPhoneController,
          decoration: _inputDecoration(
            'Email or Phone Number',
            Icons.person_outline,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _loginPasswordController,
          obscureText: _loginObscurePassword,
          decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _loginObscurePassword ? Icons.visibility_off : Icons.visibility,
                color: blue,
              ),
              onPressed: () {
                setState(() {
                  _loginObscurePassword = !_loginObscurePassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: Color(0xFF005792), // blue
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.yellow[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Note: You can only log in after your registration has been approved by the admin. Please be patient while we review your details. You will be notified once your account is activated.',
                  style: TextStyle(fontSize: 14, color: navy),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 6,
              shadowColor: navy.withOpacity(0.18),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: _isLoginLoading ? null : _loginDriver,
            child: _isLoginLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Text('Login', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: blue),
      labelText: label,
      labelStyle: TextStyle(color: blue),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: blue, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: blue.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: navy, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    );
  }

  Future<void> _loginDriver() async {
    setState(() => _isLoginLoading = true);
    String email = _loginEmailPhoneController.text.trim();
    String password = _loginPasswordController.text;
    String? error;
    if (email.isEmpty ||
        !RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      error = 'Enter a valid email.';
    } else if (password.isEmpty) {
      error = 'Enter your password.';
    }
    if (error != null) {
      setState(() => _isLoginLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    try {
      UserCredential cred = await _authService.login(
        email: email,
        password: password,
      );
      // Check if driver is approved
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();
      if (!doc.exists || doc['userType'] != 'driver') {
        throw Exception('No driver account found.');
      }
      if (doc['approved'] != true) {
        throw Exception('Your registration is still pending admin approval.');
      }
      // TODO: Navigate to driver dashboard/home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DriverHomePage()),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login successful!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed:  ')));
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
    }
  }
}
