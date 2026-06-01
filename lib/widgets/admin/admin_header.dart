import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/gradients.dart';

class AdminHeader extends StatelessWidget {
  final User? currentUser;
  final String adminName;
  final String stationName;
  final String? avatarUrl;
  final String? stationId;
  final DateTime? localLastOpened;
  final VoidCallback onNotificationPressed;
  final ValueChanged<DateTime> onNotificationOpened;
  final VoidCallback? onAvatarPressed;
  final String greetingText;

  const AdminHeader({
    super.key,
    required this.currentUser,
    required this.adminName,
    required this.stationName,
    required this.stationId,
    required this.localLastOpened,
    required this.onNotificationPressed,
    required this.onNotificationOpened,
    this.avatarUrl,
    this.onAvatarPressed,
    this.greetingText = 'Halo, Admin!',
  });

  @override
  Widget build(BuildContext context) {
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
                    _AdminAvatar(avatarUrl: avatarUrl, onTap: onAvatarPressed),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            greetingText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.caption1.copyWith(
                              color: AppColors.softGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adminName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.h3.copyWith(
                              color: AppColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            stationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyle.body3.copyWith(
                              color: AppColors.softGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _NotificationButton(
                currentUser: currentUser,
                stationId: stationId,
                localLastOpened: localLastOpened,
                onPressed: onNotificationPressed,
                onNotificationOpened: onNotificationOpened,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback? onTap;

  const _AdminAvatar({this.avatarUrl, this.onTap});

  @override
  Widget build(BuildContext context) {
    final Widget avatar = Container(
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
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? Image.network(
                  avatarUrl!,
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

    if (onTap == null) {
      return avatar;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: avatar,
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final User? currentUser;
  final String? stationId;
  final DateTime? localLastOpened;
  final VoidCallback onPressed;
  final ValueChanged<DateTime> onNotificationOpened;

  const _NotificationButton({
    required this.currentUser,
    required this.stationId,
    required this.localLastOpened,
    required this.onPressed,
    required this.onNotificationOpened,
  });

  @override
  Widget build(BuildContext context) {
    // Tombol notifikasi membaca booking milik station admin aktif dari Firestore.
    if (currentUser == null) {
      return _notificationShell(notificationCount: 0, onTap: () {});
    }

    final FirestoreService firestoreService = FirestoreService();
    final bool hasStationId = stationId != null && stationId!.isNotEmpty;

    return StreamBuilder<DocumentSnapshot>(
      stream: firestoreService.getUserStream(currentUser!.uid),
      builder: (context, userSnap) {
        Timestamp? lastOpened;
        if (userSnap.hasData && userSnap.data!.exists) {
          final userData = userSnap.data!.data() as Map<String, dynamic>;
          lastOpened = userData['lastOpenedBookingNotifications'] as Timestamp?;
          lastOpened ??= userData['lastOpenedNotifications'] as Timestamp?;
        }

        DateTime? compareTime = lastOpened?.toDate();
        if (localLastOpened != null) {
          if (compareTime == null || localLastOpened!.isAfter(compareTime)) {
            compareTime = localLastOpened;
          }
        }

        return FutureBuilder<int>(
          future: hasStationId
              ? firestoreService.getStationBookingNotificationCount(
                  stationId!,
                  lastOpenedAt: compareTime,
                )
              : Future.value(0),
          builder: (context, snapshot) {
            final int unreadCount = snapshot.data ?? 0;

            return _notificationShell(
              notificationCount: unreadCount,
              onTap: () {
                // Klik notifikasi menyimpan waktu buka terakhir agar badge berubah.
                final now = DateTime.now();
                onNotificationOpened(now);
                firestoreService.updateUser(currentUser!.uid, {
                  'lastOpenedBookingNotifications': now,
                });
                onPressed();
              },
            );
          },
        );
      },
    );
  }

  Widget _notificationShell({required int notificationCount, required VoidCallback onTap}) {
    // Wadah visual untuk ikon lonceng dan badge jumlah booking baru.
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
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
              if (notificationCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentCyan.withValues(alpha: 0.45),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      notificationCount > 99
                          ? '99+'
                          : notificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
