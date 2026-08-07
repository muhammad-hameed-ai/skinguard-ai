// ═══════════════════════════════════════════════════════════════
//  Design System — palette, typography, risk display
//
//  §2.1  Palette: 13 named colours
//  §2.2  Typography: Archivo (display), Inter (copy), IBM Plex Mono (values)
//  §2.4  Risk: colour + word + glyph (8% male CVD accommodation)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── §2.1 Palette ──────────────────────────────────────────
  static const Color ink        = Color(0xFF0C1512);
  static const Color film       = Color(0xFFEDF1EF);
  static const Color filmSoft   = Color(0xFFF6F8F7);
  static const Color paper      = Color(0xFFFFFFFF);
  static const Color slate      = Color(0xFF5A6B66);
  static const Color slateSoft  = Color(0xFF8A9995);
  static const Color line       = Color(0xFFD6DEDB);
  static const Color aperture   = Color(0xFF0B6E63);
  static const Color apertureLt = Color(0xFF12958A);
  static const Color signal     = Color(0xFFC4703C);
  static const Color clear      = Color(0xFF2D6A4F);
  static const Color watch      = Color(0xFFB87333);
  static const Color refer      = Color(0xFF9B2226);

  // ── §2.2 Typography ───────────────────────────────────────

  /// Display / screen titles / result figures — Archivo 700/800
  static TextStyle display({
    double size = 32,
    FontWeight weight = FontWeight.w700,
    Color color = ink,
  }) => GoogleFonts.archivo(
    fontSize: size,
    fontWeight: weight,
    color: color,
  );

  /// All interface copy — Inter 400/500/600
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double? height,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  /// MEASURED VALUES ONLY — IBM Plex Mono 400/500
  /// Percentages, thresholds, scan IDs, timestamps, milliseconds.
  /// If a human wrote it, use Inter. This makes the app read as
  /// an instrument rather than a brochure.
  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = ink,
  }) => GoogleFonts.ibmPlexMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
  );

  // ── §2.4 Risk display ─────────────────────────────────────
  // Never colour alone. Always colour + word + glyph.

  static const Map<String, _RiskVisual> riskVisuals = {
    'low':       _RiskVisual('●', 'Low risk',       clear),
    'moderate':  _RiskVisual('◈', 'Needs review',   watch),
    'uncertain': _RiskVisual('◈', 'Not confident',  watch),
    'high':      _RiskVisual('◆', 'See a doctor',   refer),
    'veryHigh':  _RiskVisual('◆', 'See a doctor',   refer),
  };

  /// Full Material theme for the app.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: aperture,
      scaffoldBackgroundColor: film,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: film,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ink),
        titleTextStyle: GoogleFonts.archivo(
          color: ink, fontSize: 20, fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: aperture,
          foregroundColor: paper,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: aperture,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line, width: 0.5),
        ),
        color: paper,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: filmSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: aperture, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(color: slate),
        hintStyle: GoogleFonts.inter(color: slateSoft),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: paper,
        selectedItemColor: aperture,
        unselectedItemColor: slateSoft,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class _RiskVisual {
  final String glyph;
  final String label;
  final Color color;
  const _RiskVisual(this.glyph, this.label, this.color);
}

/// Extension to easily get risk visuals from a risk band name.
extension RiskVisualExt on String {
  String get riskGlyph => AppTheme.riskVisuals[this]?.glyph ?? '●';
  String get riskLabel => AppTheme.riskVisuals[this]?.label ?? this;
  Color  get riskColor => AppTheme.riskVisuals[this]?.color ?? AppTheme.slate;
}
