import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gamezone/services/firestore_service.dart';

import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/gradients.dart';

// Header khusus untuk halaman Super Admin.
// Menampilkan avatar, teks sapaan, dan tombol notifikasi.
class SuperAdminHeader extends StatelessWidget {
  final User? currentUser;
  final DateTime? localLastOpened;
  final VoidCallback onNotificationPressed;
  final ValueChanged<DateTime> onNotificationOpened;

  const SuperAdminHeader({
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
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _SuperAdminAvatar(currentUser: currentUser),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Halo, Super Admin!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF9AA3C3),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dashboard Platform',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.h3.copyWith(
                              color: AppColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _NotificationButton(
                currentUser: currentUser,
                localLastOpened: localLastOpened,
                onNotificationPressed: onNotificationPressed,
                onNotificationOpened: onNotificationOpened,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget tombol notifikasi: membaca stream Firestore, menandakan notifikasi baru.
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

    final FirestoreService firestoreService = FirestoreService();

    return StreamBuilder<DocumentSnapshot>(
      stream: firestoreService.getUserStream(currentUser!.uid),
      builder: (context, userSnap) {
        // Ambil waktu terakhir membuka notifikasi dari dokumen user.
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
          stream: firestoreService.getPendingAdminsStream(),
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

            return _notificationShell(
              showDot: showDot,
              onTap: () {
                final now = DateTime.now();
                onNotificationOpened(now);
                firestoreService.updateUser(currentUser!.uid, {
                  'lastOpenedNotifications': now,
                });
                onNotificationPressed();
              },
            );
          },
        );
      },
    );
  }

  Widget _notificationShell({required bool showDot, required VoidCallback onTap}) {
    // Wadah visual untuk ikon lonceng dan titik indikator.
    return Material(
      color: AppColors.secondaryDark.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: AppColors.accentCyan.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.softGray,
                size: 22,
              ),
              if (showDot)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentCyan.withValues(alpha: 0.45),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
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

class _SuperAdminAvatar extends StatelessWidget {
  final User? currentUser;

  const _SuperAdminAvatar({this.currentUser});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    // Helper untuk membangun tampilan avatar dengan gradient dan border.
    Widget avatarShell(String? avatarUrl) {
      return Container(
        width: 52,
        height: 52,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: Gradients.accent,
          boxShadow: [
            BoxShadow(
              color: AppColors.accentCyan.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryDarkNavy,
            border: Border.all(
              color: const Color(0xFF22D3EE).withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.person_rounded,
                        color: AppColors.softGray,
                        size: 24,
                      );
                    },
                  )
                : const Icon(
                    Icons.person_rounded,
                    color: AppColors.softGray,
                    size: 24,
                  ),
          ),
        ),
      );
    }

    // Jika belum ada user, tampilkan avatar default.
    if (currentUser == null) {
      return avatarShell(null);
    }

    // Ambil URL avatar dari dokumen user secara realtime.
    return StreamBuilder<DocumentSnapshot>(
      stream: firestoreService.getUserStream(currentUser!.uid),
      builder: (context, snapshot) {
        String? avatarUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          avatarUrl = data['foto'] as String?;
        }
        return avatarShell(avatarUrl);
      },
    );
  }
}
