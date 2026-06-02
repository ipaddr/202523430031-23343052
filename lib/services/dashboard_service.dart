import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:gamezone/utils/helpers.dart';
import 'package:gamezone/widgets/admin/unit_filter_bar.dart';

// Dashboard Summary
class DashboardAdminSummary {
  final int totalBooking;
  final int totalUnit;
  final int bookingHariIni;
  final int totalPemasukan;
  final double ratingGameStation;
  final PopularUnitData? unitTerlaris;
  final List<RecentActivityData> aktivitasTerbaru;

  const DashboardAdminSummary({
    required this.totalBooking,
    required this.totalUnit,
    required this.bookingHariIni,
    required this.totalPemasukan,
    required this.ratingGameStation,
    required this.unitTerlaris,
    required this.aktivitasTerbaru,
  });
}

class PopularUnitData {
  final String unitId;
  final String unitName;
  final int bookingCount;

  const PopularUnitData({
    required this.unitId,
    required this.unitName,
    required this.bookingCount,
  });
}

class RecentActivityData {
  final String activityName;
  final String timeText;
  final String? photoUrl;
  final DateTime? occurredAt;

  const RecentActivityData({
    required this.activityName,
    required this.timeText,
    this.photoUrl,
    this.occurredAt,
  });
}

class UnitStatusSummary {
  final int totalUnit;
  final int full;
  final int available;

  const UnitStatusSummary({
    required this.totalUnit,
    required this.full,
    required this.available,
  });
}

class DashboardService {
  final FirebaseFirestore _db;

  DashboardService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  // =========================
  // Ringkasan Dashboard
  Future<DashboardAdminSummary> getDashboardAdminSummary({
    int recentLimit = 5,
  }) async {
    final results = await Future.wait([
      getTotalBooking(),
      getTotalUnits(),
      getBookingHariIni(),
      getTotalPemasukan(),
      getRatingGameStation(),
      getMostBookedUnit(),
      getAktivitasTerbaru(limit: recentLimit),
    ]);

    return DashboardAdminSummary(
      totalBooking: results[0] as int,
      totalUnit: results[1] as int,
      bookingHariIni: results[2] as int,
      totalPemasukan: results[3] as int,
      ratingGameStation: results[4] as double,
      unitTerlaris: results[5] as PopularUnitData?,
      aktivitasTerbaru: results[6] as List<RecentActivityData>,
    );
  }

  Future<DashboardAdminSummary> getStationDashboardAdminSummary(
    String stationId, {
    int recentLimit = 5,
  }) async {
    final results = await Future.wait([
      getStationTotalBooking(stationId),
      getStationTotalUnits(stationId),
      getStationBookingHariIni(stationId),
      getStationTotalPemasukan(stationId),
      getStationRatingGameStation(stationId),
      getMostBookedUnit(stationId: stationId),
      Future<List<RecentActivityData>>.value(const []),
    ]);

    return DashboardAdminSummary(
      totalBooking: results[0] as int,
      totalUnit: results[1] as int,
      bookingHariIni: results[2] as int,
      totalPemasukan: results[3] as int,
      ratingGameStation: results[4] as double,
      unitTerlaris: results[5] as PopularUnitData?,
      aktivitasTerbaru: results[6] as List<RecentActivityData>,
    );
  }

  // =========================
  // ACTIVITY ANALYTICS
  // =========================

  Future<List<RecentActivityData>> getAktivitasTerbaru({int limit = 5}) async {
    final activities = <RecentActivityData>[];

    await Future.wait([
      _appendUserActivities(activities),
      _appendStationActivities(activities),
      _appendBookingActivities(activities),
      _appendReviewActivities(activities),
    ]);

    activities.sort((a, b) {
      final DateTime? first = a.occurredAt;
      final DateTime? second = b.occurredAt;
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });

    return activities.take(limit).toList(growable: false);
  }

