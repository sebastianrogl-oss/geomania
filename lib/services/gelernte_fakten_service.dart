import 'package:shared_preferences/shared_preferences.dart';
import '../data/countries.dart';
import '../data/lernpfad_data.dart';
import 'station_session_service.dart';

/// Dauerhafte Erfassung dessen, was der Spieler tatsächlich gelernt hat.
///
/// Zwei getrennte Mengen:
/// - [_kFakten]: Land+Kategorie-Kombinationen ("FR_flagge"). Ein Eintrag
///   entsteht, sobald eine Frage dazu RICHTIG beantwortet wurde. Dieselbe
///   Kombination erneut richtig zu beantworten ändert nichts.
/// - [_kLaender]: reine ISO-Codes. Ein Land gilt als gelernt, sobald
///   mindestens eine Frage dazu richtig war. Grundlage für die spätere
///   Weltkarte.
///
/// Bewusst NICHT abgeleitet aus abgeschlossenen Stationen: deren
/// `laenderCodes` sind der Fragen-POOL, aus dem nur ein Teil gezogen wird —
/// eine Station mit 8 Fragen kann 16 Länder im Pool haben. Genau das machte
/// den früheren Zähler unehrlich.
class GelernteFaktenService {
  static const _kFakten = 'gelernt_fakten';
  static const _kLaender = 'gelernt_laender';

  /// Verbucht eine richtig beantwortete Frage.
  ///
  /// Tut nichts, wenn sich der Frage kein einzelnes Hauptland zuordnen lässt
  /// (siehe [hauptland]).
  static Future<void> frageRichtig(Frage frage) async {
    final iso = hauptland(frage);
    if (iso == null || iso.isEmpty) return;
    final kategorie = kategorieFuer(frage.modus);

    final prefs = await SharedPreferences.getInstance();
    final fakten = (prefs.getStringList(_kFakten) ?? const []).toSet();
    final laender = (prefs.getStringList(_kLaender) ?? const []).toSet();

    // Set-Semantik: Duplikate ändern nichts.
    final vorher = fakten.length;
    fakten.add('${iso}_$kategorie');
    laender.add(iso);

    if (fakten.length != vorher) {
      await prefs.setStringList(_kFakten, fakten.toList());
    }
    await prefs.setStringList(_kLaender, laender.toList());
  }

  /// Anzahl gelernter Land+Kategorie-Kombinationen.
  static Future<int> anzahlFakten() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kFakten) ?? const []).toSet().length;
  }

  // Die Gesamtzahl erreichbarer Fakten (ausgezählt: 1573 über zwölf
  // Kategorien) ist bewusst entfallen — die Schluss-Ansicht zeigt nur noch
  // die eigene Leistung, nicht den Rest, der noch fehlt.

  /// Gelernte Länder als ISO-Codes (für Weltkarte und Kontinent-Fortschritt).
  static Future<Set<String>> gelernteLaender() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kLaender) ?? const []).toSet();
  }

  /// Gelernte Länder eines Kontinents gegen dessen Gesamtzahl.
  static Future<(int, int)> kontinentFortschritt(LernWelt welt) async {
    final gelernt = await gelernteLaender();
    // Die Welt-Welt führt '*' als Platzhalter statt einer Länderliste.
    if (welt.laenderCodes.length == 1 && welt.laenderCodes.first == '*') {
      return (gelernt.length, welt.totalLaender);
    }
    final zurWelt = welt.laenderCodes.toSet();
    return (gelernt.where(zurWelt.contains).length, welt.totalLaender);
  }

  /// Das GEFRAGTE Hauptland einer Frage — nicht die Antwortoptionen und nicht
  /// alle beteiligten Länder. Das hält die Zahl ehrlich.
  ///
  /// Normalerweise steht es in `Frage.laenderCode`. Bei Modi ohne
  /// Landvorschau ist das Feld leer, weil eine Vorschau die Antwort verraten
  /// würde — dort steckt das gesuchte Land in der richtigen Antwort.
  static String? hauptland(Frage frage) {
    if (frage.laenderCode.isNotEmpty) return frage.laenderCode;

    switch (frage.modus) {
      // Antwort ist bereits ein ISO-Code.
      case LernModus.grenzkettenRaetsel:
        return frage.richtigeAntwort;

      // Antwort ist ein Ländername — über die Länderliste auflösen. Beide
      // Seiten stammen aus derselben Quelle und sind damit gleich lokalisiert.
      case LernModus.waehrungZuLand:
      case LernModus.extremFrage:
      case LernModus.extremFrageLeicht:
      case LernModus.zufallsFakt:
      case LernModus.bekanntesGebaeude:
        return _isoFuerNamen(frage.richtigeAntwort);

      // Sortierspiel vergleicht mehrere Länder miteinander; ein einzelnes
      // "gefragtes" Land gibt es dort nicht.
      case LernModus.sortierSpiel:
        return null;

      default:
        return null;
    }
  }

  static String? _isoFuerNamen(String name) {
    final gesucht = name.trim().toLowerCase();
    for (final c in countries) {
      if (c.name.trim().toLowerCase() == gesucht) return c.iso2;
    }
    return null;
  }

  /// Kategorie eines Modus. Modi, die inhaltlich dasselbe Wissen abfragen,
  /// teilen sich bewusst eine Kategorie — ob eine Flagge angetippt oder
  /// eingetippt wird, ist derselbe Lernstoff.
  static String kategorieFuer(LernModus modus) => switch (modus) {
        LernModus.flaggenQuizBild ||
        LernModus.flaggenQuizMultiple ||
        LernModus.flaggenQuizEingabe =>
          'flagge',
        LernModus.hauptstaedteMultiple ||
        LernModus.hauptstaedteEingabe =>
          'hauptstadt',
        LernModus.umrissBild ||
        LernModus.umrissMultiple ||
        LernModus.umrissEingabe =>
          'umriss',
        LernModus.waehrungsQuiz || LernModus.waehrungZuLand => 'waehrung',
        LernModus.extremFrage || LernModus.extremFrageLeicht => 'superlativ',
        LernModus.nachbarland => 'nachbarn',
        LernModus.grenzkettenRaetsel => 'geografie',
        LernModus.bipGesamt => 'bip',
        LernModus.flaeche => 'flaeche',
        LernModus.wirtschaftssektoren => 'wirtschaft',
        LernModus.preisSchaetzen => 'preis',
        LernModus.zufallsFakt => 'fakt',
        LernModus.bekanntesGebaeude => 'bauwerk',
        LernModus.sortierSpiel => 'sortieren',
      };

  /// Nur für den Debug-Bereich der Einstellungen.
  static Future<void> debugZuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFakten);
    await prefs.remove(_kLaender);
  }
}
