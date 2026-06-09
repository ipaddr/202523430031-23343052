import 'package:flutter/material.dart';

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
        child: Icon(
          fallbackIcon,
          color: const Color(0xFF64748B),
          size: width * 0.5,
        ),
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

class CustomUserAvatar extends StatelessWidget {
  final String? photoUrl;
  final double size;
  final bool hasBorder;

  const CustomUserAvatar({
    super.key,
    required this.photoUrl,
    this.size = 40.0,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final Widget fallbackIcon = Center(
      child: Icon(
        Icons.person_rounded,
        color: const Color(0xFF94A3B8),
        size: size * 0.52,
      ),
    );

    final Widget imageWidget = (photoUrl != null && photoUrl!.trim().isNotEmpty)
        ? Image.network(
            photoUrl!.trim(),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallbackIcon,
          )
        : fallbackIcon;

    return Container(
      width: size,
      height: size,
      padding: hasBorder ? EdgeInsets.all(size * 0.04) : EdgeInsets.zero,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasBorder
            ? const LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFFC084FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: hasBorder
            ? [
                BoxShadow(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
                  blurRadius: size * 0.35,
                  offset: Offset(0, size * 0.15),
                ),
              ]
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0F172A),
          border: Border.all(
            color: const Color(0xFF22D3EE).withValues(alpha: 0.5),
            width: size * 0.03,
          ),
        ),
        child: ClipOval(child: imageWidget),
      ),
    );
  }
}
