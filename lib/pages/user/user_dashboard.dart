import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_textstyle.dart';
import '../../styles/app_theme.dart';
import '../../widgets/background.dart';
import '../profile_page.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  int _activeTabIndex = 0;

  void _refreshUserData() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: GameZoneBackground(
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<DocumentSnapshot>(
            stream: currentUser != null
                ? _firestoreService.getUserStream(currentUser.uid)
                : const Stream.empty(),
            builder: (context, userSnapshot) {
              Map<String, dynamic> userData = {};
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                userData = userSnapshot.data!.data() as Map<String, dynamic>;
              }

              final String userName =
                  userData['nama'] ??
                  userData['name'] ??
                  currentUser?.displayName ??
                  'Gamers';
              final String avatarUrl =
                  userData['foto'] ??
                  userData['photoUrl'] ??
                  currentUser?.photoURL ??
                  '';

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sticky Header (diakses di seluruh tab)
                      _buildHeader(
                        userName: userName,
                        avatarUrl: avatarUrl,
                        currentUser: currentUser,
                      ),

                      // Area Konten Dinamis
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _buildTabContent(
                            userName: userName,
                            avatarUrl: avatarUrl,
                            currentUser: currentUser,
                          ),
                        ),
                      ),

                      // Bottom Navigation Bar
                      if (MediaQuery.of(context).viewInsets.bottom == 0)
                        _buildUserBottomNavBar(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Switch Tab Content
  Widget _buildTabContent({
    required String userName,
    required String avatarUrl,
    required User? currentUser,
  }) {
    switch (_activeTabIndex) {
      case 0:
        return _buildBerandaTab(userName: userName, avatarUrl: avatarUrl);
      case 1:
        return _buildPlaceholderTab(
          'Booking Station',
          Icons.book_online_rounded,
          'Fitur booking station akan segera hadir untuk mempermudah reservasi Anda.',
        );
      case 2:
        return _buildPlaceholderTab(
          'Gemini AI Assistant',
          Icons.psychology_rounded,
          'Fitur asisten AI akan segera hadir untuk merekomendasikan game terbaik untuk Anda.',
        );
      case 3:
        return _buildPlaceholderTab(
          'Riwayat Transaksi',
          Icons.history_rounded,
          'Riwayat booking dan rental game station Anda akan muncul di halaman ini.',
        );
      case 4:
        return ProfilePage(
          key: const ValueKey('profile-tab'),
          isNestedTab: true,
          onProfileUpdated: _refreshUserData,
        );
      default:
        return _buildBerandaTab(userName: userName, avatarUrl: avatarUrl);
    }
  }

  Widget _buildBerandaTab({
    required String userName,
    required String avatarUrl,
  }) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Hero Banner Berita Game
        _buildHeroNewsBanner(),
        const SizedBox(height: 28),

        // Game Station Populer
        _buildPopulerStationSection(),
      ],
    );
  }

  // Header Widget
  Widget _buildHeader({
    required String userName,
    required String avatarUrl,
    required User? currentUser,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // Foto Profil User (Samakan dengan style Admin)
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22D3EE), Color(0xFFC084FC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0F172A),
                      border: Border.all(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 24,
                                  ),
                            )
                          : const Icon(
                              Icons.person_rounded,
                              color: Color(0xFF94A3B8),
                              size: 24,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nama User
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Halo, Gamers!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.caption1.copyWith(
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.h3.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Tombol Notifikasi
          Material(
            color: const Color(0xFF1E293B).withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (currentUser != null) {
                  _showUserNotifications(context, currentUser);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Silakan login terlebih dahulu untuk melihat notifikasi.',
                      ),
                      backgroundColor: AppColors.errorRed,
                    ),
                  );
                }
              },
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF94A3B8),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hero Banner Berita Game Widget
  Widget _buildHeroNewsBanner() {
    // Persiapan API nanti: ambil headline pertama.
    // Sementara menggunakan data statis.
    final String title = 'Berita Terkini';
    final String description =
        'Ikuti perkembangan dunia game, esports, turnamen, dan teknologi gaming terbaru.';
    const String? imageUrl = null; // Bisa ditambahkan foto di masa depan

    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF00F2FE), Color(0xFF4FACFE), Color(0xFF7028FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FACFE).withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background / API Image overlay
            if (imageUrl != null)
              Positioned.fill(
                child: Image.network(imageUrl, fit: BoxFit.cover),
              ),
            if (imageUrl != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            // Default decorative graphics
            if (imageUrl == null)
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  Icons.newspaper_rounded,
                  size: 150,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            Positioned(
              left: -30,
              top: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Badge Berita Terkini / News
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NEWS UPDATE',
                      style: AppTextStyle.caption2.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: AppTextStyle.h3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: AppTextStyle.body3.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Game Station Populer Section Widget
  Widget _buildPopulerStationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Game Station Populer',
              style: AppTextStyle.h4.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _activeTabIndex = 1;
                });
              },
              child: Text(
                'LIHAT SEMUA',
                style: AppTextStyle.accentText.copyWith(
                  color: const Color(0xFF22D3EE),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getStationsByVerificationStatusStream(
            'verified',
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 180,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                height: 120,
                alignment: Alignment.center,
                child: Text(
                  'Gagal memuat data station.\n\nError: ${snapshot.error}',
                  style: AppTextStyle.body2.copyWith(color: AppColors.errorRed),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final List<DocumentSnapshot> allDocs = snapshot.data?.docs ?? [];

            // Urutkan berdasarkan rating tertinggi secara manual agar aman
            final List<Map<String, dynamic>> stations = allDocs.map((doc) {
              final Map<String, dynamic> data =
                  doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList();

            stations.sort((a, b) {
              final double ratingA = (a['rating'] is num)
                  ? (a['rating'] as num).toDouble()
                  : 0.0;
              final double ratingB = (b['rating'] is num)
                  ? (b['rating'] as num).toDouble()
                  : 0.0;
              return ratingB.compareTo(ratingA); // Descending
            });

            if (stations.isEmpty) {
              return Container(
                width: double.infinity,
                height: 180,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF334155).withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sports_esports_outlined,
                        color: Color(0xFF22D3EE),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Belum ada stasiun game',
                      style: AppTextStyle.body1.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Belum ada stasiun game yang tersedia saat ini.',
                      style: AppTextStyle.body3.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Tampilkan maksimal 5 Game Station terpopuler secara vertikal
            final List<Map<String, dynamic>> topStations = stations
                .take(5)
                .toList();

            return Column(
              children: topStations.map((station) {
                final String name =
                    station['namaStation'] ??
                    station['stationName'] ??
                    'Game Station';
                final String alamat =
                    station['alamat'] ?? 'Alamat tidak tersedia';

                final bool hasRating =
                    station['rating'] != null &&
                    (station['rating'] is num) &&
                    (station['rating'] as num) > 0;
                final double rating = hasRating
                    ? (station['rating'] as num).toDouble()
                    : 0.0;

                final dynamic totalReview =
                    station['totalReview'] ??
                    station['reviewsCount'] ??
                    station['reviews'] ??
                    station['totalReviews'];
                final String reviewText =
                    (totalReview != null && totalReview != 0)
                    ? '$totalReview Review'
                    : 'Belum ada review';

                // Ambil foto
                String fotoUrl = '';
                final fotoData = station['foto'];
                if (fotoData is String && fotoData.trim().isNotEmpty) {
                  fotoUrl = fotoData.trim();
                } else if (fotoData is List &&
                    fotoData.isNotEmpty &&
                    fotoData.first != null) {
                  fotoUrl = fotoData.first.toString().trim();
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/station-detail',
                      arguments: {
                        'stationId': station['id']?.toString() ?? '',
                        'stationData': station,
                        'viewMode': 'user',
                      },
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF334155).withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        children: [
                          // Foto Station
                          SizedBox(
                            width: 104,
                            height: 104,
                            child: fotoUrl.isNotEmpty
                                ? Image.network(
                                    fotoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, err, stack) =>
                                        _buildPlaceholderImage(),
                                  )
                                : _buildPlaceholderImage(),
                          ),
                          // Detail Info
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: AppTextStyle.body1.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Rating & Review Stack
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
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
                                                hasRating
                                                    ? rating.toStringAsFixed(1)
                                                    : 'Belum ada rating',
                                                style: AppTextStyle.caption1
                                                    .copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            reviewText,
                                            style: AppTextStyle.caption2
                                                .copyWith(
                                                  color: const Color(
                                                    0xFF94A3B8,
                                                  ),
                                                  fontSize: 9,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        color: Color(0xFF94A3B8),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          alamat,
                                          style: AppTextStyle.caption1.copyWith(
                                            color: const Color(0xFF94A3B8),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // Placeholder Image Widget
  Widget _buildPlaceholderImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: Color(0xFF475569),
          size: 32,
        ),
      ),
    );
  }

  // Notifikasi Booking User
  Future<void> _showUserNotifications(
    BuildContext context,
    User currentUser,
  ) async {
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
                'Notifikasi Booking Anda',
                style: AppTextStyle.h4.copyWith(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Status real-time pemesanan game station Anda.',
                style: AppTextStyle.body3.copyWith(
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('userId', isEqualTo: currentUser.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF22D3EE),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Gagal memuat notifikasi.\n\nError: ${snapshot.error}',
                          style: AppTextStyle.body2.copyWith(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final allBookings = snapshot.data?.docs ?? [];

                    // Filter status pending, confirmed, completed, cancelled
                    final List<DocumentSnapshot> filteredBookings = allBookings
                        .where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final String status = (data['statusBooking'] ?? '')
                              .toString()
                              .toLowerCase();
                          return status == 'confirmed' ||
                              status == 'completed' ||
                              status == 'cancelled';
                        })
                        .toList();

                    filteredBookings.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final Timestamp? aTime =
                          (aData['updatedAt'] ?? aData['createdAt'])
                              as Timestamp?;
                      final Timestamp? bTime =
                          (bData['updatedAt'] ?? bData['createdAt'])
                              as Timestamp?;
                      final int aMillis = aTime?.millisecondsSinceEpoch ?? 0;
                      final int bMillis = bTime?.millisecondsSinceEpoch ?? 0;
                      return bMillis.compareTo(aMillis);
                    });

                    if (filteredBookings.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada notifikasi baru.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredBookings.length,
                      itemBuilder: (context, index) {
                        final data =
                            filteredBookings[index].data()
                                as Map<String, dynamic>;
                        final String status = (data['statusBooking'] ?? '')
                            .toString()
                            .toLowerCase();
                        final String unitName =
                            data['namaUnit']?.toString() ?? 'Room';
                        final String stationName =
                            data['namaStation']?.toString() ?? 'Game Station';

                        String title = '';
                        String message = '';
                        Color statusColor = Colors.white;
                        IconData statusIcon = Icons.notifications_none_rounded;

                        if (status == 'confirmed') {
                          title = 'Booking Diterima';
                          message =
                              'Booking Anda telah dikonfirmasi oleh Game Station.';
                          statusColor = const Color(0xFF22D3EE);
                          statusIcon = Icons.check_circle_rounded;
                        } else if (status == 'cancelled') {
                          title = 'Booking Dibatalkan';
                          message = 'Booking Anda dibatalkan oleh pengelola.';
                          statusColor = const Color(0xFFEF4444);
                          statusIcon = Icons.cancel_rounded;
                        } else if (status == 'completed') {
                          title = 'Booking Selesai';
                          message =
                              'Terima kasih telah bermain.\nSilakan berikan rating dan review.';
                          statusColor = const Color(0xFF10B981);
                          statusIcon = Icons.stars_rounded;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF11172A,
                            ).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.15),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  statusIcon,
                                  color: statusColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message,
                                      style: const TextStyle(
                                        color: Color(0xFFCBD5E1),
                                        fontSize: 12.5,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$unitName - $stationName',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
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
              ),
            ],
          ),
        );
      },
    );
  }

  // Placeholder untuk Tab Booking / AI / Riwayat
  Widget _buildPlaceholderTab(String title, IconData icon, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF22D3EE).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: const Color(0xFF22D3EE), size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: AppTextStyle.h3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: AppTextStyle.body2.copyWith(color: const Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Navigasi Bawah Kustom (User Bottom Navigation Bar)
  Widget _buildUserBottomNavBar() {
    final double systemBottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryDarkNavy.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: AppColors.accentCyan.withValues(alpha: 0.08),
            width: 1.2,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: systemBottomInset),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                height: 84,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBottomNavItem(0, Icons.home_rounded, 'Beranda'),
                      _buildBottomNavItem(
                        1,
                        Icons.mail_outline_rounded,
                        'Booking',
                      ),
                      _buildBottomNavItem(2, Icons.smart_toy_outlined, 'AI'),
                      _buildBottomNavItem(3, Icons.history_rounded, 'Riwayat'),
                      _buildBottomNavItem(4, Icons.person_rounded, 'Profil'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final bool isActive = _activeTabIndex == index;
    final Color inactiveColor = AppColors.lightText;
    final Color activeColor = AppColors.white;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTabIndex = index;
        });
      },
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                gradient: isActive ? AppColors.gradientCyanToBlue : null,
                color: isActive ? null : Colors.transparent,
                border: Border.all(
                  color: isActive
                      ? AppColors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? activeColor : inactiveColor,
                size: isActive ? 21 : 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.caption2.copyWith(
                color: isActive ? AppColors.accentCyan : inactiveColor,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.4,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
