import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> sendNotification({
    required String userId,
    required String roleTarget,
    required String title,
    required String message,
    required String type,
    required String relatedBookingId,
  }) async {
    try {
      final notificationId = _db.collection('notifications').doc().id;
      final payload = {
        'userId': userId,
        'roleTarget': roleTarget,
        'title': title,
        'message': message,
        'type': type,
        'isRead': false,
        'relatedBookingId': relatedBookingId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('notifications').doc(notificationId).set(payload);
      debugPrint('NotificationService: Notifikasi berhasil dikirim: $title');
    } catch (e) {
      debugPrint('NotificationService error: Gagal mengirim notifikasi — $e');
    }
  }
}
