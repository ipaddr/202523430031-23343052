import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  // Setujui Game Station
  Future<void> _approveStation(BuildContext context, String stationId, String ownerId, String name) async {
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      
      batch.update(db.collection('stations').doc(stationId), {
        'statusVerifikasi': 'verified',
      });
      
      batch.update(db.collection('users').doc(ownerId), {
        'status': 'active',
      });
      
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

  // Tolak Game Station
  Future<void> _rejectStation(BuildContext context, String stationId, String name) async {
    try {
      await FirebaseFirestore.instance.collection('stations').doc(stationId).update({
        'statusVerifikasi': 'rejected',
      });
      
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('stations')
              .where('statusVerifikasi', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(
                icon: Icons.fact_check_outlined,
                title: 'Tidak Ada Pengajuan',
                subtitle: 'Semua pengajuan pendaftaran mitra game station saat ini telah diverifikasi.',
              );
            }

            final pendingStations = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: pendingStations.length,
              itemBuilder: (context, index) {
                final doc = pendingStations[index];
                final data = doc.data() as Map<String, dynamic>;
                final String stationId = doc.id;
                final String ownerId = data['ownerId'] ?? '';
                final String stationName = data['namaStation'] ?? 'Nama Tidak Diketahui';
                final String stationType = data['jenis'] ?? '';
                final int roomsCount = data['jumlahRooms'] ?? 0;
                final String address = data['alamat'] ?? '';
                final List<dynamic> photos = data['foto'] ?? [];
                final List<dynamic> documents = data['buktiLegalitas'] ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11172A).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              stationName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$stationType • $roomsCount Room/PC',
                        style: const TextStyle(
                          color: Color(0xFF22D3EE),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFF1E293B), height: 1),
                      const SizedBox(height: 12),
                      
                      _buildDetailRow(Icons.pin_drop_outlined, 'Alamat', address),
                      
                      const SizedBox(height: 14),
                      // Pratinjau Foto
                      if (photos.isNotEmpty) ...[
                        const Text(
                          'Foto Game Station:',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            itemBuilder: (context, pIdx) {
                              final String photoStr = photos[pIdx];
                              Widget imageWidget;
                              if (photoStr.startsWith('data:image')) {
                                final base64Data = photoStr.split(',').last;
                                imageWidget = Image.memory(base64Decode(base64Data), fit: BoxFit.cover);
                              } else {
                                imageWidget = Image.network(photoStr, fit: BoxFit.cover);
                              }

                              return Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF1E293B)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imageWidget,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Tombol Tindakan
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showReviewDetailsDialog(
                                context,
                                stationId: stationId,
                                ownerId: ownerId,
                                data: data,
                                photos: photos,
                                documents: documents,
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF22D3EE)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.zoom_in_rounded, color: Color(0xFF22D3EE), size: 16),
                              label: const Text(
                                'Tinjau Berkas',
                                style: TextStyle(color: Color(0xFF22D3EE), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => _rejectStation(context, stationId, stationName),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                              ),
                              padding: const EdgeInsets.all(12),
                            ),
                            icon: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 18),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _approveStation(context, stationId, ownerId, stationName),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: Color(0xFF10B981)),
                              ),
                              padding: const EdgeInsets.all(12),
                            ),
                            icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
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
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF64748B), size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, height: 1.45),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                TextSpan(text: value, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Dialog Tinjau Berkas Detail Penuh
  void _showReviewDetailsDialog(
    BuildContext context, {
    required String stationId,
    required String ownerId,
    required Map<String, dynamic> data,
    required List<dynamic> photos,
    required List<dynamic> documents,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFF22D3EE), width: 1.2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Detail Pendaftaran',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _HeaderGroup(title: 'DATA TEMPAT & PEMILIK'),
                          _buildDetailValue('Nama Game Station', data['namaStation']),
                          _buildDetailValue('Nama Pemilik', data['namaOwner'] ?? 'Mendaftar via Pihak Ketiga'),
                          _buildDetailValue('Email Pemilik', data['emailOwner'] ?? 'Mendaftar via Pihak Ketiga'),
                          _buildDetailValue('Nomor HP Pemilik', data['noHpOwner'] ?? 'Mendaftar via Pihak Ketiga'),
                          _buildDetailValue('Jenis Game Station', data['jenis']),
                          _buildDetailValue('Jumlah PC/Room', '${data['jumlahRooms']} Unit'),
                          _buildDetailValue('Alamat Detail', data['alamat']),
                          const SizedBox(height: 18),
                          
                          const _HeaderGroup(title: 'FOTO UTAMA GAME STATION'),
                          const SizedBox(height: 8),
                          _buildPhotoCarousel(photos),
                          const SizedBox(height: 18),

                          const _HeaderGroup(title: 'DOKUMEN LEGALITAS / IZIN'),
                          const SizedBox(height: 8),
                          _buildDocumentsList(documents),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _rejectStation(context, stationId, data['namaStation']);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFFEF4444)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Tolak Berkas', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _approveStation(context, stationId, ownerId, data['namaStation']);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFF10B981)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Setujui / Aktifkan', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailValue(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, height: 1.45),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            TextSpan(text: '${value ?? "-"}', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCarousel(List<dynamic> photos) {
    if (photos.isEmpty) {
      return const Text('Tidak ada foto.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11));
    }
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final String photoStr = photos[index];
          Widget imageWidget;
          if (photoStr.startsWith('data:image')) {
            final base64Data = photoStr.split(',').last;
            imageWidget = Image.memory(base64Decode(base64Data), fit: BoxFit.cover);
          } else {
            imageWidget = Image.network(photoStr, fit: BoxFit.cover);
          }

          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.25), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageWidget,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentsList(List<dynamic> documents) {
    if (documents.isEmpty) {
      return const Text('Tidak ada dokumen legalitas.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11));
    }
    return Column(
      children: List.generate(documents.length, (index) {
        final String docStr = documents[index];
        final bool isPdf = docStr.toLowerCase().contains('pdf') || docStr.contains('application/pdf');
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF22D3EE).withValues(alpha: 0.1), width: 1),
          ),
          child: Row(
            children: [
              Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF22D3EE),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Dokumen Legalitas ${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
            ],
          ),
        );
      }),
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
                color: const Color(0xFF22D3EE).withValues(alpha: 0.1),
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

class _HeaderGroup extends StatelessWidget {
  final String title;
  const _HeaderGroup({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF22D3EE),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        const Divider(color: Color(0xFF1E293B), height: 1),
      ],
    );
  }
}
