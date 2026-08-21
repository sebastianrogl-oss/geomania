import 'package:shared_preferences/shared_preferences.dart';

/// Merkt sich, WANN gespielt wird, und leitet daraus die übliche Spielzeit ab.
///
/// Grundlage der täglichen Erinnerung (services/benachrichtigungs_service.dart):
/// eine Erinnerung um 19 Uhr nützt niemandem, der immer morgens spielt.
///
/// Bewusst rein lokal und ohne Konto-Bezug — die Uhrzeiten verlassen das Gerät
/// nicht.
class SpielzeitService {
  /// Ein Eintrag je Kalendertag, Format `jjjj-mm-tt|minute`.
  static const _kProtokoll = 'spielzeit_protokoll';

  /// Vom Nutzer in den Einstellungen gesetzte Uhrzeit. Ist sie gesetzt, wird
  /// nicht mehr gerechnet — eine ausdrückliche Angabe schlägt jede Statistik.
  static const _kManuell = 'spielzeit_manuell';

  static const int kTagMinuten = 24 * 60;

  /// Vorgabe, solange zu wenige oder zu unregelmäßige Daten vorliegen.
  static const int kVorgabeMinute = 19 * 60;

  /// Sinnvoller Rahmen: niemand soll um 3 Uhr nachts erinnert werden, auch
  /// wenn er tatsächlich um 3 Uhr nachts spielt.
  static const int kFruehesteMinute = 8 * 60;
  static const int kSpaetesteMinute = 21 * 60;

  /// So viele Spieltage fließen in die Rechnung ein. Mehr wäre träge (ein
  /// geänderter Tagesrhythmus schlüge zu langsam durch), weniger zappelig.
  static const int kMaxEintraege = 14;

  /// Ab so vielen Einträgen wird gerechnet, darunter gilt [kVorgabeMinute].
  static const int kMindestEintraege = 3;

  /// Breite des Suchfensters (3 Stunden). Was innerhalb von drei Stunden
  /// liegt, gilt als "dieselbe Tageszeit".
  static const int kFensterMinuten = 180;

  /// So viel Anteil aller Einträge muss das dichteste Fenster enthalten, damit
  /// das Ergebnis als "übliche" Spielzeit durchgeht. Wer über den ganzen Tag
  /// verteilt spielt, hat keine übliche Zeit — dann ist die Vorgabe die
  /// ehrlichere Antwort als ein errechneter Scheinwert.
  static const double kMindestAnteil = 0.4;

  // ── Protokoll ──────────────────────────────────────────────────────────────

  /// Hält den aktuellen Zeitpunkt fest — aufgerufen bei jedem
  /// Stationsabschluss.
  ///
  /// Nur EIN Eintrag je Kalendertag, und zwar der erste: wer abends acht
  /// Stationen am Stück spielt, soll den Schnitt nicht achtfach in seine
  /// Richtung ziehen. Der erste Abschluss des Tages sagt am besten, wann zur
  /// App gegriffen wird.
  static Future<void> protokolliere([DateTime? jetzt]) async {
    final zeit = jetzt ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final liste = prefs.getStringList(_kProtokoll) ?? <String>[];
    final tag = _tagesSchluessel(zeit);

    if (liste.isNotEmpty && liste.last.startsWith('$tag|')) return;

    liste.add('$tag|${zeit.hour * 60 + zeit.minute}');
    while (liste.length > kMaxEintraege) {
      liste.removeAt(0);
    }
    await prefs.setStringList(_kProtokoll, liste);
  }

  /// True, wenn heute schon ein Stationsabschluss protokolliert wurde.
  static Future<bool> hatHeuteGespielt([DateTime? jetzt]) async {
    final prefs = await SharedPreferences.getInstance();
    final liste = prefs.getStringList(_kProtokoll) ?? <String>[];
    if (liste.isEmpty) return false;
    final tag = _tagesSchluessel(jetzt ?? DateTime.now());
    return liste.last.startsWith('$tag|');
  }

  /// Die protokollierten Uhrzeiten als Minuten seit Mitternacht.
  static Future<List<int>> protokollierteMinuten() async {
    final prefs = await SharedPreferences.getInstance();
    final liste = prefs.getStringList(_kProtokoll) ?? <String>[];
    final minuten = <int>[];
    for (final eintrag in liste) {
      final minute = int.tryParse(eintrag.split('|').last);
      if (minute != null) minuten.add(minute);
    }
    return minuten;
  }

  static String _tagesSchluessel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── Manuelle Überschreibung ────────────────────────────────────────────────

