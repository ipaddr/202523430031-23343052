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

  // User
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data();
  }

  // Station (lookup by ownerId / email / name)
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
    final String? bookingId = bookingData['bookingId']?.toString();
    final String generatedId = bookingId != null && bookingId.isNotEmpty
        ? bookingId
        : _db.collection('bookings').doc().id;

    final Map<String, dynamic> payload = Map<String, dynamic>.from(bookingData)
      ..['bookingId'] = generatedId
      ..['updatedAt'] = FieldValue.serverTimestamp()
      ..putIfAbsent('createdAt', () => FieldValue.serverTimestamp());

    await _db.collection('bookings').doc(generatedId).set(payload);
  }

  Future<void> updateBooking(
    String bookingId,
    Map<String, dynamic> updates,
  ) async {
    final Map<String, dynamic> payload = Map<String, dynamic>.from(updates)
      ..['updatedAt'] = FieldValue.serverTimestamp();

    await _db.collection('bookings').doc(bookingId).update(payload);
  }

  Future<void> cancelBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'statusBooking': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  // =========================
  // Delegated/analytics methods (via DashboardService)
  // =========================

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

  // Station CRUD delegations
  Future<void> createStation(
    String stationId,
    Map<String, dynamic> stationData,
  ) async => await _db.collection('stations').doc(stationId).set(stationData);

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

  // User CRUD
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

  // Unit CRUD
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
