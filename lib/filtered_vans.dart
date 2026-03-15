import 'package:flutter/material.dart';

class FilteredVansPage extends StatelessWidget {
  final String childId;
  final String childName;

  const FilteredVansPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00B894),
        title: const Text('Select Van', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(child: Text('Van filtering coming soon')),
    );
  }
}