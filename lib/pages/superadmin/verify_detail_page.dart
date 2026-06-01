import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/background.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';
import 'package:gamezone/utils/helpers.dart';

/// Halaman Detail Verifikasi Game Station
class VerifyDetailPage extends StatefulWidget {
  final String stationId;
  final String ownerId;
  final Map<String, dynamic> data;
  final List<dynamic> photos;
  final List<dynamic> documents;
  final Future<void> Function(
    BuildContext context,
    String stationId,
    String ownerId,
    String name,
  )
  onApprove;
  final Future<void> Function(
    BuildContext context,
    String stationId,
    String name,
  )
  onReject;

  const VerifyDetailPage({
    super.key,
    required this.stationId,
    required this.ownerId,
    required this.data,
    required this.photos,
    required this.documents,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<VerifyDetailPage> createState() => _VerifyDetailPageState();
}

class _VerifyDetailPageState extends State<VerifyDetailPage> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Detail verifikasi membaca ulang data station dan menampilkan aksi final.
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: GameZoneBackground(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('stations')
              .doc(widget.stationId)
              .snapshots(),
          builder: (context, snapshot) {
            Map<String, dynamic> stationData = widget.data;
            if (snapshot.hasData &&
                snapshot.data != null &&
                snapshot.data!.exists) {
              stationData = snapshot.data!.data() as Map<String, dynamic>;
            }

            final String status = stationData['statusVerifikasi'] ?? 'pending';
            final List<dynamic> photos = stationData['foto'] ?? widget.photos;
            final List<dynamic> documents =
                stationData['buktiLegalitas'] ?? widget.documents;
            final String stationName =
                stationData['namaStation'] ?? 'Nama Tidak Diketahui';
            final String address = stationData['alamat'] ?? '-';
            final String phone =
                stationData['noHpOwner'] ??
                stationData['noHp'] ??
                stationData['telepon'] ??
                '-';
            final String jenis = stationData['jenis'] ?? '-';
            final int jumlahRooms = stationData['jumlahRooms'] ?? 0;

            // Slider utama menampilkan foto station jika tersedia.
            Widget heroSlider = Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFF64748B),
                size: 48,
              ),
            );

