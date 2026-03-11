import 'package:flutter/material.dart';

class VehicleOwnerHomePage extends StatelessWidget {
  const VehicleOwnerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Owner Home')),
      body: const Center(
        child: Text(
          'Welcome to the Vehicle Owner Home Page!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
