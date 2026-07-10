import 'dart:math';
import '../data/portfolio_daten.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Rendite-Berechnung
// Deterministischer Teil (Basis/News/Trend) für die "Chance"-Balken in Screen 2,
// plus die seed-basierte Zufalls-Schwankung für die tatsächliche Tagesrendite.
// ══════════════════════════════════════════════════════════════════════════════

// Gewinner bekommen immer +|staerke|, Verlierer immer -|staerke| — unabhängig
// vom Vorzeichen der News (z.B. "Ölpreis bricht ein" hat staerke=-2.0, aber die
// im Klartext genannten Gewinner sollen trotzdem profitieren). Nur die
// Sektor-Kopplung übernimmt das rohe Vorzeichen der News.
//
// kontinentsAllianz/sektorKombination wirken NICHT hier, sondern nur als
// eigene Portfolio-Boni (siehe berechneAllianzBonus/berechneSektorKomboBonus)
// — tragen daher nichts zur einzelnen Länder-Rendite bei.
// extremEreignis hat keinen fixen staerke-Wert, sondern eine Bandbreite; der
// tatsächliche (seed-basierte) Wert wird über extremEreignisWert() gezogen.
double nachrichtenEffekt(String iso, List<MarktNews> heutigeNews, int tagesSeed) {
  double e = 0;
  final profil = landProfile[iso]!;
  for (final n in heutigeNews) {
    if (n.typ == NewsTyp.kontinentsAllianz || n.typ == NewsTyp.sektorKombination) {
      continue;
    }
    if (n.typ == NewsTyp.extremEreignis) {
      if (n.gewinner.contains(iso) || n.verlierer.contains(iso)) {
        e += extremEreignisWert(n, tagesSeed);
      }
      continue;
    }
    if (n.gewinner.contains(iso)) e += n.staerke!.abs();
    if (n.verlierer.contains(iso)) e -= n.staerke!.abs();
    if (n.sektor != null && profil.sektoren.contains(n.sektor)) {
      e += n.staerke! * 0.5;
    }
  }
  return e;
}

/// Zieht den tatsächlichen (verborgenen) Effekt eines extremEreignis
/// seed-basiert innerhalb seiner Bandbreite — für alle Spieler an diesem Tag
/// identisch, aber vor der Auflösung nicht sichtbar (nur die Spanne selbst
/// wird vorab angezeigt).
double extremEreignisWert(MarktNews n, int tagesSeed) {
  final min = n.bandbreiteMin!;
  final max = n.bandbreiteMax!;
  final rng = Random(tagesSeed + n.titel.hashCode);
  return min + rng.nextDouble() * (max - min);
}

double trendEffekt(String iso, MakroTrend trend) {
  final profil = landProfile[iso]!;
  return profil.sektoren.contains(trend.sektor) ? trend.staerke : 0;
}

/// Erwartete Rendite in % — Basis + News + Trend, OHNE die zufällige
/// Schwankung (die bleibt vor der Auflösung bewusst verborgen).
double erwarteteRendite(
    String iso, List<MarktNews> heutigeNews, MakroTrend trend, int tagesSeed) {
  final profil = landProfile[iso]!;
  return profil.basisWachstum +
      nachrichtenEffekt(iso, heutigeNews, tagesSeed) +
      trendEffekt(iso, trend);
}

/// Seed-basierte Zufalls-Schwankung: ±6% max bei vollem Risiko. Für alle
/// Spieler an diesem Tag identisch (fair), aber vor der Auflösung nicht sichtbar.
double zufallsSchwankung(String iso, int tagesSeed) {
  final profil = landProfile[iso]!;
  final rng = Random(tagesSeed + iso.hashCode);
  return (rng.nextDouble() * 2 - 1) * profil.risiko * 6.0;
}

/// Tatsächliche Tagesrendite in % — erwartete Rendite plus Zufalls-Schwankung.
double tatsaechlicheRendite(
    String iso, List<MarktNews> heutigeNews, MakroTrend trend, int tagesSeed) {
  return erwarteteRendite(iso, heutigeNews, trend, tagesSeed) +
      zufallsSchwankung(iso, tagesSeed);
}

