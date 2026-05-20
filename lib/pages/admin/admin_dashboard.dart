import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/dashboard_shell.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DashboardShell(
      icon: Icons.admin_panel_settings_rounded,
      iconColor: const Color(0xFF7C4DFF),
      title: 'Admin Dashboard',
      subtitle: user?.email ?? 'Akun Admin',
      buttonText: 'Keluar',
      onPrimaryAction: () => _logout(context),
    );
  }
}
