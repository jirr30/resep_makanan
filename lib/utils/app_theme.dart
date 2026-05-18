import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary    = Color(0xFFFF6B35);
  static const Color secondary  = Color(0xFF2D3436);
  static const Color accent     = Color(0xFFFDCB6E);

  // Light
  static const Color bgLight        = Color(0xFFF8F9FA);
  static const Color cardLight      = Colors.white;
  static const Color textPrimary    = Color(0xFF2D3436);
  static const Color textSecondary  = Color(0xFF636E72);
  static const Color borderLight    = Color(0xFFDFE6E9);

  // Dark
  static const Color bgDark         = Color(0xFF121212);
  static const Color cardDark       = Color(0xFF1E1E1E);
  static const Color surfaceDark    = Color(0xFF252525);
  static const Color textPrimaryDark   = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB2BEC3);
  static const Color borderDark     = Color(0xFF3D3D3D);

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: primary,
        primary: primary,
        surface: isDark ? cardDark : cardLight,
      ),
      scaffoldBackgroundColor: isDark ? bgDark : bgLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: isDark ? cardDark : cardLight,
        elevation: isDark ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark ? const BorderSide(color: borderDark) : BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceDark : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? borderDark : borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(color: isDark ? textSecondaryDark : textSecondary),
        hintStyle: TextStyle(color: isDark ? textSecondaryDark : textSecondary),
      ),
      dividerTheme: DividerThemeData(color: isDark ? borderDark : borderLight),
      listTileTheme: ListTileThemeData(
        textColor: isDark ? textPrimaryDark : textPrimary,
        iconColor: isDark ? textSecondaryDark : textSecondary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary.withValues(alpha: 0.4) : null),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? cardDark : Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: isDark ? textSecondaryDark : textSecondary,
        elevation: 8,
      ),
      tabBarTheme: TabBarTheme(
        labelColor: primary,
        unselectedLabelColor: isDark ? textSecondaryDark : textSecondary,
        indicatorColor: primary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? surfaceDark : secondary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? surfaceDark : bgLight,
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(color: isDark ? textPrimaryDark : textPrimary),
        side: BorderSide(color: isDark ? borderDark : borderLight),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: isDark ? cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? cardDark : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      iconTheme: IconThemeData(color: isDark ? textSecondaryDark : textSecondary),
      textTheme: TextTheme(
        bodyLarge:  TextStyle(color: isDark ? textPrimaryDark : textPrimary),
        bodyMedium: TextStyle(color: isDark ? textPrimaryDark : textPrimary),
        titleLarge: TextStyle(color: isDark ? textPrimaryDark : textPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }
}
