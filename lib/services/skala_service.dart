import 'dart:math';
import 'locale_service.dart';

// Dezimal-Trennzeichen ist im Deutschen ein Komma, im Englischen ein Punkt
// (den Dart's toStringAsFixed() bereits liefert) — daher hier zentral statt
// verstreuter .replaceAll('.', ',')-Aufrufe.
String _dec(double v, int decimals) {
  final s = v.toStringAsFixed(decimals);
  return LocaleService.istEnglisch ? s : s.replaceAll('.', ',');
}

// Ganzzahlige Rundung würde bei sehr kleinen Werten (z.B. Tourismuseinnahmen
// oder Militärausgaben winziger Länder) fälschlich "0" anzeigen, obwohl der
// Wert ungleich null ist — dann fest auf 2 Nachkommastellen ausweichen,
// sonst ganzzahlig runden wie gewohnt.
String _fmtGerundetOderZweiDezimal(double v, String einheit) {
  if (v == 0) return '0 $einheit';
  if (v.round() == 0) return '${_dec(v, 2)} $einheit';
  return '${v.round()} $einheit';
}

/// Reglerstufen einer logarithmischen Skala.
///
/// Anders als bei der linearen Skala gibt es hier keine "schönen" Schrittweiten
/// — die Stufen sitzen auf der Position, nicht auf dem Wert — also kann die
/// Zahl frei gewählt werden. 500 Stufen bedeuten 0,2 % Abweichung je Stufe und
/// damit rund 1,2 Punkte Abstand zwischen zwei benachbarten Reglerstellungen.
const int _kLogStufen = 500;

/// Unter- und Obergrenze der Reglerstufen einer linearen Skala.
///
/// Vorher 50 bis 500, tatsächlich erreicht wurden im Median nur 137 — mit der
/// Folge, dass von 101 möglichen Punktwerten nur 58 überhaupt vorkamen und der
/// erste Sprung unter die volle Punktzahl 4 Punkte betrug. [_niceStep] zielt
/// jetzt auf Spanne/500 statt Spanne/200; weil es auf einen schönen Wert
/// AUFrundet, landet die Stufenzahl damit zwischen 200 und 500.
const int _kMinStufen = 200;
const int _kMaxStufen = 500;

class SkalaErgebnis {
  final double min;
  final double max;
  final double schritt;
  final String Function(double) format;

  /// Regler und Bewertung laufen logarithmisch statt linear.
  ///
  /// Gesetzt für die Kategorien in [SkalaService.kLogKategorien]. Bedingung
  /// dafür ist immer [min] > 0 — [SkalaService.ausRundenWerten] fällt sonst
  /// auf linear zurück, damit nirgends der Logarithmus von 0 gebildet wird.
  final bool logarithmisch;

  const SkalaErgebnis({
    required this.min,
    required this.max,
    required this.schritt,
    required this.format,
    this.logarithmisch = false,
  });

  int get divisionen => logarithmisch
      ? _kLogStufen
      : ((max - min) / schritt).round().clamp(_kMinStufen, _kMaxStufen);

  /// Position eines Werts auf dem Regler, 0 (links) bis 1 (rechts).
  ///
  /// Der Regler selbst läuft immer von 0 bis 1 — nur diese Funktion weiß, ob
  /// dahinter eine lineare oder eine logarithmische Achse steht. Damit gibt es
  /// genau eine Stelle, an der die Achse definiert ist, statt einer Rechnung
  /// im Regler und einer zweiten in jeder Markierung.
  double positionVon(double wert) {
    if (max <= min) return 0;
    final w = wert.clamp(min, max);
    if (!logarithmisch) return (w - min) / (max - min);
    return log(w / min) / log(max / min);
  }

  /// Wert an einer Reglerposition 0 bis 1 — die Umkehrung von [positionVon].
  double wertAn(double position) {
    final p = position.clamp(0.0, 1.0);
    if (!logarithmisch) return min + p * (max - min);
    return min * exp(p * log(max / min));
  }

