import 'dart:math';

class SkalaErgebnis {
  final double min;
  final double max;
  final double schritt;
  final String Function(double) format;

  const SkalaErgebnis({
    required this.min,
    required this.max,
    required this.schritt,
    required this.format,
  });

  int get divisionen => ((max - min) / schritt).round().clamp(50, 500);
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
        format: (v) => '\$ ${v.round()}/Monat');
    }
    final loRoh = (realVal * 0.2).clamp(0.0, realVal * 0.5);
    final hiRoh = _hiMitHeadroom(realVal, 3.0, 1.5, 7000.0);
    final (lo, hi) = _positioniere(realVal, loRoh, hiRoh, seed);
    final s = _niceStep(hi - lo);
    return SkalaErgebnis(
      min: _roundDown(lo, s),
      max: _roundUp(hi, s),
      schritt: s,
      format: (v) => '\$ ${v.round()}/Monat',
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
      format: (v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} J.',
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
        format: (v) => v.toStringAsFixed(2).replaceAll('.', ','));

  // ── Tourismuseinnahmen (Mrd. USD) ────────────────────────────────────────────
  static SkalaErgebnis tourismusEinnahmen(double _) => SkalaErgebnis(
        min: 0, max: 250, schritt: 1,
        format: (v) => '${v.round()} Mrd. \$');

  // ── Militärausgaben (Mrd. USD) ───────────────────────────────────────────────
  static SkalaErgebnis militaerAusgaben(double _) => SkalaErgebnis(
        min: 0, max: 900, schritt: 1,
        format: (v) => '${v.round()} Mrd. \$');

  // ── Geburtenrate (Kinder pro Frau) ──────────────────────────────────────────
  static SkalaErgebnis geburtenrate(double _) => SkalaErgebnis(
        min: 0.5, max: 7.5, schritt: 0.1,
        format: (v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} Kinder/Frau');

  // ── Waldanteil (%) ───────────────────────────────────────────────────────────
  static SkalaErgebnis waldanteil(double _) => SkalaErgebnis(
        min: 0, max: 100, schritt: 1,
        format: (v) => '${v.round()} %');

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
        format: (v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} L/Kopf');

  // ── Olympia-Medaillen (Anzahl gesamt) ─────────────────────────────────────────
  static SkalaErgebnis olympiaMedaillen(double realVal, [int? seed]) {
    if (realVal < 10) {
      return SkalaErgebnis(
          min: 0, max: (realVal * 6).clamp(5.0, 50.0), schritt: 1,
          format: (v) => '${v.round()} Medaillen');
    }
    final loRoh = (realVal * 0.15).clamp(1.0, realVal * 0.45);
    final hiRoh = _hiMitHeadroom(realVal, 4.0, 2.0, 3000.0);
    final (lo, hi) = _positioniere(realVal, loRoh, hiRoh, seed);
    final s = _niceStep(hi - lo);
    return SkalaErgebnis(
      min: _roundDown(lo, s),
      max: _roundUp(hi, s),
      schritt: s,
      format: (v) => '${v.round()} Medaillen',
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
          format: (v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} %');
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
      format: (v) => '${v.toStringAsFixed(1).replaceAll('.', ',')} %',
    );
  }

  // ── Staatsschulden (% des BIP) ─────────────────────────────────────────────────
  static SkalaErgebnis staatsschulden(double _) => SkalaErgebnis(
        min: 0, max: 300, schritt: 1,
        format: (v) => '${v.round()} % BIP');

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

  static double _niceStep(double range) {
    if (range <= 0) return 1;
    const nice = <double>[0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 20, 50, 100, 200,
      500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000, 1000000];
    final target = range / 200;
    for (final s in nice) {
      if (s >= target) return s;
    }
    return nice.last;
  }

  static double _roundDown(double v, double step) => (v / step).floor() * step;
  static double _roundUp(double v, double step) => (v / step).ceil() * step;

  static String _fmtInt(int n) {
    if (n <= 0) return '0';
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _fmtPop(double v) {
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2).replaceAll('.', ',')} Mrd.';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1).replaceAll('.', ',')} Mio.';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)} Tsd.';
    return '${v.toInt()} Pers.';
  }

  static String _fmtGross(double v) {
    if (v >= 1e12) return '${(v / 1e12).toStringAsFixed(2).replaceAll('.', ',')} Bio.';
    if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(1).replaceAll('.', ',')} Mrd.';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(0)} Mio.';
    return _fmtInt(v.round());
  }

  static String _fmtArea(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2).replaceAll('.', ',')} Mio. km²';
    if (v >= 1000) return '${_fmtInt(v.round())} km²';
    return '${v.toStringAsFixed(0)} km²';
  }
}
