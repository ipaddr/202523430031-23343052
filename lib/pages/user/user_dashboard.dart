import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/news_service.dart';
import '../../models/news_model.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/widgets/common/custom_empty_state.dart';
import 'package:gamezone/widgets/common/custom_notification_button.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';
import '../../widgets/background.dart';
import '../profile_page.dart';
import 'ai_page.dart';
import 'booking_page.dart';
import 'booking_history_page.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final NewsService _newsService = NewsService();

  // FIX: Future disimpan sekali di initState, tidak dibuat ulang tiap rebuild.
  // Kalau dibuat langsung di build() / _buildBerandaTab(), Flutter akan
  // membuat Future baru setiap rebuild (dipicu stream Firestore) sehingga
  // FutureBuilder tidak pernah settle dan berita tidak tampil pada release build.
  late Future<List<NewsModel>> _newsFuture;

  int _activeTabIndex = 0;
  // Flag untuk mencegah double-navigation saat proses logout sedang berjalan.
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    // Inisialisasi sekali — Future ini tidak akan di-recreate selama widget hidup.
    _newsFuture = _newsService.getLatestGamingNews();
    debugPrint('================ GNEWS FUTURE INIT ================');
    debugPrint('GNEWS_API_KEY Loaded: Yes');
    debugPrint(
      'Future dibuat di initState — tidak akan di-recreate saat rebuild.',
    );
    debugPrint('====================================================');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Object? args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args.containsKey('initialTabIndex')) {
      final int? index = args['initialTabIndex'] as int?;
      if (index != null) {
        _activeTabIndex = index;
      }
    }
  }

  void _refreshUserData() {
    setState(() {});
  }

  /// Logout yang diinisiasi dari tab profil.
  /// Set _isLoggingOut = true SEBELUM signout agar build() tidak trigger
  /// navigasi ganda saat currentUser menjadi null.
  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);
    await _authService.logout();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/splash', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();

    if (currentUser == null) {
      // Guard: hanya jalankan sekali. Jika ProfilePage sudah memanggil logout
      // dan navigasi ke /splash, jangan panggil lagi dari sini.
      if (!_isLoggingOut) {
        _isLoggingOut = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushNamedAndRemoveUntil('/splash', (route) => false);
        });
      }
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: GameZoneBackground(
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<DocumentSnapshot>(
            stream: _firestoreService.getUserStream(currentUser.uid),
            builder: (context, userSnapshot) {
              Map<String, dynamic> userData = {};
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                userData = userSnapshot.data!.data() as Map<String, dynamic>;
              }

              final String userName =
                  userData['nama'] ??
                  userData['name'] ??
                  'Gamers';
              final String avatarUrl =
                  userData['foto'] ??
                  userData['photoUrl'] ??
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
        return const BookingPage(key: ValueKey('booking-tab'));
      case 2:
        return const AiPage(key: ValueKey('ai-tab'));
      case 3:
        return const BookingHistoryPage(key: ValueKey('history-tab'));
      case 4:
        return ProfilePage(
          key: const ValueKey('profile-tab'),
          isNestedTab: true,
          onProfileUpdated: _refreshUserData,
          onLogoutRequested: _handleLogout,
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
        // Hero Banner Berita Game Carousel
        FutureBuilder<List<NewsModel>>(
          future: _newsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildNewsLoadingCard();
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return _buildNewsErrorCard();
            }

            final List<NewsModel> newsList = snapshot.data!;
            return SizedBox(
              height: 160,
              child: PageView.builder(
                itemCount: newsList.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final NewsModel news = newsList[index];
                  return _buildHeroNewsBanner(news);
                },
              ),
            );
          },
        ),
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
                CustomUserAvatar(photoUrl: avatarUrl, size: 52),
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
          // Tombol Notifikasi — stream Firestore, dot indicator seperti Admin
          _UserNotificationButton(
            currentUser: currentUser,
            onPressed: () {
              if (currentUser != null) {
                _showUserNotifications(context, currentUser);
              }
            },
          ),
        ],
      ),
    );
  }

  // Hero Banner Berita Game Widget
  Widget _buildHeroNewsBanner(NewsModel news) {
    final String title = news.title.isNotEmpty ? news.title : 'Berita Terkini';
    final String description = news.description.isNotEmpty
        ? news.description
        : 'Ikuti perkembangan dunia game, esports, dan teknologi gaming terbaru.';
    final String? imageUrl = news.image.isNotEmpty ? news.image : null;

    debugPrint('GNews banner — imageUrl: ${imageUrl ?? "null (no image)"}');

    return GestureDetector(
      onTap: () async {
        if (news.url.isEmpty) return;
        try {
          final Uri uri = Uri.parse(news.url);
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            await launchUrl(uri);
          }
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal membuka berita.'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      },
      // Container luar: menentukan ukuran card (160px) + gradient background.
      // Gradient ini juga berfungsi sebagai fallback saat gambar belum/gagal muat.
      child: Container(
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
        // ClipRRect memotong konten agar tidak keluar dari radius card.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // ── Layer 1: Gambar GNews ──────────────────────────────────────
              // non-Positioned di Stack → Stack pakai ukuran dari SizedBox ini.
              // Kalau imageUrl null atau gambar gagal load, layer ini tidak
              // menambah visual apapun — gradient Container parent tetap terlihat
              // sebagai fallback yang sudah cukup menarik.
              if (imageUrl != null)
                SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      // Shimmer ringan saat loading
                      return const SizedBox.shrink();
                    },
                    errorBuilder: (context, error, stack) {
                      debugPrint('GNews image blocked/error: $imageUrl');
                      // Fallback: jangan kosong — tampilkan dekorasi
                      return Container(
                        width: double.infinity,
                        height: 160,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF0D1B4B),
                              Color(0xFF1A1060),
                              Color(0xFF0A2A4A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Lingkaran dekoratif background
                            Positioned(
                              right: -40,
                              top: -40,
                              child: Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.04),
                                ),
                              ),
                            ),
                            Positioned(
                              left: -20,
                              bottom: -20,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(
                                    0xFF4FACFE,
                                  ).withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            // Ikon sumber berita di tengah kanan
                            Positioned(
                              right: 20,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Icon(
                                  Icons.article_rounded,
                                  size: 72,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              // ── Layer 2: Overlay gelap (teks tetap terbaca) ───────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(
                          alpha: imageUrl != null ? 0.08 : 0.0,
                        ),
                        Colors.black.withValues(alpha: 0.70),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // ── Layer 3: Dekorasi lingkaran kiri atas ────────────────────
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

              // ── Layer 4: Ikon dekoratif kanan bawah (hanya tanpa gambar) ────
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

              // ── Layer 5: Konten teks ──────────────────────────────────────
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge + Source
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                          if (news.source.isNotEmpty)
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  news.source.toUpperCase(),
                                  style: AppTextStyle.caption2.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const Spacer(),

                      // Judul berita
                      Text(
                        title,
                        style: AppTextStyle.h3.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),

                      // Deskripsi
                      Text(
                        description,
                        style: AppTextStyle.body3.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          height: 1.3,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
  }

  Widget _buildNewsLoadingCard() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF334155).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
      ),
    );
  }

  Widget _buildNewsErrorCard() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.errorRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.errorRed,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              'Berita tidak tersedia saat ini',
              style: AppTextStyle.body3.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
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
              return const CustomEmptyState(
                icon: Icons.sports_esports_outlined,
                title: 'Belum ada stasiun game',
                subtitle: 'Belum ada stasiun game yang tersedia saat ini.',
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
                      .collection('notifications')
                      .where('userId', isEqualTo: currentUser.uid)
                      .where('roleTarget', isEqualTo: 'user')
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

                    final allNotifs = snapshot.data?.docs ?? [];

                    final List<DocumentSnapshot> filteredNotifs = allNotifs.toList();

                    filteredNotifs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final Timestamp? aTime = aData['createdAt'] as Timestamp?;
                      final Timestamp? bTime = bData['createdAt'] as Timestamp?;
                      final int aMillis = aTime?.millisecondsSinceEpoch ?? 0;
                      final int bMillis = bTime?.millisecondsSinceEpoch ?? 0;
                      return bMillis.compareTo(aMillis);
                    });

                    if (filteredNotifs.isEmpty) {
                      return const CustomEmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'Belum ada notifikasi baru.',
                        subtitle:
                            'Status real-time pemesanan game station Anda akan muncul di sini.',
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredNotifs.length,
                      itemBuilder: (context, index) {
                        final data =
                            filteredNotifs[index].data()
                                as Map<String, dynamic>;
                        final String title = data['title']?.toString() ?? 'Notifikasi';
                        final String message = data['message']?.toString() ?? '';
                        final String type = (data['type'] ?? '').toString();

                        Color statusColor = Colors.white;
                        IconData statusIcon = Icons.notifications_none_rounded;

                        if (type.contains('confirmed') || type.contains('success')) {
                          statusColor = const Color(0xFF22D3EE);
                          statusIcon = Icons.check_circle_rounded;
                        } else if (type.contains('cancelled') || type.contains('rejected') || type.contains('expired')) {
                          statusColor = const Color(0xFFEF4444);
                          statusIcon = Icons.cancel_rounded;
                        } else if (type.contains('checkin')) {
                          statusColor = const Color(0xFF06B6D4);
                          statusIcon = Icons.sports_esports_rounded;
                        } else if (type.contains('completed')) {
                          statusColor = const Color(0xFF10B981);
                          statusIcon = Icons.stars_rounded;
                        } else {
                          statusColor = const Color(0xFFF59E0B);
                          statusIcon = Icons.info_outline_rounded;
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

// ─── Tombol Notifikasi User ──────────────────────────────────────────────────
// Mengikuti pola yang sama dengan _NotificationButton di admin_header.dart:
// • Stream getUserStream → ambil lastOpenedNotifications
// • Stream getUserBookingNotificationsStream → hitung notif belum dibaca
// • Tampilkan dot indicator jika ada; simpan timestamp saat dibuka
class _UserNotificationButton extends StatefulWidget {
  final User? currentUser;
  final VoidCallback onPressed;

  const _UserNotificationButton({
    required this.currentUser,
    required this.onPressed,
  });

  @override
  State<_UserNotificationButton> createState() =>
      _UserNotificationButtonState();
}

class _UserNotificationButtonState extends State<_UserNotificationButton> {
  DateTime? _localLastOpened;

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser == null) {
      return CustomNotificationButton(hasNotification: false, onTap: () {});
    }

    final FirestoreService firestoreService = FirestoreService();

    return StreamBuilder<DocumentSnapshot>(
      stream: firestoreService.getUserStream(widget.currentUser!.uid),
      builder: (context, userSnap) {
        Timestamp? lastOpened;
        if (userSnap.hasData && userSnap.data!.exists) {
          final userData = userSnap.data!.data() as Map<String, dynamic>;
          lastOpened =
              userData['lastOpenedBookingNotifications'] as Timestamp? ??
              userData['lastOpenedNotifications'] as Timestamp?;
        }

        DateTime? compareTime = lastOpened?.toDate();
        if (_localLastOpened != null) {
          if (compareTime == null || _localLastOpened!.isAfter(compareTime)) {
            compareTime = _localLastOpened;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: widget.currentUser!.uid)
              .where('roleTarget', isEqualTo: 'user')
              .snapshots(),
          builder: (context, bookingSnap) {
            bool showDot = false;

            if (bookingSnap.hasData && bookingSnap.data!.docs.isNotEmpty) {
              if (compareTime == null) {
                showDot = true;
              } else {
                for (final doc in bookingSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                  if (createdAt != null &&
                      createdAt.toDate().isAfter(compareTime)) {
                    showDot = true;
                    break;
                  }
                }
              }
            }

            return CustomNotificationButton(
              hasNotification: showDot,
              onTap: () {
                // Simpan timestamp buka ke Firestore dan state lokal
                final now = DateTime.now();
                setState(() => _localLastOpened = now);
                firestoreService.updateUser(widget.currentUser!.uid, {
                  'lastOpenedBookingNotifications': now,
                });
                widget.onPressed();
              },
            );
          },
        );
      },
    );
  }
}
