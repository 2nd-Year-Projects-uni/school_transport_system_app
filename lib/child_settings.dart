import 'package:flutter/material.dart';

class ChildSettingsPage extends StatelessWidget {
  final String childId;
  final String childName;

  const ChildSettingsPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00B894),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(child: Text('Settings coming soon')),
    );
  }
}