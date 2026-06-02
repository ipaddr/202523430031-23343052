import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/widgets/background.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';
import 'package:gamezone/widgets/common/status_badge.dart';

class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({super.key});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isRouteInitialized = false;
  String _bookingId = '';
  String _viewMode = 'admin'; // 'admin' | 'user' | 'superadmin'
  Map<String, dynamic>? _initialBookingData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRouteInitialized) {
      _isRouteInitialized = true;
      _parseRouteArguments();
    }
  }

  void _parseRouteArguments() {
    final Object? arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is Map) {
      _bookingId = arguments['bookingId']?.toString() ?? '';
      _viewMode = arguments['viewMode']?.toString() ?? 'admin';
      final dynamic data = arguments['bookingData'];
      if (data is Map) {
        _initialBookingData = Map<String, dynamic>.from(data);
      }
      if (_bookingId.isEmpty) {
        _bookingId = _initialBookingData?['bookingId']?.toString() ?? '';
      }
    }
  }

  String _formatCurrency(int value) {
    if (value <= 0) return 'Rp 0';
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Color _getStatusColor(String status) => bookingStatusColor(status);
  String _getStatusLabel(String status) => bookingStatusLabel(status);

  // ── Terima booking: pending → confirmed ──────────────────────────────────
  Future<void> _handleTerimaBooking() async {
    // Guard: hanya admin yang boleh
    if (_viewMode != 'admin') {
      debugPrint('BookingDetail: aksi TERIMA diblokir — viewMode=$_viewMode');
      return;
    }

    Map<String, dynamic>? bookingData = _initialBookingData;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(_bookingId)
          .get();
      if (snap.exists) bookingData = snap.data();
    } catch (_) {}

    if (bookingData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data booking tidak ditemukan.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return;
    }

    final String unitId = bookingData['unitId']?.toString() ?? '';
    final String tanggalBooking =
        bookingData['tanggalBooking']?.toString() ?? '';
    final String jamMulai = bookingData['jamMulai']?.toString() ?? '';
    final String jamSelesai = bookingData['jamSelesai']?.toString() ?? '';

    try {
      // Batalkan booking pending lain yang bertabrakan jadwal
      await _firestoreService.cancelConflictingBookings(
        confirmedBookingId: _bookingId,
        unitId: unitId,
        tanggalBooking: tanggalBooking,
        jamMulai: jamMulai,
        jamSelesai: jamSelesai,
      );
      // Set confirmed
      await _firestoreService.updateBooking(_bookingId, {
        'statusBooking': 'confirmed',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking diterima dan dikonfirmasi.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menerima booking: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ── Tolak booking: pending → rejected ────────────────────────────────────
  Future<void> _handleTolakBooking() async {
    if (_viewMode != 'admin') {
      debugPrint('BookingDetail: aksi TOLAK diblokir — viewMode=$_viewMode');
      return;
    }
    try {
      await _firestoreService.updateBooking(_bookingId, {
        'statusBooking': 'cancelled',
        'cancelReason': 'Booking ditolak oleh Admin.',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking ditolak.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menolak booking: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ── Check-in: pending_confirmation+paid → confirmed ──────────────────────
  Future<void> _handleCheckIn() async {
    if (_viewMode != 'admin') {
      debugPrint('BookingDetail: aksi CHECK-IN diblokir — viewMode=$_viewMode');
      return;
    }

    Map<String, dynamic>? bookingData = _initialBookingData;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(_bookingId)
          .get();
      if (snap.exists) bookingData = snap.data();
    } catch (_) {}

    if (bookingData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data booking tidak ditemukan.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
      return;
    }

    final String unitId = bookingData['unitId']?.toString() ?? '';
    final String tanggalBooking =
        bookingData['tanggalBooking']?.toString() ?? '';
    final String jamMulai = bookingData['jamMulai']?.toString() ?? '';
    final String jamSelesai = bookingData['jamSelesai']?.toString() ?? '';

    try {
      // Batalkan booking pending lain yang bertabrakan jadwal
      await _firestoreService.cancelConflictingBookings(
        confirmedBookingId: _bookingId,
        unitId: unitId,
        tanggalBooking: tanggalBooking,
        jamMulai: jamMulai,
        jamSelesai: jamSelesai,
      );

      await _firestoreService.updateBooking(_bookingId, {
        'statusBooking': 'confirmed',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in berhasil dikonfirmasi. Status Booking menjadi dikonfirmasi.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal konfirmasi check-in: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ── Batalkan booking: pending → cancelled ────────────────────────────────
  Future<void> _handleCancelBooking() async {
    if (_viewMode != 'user') {
      debugPrint('BookingDetail: aksi CANCEL diblokir — viewMode=$_viewMode');
      return;
    }
    try {
      await _firestoreService.cancelBooking(_bookingId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking berhasil dibatalkan.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan booking: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ── Selesaikan booking: active → completed ───────────────────────────────
  Future<void> _handleCompleteBooking() async {
    if (_viewMode != 'admin') {
      debugPrint('BookingDetail: aksi COMPLETE diblokir — viewMode=$_viewMode');
      return;
    }
    try {
      await _firestoreService.updateBooking(_bookingId, {
        'statusBooking': 'completed',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking telah selesai.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyelesaikan booking: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameZoneBackground(
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            // Stream booking — data utama halaman ini
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .doc(_bookingId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                );
              }

              Map<String, dynamic>? bookingData;
              if (snapshot.hasData && snapshot.data!.exists) {
                bookingData = snapshot.data!.data() as Map<String, dynamic>?;
              } else {
                bookingData = _initialBookingData;
              }

              if (bookingData == null) {
                return Center(
                  child: Text(
                    'Data Booking tidak ditemukan.',
                    style: AppTextStyle.body1.copyWith(color: AppColors.white),
                  ),
                );
              }

              // ── Ambil ID referensi untuk fetch data terkait ──────────────
              final String bookingId =
                  bookingData['bookingId']?.toString() ?? _bookingId;
              final String statusBooking =
                  bookingData['statusBooking']?.toString() ?? 'pending';
              final String userId = bookingData['userId']?.toString() ?? '';
              final String stationId =
                  bookingData['stationId']?.toString() ?? '';
              final String unitId = bookingData['unitId']?.toString() ?? '';

              // ── Data jadwal & harga langsung dari dokumen booking ─────────
              final String tanggalBooking =
                  bookingData['tanggalBooking']?.toString() ?? '-';
              final String jamMulai =
                  bookingData['jamMulai']?.toString() ?? '00:00';
              final String jamSelesai =
                  bookingData['jamSelesai']?.toString() ?? '00:00';
              final int durasiJam =
                  (bookingData['durasiJam'] as num?)?.toInt() ?? 1;
              final int totalHarga =
                  (bookingData['totalHarga'] as num?)?.toInt() ?? 0;
              final String statusPembayaran =
                  bookingData['statusPembayaran']?.toString() ?? 'unpaid';

              return _BookingDetailContent(
                firestoreService: _firestoreService,
                bookingId: bookingId,
                statusBooking: statusBooking,
                statusPembayaran: statusPembayaran,
                viewMode: _viewMode,
                userId: userId,
                stationId: stationId,
                unitId: unitId,
                tanggalBooking: tanggalBooking,
                jamMulai: jamMulai,
                jamSelesai: jamSelesai,
                durasiJam: durasiJam,
                totalHarga: totalHarga,
                formatCurrency: _formatCurrency,
                getStatusColor: _getStatusColor,
                getStatusLabel: _getStatusLabel,
                onTerima: _handleTerimaBooking,
                onTolak: _handleTolakBooking,
                onCheckIn: _handleCheckIn,
                onCancel: _handleCancelBooking,
                onComplete: _handleCompleteBooking,
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Widget konten utama — fetch user/station/unit secara paralel ────────────
// Dipisah agar StreamBuilder booking di atas tidak ikut rebuild saat
// data user/station/unit datang.
class _BookingDetailContent extends StatelessWidget {
  final FirestoreService firestoreService;
  final String bookingId;
  final String statusBooking;
  final String statusPembayaran;
  final String viewMode; // 'admin' | 'user' | 'superadmin'
  final String userId;
  final String stationId;
  final String unitId;
  final String tanggalBooking;
  final String jamMulai;
  final String jamSelesai;
  final int durasiJam;
  final int totalHarga;
  final String Function(int) formatCurrency;
  final Color Function(String) getStatusColor;
  final String Function(String) getStatusLabel;
  final VoidCallback onTerima;
  final VoidCallback onTolak;
  final VoidCallback onCheckIn;
  final VoidCallback onCancel;
  final VoidCallback onComplete;

  const _BookingDetailContent({
    required this.firestoreService,
    required this.bookingId,
    required this.statusBooking,
    required this.statusPembayaran,
    required this.viewMode,
    required this.userId,
    required this.stationId,
    required this.unitId,
    required this.tanggalBooking,
    required this.jamMulai,
    required this.jamSelesai,
    required this.durasiJam,
    required this.totalHarga,
    required this.formatCurrency,
    required this.getStatusColor,
    required this.getStatusLabel,
    required this.onTerima,
    required this.onTolak,
    required this.onCheckIn,
    required this.onCancel,
    required this.onComplete,
  });

  /// Fetch user, station, dan unit secara paralel — masing-masing terisolasi.
  /// Jika satu query gagal (permission-denied, dll), yang lain tetap jalan.
  Future<List<Map<String, dynamic>?>> _fetchRelatedData() async {
    debugPrint('── BookingDetail fetch ──────────────────────');
    debugPrint('  bookingId : $bookingId');
    debugPrint('  userId    : "$userId"');
    debugPrint('  stationId : "$stationId"');
    debugPrint('  unitId    : "$unitId"');

    final results = await Future.wait([
      // [0] user — menggunakan direct Firestore query sebagai fallback
      () async {
        if (userId.isEmpty) {
          debugPrint('  [user]    SKIP — userId kosong');
          return null;
        }
        try {
          final data = await firestoreService.getUserData(userId);
          debugPrint('  [user]    OK — fields: ${data?.keys.toList()}');
          return data;
        } catch (e) {
          debugPrint('  [user]    ERROR (kemungkinan permission-denied): $e');
          return null;
        }
      }(),

      // [1] station
      () async {
        if (stationId.isEmpty) {
          debugPrint('  [station] SKIP — stationId kosong');
          return null;
        }
        try {
          final data = await firestoreService.getStationData(stationId);
          debugPrint('  [station] OK — fields: ${data?.keys.toList()}');
          return data;
        } catch (e) {
          debugPrint('  [station] ERROR: $e');
          return null;
        }
      }(),

      // [2] unit
      () async {
        if (unitId.isEmpty) {
          debugPrint('  [unit]    SKIP — unitId kosong');
          return null;
        }
        try {
          final snap = await firestoreService.getUnitById(unitId);
          if (!snap.exists) {
            debugPrint(
              '  [unit]    NOT FOUND — unitId=$unitId tidak ada di Firestore',
            );
            return null;
          }
          final data = snap.data() as Map<String, dynamic>?;
          debugPrint('  [unit]    OK — fields: ${data?.keys.toList()}');
          return data;
        } catch (e) {
          debugPrint('  [unit]    ERROR: $e');
          return null;
        }
      }(),
    ]);

    debugPrint('────────────────────────────────────────────');
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>?>>(
      future: _fetchRelatedData(),
      builder: (context, snap) {
        // Tampilkan data yang ada sambil loading — tidak blokir UI
        final Map<String, dynamic> userData = snap.data?[0] ?? {};
        final Map<String, dynamic> stationData = snap.data?[1] ?? {};
        final Map<String, dynamic> unitData = snap.data?[2] ?? {};

        // ── User ────────────────────────────────────────────────────────────
        final String namaUser = userData['nama']?.toString().isNotEmpty == true
            ? userData['nama'].toString()
            : '-';
        final String emailUser =
            userData['email']?.toString().isNotEmpty == true
            ? userData['email'].toString()
            : '-';
        final String noHpUser = userData['noHp']?.toString().isNotEmpty == true
            ? userData['noHp'].toString()
            : '-';
        final String fotoUser = userData['foto']?.toString() ?? '';

        // ── Station ─────────────────────────────────────────────────────────
        final String namaStation =
            stationData['namaStation']?.toString().isNotEmpty == true
            ? stationData['namaStation'].toString()
            : '-';

        // ── Unit ────────────────────────────────────────────────────────────
        final String namaUnit =
            unitData['namaUnit']?.toString().isNotEmpty == true
            ? unitData['namaUnit'].toString()
            : '-';
        final String jenisRoom =
            unitData['jenisRoom']?.toString().isNotEmpty == true
            ? unitData['jenisRoom'].toString()
            : '-';
        final int hargaPerJam = (unitData['hargaPerJam'] as num?)?.toInt() ?? 0;

        return Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                      Text(
                        'Detail Booking',
                        style: AppTextStyle.h4.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryDark.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.softGray,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // CONTENT
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                children: [
                  _buildBookingCard(bookingId, statusBooking),
                  const SizedBox(height: 20),
                  _buildCustomerCard(namaUser, fotoUser, noHpUser, emailUser),
                  const SizedBox(height: 20),
                  _buildUnitCard(namaUnit, jenisRoom, namaStation),
                  const SizedBox(height: 20),
                  _buildScheduleCard(
                    tanggalBooking,
                    jamMulai,
                    jamSelesai,
                    durasiJam,
                  ),
                  const SizedBox(height: 20),
                  _buildPaymentSummaryCard(
                    namaUnit,
                    durasiJam,
                    hargaPerJam,
                    totalHarga,
                  ),
                  const SizedBox(height: 32),
                  _buildActions(statusBooking, statusPembayaran, context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Booking card: Booking ID + status badge ──────────────────────────────
  Widget _buildBookingCard(String bookingId, String statusBooking) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10162E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      // Row dengan MainAxisAlignment.spaceBetween menyebabkan overflow jika
      // bookingId panjang. Gunakan Expanded + overflow ellipsis pada ID-nya.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BOOKING ID',
                  style: AppTextStyle.caption2.copyWith(
                    color: AppColors.softGray,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '#$bookingId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.h3.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          StatusBadge(
            label: getStatusLabel(statusBooking),
            color: getStatusColor(statusBooking),
          ),
        ],
      ),
    );
  }

  // ── Customer card: data dari users/{userId} ──────────────────────────────
  Widget _buildCustomerCard(
    String namaUser,
    String fotoUser,
    String noHp,
    String email,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CUSTOMER INFORMATION',
          style: AppTextStyle.caption2.copyWith(
            color: AppColors.softGray,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10162E).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              CustomUserAvatar(photoUrl: fotoUser, size: 48, hasBorder: false),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Name',
                      style: AppTextStyle.caption2.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      namaUser,
                      style: AppTextStyle.body1.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      noHp,
                      style: AppTextStyle.caption1.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                    Text(
                      email,
                      style: AppTextStyle.caption1.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Unit card: data dari units/{unitId} + stations/{stationId} ──────────
  Widget _buildUnitCard(String namaUnit, String jenisRoom, String namaStation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UNIT INFORMATION',
          style: AppTextStyle.caption2.copyWith(
            color: AppColors.softGray,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10162E).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: AppColors.accentCyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Room / Unit',
                      style: AppTextStyle.caption2.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      jenisRoom != '-' ? '$namaUnit ($jenisRoom)' : namaUnit,
                      style: AppTextStyle.body1.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      namaStation,
                      style: AppTextStyle.caption1.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Schedule card ─────────────────────────────────────────────────────────
  Widget _buildScheduleCard(
    String tanggalBooking,
    String jamMulai,
    String jamSelesai,
    int durasiJam,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE & SCHEDULE',
          style: AppTextStyle.caption2.copyWith(
            color: AppColors.softGray,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10162E).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.accentCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: AppTextStyle.caption2.copyWith(
                          color: AppColors.softGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tanggalBooking,
                        style: AppTextStyle.body1.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: AppColors.accentCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule',
                        style: AppTextStyle.caption2.copyWith(
                          color: AppColors.softGray,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$jamMulai - $jamSelesai ($durasiJam Jam)',
                        style: AppTextStyle.body1.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Payment summary: hargaPerJam dari unit, totalHarga dari booking ──────
  Widget _buildPaymentSummaryCard(
    String namaUnit,
    int durasiJam,
    int hargaPerJam,
    int totalHarga,
  ) {
    // Hitung subtotal dari hargaPerJam × durasiJam.
    // Jika hargaPerJam tidak tersedia dari unit (0), tampilkan totalHarga langsung.
    final int subtotal = hargaPerJam > 0 ? hargaPerJam * durasiJam : totalHarga;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAYMENT SUMMARY',
          style: AppTextStyle.caption2.copyWith(
            color: AppColors.softGray,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10162E).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$namaUnit ($durasiJam Jam)',
                      style: AppTextStyle.body2.copyWith(
                        color: AppColors.softGray,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatCurrency(subtotal),
                    style: AppTextStyle.body2.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Revenue',
                    style: AppTextStyle.body1.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    formatCurrency(totalHarga),
                    style: AppTextStyle.h3.copyWith(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Action buttons — ditentukan oleh viewMode + status matrix ────────────
  //
  // STATUS MATRIX
  //   pending + unpaid   → USER: Bayar Sekarang + Batalkan
  //   pending + paid     → ADMIN: Terima + Tolak
  //   confirmed + unpaid → ADMIN: info "Menunggu Pembayaran"
  //   confirmed + paid   → ADMIN: Konfirmasi Check-In
  //   active             → ADMIN: Selesaikan Booking
  //   completed          → USER: Beri Rating | ADMIN: badge Selesai
  //   cancelled/rejected → Semua: badge status (tidak ada aksi)
  //   superadmin         → Hanya informasi, semua tombol disembunyikan
  Widget _buildActions(
    String statusBooking,
    String statusPembayaran,
    BuildContext context,
  ) {
    final String status = statusBooking.toLowerCase();
    final bool isPaid = statusPembayaran.toLowerCase() == 'paid';
    final bool isUnpaid = statusPembayaran.toLowerCase() == 'unpaid';

    // ── SUPERADMIN: hanya lihat, tanpa aksi ──────────────────────────────
    if (viewMode == 'superadmin') {
      return const SizedBox.shrink();
    }

    // ── USER view ─────────────────────────────────────────────────────────
    if (viewMode == 'user') {
      // pending + unpaid → Bayar + Batalkan
      if (status == 'pending' && isUnpaid) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BAYAR SEKARANG
            Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFFA855F7)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/payment',
                    arguments: {
                      'bookingId': bookingId,
                      'stationId': stationId,
                      'unitId': unitId,
                      'totalHarga': totalHarga,
                      'namaUnit': '',
                      'tanggalBooking': tanggalBooking,
                      'jamMulai': jamMulai,
                      'jamSelesai': jamSelesai,
                      'durasiJam': durasiJam,
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'BAYAR SEKARANG',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // BATALKAN BOOKING
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'BATALKAN BOOKING',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      // pending + paid / confirmed → info status, tidak ada aksi user
      if ((status == 'pending' && isPaid) || status == 'confirmed') {
        return _buildInfoBanner(
          icon: Icons.access_time_rounded,
          color: const Color(0xFFF59E0B),
          message: 'Booking sedang diproses oleh Admin.',
        );
      }

      // checkin → user sedang bermain
      if (status == 'checkin') {
        return _buildInfoBanner(
          icon: Icons.sports_esports_rounded,
          color: AppColors.accentCyan,
          message: 'Sedang Bermain.',
        );
      }

      // cancelled / rejected / expired / completed → badge informasi / empty
      return const SizedBox.shrink();
    }

    // ── ADMIN view ────────────────────────────────────────────────────────

    // 1. Menunggu Konfirmasi & Sudah Bayar: pending_confirmation + paid → Konfirmasi Check-In & Tolak Booking
    if (status == 'pending_confirmation' && isPaid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFFA855F7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton(
              onPressed: onCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'KONFIRMASI CHECK-IN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: onTolak,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'TOLAK BOOKING',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 2. Diterima/Dikonfirmasi: confirmed → Selesaikan Booking (Selesai)
    if (status == 'confirmed') {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF22D3EE)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ElevatedButton(
          onPressed: onComplete,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'SELESAI',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // 5. Terminal states
    return const SizedBox.shrink();
  }

  /// Banner informasi (tidak ada aksi) dengan ikon dan warna dinamis.
  Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
