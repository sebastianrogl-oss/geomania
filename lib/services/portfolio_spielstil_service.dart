import 'portfolio_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Spielstil-Label (Phase 8)
// Ordnet dem Spieler nach ~7 gespielten Tagen automatisch eine von vier
// Identitäten zu, basierend auf seinem bisherigen Investitionsverhalten.
// ══════════════════════════════════════════════════════════════════════════════

const int kSpielstilMindestTage = 7;

class SpielstilErgebnis {
  final String titel;
  final String emoji;
  const SpielstilErgebnis({required this.titel, required this.emoji});
}

/// Gibt null zurück, solange noch nicht genug Tage gespielt wurden.
SpielstilErgebnis? berechneSpielstil(PortfolioSpielstilRohdaten daten) {
  if (daten.tage < kSpielstilMindestTage || daten.auswahlen == 0) return null;

  final avgEffektiv = daten.effektivSumme / daten.tage; // 1.0 (konzentriert) - 3.0 (breit)
  final avgRisiko = daten.risikoSumme / daten.tage;      // 0.0 - 1.0
  final newsQuote = daten.newsTreffer / daten.auswahlen; // 0.0 - 1.0
  final trendQuote = daten.trendTreffer / daten.auswahlen; // 0.0 - 1.0

  // Vier Persönlichkeits-Achsen — die höchste gewinnt.
  final diversifiziert = avgEffektiv / 3.0;
  final scores = <String, double>{
    'sicher':      diversifiziert * (1 - avgRisiko),               // breit + stabil
    'zocker':      (1 - diversifiziert) * avgRisiko,                // konzentriert + riskant
    'spezialist':  trendQuote * (1 - (avgRisiko - 0.5).abs() * 2).clamp(0.0, 1.0), // Trend-treu, mittleres Risiko
    'jaeger':      newsQuote,                                       // folgt den Schlagzeilen
  };

  final bester = scores.entries.reduce((a, b) => b.value > a.value ? b : a).key;

  switch (bester) {
    case 'sicher':
      return const SpielstilErgebnis(titel: 'Der Sichere', emoji: '🛡️');
    case 'zocker':
      return const SpielstilErgebnis(titel: 'Der Zocker', emoji: '🎰');
    case 'spezialist':
      return const SpielstilErgebnis(titel: 'Der Spezialist', emoji: '🎯');
    case 'jaeger':
    default:
      return const SpielstilErgebnis(titel: 'Der Jäger', emoji: '🦅');
  }
}
