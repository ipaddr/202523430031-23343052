import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../widgets/background.dart';
import 'package:gamezone/widgets/common/custom_image_loader.dart';
import 'package:gamezone/utils/helpers.dart';

/// Halaman Detail Pengguna & Game Station untuk Super Admin.
/// Jika [isUser] = false (station), halaman ini juga menangani aksi
/// verifikasi (Terima / Tolak) ketika status station masih 'pending'.
class UsersDetailPage extends StatefulWidget {
  final String? stationId;
  final String ownerId;
  final Map<String, dynamic> data;
  final List<dynamic> photos;
  final List<dynamic> documents;
  final bool isUser;

  const UsersDetailPage({
    super.key,
    this.stationId,
    required this.ownerId,
    required this.data,
    required this.photos,
    required this.documents,
    this.isUser = false,
  });

  @override
  State<UsersDetailPage> createState() => _UsersDetailPageState();
}

class _UsersDetailPageState extends State<UsersDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Verifikasi Station

  /// Setujui game station: ubah statusVerifikasi → 'verified' di Firestore.
  Future<void> _approveStation(
    BuildContext context,
    String stationId,
    String ownerId,
    String stationName,
  ) async {
    try {
      await _firestoreService.verifyStation(stationId, ownerId, 'verified');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Stasiun "$stationName" berhasil disetujui!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Gagal menyetujui stasiun game. Coba lagi.'),
        ),
      );
    }
  }

  /// Tolak game station: ubah statusVerifikasi → 'rejected' di Firestore.
  Future<void> _rejectStation(
    BuildContext context,
    String stationId,
    String stationName,
  ) async {
    try {
      await _firestoreService.rejectStation(stationId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Row(
            children: [
              const Icon(Icons.cancel_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pendaftaran "$stationName" telah ditolak.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
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
    // Detail page memilih tampilan user atau station berdasarkan flag input.
    return widget.isUser
        ? _buildUserDetailPageContent()
        : _buildStationDetailPageContent();
  }

  Widget _buildUserDetailPageContent() {
    // Baca data user secara real-time dari Firestore agar selalu sinkron.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameZoneBackground(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.ownerId)
              .snapshots(),
          builder: (context, snapshot) {
            // Gunakan widget.data sebagai fallback hingga snapshot pertama tiba.
            Map<String, dynamic> userData = widget.data;
            if (snapshot.hasData &&
                snapshot.data != null &&
                snapshot.data!.exists) {
              userData = snapshot.data!.data() as Map<String, dynamic>;
            }

            final String name = userData['nama'] ?? 'Tanpa Nama';
            final String email = userData['email'] ?? '-';
            final String phone = userData['noHp'] ?? '-';
            final String role = (userData['role'] ?? 'user')
                .toString()
                .toUpperCase();
            final String status = userData['status'] ?? 'active';
            final bool isBanned = status == 'banned';
            final String photo = userData['foto'] ?? '';

            Widget heroImage = Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Color(0xFF64748B),
                size: 64,
              ),
            );

            if (photo.isNotEmpty) {
              heroImage = GestureDetector(
                onTap: () => openExternalUrl(context, photo),
                child: CustomImageLoader(
                  photoStr: photo,
                  width: double.infinity,
                  height: 220,
                  radius: 24,
                ),
              );
            }

            return Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
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
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Detail Pengguna',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              heroImage,
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
                                            name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isBanned
                                                ? const Color(0xFF2E1620)
                                                : const Color(0xFF162E25),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            isBanned ? 'BANNED' : 'AKTIF',
                                            style: TextStyle(
                                              color: isBanned
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF10B981),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _buildDetailField('EMAIL PENGGUNA', email),
                                    const SizedBox(height: 16),
                                    _buildDetailField(
                                      'NOMOR HP / TELEPON',
                                      phone,
                                      isCyan: true,
                                    ),
                                    const SizedBox(height: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'HAK AKSES / ROLE',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF22D3EE,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            role,
                                            style: const TextStyle(
                                              color: Color(0xFF22D3EE),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 100),
                            ],
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

  Widget _buildStationDetailPageContent() {
    // Bagian ini menampilkan detail game station beserta dokumennya.
    return Scaffold(
      backgroundColor: Colors.transparent,
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

            final bool isAktif =
                (stationData['isAktif'] ??
                (stationData['statusVerifikasi'] == 'verified'));
            final String verifyStatus =
                stationData['statusVerifikasi'] ?? 'pending';
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
            // jumlahRooms dihapus — field ini tidak ada di Firestore.
            // Jumlah unit dihitung langsung dari collection units di bawah.

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
                    Positioned(
                      left: 8,
                      top: 98,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 98,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 24,
                      ),
                    ),
                  ],
                ],
              );
            }

            String statusText = isAktif ? 'AKTIF' : 'NONAKTIF';
            Color statusTextColor = isAktif
                ? const Color(0xFF10B981)
                : const Color(0xFF64748B);
            // Tampilkan label verifikasi yang lebih informatif.
            if (verifyStatus == 'pending') {
              statusText = 'MENUNGGU';
              statusTextColor = const Color(0xFF22D3EE);
            } else if (verifyStatus == 'rejected') {
              statusText = 'DITOLAK';
              statusTextColor = const Color(0xFFEF4444);
            }
            final Color statusBgColor = statusTextColor.withValues(alpha: 0.1);

            return Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
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
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Detail Game Station',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                                    // Hitung jumlah unit langsung dari collection units
                                    // menggunakan stationId yang benar.
                                    FutureBuilder<QuerySnapshot?>(
                                      future:
                                          widget.stationId != null &&
                                              widget.stationId!.isNotEmpty
                                          ? _firestoreService
                                                .getUnitsOnceByStation(
                                                  widget.stationId!,
                                                )
                                          : Future.value(),
                                      builder: (context, unitSnap) {
                                        final String kapasitasText;
                                        if (unitSnap.connectionState ==
                                            ConnectionState.waiting) {
                                          kapasitasText = 'Memuat...';
                                        } else if (unitSnap.hasData &&
                                            unitSnap.data != null) {
                                          final int count =
                                              unitSnap.data!.docs.length;
                                          kapasitasText =
                                              '$count Unit PC / Rooms';
                                        } else {
                                          kapasitasText = '0 Unit PC / Rooms';
                                        }
                                        return _buildDetailField(
                                          'KAPASITAS',
                                          kapasitasText,
                                        );
                                      },
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
                                            CustomUserAvatar(
                                              photoUrl: ownerPhoto,
                                              size: 48,
                                              hasBorder: false,
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

                                              return isPdf
                                                  ? GestureDetector(
                                                      onTap: () =>
                                                          openExternalUrl(
                                                            context,
                                                            docUrl,
                                                          ),
                                                      child: Container(
                                                        margin:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 6,
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
                                                                alpha: 0.55,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                const Color(
                                                                  0xFF334155,
                                                                ).withValues(
                                                                  alpha: 0.5,
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
                                                      ),
                                                    )
                                                  : Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 10,
                                                          ),
                                                      child: CustomImageLoader(
                                                        photoStr: docUrl,
                                                        width: double.infinity,
                                                        height: 160,
                                                        radius: 16,
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

                // Tombol Terima / Tolak hanya tampil saat status masih pending.
                if (verifyStatus == 'pending')
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
                                final sid = widget.stationId ?? '';
                                if (sid.isEmpty) return;
                                await _approveStation(
                                  context,
                                  sid,
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
                                final sid = widget.stationId ?? '';
                                if (sid.isEmpty) return;
                                await _rejectStation(context, sid, stationName);
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
    // Field detail dipakai ulang untuk label dan nilai informasi.
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