  /// Abstand zweier Werte, gemessen als Prozent der Reglerlänge (0 bis 100).
  ///
  /// DIE Stelle, an der über die Bewertung entschieden wird. Auf einer
  /// logarithmischen Skala zählt damit automatisch das VERHÄLTNIS statt der
  /// Differenz: doppelt so hoch geschätzt kostet überall gleich viel, egal ob
  /// die Wahrheit bei 40 km oder bei 200 000 km liegt.
  ///
  /// Warum das nötig war: Vorher war der Abstand immer die Differenz geteilt
  /// durch die Skalenbreite. Zog ein einzelnes Ausreißer-Land die Skala
  /// auseinander — Kanada mit 202 000 km Küste unter vier Ländern mit unter
  /// 350 km — verschwand jeder Unterschied zwischen den übrigen vieren im
  /// Nichts: 160 km statt 40 km zu schätzen, also das Vierfache, gab weiterhin
  /// die volle Punktzahl.
  double abstand(double a, double b) {
    if (max <= min) return 0;
    final x = a.clamp(min, max);
    final y = b.clamp(min, max);
    if (!logarithmisch) return (x - y).abs() / (max - min) * 100;
    return (log(x) - log(y)).abs() / log(max / min) * 100;
  }
}

class SkalaService {
  // Berechnet ein oberes Skalenende, das IMMER >= realVal*mindestFaktor ist
  // (die richtige Antwort bleibt so garantiert innerhalb der Skala) und nur
  // dann auf [hardCap] gedeckelt wird, wenn das den Mindestwert nicht
  // unterschreitet. Ein einfaches `.clamp(realVal*mindestFaktor, hardCap)`
  // wirft bei großen realVal (z.B. Monaco, Russland, USA, Indien) eine
  // ArgumentError, weil dann lowerLimit > upperLimit wird.
  static double _hiMitHeadroom(
      double realVal, double faktor, double mindestFaktor, double hardCap) {
    var hi = realVal * faktor;
    final mindest = realVal * mindestFaktor;
    if (hi < mindest) hi = mindest;
    if (hi > hardCap && mindest <= hardCap) hi = hardCap;
    return hi;
  }

  // Ohne diese Funktion sitzt realVal bei JEDER adaptiven Skala (siehe
  // Faktoren unten, z.B. lo=0.15*realVal / hi=4.5*realVal) systematisch im
  // unteren Fünftel der Skala — (1-0.15)/(4.5-0.15)≈20%, egal welches Land
  // oder welche Kategorie. Verschiebt lo/hi seed-basiert so, dass realVal an
  // einer zufälligen Position (15%-80%) landet, auch mal in der oberen
  // Hälfte. Die ursprüngliche Breite (hi-lo) wird nur als OBERGRENZE
  // verwendet: bei hohen Zielpositionen würde lo=realVal-ziel*breite
  // negativ werden (unmöglich, da lo>=0), daher wird die Breite in diesem
  // Fall verkleinert (auf maximal realVal/ziel), statt lo einfach bei 0 zu
  // kappen — sonst bliebe die erreichbare Position trotz hohem ziel
  // rechnerisch bei realVal/breite gedeckelt (das war der ursprüngliche
  // Bug: nie über ~23% hinausgekommen). Ohne seed (null) bleibt das
  // bisherige, deterministische Verhalten erhalten — genutzt von
  // fuerKategorie()/Station-Quiz, das absichtlich NICHT verändert wird.
  static (double, double) _positioniere(
      double realVal, double lo, double hi, int? seed) {
    if (seed == null) return (lo, hi);
    final rng = Random(seed);
    final ziel = 0.15 + rng.nextDouble() * 0.65;
    final breiteMax = hi - lo;
    final breite = min(breiteMax, realVal / ziel * 0.95);
    final neuLo = (realVal - ziel * breite).clamp(0.0, double.infinity);
    return (neuLo, neuLo + breite);
  }

  // ── GDP per capita (USD) ─────────────────────────────────────────────────────
  static SkalaErgebnis bipProKopf(double realVal, [int? seed]) {
    if (realVal < 300) {
      return SkalaErgebnis(
        min: 0, max: (realVal * 6).clamp(100.0, 2000.0), schritt: 10,
        format: (v) => '\$ ${_fmtInt(v.round())}');
    }
    final loRoh = (realVal * 0.15).clamp(100.0, realVal * 0.45);
    final hiRoh = _hiMitHeadroom(realVal, 4.5, 2.0, 500000.0);
    final (lo, hi) = _positioniere(realVal, loRoh, hiRoh, seed);
    final s = _niceStep(hi - lo);
    return SkalaErgebnis(
      min: _roundDown(lo, s),
      max: _roundUp(hi, s),
      schritt: s,
      format: (v) => '\$ ${_fmtInt(v.round())}',
    );
  }

