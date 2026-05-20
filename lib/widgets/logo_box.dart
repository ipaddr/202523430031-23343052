import 'package:flutter/material.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/gradients.dart';

class LogoBox extends StatelessWidget {
  final double size;
  final Widget child;
  const LogoBox({super.key, required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlue.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.accentCyan.withValues(alpha: 0.08),
            blurRadius: 60,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        child: Container(
          decoration: const BoxDecoration(gradient: Gradients.kAccent),
          child: Center(child: child),
        ),
      ),
    );
  }
}
