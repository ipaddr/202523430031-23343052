import 'package:flutter/material.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';


export 'package:gamezone/utils/helpers.dart' show bookingStatusColor, bookingStatusLabel;

/// Badge status kecil — digunakan di seluruh halaman User, Admin, SuperAdmin.
///
/// Contoh penggunaan:
/// ```dart
/// StatusBadge(label: 'MENUNGGU', color: AppColors.warningOrange)
/// StatusBadge(label: 'DIKONFIRMASI', color: AppColors.accentCyan)
/// StatusBadge(label: 'BELUM DIBAYAR', color: AppColors.warningOrange)
/// StatusBadge(label: 'SELESAI', color: AppColors.successGreen)
/// ```
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingL,
        vertical: AppTheme.paddingS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTextStyle.caption1.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

