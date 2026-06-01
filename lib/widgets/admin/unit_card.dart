import 'package:flutter/material.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';

class UnitCard extends StatelessWidget {
  final String stationId;
  final String unitId;
  final Map<String, dynamic> entry;
  final VoidCallback? onDetail;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const UnitCard({
    super.key,
    required this.stationId,
    required this.unitId,
    required this.entry,
    this.onDetail,
    this.onEdit,
    this.onDelete,
  });

  // Uses shared `readFirstString` from widgets/utils.dart.

  String? _unitImage(Map<String, dynamic> data) {
    final String? direct = data['foto']?.toString();
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    return null;
  }

  String _typeLabel(String type) {
    final lower = type.toLowerCase();
    if (lower == 'pc') return 'PC';
    if (lower == 'room') return 'Room';
    return type.isEmpty ? 'Unit' : type;
  }

  IconData _typeIcon(String type) {
    final lower = type.toLowerCase();
    if (lower == 'pc') return Icons.computer_rounded;
    if (lower == 'room') return Icons.meeting_room_rounded;
    return Icons.devices_other_rounded;
  }

  Color _statusColor(String status) {
    final String lower = status.trim().toLowerCase();
    if (lower == 'digunakan') return AppColors.errorRed;
    if (lower == 'tersedia') return AppColors.successGreen;
    if (lower == 'perawatan') return AppColors.warningOrange;
    return AppColors.lightText;
  }

  String _statusLabel(String status) {
    final String lower = status.trim().toLowerCase();
    if (lower == 'digunakan') return 'Digunakan';
    if (lower == 'tersedia') return 'Tersedia';
    if (lower == 'perawatan') return 'Perawatan';
    return status.isEmpty ? 'Unknown' : status;
  }

  String _formatCurrency(int value) {
    if (value <= 0) return '-';
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match match) => '${match[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    final String name = entry['namaUnit']?.toString() ?? 'Unit';
    final String type = entry['jenisUnit']?.toString() ?? '';
    final String status = entry['status']?.toString() ?? 'tersedia';

    final int price = entry['hargaPerJam'] is int
        ? entry['hargaPerJam']
        : int.tryParse(entry['hargaPerJam']?.toString() ?? '0') ?? 0;

    final int capacity = entry['kapasitas'] is int
        ? entry['kapasitas']
        : int.tryParse(entry['kapasitas']?.toString() ?? '0') ?? 0;

    final String noPc = entry['noPC']?.toString() ?? '';
    final String jenisRoom = entry['jenisRoom']?.toString() ?? '';

    final List<String> metaParts = [];

    if (type.toLowerCase() == 'pc') {
      if (noPc.isNotEmpty) metaParts.add('PC $noPc');
      if (price > 0) {
        metaParts.add('${_formatCurrency(price)}/jam');
      } else {
        metaParts.add('Tanpa harga');
      }
    } else if (type.toLowerCase() == 'room') {
      if (jenisRoom.isNotEmpty) metaParts.add(jenisRoom);
      if (price > 0) {
        metaParts.add('${_formatCurrency(price)}/jam');
      } else {
        metaParts.add('Tanpa harga');
      }
    } else {
      if (price > 0) {
        metaParts.add('${_formatCurrency(price)}/jam');
      } else {
        metaParts.add('Tanpa harga');
      }
    }

    final Color statusColor = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color: AppColors.secondaryDark.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.08),
          width: 1.1,
        ),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomImageLoader(
                  photoStr: _unitImage(entry),
                  width: 56,
                  height: 56,
                  radius: 14,
                  fallbackIcon: _typeIcon(type),
                ),
                const SizedBox(width: AppTheme.paddingM),
                Expanded(
                  child: Column(
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
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyle.body1.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  metaParts.join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyle.body3.copyWith(
                                    color: AppColors.softGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.paddingM,
                              vertical: AppTheme.paddingXS,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLarge,
                              ),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: AppTextStyle.caption2.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Material(
                      color: AppColors.white.withValues(alpha: 0.03),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.edit_rounded,
                            color: AppColors.softGray,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: AppColors.white.withValues(alpha: 0.03),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.errorRed,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.paddingM),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.paddingM,
                    vertical: AppTheme.paddingS,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: Text(
                    _typeLabel(type),
                    style: AppTextStyle.caption1.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (capacity > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.paddingM,
                      vertical: AppTheme.paddingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    child: Text(
                      '$capacity orang',
                      style: AppTextStyle.caption1.copyWith(
                        color: AppColors.softGray,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
