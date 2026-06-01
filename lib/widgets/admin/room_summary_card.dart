import 'package:flutter/material.dart';

import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/widgets/admin/admin_stat_card.dart';
import 'package:gamezone/widgets/admin/room_status_chart.dart';

/// Kartu ringkasan statistik unit station: jumlah total unit, PC, Room,
/// unit available, dan grafik status unit.
class RoomSummaryCard extends StatelessWidget {
  final int totalUnit;
  final int totalPc;
  final int totalRoom;
  final int available;
  final int full;

  const RoomSummaryCard({
    super.key,
    required this.totalUnit,
    required this.totalPc,
    required this.totalRoom,
    required this.available,
    required this.full,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ringkasan Unit',
                    style: AppTextStyle.h4.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Statistik unit milik station yang sedang dikelola.',
                    style: AppTextStyle.body3.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.paddingM),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.25,
          children: [
            AdminStatCard(
              icon: Icons.devices_other_rounded,
              title: 'Total Unit',
              value: totalUnit.toString(),
              iconColor: AppColors.accentCyan,
            ),
            AdminStatCard(
              icon: Icons.computer_rounded,
              title: 'PC',
              value: totalPc.toString(),
              iconColor: AppColors.accentCyan,
            ),
            AdminStatCard(
              icon: Icons.meeting_room_rounded,
              title: 'Room',
              value: totalRoom.toString(),
              iconColor: AppColors.accentCyan,
            ),
            AdminStatCard(
              icon: Icons.check_circle_rounded,
              title: 'Tersedia',
              value: available.toString(),
              iconColor: AppColors.successGreen,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Visual status unit.
        UnitStatusChart(totalUnit: totalUnit, full: full, available: available),
      ],
    );
  }
}
