import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'dashboard_service.dart';
export 'dashboard_service.dart';

class FirestoreService {
  final FirebaseFirestore _db;
  final DashboardService _dashboard;

  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance,
      _dashboard = DashboardService(
        firestore: firestore ?? FirebaseFirestore.instance,
      );

  // Helper Notifikasi Standar

  Future<void> _sendNotificationHelper({
    required String targetId,
    required String roleTarget,
    String? stationId,
    String? bookingId,
    required String type,
    required String title,
    required String message,
  }) async {
    try {
      final String notifId = _db.collection('notifications').doc().id;
      final payload = {
        'userId': targetId,
        'targetId': targetId,
        'roleTarget': roleTarget,
        'stationId': stationId ?? '',
        'bookingId': bookingId ?? '',
        'relatedBookingId': bookingId ?? '',
        'type': type,
        'title': title,
        'message': message,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('notifications').doc(notifId).set(payload);
      if (kDebugMode) {
        debugPrint(
          '[Firestore] Notification Sent: $title ($type) untuk $roleTarget',
        );
      }
    } catch (e) {
      debugPrint('[Firestore] Gagal mengirim notifikasi: $e');
    }
  }

  void _addNotificationToBatch(
    WriteBatch batch, {
    required String targetId,
    required String roleTarget,
    String? stationId,
    String? bookingId,
    required String type,
    required String title,
    required String message,
  }) {
    final DocumentReference notifRef = _db.collection('notifications').doc();
    batch.set(notifRef, {
      'userId': targetId,
      'targetId': targetId,
      'roleTarget': roleTarget,
      'stationId': stationId ?? '',
      'bookingId': bookingId ?? '',
      'relatedBookingId': bookingId ?? '',
      'type': type,
      'title': title,
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // User

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final data = snap.docs.first.data();
      data['id'] = snap.docs.first.id;
      return data;
    }
    return null;
  }

  // Station

  Future<Map<String, dynamic>?> getStationByOwnerId(
    String ownerId, {
    String? email,
    String? name,
  }) async {
    try {
      final direct = await _db.collection('stations').doc(ownerId).get();
      if (direct.exists) {
        final data = direct.data();
        if (data != null) {
          data['id'] = direct.id;
          return data;
        }
      }

      String normalize(dynamic v) =>
          v == null ? '' : v.toString().trim().toLowerCase();

      final queries = <Query<Map<String, dynamic>>>[];
      queries.add(
        _db
            .collection('stations')
            .where('ownerId', isEqualTo: ownerId)
            .limit(1),
      );
      if (email != null && email.isNotEmpty) {
        queries.add(
          _db
              .collection('stations')
              .where('emailOwner', isEqualTo: email)
              .limit(1),
        );
      }
      if (name != null && name.isNotEmpty) {
        queries.add(
          _db
              .collection('stations')
              .where('namaOwner', isEqualTo: name)
              .limit(1),
        );
        queries.add(
          _db
              .collection('stations')
              .where('ownerName', isEqualTo: name)
              .limit(1),
        );
      }

      for (final q in queries) {
        final snap = await q.get();
        if (snap.docs.isNotEmpty) {
          final Map<String, dynamic> data = snap.docs.first.data();
          data['id'] = snap.docs.first.id;
          return data;
        }
      }

      final all = await _db.collection('stations').get();
      for (final d in all.docs) {
        final Map<String, dynamic> data = d.data();
        if (normalize(data['ownerId']) == normalize(ownerId) ||
            (email != null &&
                normalize(data['emailOwner']) == normalize(email)) ||
            (name != null &&
                (normalize(data['namaOwner']) == normalize(name) ||
                    normalize(data['ownerName']) == normalize(name)))) {
          data['id'] = d.id;
          return data;
        }
      }
    } catch (e) {
      debugPrint('[Firestore] Error getStationByOwnerId: $e');
    }
    return null;
  }

  // Units

  Stream<QuerySnapshot> getUnitsStreamByStation(String stationId) {
    return _db
        .collection('units')
        .where('stationId', isEqualTo: stationId)
        .snapshots();
  }

  Future<QuerySnapshot> getUnitsOnceByStation(String stationId) {
    return _db
        .collection('units')
        .where('stationId', isEqualTo: stationId)
        .get();
  }

  Future<DocumentSnapshot> getUnitById(String unitId) {
    return _db.collection('units').doc(unitId).get();
  }

  // Bookings

  Stream<QuerySnapshot> getBookingsStreamByStation(String stationId) {
    return _db
        .collection('bookings')
        .where('stationId', isEqualTo: stationId)
        .snapshots();
  }

  Stream<QuerySnapshot> getBookingsStreamByUnit(String unitId) {
    return _db
        .collection('bookings')
        .where('unitId', isEqualTo: unitId)
        .snapshots();
  }

  Future<DocumentSnapshot> getBookingById(String bookingId) {
    return _db.collection('bookings').doc(bookingId).get();
  }

  Future<void> createBooking(Map<String, dynamic> bookingData) async {
    final String unitId = bookingData['unitId']?.toString() ?? '';
    final String tanggalBooking =
        bookingData['tanggalBooking']?.toString() ?? '';
    final String jamMulai = bookingData['jamMulai']?.toString() ?? '';
    final String jamSelesai = bookingData['jamSelesai']?.toString() ?? '';

    if (unitId.isNotEmpty) {
      final DocumentSnapshot unitSnap = await _db
          .collection('units')
          .doc(unitId)
          .get();
      if (unitSnap.exists) {
        final Map<String, dynamic> currentUnitData =
            unitSnap.data() as Map<String, dynamic>? ?? {};
        final String currentStatus = (currentUnitData['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (currentStatus == 'perawatan' ||
            currentStatus == 'maintenance' ||
            currentStatus == 'tidak_aktif' ||
            currentStatus == 'tidak_tersedia' ||
            currentStatus == 'inactive') {
          throw Exception('Unit tidak tersedia untuk dipesan.');
        }
      }
    }

    // Cek bentrok jadwal dengan booking lain yang sudah dibayar atau aktif
    if (unitId.isNotEmpty &&
        tanggalBooking.isNotEmpty &&
        jamMulai.isNotEmpty &&
        jamSelesai.isNotEmpty) {
      final bookingsSnap = await _db
          .collection('bookings')
          .where('unitId', isEqualTo: unitId)
          .where('tanggalBooking', isEqualTo: tanggalBooking)
          .get();

      final int newStart = _timeStrToMinutes(jamMulai);
      final int newEnd = _timeStrToMinutes(jamSelesai);

      for (final doc in bookingsSnap.docs) {
        final data = doc.data();
        final String statusBooking = (data['statusBooking'] ?? '')
            .toString()
            .toLowerCase();
        final String statusPembayaran = (data['statusPembayaran'] ?? '')
            .toString()
            .toLowerCase();

        // Abaikan status terminal
        if (statusBooking == 'cancelled' ||
            statusBooking == 'rejected' ||
            statusBooking == 'completed' ||
            statusBooking == 'expired' ||
            statusPembayaran == 'expired' ||
            statusPembayaran == 'cancelled') {
          continue;
        }

        // Blokir jika booking lain sudah paid atau statusnya aktif (pending_confirmation, confirmed, active, checkin)
        final bool isPaid = statusPembayaran == 'paid';
        final bool isActiveStatus =
            statusBooking == 'pending_confirmation' ||
            statusBooking == 'confirmed' ||
            statusBooking == 'active' ||
            statusBooking == 'checkin';

        if (isPaid || isActiveStatus) {
          final int existStart = _timeStrToMinutes(
            data['jamMulai']?.toString() ?? '00:00',
          );
          final int existEnd = _timeStrToMinutes(
            data['jamSelesai']?.toString() ?? '00:00',
          );

          if (newStart < existEnd && newEnd > existStart) {
            throw Exception(
              'Jadwal tersebut sudah dibooking oleh pengguna lain.',
            );
          }
        }
      }
    }

    final String? bookingId = bookingData['bookingId']?.toString();
    final String generatedId = bookingId != null && bookingId.isNotEmpty
        ? bookingId
        : _db.collection('bookings').doc().id;

    final Map<String, dynamic> payload = Map<String, dynamic>.from(bookingData)
      ..['bookingId'] = generatedId
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..putIfAbsent('createdAt', () => FieldValue.serverTimestamp());

    await _db.collection('bookings').doc(generatedId).set(payload);

    try {
      final String uId = payload['userId']?.toString() ?? '';
      final String stationId = payload['stationId']?.toString() ?? '';
      if (uId.isNotEmpty) {
        // Notifikasi untuk User
        await _sendNotificationHelper(
          targetId: uId,
          roleTarget: 'user',
          stationId: stationId,
          bookingId: generatedId,
          type: 'booking_created',
          title: 'Booking Berhasil Dibuat',
          message: 'Booking berhasil dibuat dan menunggu pembayaran.',
        );

        // Notifikasi untuk Admin
        await _sendNotificationHelper(
          targetId: uId, // gunakan uId sebagai targetId (bukan ownerId)
          roleTarget: 'admin',
          stationId: stationId,
          bookingId: generatedId,
          type: 'booking_received',
          title: 'Booking Baru Masuk',
          message: 'Ada booking baru yang memerlukan tindakan.',
        );

        // Pengecekan booking pertama untuk stasiun (station_first_booking) -> ke Superadmin
        if (stationId.isNotEmpty) {
          final bookingsSnap = await _db
              .collection('bookings')
              .where('stationId', isEqualTo: stationId)
              .limit(2)
              .get();
          if (bookingsSnap.docs.length <= 1) {
            await _sendNotificationHelper(
              targetId: 'superadmin',
              roleTarget: 'superadmin',
              stationId: stationId,
              bookingId: generatedId,
              type: 'station_first_booking',
              title: 'Booking Pertama Game Station',
              message: 'Game Station menerima booking pertamanya!',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[Firestore] Gagal generate notifikasi di createBooking: $e');
    }
  }

  /// Menghasilkan ID booking baru tanpa menyimpan ke Firestore.
  String generateBookingId() {
    return _db.collection('bookings').doc().id;
  }

  Future<void> updateBooking(
    String bookingId,
    Map<String, dynamic> updates,
  ) async {
    String oldStatusPembayaran = '';
    int totalHarga = 0;
    String stationId = '';
    try {
      final oldSnap = await _db.collection('bookings').doc(bookingId).get();
      if (oldSnap.exists) {
        final oldData = oldSnap.data();
        oldStatusPembayaran = oldData?['statusPembayaran']?.toString() ?? '';
        totalHarga = (oldData?['totalHarga'] is num)
            ? (oldData?['totalHarga'] as num).toInt()
            : int.tryParse(oldData?['totalHarga']?.toString() ?? '0') ?? 0;
        stationId = oldData?['stationId']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('[Firestore] Gagal mengambil data lama booking di updateBooking: $e');
    }

    final Map<String, dynamic> payload = Map<String, dynamic>.from(updates)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('bookings').doc(bookingId).update(payload);

    final String newBookingStatus = updates['statusBooking']?.toString() ?? '';
    final String newPaymentStatus = updates['statusPembayaran']?.toString() ?? '';
    if (oldStatusPembayaran == 'paid' && stationId.isNotEmpty) {
      if (newBookingStatus == 'cancelled' ||
          newBookingStatus == 'rejected' ||
          newPaymentStatus == 'cancelled' ||
          newPaymentStatus == 'expired') {
        try {
          await _db.collection('stations').doc(stationId).update({
            'totalPemasukan': FieldValue.increment(-totalHarga),
          });
          if (kDebugMode) {
            debugPrint('[Firestore] Pemasukan stasiun $stationId didecrement sebesar $totalHarga karena booking $bookingId dibatalkan.');
          }
        } catch (e) {
          debugPrint('[Firestore] Gagal decrement totalPemasukan stasiun: $e');
        }
      }
    }

    // Ambil data terbaru untuk notifikasi
    try {
      final snap = await _db.collection('bookings').doc(bookingId).get();
      if (snap.exists) {
        final data = snap.data();
        if (data != null) {
          final String uId = data['userId']?.toString() ?? '';
          final String stationId = data['stationId']?.toString() ?? '';

          if (updates.containsKey('statusBooking')) {
            final String newStatus = updates['statusBooking'];

            // Sinkronisasi status unit (room/PC) ke 'digunakan' atau 'tersedia'
            final String unitId = data['unitId']?.toString() ?? '';
            if (unitId.isNotEmpty) {
              if (newStatus == 'confirmed' ||
                  newStatus == 'checkin' ||
                  newStatus == 'active') {
                await _db.collection('units').doc(unitId).update({
                  'status': 'digunakan',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (kDebugMode) {
                  debugPrint(
                    '[Firestore] Status unit $unitId diubah menjadi digunakan karena booking $newStatus',
                  );
                }
              } else if (newStatus == 'completed' ||
                  newStatus == 'cancelled' ||
                  newStatus == 'rejected') {
                await _db.collection('units').doc(unitId).update({
                  'status': 'tersedia',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (kDebugMode) {
                  debugPrint(
                    '[Firestore] Status unit $unitId diubah menjadi tersedia karena booking $newStatus',
                  );
                }
              }
            }

            if (newStatus == 'confirmed') {
              // USER: booking_confirmed
              await _sendNotificationHelper(
                targetId: uId,
                roleTarget: 'user',
                stationId: stationId,
                bookingId: bookingId,
                type: 'booking_confirmed',
                title: 'Booking Diterima',
                message: 'Booking Anda telah diterima oleh Game Station.',
              );

              // ADMIN: booking_today (jika tanggalBooking hari ini)
              final String tanggalBooking =
                  data['tanggalBooking']?.toString() ?? '';
              final String todayDate = DateTime.now()
                  .toIso8601String()
                  .substring(0, 10);
              if (tanggalBooking == todayDate) {
                await _sendNotificationHelper(
                  targetId: uId,
                  roleTarget: 'admin',
                  stationId: stationId,
                  bookingId: bookingId,
                  type: 'booking_today',
                  title: 'Jadwal Bermain Hari Ini',
                  message: 'Hari ini terdapat booking jadwal bermain.',
                );
              }
            } else if (newStatus == 'rejected') {
              // USER: booking_rejected
              await _sendNotificationHelper(
                targetId: uId,
                roleTarget: 'user',
                stationId: stationId,
                bookingId: bookingId,
                type: 'booking_rejected',
                title: 'Booking Ditolak',
                message: 'Booking Anda ditolak oleh Game Station.',
              );
            } else if (newStatus == 'cancelled') {
              final String customReason = updates['cancelReason']?.toString() ?? '';
              
              String title = 'Booking Dibatalkan';
              String message = 'Booking Anda telah dibatalkan.';
              
              if (customReason.toLowerCase().contains('ditolak') || customReason.toLowerCase().contains('reject')) {
                title = 'Booking Ditolak oleh Admin';
                message = customReason.isNotEmpty ? customReason : 'Booking Anda ditolak oleh Admin.';
              } else if (customReason.toLowerCase().contains('dibatalkan karena jadwal telah dikonfirmasi') || 
                         customReason.toLowerCase().contains('slot sudah digunakan') || 
                         customReason.toLowerCase().contains('bentrok')) {
                title = 'Booking Dibatalkan Otomatis';
                message = customReason.isNotEmpty ? customReason : 'Booking dibatalkan otomatis karena bentrok jadwal.';
              } else if (customReason.isNotEmpty) {
                message = customReason;
              } else {
                title = 'Booking Dibatalkan';
                message = 'Booking dibatalkan karena pembayaran tidak diselesaikan.';
              }

              // USER: booking_cancelled
              await _sendNotificationHelper(
                targetId: uId,
                roleTarget: 'user',
                stationId: stationId,
                bookingId: bookingId,
                type: 'booking_cancelled',
                title: title,
                message: message,
              );
              // ADMIN: booking_cancelled
              await _sendNotificationHelper(
                targetId: uId,
                roleTarget: 'admin',
                stationId: stationId,
                bookingId: bookingId,
                type: 'booking_cancelled',
                title: title,
                message: message,
              );
            } else if (newStatus == 'completed') {
              // USER: booking_completed
              await _sendNotificationHelper(
                targetId: uId,
                roleTarget: 'user',
                stationId: stationId,
                bookingId: bookingId,
                type: 'booking_completed',
                title: 'Sesi Bermain Selesai',
                message:
                    'Sesi bermain Anda telah selesai. Jangan lupa berikan rating dan review untuk Game Station.',
              );
            }
          }

          if (updates.containsKey('statusPembayaran')) {
            final String newPay = updates['statusPembayaran'];
            if (newPay == 'paid') {
              // USER: payment_success
              await _sendNotificationHelper(
                targetId: uId,
                roleTarget: 'user',
                stationId: stationId,
                bookingId: bookingId,
                type: 'payment_success',
                title: 'Pembayaran Berhasil',
                message:
                    'Pembayaran berhasil. Booking sedang menunggu konfirmasi Game Station.',
              );
              // ADMIN: payment_received
              await _sendNotificationHelper(
                targetId: uId,
                roleTarget: 'admin',
                stationId: stationId,
                bookingId: bookingId,
                type: 'payment_received',
                title: 'Pembayaran Berhasil',
                message:
                    'User telah melakukan pembayaran dan menunggu konfirmasi.',
              );
            } else if (newPay == 'expired' || newPay == 'cancelled') {
              // USER: booking_cancelled
              await _sendNotificationHelper(
                targetId: uId,
                roleTarget: 'user',
                stationId: stationId,
                bookingId: bookingId,
                type: 'booking_cancelled',
                title: 'Booking Dibatalkan Otomatis',
                message:
                    'Booking dibatalkan karena pembayaran tidak diselesaikan.',
              );
              // ADMIN: booking_cancelled
              await _sendNotificationHelper(
                targetId: uId,
                roleTarget: 'admin',
                stationId: stationId,
                bookingId: bookingId,
                type: 'booking_cancelled',
                title: 'Booking Dibatalkan Otomatis',
                message:
                    'Booking dibatalkan karena pembayaran tidak diselesaikan.',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[Firestore] Gagal generate notifikasi di updateBooking: $e');
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    await updateBooking(bookingId, {'statusBooking': 'cancelled'});
  }

  /// Memeriksa booking milik [userId] yang masih pending/unpaid dan sudah
  /// melewati batas waktu pembayaran (createdAt + [paymentWindowMinutes]).
  ///
  /// Booking yang overdue di-expire secara batch:
  ///   statusPembayaran → 'expired'
  ///   statusBooking    → 'cancelled'
  ///
  /// Dipanggil saat BookingHistoryPage dibuka — tanpa Cloud Functions,
  /// status tetap sinkron setiap kali user membuka riwayat booking.
  Future<void> expireOverdueBookings(
    String userId, {
    int paymentWindowMinutes = 15,
  }) async {
    try {
      final snap = await _db
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('statusBooking', isEqualTo: 'pending')
          .where('statusPembayaran', isEqualTo: 'unpaid')
          .get();

      if (snap.docs.isEmpty) return;

      final DateTime now = DateTime.now();
      final Duration window = Duration(minutes: paymentWindowMinutes);
      final WriteBatch batch = _db.batch();
      int expiredCount = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final dynamic raw = data['createdAt'];
        if (raw == null) continue;

        DateTime? createdAt;
        if (raw is Timestamp) {
          createdAt = raw.toDate();
        } else if (raw is DateTime) {
          createdAt = raw;
        }
        if (createdAt == null) continue;

        if (now.isAfter(createdAt.add(window))) {
          batch.update(doc.reference, {
            'statusPembayaran': 'expired',
            'statusBooking': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final String stationId = data['stationId']?.toString() ?? '';

          // USER: booking_cancelled
          _addNotificationToBatch(
            batch,
            targetId: userId,
            roleTarget: 'user',
            stationId: stationId,
            bookingId: doc.id,
            type: 'booking_cancelled',
            title: 'Booking Dibatalkan Otomatis',
            message: 'Booking dibatalkan karena pembayaran tidak diselesaikan.',
          );

          // ADMIN: booking_cancelled
          _addNotificationToBatch(
            batch,
            targetId: userId,
            roleTarget: 'admin',
            stationId: stationId,
            bookingId: doc.id,
            type: 'booking_cancelled',
            title: 'Booking Dibatalkan Otomatis',
            message: 'Booking dibatalkan karena pembayaran tidak diselesaikan.',
          );

          expiredCount++;
        }
      }

      if (expiredCount > 0) {
        await batch.commit();
        if (kDebugMode) {
          debugPrint(
            '[Firestore] $expiredCount booking expired untuk user $userId',
          );
        }
      }
    } catch (e) {
      debugPrint('[Firestore] Error expireOverdueBookings: $e');
    }
  }

  /// Membaca semua booking yang sedang berjalan dan menyelesaikan otomatis jika
  /// waktu sewa (tanggalBooking + jamSelesai) sudah terlewati.
  /// Dipanggil di berbagai entry point halaman admin & user, serta oleh timer
  /// periodik di [MyApp] agar tidak bergantung pada navigasi halaman.
  ///
  /// Status yang dicakup: 'confirmed', 'active', 'checkin'
  /// ('active' dan 'checkin' dipertahankan untuk kompatibilitas masa depan).
  Future<void> completeFinishedBookings({
    String? userId,
    String? stationId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('bookings')
          .where(
            'statusBooking',
            whereIn: const ['confirmed', 'active', 'checkin'],
          );

      if (userId != null && userId.isNotEmpty) {
        query = query.where('userId', isEqualTo: userId);
      }
      if (stationId != null && stationId.isNotEmpty) {
        query = query.where('stationId', isEqualTo: stationId);
      }

      final snap = await query.get();
      if (snap.docs.isEmpty) return;

      final DateTime now = DateTime.now();
      final WriteBatch batch = _db.batch();
      int completedCount = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final String tanggalBooking = data['tanggalBooking']?.toString() ?? '';
        final String jamSelesai = data['jamSelesai']?.toString() ?? '';
        final String unitId = data['unitId']?.toString() ?? '';
        final String uId = data['userId']?.toString() ?? '';
        final String statId = data['stationId']?.toString() ?? '';

        if (tanggalBooking.isEmpty || jamSelesai.isEmpty) continue;

        final DateTime? endTime = _parseBookingEndTime(
          tanggalBooking,
          jamSelesai,
        );
        if (endTime == null) continue;

        if (now.isAfter(endTime) || now.isAtSameMomentAs(endTime)) {
          // 1. Perbarui status Booking menjadi selesai
          batch.update(doc.reference, {
            'statusBooking': 'completed',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // 2. Kembalikan status Unit menjadi tersedia
          if (unitId.isNotEmpty) {
            batch.update(_db.collection('units').doc(unitId), {
              'status': 'tersedia',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }

          // 3. Buat Notifikasi untuk pengguna
          if (uId.isNotEmpty) {
            _addNotificationToBatch(
              batch,
              targetId: uId,
              roleTarget: 'user',
              stationId: statId,
              bookingId: doc.id,
              type: 'booking_completed',
              title: 'Sesi Bermain Selesai',
              message:
                  'Sesi bermain Anda telah selesai. Jangan lupa berikan rating dan review untuk Game Station.',
            );
          }

          completedCount++;
        }
      }

      if (completedCount > 0) {
        await batch.commit();
        if (kDebugMode) {
          debugPrint(
            '[Firestore] $completedCount booking otomatis diselesaikan',
          );
        }
      }
    } catch (e) {
      debugPrint('[Firestore] Error completeFinishedBookings: $e');
    }
  }

  DateTime? _parseBookingEndTime(String tanggalBooking, String jamSelesai) {
    try {
      final cleanTime = jamSelesai.replaceAll('.', ':');
      final timeParts = cleanTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final dateParts = tanggalBooking.split('-');
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      debugPrint('[Firestore] Error parsing booking end time: $e');
      return null;
    }
  }

  /// Membatalkan booking lain yang jadwalnya bertabrakan dengan booking yang
  /// baru dikonfirmasi admin.
  Future<int> cancelConflictingBookings({
    required String confirmedBookingId,
    required String unitId,
    required String tanggalBooking,
    required String jamMulai,
    required String jamSelesai,
  }) async {
    int cancelledCount = 0;
    try {
      final snap = await _db
          .collection('bookings')
          .where('unitId', isEqualTo: unitId)
          .where('tanggalBooking', isEqualTo: tanggalBooking)
          .where('statusBooking', isEqualTo: 'pending')
          .get();

      if (snap.docs.isEmpty) return 0;

      final int newStart = _timeStrToMinutes(jamMulai);
      final int newEnd = _timeStrToMinutes(jamSelesai);
      final WriteBatch batch = _db.batch();

      for (final doc in snap.docs) {
        if (doc.id == confirmedBookingId) continue;
        final data = doc.data();
        final int existStart = _timeStrToMinutes(
          data['jamMulai']?.toString() ?? '00:00',
        );
        final int existEnd = _timeStrToMinutes(
          data['jamSelesai']?.toString() ?? '00:00',
        );

        if (newStart < existEnd && newEnd > existStart) {
          batch.update(doc.reference, {
            'statusBooking': 'cancelled',
            'cancelReason':
                'Dibatalkan karena jadwal telah dikonfirmasi untuk booking lain.',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          cancelledCount++;
        }
      }
      if (cancelledCount > 0) await batch.commit();
    } catch (e) {
      debugPrint('[Firestore] Error cancelConflictingBookings: $e');
    }
    return cancelledCount;
  }

  int _timeStrToMinutes(String timeStr) {
    try {
      final parts = timeStr.replaceAll('.', ':').split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (_) {
      return 0;
    }
  }

  /// Membatalkan booking lain yang slot waktunya bertabrakan dengan booking
  /// yang baru saja dibayar oleh user.
  ///
  /// Dipanggil setelah [simulatePayment] berhasil — dari sisi user, bukan admin.
  /// Booking yang di-cancel harus memenuhi semua syarat:
  ///   • unitId sama
  ///   • tanggalBooking sama
  ///   • jam overlap
  ///   • statusPembayaran bukan 'paid', 'completed', 'cancelled'
  ///
  /// Field yang diupdate pada booking yang dibatalkan:
  ///   statusBooking    → 'cancelled'
  ///   statusPembayaran → 'cancelled'
  ///   cancelReason     → pesan informatif
  Future<void> cancelConflictingBookingsAfterPayment({
    required String paidBookingId,
    required String unitId,
    required String tanggalBooking,
    required String jamMulai,
    required String jamSelesai,
  }) async {
    try {
      // Ambil semua booking pada unit dan tanggal yang sama
      final snap = await _db
          .collection('bookings')
          .where('unitId', isEqualTo: unitId)
          .where('tanggalBooking', isEqualTo: tanggalBooking)
          .get();

      if (snap.docs.isEmpty) return;

      final int paidStart = _timeStrToMinutes(jamMulai);
      final int paidEnd = _timeStrToMinutes(jamSelesai);

      final WriteBatch batch = _db.batch();
      int cancelledCount = 0;

      for (final doc in snap.docs) {
        // Lewati booking yang baru dibayar itu sendiri
        if (doc.id == paidBookingId) continue;

        final data = doc.data();

        // Jangan batalkan booking yang sudah dalam status final
        final String statusBooking = (data['statusBooking'] ?? '')
            .toString()
            .toLowerCase();
        final String statusBayar = (data['statusPembayaran'] ?? '')
            .toString()
            .toLowerCase();

        if (statusBooking == 'cancelled' ||
            statusBooking == 'completed' ||
            statusBooking == 'rejected' ||
            statusBayar == 'paid' ||
            statusBayar == 'cancelled') {
          continue;
        }

        // Hitung overlap waktu
        final int existStart = _timeStrToMinutes(
          data['jamMulai']?.toString() ?? '00:00',
        );
        final int existEnd = _timeStrToMinutes(
          data['jamSelesai']?.toString() ?? '00:00',
        );

        // Overlap terjadi jika: paidStart < existEnd && paidEnd > existStart
        if (paidStart < existEnd && paidEnd > existStart) {
          batch.update(doc.reference, {
            'statusBooking': 'cancelled',
            'statusPembayaran': 'cancelled',
            'cancelReason':
                'Slot sudah digunakan oleh booking lain yang telah dibayar.',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          cancelledCount++;
          if (kDebugMode) {
            debugPrint(
              '[Firestore] Batalkan booking ${doc.id} karena konflik dengan $paidBookingId',
            );
          }
        }
      }

      if (cancelledCount > 0) {
        await batch.commit();
        if (kDebugMode) {
          debugPrint(
            '[Firestore] $cancelledCount booking dibatalkan karena konflik dengan $paidBookingId',
          );
        }
      }
    } catch (e) {
      // Tidak throw — pembayaran sudah berhasil, log saja
      debugPrint('[Firestore] Error cancelConflictingBookingsAfterPayment: $e');
    }
  }

  Future<QuerySnapshot> getActiveBookingsByUnit(String unitId) {
    return _db
        .collection('bookings')
        .where('unitId', isEqualTo: unitId)
        .where('statusBooking', whereIn: const ['active'])
        .get();
  }

  Future<QuerySnapshot> getStationBookingNotificationsOnce(String stationId) {
    return _db
        .collection('bookings')
        .where('stationId', isEqualTo: stationId)
        .get();
  }

  // Analytics (didelegasikan ke DashboardService)

  Future<int> getTotalUnits() async => _dashboard.getTotalUnits();
  Future<int> getStationTotalUnits(String stationId) async =>
      _dashboard.getStationTotalUnits(stationId);
  Future<int> getTotalPC() async => _dashboard.getTotalPC();
  Future<int> getStationTotalPC(String stationId) async =>
      _dashboard.getTotalPCByStation(stationId);
  Future<int> getTotalUnitsByType(String type) async =>
      _dashboard.getTotalUnitsByType(type);
  Future<int> getStationTotalUnitsByType(String stationId, String type) async =>
      _dashboard.getStationTotalUnitsByType(stationId, type);
  Future<UnitStatusSummary> getUnitStatusSummary() async =>
      _dashboard.getUnitStatusSummary();
  Future<UnitStatusSummary> getStationUnitStatusSummary(
    String stationId,
  ) async => _dashboard.getStationUnitStatusSummary(stationId);
  Future<PopularUnitData?> getMostBookedUnit({
    String? stationId,
    String? type,
  }) async => _dashboard.getMostBookedUnit(stationId: stationId, type: type);
  Future<int> getTotalBooking() async => _dashboard.getTotalBooking();
  Future<int> getStationTotalBooking(String stationId) async =>
      _dashboard.getStationTotalBooking(stationId);
  Future<int> getStationBookingHariIni(String stationId) async =>
      _dashboard.getStationBookingHariIni(stationId);
  Future<int> getStationTotalPemasukan(String stationId) async =>
      _dashboard.getStationTotalPemasukan(stationId);
  Future<double> getStationRatingGameStation(String stationId) async =>
      _dashboard.getStationRatingGameStation(stationId);

  Stream<QuerySnapshot> getStationBookingNotificationsStream(String stationId) {
    return _db
        .collection('bookings')
        .where('stationId', isEqualTo: stationId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getPendingAdminsStream() =>
      _db.collection('users').where('role', isEqualTo: 'admin').snapshots();

  Stream<QuerySnapshot> getUserBookingNotificationsStream(String userId) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where(
          'statusBooking',
          whereIn: ['confirmed', 'completed', 'cancelled', 'rejected'],
        )
        .snapshots();
  }

  Future<int> getStationBookingNotificationCount(
    String stationId, {
    DateTime? lastOpenedAt,
  }) async => _dashboard.getStationBookingNotificationCount(
    stationId,
    lastOpenedAt: lastOpenedAt,
  );

  Future<int> getBookingHariIni() async => _dashboard.getBookingHariIni();
  Future<double> getRatingGameStation() async =>
      _dashboard.getRatingGameStation();

  Future<DashboardAdminSummary> getDashboardAdminSummary({
    int recentLimit = 5,
  }) async => _dashboard.getDashboardAdminSummary(recentLimit: recentLimit);

  Future<DashboardAdminSummary> getStationDashboardAdminSummary(
    String stationId, {
    int recentLimit = 5,
  }) async => _dashboard.getStationDashboardAdminSummary(
    stationId,
    recentLimit: recentLimit,
  );

  Future<List<RecentActivityData>> getAktivitasTerbaru({int limit = 5}) async =>
      _dashboard.getAktivitasTerbaru(limit: limit);

  // Station CRUD (Buat/Baca/Ubah/Hapus)

  Future<void> createStation(
    String stationId,
    Map<String, dynamic> data,
  ) async => await _db.collection('stations').doc(stationId).set(data);

  Future<void> updateStation(
    String stationId,
    Map<String, dynamic> updates,
  ) async => await _db.collection('stations').doc(stationId).update(updates);

  Future<void> deleteStation(String stationId) async =>
      await _db.collection('stations').doc(stationId).delete();

  Stream<QuerySnapshot> getStationsStream() =>
      _db.collection('stations').snapshots();

  Stream<QuerySnapshot> getStationsByVerificationStatusStream(String status) =>
      _db
          .collection('stations')
          .where('statusVerifikasi', isEqualTo: status)
          .snapshots();

  Stream<QuerySnapshot> getVerifiedOrRejectedStationsStream() => _db
      .collection('stations')
      .where('statusVerifikasi', whereIn: const ['verified', 'rejected'])
      .snapshots();

  Stream<DocumentSnapshot> getStationStream(String stationId) =>
      _db.collection('stations').doc(stationId).snapshots();

  Future<void> verifyStation(
    String stationId,
    String ownerId,
    String status,
  ) async {
    final batch = _db.batch();
    batch.update(_db.collection('stations').doc(stationId), {
      'statusVerifikasi': status,
    });
    if (status == 'verified') {
      batch.update(_db.collection('users').doc(ownerId), {'status': 'active'});
      _addNotificationToBatch(
        batch,
        targetId: 'superadmin',
        roleTarget: 'superadmin',
        stationId: stationId,
        bookingId: '',
        type: 'admin_verified',
        title: 'Admin Diterima',
        message: 'Game Station berhasil diverifikasi.',
      );
    } else if (status == 'rejected') {
      batch.update(_db.collection('users').doc(ownerId), {
        'status': 'rejected',
      });
      _addNotificationToBatch(
        batch,
        targetId: 'superadmin',
        roleTarget: 'superadmin',
        stationId: stationId,
        bookingId: '',
        type: 'admin_rejected',
        title: 'Admin Ditolak',
        message: 'Pengajuan Game Station ditolak.',
      );
    }
    await batch.commit();
  }

  Future<void> rejectStation(String stationId) async {
    final stationDoc = await _db.collection('stations').doc(stationId).get();
    final ownerId = stationDoc.data()?['ownerId'] as String?;
    final batch = _db.batch();
    batch.update(_db.collection('stations').doc(stationId), {
      'statusVerifikasi': 'rejected',
    });
    if (ownerId != null) {
      batch.update(_db.collection('users').doc(ownerId), {
        'status': 'rejected',
      });
    }
    _addNotificationToBatch(
      batch,
      targetId: 'superadmin',
      roleTarget: 'superadmin',
      stationId: stationId,
      bookingId: '',
      type: 'admin_rejected',
      title: 'Admin Ditolak',
      message: 'Pengajuan Game Station ditolak.',
    );
    await batch.commit();
  }

  // User CRUD (Buat/Baca/Ubah/Hapus)

  Future<void> createUser(String userId, Map<String, dynamic> userData) async =>
      await _db.collection('users').doc(userId).set(userData);

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async =>
      await _db.collection('users').doc(userId).update(updates);

  Future<void> deleteUser(String userId) async =>
      await _db.collection('users').doc(userId).delete();

  Stream<QuerySnapshot> getUsersStream() => _db.collection('users').snapshots();

  Stream<DocumentSnapshot> getUserStream(String userId) =>
      _db.collection('users').doc(userId).snapshots();

  Future<void> registerAdminStation(
    String uid,
    Map<String, dynamic> userData,
    Map<String, dynamic> stationData,
  ) async {
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(uid), userData);
    batch.set(_db.collection('stations').doc(uid), stationData);
    await batch.commit();
  }

  // Unit CRUD (Buat/Baca/Ubah/Hapus)

  Future<void> createUnit(Map<String, dynamic> unitData) async {
    final String? unitId = unitData['id']?.toString();
    final String generatedId = unitId != null && unitId.isNotEmpty
        ? unitId
        : _db.collection('units').doc().id;
    final Map<String, dynamic> payload = Map<String, dynamic>.from(unitData)
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..putIfAbsent('createdAt', () => FieldValue.serverTimestamp());
    await _db.collection('units').doc(generatedId).set(payload);
  }

  Future<void> updateUnit(String unitId, Map<String, dynamic> updates) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(updates)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('units').doc(unitId).update(payload);
  }

  Future<void> deleteUnit(String unitId) async =>
      await _db.collection('units').doc(unitId).delete();

  Future<Map<String, dynamic>?> getStationData(String stationId) async {
    final doc = await _db.collection('stations').doc(stationId).get();
    return doc.data();
  }
}
