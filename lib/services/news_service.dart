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
      if (kDebugMode) {
        debugPrint('[News] Cache hit: ${_cachedNews!.length} artikel');
      }
      return _cachedNews!;
    }

    // Audit: Verifikasi API Key
    final String apiKey = dotenv.env['GNEWS_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('[News] GNEWS_API_KEY kosong atau tidak terbaca dari .env');
      return [];
    }

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
    if (kDebugMode) {
      debugPrint('[News] Meminta berita: $safeUrl');
    }

    try {
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[News] Gagal mengambil berita: HTTP ${response.statusCode} - ${response.reasonPhrase}');
        if (kDebugMode) {
          debugPrint('[News] Response body: ${response.body}');
        }
        return [];
      }

      // Audit: Parsing
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (parseError) {
        debugPrint('[News] Gagal decode JSON: $parseError');
        return [];
      }

      final List<dynamic>? articles = data['articles'] as List<dynamic>?;

      if (articles == null) {
        debugPrint('[News] Field "articles" null atau tidak ditemukan');
        return [];
      }

      // Parsing tiap artikel
      final List<NewsModel> allNews = [];
      for (int i = 0; i < articles.length; i++) {
        try {
          final article = articles[i] as Map<String, dynamic>;
          final NewsModel model = NewsModel.fromJson(article);
          allNews.add(model);
        } catch (itemError) {
          debugPrint('[News] Gagal parsing artikel[$i]: $itemError');
          // Lewati artikel rusak, lanjutkan parsing sisanya
        }
      }

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

      return finalNewsList;
    } on TimeoutException catch (e) {
      debugPrint('[News] Request timed out: $e');
      return [];
    } catch (e, stackTrace) {
      debugPrint('[News] Error tidak terduga: $e');
      if (kDebugMode) {
        debugPrint('[News] StackTrace: $stackTrace');
      }
      return [];
    }
  }
}
