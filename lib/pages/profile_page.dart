import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

import '../styles/app_colors.dart';
import '../styles/app_textstyle.dart';
import '../widgets/background.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';

// Halaman profil untuk melihat data akun aktif dan melakukan logout.
class ProfilePage extends StatefulWidget {
  final bool isNestedTab;
  final VoidCallback? onProfileUpdated;

  /// Callback dipanggil saat user konfirmasi logout dari tab profil.
  /// Dashboard menyetel _isLoggingOut sebelum logout dieksekusi agar
  /// tidak ada double-navigation atau flash ke tab lain.
  final Future<void> Function()? onLogoutRequested;

  const ProfilePage({
    super.key,
    this.isNestedTab = false,
    this.onProfileUpdated,
    this.onLogoutRequested,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  Stream<DocumentSnapshot>? _userStream;

  Future<void> _logout(NavigatorState navigator) async {
    // Sign out terlebih dahulu.
    await _authService.logout();
    // Navigasi ke splash — hanya jika tidak ada dashboard yang mengelola navigasi.
    if (navigator.mounted) {
      navigator.pushNamedAndRemoveUntil('/splash', (route) => false);
    }
  }

  // Dialog konfirmasi logout agar seragam di semua role
  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    // Ambil navigator dari page context SEBELUM dialog dibuka.
    final navigator = Navigator.of(context, rootNavigator: true);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: ThemeData.dark(),
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF1E293B)),
            ),
            title: const Text(
              'Keluar Akun',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Apakah Anda yakin ingin keluar dari akun Anda?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Keluar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm == true) {
      // Jika dashboard menyediakan callback, delegasikan seluruh proses logout
      // ke dashboard agar ia bisa set _isLoggingOut sebelum signout — mencegah
      // flash rebuild ke tab lain sebelum navigasi ke splash.
      if (widget.onLogoutRequested != null) {
        await widget.onLogoutRequested!();
      } else {
        await _logout(navigator);
      }
    }
  }


  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: ThemeData.dark(),
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF1E293B)),
            ),
            title: const Row(
              children: [
                Icon(Icons.sports_esports_rounded, color: Color(0xFF22D3EE)),
                SizedBox(width: 12),
                Text(
                  'Tentang Aplikasi',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GameZone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Platform pencarian dan booking game station.',
                  style: TextStyle(color: Color(0xFF94A3C3), fontSize: 13),
                ),
                SizedBox(height: 16),
                Divider(color: Colors.white10),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Versi',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    Text(
                      '1.0.0',
                      style: TextStyle(
                        color: Color(0xFF22D3EE),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Tutup',
                  style: TextStyle(
                    color: Color(0xFF22D3EE),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Mengubah bulan ke format bahasa indonesia
  String _getIndonesianMonth(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // Konten profil dibangun dari data user aktif di Firestore.
    final firebaseUser = _authService.getCurrentUser();
    if (firebaseUser == null) {
      return const Center(
        child: Text(
          'Tidak ada pengguna masuk.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    _userStream ??= _firestoreService.getUserStream(firebaseUser.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
          );
        }

        Map<String, dynamic> userData = {};
        if (snapshot.hasData && snapshot.data!.exists) {
          userData = snapshot.data!.data() as Map<String, dynamic>;
        }

        final String name = userData['nama'] ?? '';
        final String email = userData['email'] ?? firebaseUser.email ?? '-';
        final String role = (userData['role'] ?? 'user')
            .toString()
            .toLowerCase();
        final String phone = userData['noHp'] ?? '';

        final Timestamp? joinedTimestamp = userData['createdAt'] as Timestamp?;
        String joinedDate = 'Tidak tersedia';
        if (joinedTimestamp != null) {
          final date = joinedTimestamp.toDate();
          joinedDate =
              '${date.day} ${_getIndonesianMonth(date.month)} ${date.year}';
        }

        final Color themeColor;
        final String roleLabel;
        final IconData roleIcon;
        final String avatarUrl = userData['foto'] ?? '';

        if (role == 'superadmin' || role == 'super_admin') {
          themeColor = const Color(0xFF22D3EE); // Cyan
          roleLabel = 'PERAN: SUPER ADMIN PLATFORM';
          roleIcon = Icons.shield_rounded;
        } else if (role == 'admin') {
          themeColor = const Color(0xFF22D3EE); // Cyan
          roleLabel = 'PERAN: MITRA / ADMIN';
          roleIcon = Icons.admin_panel_settings_rounded;
        } else {
          themeColor = const Color(0xFF22D3EE); // Cyan
          roleLabel = 'PERAN: PENGGUNA PLATFORM';
          roleIcon = Icons.person_rounded;
        }

        // Tentukan body profil berdasarkan peran user
        final Widget finalBody;
        if (role == 'admin') {
          finalBody = FutureBuilder<Map<String, dynamic>?>(
            future: _firestoreService.getStationByOwnerId(
              firebaseUser.uid,
              email: firebaseUser.email,
              name: firebaseUser.displayName,
            ),
            builder: (context, stationSnapshot) {
              if (stationSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
                );
              }

              final Map<String, dynamic>? stationData = stationSnapshot.data;
              final String stationName =
                  stationData?['namaStation']?.toString() ??
                  stationData?['stationName']?.toString() ??
                  'Belum Diatur';
              final String stationType =
                  stationData?['jenis']?.toString() ??
                  stationData?['jenisStation']?.toString() ??
                  'Belum Diatur';
              final String stationOperationalHours = _formatOperationalHours(
                stationData?['jamOperasional'],
              );
              final String stationStatus =
                  stationData?['statusVerifikasi']?.toString() ?? 'pending';
              final String stationPhotoUrl = _readFirstPhotoUrl(
                stationData?['foto'],
                fallback: avatarUrl,
              );

              return _buildProfileBody(
                context: context,
                themeColor: themeColor,
                roleLabel: roleLabel,
                roleIcon: roleIcon,
                avatarUrl: stationPhotoUrl,
                displayName: name,
                accountRows: [
                  _ProfileRowData(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: email,
                  ),
                  _ProfileRowData(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Role',
                    value: 'Admin',
                  ),
                  _ProfileRowData(
                    icon: Icons.sports_esports_rounded,
                    label: 'Nama Game Station',
                    value: stationName,
                  ),
                  _ProfileRowData(
                    icon: Icons.videogame_asset_rounded,
                    label: 'Jenis Game Station',
                    value: stationType,
                  ),
                  _ProfileRowData(
                    icon: Icons.access_time_rounded,
                    label: 'Jam Operasional',
                    value: stationOperationalHours,
                  ),
                  _ProfileRowData(
                    icon: Icons.verified_rounded,
                    label: 'Status Verifikasi Station',
                    value: stationStatus.toUpperCase(),
                  ),
                  _ProfileRowData(
                    icon: Icons.calendar_today_rounded,
                    label: 'Tanggal Bergabung',
                    value: joinedDate,
                  ),
                ],
              );
            },
          );
        } else {
          finalBody = _buildProfileBody(
            context: context,
            themeColor: themeColor,
            roleLabel: roleLabel,
            roleIcon: roleIcon,
            avatarUrl: avatarUrl,
            displayName: name,
            accountRows: [
              _ProfileRowData(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: email,
              ),
              _ProfileRowData(
                icon: Icons.phone_android_rounded,
                label: 'Nomor HP',
                value: phone.isEmpty ? 'Belum Diatur' : phone,
              ),
              _ProfileRowData(
                icon: Icons.security_rounded,
                label: 'Role',
                value: role == 'superadmin' || role == 'super_admin'
                    ? 'Super Admin'
                    : 'User',
              ),
              _ProfileRowData(
                icon: Icons.calendar_today_rounded,
                label: 'Tanggal Bergabung',
                value: joinedDate,
              ),
            ],
          );
        }

        if (widget.isNestedTab) {
          return finalBody;
        }

        return Scaffold(
          body: GameZoneBackground(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1E293B,
                              ).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF22D3EE,
                                ).withValues(alpha: 0.15),
                              ),
                            ),
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          role == 'admin'
                              ? 'Profil Admin'
                              : (role == 'superadmin' || role == 'super_admin'
                                    ? 'Profil Super Admin'
                                    : 'Profil Pengguna'),
                          style: AppTextStyle.h3.copyWith(
                            color: AppColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: finalBody),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileBody({
    required BuildContext context,
    required Color themeColor,
    required String roleLabel,
    required IconData roleIcon,
    required String avatarUrl,
    required String displayName,
    required List<_ProfileRowData> accountRows,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const SizedBox(height: 10),
            Center(
              child: Stack(
                children: [
                  CustomUserAvatar(photoUrl: avatarUrl, size: 100),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        roleIcon,
                        color: const Color(0xFF0F172A),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                displayName.isEmpty ? 'Belum Diatur' : displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                roleLabel,
                style: TextStyle(
                  color: themeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Kartu informasi akun menyesuaikan role tanpa mengubah gaya visual.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF11172A).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: themeColor.withValues(alpha: 0.1),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INFORMASI AKUN',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < accountRows.length; i++) ...[
                    if (i > 0)
                      const Divider(color: Color(0xFF1E293B), height: 24),
                    _buildProfileRow(
                      themeColor,
                      accountRows[i].icon,
                      accountRows[i].label,
                      accountRows[i].value,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/edit-profile',
                );

                if (result == true) {
                  widget.onProfileUpdated?.call();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor.withValues(alpha: 0.15),
                foregroundColor: themeColor,
                shadowColor: Colors.transparent,
                side: BorderSide(color: themeColor, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text(
                'Edit Profil',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),


            ElevatedButton.icon(
              onPressed: () => _showAboutDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFF22D3EE,
                ).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF22D3EE),
                shadowColor: Colors.transparent,
                side: const BorderSide(color: Color(0xFF22D3EE), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: const Text(
                'Tentang Aplikasi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: () => _showLogoutConfirmationDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFFEF4444,
                ).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFFEF4444),
                shadowColor: Colors.transparent,
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Keluar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _readFirstPhotoUrl(dynamic photoData, {required String fallback}) {
    if (photoData is String && photoData.trim().isNotEmpty) {
      return photoData.trim();
    }

    if (photoData is List && photoData.isNotEmpty) {
      final dynamic firstPhoto = photoData.first;
      final String firstPhotoString = firstPhoto?.toString().trim() ?? '';
      if (firstPhotoString.isNotEmpty) {
        return firstPhotoString;
      }
    }

    return fallback;
  }

  String _formatOperationalHours(dynamic hoursData) {
    if (hoursData == null) {
      return 'Belum Diatur';
    }

    if (hoursData is String) {
      final String value = hoursData.trim();
      return value.isEmpty ? 'Belum Diatur' : value;
    }

    if (hoursData is List) {
      final List<String> rows = [];
      for (final dynamic item in hoursData) {
        if (item is Map) {
          final String day = item['hari']?.toString() ?? '';
          final String start = item['buka']?.toString() ?? '';
          final String end = item['tutup']?.toString() ?? '';
          final bool isOpen = item['isOpen'] == true;
          if (!isOpen || day.isEmpty || start.isEmpty || end.isEmpty) {
            continue;
          }
          rows.add('$day: $start - $end');
        }
      }

      return rows.isEmpty ? 'Belum Diatur' : rows.join('\n');
    }

    if (hoursData is Map) {
      final dynamic legacyValue = hoursData['value'] ?? hoursData['text'];
      if (legacyValue != null && legacyValue.toString().trim().isNotEmpty) {
        return legacyValue.toString().trim();
      }
    }

    final String fallback = hoursData.toString().trim();
    return fallback.isEmpty ? 'Belum Diatur' : fallback;
  }

  Widget _buildProfileRow(
    Color themeColor,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, color: themeColor, size: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                softWrap: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileRowData {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRowData({
    required this.icon,
    required this.label,
    required this.value,
  });
}
