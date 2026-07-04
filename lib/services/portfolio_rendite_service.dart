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
double nachrichtenEffekt(String iso, List<MarktNews> heutigeNews) {
  double e = 0;
  final profil = landProfile[iso]!;
  for (final n in heutigeNews) {
    if (n.gewinner.contains(iso)) e += n.staerke.abs();
    if (n.verlierer.contains(iso)) e -= n.staerke.abs();
    if (profil.sektoren.contains(n.sektor)) e += n.staerke * 0.5;
  }
  return e;
}

double trendEffekt(String iso, MakroTrend trend) {
  final profil = landProfile[iso]!;
  return profil.sektoren.contains(trend.sektor) ? trend.staerke : 0;
}

/// Erwartete Rendite in % — Basis + News + Trend, OHNE die zufällige
/// Schwankung (die bleibt vor der Auflösung bewusst verborgen).
double erwarteteRendite(String iso, List<MarktNews> heutigeNews, MakroTrend trend) {
  final profil = landProfile[iso]!;
  return profil.basisWachstum + nachrichtenEffekt(iso, heutigeNews) + trendEffekt(iso, trend);
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
  return erwarteteRendite(iso, heutigeNews, trend) + zufallsSchwankung(iso, tagesSeed);
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
