import '../l10n/abzeichen_uebersetzungen_en.dart';
import '../services/locale_service.dart';

/// Alle Daten, die zur Auswertung der 30 Abzeichen-Bedingungen nötig sind —
/// wird einmalig frisch aus den bestehenden Datenquellen (Streak/Spieltage,
/// Lernpfad-Streak, Kontinent-/Stationsfortschritt, Challenge-Rekorde)
/// zusammengebaut, dann werden alle Bedingungen synchron dagegen geprüft.
class AbzeichenKontext {
  /// Challenge-ID -> aktueller Serien-Zähler dieser Challenge.
  final Map<String, int> streaksProChallenge;
  /// Wurde bei DIESEM Challenge-Abschluss die Maximalpunktzahl erreicht?
  final bool heutePerfekt;
  /// Wurde bei DIESEM Challenge-Abschluss ein neuer persönlicher Rekord aufgestellt?
  final bool neuerRekordHeute;
  /// Wurden heute bereits alle 4 Tages-Challenges gespielt?
  final bool alleChallengesHeute;
  /// Aktuelle allgemeine App-Streak (Lernpfad, aus fortschritt_service.dart).
  final int appStreak;
  /// Challenge-ID -> aktueller Allzeit-Bestwert (ChallengeRekordService.getRekord).
  final Map<String, int?> rekordProChallenge;
  /// IDs der Lernwelten (Kontinente), deren Stationen zu 100% abgeschlossen sind.
  final Set<String> abgeschlosseneWelten;
  /// Gesamtzahl abgeschlossener Stationen im Lernpfad, über alle Kontinente hinweg.
  final int gesamtAbgeschlosseneStationen;

  const AbzeichenKontext({
    required this.streaksProChallenge,
    required this.heutePerfekt,
    required this.neuerRekordHeute,
    required this.alleChallengesHeute,
    required this.appStreak,
    this.rekordProChallenge = const {},
    this.abgeschlosseneWelten = const {},
    this.gesamtAbgeschlosseneStationen = 0,
  });

  int get maxChallengeStreak => streaksProChallenge.values.isEmpty
      ? 0
      : streaksProChallenge.values.reduce((a, b) => a > b ? a : b);
}

enum AbzeichenTier { bronze, silber, gold }

enum AbzeichenKategorie {
  serien,
  kontinente,
  meilensteine,
  challenges,

  /// Nicht erspielbar, nur verliehen — siehe [istVerliehen].
  ///
  /// Bekommt bewusst KEINEN eigenen Reiter im Münzalbum: fünf Reiter
  /// schneiden auf 320 und 360 px schon bei normaler Schrift "Meilensteine"
  /// und "Challenges" ab (gemessen: 52 px Platz für 69 px Text). Die
  /// Ehrenmünzen hängen deshalb unten an der letzten Album-Seite — was der
  /// Sache auch näher kommt, sie stehen damit ganz am Ende der Mappe.
  ehrung,
}

class Abzeichen {
  final String id;
  final String nameDe;
  final String beschreibungDe;
  final String emoji;
  final AbzeichenTier tier;
  final AbzeichenKategorie kategorie;
  final bool Function(AbzeichenKontext) istErreicht;

  const Abzeichen({
    required this.id,
    required this.nameDe,
    required this.beschreibungDe,
    required this.emoji,
    required this.tier,
    required this.kategorie,
    required this.istErreicht,
  });

  // Computed statt gespeichertes Feld: gleiches Muster wie CountryRanking.name
  // (country_rankings.dart) — jede bestehende `.name`/`.beschreibung`-Stelle
  // bleibt unverändert funktionsfähig und wird automatisch lokalisiert.
  String get name =>
      LocaleService.istEnglisch ? (abzeichenNamenEn[id] ?? nameDe) : nameDe;
  String get beschreibung => LocaleService.istEnglisch
      ? (abzeichenBeschreibungenEn[id] ?? beschreibungDe)
      : beschreibungDe;
}

// ── Serien & Erfolge ───────────────────────────────────────────────────────────

