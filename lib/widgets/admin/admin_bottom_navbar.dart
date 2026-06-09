import 'package:flutter/material.dart';

import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';

class AdminBottomNavItem extends StatelessWidget {
  final bool isActive;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const AdminBottomNavItem({
    super.key,
    required this.isActive,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color inactiveColor = AppColors.lightText;
    final Color activeColor = AppColors.white;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                gradient: isActive ? AppColors.gradientCyanToBlue : null,
                color: isActive ? null : Colors.transparent,
                border: Border.all(
                  color: isActive
                      ? AppColors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? activeColor : inactiveColor,
                size: isActive ? 21 : 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.caption2.copyWith(
                color: isActive ? AppColors.accentCyan : inactiveColor,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AdminBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final double systemBottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryDarkNavy.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: AppColors.accentCyan.withValues(alpha: 0.08),
            width: 1.2,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: systemBottomInset),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                height: 84,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      AdminBottomNavItem(
                        isActive: currentIndex == 0,
                        icon: Icons.home_rounded,
                        label: 'Beranda',
                        onTap: () => onTabSelected(0),
                      ),
                      AdminBottomNavItem(
                        isActive: currentIndex == 1,
                        icon: Icons.meeting_room_rounded,
                        label: 'Room',
                        onTap: () => onTabSelected(1),
                      ),
                      AdminBottomNavItem(
                        isActive: currentIndex == 2,
                        icon: Icons.book_online_rounded,
                        label: 'Booking',
                        onTap: () => onTabSelected(2),
                      ),
                      AdminBottomNavItem(
                        isActive: currentIndex == 3,
                        icon: Icons.person_rounded,
                        label: 'Profil',
                        onTap: () => onTabSelected(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
