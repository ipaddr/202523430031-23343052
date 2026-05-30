import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'verify_detail_page.dart';

// Halaman daftar verifikasi untuk meninjau pengajuan game station.
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  int _selectedTab = 0;

  // Setujui game station dan update status terkait di Firestore.
  Future<void> _approveStation(
    BuildContext context,
    String stationId,
    String ownerId,
    String name,
  ) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      batch.update(db.collection('stations').doc(stationId), {
        'statusVerifikasi': 'verified',
      });

      batch.update(db.collection('users').doc(ownerId), {'status': 'active'});

      await batch.commit();

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
      await FirebaseFirestore.instance
          .collection('stations')
          .doc(stationId)
          .update({'statusVerifikasi': 'rejected'});

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
    // Layout utama terdiri dari tab status dan daftar pengajuan.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          children: [
            _buildTabBar(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    // Tab bar memisahkan pengajuan menunggu dan riwayat selesai.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stations')
                .where('statusVerifikasi', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return _buildTabButton(
                title: count > 0 ? 'Menunggu ($count)' : 'Menunggu',
                index: 0,
              );
            },
          ),
          const SizedBox(width: 12),
          _buildTabButton(title: 'Selesai', index: 1),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String title, required int index}) {
    // Tombol tab kecil untuk mengganti daftar yang sedang ditampilkan.
    final bool isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.transparent : const Color(0xFF141B31),
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFFC084FC)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: BorderRadius.circular(24),
          border: isActive ? null : Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    // Query berubah sesuai tab aktif agar daftar tetap fokus.
    Query query = FirebaseFirestore.instance.collection('stations');
    if (_selectedTab == 0) {
      query = query.where('statusVerifikasi', isEqualTo: 'pending');
    } else {
      query = query.where(
        'statusVerifikasi',
        whereIn: ['verified', 'rejected'],
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.fact_check_outlined,
            title: _selectedTab == 0
                ? 'Tidak Ada Pengajuan'
                : 'Belum Ada Riwayat',
            subtitle: _selectedTab == 0
                ? 'Semua pengajuan pendaftaran mitra game station saat ini telah diverifikasi.'
                : 'Belum ada pendaftaran yang selesai diverifikasi.',
          );
        }

        final stations = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final doc = stations[index];
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

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
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
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E293B)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Lihat Detail',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
    // Empty state muncul saat tidak ada data untuk tab aktif.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
