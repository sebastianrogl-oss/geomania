import 'package:flutter/material.dart';

/// Der Hintergrundton der gesamten App — die einzige Stelle, an der er steht.
///
/// Vorher lag er dreifach vor: 0xFFF5F4F0 (Theme, Home, Lernpfad, Profil,
/// Einstellungen), 0xFFF5F5F0 (Quiz-Screens und Spiele) und 0xFFF5F0E8
/// (Portfolio, Rangliste). Die drei sahen fast gleich aus, ließen sich aber
/// nur einzeln ändern. Neue Hintergründe bitte über diese Konstante setzen,
/// nicht erneut hartcodieren.
///
/// Nicht zu verwechseln mit [AppTheme.card] (0xFFEAEAE5) — dem bewusst etwas
/// dunkleren Ton für Karten und Kacheln, der sich davon abheben soll.
///
/// Der Wert ist aus den Ergebnis-Videos gemessen, nicht geschätzt: rgb(244,
/// 245, 238) an den vier Eckpunkten des ersten Frames, übereinstimmend in allen
/// acht Dateien. Dadurch geht der Videorand ohne sichtbare Kante in den Screen
/// über. Wird der Videohintergrund je geändert, muss dieser Wert mitwandern.
const kHintergrund = Color(0xFFF4F5EE);

class AppTheme {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color bg          = kHintergrund;
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
