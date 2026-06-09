import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/news_model.dart';

class NewsService {
  // Cache positif-only: hanya tersimpan jika berita berhasil di-fetch (> 0 artikel).
  // Cache [] (kosong karena error/API limit) TIDAK disimpan agar retry tetap bisa berjalan.
  static List<NewsModel>? _cachedNews;

  // Mengambil daftar berita terbaru seputar dunia gaming
  Future<List<NewsModel>> getLatestGamingNews() async {
    // Gunakan cache hanya jika terisi (hasil fetch sukses sebelumnya)
    if (_cachedNews != null && _cachedNews!.isNotEmpty) {
      debugPrint('================ GNEWS CACHE HIT ================');
      debugPrint('Total Berita (Cache): ${_cachedNews!.length}');
      debugPrint('==================================================');
      return _cachedNews!;
    }

    // Audit: Verifikasi API Key
    final String apiKey = dotenv.env['GNEWS_API_KEY'] ?? '';
    final bool keyLoaded = apiKey.isNotEmpty;
    debugPrint('================ GNEWS API KEY CHECK ================');
    debugPrint('GNEWS_API_KEY Loaded: ${keyLoaded ? "Yes" : "No"}');
    if (!keyLoaded) {
      debugPrint('ERROR: GNEWS_API_KEY kosong atau tidak terbaca dari .env');
      debugPrint('======================================================');
      return [];
    }
    debugPrint('======================================================');

    const String query =
        'videogame OR "video game" OR gaming OR esports OR "game release" OR '
        '"game update" OR steam OR playstation OR xbox OR nintendo';

    final Uri uri = Uri.parse('https://gnews.io/api/v4/search').replace(
      queryParameters: {
        'q': query,
        'lang': 'en',
        'max': '10',
        'apikey': apiKey,
      },
    );

    // Audit: Log Request
    // Tampilkan URL tanpa API key agar aman di log
    final String safeUrl = uri.toString().replaceAll(apiKey, '***HIDDEN***');
    debugPrint('================ GNEWS REQUEST ================');
    debugPrint('Request URL: $safeUrl');
    debugPrint(
      'Query Params: q=$query | lang=en | max=10 | apikey=***HIDDEN***',
    );
    debugPrint('================================================');

    try {
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      // Audit: Log Response
      debugPrint('================ GNEWS RESPONSE ================');
      debugPrint('Status Code: ${response.statusCode}');

      switch (response.statusCode) {
        case 200:
          debugPrint('Respons Diterima: Ya');
          break;
        case 401:
          debugPrint(
            'Respons Diterima: Ya — 401 Unauthorized (API key tidak valid)',
          );
          debugPrint('Body: ${response.body}');
          debugPrint('=================================================');
          return [];
        case 403:
          debugPrint('Respons Diterima: Ya — 403 Forbidden (akses ditolak)');
          debugPrint('Body: ${response.body}');
          debugPrint('=================================================');
          return [];
        case 429:
          debugPrint(
            'Respons Diterima: Ya — 429 Too Many Requests (kuota habis)',
          );
          debugPrint('Body: ${response.body}');
          debugPrint('=================================================');
          return [];
        case 500:
          debugPrint('Respons Diterima: Ya — 500 Internal Server Error');
          debugPrint('Body: ${response.body}');
          debugPrint('=================================================');
          return [];
        default:
          debugPrint(
            'Respons Diterima: Ya — HTTP ${response.statusCode} (tidak dikenal)',
          );
          debugPrint('Body: ${response.body}');
          debugPrint('=================================================');
          return [];
      }

      // Audit: Parsing
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (parseError) {
        debugPrint('Parsing Berhasil: Tidak');
        debugPrint('JSON decode error: $parseError');
        debugPrint(
          'Raw body (200 karakter pertama): ${response.body.substring(0, response.body.length.clamp(0, 200))}',
        );
        debugPrint('=================================================');
        return [];
      }

      final List<dynamic>? articles = data['articles'] as List<dynamic>?;

      if (articles == null) {
        debugPrint(
          'Parsing Berhasil: Tidak — field "articles" null atau tidak ada',
        );
        debugPrint('Keys tersedia di response: ${data.keys.toList()}');
        debugPrint('=================================================');
        return [];
      }

      debugPrint('=================================================');

      // Parsing tiap artikel
      final List<NewsModel> allNews = [];
      for (int i = 0; i < articles.length; i++) {
        try {
          final article = articles[i] as Map<String, dynamic>;
          final NewsModel model = NewsModel.fromJson(article);
          allNews.add(model);
        } catch (itemError) {
          debugPrint('Parsing artikel[$i] gagal: $itemError');
          // Lewati artikel rusak, lanjutkan parsing sisanya
        }
      }

      debugPrint('Parsing Berhasil: Ya');
      debugPrint('GNews Artikel Diterima: ${allNews.length} artikel.');

      // Post-filtering: hanya berita gaming murni
      final List<String> includeKeywords = [
        'game',
        'gaming',
        'videogame',
        'esports',
        'steam',
        'playstation',
        'xbox',
        'nintendo',
      ];
      final List<String> excludeKeywords = [
        'crypto',
        'saham',
        'politik',
        'ekonomi',
        'politics',
        'economy',
        'cryptocurrency',
        'bitcoin',
      ];
      final List<String> techExcludeKeywords = [
        'ai',
        'smartphone',
        'laptop',
        'gpu',
        'cpu',
        'artificial intelligence',
      ];

      final List<NewsModel> filteredNews = allNews.where((news) {
        final String titleLower = news.title.toLowerCase();
        final String descLower = news.description.toLowerCase();

        final bool hasInclude = includeKeywords.any(
          (kw) => titleLower.contains(kw) || descLower.contains(kw),
        );
        if (!hasInclude) return false;

        final bool hasAbsoluteExclude = excludeKeywords.any(
          (kw) => titleLower.contains(kw) || descLower.contains(kw),
        );
        if (hasAbsoluteExclude) return false;

        final bool hasTechExclude = techExcludeKeywords.any(
          (kw) => titleLower.contains(kw) || descLower.contains(kw),
        );
        if (hasTechExclude) {
          final List<String> gameIndicators = [
            'game',
            'gaming',
            'esports',
            'playstation',
            'xbox',
            'nintendo',
            'steam',
          ];
          final bool hasGameContext = gameIndicators.any(
            (kw) => titleLower.contains(kw) || descLower.contains(kw),
          );
          if (!hasGameContext) return false;
        }

        return true;
      }).toList();

      // Urutkan: artikel dengan gambar muncul lebih dulu.
      // Publisher seperti PhoneArena memblokir hotlinking — artikel mereka
      // punya field image tapi gambar gagal dimuat dari luar domain.
      // Dengan sort ini, artikel yang kemungkinan besar punya gambar tampil
      // di slide pertama, bukan di-hide oleh artikel tanpa gambar.
      final List<NewsModel> finalNewsList = filteredNews.take(5).toList()
        ..sort((a, b) {
          // Artikel dengan image non-kosong naik ke atas
          final int aHas = a.image.isNotEmpty ? 0 : 1;
          final int bHas = b.image.isNotEmpty ? 0 : 1;
          return aHas.compareTo(bHas);
        });

      // Simpan cache HANYA jika ada berita — cache kosong tidak disimpan
      // agar cold start berikutnya bisa retry ke API.
      if (finalNewsList.isNotEmpty) {
        _cachedNews = finalNewsList;
      }
      debugPrint('================ GNEWS FILTER SUCCESS ================');
      debugPrint('Total Raw Received       : ${allNews.length}');
      debugPrint(
        'Non-Gaming Filtered Out  : ${allNews.length - filteredNews.length}',
      );
      debugPrint('Final Gaming News Count  : ${finalNewsList.length}');
      debugPrint(
        'Cache Diperbarui         : ${finalNewsList.isNotEmpty ? "Ya" : "Tidak (list kosong, tidak di-cache)"}',
      );
      debugPrint('======================================================');

      return finalNewsList;
    } on TimeoutException catch (e) {
      debugPrint('================ GNEWS TIMEOUT ================');
      debugPrint('Request timed out (>15 detik): $e');
      debugPrint('Respons Diterima: Tidak');
      debugPrint('Parsing Berhasil: Tidak');
      debugPrint('================================================');
      return [];
    } catch (e, stackTrace) {
      // Log lengkap — jangan silent catch
      debugPrint('================ GNEWS EXCEPTION ================');
      debugPrint('Exception: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('Respons Diterima: Tidak');
      debugPrint('Parsing Berhasil: Tidak');
      debugPrint('==================================================');
      return [];
    }
  }
}
