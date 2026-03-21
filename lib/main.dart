import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'welcome_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ride Safe',
      debugShowCheckedModeBanner: false,
      home: const WelcomePage(),
    );
  }
}