  // ── Population (persons) ─────────────────────────────────────────────────────
  static SkalaErgebnis bevoelkerung(double realVal, [int? seed]) {
    if (realVal < 5000) {
      // Kleinstaaten wie Vatikanstadt (~800 Einw.): eigener kleiner Bereich,
      // sonst kann die adaptive Prozent-Formel unten min>max erzeugen.
      return SkalaErgebnis(
        min: 0,
        max: (realVal * 6).clamp(200.0, 20000.0),
        schritt: 10,
        format: _fmtPop,
      );
    }
    final loRoh = (realVal * 0.12).clamp(1000.0, realVal * 0.4);
    final hiRoh = _hiMitHeadroom(realVal, 4.5, 2.0, 3e9);
    final (lo, hi) = _positioniere(realVal, loRoh, hiRoh, seed);
    final s = _niceStep(hi - lo);
    return SkalaErgebnis(
      min: _roundDown(lo, s),
      max: _roundUp(hi, s),
      schritt: s,
      format: _fmtPop,
    );
  }

  // ── GDP total (USD) ───────────────────────────────────────────────────────────
  static SkalaErgebnis bipGesamt(double realVal, [int? seed]) {
    final loRoh = (realVal * 0.15).clamp(1e6, realVal * 0.45);
    final hiRoh = _hiMitHeadroom(realVal, 4.5, 2.0, 60e12);
    final (lo, hi) = _positioniere(realVal, loRoh, hiRoh, seed);
    final s = _niceStep(hi - lo);
    return SkalaErgebnis(
      min: _roundDown(lo, s),
      max: _roundUp(hi, s),
      schritt: s,
      format: (v) => '\$ ${_fmtGross(v)}',
    );
  }

  // ── Mindestlohn (USD/Monat) ─────────────────────────────────────────────────
  static SkalaErgebnis mindestlohn(double realVal, [int? seed]) {
    if (realVal < 20) {
      return SkalaErgebnis(
        min: 0, max: 60, schritt: 1,
        format: (v) => '\$ ${v.round()}/${LocaleService.istEnglisch ? 'mo' : 'Monat'}');
    }
    final loRoh = (realVal * 0.2).clamp(0.0, realVal * 0.5);
    final hiRoh = _hiMitHeadroom(realVal, 3.0, 1.5, 7000.0);
    final (lo, hi) = _positioniere(realVal, loRoh, hiRoh, seed);
    final s = _niceStep(hi - lo);
    return SkalaErgebnis(
      min: _roundDown(lo, s),
      max: _roundUp(hi, s),
      schritt: s,
      format: (v) => '\$ ${v.round()}/${LocaleService.istEnglisch ? 'mo' : 'Monat'}',
    );
  }

  /// Dispatcher: passende adaptive Skala für eine Sortier-/Preis-Kategorie
  /// (dieselben IDs wie in [_SpielKategorie] in station_session_service.dart).
  /// KEIN seed weitergereicht -> Station-Quiz bleibt bewusst beim bisherigen,
  /// deterministischen (niedrig positionierten) Verhalten.
  static SkalaErgebnis? fuerKategorie(String kategorieId, double realVal) =>
      switch (kategorieId) {
        'bevoelkerung'    => bevoelkerung(realVal),
        'bipGesamt'       => bipGesamt(realVal),
        'bipProKopf'      => bipProKopf(realVal),
        'flaeche'         => flaeche(realVal),
        'lebenserwartung' => lebenserwartung(realVal),
        'mindestlohn'     => mindestlohn(realVal),
        _ => null,
      };

  // ── Area (km²) ──────────────────────────────────────────────────────────────
  static SkalaErgebnis flaeche(double realVal, [int? seed]) {
    if (realVal < 5) {
      // Microstates like Vatican, Monaco
      return SkalaErgebnis(
        min: 0,
        max: (realVal * 8).clamp(5, 50),
        schritt: 0.01,
        format: (v) => '${v.toStringAsFixed(2)} km²',
      );
    }
    final loRoh = (realVal * 0.10).clamp(1.0, realVal * 0.4);
    final hiRoh = _hiMitHeadroom(realVal, 5.0, 2.5, 40e6);
    final (lo, hi) = _positioniere(realVal, loRoh, hiRoh, seed);
    final s = _niceStep(hi - lo);
    return SkalaErgebnis(
      min: _roundDown(lo, s),
      max: _roundUp(hi, s),
      schritt: s,
      format: _fmtArea,
    );
  }

  // ── Life expectancy (years) ──────────────────────────────────────────────────
  static SkalaErgebnis lebenserwartung(double realVal) {
    return SkalaErgebnis(
      min: 40.0,
      max: 90.0,
      schritt: 0.5,
      format: (v) =>
          '${_dec(v, 1)} ${LocaleService.istEnglisch ? 'yrs' : 'J.'}',
    );
  }

  // ── Internetgeschwindigkeit (Mbps) ──────────────────────────────────────────
  static SkalaErgebnis internetGeschwindigkeit(double _) => SkalaErgebnis(
        min: 1, max: 350, schritt: 1,
        format: (v) => '${v.round()} Mbps');

