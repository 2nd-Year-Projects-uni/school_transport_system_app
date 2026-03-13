import 'package:flutter/material.dart';

class PayPage extends StatelessWidget {
  final String childId;
  final String childName;

  const PayPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00B894),
        title: const Text('Payment', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(child: Text('Payment coming soon')),
    );
  }
}