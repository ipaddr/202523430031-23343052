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
    // Ambil data booking terlebih dahulu untuk mendapatkan stationId dan totalHarga
    String stationId = '';
    int totalHarga = 0;
    String unitId = '';
    String tanggalBooking = '';
    String jamMulai = '';
    String jamSelesai = '';

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
      }
    } catch (e) {
      debugPrint('PaymentService: Gagal mengambil data booking awal — $e');
    }

    // Langkah 1: Update status pembayaran booking & totalPemasukan stasiun secara atomik
    try {
      await _firestore.runTransaction((transaction) async {
        final DocumentReference bookingRef = _firestore.collection('bookings').doc(bookingId);

        // 1. Update Booking
        transaction.update(bookingRef, {
          'statusPembayaran': 'paid',
          'metodePembayaran': metodePembayaran,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 2. Increment totalPemasukan stasiun
        if (stationId.isNotEmpty) {
          final DocumentReference stationRef = _firestore.collection('stations').doc(stationId);
          transaction.update(stationRef, {
            'totalPemasukan': FieldValue.increment(totalHarga),
          });
        }
      });

      debugPrint(
        'PaymentService: booking $bookingId berhasil dibayar via $metodePembayaran. '
        'totalPemasukan stasiun $stationId bertambah Rp $totalHarga.',
      );
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
        'PaymentService: conflict check gagal setelah pembayaran — $e',
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
      debugPrint('PaymentService: booking $bookingId expired dan dibatalkan.');
    } catch (e) {
      debugPrint('PaymentService: gagal expire booking $bookingId — $e');
    }
  }
}