bool _streak3(AbzeichenKontext k) => k.maxChallengeStreak >= 3;
bool _streak7(AbzeichenKontext k) => k.maxChallengeStreak >= 7;
bool _streak30(AbzeichenKontext k) => k.maxChallengeStreak >= 30;
bool _perfekt(AbzeichenKontext k) => k.heutePerfekt;
bool _neuerRekord(AbzeichenKontext k) => k.neuerRekordHeute;
bool _alleChallenges(AbzeichenKontext k) => k.alleChallengesHeute;
bool _streakApp30(AbzeichenKontext k) => k.appStreak >= 30;

// ── Kontinente ─────────────────────────────────────────────────────────────────

bool _kontinent(AbzeichenKontext k, String weltId) =>
    k.abgeschlosseneWelten.contains(weltId);

// ── Meilensteine ───────────────────────────────────────────────────────────────
//
// Gesamtzahl Stationen im Lernpfad: 594 (7 Welten, siehe lernpfad_data.dart).

bool _stationen25(AbzeichenKontext k) => k.gesamtAbgeschlosseneStationen >= 25;
bool _stationen50(AbzeichenKontext k) => k.gesamtAbgeschlosseneStationen >= 50;
bool _stationen100(AbzeichenKontext k) => k.gesamtAbgeschlosseneStationen >= 100;
bool _stationenAlle(AbzeichenKontext k) => k.gesamtAbgeschlosseneStationen >= 594;

// ── Tages-Challenge-Punkte-Stufen ──────────────────────────────────────────────
//
// Schwellenwerte je Challenge (Design-Entscheidung, kein fester Vorgabewert
// aus dem Spiel selbst):
// - preis: Rekord ist eine Punktzahl mit festem Maximum 500/Runde
//   (5 Fragen x 100 Punkte).
// - ranking_game: dasselbe Muster, dort weiterhin 800/Runde.
// - higher_lower: Rekord ist die beste Serie ohne Deckel -> kleinere Schwellen.
// - portfolio: Rekord ist der beste Tagesgewinn in $ (Startkapital 1000).

bool _rekordMind(AbzeichenKontext k, String challengeId, int schwelle) =>
    (k.rekordProChallenge[challengeId] ?? 0) >= schwelle;

