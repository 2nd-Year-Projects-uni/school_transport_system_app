import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  final String childId;
  final String childName;

  const DashboardPage({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Text(
          widget.childName,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          "Dashboard for ${widget.childName}\nChild ID: ${widget.childId}",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
