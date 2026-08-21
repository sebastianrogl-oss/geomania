import '../services/locale_service.dart';
import 'uebersetzungen_ads.dart';
import 'uebersetzungen_anzeigename.dart';
import 'uebersetzungen_categorymatch.dart';
import 'uebersetzungen_challenges.dart';
import 'uebersetzungen_connections.dart';
import 'uebersetzungen_currencyquiz.dart';
import 'uebersetzungen_economicblocks.dart';
import 'uebersetzungen_erinnerungen.dart';
import 'uebersetzungen_financehub.dart';
import 'uebersetzungen_flagquiz.dart';
import 'uebersetzungen_gdpquiz.dart';
import 'uebersetzungen_higherlower.dart';
import 'uebersetzungen_lernen.dart';
import 'uebersetzungen_quiz.dart';
import 'laender_fakten_en.dart';
import 'laender_gebaeude_en.dart';
import 'laender_grenzketten_en.dart';
import 'schaetzen_fakten_en.dart';
import 'uebersetzungen_lernpfad.dart';
import 'uebersetzungen_lernwelten.dart';
import 'uebersetzungen_mapquiz.dart';
import 'uebersetzungen_marktbriefing.dart';
import 'uebersetzungen_outlinequiz.dart';
import 'uebersetzungen_portfolio.dart';
import 'uebersetzungen_portfolio_aufloesung.dart';
import 'uebersetzungen_portfolio_investieren.dart';
import 'uebersetzungen_portfoliobeispiel.dart';
import 'portfolio_news_en.dart';
import 'portfolio_sektoren_kontinente_en.dart';
import 'uebersetzungen_profil.dart';
import 'uebersetzungen_ranking.dart';
import 'uebersetzungen_rangliste.dart';
import 'uebersetzungen_rankingquiz.dart';
import 'uebersetzungen_schaetzen.dart';
import 'uebersetzungen_sortierspiel.dart';
import 'spielkategorien_en.dart';
import 'uebersetzungen_settings.dart';
import 'uebersetzungen_stationquiz.dart';
import 'uebersetzungen_tagesspiele.dart';
import 'uebersetzungen_waehrungen.dart';
import 'waehrungen_namen_en.dart';
import 'uebersetzungen_widgets.dart';
import 'uebersetzungen_wirtschaftssektoren.dart';
import 'wirtschaftssektoren_en.dart';
import 'wirtschaftssektoren_frage_en.dart';
import 'wirtschaftssektoren_daten_en.dart';

// Zentrale Übersetzungstabelle (Deutsch -> Englisch). Statt eines
// offiziellen ARB-/gen-l10n-Setups (zu viel Umbau-Overhead für eine bereits
// fertige, komplett deutschsprachige Codebase) wird jeder deutsche String
// zur Laufzeit über diese Tabelle nachgeschlagen. Auf mehrere Teil-Dateien
// aufgeteilt (pro Datenquelle/Screen-Gruppe), damit parallele Bearbeitung
// an unabhängigen Dateien möglich ist, ohne dass sich Änderungen an EINER
// riesigen Map gegenseitig überschreiben.
final Map<String, String> uebersetzungen = {
  ...uebersetzungenAds,
  ...uebersetzungenAnzeigename,
  ...uebersetzungenCategoryMatch,
  ...uebersetzungenChallenges,
  ...uebersetzungenConnections,
  ...uebersetzungenCurrencyQuiz,
  ...uebersetzungenEconomicBlocks,
  ...uebersetzungenErinnerungen,
  ...uebersetzungenFinanceHub,
  ...uebersetzungenFlagQuiz,
  ...uebersetzungenGdpQuiz,
  ...uebersetzungenLernen,
  ...uebersetzungenQuiz,
  ...uebersetzungenSettings,
  ...uebersetzungenLernpfad,
  ...uebersetzungenLernwelten,
  ...uebersetzungenMapQuiz,
  ...uebersetzungenStationQuiz,
  ...uebersetzungenTagesspiele,
  ...uebersetzungenWaehrungen,
  ...waehrungsNamenEn,
  ...waehrungsFunFactsEn,
  ...uebersetzungenHigherLower,
  ...uebersetzungenWidgets,
  ...uebersetzungenRanking,
  ...uebersetzungenRangliste,
  ...uebersetzungenRankingQuiz,
  ...uebersetzungenSchaetzen,
  ...uebersetzungenSortierSpiel,
  ...uebersetzungenPortfolio,
  ...uebersetzungenPortfolioAufloesung,
  ...uebersetzungenMarktbriefing,
  ...uebersetzungenOutlineQuiz,
  ...uebersetzungenPortfolioInvestieren,
  ...uebersetzungenPortfolioBeispiel,
  ...portfolioNewsEn,
  ...portfolioSektorenEn,
  ...portfolioKontinenteEn,
  ...uebersetzungenProfil,
  ...laenderFaktenEn,
  ...laenderGebaeudeEn,
  ...laenderGrenzkettenEn,
  ...schaetzenFaktenEn,
  ...wirtschaftssektorenFrageEn,
  ...wirtschaftssektorenEn,
  ...exportgueterEn,
  ...sektorBeschreibungenEn,
  ...sektorFunFactsEn,
  ...uebersetzungenWirtschaftssektoren,
  ...spielkategorienEn,
};

/// Übersetzt [de] nach Englisch, wenn LocaleService.istEnglisch — sonst wird
/// [de] unverändert zurückgegeben. [p] ersetzt {platzhalter} im Ergebnis
/// (für Strings mit interpolierten Werten, z.B. t('{n} Punkte', {'n': '5'})).
String t(String de, [Map<String, String>? p]) {
  var s = LocaleService.istEnglisch ? (uebersetzungen[de] ?? de) : de;
  if (p != null) {
    for (final e in p.entries) {
      s = s.replaceAll('{${e.key}}', e.value);
    }
  }
  return s;
}
