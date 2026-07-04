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

  final news = (List.of(newsPool)..shuffle(Random(basisSeed + 7)))
      .take(3)
      .toList();

  final pool = (landProfile.keys.toList()..shuffle(Random(basisSeed + 41)))
      .take(16)
      .toList();

  final durchschnitt = pool
          .map((iso) => landProfile[iso]!.basisWachstum)
          .fold(0.0, (a, b) => a + b) /
      pool.length;

  return TagesMarkt(news: news, laenderPool: pool, bullish: durchschnitt >= 0);
}
