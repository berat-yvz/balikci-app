import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Ocean / fishing palette
  static const navy = Color(0xFF0A1628); // deep navy
  static const teal = Color(0xFF0D7E8A); // ocean teal
  static const sand = Color(0xFFC9A84C); // sandy gold
  static const foam = Color(0xFFF0F8FF); // foam white

  // App semantic colors (kept for existing code references)
  static const primary = teal;
  static const secondary = Color(0xFF1B5FAE); // deep sea blue
  static const accent = sand;
  static const primaryLight = Color(0xFFE1F5EE);
  static const background = Color(0xFF07101E); // slightly darker than navy
  static const surface = Color(0xFF0B1C33);
  static const dark = Color(0xFF06101D);
  static const muted = Color(0xFF8EA0B5);

  // Required named colors
  static const pinPublic = Color(0xFF0D7E8A);
  static const pinFriends = Color(0xFF2E6FB9);
  static const pinPrivate = Color(0xFF7B8794);
  static const pinVip = Color(0xFFC9A84C);

  static const rankAcemi = Color(0xFF7B8794);
  static const rankOltaKurdu = Color(0xFF2E6FB9);
  static const rankUsta = Color(0xFF0D7E8A);
  static const rankDenizReisi = Color(0xFFC9A84C);

  static const danger = Color(0xFFD64545);
  static const success = Color(0xFF2FBF71);
  static const warning = Color(0xFFF2C14E);
}

class AppTextStyles {
  AppTextStyles._();

  // Display: Poppins if available on platform; otherwise fallback.
  // (No new packages are added; this keeps build green.)
  static const String _displayFamily = 'Poppins';

  static const h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    fontFamily: _displayFamily,
  );
  static const h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    fontFamily: _displayFamily,
  );
  static const h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    fontFamily: _displayFamily,
  );
  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
  );
  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
}

ThemeData buildAppTheme() {
  final colorScheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.teal,
    onPrimary: AppColors.foam,
    secondary: AppColors.sand,
    onSecondary: AppColors.navy,
    error: AppColors.danger,
    onError: AppColors.foam,
    surface: AppColors.surface,
    onSurface: AppColors.foam,
    surfaceContainerHighest: Color(0xFF0E2542),
    onSurfaceVariant: Color(0xFFB8C7DA),
    outline: Color(0xFF24415F),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.foam,
    onInverseSurface: AppColors.navy,
    inversePrimary: AppColors.teal,
    tertiary: Color(0xFF2E6FB9),
    onTertiary: AppColors.foam,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: AppColors.foam,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.foam,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        fontFamily: 'Poppins',
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF0B1C33),
      elevation: 2.5,
      shadowColor: Colors.black,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // subtle wave-like radius
        side: BorderSide(
          color: const Color(0xFF173454).withValues(alpha: 0.9),
          width: 1,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.teal,
        foregroundColor: AppColors.foam,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF07182D),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: Color(0xFF9FB2C9)),
      labelStyle: const TextStyle(color: Color(0xFFB8C7DA)),
      prefixIconColor: const Color(0xFF9FB2C9),
      suffixIconColor: const Color(0xFF9FB2C9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF24415F).withValues(alpha: 0.9),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: const Color(0xFF24415F).withValues(alpha: 0.9),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.teal,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.navy,
      selectedItemColor: AppColors.teal,
      unselectedItemColor: Color(0xFF9FB2C9),
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w800,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w800,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
