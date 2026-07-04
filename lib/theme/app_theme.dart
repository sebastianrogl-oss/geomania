import 'package:flutter/material.dart';

class AppTheme {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color bg          = Color(0xFFF5F4F0);
  static const Color card        = Color(0xFFEAEAE5);
  static const Color accentGreen = Color(0xFF4A9E4A);
  static const Color gold        = Color(0xFFF9A825);
  static const Color purple      = Color(0xFF7C3AED);
  static const Color blue        = Color(0xFF4A90D9);
  static const Color textDark    = Color(0xFF1A1A1A);
  static const Color textMid     = Color(0xFF888888);

  // Legacy aliases used by other screens
  static const Color darkGreen  = Color(0xFF1B5E20);
  static const Color midGreen   = Color(0xFF2E7D32);
  static const Color skyBlue    = Color(0xFF87CEEB);
  static const Color creamWhite = bg;

  // ── Theme ──────────────────────────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: darkGreen,
      primary: accentGreen,
      secondary: blue,
    ),
  );
}
