import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF000000); // Black
  static const Color accent = Color(0xFFFF8C00); // Orange
  static const Color background = Color(0xFFF7F7F7); // Soft white

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,

    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      primary: primary,
      secondary: accent,
      // `background` is deprecated and no widget reads it; the page colour
      // comes from scaffoldBackgroundColor above.
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    dividerTheme: DividerThemeData(
      thickness: 1,
      color: Colors.grey.shade200,
    ),


    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.bold),
      bodyMedium: TextStyle(fontSize: 15),
    ),
  );
}
