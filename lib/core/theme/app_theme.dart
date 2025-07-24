import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryGreen = Color(0xFF2ECC71);
  static const Color darkGreen = Color(0xFF27AE60);
  static const Color lightGreen = Color(0xFFE8F8F5);

  // Neutral Colors
  static const Color darkGray = Color(0xFF2C3E50);
  static const Color mediumGray = Color(0xFF7F8C8D);
  static const Color lightGray = Color(0xFFECF0F1);
  static const Color white = Color(0xFFFFFFFF);

  // Accent Colors
  static const Color orange = Color(0xFFE67E22);
  static const Color red = Color(0xFFE74C3C);
  static const Color blue = Color(0xFF3498DB);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: white,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// Utility classes for consistent spacing and styling
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppTheme.darkGray,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppTheme.darkGray,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppTheme.darkGray,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 14,
    color: AppTheme.mediumGray,
  );
}