/// Kontinents-Synergie: alle gewählten Länder ein Kontinent → +6%,
/// mindestens zwei gemeinsam → +2%, sonst 0.
int kontinentsBonusProzent(List<String> isos) {
  final konts = isos.map((iso) => landKontinent[iso]).toList();
  if (konts.toSet().length == 1) return 6;
  final counts = <String?, int>{};
  for (final k in konts) {
    counts[k] = (counts[k] ?? 0) + 1;
  }
  if (counts.values.any((c) => c >= 2)) return 2;
  return 0;
}

// ── Allianz-Bonus (NEU, unabhängig vom Kontinents-Bonus oben) ────────────────
// kontinentsBonusProzent() belohnt Länder AUS DEMSELBEN Kontinent.
// berechneAllianzBonus() belohnt das GENAUE GEGENTEIL: mind. 1 Land aus JEDEM
// der von einer aktiven kontinentsAllianz-News geforderten Kontinente. Beide
// Mechanismen sind unabhängig, können gleichzeitig greifen und addieren sich.

/// Die kontinentsAllianz-News von heute, deren Bedingung tatsächlich erfüllt
/// ist — für die zeilenweise Anzeige im Auflösungs-Screen.
List<MarktNews> erfuellteAllianzNews(
    List<String> gewaehlteLaender, List<MarktNews> heutigeNews) {
  final vorhandeneKontinente =
      gewaehlteLaender.map((iso) => landKontinent[iso]).toSet();
  return heutigeNews.where((n) {
    if (n.typ != NewsTyp.kontinentsAllianz) return false;
    return n.allianzKontinente!.every(vorhandeneKontinente.contains);
  }).toList();
}

/// Summe der Boni aller heute erfüllten Allianzen (Prozentpunkte).
double berechneAllianzBonus(
    List<String> gewaehlteLaender, List<MarktNews> heutigeNews) {
  return erfuellteAllianzNews(gewaehlteLaender, heutigeNews)
      .fold(0.0, (summe, n) => summe + n.allianzBonus!);
}

// ── Sektor-Kombo-Bonus (NEU, unabhängig von Kontinents-/Allianz-Bonus) ──────
// Wirkt, wenn tatsächlich in BEIDE von einer sektorKombination-News genannten
// Sektoren investiert wurde (Gewicht > 0%) — unabhängig davon, welche Länder
// konkret gewählt sind, solange sie diese Sektoren abdecken.

/// Aggregiertes Gewicht (Summe der Länder-Prozente) je Sektor, basierend auf
/// den PRIMÄREN und SEKUNDÄREN Sektoren jedes gewählten Landes.
Map<String, double> berechneSektorGewichtung(Map<String, int> gewichte) {
  final result = <String, double>{};
  for (final eintrag in gewichte.entries) {
    if (eintrag.value <= 0) continue;
    for (final sektor in landProfile[eintrag.key]?.sektoren ?? const []) {
      result[sektor] = (result[sektor] ?? 0) + eintrag.value;
    }
  }
  return result;
}

/// Die sektorKombination-News von heute, deren Bedingung tatsächlich erfüllt
/// ist — für die zeilenweise Anzeige im Auflösungs-Screen.
List<MarktNews> erfuellteSektorKombos(
    Map<String, double> sektorGewichtung, List<MarktNews> heutigeNews) {
  return heutigeNews.where((n) {
    if (n.typ != NewsTyp.sektorKombination) return false;
    return n.sektorKombo!.every((s) => (sektorGewichtung[s] ?? 0) > 0);
  }).toList();
}

/// Summe der Boni aller heute erfüllten Sektor-Kombinationen (Prozentpunkte).
double berechneSektorKomboBonus(
    Map<String, double> sektorGewichtung, List<MarktNews> heutigeNews) {
  return erfuellteSektorKombos(sektorGewichtung, heutigeNews)
      .fold(0.0, (summe, n) => summe + n.sektorKomboBonus!);
}