  // Menghitung jumlah transaksi pemesanan khusus untuk hari ini
  Future<int> getBookingHariIni() async {
    try {
      final DateTime today = DateTime.now();
      // Format tanggalBooking sesuai yang disimpan di Firestore: 'YYYY-MM-DD'
      final String todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Filter langsung di Firestore menggunakan tanggalBooking (tanggal bermain
      // yang dipilih user), bukan createdAt (tanggal dokumen dibuat).
      final snapshot = await _db
          .collection('bookings')
          .where('tanggalBooking', isEqualTo: todayStr)
          .get();

      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting booking hari ini: $e');
      return 0;
    }
  }

  Future<int> getStationBookingNotificationCount(
    String stationId, {
    DateTime? lastOpenedAt,
  }) async {
    try {
      final snapshot = await _db
          .collection('bookings')
          .where('stationId', isEqualTo: stationId)
          .get();

      if (lastOpenedAt == null) {
        return snapshot.size;
      }

      return snapshot.docs.where((doc) {
        final DateTime? createdAt = _readDateTime(doc.data());
        return createdAt != null && createdAt.isAfter(lastOpenedAt);
      }).length;
    } catch (e) {
      debugPrint('Error getting station booking notification count: $e');
      return 0;
    }
  }

  Future<void> _appendUserActivities(List<RecentActivityData> target) async {
    try {
      final snapshot = await _db.collection('users').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = _readDateTime(data);
        if (createdAt == null) continue;

        final String role = _readString(data, const ['role']) ?? 'user';
        final String name =
            _readString(data, const ['nama', 'name', 'displayName']) ?? 'User';
        final String email = _readString(data, const ['email']) ?? '';
        final String photoUrl =
            _readString(data, const ['foto', 'photoUrl', 'avatarUrl']) ?? '';

        if (role == 'user') {
          target.add(
            RecentActivityData(
              activityName: '$name - User Baru',
              timeText: _formatRelativeTime(createdAt),
              photoUrl: photoUrl.isEmpty ? null : photoUrl,
              occurredAt: createdAt,
            ),
          );
        } else if (role == 'admin') {
          target.add(
            RecentActivityData(
              activityName: '$name - Admin Baru',
              timeText: _formatRelativeTime(createdAt),
              photoUrl: photoUrl.isEmpty ? null : photoUrl,
              occurredAt: createdAt,
            ),
          );
        } else if (email.isNotEmpty) {
          target.add(
            RecentActivityData(
              activityName: '$name - $email',
              timeText: _formatRelativeTime(createdAt),
              photoUrl: photoUrl.isEmpty ? null : photoUrl,
              occurredAt: createdAt,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error appending user activities: $e');
    }
  }

  Future<void> _appendStationActivities(List<RecentActivityData> target) async {
    try {
      final snapshot = await _db.collection('stations').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = _readDateTime(data);
        if (createdAt == null) continue;

        final String stationName =
            _readString(data, const ['namaStation', 'stationName', 'name']) ??
            'Game Station';
        final String photoUrl = _firstStringFromList(data, const [
          'foto',
          'photos',
          'images',
        ]);

        target.add(
          RecentActivityData(
            activityName: '$stationName - Station Baru',
            timeText: _formatRelativeTime(createdAt),
            photoUrl: photoUrl,
            occurredAt: createdAt,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error appending station activities: $e');
    }
  }

  Future<void> _appendBookingActivities(List<RecentActivityData> target) async {
    try {
      final snapshot = await _db.collection('bookings').get();
      final unitsSnapshot = await _db.collection('units').get();

      final Map<String, Map<String, dynamic>> unitDocsByKey = {};
      for (final unitDoc in unitsSnapshot.docs) {
        final data = unitDoc.data();
        final unitName = data['namaUnit']?.toString() ?? unitDoc.id;
        final photoUrl = data['foto']?.toString() ?? '';
        final keys = <String>{unitDoc.id};

        for (final key in keys) {
          unitDocsByKey[key] = {'unitName': unitName, 'photoUrl': photoUrl};
        }
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = _readDateTime(data);
        if (createdAt == null) continue;

        final String unitName = data['namaUnit']?.toString() ?? 'Unit';
        final String stationName = data['namaStation']?.toString() ?? '';
        final String userName = data['namaUser']?.toString() ?? '';
        final String photoUrl = data['fotoUser']?.toString() ?? '';

        final String activityName;
        if (stationName.isNotEmpty) {
          activityName = '$stationName - $unitName';
        } else if (userName.isNotEmpty) {
          activityName = '$userName - $unitName';
        } else {
          activityName = unitName;
        }

        target.add(
          RecentActivityData(
            activityName: activityName,
            timeText: _formatRelativeTime(createdAt),
            photoUrl: photoUrl.isEmpty ? null : photoUrl,
            occurredAt: createdAt,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error appending booking activities: $e');
    }
  }

  Future<void> _appendReviewActivities(List<RecentActivityData> target) async {
    try {
      final snapshot = await _db.collection('reviews').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = _readDateTime(data);
        if (createdAt == null) continue;

        final String stationName =
            _readString(data, const ['stationName', 'namaStation']) ??
            'Station';
        final String unitName = data['namaUnit']?.toString() ?? 'Unit';
        final String userName =
            _readString(data, const ['namaUser', 'userName', 'nama', 'name']) ??
            'User';
        final String photoUrl =
            _readString(data, const [
              'userPhoto',
              'foto',
              'photoUrl',
              'avatarUrl',
            ]) ??
            '';

        target.add(
          RecentActivityData(
            activityName: '$userName - Review $stationName / $unitName',
            timeText: _formatRelativeTime(createdAt),
            photoUrl: photoUrl.isEmpty ? null : photoUrl,
            occurredAt: createdAt,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error appending review activities: $e');
    }
  }

  // =========================
  // UNIT ANALYTICS
  // =========================

  // Map QueryDocumentSnapshot list to a normalized list of maps with id/data
  // and sort by unit name.
  List<Map<String, dynamic>> mapUnitDocs(
    List<QueryDocumentSnapshot<Object?>> docs,
  ) {
    final entries = docs.map((doc) {
      return {'id': doc.id, 'data': doc.data() as Map<String, dynamic>};
    }).toList();

    entries.sort((a, b) {
      final aData = a['data'] as Map<String, dynamic>;
      final bData = b['data'] as Map<String, dynamic>;
      final String aName = aData['namaUnit']?.toString().toLowerCase() ?? '';
      final String bName = bData['namaUnit']?.toString().toLowerCase() ?? '';
      return aName.compareTo(bName);
    });

    return entries;
  }

  // Apply status filter to a list of mapped unit entries (each entry is
  // {'id':..., 'data': {...}}). Returns filtered list.
  List<Map<String, dynamic>> applyStatusFilterToMappedEntries(
    List<Map<String, dynamic>> mappedEntries,
    UnitStatusFilter selectedStatus,
  ) {
    if (selectedStatus == UnitStatusFilter.all) return mappedEntries;

    return mappedEntries
        .where((entry) {
          final data = entry['data'] as Map<String, dynamic>;
          final String status = readUnitStatus(data);
          if (selectedStatus == UnitStatusFilter.available) {
            return isAvailableStatus(status);
          }
          return isFullStatus(status);
        })
        .toList(growable: false);
  }

  // Lightweight analytics summary for a set of mapped entries.
  UnitOverview buildUnitOverviewFromMappedEntries(
    List<Map<String, dynamic>> mappedEntries,
  ) {
    var totalPc = 0;
    var totalRoom = 0;
    var available = 0;
    var full = 0;

    for (final entry in mappedEntries) {
      final data = entry['data'] as Map<String, dynamic>;
      final String type = readUnitType(data);
      final String status = readUnitStatus(data);

      if (isPcType(type)) {
        totalPc++;
      } else if (isRoomType(type)) {
        totalRoom++;
      }

      if (isFullStatus(status)) {
        full++;
      } else if (isAvailableStatus(status)) {
        available++;
      }
    }

    if (available == 0 && full == 0 && mappedEntries.isNotEmpty) {
      available = mappedEntries.length;
    } else if (available + full < mappedEntries.length) {
      available += mappedEntries.length - (available + full);
    }

    return UnitOverview(
      totalUnit: mappedEntries.length,
      totalPc: totalPc,
      totalRoom: totalRoom,
      full: full,
      available: available,
    );
  }

  // Statistik Unit
  Future<int> getTotalUnits() async {
    try {
      final snapshot = await _db.collection('units').get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting total units: $e');
      return 0;
    }
  }

  Future<int> getTotalUnitsByStation(String stationId) async {
    try {
      final snapshot = await _db
          .collection('units')
          .where('stationId', isEqualTo: stationId)
          .get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting total units by station: $e');
      return 0;
    }
  }

  Future<int> getStationTotalUnits(String stationId) async {
    return getTotalUnitsByStation(stationId);
  }

  Future<int> getTotalPC() async {
    return _getUnitCountByType(type: 'pc');
  }

  Future<int> getTotalPCByStation(String stationId) async {
    return _getUnitCountByType(stationId: stationId, type: 'pc');
  }

  Future<int> getTotalUnitsByType(String type) async {
    return _getUnitCountByType(type: type);
  }

  Future<int> getStationTotalUnitsByType(String stationId, String type) async {
    return _getUnitCountByType(stationId: stationId, type: type);
  }

  Future<UnitStatusSummary> getUnitStatusSummary() async {
    return _getUnitStatusSummary();
  }

  Future<UnitStatusSummary> getStationUnitStatusSummary(
    String stationId,
  ) async {
    return _getUnitStatusSummary(stationId: stationId);
  }

  Future<PopularUnitData?> getMostBookedUnit({
    String? stationId,
    String? type,
  }) async {
    try {
      final bookingsSnapshot = await _db.collection('bookings').get();
      if (bookingsSnapshot.docs.isEmpty) {
        return null;
      }

      final Map<String, int> bookingCounts = {};
      final Map<String, String> unitNamesByKey = {};

      final unitsSnapshot = await _db.collection('units').get();
      for (final unitDoc in unitsSnapshot.docs) {
        final data = unitDoc.data();
        if (stationId != null && stationId.isNotEmpty) {
          if (!_isStationLinkedDocument(data, stationId)) continue;
        }
        if (type != null && type.isNotEmpty) {
          final unitType = data['jenisUnit']?.toString();
          if (unitType != type) continue;
        }

        final unitName = data['namaUnit']?.toString() ?? unitDoc.id;
        unitNamesByKey[unitDoc.id] = unitName;
      }

      for (final doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final bookingStationId = data['stationId']?.toString();
        if (stationId != null &&
            stationId.isNotEmpty &&
            bookingStationId != stationId) {
          continue;
        }

        final unitId = data['unitId']?.toString();
        final resolvedKey = unitId ?? doc.id;
        if (type != null && type.isNotEmpty) {
          final unitType = data['jenisUnit']?.toString();
          if (unitType != type) continue;
        }

        bookingCounts[resolvedKey] = (bookingCounts[resolvedKey] ?? 0) + 1;
      }

      if (bookingCounts.isEmpty) {
        return null;
      }

      final topEntry = bookingCounts.entries.reduce((current, next) {
        return next.value > current.value ? next : current;
      });

      final unitName = unitNamesByKey[topEntry.key] ?? topEntry.key;
      return PopularUnitData(
        unitId: topEntry.key,
        unitName: unitName,
        bookingCount: topEntry.value,
      );
    } catch (e) {
      debugPrint('Error getting most booked unit: $e');
      return null;
    }
  }

  // =========================
  // REVENUE ANALYTICS
  // =========================

  // Membaca booking
  Future<int> getTotalPemasukan() async {
    try {
      final DateTime now = DateTime.now();
      final String monthStart =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      // Hari terakhir bulan: ambil hari pertama bulan depan lalu kurangi 1 hari
      final DateTime firstOfNextMonth = (now.month < 12)
          ? DateTime(now.year, now.month + 1, 1)
          : DateTime(now.year + 1, 1, 1);
      final DateTime lastDay = firstOfNextMonth.subtract(
        const Duration(days: 1),
      );
      final String monthEnd =
          '${lastDay.year}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';

      // Hanya booking yang sudah dibayar (statusPembayaran: paid)
      // dan tanggal bermain dalam bulan berjalan.
      final bookingSnapshot = await _db
          .collection('bookings')
          .where('statusPembayaran', isEqualTo: 'paid')
          .where('tanggalBooking', isGreaterThanOrEqualTo: monthStart)
          .where('tanggalBooking', isLessThanOrEqualTo: monthEnd)
          .get();

      var total = 0;
      for (final doc in bookingSnapshot.docs) {
        total += (doc.data()['totalHarga'] as num?)?.toInt() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('Error getting total pemasukan: $e');
      return 0;
    }
  }

  // =========================
  // RATING ANALYTICS
  // =========================

  Future<double> getRatingGameStation() async {
    try {
      final reviewsSnapshot = await _db.collection('reviews').get();
      if (reviewsSnapshot.docs.isNotEmpty) {
        double total = 0;
        var count = 0;

        for (final doc in reviewsSnapshot.docs) {
          final rating = _readDouble(doc.data(), const [
            'rating',
            'nilai',
            'score',
          ]);
          if (rating != null) {
            total += rating;
            count++;
          }
        }

        if (count > 0) {
          return total / count;
        }
      }

      final stationSnapshot = await _db.collection('stations').get();
      double total = 0;
      var count = 0;

      for (final doc in stationSnapshot.docs) {
        final rating = _readDouble(doc.data(), const ['rating']);
        if (rating != null) {
          total += rating;
          count++;
        }
      }

      return count == 0 ? 0 : total / count;
    } catch (e) {
      debugPrint('Error getting rating game station: $e');
      return 0.0;
    }
  }

  Future<double> getStationRatingGameStation(String stationId) async {
    try {
      final reviewsSnapshot = await _db.collection('reviews').get();
      double total = 0;
      var count = 0;

      for (final doc in reviewsSnapshot.docs) {
        final data = doc.data();
        if (!_isStationLinkedDocument(data, stationId)) {
          continue;
        }

        final rating = _readDouble(data, const ['rating', 'nilai', 'score']);
        if (rating != null) {
          total += rating;
          count++;
        }
      }

      if (count > 0) {
        return total / count;
      }

      return 0.0;
    } catch (e) {
      debugPrint('Error getting station rating game station: $e');
      return 0.0;
    }
  }

  // =========================
  // UNIT HELPERS (internal)
  // =========================

  Future<int> _getUnitCountByType({
    String? stationId,
    required String type,
  }) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('units')
          .where('jenisUnit', isEqualTo: type)
          .get();

      if (stationId != null && stationId.isNotEmpty) {
        snapshot = await _db
            .collection('units')
            .where('stationId', isEqualTo: stationId)
            .where('jenisUnit', isEqualTo: type)
            .get();
      }

      if (snapshot.docs.isNotEmpty) {
        return snapshot.size;
      }

      return 0;
    } catch (e) {
      debugPrint('Error getting unit count by type: $e');
      return 0;
    }
  }

  Future<UnitStatusSummary> _getUnitStatusSummary({String? stationId}) async {
    try {
      final unitsSnapshot = stationId == null || stationId.isEmpty
          ? await _db.collection('units').get()
          : await _db
                .collection('units')
                .where('stationId', isEqualTo: stationId)
                .get();

      if (unitsSnapshot.docs.isEmpty) {
        return const UnitStatusSummary(totalUnit: 0, full: 0, available: 0);
      }

      final int totalUnit = unitsSnapshot.size;
      var full = 0;
      var available = 0;

      for (final doc in unitsSnapshot.docs) {
        final data = doc.data();
        final String? status = _readString(data, const ['status']);

        if (status == null) {
          continue;
        }

        final normalized = status.toLowerCase();
        if (normalized.contains('digunakan') ||
            normalized.contains('full') ||
            normalized.contains('booked') ||
            normalized.contains('occupied')) {
          full++;
        } else if (normalized.contains('tersedia') ||
            normalized.contains('available') ||
            normalized.contains('ready') ||
            normalized.contains('free')) {
          available++;
        }
      }

      if (full == 0 && available == 0) {
        available = totalUnit;
      } else if (full + available < totalUnit) {
        available += totalUnit - (full + available);
      }

      return UnitStatusSummary(
        totalUnit: totalUnit,
        full: full,
        available: available,
      );
    } catch (e) {
      debugPrint('Error getting unit status summary: $e');
      return const UnitStatusSummary(totalUnit: 0, full: 0, available: 0);
    }
  }

  // Statistik Booking
  Future<int> getTotalBooking() async {
    try {
      final snapshot = await _db.collection('bookings').get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting total booking: $e');
      return 0;
    }
  }

  Future<int> getStationTotalBooking(String stationId) async {
    try {
      final snapshot = await _db
          .collection('bookings')
          .where('stationId', isEqualTo: stationId)
          .get();
      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting station total booking: $e');
      return 0;
    }
  }

  Future<int> getStationBookingHariIni(String stationId) async {
    try {
      final DateTime today = DateTime.now();
      // Format tanggalBooking sesuai yang disimpan di Firestore: 'YYYY-MM-DD'
      final String todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Filter langsung di Firestore — tanggalBooking adalah tanggal bermain
      // yang dipilih user, bukan tanggal dokumen booking dibuat (createdAt).
      final snapshot = await _db
          .collection('bookings')
          .where('stationId', isEqualTo: stationId)
          .where('tanggalBooking', isEqualTo: todayStr)
          .get();

      return snapshot.size;
    } catch (e) {
      debugPrint('Error getting station booking hari ini: $e');
      return 0;
    }
  }

  Future<int> getStationTotalPemasukan(String stationId) async {
    try {
      final doc = await _db.collection('stations').doc(stationId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('totalPemasukan')) {
          return (data['totalPemasukan'] as num).toInt();
        }
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting station total pemasukan: $e');
      return 0;
    }
  }

  // -------------------------
  // Helpers (used by dashboard logic)
  // -------------------------

  Future<Map<String, dynamic>?> getStationData(String stationId) async {
    final doc = await _db.collection('stations').doc(stationId).get();
    return doc.data();
  }

  bool _isStationLinkedDocument(Map<String, dynamic> data, String stationId) {
    for (final key in const [
      'stationId',
      'stationRef',
      'gameStationId',
      'gameStationRef',
      'station',
    ]) {
      final value = data[key];
      if (value is String && value == stationId) {
        return true;
      }
      if (value is DocumentReference && value.id == stationId) {
        return true;
      }
    }
    return false;
  }

  double? _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value != null) {
        return double.tryParse(value.toString());
      }
    }
    return null;
  }

  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _firstStringFromList(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first != null && first.toString().trim().isNotEmpty) {
          return first.toString().trim();
        }
      }
    }
    return '';
  }

  DateTime? _readDateTime(Map<String, dynamic> data) {
    for (final key in const [
      'createdAt',
      'timestamp',
      'date',
      'bookingDate',
      'updatedAt',
    ]) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
    }
    return null;
  }

  String _formatRelativeTime(DateTime timestamp) {
    final Duration difference = DateTime.now().difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}j lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}h lalu';
    }

    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

class UnitOverview {
  final int totalUnit;
  final int totalPc;
  final int totalRoom;
  final int full;
  final int available;

  const UnitOverview({
    required this.totalUnit,
    required this.totalPc,
    required this.totalRoom,
    required this.full,
    required this.available,
  });
}
