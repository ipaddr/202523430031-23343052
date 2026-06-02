import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:gamezone/services/auth_service.dart';
import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/styles/gradients.dart';
import 'package:gamezone/widgets/background.dart';
import 'package:gamezone/widgets/admin/admin_bottom_navbar.dart';
import 'package:gamezone/widgets/admin/admin_header.dart';
import 'package:gamezone/widgets/admin/unit_card.dart';
import 'package:gamezone/utils/helpers.dart';
import 'package:gamezone/widgets/common/custom_empty_state.dart';
import 'package:gamezone/widgets/common/custom_search_bar.dart';
// util widgets are used in extracted widgets

/// Halaman pengelolaan unit milik station aktif admin.
class RoomPage extends StatefulWidget {
  final bool isNestedTab;
  final User? initialCurrentUser;
  final Map<String, dynamic>? initialStation;
  final Map<String, dynamic>? initialUserData;

  const RoomPage({
    super.key,
    this.isNestedTab = false,
    this.initialCurrentUser,
    this.initialStation,
    this.initialUserData,
  });

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  static const String _roomDetailRoute = '/room-detail';
  static const String _roomFormRoute = '/admin-room-form';

  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final DashboardService _dashboardService = DashboardService();

  late Future<_RoomPageData?> _stationFuture;
  DateTime? _localLastOpened;
  Stream<QuerySnapshot>? _unitsStream;
  String? _cachedStationId;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedType = 'Semua';
  String _selectedStatus = 'Semua Status';
  String _selectedJenisRoom = 'Semua Room';
  String _selectedSort = 'Terbaru';

  @override
  void initState() {
    super.initState();
    _stationFuture = _loadStationData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_RoomPageData?> _loadStationData() async {
    final User? currentUser =
        widget.initialCurrentUser ?? await _authService.resolveCurrentUser();
    if (currentUser == null) {
      return null;
    }

    final Map<String, dynamic>? userData =
        widget.initialUserData ??
        await _firestoreService.getUserData(currentUser.uid);
    final String? userName =
        userData?['nama']?.toString() ??
        userData?['name']?.toString() ??
        currentUser.displayName;
    final String? userEmail =
        userData?['email']?.toString() ?? currentUser.email;

    if (widget.initialStation != null) {
      return _RoomPageData(
        currentUser: currentUser,
        station: widget.initialStation!,
        userData: userData,
      );
    }

    final Map<String, dynamic>? station = await _firestoreService
        .getStationByOwnerId(currentUser.uid, email: userEmail, name: userName);

    if (station == null) {
      return null;
    }

    return _RoomPageData(
      currentUser: currentUser,
      station: station,
      userData: userData,
    );
  }

  void _handleTabSelection(BuildContext context, int index) {
    if (index == 1) {
      return;
    }

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/admin-dashboard');
      return;
    }

    if (index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warningOrange,
          content: Text(
            'Halaman booking belum dihubungkan dari Room Page.',
            style: AppTextStyle.body3.copyWith(color: AppColors.white),
          ),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.pushReplacementNamed(context, '/edit-profile');
    }
  }

