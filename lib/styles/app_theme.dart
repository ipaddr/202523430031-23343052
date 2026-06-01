import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_textstyle.dart';

// Theme aplikasi berisi token ukuran, warna, dan komponen Material.
class AppTheme {
  // Konstanta Tema - Premium Gaming
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXL = 20;
  static const double radiusXXL = 28;

  static const double paddingXS = 4;
  static const double paddingS = 8;
  static const double paddingM = 12;
  static const double paddingL = 16;
  static const double paddingXL = 20;
  static const double paddingXXL = 24;
  static const double paddingXXXL = 32;

  // Definisi Bayangan - Glassmorphism + Gaming
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(color: Color(0x1A3B82F6), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> shadowMedium = [
    BoxShadow(color: Color(0x2A3B82F6), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> shadowLarge = [
    BoxShadow(color: Color(0x3A3B82F6), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> shadowGlassmorphism = [
    BoxShadow(color: Color(0x1522D3EE), blurRadius: 20, offset: Offset(0, 4)),
  ];

  // Konfigurasi Tema Utama
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.primaryDarkNavy,
      primaryColor: AppColors.accentBlue,

      // Tema AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.secondaryDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyle.h4.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),

      // Tema Tombol
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: paddingXL,
            vertical: paddingL,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          textStyle: AppTextStyle.buttonMedium,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentCyan,
          side: const BorderSide(color: AppColors.accentCyan, width: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: paddingXL,
            vertical: paddingL,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: AppTextStyle.buttonMedium,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentCyan,
          padding: const EdgeInsets.symmetric(
            horizontal: paddingL,
            vertical: paddingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: AppTextStyle.buttonMedium,
        ),
      ),

      // Tema Input Dekorasi
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondaryDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingL,
          vertical: paddingL,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
        ),
        hintStyle: AppTextStyle.body2.copyWith(color: const Color(0xFF94A3B8)),
        labelStyle: AppTextStyle.label.copyWith(color: AppColors.white),
        prefixIconColor: const Color(0xFF94A3B8),
        suffixIconColor: const Color(0xFF94A3B8),
      ),

      // Tema Kartu
      cardTheme: CardThemeData(
        color: AppColors.secondaryDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXL),
        ),
      ),

      // Tema Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.accentBlueTrans30,
        selectedColor: AppColors.accentBlue,
        labelStyle: AppTextStyle.body3.copyWith(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        side: const BorderSide(color: AppColors.accentBlue, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: paddingM,
          vertical: paddingS,
        ),
      ),

      // Tema Ikon
      iconTheme: const IconThemeData(color: AppColors.white, size: 24),

      // Tema Navigasi Bawah
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.secondaryDark,
        selectedItemColor: AppColors.accentBlue,
        unselectedItemColor: const Color(0xFF94A3B8),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTextStyle.caption1,
        unselectedLabelStyle: AppTextStyle.caption2,
      ),

      // Skema Warna
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentBlue,
        secondary: AppColors.accentCyan,
        surface: AppColors.secondaryDark,
        error: AppColors.errorRed,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.white,
        onError: AppColors.white,
      ),

      // Tema Pembatas
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
        space: paddingL,
      ),

      // Tema Teks
      textTheme: TextTheme(
        displayLarge: AppTextStyle.h1.copyWith(color: AppColors.white),
        displayMedium: AppTextStyle.h2.copyWith(color: AppColors.white),
        displaySmall: AppTextStyle.h3.copyWith(color: AppColors.white),
        headlineSmall: AppTextStyle.h4.copyWith(color: AppColors.white),
        titleLarge: AppTextStyle.body1.copyWith(color: AppColors.white),
        titleMedium: AppTextStyle.body2.copyWith(
          color: const Color(0xFFCBD5E1),
        ),
        titleSmall: AppTextStyle.body3.copyWith(color: const Color(0xFFCBD5E1)),
        bodyLarge: AppTextStyle.body1.copyWith(color: AppColors.white),
        bodyMedium: AppTextStyle.body2.copyWith(color: const Color(0xFFCBD5E1)),
        bodySmall: AppTextStyle.body3.copyWith(color: const Color(0xFFCBD5E1)),
        labelLarge: AppTextStyle.buttonMedium,
        labelMedium: AppTextStyle.caption1.copyWith(
          color: const Color(0xFF94A3B8),
        ),
        labelSmall: AppTextStyle.caption2.copyWith(
          color: const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
