import 'package:flutter/material.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';

/// Menampilkan dialog konfirmasi kustom dengan gaya premium GameZone.
Future<bool> showCustomConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmLabel = 'Ya',
  String cancelLabel = 'Batal',
  Color? confirmColor,
  Color? confirmTextColor,
  bool isDestructive = false,
}) async {
  final Color actualConfirmColor = confirmColor ??
      (isDestructive ? AppColors.errorRed : AppColors.accentCyan);

  final Color actualConfirmTextColor = confirmTextColor ??
      (isDestructive ? Colors.white : Colors.black);

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return Theme(
        data: ThemeData.dark(),
        child: AlertDialog(
          backgroundColor: AppColors.primaryDarkNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            side: BorderSide(
              color: isDestructive
                  ? const Color(0xFF1E293B)
                  : AppColors.accentCyan.withValues(alpha: 0.12),
            ),
          ),
          title: Text(
            title,
            style: AppTextStyle.h4.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            content,
            style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                cancelLabel,
                style: AppTextStyle.buttonSmall.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: actualConfirmColor,
                foregroundColor: actualConfirmTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                confirmLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}
