import 'package:flutter/material.dart';

import '../screens/admin_reports_screen.dart';
import '../screens/logout_screen.dart';
import '../services/admin_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AdminService _adminService = AdminService();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final isAdmin = await _adminService.isCurrentUserAdmin();
      if (!mounted) return;
      setState(() {
        _isAdmin = isAdmin;
      });
    } catch (_) {
      // Not admin.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Admin section (only visible for admins)
          if (_isAdmin) ...[
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: Icon(Icons.admin_panel_settings,
                    color: Colors.blue.shade700),
                title: const Text(
                  'Admin – Review Reports',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Review accessibility reports'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminReportsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Logout button
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogoutScreen()),
              ),
              child: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}