const List<Abzeichen> alleAbzeichen = [
  // ── Serien & Erfolge (7) ──────────────────────────────────────────────────
  Abzeichen(
    id: 'streak_3',
    nameDe: 'Drei Tage dran',
    beschreibungDe: 'Du hast 3 Tage in Folge eine Tages-Challenge gespielt',
    emoji: '🔥',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.serien,
    istErreicht: _streak3,
  ),
  Abzeichen(
    id: 'streak_7',
    nameDe: 'Eine Woche dabei',
    beschreibungDe: 'Du hast 7 Tage in Folge eine Tages-Challenge gespielt',
    emoji: '🔥🔥',
    tier: AbzeichenTier.silber,
    kategorie: AbzeichenKategorie.serien,
    istErreicht: _streak7,
  ),
  Abzeichen(
    id: 'streak_30',
    nameDe: 'Ein Monat Ausdauer',
    beschreibungDe: 'Du hast 30 Tage in Folge eine Tages-Challenge gespielt',
    emoji: '🔥🔥🔥',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.serien,
    istErreicht: _streak30,
  ),
  Abzeichen(
    id: 'perfekt',
    nameDe: 'Volle Punktzahl',
    beschreibungDe: 'Du hast an einem Tag die Maximalpunktzahl in einer Tages-Challenge erreicht',
    emoji: '🎯',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.serien,
    istErreicht: _perfekt,
  ),
  Abzeichen(
    id: 'neuer_rekord',
    nameDe: 'Persönliche Bestleistung',
    beschreibungDe: 'Du hast einen persönlichen Bestwert in einer der Tages-Challenges aufgestellt',
    emoji: '💪',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.serien,
    istErreicht: _neuerRekord,
  ),
  Abzeichen(
    id: 'alle_challenges',
    nameDe: 'Kompletter Tag',
    beschreibungDe: 'Du hast an einem Tag alle 4 Tages-Challenges gespielt',
    emoji: '🏅',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.serien,
    istErreicht: _alleChallenges,
  ),
  Abzeichen(
    id: 'streak_app_30',
    nameDe: 'Treuer Spieler',
    beschreibungDe: 'Du hast 30 Tage in Folge die App genutzt',
    emoji: '👑',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.serien,
    istErreicht: _streakApp30,
  ),

  // ── Kontinente (7) ────────────────────────────────────────────────────────
  Abzeichen(
    id: 'kontinent_europa',
    nameDe: 'Europa-Meister',
    beschreibungDe: 'Du hast alle Stationen in Europa abgeschlossen',
    emoji: '🏰',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.kontinente,
    istErreicht: _kontinentEuropa,
  ),
  Abzeichen(
    id: 'kontinent_suedamerika',
    nameDe: 'Südamerika-Meister',
    beschreibungDe: 'Du hast alle Stationen in Südamerika abgeschlossen',
    emoji: '🦜',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.kontinente,
    istErreicht: _kontinentSuedamerika,
  ),
  Abzeichen(
    id: 'kontinent_nordamerika',
    nameDe: 'Nordamerika-Meister',
    beschreibungDe: 'Du hast alle Stationen in Nordamerika abgeschlossen',
    emoji: '🦅',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.kontinente,
    istErreicht: _kontinentNordamerika,
  ),
  Abzeichen(
    id: 'kontinent_afrika',
    nameDe: 'Afrika-Meister',
    beschreibungDe: 'Du hast alle Stationen in Afrika abgeschlossen',
    emoji: '🦁',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.kontinente,
    istErreicht: _kontinentAfrika,
  ),
  Abzeichen(
    id: 'kontinent_asien',
    nameDe: 'Asien-Meister',
    beschreibungDe: 'Du hast alle Stationen in Asien abgeschlossen',
    emoji: '🐼',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.kontinente,
    istErreicht: _kontinentAsien,
  ),
  Abzeichen(
    id: 'kontinent_ozeanien',
    nameDe: 'Ozeanien-Meister',
    beschreibungDe: 'Du hast alle Stationen in Ozeanien abgeschlossen',
    emoji: '🦘',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.kontinente,
    istErreicht: _kontinentOzeanien,
  ),
  Abzeichen(
    id: 'kontinent_welt',
    nameDe: 'Weltmeister',
    beschreibungDe: 'Du hast die abschließende Welt "Die Welt" komplett gemeistert',
    emoji: '🌍',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.kontinente,
    istErreicht: _kontinentWelt,
  ),

  // ── Meilensteine (4) ──────────────────────────────────────────────────────
  Abzeichen(
    id: 'stationen_25',
    nameDe: 'Erste Schritte',
    beschreibungDe: 'Du hast 25 Stationen im Lernpfad abgeschlossen',
    emoji: '📍',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.meilensteine,
    istErreicht: _stationen25,
  ),
  Abzeichen(
    id: 'stationen_50',
    nameDe: 'Auf gutem Weg',
    beschreibungDe: 'Du hast 50 Stationen im Lernpfad abgeschlossen',
    emoji: '🗺️',
    tier: AbzeichenTier.silber,
    kategorie: AbzeichenKategorie.meilensteine,
    istErreicht: _stationen50,
  ),
  Abzeichen(
    id: 'stationen_100',
    nameDe: 'Kartograph',
    beschreibungDe: 'Du hast 100 Stationen im Lernpfad abgeschlossen',
    emoji: '🧭',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.meilensteine,
    istErreicht: _stationen100,
  ),
  Abzeichen(
    id: 'stationen_alle',
    nameDe: 'Lernpfad-Champion',
    beschreibungDe: 'Du hast ALLE Stationen im Lernpfad abgeschlossen',
    emoji: '💎',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.meilensteine,
    istErreicht: _stationenAlle,
  ),

  // ── Tages-Challenges: Punkte-Stufen (12) ──────────────────────────────────
  Abzeichen(
    id: 'punkte_preis_bronze',
    nameDe: 'Schätz-Talent',
    beschreibungDe: 'Du hast in "Das große Schätzen" mind. 250 Punkte in einer Runde erreicht',
    emoji: '🥉',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punktePreisBronze,
  ),
  Abzeichen(
    id: 'punkte_preis_silber',
    nameDe: 'Schätz-Profi',
    beschreibungDe: 'Du hast in "Das große Schätzen" mind. 375 Punkte in einer Runde erreicht',
    emoji: '🥈',
    tier: AbzeichenTier.silber,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punktePreisSilber,
  ),
  Abzeichen(
    id: 'punkte_preis_gold',
    nameDe: 'Schätz-Meister',
    beschreibungDe: 'Du hast in "Das große Schätzen" mind. 488 Punkte in einer Runde erreicht',
    emoji: '🥇',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punktePreisGold,
  ),
  Abzeichen(
    id: 'punkte_higher_lower_bronze',
    nameDe: 'Serien-Talent',
    beschreibungDe: 'Du hast bei "Higher or Lower" mind. 10 Richtige in Folge geschafft',
    emoji: '🥉',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punkteHigherLowerBronze,
  ),
  Abzeichen(
    id: 'punkte_higher_lower_silber',
    nameDe: 'Serien-Profi',
    beschreibungDe: 'Du hast bei "Higher or Lower" mind. 20 Richtige in Folge geschafft',
    emoji: '🥈',
    tier: AbzeichenTier.silber,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punkteHigherLowerSilber,
  ),
  Abzeichen(
    id: 'punkte_higher_lower_gold',
    nameDe: 'Serien-Meister',
    beschreibungDe: 'Du hast bei "Higher or Lower" mind. 35 Richtige in Folge geschafft',
    emoji: '🥇',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punkteHigherLowerGold,
  ),
  Abzeichen(
    id: 'punkte_ranking_game_bronze',
    nameDe: 'Rang-Talent',
    beschreibungDe: 'Du hast im Ranking Game mind. 400 Punkte in einer Runde erreicht',
    emoji: '🥉',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punkteRankingGameBronze,
  ),
  Abzeichen(
    id: 'punkte_ranking_game_silber',
    nameDe: 'Rang-Profi',
    beschreibungDe: 'Du hast im Ranking Game mind. 600 Punkte in einer Runde erreicht',
    emoji: '🥈',
    tier: AbzeichenTier.silber,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punkteRankingGameSilber,
  ),
  Abzeichen(
    id: 'punkte_ranking_game_gold',
    nameDe: 'Rang-Meister',
    beschreibungDe: 'Du hast im Ranking Game mind. 780 Punkte in einer Runde erreicht',
    emoji: '🥇',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punkteRankingGameGold,
  ),
  Abzeichen(
    id: 'punkte_portfolio_bronze',
    nameDe: 'Investment-Talent',
    beschreibungDe: 'Du hast beim Portfolio mind. 50\$ Gewinn an einem Tag erreicht',
    emoji: '🥉',
    tier: AbzeichenTier.bronze,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punktePortfolioBronze,
  ),
  Abzeichen(
    id: 'punkte_portfolio_silber',
    nameDe: 'Investment-Profi',
    beschreibungDe: 'Du hast beim Portfolio mind. 150\$ Gewinn an einem Tag erreicht',
    emoji: '🥈',
    tier: AbzeichenTier.silber,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punktePortfolioSilber,
  ),
  Abzeichen(
    id: 'punkte_portfolio_gold',
    nameDe: 'Investment-Meister',
    beschreibungDe: 'Du hast beim Portfolio mind. 300\$ Gewinn an einem Tag erreicht',
    emoji: '🥇',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.challenges,
    istErreicht: _punktePortfolioGold,
  ),

  // ── Ehrung: nicht erspielbar ──────────────────────────────────────────────
  Abzeichen(
    id: 'urgestein',
    nameDe: 'Urgestein',
    beschreibungDe: 'Du warst von Anfang an dabei',
    // Moai statt Grabstein: 🪦 stammt aus Emoji 13.0 (2020) und erscheint auf
    // Android 10 und älter als leeres Rechteck — die App bündelt keine
    // Emoji-Schrift, sondern nutzt die des Systems. 🗿 gibt es seit 2010 und
    // ist überall vorhanden. Es wurde durch den pensionierten Modus
    // bekanntesGebaeude gerade frei.
    emoji: '🗿',
    tier: AbzeichenTier.gold,
    kategorie: AbzeichenKategorie.ehrung,
    // Nie von selbst. istErreicht wird zwar wie bei allen anderen geprüft,
    // liefert hier aber immer false — freigeschaltet wird die Münze
    // ausschliesslich über AbzeichenService.verleihen().
    istErreicht: _nie,
  ),
];

