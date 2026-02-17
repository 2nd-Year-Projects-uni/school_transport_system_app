import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddChildPage extends StatefulWidget {
  const AddChildPage({super.key});

  @override
  State<AddChildPage> createState() => _AddChildPageState();
}

class _AddChildPageState extends State<AddChildPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController dropoffController = TextEditingController();

  bool loading = false;

  final String parentId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> saveStudent() async {
    if (nameController.text.isEmpty ||
        pickupController.text.isEmpty ||
        dropoffController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance.collection('Students').add({
        'name': nameController.text.trim(),
        'pickupLocation': pickupController.text.trim(),
        'dropoffLocation': dropoffController.text.trim(),
        'parentId': parentId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add student")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors from LoginPage
    final Color navy = const Color(0xFF001F3F);
    final Color blue = const Color(0xFF005792);
    final Color teal = const Color(0xFF00B894);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: teal,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Add Student",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // School bus/minimal icon
                Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: teal.withOpacity(0.12),
                    child: Icon(
                      Icons.school_outlined,
                      color: teal,
                      size: 32,
                    ),
                  ),
                ),
                
                // Headline
                Text(
                  'Add New Student',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: navy,
                    letterSpacing: 0.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Subtitle
                Text(
                  'Enter your child\'s details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: blue.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 30),

                // Student Name Field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.person_outline, color: blue),
                    labelText: 'Student Name',
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

                // Pickup Location Field
                TextField(
                  controller: pickupController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined, color: blue),
                    labelText: 'Pickup Location',
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

                // Drop-off Location Field
                TextField(
                  controller: dropoffController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.location_city_outlined, color: blue),
                    labelText: 'Drop-off Location',
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
                const SizedBox(height: 30),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: loading ? null : saveStudent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 6,
                      shadowColor: navy.withOpacity(0.18),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          )
                        : const Text(
                            "Save Student",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}