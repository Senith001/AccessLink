import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/auth/auth_page.dart';

import '../services/auth_service.dart';
import '../navigation/bottom_navigation.dart';
import 'registration_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final _sw = Stopwatch()..start();
      await _authService.loginUser(email, password);
      debugPrint(
        'LOGIN_TIMING: signIn returned after ' +
            _sw.elapsedMilliseconds.toString() +
            'ms',
      );

      if (!mounted) return;

      _showMessage('Login successful!');

      // Navigate to the Home shell and remove login from the back stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BottomNavigationScreen()),
      );
      debugPrint(
        'LOGIN_TIMING: navigation issued at ' +
            _sw.elapsedMilliseconds.toString() +
            'ms',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('AUTH ERROR (login) code=${e.code} msg=${e.message}');
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message = 'No account found with this email.';
          break;

        case 'wrong-password':
          message = 'Incorrect password.';
          break;

        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;

        case 'network-request-failed':
          message = 'Request timed out. Check your connection and try again.';
          break;

        default:
          message = 'Login failed. Please try again.';
      }

      _showMessage(message);
    } catch (e) {
      debugPrint('AUTH UNKNOWN (login) err=$e');
      if (!mounted) return;

      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: 'Login',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(title: 'Login'),
              const SizedBox(height: 30),

              // Email Field
              TextField(
                textAlignVertical: TextAlignVertical.center,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Enter your email address',
                ),
              ),
              const SizedBox(height: 16),

              // Password Field
              TextField(
                textAlignVertical: TextAlignVertical.center,
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your passcode',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Forgot Password Link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    _showMessage('Forgot Password clicked.');
                  },
                  child: const Text('Forgot Password?'),
                ),
              ),
              const SizedBox(height: 24),

              // Sign In Button
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
              const SizedBox(height: 24),

              // Sign Up Link
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegistrationScreen(),
                      ),
                    );
                  },
                  child: const Text('Don\'t have an account? Sign Up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}