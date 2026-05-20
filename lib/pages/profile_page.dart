import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../styles/app_colors.dart';
import '../styles/app_textstyle.dart';
import '../widgets/background.dart';

class ProfilePage extends StatefulWidget {
  final bool isNestedTab;
  const ProfilePage({super.key, this.isNestedTab = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return const Center(child: Text('Tidak ada pengguna masuk.', style: TextStyle(color: Colors.white)));
    }

    final Widget content = StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)));
        }

        Map<String, dynamic> userData = {};
        if (snapshot.hasData && snapshot.data!.exists) {
          userData = snapshot.data!.data() as Map<String, dynamic>;
        }

        final String name = userData['nama'] ?? firebaseUser.displayName ?? 'Pengguna GameZone';
        final String email = userData['email'] ?? firebaseUser.email ?? '-';
        final String role = (userData['role'] ?? 'user').toString().toLowerCase();
        final String phone = userData['noHp'] ?? '-';
        final String status = userData['status'] ?? 'active';

        // Konfigurasi Estetika Peran secara dinamis
        final Color themeColor;
        final String roleLabel;
        final IconData roleIcon;
        final String securityDesc;
        final String avatarUrl = userData['fotoProfil'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=150';

        if (role == 'superadmin' || role == 'super_admin') {
          themeColor = const Color(0xFF22D3EE); // Cyan
          roleLabel = 'ROLE: SUPER ADMIN PLATFORM';
          roleIcon = Icons.shield_rounded;
          securityDesc = 'Super Admin Account';
        } else if (role == 'admin') {
          themeColor = const Color(0xFFC084FC); // Purple
          roleLabel = 'ROLE: PARTNER / ADMIN';
          roleIcon = Icons.admin_panel_settings_rounded;
          securityDesc = 'Admin Partner Account';
        } else {
          themeColor = const Color(0xFF10B981); // Emerald Green
          roleLabel = 'ROLE: USER PLATFORM';
          roleIcon = Icons.person_rounded;
          securityDesc = 'Standard User Account';
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                const SizedBox(height: 10),
                // Kartu Profil Avatar
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: themeColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.25),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                          image: DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: themeColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(roleIcon, color: const Color(0xFF0F172A), size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    roleLabel,
                    style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Ikhtisar Detail Akun
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11172A).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeColor.withValues(alpha: 0.1), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('INFORMASI AKUN', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      _buildProfileRow(themeColor, Icons.mail_outline_rounded, 'Email', email),
                      const Divider(color: Color(0xFF1E293B), height: 24),
                      _buildProfileRow(themeColor, Icons.phone_android_rounded, 'Nomor HP', phone),
                      const Divider(color: Color(0xFF1E293B), height: 24),
                      _buildProfileRow(themeColor, Icons.security_rounded, 'Keamanan', securityDesc),
                      const Divider(color: Color(0xFF1E293B), height: 24),
                      _buildProfileRow(themeColor, Icons.offline_bolt_rounded, 'Status', status.toUpperCase()),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                
                // Tombol Keluar
                ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFFEF4444),
                    shadowColor: Colors.transparent,
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Keluar / Log Out',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (widget.isNestedTab) {
      return content;
    }

    return Scaffold(
      body: GameZoneBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header mandiri jika diakses sebagai rute halaman terpisah
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Profil Pengguna',
                      style: AppTextStyle.h3.copyWith(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(Color themeColor, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: themeColor, size: 18),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}
