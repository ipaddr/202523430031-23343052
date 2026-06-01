import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';

class UnitStatusChart extends StatelessWidget {
  final int totalUnit;
  final int full;
  final int available;
  final String title;

  const UnitStatusChart({
    super.key,
    required this.totalUnit,
    required this.full,
    required this.available,
    this.title = 'Status Unit',
  });

  int get _safeTotal => totalUnit <= 0 ? full + available : totalUnit;

  double get _fullValue => full.toDouble().clamp(0, _safeTotal.toDouble());

  double get _availableValue =>
      available.toDouble().clamp(0, _safeTotal.toDouble());

  double get _totalValue => _safeTotal.toDouble();

  @override
  Widget build(BuildContext context) {
    final double chartRadius = 45;
    final bool hasData = _totalValue > 0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        gradient: AppColors.gradientDarkToSecondary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: AppTheme.shadowMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingS),
                decoration: BoxDecoration(
                  gradient: Gradients.kAccent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: const Icon(
                  Icons.devices_other_rounded,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.caption1.copyWith(
                        color: AppColors.softGray,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total Unit',
                      style: AppTextStyle.h4.copyWith(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.paddingM,
                  vertical: AppTheme.paddingS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  _totalValue.toInt().toString(),
                  style: AppTextStyle.buttonSmall.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.paddingL),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          startDegreeOffset: -90,
                          sectionsSpace: 4,
                          centerSpaceRadius: chartRadius,
                          sections: hasData
                              ? [
                                  PieChartSectionData(
                                    value: _fullValue,
                                    color: AppColors.errorRed,
                                    radius: 16,
                                    showTitle: false,
                                  ),
                                  PieChartSectionData(
                                    value: _availableValue,
                                    color: AppColors.successGreen,
                                    radius: 16,
                                    showTitle: false,
                                  ),
                                ]
                              : [
                                  PieChartSectionData(
                                    value: 1,
                                    color: AppColors.softGray.withValues(
                                      alpha: 0.2,
                                    ),
                                    radius: 16,
                                    showTitle: false,
                                  ),
                                ],
                          pieTouchData: PieTouchData(enabled: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _totalValue.toInt().toString(),
                            style: AppTextStyle.h2.copyWith(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Unit',
                            style: AppTextStyle.caption2.copyWith(
                              color: AppColors.softGray,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.paddingL),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _StatusLegendItem(
                      label: 'Digunakan',
                      value: _fullValue.toInt(),
                      color: AppColors.errorRed,
                    ),
                    const SizedBox(height: AppTheme.paddingM),
                    _StatusLegendItem(
                      label: 'Tersedia',
                      value: _availableValue.toInt(),
                      color: AppColors.successGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusLegendItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatusLegendItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingM,
        vertical: AppTheme.paddingM,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.paddingM),
          Expanded(
            child: Text(
              label,
              style: AppTextStyle.body3.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.paddingS),
          Text(
            value.toString(),
            style: AppTextStyle.body2.copyWith(
              color: AppColors.softGray,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