  // ── Korruptionsindex (0-100) ─────────────────────────────────────────────────
  static SkalaErgebnis korruptionsIndex(double _) => SkalaErgebnis(
        min: 0, max: 100, schritt: 1,
        format: (v) => '${v.round()} / 100');

  // ── Pressefreiheitsindex (0-100) ─────────────────────────────────────────────
  static SkalaErgebnis pressefreiheit(double _) => SkalaErgebnis(
        min: 0, max: 100, schritt: 1,
        format: (v) => '${v.round()} / 100');

  // ── Glücksindex (0-10) ───────────────────────────────────────────────────────
  static SkalaErgebnis gluecksIndex(double _) => SkalaErgebnis(
        min: 0, max: 10, schritt: 0.1,
        format: (v) => _dec(v, 2));

  // ── Tourismuseinnahmen (Mrd. USD) ────────────────────────────────────────────
  static SkalaErgebnis tourismusEinnahmen(double _) => SkalaErgebnis(
        min: 0, max: 250, schritt: 1,
        format: (v) => _fmtGerundetOderZweiDezimal(
            v, '${LocaleService.istEnglisch ? 'B' : 'Mrd.'} \$'));

  // ── Militärausgaben (Mrd. USD) ───────────────────────────────────────────────
  static SkalaErgebnis militaerAusgaben(double _) => SkalaErgebnis(
        min: 0, max: 900, schritt: 1,
        format: (v) => _fmtGerundetOderZweiDezimal(
            v, '${LocaleService.istEnglisch ? 'B' : 'Mrd.'} \$'));

  // ── Geburtenrate (Kinder pro Frau) ──────────────────────────────────────────
  static SkalaErgebnis geburtenrate(double _) => SkalaErgebnis(
        min: 0.5, max: 7.5, schritt: 0.1,
        format: (v) =>
            '${_dec(v, 1)} ${LocaleService.istEnglisch ? 'children/woman' : 'Kinder/Frau'}');

  // ── Waldanteil (%) ───────────────────────────────────────────────────────────
  // Einige Länder haben einen echten, aber sehr kleinen Waldanteil (z.B.
  // Ägypten 0.1%, Mauretanien/Dschibuti 0.2%) — ganzzahlige Rundung würde das
  // fälschlich als "0 %" (=kein Wald) anzeigen, obwohl der Wert ungleich null
  // ist. Ein echtes "0 %" (z.B. Katar, Oman, Nauru) bleibt unverändert "0".
  static SkalaErgebnis waldanteil(double _) => SkalaErgebnis(
        min: 0, max: 100, schritt: 1,
        format: (v) => _fmtGerundetOderZweiDezimal(v, '%'));

  // ── Küstenlinie (km) ─────────────────────────────────────────────────────────
  static SkalaErgebnis kuestenlinie(double realVal, [int? seed]) {
    if (realVal < 50) {
      return SkalaErgebnis(
          min: 0, max: (realVal * 8).clamp(20.0, 300.0), schritt: 1,
          format: (v) => '${_fmtInt(v.round())} km');
    }
    final loRoh = (realVal * 0.10).clamp(1.0, realVal * 0.4);
    final hiRoh = _hiMitHeadroom(realVal, 5.0, 2.0, 300000.0);
    final (lo, hi) = _positioniere(realVal, loRoh, hiRoh, seed);
    final s = _niceStep(hi - lo);
    return SkalaErgebnis(
      min: _roundDown(lo, s),
      max: _roundUp(hi, s),
      schritt: s,
      format: (v) => '${_fmtInt(v.round())} km',
    );
  }

  // ── Alkoholkonsum (Liter/Kopf) ────────────────────────────────────────────────
  static SkalaErgebnis alkoholkonsum(double _) => SkalaErgebnis(
        min: 0, max: 15, schritt: 0.1,
        format: (v) =>
            '${_dec(v, 1)} ${LocaleService.istEnglisch ? 'L/capita' : 'L/Kopf'}');

