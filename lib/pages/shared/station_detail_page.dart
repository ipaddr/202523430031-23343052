import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';
import 'package:gamezone/widgets/background.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';

// Menentukan konteks tampilan halaman: user hanya bisa lihat, admin bisa kelola.
enum ViewMode { user, admin }

/// Halaman detail station yang digunakan bersama oleh User dan Admin.
/// Aksi berbeda berdasarkan [ViewMode] yang diteruskan via route arguments.
class StationDetailPage extends StatefulWidget {
  const StationDetailPage({super.key});

  @override
  State<StationDetailPage> createState() => _StationDetailPageState();
}

class _StationDetailPageState extends State<StationDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isRouteInitialized = false;
  String _stationId = '';
  Map<String, dynamic>? _initialStationData;
  ViewMode _viewMode = ViewMode.user;
  late Future<_StationDetailData> _dataFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRouteInitialized) return;
    _isRouteInitialized = true;
    _parseRouteArguments();
  }

  void _parseRouteArguments() {
    final Object? args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _stationId = args['stationId']?.toString() ?? '';
      _initialStationData = _toStringKeyMap(args['stationData']);
      final String? modeStr = args['viewMode']?.toString();
      if (modeStr == 'admin') _viewMode = ViewMode.admin;
      if (_stationId.isEmpty) {
        _stationId = _initialStationData?['id']?.toString() ?? '';
      }
    }
    _dataFuture = _loadData();
  }

  Map<String, dynamic>? _toStringKeyMap(Object? value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((k, dynamic v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<_StationDetailData> _loadData() async {
    Map<String, dynamic>? station = _initialStationData;

    // Selalu gunakan _stationId (doc.id dari Firestore) sebagai sid utama.
    // Jangan bergantung pada station['id'] hasil fetch karena bisa berbeda.
    final String sid = _stationId.isNotEmpty
        ? _stationId
        : _initialStationData?['id']?.toString() ?? '';

    if (sid.isNotEmpty) {
      try {
        final fetched = await _firestoreService.getStationData(sid);
        if (fetched != null) {
          station = Map<String, dynamic>.from(fetched);
          station['id'] = sid;
        }
      } catch (_) {}
    }
    station ??= _initialStationData ?? {};
    // Pastikan id selalu tersimpan di map station
    if (station['id'] == null || station['id'].toString().isEmpty) {
      station['id'] = sid;
    }

    List<Map<String, dynamic>> units = [];
    if (sid.isNotEmpty) {
      try {
        final snap = await _firestoreService.getUnitsOnceByStation(sid);
        units = snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data() as Map);
          data['id'] = d.id;
          return data;
        }).toList();
        units.sort((a, b) {
          final String an = a['namaUnit']?.toString().toLowerCase() ?? '';
          final String bn = b['namaUnit']?.toString().toLowerCase() ?? '';
          return an.compareTo(bn);
        });
      } catch (_) {}
    }
    return _StationDetailData(station: station, units: units);
  }

  String _stationName(Map<String, dynamic> d) =>
      d['stationName']?.toString() ?? 'Game Station';

  String _stationAddress(Map<String, dynamic> d) =>
      d['alamat']?.toString() ?? 'Alamat tidak tersedia';

  double _stationRating(Map<String, dynamic> d) {
    final v = d['rating'];
    if (v is num) return v.toDouble();
    return 0.0;
  }

  String _stationImage(Map<String, dynamic> d) {
    final foto = d['foto'];
    if (foto is String && foto.trim().isNotEmpty) return foto.trim();
    if (foto is List && foto.isNotEmpty) return foto.first.toString().trim();
    return '';
  }

  bool _isOpenNow(Map<String, dynamic> d) {
    final jam = d['jamOperasional'];
    if (jam == null) return false;
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;

    List<dynamic> hours = [];
    if (jam is List) {
      hours = jam;
    } else if (jam is Map) {
      hours = jam.values.toList();
    }

    for (final entry in hours) {
      if (entry is! Map) continue;
      final String? buka = entry['buka']?.toString();
      final String? tutup = entry['tutup']?.toString();
      if (buka == null || tutup == null) continue;
      final int? openMin = _parseTimeToMinutes(buka);
      final int? closeMin = _parseTimeToMinutes(tutup);
      if (openMin == null || closeMin == null) continue;
      if (nowMinutes >= openMin && nowMinutes <= closeMin) return true;
    }
    return false;
  }

  int? _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  String _formatCurrency(int value) {
    if (value <= 0) return '-';
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Color _statusColor(String status) {
    final lower = status.trim().toLowerCase();
    if (lower == 'digunakan') return AppColors.errorRed;
    if (lower == 'tersedia') return AppColors.successGreen;
    if (lower == 'perawatan') return AppColors.warningOrange;
    return AppColors.softGray;
  }

  String _statusLabel(String status) {
    final lower = status.trim().toLowerCase();
    if (lower == 'digunakan') return 'Digunakan';
    if (lower == 'tersedia') return 'Tersedia';
    if (lower == 'perawatan') return 'Perawatan';
    return status.isEmpty ? 'Unknown' : status;
  }

  String _unitType(Map<String, dynamic> d) => d['jenisUnit']?.toString() ?? '';

  bool _isPc(Map<String, dynamic> d) => _unitType(d).toLowerCase() == 'pc';

  String? _unitImage(Map<String, dynamic> d) {
    final v = d['foto']?.toString();
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  int _unitPrice(Map<String, dynamic> d) {
    final v = d['hargaPerJam'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  void _openRoomDetail(Map<String, dynamic> unitData) {
    Navigator.pushNamed(
      context,
      '/room-detail',
      arguments: {
        'unitId': unitData['id']?.toString() ?? '',
        'stationId': _stationId,
        'unitData': unitData,
        'viewMode': _viewMode == ViewMode.admin ? 'admin' : 'user',
      },
    );
  }

  void _openAddRoom() {
    Navigator.pushNamed(
      context,
      '/admin-room-form',
      arguments: {'mode': 'create', 'stationId': _stationId},
    ).then((_) => setState(() => _dataFuture = _loadData()));
  }

  void _openEditStation() {
    Navigator.pushNamed(context, '/edit-profile');
  }

  void _openManageRooms() {
    Navigator.pushNamed(context, '/admin-room');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameZoneBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: FutureBuilder<_StationDetailData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentCyan,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildErrorView('Gagal memuat detail station.');
                  }
                  final data = snapshot.data;
                  if (data == null) {
                    return _buildErrorView('Data station tidak ditemukan.');
                  }
                  return _buildBody(data);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.softGray,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyle.body1.copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(_StationDetailData data) {
    final station = data.station;
    final units = data.units;
    final name = _stationName(station);
    final address = _stationAddress(station);
    final rating = _stationRating(station);
    final imageUrl = _stationImage(station);
    final isOpen = _isOpenNow(station);
    final totalReview = station['totalReview'] ?? station['reviewsCount'] ?? 0;
    final jamOps = station['jamOperasional'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141B31),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF23304C)),
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Detail Station',
                  style: AppTextStyle.h4.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_viewMode == ViewMode.admin)
                InkWell(
                  onTap: _openEditStation,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.accentCyan,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              _buildStationImageCard(imageUrl, name, isOpen),
              const SizedBox(height: 16),

              _buildInfoCard(name, address, rating, totalReview, isOpen),
              const SizedBox(height: 16),

              if (jamOps != null) ...[
                _buildOperationalHoursCard(jamOps),
                const SizedBox(height: 16),
              ],

              _buildUnitsSection(units),
              const SizedBox(height: 16),

              // Rating & Review Section
              _buildReviewsSection(
                station['id']?.toString() ?? '',
                rating,
                totalReview is num
                    ? totalReview.toInt()
                    : int.tryParse(totalReview?.toString() ?? '0') ?? 0,
              ),
              const SizedBox(height: 16),

              if (_viewMode == ViewMode.admin) ...[
                _buildAdminActions(),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStationImageCard(String imageUrl, String name, bool isOpen) {
    return Container(
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
      child: AspectRatio(
        aspectRatio: 1.6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomImageLoader(
                photoStr: imageUrl.isNotEmpty ? imageUrl : null,
                width: double.infinity,
                height: double.infinity,
                radius: AppTheme.radiusXL,
                fallbackIcon: Icons.storefront_rounded,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.primaryDarkNavy.withValues(alpha: 0.66),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.paddingM,
                    vertical: AppTheme.paddingS,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isOpen ? AppColors.successGreen : AppColors.errorRed)
                            .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color:
                          (isOpen ? AppColors.successGreen : AppColors.errorRed)
                              .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    isOpen ? 'Buka' : 'Tutup',
                    style: AppTextStyle.caption2.copyWith(
                      color: isOpen
                          ? AppColors.successGreen
                          : AppColors.errorRed,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String name,
    String address,
    double rating,
    dynamic totalReview,
    bool isOpen,
  ) {
    final bool hasRating = rating > 0;
    final String reviewText = (totalReview != null && totalReview != 0)
        ? '$totalReview Review'
        : 'Belum ada review';

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color: AppColors.secondaryDark.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.08),
          width: 1.1,
        ),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyle.h4.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF59E0B),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasRating ? rating.toStringAsFixed(1) : '-',
                        style: AppTextStyle.caption1.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reviewText,
                    style: AppTextStyle.caption2.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.softGray,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalHoursCard(dynamic jamOps) {
    List<Map<String, dynamic>> hours = [];
    if (jamOps is List) {
      for (final e in jamOps) {
        if (e is Map) {
          hours.add(e.map((k, dynamic v) => MapEntry(k.toString(), v)));
        }
      }
    } else if (jamOps is Map) {
      jamOps.forEach((k, dynamic v) {
        if (v is Map) {
          final entry = v.map((ek, dynamic ev) => MapEntry(ek.toString(), ev));
          entry['hari'] = k.toString();
          hours.add(entry);
        }
      });
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color: AppColors.secondaryDark.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.08),
          width: 1.1,
        ),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jam Operasional',
            style: AppTextStyle.h4.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Jadwal buka dan tutup game station.',
            style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
          ),
          const SizedBox(height: 16),
          if (hours.isEmpty)
            Text(
              'Belum ada data jam operasional.',
              style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
            )
          else
            ...hours.map((h) {
              final String hari = h['hari']?.toString() ?? '-';
              final String buka = h['buka']?.toString() ?? '-';
              final String tutup = h['tutup']?.toString() ?? '-';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.accentCyan.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.accentCyan,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hari,
                        style: AppTextStyle.body3.copyWith(
                          color: AppColors.softGray,
                        ),
                      ),
                    ),
                    Text(
                      '$buka – $tutup',
                      style: AppTextStyle.body3.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildUnitsSection(List<Map<String, dynamic>> units) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color: AppColors.secondaryDark.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.08),
          width: 1.1,
        ),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daftar Room',
                    style: AppTextStyle.h4.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unit yang tersedia di station ini.',
                    style: AppTextStyle.body3.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                ],
              ),
              if (_viewMode == ViewMode.admin)
                GestureDetector(
                  onTap: _openManageRooms,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.paddingM,
                      vertical: AppTheme.paddingS,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Kelola Room',
                      style: AppTextStyle.caption1.copyWith(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (units.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppTheme.paddingXXL),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    color: AppColors.softGray.withValues(alpha: 0.5),
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Belum ada unit tersedia.',
                    style: AppTextStyle.body3.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                ],
              ),
            )
          else
            ...units.map((unit) => _buildUnitListItem(unit)),
        ],
      ),
    );
  }

  Widget _buildUnitListItem(Map<String, dynamic> unit) {
    final String name = unit['namaUnit']?.toString() ?? 'Unit';
    final bool isPc = _isPc(unit);
    final String status = unit['status']?.toString() ?? 'tersedia';
    final int price = _unitPrice(unit);
    final String? imageUrl = _unitImage(unit);

    return GestureDetector(
      onTap: () => _openRoomDetail(unit),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(AppTheme.paddingM),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: AppColors.accentCyan.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              child: SizedBox(
                width: 64,
                height: 64,
                child: CustomImageLoader(
                  photoStr: imageUrl,
                  width: 64,
                  height: 64,
                  radius: AppTheme.radiusMedium,
                  fallbackIcon: isPc
                      ? Icons.computer_rounded
                      : Icons.meeting_room_rounded,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyle.body1.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPc ? 'PC' : 'ROOM',
                          style: AppTextStyle.caption2.copyWith(
                            color: AppColors.accentCyan,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel(status),
                        style: AppTextStyle.caption2.copyWith(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price > 0 ? '${_formatCurrency(price)}/jam' : '-',
                    style: AppTextStyle.caption1.copyWith(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.softGray,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection(
    String stationId,
    double rating,
    int totalReview,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color: AppColors.secondaryDark.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.08),
          width: 1.1,
        ),
        boxShadow: AppTheme.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rating & Review',
                      style: AppTextStyle.h4.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ulasan dari para gamers GameZone.',
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
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      totalReview > 0 ? rating.toStringAsFixed(1) : '0.0',
                      style: AppTextStyle.caption1.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($totalReview review)',
                      style: AppTextStyle.caption2.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reviews')
                .where('stationId', isEqualTo: stationId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Gagal memuat review.',
                  style: AppTextStyle.body3.copyWith(color: AppColors.errorRed),
                );
              }

              final docs = [...(snapshot.data?.docs ?? const [])];

              // Urutkan review terbaru di paling atas
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final Timestamp? aTime = aData['createdAt'] as Timestamp?;
                final Timestamp? bTime = bData['createdAt'] as Timestamp?;
                final int aMillis = aTime?.millisecondsSinceEpoch ?? 0;
                final int bMillis = bTime?.millisecondsSinceEpoch ?? 0;
                return bMillis.compareTo(aMillis);
              });

              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        color: AppColors.softGray.withValues(alpha: 0.4),
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada review untuk station ini',
                        style: AppTextStyle.body3.copyWith(
                          color: AppColors.softGray,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final String userName =
                      data['userName']?.toString() ?? 'Gamers';
                  final String userPhoto = data['userPhoto']?.toString() ?? '';
                  final int rating = (data['rating'] as num?)?.toInt() ?? 5;
                  final String comment = data['comment']?.toString() ?? '';
                  final Timestamp? createdAt = data['createdAt'] as Timestamp?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomUserAvatar(
                          photoUrl: userPhoto.isNotEmpty ? userPhoto : null,
                          size: 36,
                          hasBorder: false,
                        ),
                        const SizedBox(width: 12),
                        // Konten Review
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      userName,
                                      style: AppTextStyle.body2.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    _formatReviewDate(createdAt),
                                    style: AppTextStyle.caption2.copyWith(
                                      color: AppColors.softGray,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Baris Bintang
                              Row(
                                children: List.generate(5, (starIdx) {
                                  return Icon(
                                    Icons.star_rounded,
                                    color: starIdx < rating
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF475569),
                                    size: 14,
                                  );
                                }),
                              ),
                              const SizedBox(height: 6),
                              // Komentar
                              Text(
                                comment,
                                style: AppTextStyle.body3.copyWith(
                                  color: const Color(0xFFCBD5E1),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatReviewDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Baru saja';
    final DateTime date = timestamp.toDate();
    final List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agt',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildAdminActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _openAddRoom,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: Gradients.kAccent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.shadowMedium,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, color: AppColors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Tambah Room',
                  style: AppTextStyle.buttonMedium.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StationDetailData {
  final Map<String, dynamic> station;
  final List<Map<String, dynamic>> units;

  const _StationDetailData({required this.station, required this.units});
}
