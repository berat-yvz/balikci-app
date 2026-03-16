import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF0F6E56); // teal
  static const primaryLight = Color(0xFFE1F5EE);
  static const secondary = Color(0xFF185FA5); // blue
  static const accent = Color(0xFFEF9F27); // amber
  static const danger = Color(0xFFA32D2D); // red
  static const dark = Color(0xFF1A1A1A);
  static const muted = Color(0xFF888780);
  static const background = Color(0xFFF5F5F3);

  // Pin renkleri
  static const pinPublic = Color(0xFF1D9E75);
  static const pinFriends = Color(0xFF378ADD);
  static const pinPrivate = Color(0xFF888780);
  static const pinVip = Color(0xFFEF9F27);
}

class AppTextStyles {
  AppTextStyles._();

  static const h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w700);
  static const h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w600);
  static const h3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
  static const body = TextStyle(fontSize: 15, fontWeight: FontWeight.w400);
  static const caption = TextStyle(fontSize: 13, fontWeight: FontWeight.w400);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      background: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}