  // ── Olympia-Medaillen (Anzahl gesamt) ─────────────────────────────────────────
  static SkalaErgebnis olympiaMedaillen(double realVal, [int? seed]) {
    if (realVal < 10) {
      return SkalaErgebnis(
          min: 0, max: (realVal * 6).clamp(5.0, 50.0), schritt: 1,
          format: (v) =>
              '${v.round()} ${LocaleService.istEnglisch ? 'medals' : 'Medaillen'}');
    }
    final loRoh = (realVal * 0.15).clamp(1.0, realVal * 0.45);
    final hiRoh = _hiMitHeadroom(realVal, 4.0, 2.0, 3000.0);
    final (lo, hi) = _positioniere(realVal, loRoh, hiRoh, seed);
    final s = _niceStep(hi - lo);
    return SkalaErgebnis(
      min: _roundDown(lo, s),
      max: _roundUp(hi, s),
      schritt: s,
      format: (v) =>
          '${v.round()} ${LocaleService.istEnglisch ? 'medals' : 'Medaillen'}',
    );
  }

  // ── Höchster Punkt (Meter über Meeresspiegel) ─────────────────────────────────
  static SkalaErgebnis hoechsterPunkt(double _) => SkalaErgebnis(
        min: 0, max: 9000, schritt: 10,
        format: (v) => '${_fmtInt(v.round())} m');

  // ── Inflationsrate (%) ────────────────────────────────────────────────────────
  static SkalaErgebnis inflationsrate(double realVal, [int? seed]) {
    if (realVal < 10) {
      return SkalaErgebnis(
          min: 0, max: (realVal * 6).clamp(5.0, 40.0), schritt: 0.1,
          format: (v) => '${_dec(v, 1)} %');
    }
    final hiRoh = _hiMitHeadroom(realVal, 3.0, 1.5, 450.0);
    // min ist hier fest bei 0 (Inflation ist naturgemäß >=0 begrenzt) — die
    // allgemeine _positioniere()-Verschiebung kann lo nicht unter 0 drücken,
    // hier zieht daher direkt hi (statt lo) Richtung realVal, um realVal auch
    // mal in der oberen Skalenhälfte zu positionieren.
    final hi = seed == null
        ? hiRoh
        : () {
            final ziel = 0.15 + Random(seed).nextDouble() * 0.65;
            final neuHi = realVal / ziel;
            return neuHi < realVal * 1.5 ? realVal * 1.5 : neuHi;
          }();
    final s = _niceStep(hi);
    return SkalaErgebnis(
      min: 0,
      max: _roundUp(hi, s),
      schritt: s,
      format: (v) => '${_dec(v, 1)} %',
    );
  }

  // ── Staatsschulden (% des BIP) ─────────────────────────────────────────────────
  static SkalaErgebnis staatsschulden(double _) => SkalaErgebnis(
        min: 0, max: 300, schritt: 1,
        format: (v) => '${v.round()} % ${LocaleService.istEnglisch ? 'GDP' : 'BIP'}');

  // ── Rundenskala (EINMAL pro Tages-Runde, nicht pro Frage) ────────────────
  //
  // fuerRankingId()/fuerKategorie() oben liefern eine ADAPTIVE Skala pro
  // einzelnem realVal — richtig für den Lernpfad-Preisschätzen-Modus
  // (station_session_service.dart), aber falsch für die "Das große
  // Schätzen"-Tages-Challenge: dort soll der Slider innerhalb EINER Runde
  // (8 Fragen derselben Kategorie) immer dieselbe Skala zeigen, damit der
  // Spieler ein Gefühl für "hoch/niedrig in dieser Kategorie" entwickeln
  // kann. ausRundenWerten() berechnet dafür GENAU EINMAL (aus den echten
  // Werten der tatsächlich gezogenen Länder dieser Runde) eine feste Skala.

  /// Kategorien mit fester 0-100-Skala (Prozent/Index-Punkte): die
  /// Rundenskala darf hier nie über die natürlichen Grenzen hinaus gepuffert
  /// werden. Auch von preis_schaetzen_screen.dart für die Punkteberechnung
  /// genutzt (absolute statt relative Abweichung) — eine Stelle, damit beide
  /// Verwendungen nie auseinanderlaufen.
  static bool istProzentKategorie(String rankingId) => const {
        'forest',
        'corruption',
        'press_freedom',
        'inflation',
      }.contains(rankingId);

