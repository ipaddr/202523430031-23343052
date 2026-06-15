import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  /// Memproses pembayaran secara simulasi (MVP).
  ///
  /// Setelah [statusPembayaran] berubah menjadi 'paid', method ini secara
  /// otomatis membatalkan booking lain yang slot waktunya bertabrakan
  /// pada unit yang sama di tanggal yang sama.
  ///
  /// Alur:
  ///   1. Update statusPembayaran → 'paid'
  ///   2. Baca data booking untuk mendapat unitId, tanggalBooking, jamMulai, jamSelesai
  ///   3. Jalankan cancelConflictingBookingsAfterPayment()
  Future<void> simulatePayment(
    String bookingId, {
    String metodePembayaran = 'QRIS',
  }) async {
    String stationId = '';
    int totalHarga = 0;
    String unitId = '';
    String tanggalBooking = '';
    String jamMulai = '';
    String jamSelesai = '';
    String userId = '';

    try {
      final DocumentSnapshot doc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        stationId = data['stationId']?.toString() ?? '';
        totalHarga = (data['totalHarga'] is num)
            ? (data['totalHarga'] as num).toInt()
            : int.tryParse(data['totalHarga']?.toString() ?? '0') ?? 0;
        unitId = data['unitId']?.toString() ?? '';
        tanggalBooking = data['tanggalBooking']?.toString() ?? '';
        jamMulai = data['jamMulai']?.toString() ?? '';
        jamSelesai = data['jamSelesai']?.toString() ?? '';
        userId = data['userId']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('[Payment] Gagal mengambil data booking awal: $e');
    }

    // Langkah 1: Update status pembayaran booking & totalPemasukan stasiun secara atomik
    try {
      await _firestore.runTransaction((transaction) async {
        final DocumentReference bookingRef = _firestore
            .collection('bookings')
            .doc(bookingId);

        transaction.update(bookingRef, {
          'statusPembayaran': 'paid',
          'statusBooking': 'pending_confirmation',
          'metodePembayaran': metodePembayaran,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (stationId.isNotEmpty) {
          final DocumentReference stationRef = _firestore
               .collection('stations')
               .doc(stationId);
          transaction.update(stationRef, {
            'totalPemasukan': FieldValue.increment(totalHarga),
          });
        }

        if (userId.isNotEmpty) {
          final DocumentReference userNotifRef = _firestore
              .collection('notifications')
              .doc();
          transaction.set(userNotifRef, {
            'userId': userId,
            'targetId': userId,
            'roleTarget': 'user',
            'stationId': stationId,
            'bookingId': bookingId,
            'relatedBookingId': bookingId,
            'type': 'payment_success',
            'title': 'Pembayaran Berhasil',
            'message':
                'Pembayaran berhasil. Booking sedang menunggu konfirmasi Game Station.',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          final DocumentReference adminNotifRef = _firestore
              .collection('notifications')
              .doc();
          transaction.set(adminNotifRef, {
            'userId': userId,
            'targetId': userId,
            'roleTarget': 'admin',
            'stationId': stationId,
            'bookingId': bookingId,
            'relatedBookingId': bookingId,
            'type': 'payment_received',
            'title': 'Pembayaran Berhasil',
            'message':
                'User telah melakukan pembayaran dan menunggu konfirmasi.',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (kDebugMode) {
        debugPrint(
          '[Payment] Booking $bookingId berhasil dibayar via $metodePembayaran',
        );
      }
    } catch (e) {
      throw Exception('Gagal memproses pembayaran: $e');
    }

    // Langkah 2: Batalkan booking lain yang slot-nya konflik
    try {
      if (unitId.isEmpty || tanggalBooking.isEmpty) return;

      await _firestoreService.cancelConflictingBookingsAfterPayment(
        paidBookingId: bookingId,
        unitId: unitId,
        tanggalBooking: tanggalBooking,
        jamMulai: jamMulai,
        jamSelesai: jamSelesai,
      );
    } catch (e) {
      // Pembayaran sudah berhasil — conflict check gagal tidak perlu crash UI
      debugPrint(
        '[Payment] Conflict check gagal setelah pembayaran: $e',
      );
    }
  }

  /// Menandai booking sebagai expired dan membatalkannya secara otomatis
  /// ketika timer pembayaran habis di sisi client.
  Future<void> expireBooking(String bookingId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'statusPembayaran': 'expired',
        'statusBooking': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (kDebugMode) {
        debugPrint('[Payment] Booking $bookingId expired dan dibatalkan');
      }
    } catch (e) {
      debugPrint('[Payment] Gagal expire booking $bookingId: $e');
    }
  }
}
