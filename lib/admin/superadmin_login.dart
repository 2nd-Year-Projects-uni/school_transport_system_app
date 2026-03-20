import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'superadmin_dashboard.dart';

class SuperAdminLogin extends StatefulWidget {
  @override
  _SuperAdminLoginState createState() => _SuperAdminLoginState();
}

class _SuperAdminLoginState extends State<SuperAdminLogin> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> loginSuperAdmin() async {
    try {
      UserCredential user = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      var doc = await FirebaseFirestore.instance
          .collection('superadmins')
          .doc(user.user!.uid)
          .get();

      if (doc.exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SuperAdminDashboard()),
        );
      } else {
        await FirebaseAuth.instance.signOut();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Access Denied")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 350,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Super Admin Login",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),

              SizedBox(height: 20),

              TextField(
                controller: emailController,
                decoration: InputDecoration(hintText: "Email", filled: true),
              ),

              SizedBox(height: 10),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(hintText: "Password", filled: true),
              ),

              SizedBox(height: 20),

              ElevatedButton(onPressed: loginSuperAdmin, child: Text("Login")),
            ],
          ),
        ),
      ),
    );
  }
}
