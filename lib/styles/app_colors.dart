import 'package:flutter/material.dart';

class AppColors {
  // Warna Utama Gelap
  static const Color primaryDarkNavy = Color(0xFF0F172A);
  static const Color secondaryDark = Color(0xFF1E293B);

  // Aksen
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentCyan = Color(0xFF22D3EE);

  // Latar Belakang & Teks
  static const Color background = Color(0xFFF8FAFC);
  static const Color softGray = Color(0xFFCBD5E1);

  // Warna Tambahan
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color darkText = Color(0xFF0F172A);
  static const Color lightText = Color(0xFF64748B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color infoBlue = Color(0xFF0EA5E9);

  // Varian Transparan
  static const Color accentBlueTrans30 = Color(0x4D3B82F6);
  static const Color accentCyanTrans30 = Color(0x4D22D3EE);
  static const Color primaryDarkTrans20 = Color(0x330F172A);

  // Gradasi
  static const LinearGradient gradientBlueToBlack = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBlue, primaryDarkNavy],
  );

  static const LinearGradient gradientCyanToBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentCyan, accentBlue],
  );

  static const LinearGradient gradientDarkToSecondary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDarkNavy, secondaryDark],
  );
}