bool _nie(AbzeichenKontext k) => false;

/// Abzeichen, die man sich erspielen kann — also alles ausser den Ehrungen.
///
/// Das Münzalbum zählt darüber ("x / y Münzen gesammelt"). Zählte es alle,
/// bliebe für jeden, der die Ehrenmünze nicht hat, für immer eine Lücke
/// stehen, obwohl er alles Erreichbare gesammelt hat.
final List<Abzeichen> sammelbareAbzeichen = alleAbzeichen
    .where((a) => a.kategorie != AbzeichenKategorie.ehrung)
    .toList();

/// Ehrenmünzen, in der Reihenfolge der Liste.
final List<Abzeichen> ehrenAbzeichen = alleAbzeichen
    .where((a) => a.kategorie == AbzeichenKategorie.ehrung)
    .toList();

bool _kontinentEuropa(AbzeichenKontext k) => _kontinent(k, 'europa');
bool _kontinentSuedamerika(AbzeichenKontext k) => _kontinent(k, 'suedamerika');
bool _kontinentNordamerika(AbzeichenKontext k) => _kontinent(k, 'nordamerika');
bool _kontinentAfrika(AbzeichenKontext k) => _kontinent(k, 'afrika');
bool _kontinentAsien(AbzeichenKontext k) => _kontinent(k, 'asien');
bool _kontinentOzeanien(AbzeichenKontext k) => _kontinent(k, 'ozeanien');
bool _kontinentWelt(AbzeichenKontext k) => _kontinent(k, 'welt');

