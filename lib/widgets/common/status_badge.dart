import 'package:flutter/material.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';

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

/// Mengembalikan warna untuk status booking secara konsisten di seluruh app.
Color bookingStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
    case 'checkin':
    case 'pending_confirmation':
      return AppColors.accentCyan;
    case 'pending':
      return AppColors.warningOrange;
    case 'completed':
      return AppColors.successGreen;
    case 'cancelled':
      return AppColors.errorRed;
    default:
      return AppColors.softGray;
  }
}

/// Mengembalikan label Bahasa Indonesia untuk status booking.
String bookingStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return 'DIKONFIRMASI';
    case 'pending_confirmation':
      return 'MENUNGGU KONFIRMASI';
    case 'pending':
      return 'MENUNGGU PEMBAYARAN';
    case 'checkin':
      return 'SEDANG BERMAIN';
    case 'completed':
      return 'SELESAI';
    case 'cancelled':
      return 'DIBATALKAN';
    default:
      return status.toUpperCase();
  }
}
