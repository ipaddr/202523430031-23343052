import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  // System prompt: jawaban informatif Bahasa Indonesia, identitas AI GameZone, dan aturan rekomendasi terstruktur
  static const String _systemPrompt =
      'Anda adalah AI GameZone, asisten pintar khusus untuk Game Station yang membantu merekomendasikan game, memberikan tips gaming, dan informasi Game Station.\n\n'
      'ATURAN UTAMA RESPON:\n'
      '1. Selalu jawab dalam Bahasa Indonesia secara lengkap, mengalir natural, dan langsung ke inti (DILARANG memberikan jawaban satu frasa pendek/menggantung seperti "Untuk 4" atau "Untuk berdua").\n'
      '2. Panjang jawaban wajib berkisar antara 2 hingga 3 kalimat lengkap (sekitar 30 sampai 50 kata) agar tetap informatif dan utuh.\n'
      '3. Jika ditanya identitas seperti "Siapa kamu", "Kamu siapa", atau "Apa itu AI GameZone", jawab singkat: "Saya AI GameZone. Saya membantu memberikan rekomendasi game, tips gaming, dan informasi seputar Game Station."\n'
      '4. Jika meminta rekomendasi game, berikan wajib 2-3 game beserta alasan singkatnya dalam bentuk penjelasan mengalir. Contoh: "Overcooked 2, Pummel Party, dan Lethal Company cocok dimainkan 4 orang. Overcooked 2 cocok untuk kerja sama, sedangkan Pummel Party lebih santai dan seru bersama teman."';

  // Getter dinamis untuk membaca API Key dari file .env
  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Kirim satu pesan ke Gemini dan dapatkan respons singkat.
  /// Hanya mengirim pesan terakhir user — tidak ada riwayat, tidak ada konteks tambahan.
  Future<String> sendMessage(String userMessage) async {
    final String key = _apiKey;
    if (key.trim().isEmpty) {
      debugPrint('[AI] GEMINI_API_KEY kosong atau tidak terbaca dari .env');
      return 'AI sedang sibuk. Silakan coba lagi beberapa saat.';
    }

    if (userMessage.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint('[AI] Pesan kosong diabaikan');
      }
      return 'Pesan tidak boleh kosong.';
    }

    final Uri uri = Uri.parse('$_baseUrl?key=$key');

    final Map<String, dynamic> body = {
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userMessage.trim()},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': 800,
        'temperature': 0.6,
      },
    };

    final String obfuscatedKey = key.length > 8
        ? '${key.substring(0, 5)}...${key.substring(key.length - 3)}'
        : 'INVALID_KEY';

    if (kDebugMode) {
      debugPrint('[AI] Request model: $_model, endpoint: $_baseUrl?key=$obfuscatedKey');
    }

    try {
      final http.Response response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('[AI] Response status code: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        final String? text =
            data['candidates']?[0]?['content']?['parts']?[0]?['text']
                as String?;

        if (text != null && text.trim().isNotEmpty) {
          return _cleanMarkdown(text.trim());
        }
        return 'Terjadi kesalahan. Silakan coba kembali.';
      } else {
        debugPrint('[AI] Gemini API Error: HTTP ${response.statusCode} - ${response.body}');

        String status = '';
        String rawMessage = '';
        try {
          final Map<String, dynamic> errorData =
              jsonDecode(response.body) as Map<String, dynamic>;
          status = errorData['error']?['status']?.toString() ?? '';
          rawMessage = errorData['error']?['message']?.toString() ?? '';
        } catch (e) {
          debugPrint('[AI] Gagal decode JSON error response: $e');
        }

        final String normalizedMessage = rawMessage.toLowerCase();
        final String normalizedStatus = status.toUpperCase();

        if (response.statusCode == 429 ||
            normalizedStatus == 'RESOURCE_EXHAUSTED' ||
            normalizedMessage.contains('exhausted') ||
            normalizedMessage.contains('busy') ||
            normalizedMessage.contains('high demand') ||
            normalizedMessage.contains('overload')) {
          return 'AI sedang sibuk. Silakan coba lagi beberapa saat.';
        } else if (normalizedMessage.contains('quota') ||
            normalizedMessage.contains('limit') ||
            normalizedMessage.contains('exceeded') ||
            normalizedStatus == 'RESOURCE_EXHAUSTED') {
          return 'Kuota AI sedang penuh. Coba lagi nanti.';
        } else {
          return 'Terjadi kesalahan. Silakan coba kembali.';
        }
      }
    } on TimeoutException catch (e) {
      debugPrint('[AI] Request timed out: $e');
      return 'Permintaan terlalu lama. Coba lagi.';
    } on SocketException catch (e) {
      debugPrint('[AI] SocketException: $e');
      return 'Koneksi internet bermasalah.';
    } catch (e) {
      debugPrint('[AI] Exception: $e');
      final String errStr = e.toString().toLowerCase();
      if (errStr.contains('timeout')) {
        return 'Permintaan terlalu lama. Coba lagi.';
      } else if (errStr.contains('socket') ||
          errStr.contains('handshake') ||
          errStr.contains('connection') ||
          errStr.contains('failed host')) {
        return 'Koneksi internet bermasalah.';
      }
      return 'Terjadi kesalahan. Silakan coba kembali.';
    }
  }

  // Memberikan rekomendasi atau asisten game station menggunakan kecerdasan buatan
  Future<String> getAiRecommendation(String prompt) async {
    return sendMessage(prompt);
  }

  /// Membersihkan simbol-simbol markdown sederhana (seperti bold, italic, heading)
  /// agar jawaban yang ditampilkan di UI berupa teks biasa yang sangat rapi.
  String _cleanMarkdown(String text) {
    if (text.isEmpty) return text;

    return text
        // Hilangkan format bold (**text** atau __text__)
        .replaceAll('**', '')
        .replaceAll('__', '')
        // Hilangkan format heading (# heading, ## heading, ### heading) di awal baris
        .replaceAll(RegExp(r'^#+\s+', multiLine: true), '')
        // Hilangkan format italic tunggal (*text* atau _text_) secara aman
        .replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '')
        .replaceAll(RegExp(r'(?<!_)_(?!_)'), '')
        .trim();
  }
}
