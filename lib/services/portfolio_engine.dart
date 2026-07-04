import '../data/portfolio_daten.dart';
import 'portfolio_rendite_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Tages-Engine (Phase 6)
// Fasst die Rendite-Berechnung für ein komplettes Depot zu einem
// nachvollziehbaren, zeilenweise aufschlüsselbaren Ergebnis zusammen.
// ══════════════════════════════════════════════════════════════════════════════

class PortfolioLandBeitrag {
  final String iso;
  final int anteilProzent;
  final double basis;
  final double news;
  final List<String> newsNamen; // Titel der News, die dieses Land beeinflusst haben
  final double trend;
  final double schwankung;
  final double tagesRendite;   // Basis + News + Trend + Schwankung
  final double beitragProzent; // tagesRendite * anteil

  const PortfolioLandBeitrag({
    required this.iso,
    required this.anteilProzent,
    required this.basis,
    required this.news,
    required this.newsNamen,
    required this.trend,
    required this.schwankung,
    required this.tagesRendite,
    required this.beitragProzent,
  });
}

class PortfolioTagesErgebnis {
  final List<PortfolioLandBeitrag> beitraege;
  final int kontinentsBonus; // Prozentpunkte
  final double depotRenditeGesamt; // inkl. Kontinents-Bonus
  final double altesKapital;
  final double neuesKapital;
  final double gewichtetesRisiko; // 0.0-1.0
  final double effektiveLaenderzahl; // Diversifikations-Maß (1 = konzentriert, 3 = breit)
  final int newsTrefferAnzahl;
  final int trendTrefferAnzahl; // Anzahl gewählter Länder, die vom Makro-Trend profitieren

  const PortfolioTagesErgebnis({
    required this.beitraege,
    required this.kontinentsBonus,
    required this.depotRenditeGesamt,
    required this.altesKapital,
    required this.neuesKapital,
    required this.gewichtetesRisiko,
    required this.effektiveLaenderzahl,
    required this.newsTrefferAnzahl,
    required this.trendTrefferAnzahl,
  });
}

PortfolioTagesErgebnis berechneTagesErgebnis({
  required Map<String, int> gewichte, // iso -> Prozent, Summe 100
  required List<MarktNews> heutigeNews,
  required MakroTrend trend,
  required double altesKapital,
  required int tagesSeed,
}) {
  final beitraege = <PortfolioLandBeitrag>[];
  var depotRendite = 0.0;
  var risikoSumme = 0.0;
  var herfindahl = 0.0;
  var newsTreffer = 0;
  var trendTreffer = 0;

  for (final eintrag in gewichte.entries) {
    final iso = eintrag.key;
    final anteil = eintrag.value / 100.0;
    final profil = landProfile[iso]!;

    final basis = profil.basisWachstum;
    final news = nachrichtenEffekt(iso, heutigeNews);
    final newsNamen = heutigeNews
        .where((n) =>
            n.gewinner.contains(iso) ||
            n.verlierer.contains(iso) ||
            profil.sektoren.contains(n.sektor))
        .map((n) => n.titel)
        .toList();
    final trendWert = trendEffekt(iso, trend);
    final schwankung = zufallsSchwankung(iso, tagesSeed);
    final tagesRendite = basis + news + trendWert + schwankung;
    final beitrag = tagesRendite * anteil;

    beitraege.add(PortfolioLandBeitrag(
      iso: iso,
      anteilProzent: eintrag.value,
      basis: basis,
      news: news,
      newsNamen: newsNamen,
      trend: trendWert,
      schwankung: schwankung,
      tagesRendite: tagesRendite,
      beitragProzent: beitrag,
    ));

    depotRendite += beitrag;
    risikoSumme += anteil * profil.risiko;
    herfindahl += anteil * anteil;
    if (newsNamen.isNotEmpty &&
        heutigeNews.any((n) => n.gewinner.contains(iso) || n.verlierer.contains(iso))) {
      newsTreffer++;
    }
    if (trendWert != 0) trendTreffer++;
  }

  final kontBonus = kontinentsBonusProzent(gewichte.keys.toList());
  depotRendite += kontBonus;

  final neuesKapital = altesKapital * (1 + depotRendite / 100);

  return PortfolioTagesErgebnis(
    beitraege: beitraege,
    kontinentsBonus: kontBonus,
    depotRenditeGesamt: depotRendite,
    altesKapital: altesKapital,
    neuesKapital: neuesKapital,
    gewichtetesRisiko: risikoSumme,
    effektiveLaenderzahl: herfindahl == 0 ? 0 : 1 / herfindahl,
    newsTrefferAnzahl: newsTreffer,
    trendTrefferAnzahl: trendTreffer,
  );
}
