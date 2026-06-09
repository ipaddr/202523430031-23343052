import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/widgets/common/custom_notification_button.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';

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
    final Widget avatar = CustomUserAvatar(photoUrl: avatarUrl, size: 52);

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
    if (currentUser == null) {
      return _notificationShell(notificationCount: 0, onTap: () {});
    }

    final FirestoreService firestoreService = FirestoreService();

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

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('roleTarget', isEqualTo: 'admin')
              .where('stationId', isEqualTo: stationId ?? '')
              .snapshots(),
          builder: (context, snapshot) {
            int unreadCount = 0;
            if (snapshot.hasData) {
              if (compareTime == null) {
                unreadCount = snapshot.data!.docs.length;
              } else {
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                  if (createdAt != null &&
                      createdAt.toDate().isAfter(compareTime)) {
                    unreadCount++;
                  }
                }
              }
            }

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

  Widget _notificationShell({
    required int notificationCount,
    required VoidCallback onTap,
  }) {
    return CustomNotificationButton(
      hasNotification: notificationCount > 0,
      notificationCount: notificationCount,
      onTap: onTap,
    );
  }
}
