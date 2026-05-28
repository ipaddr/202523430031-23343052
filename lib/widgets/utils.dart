import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget sederhana untuk memuat gambar dari URL dengan fallback
class CustomImageLoader extends StatelessWidget {
  final String? photoStr;
  final double width;
  final double height;
  final double radius;
  final IconData fallbackIcon;

  const CustomImageLoader({
    super.key,
    required this.photoStr,
    required this.width,
    required this.height,
    this.radius = 12.0,
    this.fallbackIcon = Icons.storefront_rounded,
  });

  @override
  Widget build(BuildContext context) {
    if (photoStr == null || photoStr!.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(fallbackIcon, color: const Color(0xFF64748B), size: width * 0.5),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFF1E293B),
        child: Image.network(
          photoStr!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.broken_image_rounded,
            color: const Color(0xFF64748B),
            size: width * 0.5,
          ),
        ),
      ),
    );
  }
}

/// Fungsi pembantu untuk membuka URL dokumen/tautan eksternal
Future<void> openExternalUrl(BuildContext context, String urlString) async {
  if (urlString.isEmpty) return;
  try {
    await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: const Color(0xFFEF4444), content: Text('Gagal membuka berkas: $e')),
      );
    }
  }
}
