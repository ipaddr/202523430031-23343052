import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class XenditService {
  String get _secretKey => dotenv.env['XENDIT_SECRET_KEY'] ?? '';

  String _getAuthHeader() {
    final String key = _secretKey;
    // Xendit menggunakan Basic Auth dengan key: sebagai username dan password dikosongkan.
    return 'Basic ${base64Encode(utf8.encode('$key:'))}';
  }

  /// Membuat invoice Xendit baru untuk booking yang diberikan.
  /// Mengembalikan Map yang berisi 'invoice_url' dan 'id' (invoice ID).
  Future<Map<String, String>?> createInvoice({
    required String bookingId,
    required int amount,
    required String payerEmail,
    required String stationName,
  }) async {
    if (_secretKey.isEmpty) {
      debugPrint('[Xendit] XENDIT_SECRET_KEY belum diatur di .env');
      return null;
    }

    final url = Uri.parse('https://api.xendit.co/v2/invoices');
    final String auth = _getAuthHeader();

    final body = jsonEncode({
      'external_id': 'booking_$bookingId',
      'amount': amount,
      'payer_email': payerEmail.isNotEmpty ? payerEmail : 'gamer@gamezone.com',
      'description': 'Pembayaran Booking Game Station - $stationName',
      'invoice_duration': 900, // 15 menit, sesuaikan dengan limit booking
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': auth,
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final String invoiceUrl = data['invoice_url']?.toString() ?? '';
        final String invoiceId = data['id']?.toString() ?? '';
        return {
          'invoice_url': invoiceUrl,
          'invoice_id': invoiceId,
        };
      } else {
        debugPrint('[Xendit] Gagal membuat invoice: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[Xendit] Error createInvoice: $e');
      return null;
    }
  }

  /// Memeriksa status invoice terkini di Xendit berdasarkan invoice ID.
  /// Mengembalikan String status ('PENDING', 'PAID', 'SETTLED', 'EXPIRED').
  Future<String?> checkInvoiceStatus(String invoiceId) async {
    if (_secretKey.isEmpty || invoiceId.isEmpty) return null;

    final url = Uri.parse('https://api.xendit.co/v2/invoices/$invoiceId');
    final String auth = _getAuthHeader();

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': auth,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['status']?.toString();
      } else {
        debugPrint('[Xendit] Gagal cek status: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[Xendit] Error checkInvoiceStatus: $e');
      return null;
    }
  }
}
