import 'package:flutter/material.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';

class FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? AppColors.accentCyan.withValues(alpha: 0.55)
        : AppColors.white.withValues(alpha: 0.08);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? Gradients.kAccent : null,
          color: selected
              ? null
              : AppColors.secondaryDark.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: borderColor, width: 1.1),
        ),
        child: Text(
          label,
          style: AppTextStyle.caption1.copyWith(
            color: selected ? AppColors.white : AppColors.softGray,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
