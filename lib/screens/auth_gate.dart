import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../navigation/bottom_navigation.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

/// Persistent authentication gate that monitors auth state.
/// Directs signed-in users to [BottomNavigationScreen] and signed-out users
/// to [LoginScreen], displaying a clean branded loading state while resolving.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // While checking auth status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.accessible,
                    size: 64,
                    color: Color(0xFF1976D2),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'AccessLink',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // If user is signed in, present bottom navigation screen
        if (snapshot.hasData && snapshot.data != null) {
          return const BottomNavigationScreen();
        }

        // Otherwise present login screen
        return const LoginScreen();
      },
    );
  }
}
