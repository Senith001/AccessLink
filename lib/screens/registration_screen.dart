import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../repositories/user_repository.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameOrEmailController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();
  final _userRepository = UserRepository();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    if (!_agreeToTerms) {
      _showMessage('Please agree to the Terms & Conditions.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await _authService.registerUser(
        email,
        password,
      );

      if (!mounted) return;

      // Save user data to Firestore
      try {
        String name = _nameOrEmailController.text.trim();
        if (name.isEmpty) {
          name = email; // Fallback to email if name is empty
        }
        
        String phone = _phoneController.text.trim();
        
        await _userRepository.createUser(
          uid: credential.user!.uid,
          name: name,
          email: email,
          phone: phone.isEmpty ? null : phone,
        );
      } on FirebaseException catch (e) {
        debugPrint('PROFILE WRITE ERROR code=${e.code} msg=${e.message}');
        // If Firestore write fails after successful auth, show warning but don't crash
        debugPrint('Failed to save user profile: ${e.message}');
        if (mounted) {
          _showMessage('Account created, but saving your profile failed. Please update it later.');
        }
      } catch (e) {
        // Generic error for any other exceptions during Firestore write
        debugPrint('Failed to save user profile: $e');
        if (mounted) {
          _showMessage('Account created, but saving your profile failed. Please update it later.');
        }
      }

      if (!mounted) return;

      _showMessage('Registration successful!');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      debugPrint('AUTH ERROR (register) code=${e.code} msg=${e.message}');
      if (!mounted) return;

      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'weak-password':
          message = 'Password is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password registration is not enabled.';
          break;
        case 'network-request-failed':
          message = 'Request timed out. Check your connection and try again.';
          break;
        default:
          message = 'Registration failed. Please try again.';
      }
      _showMessage(message);
    } catch (e) {
      debugPrint('AUTH UNKNOWN (register) err=$e');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _nameOrEmailController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
        title: const Text('Sign Up'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Input 1: Name or Email
              TextField(
                controller: _nameOrEmailController,
                decoration: const InputDecoration(
                  labelText: 'Name or Email',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Input 2: Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Input 3: Phone number
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Input 4: Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
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
              const SizedBox(height: 16),

              // Input 5: Confirm Password
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Terms & Conditions checkbox
              Row(
                children: [
                  Checkbox(
                    value: _agreeToTerms,
                    onChanged: (value) {
                      setState(() {
                        _agreeToTerms = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: const [
                          TextSpan(text: 'I agree to all the '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sign Up button
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign Up'),
              ),
              const SizedBox(height: 16),

              // Already have an account? Sign In
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Already have an account? Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }

}