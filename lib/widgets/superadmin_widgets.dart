import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';

// Komponen bersama untuk area super admin agar dashboard utama tetap ringkas.

class SuperAdminTopBar extends StatelessWidget {
  final User? currentUser;
  final DateTime? localLastOpened;
  final VoidCallback onNotificationPressed;
  final ValueChanged<DateTime> onNotificationOpened;

  const SuperAdminTopBar({
    super.key,
    required this.currentUser,
    required this.localLastOpened,
    required this.onNotificationPressed,
    required this.onNotificationOpened,
  });

  @override
  Widget build(BuildContext context) {
    // Header atas menyatukan salam, notifikasi, dan avatar pengguna.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Halo, Super Admin!',
                    style: TextStyle(
                      color: Color(0xFF9AA3C3),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard Platform',
                    style: AppTextStyle.h3.copyWith(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _NotificationButton(
                    currentUser: currentUser,
                    localLastOpened: localLastOpened,
                    onNotificationPressed: onNotificationPressed,
                    onNotificationOpened: onNotificationOpened,
                  ),
                  const SizedBox(width: 12),
                  _ProfileAvatar(currentUser: currentUser),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final User? currentUser;
  final DateTime? localLastOpened;
  final VoidCallback onNotificationPressed;
  final ValueChanged<DateTime> onNotificationOpened;

  const _NotificationButton({
    required this.currentUser,
    required this.localLastOpened,
    required this.onNotificationPressed,
    required this.onNotificationOpened,
  });

  @override
  Widget build(BuildContext context) {
    // Tombol lonceng membaca status notifikasi admin dari Firestore.
    if (currentUser == null) {
      return _emptyButton(
        const Icon(
          Icons.notifications_none_rounded,
          color: Color(0xFF94A3B8),
          size: 22,
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots(),
      builder: (context, userSnap) {
        Timestamp? lastOpened;
        if (userSnap.hasData && userSnap.data!.exists) {
          final userData = userSnap.data!.data() as Map<String, dynamic>;
          lastOpened = userData['lastOpenedNotifications'] as Timestamp?;
        }

        DateTime? compareTime = lastOpened?.toDate();
        if (localLastOpened != null) {
          if (compareTime == null || localLastOpened!.isAfter(compareTime)) {
            compareTime = localLastOpened;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .snapshots(),
          builder: (context, snapshot) {
            bool showDot = false;
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              if (compareTime == null) {
                showDot = true;
              } else {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                  if (createdAt != null &&
                      createdAt.toDate().isAfter(compareTime)) {
                    showDot = true;
                    break;
                  }
                }
              }
            }

            return GestureDetector(
              onTap: () {
                final now = DateTime.now();
                onNotificationOpened(now);
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .set({
                      'lastOpenedNotifications': now,
                    }, SetOptions(merge: true));
                onNotificationPressed();
              },
              child: _notificationShell(showDot: showDot),
            );
          },
        );
      },
    );
  }

  Widget _notificationShell({required bool showDot}) {
    // Wadah visual untuk ikon lonceng dan titik indikator.
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF141B31),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFF94A3B8),
            size: 22,
          ),
          if (showDot)
            Positioned(
              top: 13,
              right: 13,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF22D3EE),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x9022D3EE),
                      blurRadius: 6,
                      spreadRadius: 1.5,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyButton(Widget child) {
    // Tampilan cadangan saat belum ada user yang login.
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF141B31),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: child,
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final User? currentUser;

  const _ProfileAvatar({required this.currentUser});

  @override
  Widget build(BuildContext context) {
    // Avatar profil mengambil foto terakhir dari dokumen user aktif.
    if (currentUser == null) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF141B31),
          border: Border.all(
            color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.person, color: Color(0xFF64748B), size: 22),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String avatarUrl = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          avatarUrl = data['foto'] ?? '';
        }
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF141B31),
            border: Border.all(
              color: const Color(0xFF22D3EE).withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: avatarUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.person,
                      color: Color(0xFF64748B),
                      size: 22,
                    ),
                  ),
                )
              : const Icon(Icons.person, color: Color(0xFF64748B), size: 22),
        );
      },
    );
  }
}

class SuperAdminSheetHeader extends StatelessWidget {
  final String title;

  const SuperAdminSheetHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    // Header modal dipakai ulang untuk beberapa sheet super admin.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class SuperAdminStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const SuperAdminStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    // Kartu ringkas untuk statistik dashboard.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class SuperAdminActivityItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeText;
  final String categoryText;
  final IconData? icon;
  final Color? iconColor;
  final String? imagePath;

  const SuperAdminActivityItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.categoryText,
    this.icon,
    this.iconColor,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    // Satu baris aktivitas yang menampilkan ikon, judul, waktu, dan kategori.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF11172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.05),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          if (imagePath != null)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(imagePath!),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFF22D3EE)).withValues(
                  alpha: 0.1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon ?? Icons.info_outline_rounded,
                color: iconColor ?? const Color(0xFF22D3EE),
                size: 20,
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeText,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                categoryText,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SuperAdminNavItem extends StatelessWidget {
  final bool isActive;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const SuperAdminNavItem({
    super.key,
    required this.isActive,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Item navigasi bawah dengan state aktif dan efek gradient.
    final Color textColor = isActive
        ? const Color(0xFF22D3EE)
        : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 85,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isActive
                ? Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22D3EE), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF22D3EE,
                          ).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: Colors.transparent),
                    child: Icon(icon, color: const Color(0xFF64748B), size: 22),
                  ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuperAdminBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const SuperAdminBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Bar navigasi bawah untuk berpindah antar tab utama.
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF090D20),
        border: Border(top: BorderSide(color: Color(0xFF141C38), width: 1.2)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SizedBox(
              height: 82,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    SuperAdminNavItem(
                      isActive: currentIndex == 0,
                      icon: Icons.home_rounded,
                      label: 'BERANDA',
                      onTap: () => onTabSelected(0),
                    ),
                    SuperAdminNavItem(
                      isActive: currentIndex == 1,
                      icon: Icons.help_outline_rounded,
                      label: 'VERIFIKASI',
                      onTap: () => onTabSelected(1),
                    ),
                    SuperAdminNavItem(
                      isActive: currentIndex == 2,
                      icon: Icons.people_outline_rounded,
                      label: 'USER',
                      onTap: () => onTabSelected(2),
                    ),
                    SuperAdminNavItem(
                      isActive: currentIndex == 3,
                      icon: Icons.person_rounded,
                      label: 'PROFIL',
                      onTap: () => onTabSelected(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