  // ── Logarithmische Kategorien ─────────────────────────────────────────────
  //
  // DIE EINE STELLE, an der steht, welche Kategorien einen logarithmischen
  // Regler und eine Verhältnis-Bewertung bekommen. Ein neuer oder
  // aktualisierter Datensatz kann eine Kategorie kippen — deshalb steht hier
  // das Kriterium samt Messwerten und nicht nur das Ergebnis.
  //
  // KRITERIUM: Von den 5 Ländern einer Tagesrunde liegt im Mittel MINDESTENS
  // EINES im unteren Zehntel des Reglers. Gemessen über je 3000 simulierte
  // Runden mit der echten Ziehung (Pool-Filter wie in _starteFragen) und der
  // echten Rundenskala. Nachrechnen: Runde ziehen, ausRundenWerten() rufen,
  // zählen wie viele Werte unter min + 0,1*(max-min) liegen, mitteln.
  //
  //   Kategorie       linear   log     Kategorie       linear   log
  //   gdpTotal          2,70  0,38     debt              0,16  0,00
  //   military          2,50  0,23     press_freedom     0,06  0,00
  //   tourism           2,48  0,15     corruption        0,00  0,00
  //   olympics          2,48  0,14     happiness         0,00  0,00
  //   area              2,44  0,54     birth_rate        0,00  0,00
  //   population        2,23  0,34     lifeExpectancy    0,00  0,00
  //   coastline         2,14  0,13     forest            0,70  0,02
  //   gdpPerCapita      1,87  0,00     alcohol           0,70  0,00
  //   internet          1,81  0,00     highest_point     0,66  0,06
  //   minimumWage       1,26  0,00
  //   inflation         1,02  0,00
  //
  // Die neun Kategorien rechts bleiben bewusst linear. Bei Prozent- und
  // Indexgrössen (Waldanteil, Korruption, Schulden, Glück) ist die 0 ein
  // echter, erreichbarer Wert und der Abstand zwischen 1 % und 2 % ist nicht
  // doppelt so bedeutsam wie der zwischen 50 % und 100 % — die
  // Verhältnis-Bewertung wäre dort schlicht falsch.
  //
  // ACHTUNG bei Erweiterungen: Eine logarithmische Skala verlangt einen
  // Wert > 0. Alle Fragen filtern zwar bereits auf getValue > 0, aber die
  // Skala selbst wird in ausRundenWerten() abgesichert.
  static const Set<String> kLogKategorien = {
    'gdpTotal',
    'military',
    'tourism',
    'olympics',
    'area',
    'population',
    'coastline',
    'gdpPerCapita',
    'internet',
    'minimumWage',
    'inflation',
  };

  /// Formatierfunktion für eine RankingCategory-ID, unabhängig vom
  /// tatsächlichen Wert. Ruft die jeweilige adaptive Funktion oben einmal
  /// mit einem großen Platzhalter-Wert auf (1e12 liegt über JEDER
  /// Mikrostaat-Sonderfall-Schwelle, siehe z.B. bipProKopf/flaeche/
  /// mindestlohn/kuestenlinie/olympiaMedaillen/inflationsrate) — landet so
  /// zuverlässig im "normalen" Zweig, dessen Format-Funktion (anders als
  /// z.B. bei flaeche() der Mikrostaat-Zweig) für JEDEN späteren Wert
  /// passt, weil sie selbst wertabhängig abkürzt (_fmtArea/_fmtPop/…).
  static String Function(double) _formatFuerRankingId(String id) =>
      switch (id) {
        'gdpPerCapita' => bipProKopf(1e12).format,
        'population' => bevoelkerung(1e12).format,
        'area' => flaeche(1e12).format,
        'lifeExpectancy' => lebenserwartung(1e12).format,
        'minimumWage' => mindestlohn(1e12).format,
        'coastline' => kuestenlinie(1e12).format,
        'gdpTotal' => bipGesamt(1e12).format,
        'internet' => internetGeschwindigkeit(1e12).format,
        'corruption' => korruptionsIndex(1e12).format,
        'press_freedom' => pressefreiheit(1e12).format,
        'happiness' => gluecksIndex(1e12).format,
        'tourism' => tourismusEinnahmen(1e12).format,
        'military' => militaerAusgaben(1e12).format,
        'birth_rate' => geburtenrate(1e12).format,
        'forest' => waldanteil(1e12).format,
        'alcohol' => alkoholkonsum(1e12).format,
        'olympics' => olympiaMedaillen(1e12).format,
        'highest_point' => hoechsterPunkt(1e12).format,
        'inflation' => inflationsrate(1e12).format,
        'debt' => staatsschulden(1e12).format,
        _ => (v) => v.round().toString(),
      };

