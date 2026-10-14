import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../accessibility/accessibility_settings.dart';
import '../accessibility/voice_guidance.dart';
import '../core/database/firestore_collections.dart';
import '../services/admin_service.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin_reports_screen.dart';
import 'my_reports_screen.dart';
import 'login_screen.dart';
import 'logout_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  /// Safely check staff status without initializing Firebase in test environment
  Future<bool> _checkStaffStatus() async {
    try {
      final adminService = AdminService();
      return await adminService.isCurrentUserStaff();
    } catch (e) {
      // If Firebase is not initialized (e.g., in tests), return false
      return false;
    }
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _currentUser;
  String _userRole = 'user';
  String _userName = '';
  bool _isLoadingUser = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }

      if (user != null) {
        if (mounted) setState(() => _isLoadingUser = true);
        try {
          final doc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(user.uid)
              .get();

          if (doc.exists && mounted) {
            setState(() {
              _userRole = doc.data()?['role'] as String? ?? 'user';
              _userName =
                  doc.data()?['name'] as String? ?? user.displayName ?? '';
              _isLoadingUser = false;
            });
          } else if (mounted) {
            setState(() => _isLoadingUser = false);
          }
        } catch (_) {
          if (mounted) setState(() => _isLoadingUser = false);
        }
      }
    } catch (_) {
      // Firebase not initialized in unit/widget tests
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AccessibilityScope.of(context);
    final theme = Theme.of(context);
    final voice = VoiceGuidanceScope.of(context);
    final isStaff = _userRole == 'admin' || _userRole == 'moderator';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(22) + 32,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Account & Moderation section
            Text('Account', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (_currentUser == null) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not Signed In',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to submit accessibility ratings, write reviews, upload photos, and report issues.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ).then((_) => _loadUserInfo());
                        },
                        icon: const Icon(Icons.login),
                        label: const Text('Sign In or Register'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                            child: Icon(
                              Icons.person,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName.isNotEmpty
                                      ? _userName
                                      : (_currentUser!.displayName ?? 'User'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _currentUser!.email ?? '',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isStaff
                                  ? Colors.purple.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isStaff
                                    ? Colors.purple.shade700
                                    : Colors.blue.shade700,
                              ),
                            ),
                            child: Text(
                              isStaff ? 'STAFF' : 'MEMBER',
                              style: TextStyle(
                                color: isStaff
                                    ? Colors.purple.shade900
                                    : Colors.blue.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Admin Moderation Portal tile
                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: const Text('My Reports'),
                        subtitle: const Text('Track your accessibility reports'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyReportsScreen())),
                      ),
                      if (isStaff) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.admin_panel_settings,
                            color: theme.colorScheme.primary,
                          ),
                          title: const Text('Moderation & Reports Review'),
                          subtitle: const Text(
                            'Review and moderate reported accessibility discrepancies',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(context, AdminReportsScreen.route());
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.dashboard_customize_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: const Text('Admin Dashboard & Submissions'),
                          subtitle: const Text(
                            'Review submissions, photo moderation, and place verification',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminDashboardScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                      ],
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LogoutScreen(),
                            ),
                          ).then((_) => _loadUserInfo());
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Voice assistance', style: theme.textTheme.headlineSmall),
            SwitchListTile(
              key: const ValueKey('voice-guidance-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Voice guidance'),
              subtitle: const Text(
                'Hear spoken feedback when you select buttons and controls.',
              ),
              value: settings.voiceGuidance,
              onChanged: (enabled) {
                settings.setVoiceGuidance(enabled);
                if (enabled) {
                  voice.speak(
                    'Voice guidance on. Tap a button to hear spoken feedback.',
                  );
                }
              },
            ),
            if (settings.voiceGuidance) ...[
              OutlinedButton.icon(
                onPressed: () => voice.speak(
                  'Voice guidance is ready. You can explore nearby places and choose your travel mode.',
                ),
                icon: const Icon(Icons.volume_up),
                label: const Text('Test voice'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Uses your device’s English voice and media volume. If you use TalkBack or VoiceOver, you can leave this off to avoid duplicate speech.',
              ),
              if (voice.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(liveRegion: true, child: Text(voice.error!)),
                ),
            ],
            const SizedBox(height: 24),

            // Reading & display
            Text('Reading & display', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text(
              'Make AccessLink easier to read. Changes apply immediately.',
            ),
            const SizedBox(height: 24),
            Text('Text size', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Choose a comfortable size. Your phone’s text-size setting is also respected.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: TextSize.values
                  .map(
                    (size) => ChoiceChip(
                      label: Text(size.label),
                      selected: settings.textSize == size,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (selected) {
                        if (selected) {
                          settings.setTextSize(size);
                          voice.speak('${size.label} text selected');
                        }
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('High contrast'),
              subtitle: const Text(
                'Darker text, stronger controls, and solid backgrounds.',
              ),
              value: settings.highContrast,
              onChanged: (enabled) {
                settings.setHighContrast(enabled);
                voice.speak('High contrast ${enabled ? 'on' : 'off'}');
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outline, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preview', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Find nearby places and choose how you want to travel.',
                  ),
                  const SizedBox(height: 12),
                  Icon(
                    Icons.directions,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (settings.saveError != null) ...[
              Text(settings.saveError!, semanticsLabel: settings.saveError),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: () {
                settings.reset();
                voice.speak('Display settings reset');
              },
              child: const Text(
                'Reset display settings',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
