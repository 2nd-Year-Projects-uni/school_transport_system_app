import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddAdminsPage extends StatefulWidget {
  @override
  _AddAdminsPageState createState() => _AddAdminsPageState();
}

class _AddAdminsPageState extends State<AddAdminsPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();

  final Color navy = Color(0xFF001F3F);
  final Color teal = Color(0xFF00B894);
  final Color bg = Color(0xFFF6F9FC);

  bool isLoading = false;

  //  ADD ADMIN FUNCTION
  Future<void> addAdmin() async {
    String name = nameController.text.trim();
    String email = emailController.text.trim();

    // validation
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      //  Save to Firestore
      await FirebaseFirestore.instance.collection('admins').add({
        'name': name,
        'email': email,
        'created_at': Timestamp.now(),
      });

      //  Success message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Admin Added Successfully")));

      //  Go back to dashboard
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,

      appBar: AppBar(
        title: Text("Add Admin", style: TextStyle(color: Colors.white)),
        backgroundColor: navy,
        iconTheme: IconThemeData(color: Colors.white),
      ),

      body: Center(
        child: Container(
          width: 400,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: teal),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              //  NAME
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Admin Name"),
              ),

              SizedBox(height: 10),

              //  EMAIL
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: "Admin Email"),
              ),

              SizedBox(height: 20),

              //  BUTTON
              isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: addAdmin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal,
                        padding: EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                      ),
                      child: Text("Add Admin"),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