  static Future<int?> manuelleMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kManuell);
  }

  static Future<void> setzeManuelleMinute(int? minute) async {
    final prefs = await SharedPreferences.getInstance();
    if (minute == null) {
      await prefs.remove(_kManuell);
    } else {
      await prefs.setInt(_kManuell, minute);
    }
  }

  /// Die Uhrzeit, auf die die tägliche Erinnerung gelegt wird.
  static Future<int> erinnerungsMinute() async {
    final manuell = await manuelleMinute();
    if (manuell != null) return manuell;
    return berechneTypischeMinute(await protokollierteMinuten());
  }

  // ── Die Rechnung ───────────────────────────────────────────────────────────

  /// Ermittelt die übliche Spielzeit aus den protokollierten Uhrzeiten.
  ///
  /// Bewusst KEIN Mittelwert, weder gerade noch zirkulär:
  ///
  /// - Der gerade Mittelwert von 8:00 und 22:00 ist 15:00 — eine Uhrzeit, zu
  ///   der der Nutzer nie spielt.
  /// - Der zirkuläre Mittelwert (Vektor-Mittel auf dem 24-Stunden-Kreis) legt
  ///   dieselben zwei Zeiten auf 3:00 Uhr nachts. Für Tageszeiten ist er zwar
  ///   das mathematisch saubere Mittel, bei zwei Häufungen trifft er aber
  ///   genau die Lücke dazwischen — hier also den schlimmstmöglichen Wert.
  ///
  /// Stattdessen wird die DICHTESTE Häufung gesucht: ein [kFensterMinuten]
  /// breites Fenster wandert über den Kreis, das Fenster mit den meisten
  /// Einträgen gewinnt, und innerhalb davon entscheidet der Median. Wer mal
  /// morgens und mal abends spielt, bekommt damit die Uhrzeit seiner
  /// häufigeren Hälfte statt eines Kompromisses, an dem er nie spielt.
  ///
  /// Das Fenster wandert über den KREIS, nicht über eine Liste von 0 bis 1439:
  /// wer um 23:30 und um 0:30 spielt, hat eine Häufung und nicht zwei.
  ///
  /// Ergebnis wird auf 5 Minuten gerundet und in [kFruehesteMinute] ..
  /// [kSpaetesteMinute] gezwungen.
  static int berechneTypischeMinute(List<int> minuten) {
    if (minuten.length < kMindestEintraege) return kVorgabeMinute;

    var besterStart = -1;
    var besteAnzahl = -1;
    var besteOffsets = const <int>[];

    // Jeder Eintrag ist ein Kandidat für den Fensteranfang. Mehr Startpunkte
    // zu prüfen bringt nichts: ein Fenster, das an keinem Eintrag beginnt,
    // lässt sich nach rechts schieben, bis es das tut, ohne dabei einen
    // Eintrag zu verlieren.
    for (final start in minuten) {
      final offsets = <int>[];
      for (final m in minuten) {
        final abstand = (m - start + kTagMinuten) % kTagMinuten;
        if (abstand < kFensterMinuten) offsets.add(abstand);
      }
      // Gleichstand geht an die spätere Tageszeit. Wer gleich oft morgens wie
      // abends spielt, wird abends erinnert — morgens ist der Tag noch lang
      // genug, dass die Erinnerung gar nicht nötig wäre.
      final besser = offsets.length > besteAnzahl ||
          (offsets.length == besteAnzahl && start > besterStart);
      if (besser) {
        besteAnzahl = offsets.length;
        besterStart = start;
        besteOffsets = offsets;
      }
    }

    if (besteAnzahl < minuten.length * kMindestAnteil) return kVorgabeMinute;

    final sortiert = List<int>.of(besteOffsets)..sort();
    final median = sortiert[sortiert.length ~/ 2];
    return _inRahmen((besterStart + median) % kTagMinuten);
  }

  /// Rundet auf 5 Minuten und begrenzt auf den erlaubten Rahmen.
  ///
  /// Die Begrenzung schneidet hart ab, sie verschiebt nicht: 3:00 wird zu 8:00
  /// und 23:00 zu 21:00. Für einen Nachtspieler ist die Erinnerung damit zur
  /// falschen Zeit — aber eine Benachrichtigung um 3 Uhr nachts wäre schlimmer
  /// als eine zu frühe.
  static int _inRahmen(int minute) {
    final gerundet = (minute / 5).round() * 5;
    if (gerundet < kFruehesteMinute) return kFruehesteMinute;
    if (gerundet > kSpaetesteMinute) return kSpaetesteMinute;
    return gerundet;
  }

  /// `19:00` — für die Anzeige in den Einstellungen und im Debug-Bereich.
  static String formatiere(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';
}
