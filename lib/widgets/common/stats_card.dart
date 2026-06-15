import 'package:flutter/material.dart';

import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';
import 'package:gamezone/utils/helpers.dart';

class StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const StatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color: AppColors.secondaryDark.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.paddingS),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: AppTheme.paddingL),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.caption1.copyWith(
              color: AppColors.lightText,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppTheme.paddingXS),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.h3.copyWith(
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class TodayBookingCard extends StatelessWidget {
  final String value;
  final String title;

  const TodayBookingCard({
    super.key,
    required this.value,
    this.title = 'Booking Hari Ini',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: Gradients.kAccent,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDarkNavy.withValues(alpha: 0.25),
              AppColors.secondaryDark.withValues(alpha: 0.72),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.paddingM,
                    vertical: AppTheme.paddingS,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Text(
                    'Hari Ini',
                    style: AppTextStyle.caption2.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.white.withValues(alpha: 0.9),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingL),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.caption1.copyWith(
                color: AppColors.white.withValues(alpha: 0.84),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: AppTheme.paddingXS),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.h2.copyWith(
                color: AppColors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RevenueCard extends StatelessWidget {
  final int amount;
  final String title;

  const RevenueCard({
    super.key,
    required this.amount,
    this.title = 'Total Pemasukan',
  });

  String _formatRupiah(int value) => formatRupiah(value);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.gradientCyanToBlue,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDarkNavy.withValues(alpha: 0.28),
              AppColors.secondaryDark.withValues(alpha: 0.78),
            ],
          ),
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingS),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.paddingM),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.caption1.copyWith(
                      color: AppColors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingL),
            Text(
              _formatRupiah(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.h2.copyWith(
                color: AppColors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
            const SizedBox(height: AppTheme.paddingS),
            Text(
              'Pemasukan terkini dari transaksi aktif',
              style: AppTextStyle.caption2.copyWith(
                color: AppColors.white.withValues(alpha: 0.76),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RatingCard extends StatelessWidget {
  final double rating;
  final String title;

  const RatingCard({
    super.key,
    required this.rating,
    this.title = 'Rating Game Station',
  });

  String _formatRating(double value) {
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.gradientBlueToBlack,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.shadowLarge,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDarkNavy.withValues(alpha: 0.24),
              AppColors.secondaryDark.withValues(alpha: 0.76),
            ],
          ),
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.paddingS),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.paddingM),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.caption1.copyWith(
                      color: AppColors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingL),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatRating(rating),
                  style: AppTextStyle.h2.copyWith(
                    color: AppColors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(width: AppTheme.paddingS),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '⭐',
                    style: AppTextStyle.h4.copyWith(
                      color: AppColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingS),
            Text(
              'Skor rata-rata dari performa dan ulasan pengguna',
              style: AppTextStyle.caption2.copyWith(
                color: AppColors.white.withValues(alpha: 0.76),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
