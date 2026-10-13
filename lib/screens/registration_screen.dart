import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/auth/auth_page.dart';

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
      final credential = await _authService.registerUser(email, password);

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
          _showMessage(
            'Account created, but saving your profile failed. Please update it later.',
          );
        }
      } catch (e) {
        // Generic error for any other exceptions during Firestore write
        debugPrint('Failed to save user profile: $e');
        if (mounted) {
          _showMessage(
            'Account created, but saving your profile failed. Please update it later.',
          );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    return AuthPage(
      title: 'Register',
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthHeader(
                  title: 'Register',
                  logoSize: (constraints.maxHeight - 560).clamp(64.0, 140.0),
                ),
                const SizedBox(height: 10),
                // Input 1: Name or Email
                TextField(
                  textAlignVertical: TextAlignVertical.center,
                  controller: _nameOrEmailController,
                  decoration: const InputDecoration(hintText: 'Name or Email'),
                ),
                const SizedBox(height: 10),

                // Input 2: Email
                TextField(
                  textAlignVertical: TextAlignVertical.center,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email'),
                ),
                const SizedBox(height: 10),

                // Input 3: Phone number
                TextField(
                  textAlignVertical: TextAlignVertical.center,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Phone number'),
                ),
                const SizedBox(height: 10),

                // Input 4: Password
                TextField(
                  textAlignVertical: TextAlignVertical.center,
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',

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
                const SizedBox(height: 10),

                // Input 5: Confirm Password
                TextField(
                  textAlignVertical: TextAlignVertical.center,
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirm Password',

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
                const SizedBox(height: 4),

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
                const SizedBox(height: 8),

                // Sign Up button
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Register'),
                ),
                const SizedBox(height: 10),

                // Already have an account? Sign In
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Already have an account? Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}