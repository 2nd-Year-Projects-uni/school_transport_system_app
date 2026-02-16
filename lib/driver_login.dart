import 'package:flutter/material.dart';

class DriverLoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Login'),
      ),
      body: Center(
        child: Text(
          'Driver Login Page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
