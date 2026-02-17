import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'home_screen.dart';
import 'widgets/loading_button.dart';
import 'login.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> signUp() async {
    setState(() => isLoading = true);
    try {
      await _authService.signUp(
        email: emailController.text,
        password: passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Sign up failed';
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Email already in use.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'weak-password':
          message = 'Password is too weak.';
          break;
        default:
          message = e.message ?? message;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color offWhite = const Color(0xFFF6F7FB);
    final Color navy = const Color(0xFF001F3F);
    final Color blue = const Color(0xFF005792);
    final Color teal = const Color(0xFF00B894);
    final Color subtitleColor = blue.withOpacity(0.7);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Back button at the very top left
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 8.0),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: navy, size: 28),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
                tooltip: 'Back to Login',
              ),
            ),
          ),
          // Main content centered
          Center(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    // Headline
                    Text(
                      'Create Your Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: navy,
                        letterSpacing: 0.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Full Name Field
                    TextField(
                      controller: fullNameController,
                      keyboardType: TextInputType.name,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_outline, color: blue),
                        labelText: 'Full Name',
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
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Contact Number Field
                    TextField(
                      controller: contactController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.phone_outlined, color: blue),
                        labelText: 'Contact Number',
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
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Email Field
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined, color: blue),
                        labelText: 'Email',
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
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Password Field
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline, color: blue),
                        labelText: 'Password',
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
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: blue,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Signup Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: LoadingButton(
                        isLoading: isLoading,
                        text: 'Sign Up',
                        enabled: !isLoading,
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
                        onPressed: signUp,
                        childOverride: isLoading
                            ? null
                            : const Text(
                                'Sign Up',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
