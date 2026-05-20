import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../styles/app_colors.dart';
import '../../styles/app_textstyle.dart';
import '../../widgets/background.dart';
import '../profile_page.dart';
import 'users_page.dart';
import 'verify_page.dart';

class SuperAdminDashboardPage extends StatefulWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  State<SuperAdminDashboardPage> createState() => _SuperAdminDashboardPageState();
}

class _SuperAdminDashboardPageState extends State<SuperAdminDashboardPage> {
  int _activeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameZoneBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Tetap (Gaya Desain Figma)
              _buildHeader(),
              
              // Area Konten Dinamis
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildActiveTabContent(),
                ),
              ),
              
              // Navigasi Bar Neon Berkilau
              _buildBottomNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  // --- PEMBUAT KOMPONEN UI ---

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Halo, Super Admin!',
                    style: TextStyle(
                      color: Color(0xFF9AA3C3),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard Platform',
                    style: AppTextStyle.h3.copyWith(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Wadah Ikon Lonceng
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141B31),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: Color(0xFF94A3B8),
                          size: 22,
                        ),
                        Positioned(
                          top: 13,
                          right: 13,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22D3EE),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x9022D3EE),
                                  blurRadius: 6,
                                  spreadRadius: 1.5,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Avatar Profil Pengguna (Desain Premium dari Figma)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF22D3EE).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      image: const DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&q=80&w=150',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
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

  // --- TAB 1: BERANDA (Tata Letak Figma) ---
  // --- TAB 1: BERANDA (Statistik & Lini Masa Firestore Langsung) ---
  Widget _buildBerandaTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('stations').snapshots(),
          builder: (context, stationSnapshot) {
            // Hitung metrik database dinamis
            int totalUsers = 0;
            int totalStations = 0;
            int totalRooms = 0;
            int totalAdmins = 0;

            if (userSnapshot.hasData) {
              final usersList = userSnapshot.data!.docs;
              totalUsers = usersList.where((doc) => doc.get('role') == 'user').length;
              totalAdmins = usersList.where((doc) => doc.get('role') == 'admin').length;
            }

            if (stationSnapshot.hasData) {
              final stationsList = stationSnapshot.data!.docs;
              totalStations = stationsList.length;
              for (var doc in stationsList) {
                final data = doc.data() as Map<String, dynamic>;
                final rooms = data['jumlahRooms'] ?? 0;
                totalRooms += (rooms is int) ? rooms : (int.tryParse(rooms.toString()) ?? 0);
              }
            }

            // Gabungkan ke dalam umpan aktivitas dinamis kronologis
            final List<Map<String, dynamic>> activities = [];

            if (userSnapshot.hasData) {
              for (var doc in userSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final Timestamp? createdAt = data['createdAt'] as Timestamp?;
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
                final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                final String namaStation = data['namaStation'] ?? 'Game Station';
                final int rooms = data['jumlahRooms'] ?? 0;

                activities.add({
                  'title': 'Tambah Room Game Station',
                  'subtitle': 'Station "$namaStation" memiliki $rooms Room/PC',
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                        _buildStatCard(
                          icon: Icons.people_rounded,
                          iconColor: const Color(0xFF22D3EE),
                          label: 'TOTAL USER',
                          value: totalUsers.toString().replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]},',
                              ),
                        ),
                        _buildStatCard(
                          icon: Icons.gamepad_rounded,
                          iconColor: const Color(0xFFC084FC),
                          label: 'GAME STATION',
                          value: totalStations.toString(),
                        ),
                        _buildStatCard(
                          icon: Icons.meeting_room_rounded,
                          iconColor: const Color(0xFF22D3EE),
                          label: 'TOTAL ROOM',
                          value: totalRooms.toString().replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]},',
                              ),
                        ),
                        _buildStatCard(
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
                          'Aktivitas Terbaru Platform',
                          style: AppTextStyle.h4.copyWith(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _activeTabIndex = 1; // Direct to Verification
                            });
                          },
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
                          color: const Color(0xFF11172A).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF22D3EE).withValues(alpha: 0.05),
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
                      ...activities.take(5).map((act) {
                        return _buildActivityItem(
                          title: act['title'] as String,
                          subtitle: act['subtitle'] as String,
                          timeText: _formatRelativeTime(act['timestamp'] as Timestamp?),
                          categoryText: act['categoryText'] as String,
                          isCyanStatus: act['isCyanStatus'] as bool,
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
  }

  // Utilitas pembantu untuk memformat teks Waktu Relatif dinamis
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
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required String title,
    required String subtitle,
    required String timeText,
    required String categoryText,
    required bool isCyanStatus,
    IconData? icon,
    Color? iconColor,
    String? imagePath,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF11172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.05),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          // Ikon atau miniatur Gambar
          if (imagePath != null)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFF22D3EE)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon ?? Icons.info_outline_rounded,
                color: iconColor ?? const Color(0xFF22D3EE),
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
                  subtitle,
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
                timeText,
                style: TextStyle(
                  color: isCyanStatus ? const Color(0xFF22D3EE) : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: isCyanStatus ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                categoryText,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          height: 70,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF22D3EE).withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'BERANDA'),
              _buildNavItem(1, Icons.fact_check_rounded, 'VERIFIKASI'),
              _buildNavItem(2, Icons.people_outline_rounded, 'USER'),
              _buildNavItem(3, Icons.person_outline_rounded, 'PROFIL'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isActive = _activeTabIndex == index;
    final Color color = isActive ? const Color(0xFF22D3EE) : const Color(0xFF64748B);

    return InkWell(
      onTap: () {
        setState(() {
          _activeTabIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: isActive ? 22 : 20),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
