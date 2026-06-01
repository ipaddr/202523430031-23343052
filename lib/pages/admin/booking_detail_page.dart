import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/widgets/background.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';

class BookingDetailPage extends StatefulWidget {
  const BookingDetailPage({super.key});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isRouteInitialized = false;
  String _bookingId = '';
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
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match match) => '${match[1]}.')}';
  }

  // Status booking color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppColors.accentCyan;
      case 'pending':
        return AppColors.warningOrange;
      case 'completed':
        return AppColors.successGreen;
      case 'cancelled':
        return AppColors.errorRed;
      default:
        return AppColors.softGray;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'CONFIRMED';
      case 'pending':
        return 'WAITING CHECK-IN';
      case 'completed':
        return 'SELESAI';
      case 'cancelled':
        return 'BATAL';
      default:
        return status.toUpperCase();
    }
  }

  Future<void> _handleConfirmCheckIn() async {
    try {
      await _firestoreService.updateBooking(_bookingId, {
        'statusBooking': 'confirmed',
        'statusPembayaran': 'paid',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil mengonfirmasi check-in booking.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal melakukan check-in: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _handleCancelBooking() async {
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

  Future<void> _handleCompleteBooking() async {
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

              Map<String, dynamic>? data;
              if (snapshot.hasData && snapshot.data!.exists) {
                data = snapshot.data!.data() as Map<String, dynamic>?;
              } else {
                data = _initialBookingData;
              }

              if (data == null) {
                return Center(
                  child: Text(
                    'Data Booking tidak ditemukan.',
                    style: AppTextStyle.body1.copyWith(color: AppColors.white),
                  ),
                );
              }

              final String bookingId =
                  data['bookingId']?.toString() ?? _bookingId;
              final String statusBooking =
                  data['statusBooking']?.toString() ?? 'pending';
              final String namaUser = data['namaUser']?.toString() ?? '-';
              final String fotoUser = data['fotoUser']?.toString() ?? '';
              final String emailUser = data['emailUser']?.toString() ?? '-';
              final String nomorTelepon =
                  data['nomorTelepon']?.toString() ?? '-';
              final String namaUnit = data['namaUnit']?.toString() ?? '-';
              final String jenisUnit = data['jenisUnit']?.toString() ?? '-';
              final String namaStation = data['namaStation']?.toString() ?? '-';
              final String tanggalBooking =
                  data['tanggalBooking']?.toString() ?? '-';
              final String jamMulai = data['jamMulai']?.toString() ?? '00:00';
              final String jamSelesai =
                  data['jamSelesai']?.toString() ?? '00:00';
              final int durasiJam = (data['durasiJam'] as num?)?.toInt() ?? 1;
              final int hargaPerJam =
                  (data['hargaPerJam'] as num?)?.toInt() ?? 0;
              final int totalHarga = (data['totalHarga'] as num?)?.toInt() ?? 0;

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
                                  border: Border.all(
                                    color: const Color(0xFF23304C),
                                  ),
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
                            color: AppColors.secondaryDark.withValues(
                              alpha: 0.9,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accentCyan.withValues(
                                alpha: 0.15,
                              ),
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
                        // Informasi booking
                        _buildBookingCard(bookingId, statusBooking),
                        const SizedBox(height: 20),

                        // Informasi pelanggan
                        _buildCustomerCard(
                          namaUser,
                          fotoUser,
                          nomorTelepon,
                          emailUser,
                        ),
                        const SizedBox(height: 20),

                        // Informasi unit
                        _buildUnitCard(namaUnit, jenisUnit, namaStation),
                        const SizedBox(height: 20),

                        // Jadwal booking
                        _buildScheduleCard(
                          tanggalBooking,
                          jamMulai,
                          jamSelesai,
                          durasiJam,
                        ),
                        const SizedBox(height: 20),

                        // Ringkasan pembayaran
                        _buildPaymentSummaryCard(
                          namaUnit,
                          durasiJam,
                          hargaPerJam,
                          totalHarga,
                        ),
                        const SizedBox(height: 32),

                        // Aksi admin
                        _buildAdminActions(statusBooking),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Informasi booking
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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
                style: AppTextStyle.h3.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(statusBooking).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getStatusColor(statusBooking).withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              _getStatusLabel(statusBooking),
              style: AppTextStyle.caption1.copyWith(
                color: _getStatusColor(statusBooking),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Informasi pelanggan
  Widget _buildCustomerCard(
    String namaUser,
    String fotoUser,
    String nomorTelepon,
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
              CustomImageLoader(
                photoStr: fotoUser,
                width: 48,
                height: 48,
                radius: 999,
                fallbackIcon: Icons.person_rounded,
              ),
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
                      nomorTelepon,
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

  // Informasi unit
  Widget _buildUnitCard(String namaUnit, String jenisUnit, String namaStation) {
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
                      '$namaUnit ($jenisUnit)',
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

  // Jadwal booking
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

  // Ringkasan pembayaran
  Widget _buildPaymentSummaryCard(
    String namaUnit,
    int durasiJam,
    int hargaPerJam,
    int totalHarga,
  ) {
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
                  Text(
                    '$namaUnit ($durasiJam Jam)',
                    style: AppTextStyle.body2.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                  Text(
                    _formatCurrency(hargaPerJam * durasiJam),
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
                    _formatCurrency(totalHarga),
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

  // Aksi admin
  Widget _buildAdminActions(String statusBooking) {
    if (statusBooking.toLowerCase() == 'pending') {
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
              onPressed: _handleConfirmCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'KONFIRMASI CHECK-IN',
                style: AppTextStyle.buttonMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _handleCancelBooking,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'BATALKAN BOOKING',
                style: AppTextStyle.buttonMedium.copyWith(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (statusBooking.toLowerCase() == 'confirmed') {
      return Container(
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
          onPressed: _handleCompleteBooking,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'SELESAIKAN BOOKING',
            style: AppTextStyle.buttonMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
