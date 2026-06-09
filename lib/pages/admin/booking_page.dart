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
import 'package:gamezone/widgets/common/custom_image_loader.dart';
import 'package:gamezone/widgets/common/custom_empty_state.dart';
import 'package:gamezone/widgets/common/custom_search_bar.dart';
import 'package:gamezone/widgets/common/status_badge.dart';

class BookingPage extends StatefulWidget {
  final bool isNestedTab;
  final User? initialCurrentUser;
  final Map<String, dynamic>? initialStation;
  final Map<String, dynamic>? initialUserData;

  const BookingPage({
    super.key,
    this.isNestedTab = false,
    this.initialCurrentUser,
    this.initialStation,
    this.initialUserData,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  late Future<_BookingPageData?> _stationFuture;
  Stream<QuerySnapshot>? _bookingsStream;
  String? _cachedStationId;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'Semua';
  String _selectedPayment = 'Semua';

  @override
  void initState() {
    super.initState();
    _stationFuture = _loadStationData().then((pageData) {
      if (pageData != null) {
        final stationId = pageData.station['id']?.toString() ?? '';
        if (stationId.isNotEmpty) {
          _firestoreService.completeFinishedBookings(stationId: stationId);
        }
      }
      return pageData;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_BookingPageData?> _loadStationData() async {
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
      return _BookingPageData(
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

    return _BookingPageData(
      currentUser: currentUser,
      station: station,
      userData: userData,
    );
  }

  void _handleTabSelection(BuildContext context, int index) {
    if (index == 2) {
      return;
    }

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/admin-dashboard');
      return;
    }

    if (index == 1) {
      Navigator.pushReplacementNamed(context, '/admin-room');
      return;
    }

    if (index == 3) {
      Navigator.pushReplacementNamed(context, '/edit-profile');
    }
  }

  String _formatCurrency(int value) {
    if (value <= 0) return 'Rp 0';
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match match) => '${match[1]}.')}';
  }


  Color _getBookingStatusColor(String status) => bookingStatusColor(status);
  String _getBookingStatusLabel(String status) => bookingStatusLabel(status);

  @override
  Widget build(BuildContext context) {
    final Widget mainContent = FutureBuilder<_BookingPageData?>(
      future: _stationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentCyan),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Gagal memuat data Game Station.',
                textAlign: TextAlign.center,
                style: AppTextStyle.body1.copyWith(color: AppColors.white),
              ),
            ),
          );
        }

        final _BookingPageData pageData = snapshot.data!;
        final String stationId = pageData.station['id']?.toString() ?? '';

        if (_bookingsStream == null || _cachedStationId != stationId) {
          _cachedStationId = stationId;
          _bookingsStream = _firestoreService.getBookingsStreamByStation(
            stationId,
          );
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
      return mainContent;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: GameZoneBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: mainContent),
              if (MediaQuery.of(context).viewInsets.bottom == 0)
                AdminBottomNavBar(
                  currentIndex: 2,
                  onTabSelected: (index) => _handleTabSelection(context, index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentArea(BuildContext context, _BookingPageData pageData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [


        // Pencarian booking
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: CustomSearchBar(
                  controller: _searchController,
                  hintText: 'Cari ID Booking atau Nama...',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showFilterBottomSheet(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                child: Container(
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
          ),
        ),


        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _bookingsStream,
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
                      'Gagal memuat daftar booking.',
                      style: AppTextStyle.body2.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                );
              }

              final docs = [...(snapshot.data?.docs ?? [])];
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final dynamic aTime = aData['createdAt'];
                final dynamic bTime = bData['createdAt'];
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                final DateTime aDate = aTime is Timestamp
                    ? aTime.toDate()
                    : (aTime is DateTime ? aTime : DateTime.now());
                final DateTime bDate = bTime is Timestamp
                    ? bTime.toDate()
                    : (bTime is DateTime ? bTime : DateTime.now());
                return bDate.compareTo(aDate);
              });
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final String bId =
                    data['bookingId']?.toString().toLowerCase() ?? '';
                final String uName =
                    data['namaUser']?.toString().toLowerCase() ?? '';
                final String unitName =
                    data['namaUnit']?.toString().toLowerCase() ?? '';
                final String status =
                    data['statusBooking']?.toString().toLowerCase() ??
                    'pending';
                final String payment =
                    data['statusPembayaran']?.toString().toLowerCase() ??
                    'unpaid';

                final matchesSearch =
                    bId.contains(_searchQuery) ||
                    uName.contains(_searchQuery) ||
                    unitName.contains(_searchQuery);

                final matchesStatus = _selectedStatus == 'Semua' ||
                    (status == _selectedStatus.toLowerCase() ||
                        (_selectedStatus.toLowerCase() == 'pending' &&
                            status == 'pending_confirmation'));

                final matchesPayment =
                    _selectedPayment == 'Semua' ||
                    payment == _selectedPayment.toLowerCase();

                return matchesSearch && matchesStatus && matchesPayment;
              }).toList();

              if (docs.isEmpty) {
                return const CustomEmptyState(
                  icon: Icons.bookmark_outline_rounded,
                  title: 'Belum ada booking',
                  subtitle: 'Booking yang masuk akan muncul di halaman ini.',
                );
              }

              if (filteredDocs.isEmpty) {
                return const CustomEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Tidak ditemukan',
                  subtitle: 'Silakan ubah kata kunci pencarian Anda.',
                );
              }

      
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data =
                      filteredDocs[index].data() as Map<String, dynamic>;
                  return _buildBookingCard(context, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> data) {
    final String bookingId = data['bookingId']?.toString() ?? '-';
    final String namaUser = data['namaUser']?.toString() ?? 'Pelanggan';
    final String fotoUser = data['fotoUser']?.toString() ?? '';
    final String namaUnit = data['namaUnit']?.toString() ?? 'Unit';
    final String tanggalBooking = data['tanggalBooking']?.toString() ?? '-';
    final String jamMulai = data['jamMulai']?.toString() ?? '00:00';
    final String jamSelesai = data['jamSelesai']?.toString() ?? '00:00';
    final String statusBooking = data['statusBooking']?.toString() ?? 'pending';
    final String statusPembayaran =
        data['statusPembayaran']?.toString() ?? 'unpaid';
    final int totalHarga = (data['totalHarga'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10162E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomUserAvatar(photoUrl: fotoUser, size: 44, hasBorder: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      namaUser,
                      style: AppTextStyle.body1.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#$bookingId',
                      style: AppTextStyle.caption2.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: _getBookingStatusLabel(statusBooking),
                color: _getBookingStatusColor(statusBooking),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RUANGAN',
                      style: AppTextStyle.caption2.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      namaUnit,
                      style: AppTextStyle.body2.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'JADWAL',
                      style: AppTextStyle.caption2.copyWith(
                        color: AppColors.softGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$tanggalBooking, $jamMulai - $jamSelesai',
                      textAlign: TextAlign.right,
                      style: AppTextStyle.body2.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PEMBAYARAN',
                    style: AppTextStyle.caption2.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusPembayaran.toLowerCase() == 'paid'
                              ? AppColors.successGreen
                              : AppColors.errorRed,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusPembayaran.toLowerCase() == 'paid'
                            ? 'Sudah Dibayar'
                            : 'Belum Dibayar',
                        style: AppTextStyle.body2.copyWith(
                          color: statusPembayaran.toLowerCase() == 'paid'
                              ? AppColors.successGreen
                              : AppColors.errorRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'TOTAL',
                    style: AppTextStyle.caption2.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(totalHarga),
                    style: AppTextStyle.body1.copyWith(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (statusBooking.toLowerCase() != 'cancelled' &&
              statusBooking.toLowerCase() != 'rejected') ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/admin-booking-detail',
                    arguments: {
                      'bookingId': bookingId,
                      'bookingData': data,
                      'viewMode': 'admin',
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.paddingXL,
                    vertical: AppTheme.paddingL,
                  ),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  textStyle: AppTextStyle.buttonMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                child: Text(
                  statusBooking.toLowerCase() == 'completed'
                      ? 'Lihat Riwayat'
                      : 'Detail Booking',
                  style: AppTextStyle.buttonMedium.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final double keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
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
                          'Filter Booking',
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

                    Text(
                      'Status Booking',
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
                          [
                            'Semua',
                            'Pending',
                            'Confirmed',
                            'Active',
                            'Completed',
                            'Cancelled',
                            'Rejected',
                          ].map((status) {
                            final bool isSelected = _selectedStatus == status;
                            final String displayLabel = switch (status
                                .toLowerCase()) {
                              'pending' => 'Menunggu',
                              'confirmed' => 'Dikonfirmasi',
                              'active' => 'Sedang Bermain',
                              'completed' => 'Selesai',
                              'cancelled' => 'Dibatalkan',
                              'rejected' => 'Ditolak',
                              _ => status,
                            };
                            return _buildFilterPill(
                              label: displayLabel,
                              selected: isSelected,
                              onTap: () {
                                setSheetState(() {
                                  _selectedStatus = status;
                                });
                              },
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Status Pembayaran',
                      style: AppTextStyle.body1.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Semua', 'Paid', 'Unpaid'].map((pay) {
                        final bool isSelected = _selectedPayment == pay;
                        final String displayLabel = pay == 'Paid'
                            ? 'Lunas'
                            : pay == 'Unpaid'
                            ? 'Belum Lunas'
                            : 'Semua';
                        return _buildFilterPill(
                          label: displayLabel,
                          selected: isSelected,
                          onTap: () {
                            setSheetState(() {
                              _selectedPayment = pay;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),


                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                                side: BorderSide(
                                  color: AppColors.white.withValues(alpha: 0.12),
                                ),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedStatus = 'Semua';
                                _selectedPayment = 'Semua';
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
                              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                                ),
                              ),
                              onPressed: () {
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
}

class _BookingPageData {
  final User currentUser;
  final Map<String, dynamic> station;
  final Map<String, dynamic>? userData;

  const _BookingPageData({
    required this.currentUser,
    required this.station,
    this.userData,
  });
}