  List<_UnitEntry> _mapDocs(List<QueryDocumentSnapshot<Object?>> docs) {
    final mapped = _dashboardService.mapUnitDocs(docs);
    return mapped
        .map(
          (m) => _UnitEntry(
            id: m['id'] as String,
            data: m['data'] as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  _RoomSummary _buildSummary(List<_UnitEntry> entries) {
    final mapped = entries
        .map((e) => {'id': e.id, 'data': e.data})
        .toList(growable: false);
    final overview = _dashboardService.buildUnitOverviewFromMappedEntries(
      mapped,
    );
    return _RoomSummary(
      totalUnit: overview.totalUnit,
      totalPc: overview.totalPc,
      totalRoom: overview.totalRoom,
      full: overview.full,
      available: overview.available,
    );
  }

  void _openAddForm(
    BuildContext context,
    String stationId, {
    String? unitType,
  }) {
    final args = {'mode': 'create', 'stationId': stationId};
    if (unitType != null && unitType.isNotEmpty) args['type'] = unitType;
    Navigator.pushNamed(context, _roomFormRoute, arguments: args);
  }

  void _openEditForm(BuildContext context, String stationId, _UnitEntry entry) {
    Navigator.pushNamed(
      context,
      _roomFormRoute,
      arguments: {
        'mode': 'edit',
        'stationId': stationId,
        'unitId': entry.id,
        'unitData': entry.data,
      },
    );
  }

  void _openDetailPage(
    BuildContext context,
    String stationId,
    _UnitEntry entry,
  ) {
    Navigator.pushNamed(
      context,
      _roomDetailRoute,
      arguments: {
        'stationId': stationId,
        'unitId': entry.id,
        'unitData': entry.data,
        'viewMode': 'admin',
      },
    );
  }

  String _normalizeStationType(String? stationType) {
    return (stationType ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'\s+|-'),
      '_',
    );
  }

  bool _supportsPcAndRoomSelection(String? stationType) {
    final String normalizedType = _normalizeStationType(stationType);
    return normalizedType == 'gaming_center' ||
        normalizedType == 'esports_center';
  }

  // Aksi Unit
  Future<void> _confirmDeleteUnit(
    BuildContext context,
    String unitId,
    String unitName,
  ) async {
    // Capture ScaffoldMessenger early to avoid using BuildContext across async gaps.
    final messenger = ScaffoldMessenger.of(context);

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

    try {
      await _firestoreService.deleteUnit(unitId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.successGreen,
          content: Text(
            'Unit "$unitName" berhasil dihapus.',
            style: AppTextStyle.body3.copyWith(color: AppColors.white),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorRed,
          content: Text(
            'Gagal menghapus unit: $e',
            style: AppTextStyle.body3.copyWith(color: AppColors.white),
          ),
        ),
      );
    }
  }

  Future<void> _showNotifications(
    BuildContext context,
    _RoomPageData pageData,
  ) async {
    String stationId = pageData.station['id']?.toString() ?? '';
    String stationName =
        pageData.station['namaStation']?.toString() ??
        pageData.station['stationName']?.toString() ??
        'GameZone Station';

    if (stationId.isEmpty) {
      final Map<String, dynamic>? fallbackStation = await _firestoreService
          .getStationByOwnerId(
            pageData.currentUser.uid,
            email: pageData.currentUser.email,
            name: pageData.currentUser.displayName,
          );
      if (fallbackStation != null) {
        stationId = fallbackStation['id']?.toString() ?? '';
        stationName =
            fallbackStation['namaStation']?.toString() ??
            fallbackStation['stationName']?.toString() ??
            stationName;
      }
    }

    if (!context.mounted) return;

    if (stationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warningOrange,
          content: Text(
            'Data station belum siap untuk notifikasi booking.',
            style: AppTextStyle.body3.copyWith(color: AppColors.white),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF22D3EE), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Notifikasi Booking',
                style: AppTextStyle.h4.copyWith(
                  color: AppColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stationName,
                style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: _firestoreService.getStationBookingNotificationsOnce(
                    stationId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentCyan,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Gagal memuat notifikasi booking.\n\n${snapshot.error}',
                            style: AppTextStyle.body1.copyWith(
                              color: AppColors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final docs = [...(snapshot.data?.docs ?? const [])]
                      ..sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final Timestamp? aCreatedAt =
                            aData['createdAt'] as Timestamp?;
                        final Timestamp? bCreatedAt =
                            bData['createdAt'] as Timestamp?;
                        final int aMillis =
                            aCreatedAt?.millisecondsSinceEpoch ?? 0;
                        final int bMillis =
                            bCreatedAt?.millisecondsSinceEpoch ?? 0;
                        return bMillis.compareTo(aMillis);
                      });

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada booking baru.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length > 20 ? 20 : docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final String customerName =
                            readFirstString(data, const [
                              'namaUser',
                              'userName',
                              'nama',
                              'name',
                            ]) ??
                            'Pelanggan';
                        final String unitName =
                            data['namaUnit']?.toString() ?? 'Unit';
                        final String totalText = _formatCurrency(
                          _readFirstInt(data, const [
                            'totalPemasukan',
                            'totalPrice',
                            'totalHarga',
                            'amount',
                            'price',
                            'biaya',
                            'nominal',
                            'total',
                          ]),
                        );
                        final Timestamp? createdAt =
                            data['createdAt'] as Timestamp?;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF11172A,
                            ).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(
                                0xFF22D3EE,
                              ).withValues(alpha: 0.05),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF22D3EE,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: Color(0xFF22D3EE),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$customerName memesan $unitName',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      totalText.isNotEmpty
                                          ? 'Total $totalText'
                                          : 'Booking baru masuk',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatRelativeTime(createdAt),
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Booking',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _readFirstInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      if (value != null) {
        final parsed = int.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  String _formatCurrency(int value) {
    if (value <= 0) return '';
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match match) => '${match[1]}.')}';
  }

  String _formatRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Baru saja';
    final DateTime dateTime = timestamp.toDate();
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}j lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}h lalu';
    }

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  // Unit helpers moved to widgets/utils.dart: use `readUnitType`,
  // `readUnitStatus`, `readFirstString`, `isPcType`, `isRoomType`,
  // `isAvailableStatus`, and `isFullStatus`.

  // Int helper moved to UnitCard widget where needed.
  String _unitName(Map<String, dynamic> data) {
    return data['namaUnit']?.toString() ?? 'Unit';
  }

  Widget _buildSectionTitle({
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    final List<Widget>? subtitleWidgets = subtitle == null
        ? null
        : [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
            ),
          ];

    final List<Widget> rowChildren = [
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
            ...?subtitleWidgets,
          ],
        ),
      ),
    ];

    if (trailing != null) rowChildren.add(trailing);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowChildren,
    );
  }

  Widget _buildAddButton(
    BuildContext context,
    String stationId, {
    String? stationType,
  }) {
    final bool supportsPc = _supportsPcAndRoomSelection(stationType);
    return GestureDetector(
      onTap: () {
        if (supportsPc) {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (sheetCtx) {
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(
                  color: AppColors.primaryDarkNavy,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pilih Jenis Unit',
                        style: AppTextStyle.h4.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Gaming Center dan Esports Center bisa memilih PC Satuan atau Room. Console Center dan VR Center langsung Room saja.',
                        style: AppTextStyle.body3.copyWith(
                          color: AppColors.softGray,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildUnitTypeOption(
                      context,
                      sheetCtx,
                      icon: Icons.computer_rounded,
                      title: 'PC Satuan',
                      subtitle: 'Untuk Gaming Center dan Esports Center',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _openAddForm(context, stationId, unitType: 'pc');
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildUnitTypeOption(
                      context,
                      sheetCtx,
                      icon: Icons.meeting_room_rounded,
                      title: 'Room',
                      subtitle: 'Untuk VIP, Squad, VR, Console, dan room lain',
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _openAddForm(context, stationId, unitType: 'room');
                      },
                    ),
                  ],
                ),
              );
            },
          );
          return;
        }
        _openAddForm(context, stationId, unitType: 'room');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingL,
          vertical: AppTheme.paddingM,
        ),
        decoration: BoxDecoration(
          gradient: Gradients.kAccent,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          boxShadow: AppTheme.shadowMedium,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: AppColors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              supportsPc ? 'Tambah Unit' : 'Tambah Room',
              style: AppTextStyle.buttonSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitTypeOption(
    BuildContext context,
    BuildContext sheetCtx, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.10)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.accentCyan),
        title: Text(
          title,
          style: AppTextStyle.body1.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildTopSummaryCard(
    BuildContext context,
    _RoomSummary summary,
    String stationId,
    String? stationType,
  ) {
    final bool supportsPc = _supportsPcAndRoomSelection(stationType);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDarkNavy.withValues(alpha: 0.9),
            AppColors.secondaryDark.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Kapasitas',
                  style: AppTextStyle.caption1.copyWith(
                    color: AppColors.softGray,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${summary.totalUnit}',
                      style: AppTextStyle.h2.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 36,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      supportsPc ? 'Unit' : 'Ruangan',
                      style: AppTextStyle.h4.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (supportsPc) ...[
                  const SizedBox(height: 6),
                  Text(
                    'PC ${summary.totalPc}  •  Room ${summary.totalRoom}',
                    style: AppTextStyle.body3.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildAddButton(context, stationId, stationType: stationType),
        ],
      ),
    );
  }

  Widget _buildUnitCard(
    BuildContext context,
    String stationId,
    _UnitEntry entry,
  ) {
    return UnitCard(
      stationId: stationId,
      unitId: entry.id,
      entry: entry.data,
      onDetail: () => _openDetailPage(context, stationId, entry),
      onEdit: () => _openEditForm(context, stationId, entry),
      onDelete: () =>
          _confirmDeleteUnit(context, entry.id, _unitName(entry.data)),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return CustomEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildContentArea(BuildContext context, _RoomPageData pageData) {
    final String stationId = pageData.station['id']?.toString() ?? '';
    final String stationName =
        pageData.station['namaStation']?.toString() ??
        pageData.station['stationName']?.toString() ??
        'GameZone Station';
    final String adminName =
        pageData.userData?['nama']?.toString() ??
        pageData.userData?['name']?.toString() ??
        pageData.currentUser.displayName ??
        pageData.currentUser.email ??
        'Admin';
    final String? avatarUrl =
        pageData.station['foto']?.toString() ??
        pageData.userData?['foto']?.toString() ??
        pageData.currentUser.photoURL;

    final String? stationType = readFirstString(pageData.station, const [
      'jenis',
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Admin. Only show when not nested inside AdminDashboard
        // Header
        if (!widget.isNestedTab)
          AdminHeader(
            currentUser: pageData.currentUser,
            adminName: adminName,
            stationName: stationName,
            avatarUrl: avatarUrl,
            stationId: stationId,
            localLastOpened: _localLastOpened,
            greetingText: 'Kelola Room',
            onNotificationPressed: () => _showNotifications(context, pageData),
            onNotificationOpened: (now) {
              setState(() {
                _localLastOpened = now;
              });
            },
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Menggunakan stream yang sudah diinisialisasi
            stream: _unitsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Gagal memuat data unit.\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: AppTextStyle.body1.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                );
              }

              final List<_UnitEntry> allUnits = _mapDocs(
                snapshot.data?.docs ?? const [],
              );
              final _RoomSummary summary = _buildSummary(allUnits);

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  // Statistik Unit
                  _buildTopSummaryCard(
                    context,
                    summary,
                    stationId,
                    stationType,
                  ),
                  const SizedBox(height: 16),
                  // Daftar Ruangan header
                  _buildSectionTitle(title: 'Daftar Ruangan'),
                  const SizedBox(height: 12),
                  _buildFilterAndSearchSection(),
                  const SizedBox(height: 16),
                  // Memproses data unit dari stream utama
                  Builder(
                    builder: (context) {
                      final List<_UnitEntry> filteredUnits =
                          _filterAndSearchUnits(allUnits);

                      if (allUnits.isEmpty) {
                        return _buildEmptyState(
                          icon: Icons.meeting_room_outlined,
                          title: 'Belum ada unit',
                          subtitle:
                              'Tidak ada unit stasiun game yang tersedia saat ini.',
                        );
                      }

                      if (filteredUnits.isEmpty) {
                        return _buildEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'Tidak ditemukan',
                          subtitle: 'Silakan ubah kata kunci pencarian Anda.',
                        );
                      }

                      // Menampilkan daftar unit yang telah difilter
                      return Column(
                        children: filteredUnits
                            .map(
                              (entry) =>
                                  _buildUnitCard(context, stationId, entry),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Layout utama room page mengikuti pola dashboard admin.
    final Widget mainContent = FutureBuilder<_RoomPageData?>(
      future: _stationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentCyan),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Gagal memuat room page.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyle.body1.copyWith(color: AppColors.white),
              ),
            ),
          );
        }

        final _RoomPageData? pageData = snapshot.data;
        if (pageData == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Station admin belum ditemukan.',
                textAlign: TextAlign.center,
                style: AppTextStyle.body1.copyWith(color: AppColors.white),
              ),
            ),
          );
        }

        final String stationId = pageData.station['id']?.toString() ?? '';
        // Memuat stream unit berdasarkan station aktif
        // Memperbarui stream ketika station berubah
        if (_unitsStream == null || _cachedStationId != stationId) {
          _cachedStationId = stationId;
          _unitsStream = _firestoreService.getUnitsStreamByStation(stationId);
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _buildContentArea(context, pageData),
          ),
        );
      },
    );

    if (widget.isNestedTab) {
      // Konten halaman
      return mainContent;
    }

    // Background utama halaman
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Mengaktifkan resize agar konten utama menyesuaikan tinggi di atas keyboard
      resizeToAvoidBottomInset: true,
      body: GameZoneBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: mainContent),
              // Bottom navigation admin (Hanya muncul jika keyboard tidak aktif).
              if (MediaQuery.of(context).viewInsets.bottom == 0)
                AdminBottomNavBar(
                  currentIndex: 1,
                  onTabSelected: (index) => _handleTabSelection(context, index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAndSearchSection() {
    // Search
    return Row(
      children: [
        // Search Bar untuk pencarian namaUnit, noPC, atau jenisRoom secara realtime.
        Expanded(
          child: CustomSearchBar(
            controller: _searchController,
            hintText: 'Cari nama, no PC, atau jenis room...',
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        // Tombol filter/sort dengan ikon garis di sebelah kanan search bar
        InkWell(
          onTap: () {
            _showFilterBottomSheet(context);
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.secondaryDark.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.08),
                width: 1.1,
              ),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppColors.softGray,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        // Gunakan StatefulBuilder agar pilihan interaktif secara langsung di dalam bottom sheet
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final double keyboardPadding = MediaQuery.of(
              context,
            ).viewInsets.bottom;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + keyboardPadding),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: Color(0xFF22D3EE), width: 1.5),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handlebar atas
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter & Urutkan',
                          style: AppTextStyle.h4.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.softGray,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. Bagian Urutkan
                    Text(
                      'Urutkan',
                      style: AppTextStyle.body1.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(canvasColor: const Color(0xFF0F172A)),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSort,
                        style: AppTextStyle.body2.copyWith(
                          color: AppColors.white,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.secondaryDark.withValues(
                            alpha: 0.8,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLarge,
                            ),
                            borderSide: BorderSide(
                              color: AppColors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLarge,
                            ),
                            borderSide: BorderSide(
                              color: AppColors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLarge,
                            ),
                            borderSide: const BorderSide(
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ),
                        items:
                            <String>[
                              'Terbaru',
                              'Nama A-Z',
                              'Nama Z-A',
                              'Harga Termurah',
                              'Harga Termahal',
                            ].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setSheetState(() {
                              _selectedSort = newValue;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Filter Jenis Unit
                    Text(
                      'Jenis Unit',
                      style: AppTextStyle.body1.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: <String>['Semua', 'PC', 'Room'].map((
                        String type,
                      ) {
                        final bool isSelected = _selectedType == type;
                        return _buildFilterPill(
                          label: type,
                          selected: isSelected,
                          onTap: () {
                            setSheetState(() {
                              _selectedType = type;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 3. Filter Status
                    Text(
                      'Status Unit',
                      style: AppTextStyle.body1.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          <String>[
                            'Semua',
                            'Tersedia',
                            'Digunakan',
                            'Perawatan',
                          ].map((String status) {
                            // DB mapping for display
                            final String displayStatus = status == 'Semua'
                                ? 'Semua Status'
                                : status;
                            final bool isSelected =
                                _selectedStatus == displayStatus;
                            return _buildFilterPill(
                              label: status,
                              selected: isSelected,
                              onTap: () {
                                setSheetState(() {
                                  _selectedStatus = displayStatus;
                                });
                              },
                            );
                          }).toList(),
                    ),

                    // 4. Filter Jenis Room (Hanya tampil jika jenis unit = Room)
                    if (_selectedType == 'Room') ...[
                      const SizedBox(height: 16),
                      Text(
                        'Jenis Room',
                        style: AppTextStyle.body1.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children:
                              <String>[
                                'Semua Room',
                                'VIP Room',
                                'Private Room',
                                'Squad Room',
                                'Streaming Room',
                                'PS5 Room',
                                'VR Room',
                              ].map((String roomType) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _buildFilterPill(
                                    label: roomType,
                                    selected: _selectedJenisRoom == roomType,
                                    onTap: () {
                                      setSheetState(() {
                                        _selectedJenisRoom = roomType;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Tombol Aksi
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge,
                                ),
                                side: BorderSide(
                                  color: AppColors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                ),
                              ),
                            ),
                            onPressed: () {
                              // Reset semua filter
                              setState(() {
                                _selectedSort = 'Terbaru';
                                _selectedType = 'Semua';
                                _selectedStatus = 'Semua Status';
                                _selectedJenisRoom = 'Semua Room';
                              });
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Reset Filter',
                              style: AppTextStyle.buttonSmall.copyWith(
                                color: AppColors.softGray,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: Gradients.kAccent,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusLarge,
                              ),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge,
                                  ),
                                ),
                              ),
                              onPressed: () {
                                // Terapkan filter & pemicu pembaruan UI di halaman utama
                                setState(() {});
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Terapkan',
                                style: AppTextStyle.buttonSmall.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterPill({
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

  List<_UnitEntry> _filterAndSearchUnits(List<_UnitEntry> entries) {
    // Proses pencarian data secara realtime dan filter client-side
    final List<_UnitEntry> filtered = entries.where((entry) {
      final data = entry.data;
      final String namaUnit = data['namaUnit']?.toString().toLowerCase() ?? '';
      final String type = data['jenisUnit']?.toString().toLowerCase() ?? '';
      final String status = data['status']?.toString().toLowerCase() ?? '';
      final String noPc = data['noPC']?.toString().toLowerCase() ?? '';
      final String jenisRoom =
          data['jenisRoom']?.toString().toLowerCase() ?? '';

      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final bool matchesName = namaUnit.contains(_searchQuery);
        final bool matchesNoPc = noPc.contains(_searchQuery);
        final bool matchesJenisRoom = jenisRoom.contains(_searchQuery);
        if (!matchesName && !matchesNoPc && !matchesJenisRoom) {
          return false;
        }
      }

      // 2. Type Filter
      if (_selectedType == 'PC' && type != 'pc') {
        return false;
      }
      if (_selectedType == 'Room' && type != 'room') {
        return false;
      }

      // 3. Status Filter
      if (_selectedStatus == 'Tersedia' && status != 'tersedia') {
        return false;
      }
      if (_selectedStatus == 'Digunakan' && status != 'digunakan') {
        return false;
      }
      if (_selectedStatus == 'Perawatan' && status != 'perawatan') {
        return false;
      }

      // 4. Jenis Room Filter (hanya jika tipe yang dipilih room)
      if (_selectedType == 'Room' && _selectedJenisRoom != 'Semua Room') {
        if (jenisRoom != _selectedJenisRoom.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();

    // 5. Proses sorting data secara realtime dan interactive
    if (_selectedSort == 'Nama A-Z') {
      filtered.sort((a, b) {
        final String nameA = a.data['namaUnit']?.toString().toLowerCase() ?? '';
        final String nameB = b.data['namaUnit']?.toString().toLowerCase() ?? '';
        return nameA.compareTo(nameB);
      });
    } else if (_selectedSort == 'Nama Z-A') {
      filtered.sort((a, b) {
        final String nameA = a.data['namaUnit']?.toString().toLowerCase() ?? '';
        final String nameB = b.data['namaUnit']?.toString().toLowerCase() ?? '';
        return nameB.compareTo(nameA);
      });
    } else if (_selectedSort == 'Harga Termurah') {
      filtered.sort((a, b) {
        final num priceA = a.data['hargaPerJam'] ?? 0;
        final num priceB = b.data['hargaPerJam'] ?? 0;
        return priceA.compareTo(priceB);
      });
    } else if (_selectedSort == 'Harga Termahal') {
      filtered.sort((a, b) {
        final num priceA = a.data['hargaPerJam'] ?? 0;
        final num priceB = b.data['hargaPerJam'] ?? 0;
        return priceB.compareTo(priceA);
      });
    } else if (_selectedSort == 'Terbaru') {
      filtered.sort((a, b) {
        final Timestamp? timeA = a.data['createdAt'] as Timestamp?;
        final Timestamp? timeB = b.data['createdAt'] as Timestamp?;
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA); // Terbaru di atas
      });
    }

    return filtered;
  }
}

class _RoomPageData {
  final User currentUser;
  final Map<String, dynamic> station;
  final Map<String, dynamic>? userData;

  const _RoomPageData({
    required this.currentUser,
    required this.station,
    required this.userData,
  });
}

class _UnitEntry {
  final String id;
  final Map<String, dynamic> data;

  const _UnitEntry({required this.id, required this.data});
}

class _RoomSummary {
  final int totalUnit;
  final int totalPc;
  final int totalRoom;
  final int full;
  final int available;

  const _RoomSummary({
    required this.totalUnit,
    required this.totalPc,
    required this.totalRoom,
    required this.full,
    required this.available,
  });
}
