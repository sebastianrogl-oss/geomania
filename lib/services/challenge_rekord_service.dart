import 'package:shared_preferences/shared_preferences.dart';
import 'spielstand_sync.dart';

class ChallengeRekordService {
  static String _rekordKey(String id) => 'ch_rekord_$id';
  static String _heuteKey(String id) {
    final n = DateTime.now();
    return 'ch_heute_${id}_${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  /// DEBUG: Löscht die heute erzielten Punkte einer Challenge.
  ///
  /// Der REKORD bleibt: Er gehört nicht zum heutigen Tag. Wer ihn auch
  /// zurücksetzen will, tut das über den Fortschritts-Reset.
  static Future<void> debugHeutigePunkteLoeschen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_heuteKey(id));
  }

  static Future<int?> getRekord(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_rekordKey(id));
    return v;
  }

  static Future<bool> setzeFallsBesser(String id, int punkte) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _rekordKey(id);
    final aktuell = prefs.getInt(key);
    if (aktuell == null || punkte > aktuell) {
      await prefs.setInt(key, punkte);
      return true;
    }
    return false;
  }

  // ── Prozentwert PASSEND zum Rekord (aktuell nur Portfolio: Tages-Rendite in
  // % neben dem absoluten Dollar-Rekord) ─────────────────────────────────────

  static String _rekordProzentKey(String id) => 'ch_rekord_prozent_$id';

  /// Wird NUR gemeinsam mit einem neuen Rekord aufgerufen (siehe
  /// setzeFallsBesser-Rückgabewert), damit der gespeicherte Prozentwert immer
  /// zum selben Tag/Ereignis gehört wie der Dollar-Rekord.
  static Future<void> setzeRekordProzent(String id, double prozent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rekordProzentKey(id), prozent);
  }

  static Future<double?> getRekordProzent(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_rekordProzentKey(id));
  }

  static Future<int?> getHeutigePunkte(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_heuteKey(id));
  }

  static Future<void> speichereHeutigePunkte(String id, int punkte) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_heuteKey(id), punkte);
  }

  // ── Serien-Zähler PRO Challenge (getrennt von der allgemeinen App-Streak) ──

  static String _streakKey(String id) => 'streak_$id';
  static String _letzterSpieltagKey(String id) => 'letzterSpieltag_$id';

  static String _heuteDatumStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Aktualisiert den Serien-Zähler DIESER Challenge: gleicher Tag wie
  /// letzter Spieltag -> keine Änderung, genau ein Tag später -> +1, größere
  /// Lücke -> zurück auf 1. Idempotent bei mehrfachem Aufruf am selben Tag.
  /// Gibt den (ggf. aktualisierten) Streak-Wert zurück.
  static Future<int> streakAktualisieren(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final heute = _heuteDatumStr();
    final letzter = prefs.getString(_letzterSpieltagKey(id));
    final alterStreak = prefs.getInt(_streakKey(id)) ?? 0;
    int streak = alterStreak;

    if (letzter == heute) return streak;

    if (letzter != null) {
      final letzteDatum = DateTime.parse(letzter);
      final heuteDatum = DateTime.now();
      final diff = DateTime(heuteDatum.year, heuteDatum.month, heuteDatum.day)
          .difference(DateTime(letzteDatum.year, letzteDatum.month, letzteDatum.day))
          .inDays;
      streak = diff == 1 ? streak + 1 : 1;
    } else {
      streak = 1;
    }

    await prefs.setInt(_streakKey(id), streak);
    await prefs.setString(_letzterSpieltagKey(id), heute);
    // Eine gespielte Tages-Challenge ist der zweite Moment, an dem etwas
    // entsteht, das niemand verlieren möchte. Der Aufruf setzt nur einen
    // Sammel-Timer, siehe SpielstandSync.
    SpielstandSync.merkeAenderung();
    return streak;
  }

  static Future<int> getStreak(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey(id)) ?? 0;
  }

  // ── Spieltage-Historie PRO Challenge (für den 7-Tage-Verlaufsstreifen) ─────
  //
  // Einheitlicher Mechanismus für alle 4 Challenges (auch Portfolio, dessen
  // eigener "verlauf" nicht datumsgenau ist) — Datum wird nur bei
  // tatsächlichem Abschluss vermerkt (über DailyChallenge.markDone()).

  static String _spieltageKey(String id) => 'spieltage_$id';

  /// Vermerkt den heutigen Tag als gespielt (dedupliziert), behält die
  /// letzten 14 Tage.
  static Future<void> spieltagVermerken(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final heute = _heuteDatumStr();
    final key = _spieltageKey(id);
    final tage = (prefs.getStringList(key) ?? []).toList();
    if (tage.contains(heute)) return;
    tage.add(heute);
    if (tage.length > 14) tage.removeRange(0, tage.length - 14);
    await prefs.setStringList(key, tage);
  }

  static Future<Set<String>> getSpieltage(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_spieltageKey(id)) ?? []).toSet();
  }

  // ── Anzahl gespielter Spiele PRO Challenge ─────────────────────────────────

  static String _anzahlGespieltKey(String id) => 'anzahlGespielt_$id';

  /// Erhöht den Zähler dieser Challenge um 1 (bei jedem Abschluss).
  static Future<int> spielGezaehlt(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _anzahlGespieltKey(id);
    final neu = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, neu);
    return neu;
  }

  static Future<int> getAnzahlGespielt(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_anzahlGespieltKey(id)) ?? 0;
  }

  // ── Laufende Punkte-Summe PRO Challenge (für Ø-Anzeige im Profil) ──────────

  static String _summeKey(String id) => 'summePunkte_$id';

  /// Erhöht die laufende Summe um den bei diesem Abschluss erzielten Wert
  /// (Punkte bei Preis/HigherLower/Ranking, Tages-Rendite in % bei Portfolio).
  /// Ø = Summe / Anzahl gespielt.
  static Future<void> summeErhoehen(String id, double wert) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _summeKey(id);
    await prefs.setDouble(key, (prefs.getDouble(key) ?? 0) + wert);
  }

  static Future<double> getSumme(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_summeKey(id)) ?? 0;
  }

  // ── Beste jemals erreichte Serie PRO Challenge (getrennt von der aktuellen
  // Serie in _streakKey) ──────────────────────────────────────────────────────

  static String _besteStreakKey(String id) => 'besteStreak_$id';

  /// Aktualisiert den Rekord-Streak, falls die aktuelle Serie einen neuen
  /// Höchstwert erreicht hat.
  static Future<void> besteStreakAktualisieren(String id, int aktuelleStreak) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _besteStreakKey(id);
    if (aktuelleStreak > (prefs.getInt(key) ?? 0)) {
      await prefs.setInt(key, aktuelleStreak);
    }
  }

  static Future<int> getBesteStreak(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_besteStreakKey(id)) ?? 0;
  }
}
