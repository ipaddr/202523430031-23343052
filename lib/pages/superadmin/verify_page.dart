import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../styles/app_colors.dart';
import '../../styles/app_textstyle.dart';
import '../../styles/app_theme.dart';
import 'verify_detail_page.dart';

// Halaman daftar verifikasi untuk meninjau pengajuan game station.
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Tab Status: 0 = Semua, 1 = Menunggu, 2 = Selesai
  int _selectedTab = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Setujui game station dan update status terkait di Firestore.
  Future<void> _approveStation(
    BuildContext context,
    String stationId,
    String ownerId,
    String name,
  ) async {
    try {
      await _firestoreService.verifyStation(stationId, ownerId, 'verified');

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Stasiun "$name" berhasil disetujui!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Gagal menyetujui stasiun game. Coba lagi.'),
        ),
      );
    }
  }

  // Tolak game station dan simpan status akhir ke Firestore.
  Future<void> _rejectStation(
    BuildContext context,
    String stationId,
    String name,
  ) async {
    try {
      await _firestoreService.rejectStation(stationId);

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Row(
            children: [
              const Icon(Icons.cancel_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pendaftaran "$name" telah ditolak.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Gagal menolak stasiun game.'),
        ),
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
              _buildSearchBar(context),
              _buildTabBar(),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
            });
          },
          decoration: InputDecoration(
            hintText: 'Cari nama station, pemilik, email, nomor HP...',
            hintStyle: AppTextStyle.body3.copyWith(color: AppColors.softGray),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.softGray,
              size: 20,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.softGray,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildTabCapsule(0, 'Semua')),
          const SizedBox(width: 8),
          Expanded(child: _buildTabCapsule(1, 'Menunggu')),
          const SizedBox(width: 8),
          Expanded(child: _buildTabCapsule(2, 'Selesai')),
        ],
      ),
    );
  }

  Widget _buildTabCapsule(int index, String title) {
    final bool isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        height: 38,
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

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getStationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
          );
        }

        if (snapshot.hasError) {
          return _buildEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Terjadi Kesalahan',
            subtitle: 'Gagal memuat data pengajuan game station dari server.',
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.fact_check_outlined,
            title: 'Tidak Ada Pengajuan',
            subtitle:
                'Semua pengajuan pendaftaran mitra game station saat ini telah diverifikasi.',
          );
        }

        // Filter data secara dinamis
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Search matches
          final String name = (data['namaStation'] ?? '')
              .toString()
              .toLowerCase();
          final String ownerName = (data['namaOwner'] ?? '')
              .toString()
              .toLowerCase();
          final String email = (data['emailOwner'] ?? '')
              .toString()
              .toLowerCase();
          final String phone = (data['noHpOwner'] ?? data['noHp'] ?? '')
              .toString()
              .toLowerCase();

          final matchesSearch =
              name.contains(_searchQuery) ||
              ownerName.contains(_searchQuery) ||
              email.contains(_searchQuery) ||
              phone.contains(_searchQuery);

          // Status matches based on selected tab
          final String status = data['statusVerifikasi'] ?? 'pending';
          bool matchesStatus = true;
          if (_selectedTab == 1) {
            matchesStatus = status == 'pending';
          } else if (_selectedTab == 2) {
            matchesStatus = status == 'verified' || status == 'rejected';
          }

          return matchesSearch && matchesStatus;
        }).toList();

        // Urutkan data secara dinamis (Terbaru sebagai default)
        filteredDocs.sort((a, b) {
          final Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
          final Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
          final Timestamp? timeA = dataA['createdAt'] as Timestamp?;
          final Timestamp? timeB = dataB['createdAt'] as Timestamp?;
          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          return timeB.compareTo(timeA);
        });

        if (filteredDocs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.search_off_rounded,
            title: 'Tidak ditemukan',
            subtitle: 'Silakan ubah kata kunci pencarian Anda.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String stationId = doc.id;
            final String ownerId = data['ownerId'] ?? '';
            return _buildStationCard(data, stationId, ownerId);
          },
        );
      },
    );
  }

  Widget _buildStationCard(
    Map<String, dynamic> data,
    String stationId,
    String ownerId,
  ) {
    // Kartu pengajuan menampilkan ringkasan lalu memberi aksi verifikasi.
    final String stationName = data['namaStation'] ?? 'Nama Tidak Diketahui';
    final String ownerName = data['namaOwner'] ?? 'Owner';
    final List<dynamic> photos = data['foto'] ?? [];
    final String status = data['statusVerifikasi'] ?? 'pending';

    String statusText = 'MENUNGGU';
    Color statusColor = const Color(0xFF22D3EE);
    if (status == 'verified') {
      statusText = 'DITERIMA';
      statusColor = const Color(0xFF10B981);
    } else if (status == 'rejected') {
      statusText = 'DITOLAK';
      statusColor = const Color(0xFFEF4444);
    }

    Widget imageWidget = const Icon(
      Icons.storefront_rounded,
      color: Color(0xFF64748B),
      size: 28,
    );
    if (photos.isNotEmpty) {
      final String photoStr = photos[0];
      if (photoStr.startsWith('data:image')) {
        final base64Data = photoStr.split(',').last;
        imageWidget = Image.memory(base64Decode(base64Data), fit: BoxFit.cover);
      } else {
        imageWidget = Image.network(photoStr, fit: BoxFit.cover);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B), width: 1),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF141B31),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageWidget,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stationName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Admin: $ownerName',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF141B31),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (status == 'pending') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approveStation(
                      context,
                      stationId,
                      ownerId,
                      stationName,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF9D),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Terima',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _rejectStation(context, stationId, stationName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D1622),
                      foregroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF4C1D2F)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Tolak',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VerifyDetailPage(
                    stationId: stationId,
                    ownerId: ownerId,
                    data: data,
                    photos: photos,
                    documents: data['buktiLegalitas'] ?? [],
                    onApprove: _approveStation,
                    onReject: _rejectStation,
                  ),
                ),
              );
            },
            child: Container(
              width: double.infinity,
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
        padding: const EdgeInsets.only(
          top: 120,
          left: 40,
          right: 40,
          bottom: 24,
        ),
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
