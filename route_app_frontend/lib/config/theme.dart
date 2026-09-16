import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Core palette ──────────────────────────────────────────
  static const Color primary     = Color(0xFF00E5A0);   // neon mint
  static const Color primaryDark = Color(0xFF00B07A);
  static const Color accent      = Color(0xFFFF6B35);   // vivid orange
  static const Color accentBlue  = Color(0xFF4FC3F7);   // sky electric
  static const Color neonCyan    = Color(0xFF00F5D4);   // bright cyan
  static const Color purple      = Color(0xFF9C5FFF);   // violet glow
  static const Color gold        = Color(0xFFFFD700);

  // ── Borders ───────────────────────────────────────────────
  static const Color border      = Color(0x3300E5A0);   // subtle neon mint border
  static const Color borderSubtle = Color(0x1FFFFFFF);  // subtle white border

  // ── Backgrounds ───────────────────────────────────────────
  static const Color bg          = Color(0xFF0A0D14);
  static const Color bgCard      = Color(0xFF111827);
  static const Color bgGlass     = Color(0x1AFFFFFF);
  static const Color surface     = Color(0xFF1A2232);
  static const Color surfaceAlt  = Color(0xFF1E293B);

  // ── Text ──────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF475569);

  // ── Status ────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFEF4444);
  static const Color info    = Color(0xFF3B82F6);


  // ── Admin palette (light, professional) ───────────────────
  static const Color adminPrimary  = Color(0xFF1B5E20);
  static const Color adminSurface  = Color(0xFFF8FAFC);

  // ── Gradient helpers ──────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00E5A0), Color(0xFF00B07A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF0A0D14), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF9C5FFF), Color(0xFF4FC3F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Glow shadows ──────────────────────────────────────────
  static List<BoxShadow> glowShadow(Color color, {double spread = 8}) => [
    BoxShadow(color: color.withOpacity(0.4), blurRadius: spread * 2, spreadRadius: spread / 2),
    BoxShadow(color: color.withOpacity(0.15), blurRadius: spread * 4, spreadRadius: spread),
  ];

  // ── Glass decoration ─────────────────────────────────────
  static BoxDecoration glassCard({double radius = 16, Color? border}) => BoxDecoration(
    color: bgGlass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border ?? primary.withOpacity(0.2), width: 1),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: -4),
    ],
  );

  // ── Driver dark theme ─────────────────────────────────────
  static ThemeData get driverTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: bgCard,
        error: error,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primary.withOpacity(0.15), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: bg,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: GoogleFonts.outfit(color: textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.outfit(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // ── Admin light theme ─────────────────────────────────────
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: adminPrimary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: adminSurface,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: adminPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: adminPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: adminPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
