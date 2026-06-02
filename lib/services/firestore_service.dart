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

  // ── User ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data();
  }

  // ── Station ───────────────────────────────────────────────────────────────

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
      debugPrint('getStationByOwnerId error: $e');
    }
    return null;
  }

  // ── Units ─────────────────────────────────────────────────────────────────

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

  // ── Bookings ──────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> getBookingsStreamByStation(String stationId) {
    return _db
        .collection('bookings')
        .where('stationId', isEqualTo: stationId)
        .orderBy('createdAt', descending: true)
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
    final String? bookingId = bookingData['bookingId']?.toString();
    final String generatedId = bookingId != null && bookingId.isNotEmpty
        ? bookingId
        : _db.collection('bookings').doc().id;

    final Map<String, dynamic> payload = Map<String, dynamic>.from(bookingData)
      ..['bookingId'] = generatedId
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..putIfAbsent('createdAt', () => FieldValue.serverTimestamp());

    await _db.collection('bookings').doc(generatedId).set(payload);

    // Kirim notifikasi in-app
    try {
      final String uId = payload['userId']?.toString() ?? '';
      if (uId.isNotEmpty) {
        // Notifikasi untuk User
        final userNotifId = _db.collection('notifications').doc().id;
        await _db.collection('notifications').doc(userNotifId).set({
          'userId': uId,
          'roleTarget': 'user',
          'title': 'Booking Berhasil Dibuat',
          'message': 'Booking berhasil dibuat. Silakan lakukan pembayaran.',
          'type': 'booking_created',
          'isRead': false,
          'relatedBookingId': generatedId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Notifikasi untuk Admin
        final adminNotifId = _db.collection('notifications').doc().id;
        await _db.collection('notifications').doc(adminNotifId).set({
          'userId': uId,
          'roleTarget': 'admin',
          'title': 'Booking Baru Masuk',
          'message': 'Booking baru menunggu pembayaran.',
          'type': 'booking_created',
          'isRead': false,
          'relatedBookingId': generatedId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error generating notification in createBooking: $e');
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
    final Map<String, dynamic> payload = Map<String, dynamic>.from(updates)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('bookings').doc(bookingId).update(payload);

    // Ambil data terbaru untuk notifikasi
    try {
      final snap = await _db.collection('bookings').doc(bookingId).get();
      if (snap.exists) {
        final data = snap.data();
        if (data != null) {
          final String uId = data['userId']?.toString() ?? '';

          // Konfigurasi Notifikasi berdasarkan status yang diupdate
          String title = '';
          String message = '';
          String type = '';

          if (updates.containsKey('statusBooking')) {
            final String newStatus = updates['statusBooking'];
            
            // Sinkronisasi status unit (room/PC) ke 'digunakan' atau 'tersedia'
            final String unitId = data['unitId']?.toString() ?? '';
            if (unitId.isNotEmpty) {
              if (newStatus == 'confirmed' || newStatus == 'checkin' || newStatus == 'active') {
                await _db.collection('units').doc(unitId).update({
                  'status': 'digunakan',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                debugPrint('FirestoreService: status unit $unitId diubah menjadi digunakan karena status booking: $newStatus');
              } else if (newStatus == 'completed' || newStatus == 'cancelled' || newStatus == 'rejected') {
                await _db.collection('units').doc(unitId).update({
                  'status': 'tersedia',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                debugPrint('FirestoreService: status unit $unitId diubah menjadi tersedia karena status booking: $newStatus');
              }
            }

            if (newStatus == 'confirmed') {
              title = 'Booking Dikonfirmasi';
              message = 'Booking Anda telah dikonfirmasi oleh admin.';
              type = 'booking_confirmed';
            } else if (newStatus == 'cancelled') {
              title = 'Booking Dibatalkan';
              message = 'Booking Anda ditolak atau dibatalkan.';
              type = 'booking_cancelled';
            } else if (newStatus == 'rejected') {
              title = 'Booking Ditolak';
              message = 'Booking Anda ditolak oleh admin.';
              type = 'booking_rejected';
            } else if (newStatus == 'checkin' || newStatus == 'active') {
              title = 'Check-In Berhasil';
              message = 'Check-in berhasil. Selamat bermain.';
              type = 'booking_checkin';
            } else if (newStatus == 'completed') {
              title = 'Booking Selesai';
              message = 'Booking telah selesai. Berikan rating dan review Anda.';
              type = 'booking_completed';
            }
          } else if (updates.containsKey('statusPembayaran')) {
            final String newPay = updates['statusPembayaran'];
            if (newPay == 'paid') {
              title = 'Pembayaran Berhasil';
              message = 'Pembayaran berhasil. Menunggu konfirmasi admin.';
              type = 'payment_success';
            } else if (newPay == 'expired') {
              title = 'Pembayaran Expired';
              message = 'Booking dibatalkan karena pembayaran melewati batas waktu.';
              type = 'payment_expired';
            } else if (newPay == 'cancelled') {
              title = 'Booking Dibatalkan';
              message = 'Booking dibatalkan karena slot telah digunakan oleh booking lain yang berhasil dibayar.';
              type = 'booking_cancelled';
            }
          }

          if (type.isNotEmpty && uId.isNotEmpty) {
            // 1. Kirim notifikasi untuk User
            final userNotifId = _db.collection('notifications').doc().id;
            await _db.collection('notifications').doc(userNotifId).set({
              'userId': uId,
              'roleTarget': 'user',
              'title': title,
              'message': message,
              'type': type,
              'isRead': false,
              'relatedBookingId': bookingId,
              'createdAt': FieldValue.serverTimestamp(),
            });

            // 2. Kirim notifikasi untuk Admin dengan pesan penyesuaian khusus Admin
            String adminTitle = title;
            String adminMessage = message;
            
            final String shortId = bookingId.length > 5 ? '${bookingId.substring(0, 5)}...' : bookingId;

            if (type == 'booking_confirmed') {
              adminTitle = 'Booking Dikonfirmasi';
              adminMessage = 'Booking #$shortId telah dikonfirmasi.';
            } else if (type == 'booking_cancelled') {
              adminTitle = 'Booking Dibatalkan';
              adminMessage = 'Booking #$shortId telah dibatalkan.';
            } else if (type == 'booking_rejected') {
              adminTitle = 'Booking Ditolak';
              adminMessage = 'Booking #$shortId telah ditolak.';
            } else if (type == 'booking_checkin') {
              adminTitle = 'Check-In Berhasil';
              adminMessage = 'Booking #$shortId berhasil check-in.';
            } else if (type == 'booking_completed') {
              adminTitle = 'Booking Selesai';
              adminMessage = 'Booking #$shortId telah selesai.';
            } else if (type == 'payment_success') {
              adminTitle = 'Booking Menunggu Konfirmasi';
              adminMessage = 'Booking #$shortId telah dibayar. Menunggu konfirmasi Anda.';
            } else if (type == 'payment_expired') {
              adminTitle = 'Booking Expired';
              adminMessage = 'Booking #$shortId dibatalkan karena batas waktu pembayaran habis.';
            }

            final adminNotifId = _db.collection('notifications').doc().id;
            await _db.collection('notifications').doc(adminNotifId).set({
              'userId': uId,
              'roleTarget': 'admin',
              'title': adminTitle,
              'message': adminMessage,
              'type': type,
              'isRead': false,
              'relatedBookingId': bookingId,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error generating notification in updateBooking: $e');
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    await updateBooking(bookingId, {
      'statusBooking': 'cancelled',
    });
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
          expiredCount++;
        }
      }

      if (expiredCount > 0) {
        await batch.commit();
        debugPrint(
          'FirestoreService: $expiredCount booking expired '
          'untuk user $userId.',
        );
      }
    } catch (e) {
      debugPrint('expireOverdueBookings error: $e');
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
      debugPrint('cancelConflictingBookings error: $e');
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
          debugPrint(
            'FirestoreService: batalkan booking ${doc.id} '
            '(${data['jamMulai']}–${data['jamSelesai']}) '
            'karena konflik dengan booking $paidBookingId.',
          );
        }
      }

      if (cancelledCount > 0) {
        await batch.commit();
        debugPrint(
          'FirestoreService: $cancelledCount booking dibatalkan '
          'karena konflik dengan booking $paidBookingId.',
        );
      }
    } catch (e) {
      // Tidak throw — pembayaran sudah berhasil, log saja
      debugPrint('cancelConflictingBookingsAfterPayment error: $e');
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

  // ── Analytics (delegated to DashboardService) ─────────────────────────────

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

  // ── Station CRUD ──────────────────────────────────────────────────────────

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
    } else if (status == 'rejected') {
      batch.update(_db.collection('users').doc(ownerId), {
        'status': 'rejected',
      });
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
    await batch.commit();
  }

  // ── User CRUD ─────────────────────────────────────────────────────────────

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

  // ── Unit CRUD ─────────────────────────────────────────────────────────────

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