  /// Berechnet EINE feste Skala aus den ECHTEN Werten [werteDieserRunde]
  /// (z.B. die 8 für den heutigen "Das große Schätzen"-Tag tatsächlich
  /// gezogenen Länder dieser Kategorie) — 15% Puffer auf beiden Seiten der
  /// Spanne, damit die Extremwerte nicht exakt am Rand des Sliders kleben.
  /// Bleibt unverändert für alle Fragen dieser Runde; ändert sich nur beim
  /// nächsten Tag (andere Länder/ggf. andere Kategorie).
  static SkalaErgebnis ausRundenWerten(
      String rankingId, List<double> werteDieserRunde) {
    final format = _formatFuerRankingId(rankingId);
    if (werteDieserRunde.isEmpty) {
      return SkalaErgebnis(min: 0, max: 100, schritt: 1, format: format);
    }
    final echtesMin = werteDieserRunde.reduce(min);
    final echtesMax = werteDieserRunde.reduce(max);

    // ── Logarithmische Skala ────────────────────────────────────────────────
    //
    // Der 15-%-Puffer wird hier MULTIPLIKATIV angelegt statt additiv. Das ist
    // nicht nur die passende Rechnung für eine Log-Achse, sondern auch der
    // Grund, warum die Untergrenze niemals 0 wird: sie entsteht durch Teilen
    // statt durch Abziehen. Additiv gepuffert wäre sie es dagegen fast immer —
    // 40 km Küste minus 15 % einer Spanne von 202 000 km ist negativ und wurde
    // bisher auf 0 geklemmt. Auf 0 ist der Logarithmus nicht definiert.
    //
    // Der Sicherheitszweig darunter greift trotzdem: kommt wider Erwarten ein
    // Wert <= 0 durch (alle Fragen filtern auf > 0), bleibt es linear, statt
    // hier zu rechnen, was nicht geht.
    if (kLogKategorien.contains(rankingId) && echtesMin > 0) {
      final verhaeltnis = echtesMax / echtesMin;
      // Alle fünf Länder zufällig gleich: kein Verhältnis, aus dem sich ein
      // Puffer ableiten liesse — dann fest das 1,5-fache nach beiden Seiten.
      //
      // Gedeckelt auf das Doppelte, und zwar aus einem sichtbaren Grund: 15 %
      // der Reglerlänge sind bei einer weiten Runde sehr viel. Bei einer
      // Bevölkerungsrunde von Vatikanstadt bis Indien wäre der Puffer das
      // 8,7-fache und das rechte Skalenende stünde bei 12 Milliarden
      // Einwohnern — mehr, als es Menschen gibt. Der Deckel greift nur bei
      // solchen Extremrunden; bei engeren liegt der Puffer ohnehin darunter
      // (Verhältnis 2 ergibt 1,11) und bleibt unverändert.
      final puffer = verhaeltnis > 1
          ? min(pow(verhaeltnis, 0.15).toDouble(), 2.0)
          : 1.5;
      final lo = echtesMin / puffer;
      final hi = echtesMax * puffer;
      return SkalaErgebnis(
        min: lo,
        max: hi,
        // Bei einer Log-Achse sitzen die Reglerstufen auf der Position, nicht
        // auf dem Wert — schritt wird dort nicht gebraucht und dient nur noch
        // als Notwert für Aufrufer, die ihn blind auslesen.
        schritt: _niceStep(hi - lo),
        format: format,
        logarithmisch: true,
      );
    }

    final spanne = echtesMax - echtesMin;
    // Falls alle gezogenen Länder zufällig denselben Wert haben (spanne=0):
    // Puffer relativ zum Wert selbst statt zur (dann nutzlosen) Spanne.
    final puffer = spanne > 0
        ? spanne * 0.15
        : (echtesMax.abs() * 0.15).clamp(1.0, double.infinity);
    var lo = echtesMin - puffer;
    var hi = echtesMax + puffer;
    if (istProzentKategorie(rankingId)) {
      lo = lo.clamp(0.0, 100.0);
      hi = hi.clamp(0.0, 100.0);
    } else {
      lo = lo.clamp(0.0, double.infinity);
    }
    // Sicherheits-Fallback: extremer Randfall bei dem der Prozent-Clamp
    // oben lo/hi auf denselben Wert zusammenzieht.
    if (hi <= lo) hi = lo + 1;
    final s = _niceStep(hi - lo);
    return SkalaErgebnis(
      min: _roundDown(lo, s),
      max: _roundUp(hi, s),
      schritt: s,
      format: format,
    );
  }

