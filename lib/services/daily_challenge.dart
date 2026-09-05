import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'ad_service.dart';
import 'challenge_rekord_service.dart';
import 'fortschritt_service.dart';

class DailyChallenge {
  /// Anzahl aller Tages-Challenges (Preis schätzen, Higher-or-Lower,
  /// Ranking, Portfolio) — Grundlage für "alle erledigt".
  static const int anzahlChallenges = 4;

  static String _key() {
    final n = DateTime.now();
    return 'daily_${n.year}_${n.month.toString().padLeft(2, '0')}_${n.day.toString().padLeft(2, '0')}';
  }

  static Future<Set<String>> completedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key()) ?? []).toSet();
  }

  /// Einziger Aufrufpunkt für alle 4 Challenges -> hier wird zentral auch
  /// der Serien-Zähler, die Spieltage-Historie für den 7-Tage-Streifen und
  /// der "Anzahl gespielt"-Zähler aktualisiert, statt jeden der 5 Aufrufer-
  /// Screens einzeln anzufassen.
  static Future<void> markDone(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key();
    final done = (prefs.getStringList(key) ?? []).toSet()..add(id);
    await prefs.setStringList(key, done.toList());
    final streak = await ChallengeRekordService.streakAktualisieren(id);
    await ChallengeRekordService.besteStreakAktualisieren(id, streak);
    await ChallengeRekordService.spieltagVermerken(id);
    await ChallengeRekordService.spielGezaehlt(id);

    // ── Der App-Streak zählt JEDE Aktivität ─────────────────────────────
    //
    // Die Flamme steht für "heute gespielt", nicht für "heute eine Station
    // im Lernpfad gespielt". Wer nur eine Tages-Challenge macht, hat den Tag
    // genauso bespielt — bekam bis hierher aber keinen Streak-Tag, weil der
    // App-Streak ausschliesslich am Stationsabschluss hing.
    //
    // DIESELBE Funktion wie dort (station_quiz_screen -> streakErhoehenUnd-
    // Feiern -> FortschrittService.streakAktualisieren), keine zweite
    // Rechnung: Ein nachgebauter Tagesvergleich wäre die Stelle, an der die
    // beiden Wege irgendwann auseinanderlaufen.
    //
    // EIN TAG ZÄHLT NUR EINMAL, und das regelt die Funktion selbst: Liegt
    // die letzte Aktivität am selben Kalendertag, kehrt sie unverändert
    // zurück (`if (diff == 0)`). Wer Station UND Challenge an einem Tag
    // spielt, bekommt einen Streak-Tag, nicht zwei.
    //
    // Die Serien-Zähler der einzelnen Challenges oben bleiben davon
    // unberührt — das sind eigene Werte mit eigener Bedeutung.
    await FortschrittService.streakAktualisieren();

    // Interstitial nach der zweiten und nach der letzten Tages-Challenge
    // des Tages (der AdService entscheidet selbst, ob die Schwelle heute
    // schon bedient wurde). BEWUSST NICHT awaited — genau wie beim
    // Stationsabschluss: die Werbung ist rein optional und darf die
    // Auflösung der Challenge niemals verzögern oder blockieren. Fehler
    // fängt der AdService intern ab.
    unawaited(AdService.pruefeUndZeigeInterstitialNachChallenge(
      done.length,
      anzahlChallenges,
    ));
  }

  /// DEBUG: Streicht alle heutigen Erledigt-Marken.
  ///
  /// Danach stehen die vier Tages-Challenges wieder als offen im Panel. Was
  /// [markDone] sonst noch gefüllt hat — Serie, Spieltage-Historie, Zähler —
  /// bleibt stehen: Diese Werte gehören zur Spielhistorie, nicht zum heutigen
  /// Tag, und ein Zurückrechnen wäre bestenfalls geraten.
  static Future<void> debugHeuteLeeren() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key());
  }

  static Duration untilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }
}
