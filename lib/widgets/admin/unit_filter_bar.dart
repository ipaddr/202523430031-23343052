import 'package:flutter/material.dart';

import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';

enum UnitTypeFilter { all, pc, room }

enum UnitStatusFilter { all, available, full }

/// Filter bar untuk memilih tipe unit (Semua / PC / Room)
/// dan status unit (Semua / Available / Full).
class UnitFilterBar extends StatelessWidget {
  final UnitTypeFilter selectedTypeFilter;
  final UnitStatusFilter selectedStatusFilter;
  final ValueChanged<UnitTypeFilter> onTypeFilterChanged;
  final ValueChanged<UnitStatusFilter> onStatusFilterChanged;

  const UnitFilterBar({
    super.key,
    required this.selectedTypeFilter,
    required this.selectedStatusFilter,
    required this.onTypeFilterChanged,
    required this.onStatusFilterChanged,
  });

  Widget _buildPillFilter({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final Color borderColor = selected
        ? AppColors.accentCyan.withValues(alpha: 0.55)
        : AppColors.white.withValues(alpha: 0.08);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingM,
          vertical: AppTheme.paddingS,
        ),
        decoration: BoxDecoration(
          gradient: selected ? Gradients.kAccent : null,
          color: selected
              ? null
              : AppColors.secondaryDark.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: borderColor, width: 1),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter',
          style: AppTextStyle.h4.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPillFilter(
              label: 'Semua',
              selected: selectedTypeFilter == UnitTypeFilter.all,
              onTap: () => onTypeFilterChanged(UnitTypeFilter.all),
            ),
            _buildPillFilter(
              label: 'PC',
              selected: selectedTypeFilter == UnitTypeFilter.pc,
              onTap: () => onTypeFilterChanged(UnitTypeFilter.pc),
            ),
            _buildPillFilter(
              label: 'Room',
              selected: selectedTypeFilter == UnitTypeFilter.room,
              onTap: () => onTypeFilterChanged(UnitTypeFilter.room),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPillFilter(
              label: 'Status: Semua',
              selected: selectedStatusFilter == UnitStatusFilter.all,
              onTap: () => onStatusFilterChanged(UnitStatusFilter.all),
            ),
            _buildPillFilter(
              label: 'Tersedia',
              selected: selectedStatusFilter == UnitStatusFilter.available,
              onTap: () => onStatusFilterChanged(UnitStatusFilter.available),
            ),
            _buildPillFilter(
              label: 'Digunakan',
              selected: selectedStatusFilter == UnitStatusFilter.full,
              onTap: () => onStatusFilterChanged(UnitStatusFilter.full),
            ),
          ],
        ),
      ],
    );
  }
}
