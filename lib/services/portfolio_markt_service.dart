import 'dart:math';
import '../data/portfolio_daten.dart';
import 'tages_seed_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Tagesmarkt (Phase 4)
// Seed-basierte, für alle Spieler identische Auswahl von News und Länder-Pool.
// ══════════════════════════════════════════════════════════════════════════════

class TagesMarkt {
  final List<MarktNews> news;
  final List<String> laenderPool; // 16 ISO-Codes, seed-basiert
  final bool bullish;             // Ø Basiswachstum des heutigen Pools positiv?

  const TagesMarkt({
    required this.news,
    required this.laenderPool,
    required this.bullish,
  });
}

TagesMarkt ladeTagesMarkt() {
  final basisSeed = TagesSeedService.seedFuer('portfolio');

  final news = getHeutigeNews(basisSeed);

  final pool = (landProfile.keys.toList()..shuffle(Random(basisSeed + 41)))
      .take(16)
      .toList();

  final durchschnitt = pool
          .map((iso) => landProfile[iso]!.basisWachstum)
          .fold(0.0, (a, b) => a + b) /
      pool.length;

  return TagesMarkt(news: news, laenderPool: pool, bullish: durchschnitt >= 0);
}

// ── Tägliche News-Auswahl ────────────────────────────────────────────────────
// Feste 3-Slot-Struktur (kein zufälliger Typ-Mix mehr): Slot 1 = einzelLand,
// Slot 2 = sektorKombination, Slot 3 = kontinentsAllianz. Der alte "standard"-
// Typ (newsPool) ist damit nicht mehr Teil der täglichen Ziehung.
// Offsets bewusst NICHT +41 (das ist bereits für den Länder-Pool-Shuffle oben
// belegt), damit sich die Ziehungen nicht zufällig überschneiden.

/// Ca. jeder 10. Tag ist ein Extremereignis-Tag — einer der 3 festen Slots
/// wird dann durch ein extremEreignis ersetzt, die 3er-Struktur bleibt erhalten.
bool istExtremEreignisTag(int seed) {
  final rng = Random(seed + 43);
  return rng.nextInt(10) == 0;
}

List<MarktNews> getHeutigeNews(int seed) {
  final slots = [
    _ziehAusPool(einzelLandPool, Random(seed + 44), 1).first,
    _ziehAusPool(sektorKombinationPool, Random(seed + 46), 1).first,
    _ziehAusPool(kontinentsAllianzPool, Random(seed + 45), 1).first,
  ];

  if (istExtremEreignisTag(seed)) {
    // Ersetzt Slot 1 (einzelLand) oder Slot 3 (kontinentsAllianz) — Slot 2
    // (sektorKombination) bleibt bewusst unangetastet, damit der Sektor-Kombo-
    // Bonus jeden Tag verlässlich verfügbar ist.
    final ersetzterSlot = Random(seed + 47).nextBool() ? 0 : 2;
    slots[ersetzterSlot] =
        _ziehAusPool(extremEreignisPool, Random(seed + 48), 1).first;
  }

  return slots;
}

List<MarktNews> _ziehAusPool(List<MarktNews> pool, Random rng, int anzahl) {
  return (List.of(pool)..shuffle(rng)).take(anzahl).toList();
}
