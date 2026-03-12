import 'package:flutter/material.dart';

class DriverInfoPage extends StatelessWidget {
  final String childId;
  final String childName;

  const DriverInfoPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00B894),
        title: const Text('Driver Info', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(child: Text('Driver info coming soon')),
    );
  }
}