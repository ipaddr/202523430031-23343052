import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gamezone/services/auth_service.dart';
import 'package:gamezone/services/firestore_service.dart';
import 'package:gamezone/styles/app_colors.dart';
import 'package:gamezone/styles/app_textstyle.dart';
import 'package:gamezone/styles/app_theme.dart';
import 'package:gamezone/widgets/common/status_badge.dart';
import 'package:gamezone/widgets/common/action_button.dart';
import 'package:gamezone/widgets/common/custom_empty_state.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String _selectedTab = 'Semua';
  final List<String> _tabs = ['Semua', 'Mendatang', 'Selesai'];

  @override
  void initState() {
    super.initState();
    // Expire booking yang sudah lewat batas pembayaran saat halaman dibuka.
    // Ini memastikan status di Firestore selalu sinkron tanpa Cloud Functions.
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      _firestoreService.expireOverdueBookings(currentUser.uid);
      _firestoreService.completeFinishedBookings(userId: currentUser.uid);
    }
  }

  String _formatDate(String dbDateStr) {
    try {
      final parts = dbDateStr.split('-');
      if (parts.length < 3) return dbDateStr;
      final int year = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int day = int.parse(parts[2]);

      final List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agt',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '$day ${months[month - 1]} $year';
    } catch (_) {
      return dbDateStr;
    }
  }

  String _formatCurrency(int value) {
    if (value <= 0) return 'Rp 0';
    return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Color _getStatusColor(String status) => bookingStatusColor(status);
  String _getStatusLabel(String status) => bookingStatusLabel(status);

  void _showRatingDialog(
    String bookingId,
    String unitName,
    String stationId,
    String stationName,
  ) {
    int selectedStars = 5;
    final TextEditingController commentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF1E293B)),
              ),
              title: const Text(
                'Beri Rating & Review',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bagaimana pengalaman Anda bermain di $unitName?',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starVal = index + 1;
                          return IconButton(
                            icon: Icon(
                              Icons.star_rounded,
                              color: starVal <= selectedStars
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF475569),
                              size: 36,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                selectedStars = starVal;
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: commentController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Komentar Anda...',
                          hintStyle: const TextStyle(color: Color(0xFF475569)),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 5) {
                            return 'Komentar minimal 5 karakter';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final currentUser = _authService.getCurrentUser();
                      if (currentUser == null) return;

                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);

                      try {
                        final String reviewId =
                            FirebaseFirestore.instance.collection('reviews').doc().id;

                        // Ambil nama user terbaru dari Firestore
                        final userSnap = await _firestoreService
                            .getUserStream(currentUser.uid)
                            .first;
                        final userData = userSnap.data() as Map<String, dynamic>? ?? {};

                        final String userName =
                            userData['nama'] ?? 'Gamers';
                        final String userPhoto =
                            userData['foto'] ?? '';

                        final reviewPayload = {
                          'reviewId': reviewId,
                          'bookingId': bookingId,
                          'stationId': stationId,
                          'stationName': stationName,
                          'userId': currentUser.uid,
                          'userName': userName,
                          'userPhoto': userPhoto,
                          'rating': selectedStars,
                          'comment': commentController.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                        };

                        debugPrint(
                          'Auth UID: ${FirebaseAuth.instance.currentUser?.uid}'
                        );
                        debugPrint(
                          'Review User ID: ${reviewPayload['userId']}'
                        );

                        // Jalankan transaction untuk memastikan konsistensi
                        await FirebaseFirestore.instance.runTransaction((transaction) async {
                          final DocumentReference bookingRef =
                              FirebaseFirestore.instance.collection('bookings').doc(bookingId);
                          final DocumentReference reviewRef =
                              FirebaseFirestore.instance.collection('reviews').doc(reviewId);
                          final DocumentReference stationRef =
                              FirebaseFirestore.instance.collection('stations').doc(stationId);

                          // 1. Simpan Review
                          transaction.set(reviewRef, reviewPayload);

                          // 2. Tandai Booking sudah direview
                          transaction.update(bookingRef, {'hasReviewed': true});

                          // 3. Hitung Rating rata-rata & totalReview Station
                          // Ambil semua review yang sudah ada untuk station ini
                          final reviewsQuery = await FirebaseFirestore.instance
                              .collection('reviews')
                              .where('stationId', isEqualTo: stationId)
                              .get();

                          double totalRating = selectedStars.toDouble();
                          int totalCount = 1;

                          for (final doc in reviewsQuery.docs) {
                            if (doc.id == reviewId) continue;
                            final data = doc.data();
                            final num? r = data['rating'] as num?;
                            if (r != null) {
                              totalRating += r.toDouble();
                              totalCount++;
                            }
                          }

                          final double averageRating = totalRating / totalCount;

                          // 4. Update data Station secara atomik
                          transaction.update(stationRef, {
                            'rating': averageRating,
                            'totalReview': totalCount,
                          });
                        });

                        // Kirim notifikasi untuk Admin mengenai review baru
                        try {
                          final adminNotifId = FirebaseFirestore.instance.collection('notifications').doc().id;
                          await FirebaseFirestore.instance.collection('notifications').doc(adminNotifId).set({
                            'userId': reviewPayload['userId'] ?? '',
                            'targetId': reviewPayload['userId'] ?? '',
                            'roleTarget': 'admin',
                            'stationId': stationId,
                            'title': 'Review & Rating Baru',
                            'message': 'User memberikan rating dan review baru.',
                            'type': 'review_received',
                            'isRead': false,
                            'relatedBookingId': bookingId,
                            'bookingId': bookingId,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        } catch (e) {
                          debugPrint('Error sending admin notification for review: $e');
                        }

                        // Kirim low_rating_alert ke Superadmin jika rating rata-rata stasiun turun di bawah 3.0
                        try {
                          // Ambil data stasiun terbaru untuk memastikan rating saat ini
                          final stationSnap = await FirebaseFirestore.instance.collection('stations').doc(stationId).get();
                          final double currentRating = (stationSnap.data()?['rating'] as num?)?.toDouble() ?? 0.0;
                          if (currentRating > 0.0 && currentRating < 3.0) {
                            final superadminNotifId = FirebaseFirestore.instance.collection('notifications').doc().id;
                            await FirebaseFirestore.instance.collection('notifications').doc(superadminNotifId).set({
                              'userId': 'superadmin',
                              'targetId': 'superadmin',
                              'roleTarget': 'superadmin',
                              'stationId': stationId,
                              'bookingId': bookingId,
                              'relatedBookingId': bookingId,
                              'type': 'low_rating_alert',
                              'title': 'Laporan Review Buruk',
                              'message': 'Rating station turun di bawah batas tertentu.',
                              'isRead': false,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          }
                        } catch (e) {
                          debugPrint('Error sending low_rating_alert to superadmin: $e');
                        }

                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Terima kasih atas ulasan Anda!'),
                              backgroundColor: AppColors.successGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Gagal mengirim review: $e'),
                              backgroundColor: AppColors.errorRed,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text(
                    'Kirim',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();
    if (currentUser == null) {
      return const Center(
        child: Text(
          'Tidak ada pengguna masuk.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: _buildTabFilter(),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('userId', isEqualTo: currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accentCyan),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Gagal memuat riwayat booking.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                  ),
                );
              }

              final allDocs = snapshot.data?.docs ?? [];

              // Pemetaan data mentah ke List map
              final List<Map<String, dynamic>> bookings = allDocs.map((doc) {
                final Map<String, dynamic> data =
                    doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();

              // Urutkan berdasarkan updatedAt / createdAt DESC secara manual
              bookings.sort((a, b) {
                final Timestamp? aTime =
                    (a['updatedAt'] ?? a['createdAt']) as Timestamp?;
                final Timestamp? bTime =
                    (b['updatedAt'] ?? b['createdAt']) as Timestamp?;
                final int aMillis = aTime?.millisecondsSinceEpoch ?? 0;
                final int bMillis = bTime?.millisecondsSinceEpoch ?? 0;
                return bMillis.compareTo(aMillis);
              });

              // Filter berdasarkan Tab
              final filteredBookings = bookings.where((booking) {
                final String status = (booking['statusBooking'] ?? '')
                    .toString()
                    .toLowerCase();
                final String statusBayar = (booking['statusPembayaran'] ?? '')
                    .toString()
                    .toLowerCase();

                if (_selectedTab == 'Mendatang') {
                  // Tampilkan hanya booking aktif — expired/cancelled tidak masuk
                  return (status == 'pending' ||
                          status == 'confirmed' ||
                          status == 'active') &&
                      statusBayar != 'expired';
                } else if (_selectedTab == 'Selesai') {
                  return status == 'completed' ||
                      status == 'cancelled' ||
                      status == 'rejected';
                }
                return true; // Tab Semua: tampilkan semua
              }).toList();

              if (filteredBookings.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: filteredBookings.length,
                itemBuilder: (context, index) {
                  return _buildHistoryCard(filteredBookings[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabFilter() {
    return Row(
      children: _tabs.map((tabLabel) {
        final bool selected = _selectedTab == tabLabel;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = tabLabel;
                });
              },
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.transparent
                      : const Color(0xFF131722).withValues(alpha: 0.5),
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF22D3EE), Color(0xFFC084FC)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF22D3EE)
                        : const Color(0xFF334155).withValues(alpha: 0.3),
                    width: selected ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  tabLabel,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyle.body3.copyWith(color: AppColors.softGray),
        ),
        Text(
          value,
          style: AppTextStyle.body3.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> booking) {
    final String bookingId = booking['id'] ?? '';
    final String unitName = booking['namaUnit'] ?? 'Room';
    final String unitId = booking['unitId']?.toString() ?? '';
    final String stationId = booking['stationId']?.toString() ?? '';
    final String namaStation =
        booking['namaStation']?.toString() ?? 'Game Station';
    final String dateStr = booking['tanggalBooking'] ?? '';
    final String formattedDate = _formatDate(dateStr);

    final String jamMulai = booking['jamMulai'] ?? '00:00';
    final String jamSelesai = booking['jamSelesai'] ?? '00:00';
    final int durasiJam = (booking['durasiJam'] as num?)?.toInt() ?? 1;
    final int price = (booking['totalHarga'] as num?)?.toInt() ?? 0;

    final String status = (booking['statusBooking'] ?? 'pending').toString();
    final String statusLabel = _getStatusLabel(status);
    final Color statusColor = _getStatusColor(status);

    final String statusPembayaran = (booking['statusPembayaran'] ?? 'unpaid')
        .toString()
        .toLowerCase();
    final bool isUnpaid = statusPembayaran == 'unpaid';
    final bool isExpiredPayment = statusPembayaran == 'expired';

    final bool isCompleted = status.toLowerCase() == 'completed';
    final bool isCancelled = status.toLowerCase() == 'cancelled';
    final bool isRejected = status.toLowerCase() == 'rejected';

    // Tombol bayar hanya untuk booking yang belum dibayar, belum expired,
    // dan belum dibatalkan/ditolak/selesai
    final bool canPay =
        isUnpaid &&
        !isExpiredPayment &&
        !isCancelled &&
        !isRejected &&
        !isCompleted;

    final String subtitle = namaStation;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/admin-booking-detail',
          arguments: {
            'bookingId': bookingId,
            'statusBooking': status,
            'viewMode': 'user',
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingL,
          vertical: AppTheme.paddingM,
        ),
        decoration: BoxDecoration(
          color: AppColors.secondaryDark.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(
            color: canPay
                ? AppColors.warningOrange.withValues(alpha: 0.35)
                : AppColors.accentCyan.withValues(alpha: 0.08),
            width: 1.1,
          ),
          boxShadow: AppTheme.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unitName,
                        style: AppTextStyle.body1.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyle.caption1.copyWith(
                          color: AppColors.softGray,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.softGray,
                  size: 18,
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 10),

            _buildInfoRow('Tanggal', formattedDate),
            const SizedBox(height: 6),
            _buildInfoRow('Jam Main', '$jamMulai – $jamSelesai'),
            const SizedBox(height: 6),
            _buildInfoRow('Total', _formatCurrency(price)),

            const SizedBox(height: 10),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status Booking',
                  style: AppTextStyle.caption1.copyWith(
                    color: AppColors.softGray,
                  ),
                ),
                StatusBadge(label: statusLabel, color: statusColor),
              ],
            ),
            if (isUnpaid && !isCancelled && !isRejected) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status Pembayaran',
                    style: AppTextStyle.caption1.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                  StatusBadge(
                    label: 'BELUM DIBAYAR',
                    color: AppColors.warningOrange,
                  ),
                ],
              ),
            ],
            if (isExpiredPayment) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status Pembayaran',
                    style: AppTextStyle.caption1.copyWith(
                      color: AppColors.softGray,
                    ),
                  ),
                  StatusBadge(label: 'KADALUARSA', color: AppColors.errorRed),
                ],
              ),
            ],

            if (canPay || isCompleted || isCancelled) ...[
              const SizedBox(height: 10),
              const Divider(color: Color(0xFF334155), height: 1),
              const SizedBox(height: 10),

              if (canPay)
                PrimaryButton(
                  label: 'Bayar Sekarang',
                  height: 42,
                  onTap: () {
                    // Sertakan createdAt dari data booking agar PaymentPage
                    // bisa hitung sisa timer dari waktu booking dibuat,
                    // bukan dari nol setiap kali halaman dibuka.
                    final dynamic rawCreatedAt = booking['createdAt'];
                    int? createdAtMillis;
                    if (rawCreatedAt is Timestamp) {
                      createdAtMillis = rawCreatedAt
                          .toDate()
                          .millisecondsSinceEpoch;
                    }

                    Navigator.pushNamed(
                      context,
                      '/payment',
                      arguments: {
                        'bookingId': bookingId,
                        'stationId': stationId,
                        'unitId': unitId,
                        'namaStation': namaStation,
                        'namaUnit': unitName,
                        'tanggalBooking': dateStr,
                        'jamMulai': jamMulai,
                        'jamSelesai': jamSelesai,
                        'durasiJam': durasiJam,
                        'createdAtMillis': ?createdAtMillis,
                      },
                    );
                  },
                )
              else if (isCompleted)
                if (booking['hasReviewed'] == true)
                  SecondaryButton(
                    label: 'Review Terkirim',
                    height: 38,
                    onTap: null, // Disabled
                  )
                else
                  SecondaryButton(
                    label: 'Beri Rating & Review',
                    height: 38,
                    onTap: () => _showRatingDialog(
                      bookingId,
                      unitName,
                      stationId,
                      namaStation,
                    ),
                  )
              else if (isCancelled)
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Dibatalkan',
                        style: AppTextStyle.caption2.copyWith(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Tampilkan alasan pembatalan jika tersedia
                      if ((booking['cancelReason']?.toString() ?? '')
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            booking['cancelReason'].toString(),
                            style: AppTextStyle.caption2.copyWith(
                              color: AppColors.lightText,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const CustomEmptyState(
      icon: Icons.history_rounded,
      title: 'Belum Ada Riwayat Booking',
      subtitle: 'Riwayat booking Anda akan muncul di sini.',
    );
  }
}