            if (photos.isNotEmpty) {
              heroSlider = Stack(
                children: [
                  SizedBox(
                    height: 220,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) =>
                          setState(() => _currentImageIndex = index),
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => openExternalUrl(context, photos[index]),
                          child: CustomImageLoader(
                            photoStr: photos[index],
                            width: double.infinity,
                            height: 220,
                            radius: 24,
                          ),
                        );
                      },
                    ),
                  ),
                  if (photos.length > 1) ...[
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          photos.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentImageIndex == index ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentImageIndex == index
                                  ? const Color(0xFF22D3EE)
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 8,
                      top: 98,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ),
                    const Positioned(
                      right: 8,
                      top: 98,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ),
                  ],
                ],
              );
            }

            // Label status memberi ringkasan cepat tentang hasil verifikasi.
            String statusText = 'MENUNGGU';
            Color statusTextColor = const Color(0xFF22D3EE);
            Color statusBgColor = const Color(
              0xFF22D3EE,
            ).withValues(alpha: 0.1);
            if (status == 'verified') {
              statusText = 'DITERIMA';
              statusTextColor = const Color(0xFF10B981);
              statusBgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
            } else if (status == 'rejected') {
              statusText = 'DITOLAK';
              statusTextColor = const Color(0xFFEF4444);
              statusBgColor = const Color(0xFFEF4444).withValues(alpha: 0.1);
            }

            return Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0B0F19), Color(0xFF0F172A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E293B,
                                  ).withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF334155,
                                    ).withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.chevron_left_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Detail Verifikasi',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 42),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              heroSlider,
                              const SizedBox(height: 20),

                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF1E293B,
                                  ).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF334155,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            stationName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusBgColor,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusTextColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          color: Color(0xFF22D3EE),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            address
                                                .split(',')
                                                .take(2)
                                                .join(',')
                                                .trim(),
                                            style: const TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _buildDetailField(
                                      'JENIS GAME STATION',
                                      jenis,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDetailField(
                                      'KAPASITAS',
                                      '$jumlahRooms Unit PC / Rooms',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDetailField(
                                      'ALAMAT LENGKAP',
                                      address,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDetailField(
                                      'NOMOR TELEPON BISNIS',
                                      phone,
                                      isCyan: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(widget.ownerId)
                                    .get(),
                                builder: (context, userSnapshot) {
                                  String ownerName =
                                      stationData['namaOwner'] ??
                                      'Mitra Game Zone';
                                  String ownerEmail =
                                      stationData['emailOwner'] ??
                                      'mitra@gamezone.com';
                                  String? ownerPhoto;

                                  if (userSnapshot.hasData &&
                                      userSnapshot.data != null &&
                                      userSnapshot.data!.exists) {
                                    final userData =
                                        userSnapshot.data!.data()
                                            as Map<String, dynamic>;
                                    ownerName = userData['nama'] ?? ownerName;
                                    ownerEmail =
                                        userData['email'] ?? ownerEmail;
                                    ownerPhoto = userData['foto'];
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1E293B,
                                      ).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF334155,
                                        ).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons
                                                  .supervised_user_circle_rounded,
                                              color: const Color(0xFFC084FC),
                                              size: 20,
                                            ),
                                            SizedBox(width: 8),
                                            const Text(
                                              'Data Admin & Dokumen',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            CustomImageLoader(
                                              photoStr: ownerPhoto,
                                              width: 48,
                                              height: 48,
                                              radius: 12,
                                              fallbackIcon:
                                                  Icons.person_rounded,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    ownerName,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    ownerEmail,
                                                    style: const TextStyle(
                                                      color: Color(0xFF64748B),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'DOKUMEN IDENTITAS / IZIN USAHA (KETUK UNTUK DETAIL)',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (documents.isNotEmpty)
                                          Column(
                                            children: List.generate(documents.length, (
                                              index,
                                            ) {
                                              final docUrl =
                                                  documents[index] as String;
                                              final bool isPdf =
                                                  docUrl.toLowerCase().contains(
                                                    '.pdf',
                                                  ) ||
                                                  docUrl.contains(
                                                    '/raw/upload/',
                                                  );

                                              return GestureDetector(
                                                onTap: () => openExternalUrl(
                                                  context,
                                                  docUrl,
                                                ),
                                                child: isPdf
                                                    ? Container(
                                                        margin:
                                                            const EdgeInsets.only(
                                                              bottom: 8,
                                                            ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 14,
                                                              vertical: 12,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              const Color(
                                                                0xFF1E293B,
                                                              ).withValues(
                                                                alpha: 0.5,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color: const Color(
                                                              0xFF334155,
                                                            ),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .picture_as_pdf_rounded,
                                                              color: Color(
                                                                0xFFEF4444,
                                                              ),
                                                              size: 24,
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            const Expanded(
                                                              child: Text(
                                                                'Dokumen Izin Usaha (PDF)',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                            Icon(
                                                              Icons
                                                                  .open_in_new_rounded,
                                                              color:
                                                                  const Color(
                                                                    0xFF22D3EE,
                                                                  ).withValues(
                                                                    alpha: 0.8,
                                                                  ),
                                                              size: 18,
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    : Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              bottom: 10,
                                                            ),
                                                        child:
                                                            CustomImageLoader(
                                                              photoStr: docUrl,
                                                              width: double
                                                                  .infinity,
                                                              height: 160,
                                                              radius: 16,
                                                            ),
                                                      ),
                                              );
                                            }),
                                          )
                                        else
                                          Container(
                                            width: double.infinity,
                                            height: 140,
                                            color: const Color(0xFF141B31),
                                            child: const Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.badge_rounded,
                                                  color: Color(0xFF475569),
                                                  size: 36,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Tidak ada dokumen terlampir.',
                                                  style: TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Aksi hanya tampil saat pengajuan masih menunggu keputusan.
                if (status == 'pending')
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF22D3EE), Color(0xFFC084FC)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF22D3EE,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                await widget.onApprove(
                                  context,
                                  widget.stationId,
                                  widget.ownerId,
                                  stationName,
                                );
                                if (context.mounted) Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'TERIMA',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1014),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF4C1D24),
                                width: 1.0,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                await widget.onReject(
                                  context,
                                  widget.stationId,
                                  stationName,
                                );
                                if (context.mounted) Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Tolak',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, String value, {bool isCyan = false}) {
    // Field detail dipakai ulang untuk informasi station dan admin.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: isCyan ? const Color(0xFF22D3EE) : Colors.white,
            fontSize: isCyan ? 14 : 13,
            fontWeight: isCyan
                ? FontWeight.bold
                : const Color(0xFF22D3EE) != Colors.white
                ? FontWeight.w600
                : FontWeight.normal,
            height: isCyan ? 1.0 : 1.45,
          ),
        ),
      ],
    );
  }
}
