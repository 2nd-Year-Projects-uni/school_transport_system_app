import 'package:flutter/material.dart';

class DriverInterfacePage extends StatelessWidget {
  const DriverInterfacePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Interface')),
      body: const Center(child: Text('Welcome to the Driver Interface!')),
    );
  }
}