  /// Dispatcher: passende adaptive Skala für eine [RankingCategory]-ID (siehe
  /// country_rankings.dart) — deckt alle 20 dort definierten Kategorien ab,
  /// damit Preis-Schätzen dieselben Kategorien wie Higher/Lower und
  /// Ranking-Quiz nutzen kann.
  ///
  /// [seed] (optional): seed-basiert positioniert realVal an einer
  /// zufälligen statt immer niedrigen Stelle der Skala — siehe
  /// _positioniere(). Nur Preis-Schätzen übergibt aktuell einen Seed.
  static SkalaErgebnis fuerRankingId(String id, double realVal, [int? seed]) =>
      switch (id) {
        'gdpPerCapita' => bipProKopf(realVal, seed),
        'population' => bevoelkerung(realVal, seed),
        'area' => flaeche(realVal, seed),
        'lifeExpectancy' => lebenserwartung(realVal),
        'minimumWage' => mindestlohn(realVal, seed),
        'coastline' => kuestenlinie(realVal, seed),
        'gdpTotal' => bipGesamt(realVal, seed),
        'internet' => internetGeschwindigkeit(realVal),
        'corruption' => korruptionsIndex(realVal),
        'press_freedom' => pressefreiheit(realVal),
        'happiness' => gluecksIndex(realVal),
        'tourism' => tourismusEinnahmen(realVal),
        'military' => militaerAusgaben(realVal),
        'birth_rate' => geburtenrate(realVal),
        'forest' => waldanteil(realVal),
        'alcohol' => alkoholkonsum(realVal),
        'olympics' => olympiaMedaillen(realVal, seed),
        'highest_point' => hoechsterPunkt(realVal),
        'inflation' => inflationsrate(realVal, seed),
        'debt' => staatsschulden(realVal),
        _ => throw ArgumentError('Unbekannte RankingCategory-ID: $id'),
      };

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Schrittweite der linearen Skala — bestimmt zugleich die Zahl der
  /// Reglerstufen (Spanne geteilt durch Schritt).
  ///
  /// Zielt auf Spanne/500 statt wie früher auf Spanne/200. Weil auf den
  /// nächsten schönen Wert AUFgerundet wird (1/2/5 je Zehnerpotenz, im
  /// ungünstigsten Fall das 2,5-fache des Ziels), landet die Stufenzahl
  /// dadurch zwischen 200 und 500 statt bei rund 137.
  ///
  /// Warum das zählt: Die Punktzahl ist eine stetige Kurve, aber der Regler
  /// kann nur seine Stufen treffen. Bei 137 Stufen waren von 101 möglichen
  /// Punktwerten nur 58 erreichbar — 96 bis 99 gab es schlicht nicht, unter
  /// der vollen Punktzahl ging es direkt auf 96 weiter. Bei 400 Stufen sind es
  /// 95 von 101 und der erste Sprung beträgt einen Punkt.
  ///
  /// Die Reihe war zudem lückenhaft (0,01 · 0,05 · 0,1 …, ohne 0,02) — bei
  /// schmalen Skalen wie "Kinder pro Frau" (0,5 bis 7,5) sprang sie deshalb
  /// unnötig weit und kostete Stufen.
  static double _niceStep(double range) {
    if (range <= 0) return 1;
    const nice = <double>[
      0.001, 0.002, 0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5,
      1, 2, 5, 10, 20, 50, 100, 200, 500,
      1000, 2000, 5000, 10000, 20000, 50000,
      100000, 200000, 500000, 1000000, 2000000, 5000000,
      10000000, 20000000, 50000000, 100000000,
    ];
    final target = range / 500;
    for (final s in nice) {
      if (s >= target) return s;
    }
    return nice.last;
  }

  static double _roundDown(double v, double step) => (v / step).floor() * step;
  static double _roundUp(double v, double step) => (v / step).ceil() * step;

  static String _fmtInt(int n) {
    if (n <= 0) return '0';
    final sep = LocaleService.istEnglisch ? ',' : '.';
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(sep);
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _fmtPop(double v) {
    final en = LocaleService.istEnglisch;
    if (v >= 1e9) return '${_dec(v / 1e9, 2)} ${en ? 'B' : 'Mrd.'}';
    if (v >= 1e6) return '${_dec(v / 1e6, 1)} ${en ? 'M' : 'Mio.'}';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)} ${en ? 'K' : 'Tsd.'}';
    return '${v.toInt()} ${en ? 'people' : 'Pers.'}';
  }

  static String _fmtGross(double v) {
    final en = LocaleService.istEnglisch;
    if (v >= 1e12) return '${_dec(v / 1e12, 2)} ${en ? 'T' : 'Bio.'}';
    if (v >= 1e9) return '${_dec(v / 1e9, 1)} ${en ? 'B' : 'Mrd.'}';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(0)} ${en ? 'M' : 'Mio.'}';
    return _fmtInt(v.round());
  }

  static String _fmtArea(double v) {
    final en = LocaleService.istEnglisch;
    if (v >= 1e6) return '${_dec(v / 1e6, 2)} ${en ? 'M' : 'Mio.'} km²';
    if (v >= 1000) return '${_fmtInt(v.round())} km²';
    return '${v.toStringAsFixed(0)} km²';
  }
}
