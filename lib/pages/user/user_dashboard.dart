import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/dashboard_shell.dart';

class UserDashboardPage extends StatelessWidget {
  const UserDashboardPage({super.key});

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
      icon: Icons.person_rounded,
      iconColor: const Color(0xFF22D3EE),
      title: 'User Dashboard',
      subtitle: user?.email ?? 'Akun User',
      buttonText: 'Keluar',
      onPrimaryAction: () => _logout(context),
    );
  }
}
