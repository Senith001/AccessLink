import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const AccessLinkApp());
}

class AccessLinkApp extends StatelessWidget {
  const AccessLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AccessLink',
      home: const LoginScreen(),
    );
  }
}