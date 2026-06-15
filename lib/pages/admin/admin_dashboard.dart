import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:gamezone/services/auth_service.dart';
import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/widgets/common/background.dart';
import 'package:gamezone/widgets/admin/admin_bottom_navbar.dart';
import 'package:gamezone/widgets/admin/admin_header.dart';
import 'package:gamezone/widgets/common/stats_card.dart';
import 'package:gamezone/widgets/admin/room_status_chart.dart';
import 'package:gamezone/pages/admin/room_page.dart';
import 'package:gamezone/pages/admin/booking_page.dart';
import '../shared/profile_page.dart';

// Dashboard utama admin yang hanya menyusun widget reusable GameZone.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  late Future<_DashboardPageData> _dashboardFuture;
  int _activeTabIndex = 0;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardData();
  }

  Future<_DashboardPageData> _loadDashboardData() async {
    final currentUser = await _authService.resolveCurrentUser();
    Map<String, dynamic>? station;
    Map<String, dynamic>? userFirestoreData;

    // Mengambil station aktif milik admin login agar semua ringkasan bisa difilter.
    if (currentUser != null) {
      final Future<Map<String, dynamic>?> userFuture = _firestoreService
          .getUserData(currentUser.uid);

      userFirestoreData = await userFuture;
      final String? userName =
          userFirestoreData?['nama']?.toString() ??
          userFirestoreData?['name']?.toString();
      final String? userEmail =
          userFirestoreData?['email']?.toString() ?? currentUser.email;

      station = await _firestoreService.getStationByOwnerId(
        currentUser.uid,
        email: userEmail,
        name: userName,
      );
    }

    final String? stationId = station?['id']?.toString();
    DashboardAdminSummary summary;
    UnitStatusSummary unitStatus;

    if (stationId != null && stationId.isNotEmpty) {
      await _firestoreService.completeFinishedBookings(stationId: stationId);
      final Future<DashboardAdminSummary> summaryFuture = _firestoreService
          .getStationDashboardAdminSummary(stationId);
      final Future<UnitStatusSummary> unitStatusFuture = _firestoreService
          .getStationUnitStatusSummary(stationId);

      summary = await summaryFuture;
      unitStatus = await unitStatusFuture;
    } else {
      summary = const DashboardAdminSummary(
        totalBooking: 0,
        totalUnit: 0,
        bookingHariIni: 0,
        totalPemasukan: 0,
        ratingGameStation: 0,
        unitTerlaris: null,
        aktivitasTerbaru: [],
      );
      unitStatus = const UnitStatusSummary(totalUnit: 0, full: 0, available: 0);
    }

    return _DashboardPageData(
      summary: summary,
      unitStatus: unitStatus,
      station: station,
      userFirestoreData: userFirestoreData,
    );
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _dashboardFuture = _loadDashboardData();
    });
    await _dashboardFuture;
  }

  Future<void> _showNotifications({
    required BuildContext context,
    required String? stationId,
    required String stationName,
    required User? currentUser,
  }) async {
    String resolvedStationId = stationId ?? '';
    String resolvedStationName = stationName;

    if (resolvedStationId.isEmpty && currentUser != null) {
      final Map<String, dynamic>? fallbackStation = await _firestoreService
          .getStationByOwnerId(
            currentUser.uid,
            email: currentUser.email,
            name: currentUser.displayName,
          );
      if (fallbackStation != null) {
        resolvedStationId = fallbackStation['id']?.toString() ?? '';
        resolvedStationName =
            fallbackStation['namaStation']?.toString() ??
            fallbackStation['stationName']?.toString() ??
            resolvedStationName;
      }
    }

    if (!context.mounted) return;

    if (resolvedStationId.isEmpty) {
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

    // Lembar notifikasi booking terbaru milik stasiun admin aktif.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.primaryDarkNavy,
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
                resolvedStationName,
                style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('roleTarget', isEqualTo: 'admin')
                      .where('stationId', isEqualTo: resolvedStationId)
                      .snapshots(),
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
                        final String title =
                            data['title']?.toString() ?? 'Booking';
                        final String message =
                            data['message']?.toString() ?? '';
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
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message,
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

  String _formatRelativeTime(Timestamp? timestamp) {
    // Mengubah stempel waktu menjadi label waktu yang singkat.
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
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();

    if (currentUser == null) {
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
        backgroundColor: AppColors.primaryDarkNavy,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Menonaktifkan resize agar latar belakang tetap stabil di belakang keyboard
      resizeToAvoidBottomInset: false,
      body: GameZoneBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FutureBuilder<_DashboardPageData>(
                  future: _dashboardFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentCyan,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      debugPrint(
                        'Error loading dashboard: ${snapshot.error}\nStacktrace: ${snapshot.stackTrace}',
                      );
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Gagal memuat dashboard: ${snapshot.error}',
                            style: AppTextStyle.body1.copyWith(
                              color: AppColors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final data = snapshot.data;
                    if (data == null) {
                      return Center(
                        child: Text(
                          'Data dashboard kosong',
                          style: AppTextStyle.body1.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      );
                    }

                    final userData = data.userFirestoreData;
                    final stationData = data.station;
                    final Timestamp? lastOpenedBookingNotifications =
                        userData?['lastOpenedBookingNotifications']
                            as Timestamp?;
                    final String adminName =
                        userData?['nama'] ?? userData?['name'] ?? 'Admin';
                    final String stationName =
                        stationData?['namaStation'] ??
                        stationData?['stationName'] ??
                        'GameZone Station';

                    String? avatarUrl;
                    if (stationData != null) {
                      final foto = stationData['foto'];
                      if (foto is String && foto.trim().isNotEmpty) {
                        avatarUrl = foto.trim();
                      } else if (foto is List &&
                          foto.isNotEmpty &&
                          foto.first != null &&
                          foto.first.toString().trim().isNotEmpty) {
                        avatarUrl = foto.first.toString().trim();
                      }
                    }
                    avatarUrl ??=
                        userData?['foto'] ?? userData?['photoUrl'] ?? '';

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          children: [
                            AdminHeader(
                              currentUser: currentUser,
                              adminName: adminName,
                              stationName: stationName,
                              avatarUrl: avatarUrl,
                              stationId: stationData?['id']?.toString(),
                              localLastOpened: lastOpenedBookingNotifications
                                  ?.toDate(),
                              onNotificationPressed: () => _showNotifications(
                                context: context,
                                stationId: stationData?['id']?.toString(),
                                stationName: stationName,
                                currentUser: currentUser,
                              ),
                              onNotificationOpened: (_) {},
                            ),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: Duration.zero,
                                child: _activeTabIndex == 3
                                    ? ProfilePage(
                                        key: const ValueKey('profile-tab'),
                                        isNestedTab: true,
                                        onProfileUpdated: _refreshDashboard,
                                      )
                                    : _activeTabIndex == 2
                                    ? BookingPage(
                                        key: const ValueKey('booking-tab'),
                                        isNestedTab: true,
                                        initialCurrentUser: currentUser,
                                        initialStation: data.station,
                                        initialUserData: data.userFirestoreData,
                                      )
                                    : _activeTabIndex == 1
                                    ? RoomPage(
                                        key: const ValueKey('room-tab'),
                                        isNestedTab: true,
                                        initialCurrentUser: currentUser,
                                        initialStation: data.station,
                                        initialUserData: data.userFirestoreData,
                                      )
                                    : _buildDashboardContent(
                                        summary: data.summary,
                                        unitStatus: data.unitStatus,
                                        stationId:
                                            stationData?['id']?.toString() ??
                                            '',
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (MediaQuery.of(context).viewInsets.bottom == 0)
                AdminBottomNavBar(
                  currentIndex: _activeTabIndex,
                  onTabSelected: (index) {
                    setState(() {
                      _activeTabIndex = index;
                    });
                    if (index == 0) {
                      _refreshDashboard();
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent({
    required DashboardAdminSummary summary,
    required UnitStatusSummary unitStatus,
    required String stationId,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        RatingAnalyticsCard(
          stationId: stationId,
          averageRating: summary.ratingGameStation,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.25,
          children: [
            StatsCard(
              icon: Icons.book_online_rounded,
              title: 'Total Booking',
              value: summary.totalBooking.toString(),
              iconColor: AppColors.accentCyan,
            ),
            StatsCard(
              icon: Icons.devices_other_rounded,
              title: 'Total Unit',
              value: summary.totalUnit.toString(),
              iconColor: AppColors.accentCyan,
            ),
          ],
        ),
        const SizedBox(height: 16),
        TodayBookingCard(value: summary.bookingHariIni.toString()),
        const SizedBox(height: 16),
        RevenueCard(amount: summary.totalPemasukan),
        const SizedBox(height: 16),
        UnitStatusChart(
          totalUnit: unitStatus.totalUnit,
          full: unitStatus.full,
          available: unitStatus.available,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class RatingAnalyticsCard extends StatelessWidget {
  final String stationId;
  final double averageRating;

  const RatingAnalyticsCard({
    super.key,
    required this.stationId,
    required this.averageRating,
  });

  @override
  Widget build(BuildContext context) {
    if (stationId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('stationId', isEqualTo: stationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.accentCyan),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final totalReview = docs.length;

        // Urutkan ulasan berdasarkan createdAt secara menurun (terbaru di atas)
        final sortedDocs = [...docs];
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final Timestamp? aTime = aData['createdAt'] as Timestamp?;
          final Timestamp? bTime = bData['createdAt'] as Timestamp?;
          final int aMillis = aTime?.millisecondsSinceEpoch ?? 0;
          final int bMillis = bTime?.millisecondsSinceEpoch ?? 0;
          return bMillis.compareTo(aMillis);
        });

        final latestReviews = sortedDocs.take(5).toList();

        return Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rating Station',
                            style: AppTextStyle.body1.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ringkasan performa ulasan stasiun game Anda.',
                            style: AppTextStyle.caption2.copyWith(
                              color: AppColors.softGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            averageRating > 0
                                ? averageRating.toStringAsFixed(1)
                                : '0.0',
                            style: AppTextStyle.body2.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($totalReview)',
                            style: AppTextStyle.caption2.copyWith(
                              color: AppColors.softGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF334155), height: 1),

              // Daftar Ulasan Terbaru
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Terbaru',
                      style: AppTextStyle.caption1.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (latestReviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'Belum ada ulasan',
                            style: AppTextStyle.body3.copyWith(
                              color: AppColors.softGray,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ...latestReviews.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final String userName =
                            data['userName']?.toString() ?? 'Gamers';
                        final int rating =
                            (data['rating'] as num?)?.toInt() ?? 5;
                        final String comment =
                            data['comment']?.toString() ?? '';
                        final Timestamp? createdAt =
                            data['createdAt'] as Timestamp?;
                        final String dateStr = createdAt != null
                            ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                            : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.02),
                            ),
                          ),
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
                                      style: AppTextStyle.caption1.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    dateStr,
                                    style: AppTextStyle.caption2.copyWith(
                                      color: AppColors.softGray,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(5, (index) {
                                  return Icon(
                                    Icons.star_rounded,
                                    color: index < rating
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF475569),
                                    size: 12,
                                  );
                                }),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                comment,
                                style: AppTextStyle.body3.copyWith(
                                  color: const Color(0xFFCBD5E1),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardPageData {
  final DashboardAdminSummary summary;
  final UnitStatusSummary unitStatus;
  final Map<String, dynamic>? station;
  final Map<String, dynamic>? userFirestoreData;

  const _DashboardPageData({
    required this.summary,
    required this.unitStatus,
    this.station,
    this.userFirestoreData,
  });
}
