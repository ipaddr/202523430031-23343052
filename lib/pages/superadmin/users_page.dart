import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_textstyle.dart';
import '../../styles/app_theme.dart';
import 'users_detail_page.dart';

/// Halaman Kelola Pengguna & Game Station untuk Super Admin
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _userSearchQuery = '';
  int _activeTab = 0; // 0 = Semua Users, 1 = Pengguna, 2 = Game Station

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Aksi hapus untuk data user di Firestore.
  Future<void> _deleteUser(String userId, String name) async {
    final bool confirm = await _showConfirmDeleteDialog(
      'Hapus Pengguna',
      'Apakah Anda yakin ingin menghapus pengguna "$name" secara permanen dari sistem?',
    );
    if (confirm) {
      try {
        await _firestoreService.deleteUser(userId);
        _showSuccessSnackBar('Pengguna berhasil dihapus secara permanen!');
      } catch (e) {
        _showErrorSnackBar('Gagal menghapus pengguna: $e');
      }
    }
  }

  // Aksi hapus untuk data game station di Firestore.
  Future<void> _deleteStation(String stationId, String name) async {
    final bool confirm = await _showConfirmDeleteDialog(
      'Hapus Game Station',
      'Apakah Anda yakin ingin menghapus stasiun game "$name" secara permanen dari sistem?',
    );
    if (confirm) {
      try {
        await _firestoreService.deleteStation(stationId);
        _showSuccessSnackBar('Game Station berhasil dihapus secara permanen!');
      } catch (e) {
        _showErrorSnackBar('Gagal menghapus stasiun game: $e');
      }
    }
  }

  // Dialog konfirmasi sebelum data benar-benar dihapus.
  Future<bool> _showConfirmDeleteDialog(String title, String content) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Theme(
          data: ThemeData.dark(),
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF1E293B)),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Hapus',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }

  void _showSuccessSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: const Color(0xFF10B981), content: Text(msg)),
      );
    }
  }

  void _showErrorSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text(msg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Konten halaman
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryDark.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.08),
                      width: 1.1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: AppTextStyle.body2.copyWith(color: AppColors.white),
                    onChanged: (val) {
                      setState(() {
                        _userSearchQuery = val.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari nama, email, atau nama station...',
                      hintStyle: AppTextStyle.body3.copyWith(
                        color: AppColors.softGray,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.softGray,
                        size: 20,
                      ),
                      suffixIcon: _userSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.softGray,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _userSearchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              // Stream utama untuk user dan station agar daftar selalu terbaru.
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestoreService.getUsersStream(),
                  builder: (context, usersSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: _firestoreService.getStationsStream(),
                      builder: (context, stationsSnapshot) {
                        final int totalUsers = usersSnapshot.hasData
                            ? usersSnapshot.data!.docs
                                  .where((doc) => doc.get('role') == 'user')
                                  .length
                            : 0;
                        final int totalStations = stationsSnapshot.hasData
                            ? stationsSnapshot.data!.docs
                                  .where(
                                    (doc) =>
                                        doc.get('statusVerifikasi') ==
                                        'verified',
                                  )
                                  .length
                            : 0;

                        return Column(
                          children: [
                            // Tab Navigasi Kapsul
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    _buildTabCapsule(
                                      0,
                                      'Semua Users',
                                      isActive: _activeTab == 0,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTabCapsule(
                                      1,
                                      'Pengguna ($totalUsers)',
                                      isActive: _activeTab == 1,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTabCapsule(
                                      2,
                                      'Game Station ($totalStations)',
                                      isActive: _activeTab == 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Konten List Pengguna & Game Station
                            Expanded(
                              child: _buildListContent(
                                usersSnapshot,
                                stationsSnapshot,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabCapsule(int index, String title, {required bool isActive}) {
    // Tab kapsul dipakai untuk berpindah antara semua data, user, dan station.
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.transparent
              : const Color(0xFF131722).withValues(alpha: 0.5),
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFFC084FC)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? const Color(0xFF22D3EE)
                : const Color(0xFF334155).withValues(alpha: 0.3),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildListContent(
    AsyncSnapshot<QuerySnapshot> usersSnapshot,
    AsyncSnapshot<QuerySnapshot> stationsSnapshot,
  ) {
    // Gabungkan hasil query user dan station lalu urutkan sesuai tab aktif.
    if (usersSnapshot.connectionState == ConnectionState.waiting ||
        stationsSnapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
      );
    }

    final List<Map<String, dynamic>> items = [];

    // Filter data Pengguna
    if (_activeTab == 0 || _activeTab == 1) {
      if (usersSnapshot.hasData) {
        for (var doc in usersSnapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String role = data['role'] ?? 'user';
          if (role == 'user') {
            final String name = data['nama'] ?? 'Tanpa Nama';
            final String email = data['email'] ?? '';
            if (name.toLowerCase().contains(_userSearchQuery) ||
                email.toLowerCase().contains(_userSearchQuery)) {
              items.add({'type': 'user', 'id': doc.id, 'data': data});
            }
          }
        }
      }
    }

    // Filter data Game Station Terverifikasi
    if (_activeTab == 0 || _activeTab == 2) {
      if (stationsSnapshot.hasData) {
        for (var doc in stationsSnapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String statusVerifikasi = data['statusVerifikasi'] ?? '';
          if (statusVerifikasi == 'verified') {
            final String name = data['namaStation'] ?? 'Nama Tidak Diketahui';
            final String address = data['alamat'] ?? '';
            if (name.toLowerCase().contains(_userSearchQuery) ||
                address.toLowerCase().contains(_userSearchQuery)) {
              items.add({'type': 'station', 'id': doc.id, 'data': data});
            }
          }
        }
      }
    }

    if (items.isEmpty) {
      if (_userSearchQuery.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Tidak ditemukan',
          subtitle: 'Silakan ubah kata kunci pencarian Anda.',
        );
      } else {
        return _buildEmptyState(
          icon: Icons.people_outline_rounded,
          title: 'Tidak Ada Data',
          subtitle: 'Belum ada data pengguna atau stasiun yang terdaftar.',
        );
      }
    }

    // Urutkan item agar Game Station tampil terlebih dahulu
    items.sort((a, b) => b['type'].toString().compareTo(a['type'].toString()));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item['type'] == 'station') {
          return _buildStationCard(item['id'], item['data']);
        } else {
          return _buildUserCard(item['id'], item['data']);
        }
      },
    );
  }

  // Kartu ringkas untuk game station yang sudah diverifikasi.
  Widget _buildStationCard(String stationId, Map<String, dynamic> data) {
    final String name = data['namaStation'] ?? 'Nama Tidak Diketahui';
    final int rooms = data['jumlahRooms'] ?? 0;
    final String photo =
        (data['foto'] != null && (data['foto'] as List).isNotEmpty)
        ? data['foto'][0]
        : '';
    final bool isAktif =
        (data['isAktif'] ?? (data['statusVerifikasi'] == 'verified'));
    final String phone =
        data['noHpOwner'] ?? data['noHp'] ?? data['telepon'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.05),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomImageLoader(
                photoStr: photo,
                width: 44,
                height: 44,
                radius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isAktif
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isAktif ? 'Aktif' : 'Nonaktif',
                            style: TextStyle(
                              color: isAktif
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$rooms Room',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            phone,
                            style: const TextStyle(
                              color: Color(0xFF22D3EE),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UsersDetailPage(
                          stationId: stationId,
                          ownerId: data['ownerId'] ?? '',
                          data: data,
                          photos: data['foto'] ?? [],
                          documents: data['buktiLegalitas'] ?? [],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF334155).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Lihat Detail',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _deleteStation(stationId, name),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E1620),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4C1D2F)),
                    ),
                    child: const Center(
                      child: Text(
                        'Hapus',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Kartu ringkas untuk data pengguna standar.
  Widget _buildUserCard(String userId, Map<String, dynamic> data) {
    final String name = data['nama'] ?? 'Tanpa Nama';
    final String email = data['email'] ?? '';
    final String status = data['status'] ?? 'active';
    final bool isBanned = status == 'banned';
    final String phone = data['noHp'] ?? '-';
    final String role = (data['role'] ?? 'user').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11172A).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF22D3EE).withValues(alpha: 0.05),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomImageLoader(
                photoStr: data['foto'],
                width: 44,
                height: 44,
                radius: 22,
                fallbackIcon: Icons.person_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isBanned
                                  ? const Color(0xFF2E1620)
                                  : const Color(0xFF162E25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isBanned ? 'BANNED' : 'AKTIF',
                              style: TextStyle(
                                color: isBanned
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF10B981),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            phone,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            role,
                            style: const TextStyle(
                              color: Color(0xFF22D3EE),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UsersDetailPage(
                          ownerId: userId,
                          data: data,
                          photos: const [],
                          documents: const [],
                          isUser: true,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF334155).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Lihat Detail',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _deleteUser(userId, name),
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E1620),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF4C1D2F)),
                    ),
                    child: const Center(
                      child: Text(
                        'Hapus',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    // Menggunakan top alignment dan scrollable view dengan top padding
    // agar layout tetap stabil dan tidak terdorong/jumping saat keyboard muncul.
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(top: 120, left: 40, right: 40, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22D3EE).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF22D3EE), size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
