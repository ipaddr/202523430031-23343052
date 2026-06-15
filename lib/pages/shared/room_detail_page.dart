import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';
import 'package:gamezone/widgets/common/background.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';
import 'package:gamezone/utils/helpers.dart';
import 'station_detail_page.dart' show ViewMode;
import 'package:gamezone/widgets/common/custom_confirm_dialog.dart';
import 'package:gamezone/widgets/common/page_header.dart';

/// Halaman detail room/unit yang digunakan bersama oleh User dan Admin.
/// Aksi berbeda berdasarkan [ViewMode] yang diteruskan via route arguments.
class SharedRoomDetailPage extends StatefulWidget {
  const SharedRoomDetailPage({super.key});

  @override
  State<SharedRoomDetailPage> createState() => _SharedRoomDetailPageState();
}

class _SharedRoomDetailPageState extends State<SharedRoomDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isRouteInitialized = false;
  bool _isDeleting = false;

  String _unitId = '';
  String _stationId = '';
  Map<String, dynamic>? _initialUnitData;
  ViewMode _viewMode = ViewMode.user;
  late Future<Map<String, dynamic>?> _unitFuture;

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
      _unitId = args['unitId']?.toString() ?? '';
      _stationId = args['stationId']?.toString() ?? '';
      _initialUnitData = _toStringKeyMap(args['unitData']);
      final String? modeStr = args['viewMode']?.toString();
      if (modeStr == 'admin') _viewMode = ViewMode.admin;
      if (_unitId.isEmpty) {
        _unitId = _initialUnitData?['id']?.toString() ?? '';
      }
      if (_stationId.isEmpty) {
        _stationId = _initialUnitData?['stationId']?.toString() ?? '';
      }
    }
    _unitFuture = _loadUnitData();
  }

  Map<String, dynamic>? _toStringKeyMap(Object? value) {
    if (value is Map<String, dynamic>) return Map<String, dynamic>.from(value);
    if (value is Map) {
      return value.map((k, dynamic v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadUnitData() async {
    if (_unitId.isEmpty) return _initialUnitData;
    try {
      final DocumentSnapshot snap = await _firestoreService.getUnitById(
        _unitId,
      );
      final Object? raw = snap.data();
      if (raw is Map<String, dynamic>) {
        final data = Map<String, dynamic>.from(raw);
        data['id'] = snap.id;
        return data;
      }
      if (raw is Map) {
        final data = raw.map((k, dynamic v) => MapEntry(k.toString(), v));
        data['id'] = snap.id;
        return data;
      }
    } catch (_) {}
    return _initialUnitData;
  }

  String _unitName(Map<String, dynamic> d) =>
      d['namaUnit']?.toString() ?? 'Detail Unit';

  String _unitType(Map<String, dynamic> d) => d['jenisUnit']?.toString() ?? '';

  bool _isPc(Map<String, dynamic> d) => _unitType(d).toLowerCase() == 'pc';

  bool _isRoom(Map<String, dynamic> d) => _unitType(d).toLowerCase() == 'room';

  String? _unitImage(Map<String, dynamic> d) {
    final v = d['foto']?.toString();
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  String _formatCurrency(int value) => formatCurrencyWithDash(value);

  Color _statusColor(String status) => unitStatusColor(status);

  String _statusLabel(String status) => unitStatusLabel(status);


  List<String> _collectChipValues(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    final Set<String> values = {};
    for (final key in keys) {
      final dynamic raw = data[key];
      if (raw == null) continue;
      if (raw is List) {
        for (final item in raw) {
          final t = item?.toString().trim() ?? '';
          if (t.isNotEmpty) values.add(t);
        }
        continue;
      }
      final t = raw.toString().trim();
      if (t.isEmpty) continue;
      if (t.contains(',')) {
        for (final p in t.split(',')) {
          final c = p.trim();
          if (c.isNotEmpty) values.add(c);
        }
      } else if (t.contains('\n')) {
        for (final p in t.split('\n')) {
          final c = p.trim();
          if (c.isNotEmpty) values.add(c);
        }
      } else {
        values.add(t);
      }
    }
    return values.toList(growable: false);
  }

  Future<void> _openEditUnit(Map<String, dynamic> unitData) async {
    try {
      await Navigator.pushNamed(
        context,
        '/admin-room-form',
        arguments: {
          'mode': 'edit',
          'stationId': _stationId,
          'unitId': _unitId,
          'unitData': unitData,
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warningOrange,
          content: Text(
            'Form edit unit belum tersedia.',
            style: AppTextStyle.body3.copyWith(color: AppColors.white),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteUnit(BuildContext context, String unitName) async {
    if (_unitId.isEmpty || _isDeleting) return;
    final messenger = ScaffoldMessenger.of(context);

    final bool confirmed = await showCustomConfirmDialog(
      context: context,
      title: 'Hapus Unit',
      content: 'Unit "$unitName" akan dihapus permanen. Lanjutkan?',
      confirmLabel: 'Hapus',
      isDestructive: true,
    );

    if (!confirmed) return;

    setState(() => _isDeleting = true);
    try {
      await _firestoreService.deleteUnit(_unitId);
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.successGreen,
          content: Text(
            'Unit "$unitName" berhasil dihapus.',
            style: AppTextStyle.body3.copyWith(color: AppColors.white),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorRed,
          content: Text(
            'Gagal menghapus unit: $e',
            style: AppTextStyle.body3.copyWith(color: AppColors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _openBooking(Map<String, dynamic> unitData) {
    Navigator.pushNamed(
      context,
      '/booking-form',
      arguments: {
        'unitId': _unitId,
        'stationId': _stationId,
        'unitData': unitData,
      },
    );
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
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _unitFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentCyan,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildErrorView('Gagal memuat detail unit.');
                  }
                  final unitData = snapshot.data ?? _initialUnitData;
                  if (unitData == null || unitData.isEmpty) {
                    return _buildErrorView('Data unit tidak ditemukan.');
                  }
                  return _buildBody(unitData);
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

  Widget _buildBody(Map<String, dynamic> unitData) {
    final String unitName = _unitName(unitData);
    final bool isPc = _isPc(unitData);
    final bool isRoom = _isRoom(unitData);
    final String status = readUnitStatus(unitData);
    final int price = unitData['hargaPerJam'] is int
        ? unitData['hargaPerJam']
        : int.tryParse(unitData['hargaPerJam']?.toString() ?? '0') ?? 0;
    final String badge = _unitType(unitData).toUpperCase();
    final String unitTypeLabel = isPc
        ? 'PC'
        : isRoom
        ? 'ROOM'
        : badge;
    final String? imageUrl = _unitImage(unitData);
    final List<String> facilities = _collectChipValues(unitData, const [
      'fasilitas',
    ]);
    final List<String> games = _collectChipValues(unitData, const ['games']);
    final String kapasitasStr =
        unitData['kapasitas'] != null &&
            unitData['kapasitas'].toString().trim().isNotEmpty
        ? '${unitData['kapasitas']} orang'
        : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(title: 'Detail Unit'),

        Expanded(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              _buildImageSection(imageUrl, badge, status, isPc),
              const SizedBox(height: 16),

              _buildInfoSection(
                unitData,
                unitName,
                unitTypeLabel,
                isPc,
                isRoom,
                price,
                kapasitasStr,
                status,
              ),
              const SizedBox(height: 16),

              _buildDetailSection(unitData, isPc, isRoom, kapasitasStr, status),
              const SizedBox(height: 16),

              _buildFacilitiesSection(facilities, isRoom),
              const SizedBox(height: 16),

              _buildGamesSection(games),

              if (isPc) ...[
                const SizedBox(height: 16),
                _buildPcSpecSummary(unitData),
              ],

              const SizedBox(height: 30),

              if (_viewMode == ViewMode.user)
                _buildUserActions(unitData)
              else
                _buildAdminActions(unitData, unitName),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required Widget child}) {
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
      child: child,
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle, Widget? action}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyle.h4.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
                ),
              ],
            ],
          ),
        ),
        action ?? const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(icon, color: AppColors.accentCyan, size: 18),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyle.caption2.copyWith(
                    color: AppColors.softGray.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyle.body1.copyWith(
                    color: AppColors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, {IconData icon = Icons.check_rounded}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.paddingM,
        vertical: AppTheme.paddingS,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentCyan, size: 15),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTextStyle.caption1.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(
    String? imageUrl,
    String badge,
    String status,
    bool isPc,
  ) {
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
        aspectRatio: 1.45,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomImageLoader(
                photoStr: imageUrl,
                width: double.infinity,
                height: double.infinity,
                radius: AppTheme.radiusXL,
                fallbackIcon: isPc
                    ? Icons.computer_rounded
                    : Icons.meeting_room_rounded,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.primaryDarkNavy.withValues(alpha: 0.16),
                        AppColors.primaryDarkNavy.withValues(alpha: 0.66),
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.paddingM,
                    vertical: AppTheme.paddingS,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDarkNavy.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: Text(
                    badge.toUpperCase(),
                    style: AppTextStyle.caption2.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
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
                    color: _statusColor(status).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: _statusColor(status).withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: AppTextStyle.caption2.copyWith(
                      color: _statusColor(status),
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

  Widget _buildInfoSection(
    Map<String, dynamic> unitData,
    String unitName,
    String unitTypeLabel,
    bool isPc,
    bool isRoom,
    int price,
    String kapasitasStr,
    String status,
  ) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Informasi Utama',
            subtitle: 'Data ringkas unit yang sedang dipilih.',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unitName,
                      style: AppTextStyle.h4.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      unitTypeLabel,
                      style: AppTextStyle.body3.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(price),
                      textAlign: TextAlign.right,
                      style: AppTextStyle.h4.copyWith(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'per jam',
                      style: AppTextStyle.caption1.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoTile(
                label: isRoom ? 'Jenis Room' : 'Nomor PC',
                value: isRoom
                    ? (unitData['jenisRoom']?.toString() ?? '-')
                    : (unitData['noPC']?.toString() ?? '-'),
                icon: isRoom
                    ? Icons.meeting_room_rounded
                    : Icons.computer_rounded,
              ),
              if (isRoom)
                _buildInfoTile(
                  label: 'Kapasitas',
                  value: kapasitasStr,
                  icon: Icons.groups_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
    Map<String, dynamic> unitData,
    bool isPc,
    bool isRoom,
    String kapasitasStr,
    String status,
  ) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            isRoom ? 'Detail Room' : 'Detail PC',
            subtitle: isRoom
                ? 'Informasi teknis ruangan yang tersedia.'
                : 'Informasi perangkat PC yang dipakai.',
          ),
          const SizedBox(height: 16),
          if (isPc)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _buildInfoTile(
                  label: 'Processor',
                  value: unitData['processor']?.toString() ?? '-',
                  icon: Icons.memory_rounded,
                ),
                _buildInfoTile(
                  label: 'GPU',
                  value: unitData['gpu']?.toString() ?? '-',
                  icon: Icons.videogame_asset_rounded,
                ),
                _buildInfoTile(
                  label: 'RAM',
                  value: unitData['ram']?.toString() ?? '-',
                  icon: Icons.storage_rounded,
                ),
                _buildInfoTile(
                  label: 'Monitor',
                  value: unitData['monitor']?.toString() ?? '-',
                  icon: Icons.desktop_windows_rounded,
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    label: 'Kapasitas',
                    value: kapasitasStr,
                    icon: Icons.groups_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoTile(
                    label: 'Jenis Room',
                    value: unitData['jenisRoom']?.toString() ?? '-',
                    icon: Icons.meeting_room_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoTile(
              label: 'Status',
              value: _statusLabel(status),
              icon: Icons.verified_rounded,
            ),
            const SizedBox(height: 12),
            _buildInfoTile(
              label: 'Deskripsi',
              value: unitData['deskripsi']?.toString() ?? '-',
              icon: Icons.description_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFacilitiesSection(List<String> facilities, bool isRoom) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            isRoom ? 'Fasilitas Room' : 'Fasilitas PC',
            subtitle: isRoom
                ? 'Daftar fasilitas ruangan yang bisa digunakan.'
                : 'Daftar fasilitas PC yang tersedia.',
          ),
          const SizedBox(height: 16),
          if (facilities.isEmpty)
            Text(
              'Belum ada data fasilitas.',
              style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: facilities.map((item) => _buildChip(item)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildGamesSection(List<String> games) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Daftar Game',
            subtitle: 'Game terinstall pada unit ini.',
          ),
          const SizedBox(height: 16),
          if (games.isEmpty)
            Text(
              'Belum ada game terinstall.',
              style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: games
                  .map(
                    (item) =>
                        _buildChip(item, icon: Icons.sports_esports_rounded),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPcSpecSummary(Map<String, dynamic> unitData) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Ringkasan Spesifikasi PC',
            subtitle: 'Empat spesifikasi utama yang paling sering dicek.',
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _buildInfoTile(
                label: 'Processor',
                value: unitData['processor']?.toString() ?? '-',
                icon: Icons.memory_rounded,
              ),
              _buildInfoTile(
                label: 'GPU',
                value: unitData['gpu']?.toString() ?? '-',
                icon: Icons.videogame_asset_rounded,
              ),
              _buildInfoTile(
                label: 'RAM',
                value: unitData['ram']?.toString() ?? '-',
                icon: Icons.storage_rounded,
              ),
              _buildInfoTile(
                label: 'Monitor',
                value: unitData['monitor']?.toString() ?? '-',
                icon: Icons.desktop_windows_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tombol aksi untuk pemesanan atau pengelolaan unit

  /// Tombol aksi untuk USER: Booking Sekarang
  Widget _buildUserActions(Map<String, dynamic> unitData) {
    final String status = (unitData['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final bool canBook = status != 'perawatan' &&
        status != 'maintenance' &&
        status != 'tidak_aktif' &&
        status != 'tidak_tersedia' &&
        status != 'inactive';

    String buttonText = 'Booking Sekarang';
    if (status == 'perawatan') {
      buttonText = 'Unit Sedang Perawatan';
    } else if (status == 'tidak_aktif' ||
        status == 'tidak_tersedia' ||
        status == 'inactive') {
      buttonText = 'Unit Tidak Tersedia';
    }

    return GestureDetector(
      onTap: canBook ? () => _openBooking(unitData) : null,
      child: Opacity(
        opacity: canBook ? 1.0 : 0.45,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: canBook ? Gradients.kAccent : null,
            color: canBook ? null : const Color(0xFF334155),
            borderRadius: BorderRadius.circular(16),
            boxShadow: canBook ? AppTheme.shadowMedium : null,
          ),
          child: Text(
            buttonText,
            textAlign: TextAlign.center,
            style: AppTextStyle.buttonMedium.copyWith(
              color: canBook ? AppColors.white : AppColors.softGray,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Tombol aksi untuk ADMIN: Edit Room + Hapus Room
  Widget _buildAdminActions(Map<String, dynamic> unitData, String unitName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _openEditUnit(unitData),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentCyan.withValues(alpha: 0.15),
            foregroundColor: AppColors.accentCyan,
            shadowColor: Colors.transparent,
            side: const BorderSide(color: AppColors.accentCyan, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text(
            'Edit Unit',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isDeleting
              ? null
              : () => _confirmDeleteUnit(context, unitName),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.errorRed.withValues(alpha: 0.15),
            foregroundColor: AppColors.errorRed,
            shadowColor: Colors.transparent,
            side: const BorderSide(color: AppColors.errorRed, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: Text(
            _isDeleting ? 'Menghapus...' : 'Hapus Unit',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
