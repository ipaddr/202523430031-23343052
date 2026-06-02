import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

import '../../styles/app_colors.dart';
import '../../styles/app_textstyle.dart';
import '../../widgets/background.dart';
import '../../widgets/superadmin/superadmin_activity_item.dart';
import '../../widgets/superadmin/superadmin_bottom_navbar.dart';
import '../../widgets/superadmin/superadmin_sheet_header.dart';
import '../../widgets/superadmin/superadmin_stat_card.dart';
import '../../widgets/superadmin/superadmin_header.dart';
import '../profile_page.dart';
import 'users_page.dart';
import 'verify_page.dart';

// Halaman utama super admin yang menggabungkan ringkasan, aktivitas, dan tab.
class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() =>
      _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  int _activeTabIndex = 0;
  DateTime? _localLastOpened;
  bool _isLoggingOut = false;

  void _handleNotificationOpened(DateTime now) {
    setState(() {
      _localLastOpened = now;
    });
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
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
        ),
      );
    }

    // Layout utama berisi header, konten tab, lalu navigasi bawah.
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Mengaktifkan resize agar konten utama menyesuaikan tinggi di atas keyboard
      resizeToAvoidBottomInset: true,
      body: GameZoneBackground(
        child: SafeArea(
          // Area konten utama tanpa memotong background navbar di bawah.
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),

              // Area Konten Dinamis
              Expanded(
                child: AnimatedSwitcher(
                  duration: Duration.zero,
                  child: _buildActiveTabContent(),
                ),
              ),

              // Navigasi Bar Neon Berkilau (Hanya muncul jika keyboard tidak aktif)
              if (MediaQuery.of(context).viewInsets.bottom == 0)
                SuperAdminBottomNavBar(
                  currentIndex: _activeTabIndex,
                  onTabSelected: (index) =>
                      setState(() => _activeTabIndex = index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final currentUser = _authService.getCurrentUser();

    return SuperAdminHeader(
      currentUser: currentUser,
      localLastOpened: _localLastOpened,
      onNotificationOpened: _handleNotificationOpened,
      onNotificationPressed: () => _showNotifications(context),
    );
  }

  void _showNotifications(BuildContext context) {
    // Sheet ini menampilkan daftar pendaftaran admin baru yang belum dibaca.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
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
              SuperAdminSheetHeader(title: 'Pendaftaran Admin Baru'),
              const SizedBox(height: 16),
              // Daftar Notifikasi Khusus Admin Game Station
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestoreService.getPendingAdminsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF22D3EE),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Belum ada pendaftaran admin baru.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      );
                    }

                    final List<Map<String, dynamic>> activities = [];
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final Timestamp? createdAt =
                          data['createdAt'] as Timestamp?;
                      final String nama = data['nama'] ?? 'Admin';
                      final String email = data['email'] ?? '';

                      activities.add({
                        'title': 'Admin Game Station Terdaftar',
                        'subtitle': 'Admin "$nama" ($email) telah mendaftar',
                        'timestamp': createdAt,
                        'categoryText': 'Mitra',
                        'icon': Icons.admin_panel_settings_rounded,
                        'iconColor': const Color(0xFFC084FC),
                      });
                    }

                    // Urutkan kronologis
                    activities.sort((a, b) {
                      final Timestamp? tA = a['timestamp'] as Timestamp?;
                      final Timestamp? tB = b['timestamp'] as Timestamp?;
                      if (tA == null && tB == null) return 0;
                      if (tA == null) return -1;
                      if (tB == null) return 1;
                      return tB.compareTo(tA);
                    });

                    return ListView.builder(
                      itemCount: activities.length > 10
                          ? 10
                          : activities.length,
                      itemBuilder: (context, idx) {
                        final act = activities[idx];
                        return SuperAdminActivityItem(
                          title: act['title'] as String,
                          subtitle: act['subtitle'] as String,
                          timeText: _formatRelativeTime(
                            act['timestamp'] as Timestamp?,
                          ),
                          categoryText: act['categoryText'] as String,
                          icon: act['icon'] as IconData?,
                          iconColor: act['iconColor'] as Color?,
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

  void _showAllActivities(BuildContext context) {
    // Sheet ini menggabungkan aktivitas user dan station secara kronologis.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
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
              SuperAdminSheetHeader(title: 'Semua Aktivitas Platform'),
              const SizedBox(height: 16),
              // Daftar Semua Aktivitas
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestoreService.getUsersStream(),
                  builder: (context, userSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: _firestoreService.getStationsStream(),
                      builder: (context, stationSnapshot) {
                        final List<Map<String, dynamic>> activities = [];

                        if (userSnapshot.hasData) {
                          for (var doc in userSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final Timestamp? createdAt =
                                data['createdAt'] as Timestamp?;
                            final String role = data['role'] ?? 'user';
                            final String nama = data['nama'] ?? 'User';
                            final String email = data['email'] ?? '';

                            if (role == 'user') {
                              activities.add({
                                'title': 'Registrasi User Baru',
                                'subtitle':
                                    'User "$nama" ($email) telah bergabung',
                                'timestamp': createdAt,
                                'categoryText': 'Pengguna',
                                'icon': Icons.person_add_rounded,
                                'iconColor': const Color(0xFF22D3EE),
                              });
                            } else if (role == 'admin') {
                              activities.add({
                                'title': 'Admin Game Station Terdaftar',
                                'subtitle':
                                    'Admin "$nama" ($email) telah mendaftar',
                                'timestamp': createdAt,
                                'categoryText': 'Mitra',
                                'icon': Icons.admin_panel_settings_rounded,
                                'iconColor': const Color(0xFFC084FC),
                              });
                            }
                          }
                        }

                        if (stationSnapshot.hasData) {
                          for (var doc in stationSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final Timestamp? createdAt =
                                data['createdAt'] as Timestamp?;
                            final String namaStation =
                                data['namaStation'] ?? 'Game Station';
                            final int units =
                                data['jumlahUnits'] ?? data['totalUnits'] ?? 0;

                            activities.add({
                              'title': 'Tambah Unit Game Station',
                              'subtitle':
                                  'Station "$namaStation" memiliki $units Unit',
                              'timestamp': createdAt,
                              'categoryText': 'Station',
                              'icon': Icons.add_business_rounded,
                              'iconColor': const Color(0xFF10B981),
                            });
                          }
                        }

                        // Urutkan kronologis terbaru ke terlama
                        activities.sort((a, b) {
                          final Timestamp? tA = a['timestamp'] as Timestamp?;
                          final Timestamp? tB = b['timestamp'] as Timestamp?;
                          if (tA == null && tB == null) return 0;
                          if (tA == null) return -1;
                          if (tB == null) return 1;
                          return tB.compareTo(tA);
                        });

                        if (activities.isEmpty) {
                          return const Center(
                            child: Text(
                              'Belum ada aktivitas platform.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: activities.length,
                          itemBuilder: (context, idx) {
                            final act = activities[idx];
                            return SuperAdminActivityItem(
                              title: act['title'] as String,
                              subtitle: act['subtitle'] as String,
                              timeText: _formatRelativeTime(
                                act['timestamp'] as Timestamp?,
                              ),
                              categoryText: act['categoryText'] as String,
                              icon: act['icon'] as IconData?,
                              iconColor: act['iconColor'] as Color?,
                            );
                          },
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

  Widget _buildActiveTabContent() {
    // Konten berganti sesuai tab yang sedang aktif.
    switch (_activeTabIndex) {
      case 0:
        return _buildBerandaTab();
      case 1:
        return const VerifyPage();
      case 2:
        return const UsersPage();
      case 3:
        return const ProfilePage(isNestedTab: true);
      default:
        return _buildBerandaTab();
    }
  }

  Widget _buildBerandaTab() {
    // Beranda menampilkan statistik utama dan lima aktivitas terbaru.
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getUsersStream(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getStationsStream(),
          builder: (context, stationSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('units')
                  .snapshots(),
              builder: (context, unitSnapshot) {
                // Hitung metrik database dinamis
                int totalUsers = 0;
                int totalStations = 0;
                int totalUnits = unitSnapshot.data?.docs.length ?? 0;
                int totalAdmins = 0;

                if (userSnapshot.hasData) {
                  final usersList = userSnapshot.data!.docs;
                  totalUsers = usersList
                      .where((doc) => doc.get('role') == 'user')
                      .length;
                  totalAdmins = usersList
                      .where((doc) => doc.get('role') == 'admin')
                      .length;
                }

                if (stationSnapshot.hasData) {
                  final stationsList = stationSnapshot.data!.docs;
                  totalStations = stationsList.length;
                }

                // Gabungkan ke dalam umpan aktivitas dinamis kronologis
                final List<Map<String, dynamic>> activities = [];

                if (userSnapshot.hasData) {
                  for (var doc in userSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp? createdAt =
                        data['createdAt'] as Timestamp?;
                    final String role = data['role'] ?? 'user';
                    final String nama = data['nama'] ?? 'User';
                    final String email = data['email'] ?? '';

                    if (role == 'user') {
                      activities.add({
                        'title': 'Registrasi User Baru',
                        'subtitle': 'User "$nama" ($email) telah bergabung',
                        'timestamp': createdAt,
                        'categoryText': 'Pengguna',
                        'isCyanStatus': true,
                        'icon': Icons.person_add_rounded,
                        'iconColor': const Color(0xFF22D3EE),
                      });
                    } else if (role == 'admin') {
                      activities.add({
                        'title': 'Admin Game Station Terdaftar',
                        'subtitle': 'Admin "$nama" ($email) telah mendaftar',
                        'timestamp': createdAt,
                        'categoryText': 'Mitra',
                        'isCyanStatus': false,
                        'icon': Icons.admin_panel_settings_rounded,
                        'iconColor': const Color(0xFFC084FC),
                      });
                    }
                  }
                }

                if (stationSnapshot.hasData) {
                  for (var doc in stationSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp? createdAt =
                        data['createdAt'] as Timestamp?;
                    final String namaStation =
                        data['namaStation'] ?? 'Game Station';
                    final int units =
                        data['jumlahUnits'] ?? data['totalUnits'] ?? 0;

                    activities.add({
                      'title': 'Tambah Unit Game Station',
                      'subtitle': 'Station "$namaStation" memiliki $units Unit',
                      'timestamp': createdAt,
                      'categoryText': 'Station',
                      'isCyanStatus': false,
                      'icon': Icons.add_business_rounded,
                      'iconColor': const Color(0xFF10B981),
                    });
                  }
                }

                // Urutkan secara kronologis (menurun), menangani nilai null dengan baik (misal: latensi server)
                activities.sort((a, b) {
                  final Timestamp? tA = a['timestamp'] as Timestamp?;
                  final Timestamp? tB = b['timestamp'] as Timestamp?;
                  if (tA == null && tB == null) {
                    return 0;
                  }
                  if (tA == null) {
                    return -1;
                  }
                  if (tB == null) {
                    return 1;
                  }
                  return tB.compareTo(tA);
                });

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      children: [
                        // Grid Bagian Statistik tanpa persentase
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.25,
                          children: [
                            SuperAdminStatCard(
                              icon: Icons.people_rounded,
                              iconColor: const Color(0xFF22D3EE),
                              label: 'TOTAL USER',
                              value: totalUsers.toString().replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]},',
                              ),
                            ),
                            SuperAdminStatCard(
                              icon: Icons.gamepad_rounded,
                              iconColor: const Color(0xFFC084FC),
                              label: 'GAME STATION',
                              value: totalStations.toString(),
                            ),
                            SuperAdminStatCard(
                              icon: Icons.meeting_room_rounded,
                              iconColor: const Color(0xFF22D3EE),
                              label: 'TOTAL UNIT',
                              value: totalUnits.toString().replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]},',
                              ),
                            ),
                            SuperAdminStatCard(
                              icon: Icons.admin_panel_settings_rounded,
                              iconColor: const Color(0xFFC084FC),
                              label: 'TOTAL ADMIN',
                              value: totalAdmins.toString(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Judul Bagian
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Aktivitas Terbaru',
                              style: AppTextStyle.h4.copyWith(
                                color: AppColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showAllActivities(context),
                              child: const Text(
                                'Lihat Semua',
                                style: TextStyle(
                                  color: Color(0xFF22D3EE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Daftar Aktivitas Terbaru (Dinamis Langsung dari Firestore)
                        if (activities.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF11172A,
                              ).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(
                                  0xFF22D3EE,
                                ).withValues(alpha: 0.05),
                                width: 1.2,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Belum ada aktivitas terbaru',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          ...activities.take(5).toList().map((act) {
                            return SuperAdminActivityItem(
                              title: act['title'] as String,
                              subtitle: act['subtitle'] as String,
                              timeText: _formatRelativeTime(
                                act['timestamp'] as Timestamp?,
                              ),
                              categoryText: act['categoryText'] as String,
                              icon: act['icon'] as IconData?,
                              iconColor: act['iconColor'] as Color?,
                            );
                          }),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Utilitas pembantu untuk memformat teks Waktu Relatif dinamis
  String _formatRelativeTime(Timestamp? timestamp) {
    // Helper untuk mengubah timestamp menjadi label waktu yang singkat.
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
}
