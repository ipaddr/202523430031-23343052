import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/utils.dart';
import 'users_detail_page.dart';

/// Halaman Kelola Pengguna & Game Station untuk Super Admin
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _userSearchQuery = '';
  int _activeTab = 0; // 0 = Semua Users, 1 = Pengguna, 2 = Game Station


  // Konfirmasi & Hapus Pengguna dari Firestore
  Future<void> _deleteUser(String userId, String name) async {
    final bool confirm = await _showConfirmDeleteDialog('Hapus Pengguna', 'Apakah Anda yakin ingin menghapus pengguna "$name" secara permanen dari sistem?');
    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();
        _showSuccessSnackBar('Pengguna berhasil dihapus secara permanen!');
      } catch (e) {
        _showErrorSnackBar('Gagal menghapus pengguna: $e');
      }
    }
  }

  // Konfirmasi & Hapus Game Station dari Firestore
  Future<void> _deleteStation(String stationId, String name) async {
    final bool confirm = await _showConfirmDeleteDialog('Hapus Game Station', 'Apakah Anda yakin ingin menghapus stasiun game "$name" secara permanen dari sistem?');
    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('stations').doc(stationId).delete();
        _showSuccessSnackBar('Game Station berhasil dihapus secara permanen!');
      } catch (e) {
        _showErrorSnackBar('Gagal menghapus stasiun game: $e');
      }
    }
  }

  // Dialog konfirmasi penghapusan data
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
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          children: [
            // Kolom Pencarian
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _userSearchQuery = val.trim().toLowerCase();
                  });
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari nama atau lokasi station...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                  fillColor: const Color(0xFF1E293B).withOpacity(0.3),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: const Color(0xFF334155).withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: const Color(0xFF334155).withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF22D3EE), width: 1.2),
                  ),
                ),
              ),
            ),

            // Stream Data Utama dari Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, usersSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('stations').snapshots(),
                    builder: (context, stationsSnapshot) {
                      final int totalUsers = usersSnapshot.hasData
                          ? usersSnapshot.data!.docs.where((doc) => doc.get('role') == 'user').length
                          : 0;
                      final int totalStations = stationsSnapshot.hasData
                          ? stationsSnapshot.data!.docs.where((doc) => doc.get('statusVerifikasi') == 'verified').length
                          : 0;

                      return Column(
                        children: [
                          // Tab Navigasi Kapsul
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildTabCapsule(0, 'Semua Users', isActive: _activeTab == 0),
                                  const SizedBox(width: 8),
                                  _buildTabCapsule(1, 'Pengguna ($totalUsers)', isActive: _activeTab == 1),
                                  const SizedBox(width: 8),
                                  _buildTabCapsule(2, 'Game Station ($totalStations)', isActive: _activeTab == 2),
                                ],
                              ),
                            ),
                          ),

                          // Konten List Pengguna & Game Station
                          Expanded(
                            child: _buildListContent(usersSnapshot, stationsSnapshot),
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
    );
  }

  Widget _buildTabCapsule(int index, String title, {required bool isActive}) {
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.transparent : const Color(0xFF131722).withOpacity(0.5),
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFFC084FC)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
          border: isActive ? null : Border.all(color: const Color(0xFF334155).withOpacity(0.3)),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: FontWeight.bold,
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
    if (usersSnapshot.connectionState == ConnectionState.waiting ||
        stationsSnapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF22D3EE)));
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
            if (name.toLowerCase().contains(_userSearchQuery) || email.toLowerCase().contains(_userSearchQuery)) {
              items.add({
                'type': 'user',
                'id': doc.id,
                'data': data,
              });
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
            if (name.toLowerCase().contains(_userSearchQuery) || address.toLowerCase().contains(_userSearchQuery)) {
              items.add({
                'type': 'station',
                'id': doc.id,
                'data': data,
              });
            }
          }
        }
      }
    }

    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Tidak Ada Data',
        subtitle: 'Tidak ada data pengguna atau stasiun yang cocok.',
      );
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

  // Membangun Card untuk Game Station terverifikasi
  Widget _buildStationCard(String stationId, Map<String, dynamic> data) {
    final String name = data['namaStation'] ?? 'Nama Tidak Diketahui';
    final int rooms = data['jumlahRooms'] ?? 0;
    final String photo = (data['foto'] != null && (data['foto'] as List).isNotEmpty) ? data['foto'][0] : '';
    final bool isAktif = (data['isAktif'] ?? (data['statusVerifikasi'] == 'verified'));
    final String phone = data['noHpOwner'] ?? data['noHp'] ?? data['telepon'] ?? '-';

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
              CustomImageLoader(photoStr: photo, width: 44, height: 44, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
                              color: isAktif ? const Color(0xFF10B981) : const Color(0xFF64748B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isAktif ? 'Aktif' : 'Nonaktif',
                            style: TextStyle(
                              color: isAktif ? const Color(0xFF10B981) : const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                          const SizedBox(width: 8),
                          Text('$rooms Room', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                          const SizedBox(width: 8),
                          Text(phone, style: const TextStyle(color: Color(0xFF22D3EE), fontSize: 11, fontWeight: FontWeight.w500)),
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
                      color: const Color(0xFF1E293B).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155).withOpacity(0.4)),
                    ),
                    child: const Center(
                      child: Text('Lihat Detail', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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

  // Membangun Card untuk Pengguna (User)
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
              CustomImageLoader(photoStr: data['foto'], width: 44, height: 44, radius: 22, fallbackIcon: Icons.person_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBanned ? const Color(0xFF2E1620) : const Color(0xFF162E25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isBanned ? 'BANNED' : 'AKTIF',
                              style: TextStyle(
                                color: isBanned ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                          const SizedBox(width: 8),
                          Text(phone, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
                          const SizedBox(width: 8),
                          Text(role, style: const TextStyle(color: Color(0xFF22D3EE), fontSize: 11, fontWeight: FontWeight.w500)),
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
                      color: const Color(0xFF1E293B).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155).withOpacity(0.4)),
                    ),
                    child: const Center(
                      child: Text('Lihat Detail', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF22D3EE).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF22D3EE), size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
