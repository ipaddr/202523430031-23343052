import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gamezone/styles/app_colors.dart';

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

// Helper umum untuk membaca dan mengklasifikasikan data unit.
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

// Helper pemformatan.

String formatCurrency(int value) {
  if (value <= 0) return 'Rp 0';
  return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}

String formatCurrencyWithDash(int value) {
  if (value <= 0) return '-';
  return 'Rp ${value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}

String formatRupiah(int value) {
  final int absoluteValue = value.abs();
  final String formatted = absoluteValue.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  return value < 0 ? '-Rp $formatted' : 'Rp $formatted';
}

String formatDate(DateTime date) {
  final List<String> days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  final List<String> months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatDateFromDbString(String dbDateStr) {
  try {
    final parts = dbDateStr.split('-');
    if (parts.length < 3) return dbDateStr;
    final int year = int.parse(parts[0]);
    final int month = int.parse(parts[1]);
    final int day = int.parse(parts[2]);

    final List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agt',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '$day ${months[month - 1]} $year';
  } catch (_) {
    return dbDateStr;
  }
}

String formatDateToDb(DateTime date) {
  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String formatTimeOfDay(TimeOfDay time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatRelativeTime(DateTime timestamp) {
  final DateTime now = DateTime.now();
  final Duration difference = now.difference(timestamp);

  if (difference.inSeconds < 60) {
    return 'baru saja';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} menit lalu';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} jam lalu';
  } else {
    return '${difference.inDays} hari lalu';
  }
}

// Helper status.

Color bookingStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
    case 'checkin':
    case 'pending_confirmation':
      return AppColors.accentCyan;
    case 'pending':
      return AppColors.warningOrange;
    case 'completed':
      return AppColors.successGreen;
    case 'cancelled':
      return AppColors.errorRed;
    default:
      return AppColors.softGray;
  }
}

String bookingStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return 'DIKONFIRMASI';
    case 'pending_confirmation':
      return 'MENUNGGU KONFIRMASI';
    case 'pending':
      return 'MENUNGGU PEMBAYARAN';
    case 'checkin':
      return 'SEDANG BERMAIN';
    case 'completed':
      return 'SELESAI';
    case 'cancelled':
      return 'DIBATALKAN';
    default:
      return status.toUpperCase();
  }
}

Color unitStatusColor(String status) {
  final String lower = status.trim().toLowerCase();
  if (lower == 'digunakan') return AppColors.errorRed;
  if (lower == 'tersedia') return AppColors.successGreen;
  if (lower == 'perawatan') return AppColors.warningOrange;
  if (lower == 'tidak_aktif' || lower == 'tidak_tersedia' || lower == 'inactive') return AppColors.softGray;
  return AppColors.softGray;
}

String unitStatusLabel(String status) {
  final String lower = status.trim().toLowerCase();
  if (lower == 'digunakan') return 'Digunakan';
  if (lower == 'tersedia') return 'Tersedia';
  if (lower == 'perawatan') return 'Perawatan';
  if (lower == 'tidak_aktif' || lower == 'tidak_tersedia' || lower == 'inactive') return 'Tidak Tersedia';
  return status.isEmpty ? 'Unknown' : status;
}

String formatDurationFromTimes(String jamMulai, String jamSelesai) {
  try {
    final startParts = jamMulai.replaceAll('.', ':').split(':');
    final endParts = jamSelesai.replaceAll('.', ':').split(':');
    
    final int startHour = int.parse(startParts[0]);
    final int startMinute = int.parse(startParts[1]);
    final int endHour = int.parse(endParts[0]);
    final int endMinute = int.parse(endParts[1]);
    
    final int startMin = startHour * 60 + startMinute;
    final int endMin = endHour * 60 + endMinute;
    
    if (endMin <= startMin) return '0 Menit';
    final int diff = endMin - startMin;
    final int hours = diff ~/ 60;
    final int minutes = diff % 60;
    
    if (hours > 0 && minutes > 0) {
      return '$hours Jam $minutes Menit';
    } else if (hours > 0) {
      return '$hours Jam';
    } else {
      return '$minutes Menit';
    }
  } catch (_) {
    return '0 Menit';
  }
}