// "Das grosse Schätzen" wurde von 8 auf 5 Fragen gekürzt, die Höchstpunktzahl
// einer Runde damit von 800 auf 500. Die Schwellen sind auf denselben ANTEIL
// umgerechnet, den sie vorher hatten (50 %, 75 %, 97,5 %) — sonst wären Silber
// und Gold von einem Tag auf den anderen unerreichbar gewesen.
//
// Die Schwellen sinken dabei nur, niemand verliert also ein Abzeichen, das er
// mit einer alten 8-Fragen-Runde verdient hat.
bool _punktePreisBronze(AbzeichenKontext k) => _rekordMind(k, 'preis', 250);
bool _punktePreisSilber(AbzeichenKontext k) => _rekordMind(k, 'preis', 375);
bool _punktePreisGold(AbzeichenKontext k) => _rekordMind(k, 'preis', 488);

bool _punkteHigherLowerBronze(AbzeichenKontext k) =>
    _rekordMind(k, 'higher_lower', 10);
bool _punkteHigherLowerSilber(AbzeichenKontext k) =>
    _rekordMind(k, 'higher_lower', 20);
bool _punkteHigherLowerGold(AbzeichenKontext k) =>
    _rekordMind(k, 'higher_lower', 35);

bool _punkteRankingGameBronze(AbzeichenKontext k) =>
    _rekordMind(k, 'ranking_game', 400);
bool _punkteRankingGameSilber(AbzeichenKontext k) =>
    _rekordMind(k, 'ranking_game', 600);
bool _punkteRankingGameGold(AbzeichenKontext k) =>
    _rekordMind(k, 'ranking_game', 780);

bool _punktePortfolioBronze(AbzeichenKontext k) =>
    _rekordMind(k, 'portfolio', 50);
bool _punktePortfolioSilber(AbzeichenKontext k) =>
    _rekordMind(k, 'portfolio', 150);
bool _punktePortfolioGold(AbzeichenKontext k) =>
    _rekordMind(k, 'portfolio', 300);

/// Prioritätsreihenfolge für "wichtigstes Abzeichen" (z.B. Rangliste-Anzeige),
/// von seltenstem/wertvollstem zu häufigstem.
const _topPrioritaet = [
  'streak_app_30', 'stationen_alle', 'streak_30', 'alle_challenges',
  'perfekt', 'neuer_rekord', 'streak_7', 'streak_3',
];

/// ID des "wichtigsten" freigeschalteten Abzeichens nach [_topPrioritaet],
/// oder null wenn keins freigeschaltet ist.
String? topAbzeichenId(Set<String> freigeschaltete) {
  for (final id in _topPrioritaet) {
    if (freigeschaltete.contains(id)) return id;
  }
  return null;
}

Abzeichen? abzeichenById(String id) =>
    alleAbzeichen.cast<Abzeichen?>().firstWhere((a) => a?.id == id, orElse: () => null);
