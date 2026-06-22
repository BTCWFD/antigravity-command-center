import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colores principales
  static const Color background = Color(0xFF070A13);
  static const Color surface = Color(0xFF0F1424);
  static const Color surfaceOverlay = Color(0x1AFFFFFF);
  static const Color primary = Color(0xFF3B82F6); // Azul cobalto
  static const Color accent = Color(0xFF00E6FF); // Cyan brillante
  static const Color terminalBg = Color(0xFF03050B);
  
  // Colores de estado
  static const Color success = Color(0xFF10B981); // Esmeralda
  static const Color warning = Color(0xFFF59E0B); // Ámbar
  static const Color error = Color(0xFFEF4444); // Carmesí
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        background: background,
        surface: surface,
        primary: primary,
        secondary: accent,
        error: error,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.copyWith(
          bodyLarge: const TextStyle(color: textPrimary, fontSize: 16),
          bodyMedium: const TextStyle(color: textSecondary, fontSize: 14),
          titleLarge: const TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          headlineMedium: const TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E293B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  // Estilo de efecto Glassmorphism
  static BoxDecoration glassDecoration({
    Color color = const Color(0x0DFFFFFF),
    double borderRadius = 16,
    double borderWidth = 1,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
        width: borderWidth,
      ),
    );
  }
}
