class TagesSeedService {
  static int get heutigerSeed {
    final n = DateTime.now();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  static int seedFuer(String challenge) {
    const offsets = {
      'preis': 0,
      'higher_lower': 1000,
      'ranking_game': 2000,
      'portfolio': 3000,
      'portfolio_trend': 3500,
      'portfolio_gewichtung': 4000,
    };
    return heutigerSeed + (offsets[challenge] ?? 0);
  }

  // Start position for preis schätzen slider (15-45% of scale)
  static double startBruch(int frageIndex) {
    // Using a simple deterministic formula based on seed + index
    final v = (heutigerSeed * 1664525 + frageIndex * 1013904223) & 0x7FFFFFFF;
    return 0.15 + (v % 1000) / 1000.0 * 0.30;
  }
}
