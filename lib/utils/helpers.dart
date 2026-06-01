import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Membuka URL eksternal dengan fallback pesan jika gagal.
Future<void> openExternalUrl(BuildContext context, String urlString) async {
  if (urlString.isEmpty) return;
  try {
    await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Gagal membuka berkas: $e'),
        ),
      );
    }
  }
}

// General helpers for reading and classifying unit data.
String? readFirstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final dynamic value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return null;
}

String readUnitType(Map<String, dynamic> data) {
  return readFirstString(data, const ['jenisUnit']) ?? '';
}

String readUnitStatus(Map<String, dynamic> data) {
  return readFirstString(data, const ['status']) ?? 'tersedia';
}

bool isPcType(String type) => type.toLowerCase().contains('pc');

bool isRoomType(String type) {
  final String lower = type.toLowerCase();
  return lower.contains('room') || lower.contains('rme');
}

bool isAvailableStatus(String status) {
  final String lower = status.toLowerCase();
  return lower.contains('tersedia') ||
      lower.contains('available') ||
      lower.contains('ready') ||
      lower.contains('free');
}

bool isFullStatus(String status) {
  final String lower = status.toLowerCase();
  return lower.contains('digunakan') ||
      lower.contains('full') ||
      lower.contains('booked') ||
      lower.contains('occupied');
}
