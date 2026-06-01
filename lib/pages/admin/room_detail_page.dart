import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';

import 'package:gamezone/widgets/background.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';
import 'package:gamezone/utils/helpers.dart';

class RoomDetailPage extends StatefulWidget {
  const RoomDetailPage({super.key});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isRouteInitialized = false;
  bool _isDeleting = false;

  String _unitId = '';
  String _stationId = '';
  Map<String, dynamic>? _initialUnitData;
  late Future<Map<String, dynamic>?> _unitFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isRouteInitialized) {
      return;
    }

    _isRouteInitialized = true;
    _parseRouteArguments();
  }

  void _parseRouteArguments() {
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map) {
      _unitId = arguments['unitId']?.toString() ?? '';
      _stationId = arguments['stationId']?.toString() ?? '';

      _initialUnitData = _toStringKeyMap(arguments['unitData']);

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
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map((key, dynamic item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  Future<Map<String, dynamic>?> _loadUnitData() async {
    if (_unitId.isEmpty) {
      return _initialUnitData;
    }

    try {
      final DocumentSnapshot snapshot = await _firestoreService.getUnitById(
        _unitId,
      );
      final Object? rawData = snapshot.data();

      if (rawData is Map<String, dynamic>) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
        data['id'] = snapshot.id;
        return data;
      }

      if (rawData is Map) {
        final Map<String, dynamic> data = rawData.map(
          (key, dynamic item) => MapEntry(key.toString(), item),
        );
        data['id'] = snapshot.id;
        return data;
      }
    } catch (_) {
      // Fallback ke data yang diteruskan dari halaman sebelumnya.
    }

    return _initialUnitData;
  }

  String _unitName(Map<String, dynamic> data) {
    return data['namaUnit']?.toString() ?? 'Detail Unit';
  }

  String _unitType(Map<String, dynamic> data) {
    return data['jenisUnit']?.toString() ?? '';
  }

  bool _isPc(Map<String, dynamic> data) {
    return _unitType(data).toLowerCase() == 'pc';
  }

  bool _isRoom(Map<String, dynamic> data) {
    return _unitType(data).toLowerCase() == 'room';
  }

  String? _unitImage(Map<String, dynamic> data) {
    final String? direct = data['foto']?.toString();
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    return null;
  }

  String _formatCurrency(int value) {
    if (value <= 0) return '-';
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match match) => '${match[1]}.')}';
  }

  String _readTypeBadge(Map<String, dynamic> data) {
    return _unitType(data).toUpperCase();
  }

  Color _statusColor(String status) {
    final String lower = status.trim().toLowerCase();
    if (lower == 'digunakan') return AppColors.errorRed;
    if (lower == 'tersedia') return AppColors.successGreen;
    if (lower == 'perawatan') return AppColors.warningOrange;
    return AppColors.softGray;
  }

  String _statusLabel(String status) {
    final String lower = status.trim().toLowerCase();
    if (lower == 'digunakan') return 'Digunakan';
    if (lower == 'tersedia') return 'Tersedia';
    if (lower == 'perawatan') return 'Perawatan';
    return status.isEmpty ? 'Unknown' : status;
  }

  List<String> _collectChipValues(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    final Set<String> values = <String>{};

    for (final String key in keys) {
      final dynamic rawValue = data[key];
      if (rawValue == null) continue;

      if (rawValue is List) {
        for (final Object? item in rawValue) {
          final String text = item?.toString().trim() ?? '';
          if (text.isNotEmpty) values.add(text);
        }
        continue;
      }

      final String text = rawValue.toString().trim();
      if (text.isEmpty) continue;

      if (text.contains(',')) {
        for (final String part in text.split(',')) {
          final String chip = part.trim();
          if (chip.isNotEmpty) values.add(chip);
        }
      } else if (text.contains('\n')) {
        for (final String part in text.split('\n')) {
          final String chip = part.trim();
          if (chip.isNotEmpty) values.add(chip);
        }
      } else {
        values.add(text);
      }
    }

    return values.toList(growable: false);
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
    if (_unitId.isEmpty || _isDeleting) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.primaryDarkNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            side: BorderSide(
              color: AppColors.accentCyan.withValues(alpha: 0.12),
            ),
          ),
          title: Text(
            'Hapus Unit',
            style: AppTextStyle.h4.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Unit "$unitName" akan dihapus permanen. Lanjutkan?',
            style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Batal',
                style: AppTextStyle.buttonSmall.copyWith(
                  color: AppColors.softGray,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

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
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.accentCyan),
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
    final String unitType = _unitType(unitData);
    final bool isPc = _isPc(unitData);
    final bool isRoom = _isRoom(unitData);
    final String status = readUnitStatus(unitData);
    final int price = unitData['hargaPerJam'] is int
        ? unitData['hargaPerJam']
        : int.tryParse(unitData['hargaPerJam']?.toString() ?? '0') ?? 0;
    final String badge = _readTypeBadge(unitData);
    final String unitTypeLabel = isPc
        ? 'PC'
        : isRoom
        ? 'ROOM'
        : unitType.toUpperCase();
    final String? imageUrl = _unitImage(unitData);

    final List<String> facilities = _collectChipValues(unitData, const [
      'fasilitas',
    ]);
    final List<String> games = _collectChipValues(unitData, const ['games']);

    final List<String> pcSpecs = isPc
        ? [
            unitData['processor']?.toString() ?? '-',
            unitData['gpu']?.toString() ?? '-',
            unitData['ram']?.toString() ?? '-',
            unitData['monitor']?.toString() ?? '-',
          ]
        : <String>[];

    final String kapasitasStr =
        unitData['kapasitas'] != null &&
            unitData['kapasitas'].toString().trim().isNotEmpty
        ? '${unitData['kapasitas']} orang'
        : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HEADER SECTION (Sticky)
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
              const Expanded(
                child: Text(
                  'Detail Unit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Scrollable Content
        Expanded(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              // IMAGE SECTION
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
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
                                      AppColors.primaryDarkNavy.withValues(
                                        alpha: 0.16,
                                      ),
                                      AppColors.primaryDarkNavy.withValues(
                                        alpha: 0.66,
                                      ),
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
                                  color: AppColors.primaryDarkNavy.withValues(
                                    alpha: 0.78,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge,
                                  ),
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
                                  color: _statusColor(
                                    status,
                                  ).withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge,
                                  ),
                                  border: Border.all(
                                    color: _statusColor(
                                      status,
                                    ).withValues(alpha: 0.18),
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
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // INFO SECTION
              _buildSectionCard(
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
                    // Informasi Unit
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
              ),
              const SizedBox(height: 16),

              // DETAIL SECTION
              // Detail Unit
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      isRoom ? 'Detail Room' : 'Detail PC',
                      subtitle: isRoom
                          ? 'Informasi teknis ruangan yang tersedia.'
                          : 'Informasi perangkat PC yang dipakai admin.',
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
              ),
              const SizedBox(height: 16),

              // FASILITAS SECTION
              // Fasilitas
              _buildSectionCard(
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
                        style: AppTextStyle.body3.copyWith(
                          color: AppColors.softGray,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: facilities
                            .map((String item) => _buildChip(item))
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // GAME SECTION
              // Game
              _buildSectionCard(
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
                        style: AppTextStyle.body3.copyWith(
                          color: AppColors.softGray,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: games
                            .map(
                              (String item) => _buildChip(
                                item,
                                icon: Icons.sports_esports_rounded,
                              ),
                            )
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
              if (isPc) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        'Ringkasan Spesifikasi PC',
                        subtitle:
                            'Empat spesifikasi utama yang paling sering dicek admin.',
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
                            value: pcSpecs[0],
                            icon: Icons.memory_rounded,
                          ),
                          _buildInfoTile(
                            label: 'GPU',
                            value: pcSpecs[1],
                            icon: Icons.videogame_asset_rounded,
                          ),
                          _buildInfoTile(
                            label: 'RAM',
                            value: pcSpecs[2],
                            icon: Icons.storage_rounded,
                          ),
                          _buildInfoTile(
                            label: 'Monitor',
                            value: pcSpecs[3],
                            icon: Icons.desktop_windows_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _openEditUnit(unitData),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan.withValues(alpha: 0.15),
                  foregroundColor: AppColors.accentCyan,
                  shadowColor: Colors.transparent,
                  side: const BorderSide(
                    color: AppColors.accentCyan,
                    width: 1.2,
                  ),
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
          ),
        ),
      ],
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
                    return _buildLoadingView();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorView('Gagal memuat detail unit.');
                  }

                  final Map<String, dynamic>? unitData =
                      snapshot.data ?? _initialUnitData;
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
}
