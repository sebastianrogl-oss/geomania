import 'package:shared_preferences/shared_preferences.dart';

import '../data/lernpfad_data.dart';

/// Merkt sich, welche Erklärungen ein Spieler schon gesehen hat.
///
/// Alles rein lokal und ohne Konto-Bezug: eine Erklärung, die auf einem Gerät
/// gezeigt wurde, muss auf einem anderen wieder erscheinen — dort ist sie ja
/// genauso neu.
///
/// Bewusst ein eigener Dienst statt Schlüsseln in [EinstellungenService]:
/// diese Werte sind kein Einstellungs-, sondern ein Fortschrittszustand, und
/// der Debug-Bereich soll sie in einem Rutsch zurücksetzen können, ohne
/// Ton- oder Vibrationseinstellungen mitzunehmen.
class OnboardingService {
  /// Willkommens-Screen nach der Namensabfrage.
  static const _kWillkommen = 'onboarding_willkommen';

  /// Ein Schlüssel je Modus, dessen Anleitung sich beim ersten Vorkommen
  /// selbst öffnet — angehängt wird der Enum-Name.
  static const _kModusPrefix = 'onboarding_modus_';

  // ── Willkommen ─────────────────────────────────────────────────────────────

  static Future<bool> willkommenGezeigt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kWillkommen) ?? false;
  }

  static Future<void> merkeWillkommen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWillkommen, true);
  }

  // ── Modus-Anleitungen ──────────────────────────────────────────────────────

  static Future<bool> modusErklaerungGezeigt(LernModus modus) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kModusPrefix${modus.name}') ?? false;
  }

  static Future<void> merkeModusErklaerung(LernModus modus) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kModusPrefix${modus.name}', true);
  }

  // ── Debug ──────────────────────────────────────────────────────────────────

  /// Setzt ALLE Onboarding-Merker zurück, damit sich der Ablauf mehrfach
  /// durchspielen lässt.
  ///
  /// Rührt den Spielfortschritt nicht an: hier fallen nur die Merker, welche
  /// Erklärung schon einmal auf dem Schirm stand.
  static Future<void> debugZuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kWillkommen);
    for (final modus in LernModus.values) {
      await prefs.remove('$_kModusPrefix${modus.name}');
    }
  }
}
