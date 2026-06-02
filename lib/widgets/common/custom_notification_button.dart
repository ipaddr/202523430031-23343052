import 'package:flutter/material.dart';
import 'package:gamezone/styles/app_colors.dart';

/// Button Notifikasi terpadu yang digunakan secara seragam di seluruh aplikasi GameZone.
class CustomNotificationButton extends StatelessWidget {
  final bool hasNotification;
  final int notificationCount;
  final VoidCallback onTap;

  const CustomNotificationButton({
    super.key,
    required this.hasNotification,
    this.notificationCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              if (hasNotification)
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
}
