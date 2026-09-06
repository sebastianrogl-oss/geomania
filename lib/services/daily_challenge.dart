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
    //
    // IST ER GESTIEGEN, WIRD DAS VERMERKT. Gefeiert werden kann hier nicht:
    // Das Overlay ist ein Vollbild-Moment und braucht einen BuildContext, den
    // ein Dienst nicht hat — und mitten in der laufenden Challenge käme er
    // ohnehin zur falschen Zeit. Der Vermerk wandert deshalb bis zum
    // [ChallengeFertigButton], der einen Stelle, an der alle vier Challenges
    // ihre Ergebnis-Ansicht verlassen. Vier Screens einzeln anzufassen wäre
    // genau das Kopieren, das dieser Aufrufpunkt vermeiden soll.
    final (alterStreak, neuerStreak) =
        await FortschrittService.streakAktualisieren();
    if (neuerStreak > alterStreak) {
      // Mit dem Tag, für den er gilt. Wer die App zwischen Abschluss und
      // "Fertig" schliesst, soll die Feier nicht irgendwann nächste Woche
      // bekommen.
      await prefs.setString(_kFeierOffen, '$key|$alterStreak|$neuerStreak');
    }

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

  /// Vermerk "eine Challenge hat heute den Streak erhöht, gefeiert wurde noch
  /// nicht". Inhalt: `<Tagesschlüssel>|<alt>|<neu>`.
  ///
  /// Ein Schlüssel und keine Variable im Speicher: Zwischen dem Abschluss und
  /// dem Tippen auf "Fertig" liegt eine Ergebnis-Ansicht, und die überlebt
  /// nicht zwangsläufig jeden Wechsel in den Hintergrund.
  ///
  /// `dc_` ist als geräteeigen eingestuft (siehe spielstand.dart): Eine
  /// ausstehende Feier gehört zu diesem Telefon, nicht in die Cloud.
  static const _kFeierOffen = 'dc_streak_feier_offen';

  /// Nimmt einen offenen Feier-Vermerk entgegen und streicht ihn.
  ///
  /// Liefert `(alt, neu)` oder null, wenn nichts aussteht — dann hat entweder
  /// heute schon eine Lernpfad-Station gefeiert, oder der Tag zählte bereits.
  /// EIN TAG, EINE FEIER: Der Vermerk entsteht nur, wenn
  /// [FortschrittService.streakAktualisieren] den Streak wirklich erhöht hat,
  /// und das tut sie am selben Kalendertag genau einmal.
  ///
  /// Gestrichen wird beim LESEN, nicht nach der Feier: Ein Vermerk, der eine
  /// missglückte Anzeige überlebt, käme sonst bei jedem weiteren "Fertig"
  /// wieder hoch.
  static Future<(int, int)?> offeneStreakFeier() async {
    final prefs = await SharedPreferences.getInstance();
    final roh = prefs.getString(_kFeierOffen);
    if (roh == null) return null;
    await prefs.remove(_kFeierOffen);

    final teile = roh.split('|');
    if (teile.length != 3) return null;
    // Von gestern oder älter: Der Moment ist vorbei, eine Feier dafür wäre
    // nur noch verwirrend.
    if (teile[0] != _key()) return null;
    final alt = int.tryParse(teile[1]);
    final neu = int.tryParse(teile[2]);
    if (alt == null || neu == null || neu <= alt) return null;
    return (alt, neu);
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
