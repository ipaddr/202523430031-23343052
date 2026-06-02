import 'package:flutter/material.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';

/// Tombol aksi utama dengan gradient kAccent.
/// Digunakan untuk aksi primer: Simpan, Booking Sekarang, Bayar Sekarang, dll.
///
/// Contoh penggunaan:
/// ```dart
/// PrimaryButton(label: 'Bayar Sekarang', onTap: _handlePayment)
/// PrimaryButton(label: 'Simpan', onTap: _save, isLoading: _isLoading)
/// PrimaryButton(label: 'Tambah Room', onTap: _add, icon: Icons.add_rounded)
/// PrimaryButton(label: 'Nonaktif', onTap: null) // disabled otomatis
/// ```
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconData? icon;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.icon,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null && !isLoading;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          height: height,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: Gradients.kAccent,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: enabled ? AppTheme.shadowMedium : null,
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: AppColors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: AppTextStyle.buttonMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Tombol aksi sekunder dengan style outline.
/// Digunakan untuk aksi sekunder: Batalkan, Beri Rating, Kelola Room, dll.
///
/// Contoh penggunaan:
/// ```dart
/// SecondaryButton(label: 'Batalkan Booking', onTap: _cancel, color: AppColors.errorRed)
/// SecondaryButton(label: 'Beri Rating', onTap: _rate)          // default cyan
/// SecondaryButton(label: 'Tidak Bisa Dibatalkan', onTap: null) // disabled
/// ```
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    final Color resolvedColor = enabled
        ? (color ?? AppColors.accentCyan)
        : AppColors.lightText;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: height,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled
              ? resolvedColor.withValues(alpha: 0.08)
              : AppColors.secondaryDark.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: enabled
                ? resolvedColor.withValues(alpha: 0.5)
                : const Color(0xFF334155),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyle.buttonMedium.copyWith(
            color: resolvedColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
