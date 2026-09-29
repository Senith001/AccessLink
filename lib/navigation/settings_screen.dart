import 'package:flutter/material.dart';
import '../screens/logout_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LogoutScreen()),
          ),
          child: const Text('Log out'),
        ),
      ),
    );
  }
}
