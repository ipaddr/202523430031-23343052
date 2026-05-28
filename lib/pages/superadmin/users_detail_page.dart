import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../widgets/utils.dart';

/// Halaman Detail Pengguna & Game Station untuk Super Admin
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
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isUser ? _buildUserDetailPageContent() : _buildStationDetailPageContent();
  }

  Widget _buildUserDetailPageContent() {
    final String name = widget.data['nama'] ?? 'Tanpa Nama';
    final String email = widget.data['email'] ?? '-';
    final String phone = widget.data['noHp'] ?? '-';
    final String role = (widget.data['role'] ?? 'user').toString().toUpperCase();
    final String status = widget.data['status'] ?? 'active';
    final bool isBanned = status == 'banned';
    final String photo = widget.data['foto'] ?? '';

    Widget heroImage = Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 64),
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.4),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
                          ),
                          child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Detail Pengguna',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                        heroImage,
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF334155).withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isBanned ? const Color(0xFF2E1620) : const Color(0xFF162E25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isBanned ? 'BANNED' : 'AKTIF',
                                      style: TextStyle(
                                        color: isBanned ? const Color(0xFFEF4444) : const Color(0xFF10B981),
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
                              _buildDetailField('NOMOR HP / TELEPON', phone, isCyan: true),
                              const SizedBox(height: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'HAK AKSES / ROLE',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22D3EE).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      role,
                                      style: const TextStyle(color: Color(0xFF22D3EE), fontSize: 11, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildStationDetailPageContent() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('stations').doc(widget.stationId).snapshots(),
        builder: (context, snapshot) {
          Map<String, dynamic> stationData = widget.data;
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            stationData = snapshot.data!.data() as Map<String, dynamic>;
          }

          final bool isAktif = (stationData['isAktif'] ?? (stationData['statusVerifikasi'] == 'verified'));
          final List<dynamic> photos = stationData['foto'] ?? widget.photos;
          final List<dynamic> documents = stationData['buktiLegalitas'] ?? widget.documents;
          final String stationName = stationData['namaStation'] ?? 'Nama Tidak Diketahui';
          final String address = stationData['alamat'] ?? '-';
          final String phone = stationData['noHpOwner'] ?? stationData['noHp'] ?? stationData['telepon'] ?? '-';
          final String jenis = stationData['jenis'] ?? '-';
          final int jumlahRooms = stationData['jumlahRooms'] ?? 0;

          Widget heroSlider = Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.storefront_rounded, color: Color(0xFF64748B), size: 48),
          );

          if (photos.isNotEmpty) {
            heroSlider = Stack(
              children: [
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
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
                            color: _currentImageIndex == index ? const Color(0xFF22D3EE) : Colors.white24,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 98,
                    child: Icon(Icons.chevron_left_rounded, color: Colors.white.withOpacity(0.7), size: 24),
                  ),
                  Positioned(
                    right: 8,
                    top: 98,
                    child: Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.7), size: 24),
                  ),
                ],
              ],
            );
          }

          String statusText = isAktif ? 'AKTIF' : 'NONAKTIF';
          Color statusTextColor = isAktif ? const Color(0xFF10B981) : const Color(0xFF64748B);
          Color statusBgColor = statusTextColor.withOpacity(0.1);

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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withOpacity(0.4),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF334155).withOpacity(0.5)),
                              ),
                              child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Detail Game Station',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                                color: const Color(0xFF1E293B).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFF334155).withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          stationName,
                                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: statusBgColor,
                                          borderRadius: BorderRadius.circular(8),
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
                                      const Icon(Icons.location_on_rounded, color: Color(0xFF22D3EE), size: 14),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          address.split(',').take(2).join(',').trim(),
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildDetailField('JENIS GAME STATION', jenis),
                                  const SizedBox(height: 16),
                                  _buildDetailField('KAPASITAS', '$jumlahRooms Unit PC / Rooms'),
                                  const SizedBox(height: 16),
                                  _buildDetailField('ALAMAT LENGKAP', address),
                                  const SizedBox(height: 16),
                                  _buildDetailField('NOMOR TELEPON BISNIS', phone, isCyan: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(widget.ownerId).get(),
                              builder: (context, userSnapshot) {
                                String ownerName = stationData['namaOwner'] ?? 'Mitra Game Zone';
                                String ownerEmail = stationData['emailOwner'] ?? 'mitra@gamezone.com';
                                String? ownerPhoto;

                                if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                  ownerName = userData['nama'] ?? ownerName;
                                  ownerEmail = userData['email'] ?? ownerEmail;
                                  ownerPhoto = userData['foto'];
                                }

                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: const Color(0xFF334155).withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.supervised_user_circle_rounded, color: const Color(0xFFC084FC), size: 20),
                                          SizedBox(width: 8),
                                          const Text(
                                            'Data Admin & Dokumen',
                                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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
                                            fallbackIcon: Icons.person_rounded,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ownerName,
                                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  ownerEmail,
                                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
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
                                          children: List.generate(documents.length, (index) {
                                            final docUrl = documents[index] as String;
                                            final bool isPdf = docUrl.toLowerCase().contains('.pdf') || docUrl.contains('/raw/upload/');

                                            return GestureDetector(
                                              onTap: () => openExternalUrl(context, docUrl),
                                              child: isPdf
                                                  ? Container(
                                                      margin: const EdgeInsets.only(bottom: 8),
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF1E293B).withOpacity(0.5),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: const Color(0xFF334155)),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFEF4444), size: 24),
                                                          const SizedBox(width: 12),
                                                          const Expanded(
                                                            child: Text(
                                                              'Dokumen Izin Usaha (PDF)',
                                                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                                            ),
                                                          ),
                                                          Icon(Icons.open_in_new_rounded, color: const Color(0xFF22D3EE).withOpacity(0.8), size: 18),
                                                        ],
                                                      ),
                                                    )
                                                  : Padding(
                                                      padding: const EdgeInsets.only(bottom: 10),
                                                      child: CustomImageLoader(
                                                        photoStr: docUrl,
                                                        width: double.infinity,
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
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.badge_rounded, color: Color(0xFF475569), size: 36),
                                              SizedBox(height: 8),
                                              Text(
                                                'Tidak ada dokumen terlampir.',
                                                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailField(String label, String value, {bool isCyan = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: isCyan ? const Color(0xFF22D3EE) : Colors.white,
            fontSize: isCyan ? 14 : 13,
            fontWeight: isCyan ? FontWeight.bold : const Color(0xFF22D3EE) != Colors.white ? FontWeight.w600 : FontWeight.normal,
            height: isCyan ? 1.0 : 1.45,
          ),
        ),
      ],
    );
  }
}
