import 'countries.dart';
import '../l10n/uebersetzungen.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum LernModus {
  flaggenQuizBild,      // Flagge sehen → Land wählen (MC)
  flaggenQuizMultiple,  // Land sehen → richtige Flagge wählen
  hauptstaedteMultiple, // Hauptstadt Multiple Choice
  hauptstaedteEingabe,  // Hauptstadt Texteingabe
  umrissBild,           // Umriss sehen → Land wählen
  umrissMultiple,       // Land sehen → Umriss wählen
  flaggenQuizEingabe,   // Flagge sehen → Ländername eintippen
  umrissEingabe,        // Umriss sehen → Ländername eintippen
  waehrungsQuiz,
  sortierSpiel,
  preisSchaetzen,
  wirtschaftssektoren,
  nachbarland,          // "Welches Land grenzt an X?"
  bipGesamt,            // "Wie hoch ist das BIP von X?"
  flaeche,              // "Wie groß ist die Fläche von X?"
  extremFrage,          // Superlativ: größte/kleinste/bevölkerungsreichste
  waehrungZuLand,       // "Welches Land nutzt Währung X?" (umgekehrtes Währungsquiz)
  extremFrageLeicht,    // Superlativ, aber nur unter sehr bekannten Ländern
  zufallsFakt,          // Rätsel-artiger Fun-Fact → gesuchtes Land erraten
  bekanntesGebaeude,    // "In welchem Land steht [Bauwerk]?"
  grenzkettenRaetsel,   // "Durch welches Land MUSST du NICHT fahren?"
}

// ── Klassen ───────────────────────────────────────────────────────────────────

class LernStation {
  final String id;
  final LernModus modus;
  final int fragenAnzahl;        // 8 Quiz / 3 Sortieren
  final List<String> laenderCodes;
  final List<String> kategorien;
  final int schwierigkeitsgrad;  // 1-4

  const LernStation({
    required this.id,
    required this.modus,
    required this.fragenAnzahl,
    required this.laenderCodes,
    required this.kategorien,
    required this.schwierigkeitsgrad,
  });
}

class LernAbschnitt {
  final String id;
  final int stufe;
  final String titel;
  final String untertitel;
  final List<LernStation> stationen;
  final bool hatTimer;           // true bei stufe 4
  final int maxWiederholungen;

  const LernAbschnitt({
    required this.id,
    required this.stufe,
    required this.titel,
    required this.untertitel,
    required this.stationen,
    this.hatTimer = false,
    this.maxWiederholungen = 20,
  });
}

class LernWelt {
  final String id;
  final String name;
  final String emoji;
  final String kontinent;
  final int totalLaender;
  final List<String> laenderCodes;
  final List<LernAbschnitt> abschnitte;
  final int reihenfolge;
  final bool hatTimer;

  const LernWelt({
    required this.id,
    required this.name,
    required this.emoji,
    required this.kontinent,
    required this.totalLaender,
    required this.laenderCodes,
    required this.abschnitte,
    required this.reihenfolge,
    this.hatTimer = true,
  });
}

// ── Modus-Verteilung ────────────────────────────────────────────────────────
//
// Pro Abschnittslevel (1=Einsteiger … 4=Meister) ein Pool erlaubter Modi.
// Jedes Thema mit zwei Varianten (Flaggen, Umriss, Hauptstädte, Währung)
// wird schrittweise komplettiert: die leichtere Variante ist von Anfang an
// dabei, die zweite kommt in einem späteren Level dazu. Level 4 enthält
// den vollständigen Modus-Satz.
//
// Die 3 Eingabe-Varianten (flaggenQuizEingabe, umrissEingabe,
// hauptstaedteEingabe) sind grundsätzlich schon ab Level 1 (Einsteiger)
// verfügbar — die INNERHALB EINES ABSCHNITTS geltende Reihenfolge-Regel
// (_eingabeVorbedingung/_eingabeErlaubt, siehe unten) sorgt weiterhin
// dafür, dass sie erst gezogen werden, nachdem die leichtere Variante
// desselben Themas in genau diesem Abschnitt schon vorkam.

const List<LernModus> _modiEinsteiger = [
  LernModus.flaggenQuizBild,
  LernModus.flaggenQuizMultiple,
  LernModus.hauptstaedteMultiple,
  LernModus.waehrungsQuiz,
  LernModus.umrissBild,
  LernModus.bipGesamt,
  LernModus.flaeche,
  LernModus.umrissMultiple,
  LernModus.extremFrageLeicht,
  LernModus.nachbarland,
  LernModus.hauptstaedteEingabe,
  LernModus.flaggenQuizEingabe,
  LernModus.umrissEingabe,
];

const List<LernModus> _modiFortgeschritten = [
  ..._modiEinsteiger,
  LernModus.sortierSpiel,
  LernModus.waehrungZuLand,
  LernModus.zufallsFakt,
  LernModus.bekanntesGebaeude,
  LernModus.grenzkettenRaetsel,
];

const List<LernModus> _modiProfi = [
  ..._modiFortgeschritten,
  LernModus.preisSchaetzen,
  LernModus.extremFrage,
];

// Meister enthält den vollständigen Modus-Satz.
const List<LernModus> _modiMeister = [
  ..._modiProfi,
  LernModus.wirtschaftssektoren,
];

List<LernModus> modiFuerLevel(int level) => switch (level) {
      1 => _modiEinsteiger,
      2 => _modiFortgeschritten,
      3 => _modiProfi,
      _ => _modiMeister,
    };

/// Ordnet jedem Modus sein Thema zu — Modi mit demselben Thema sind zwei
/// Varianten derselben Fragestellung (Bild/Multiple, Multiple/Eingabe, …)
/// und dürfen nie direkt hintereinander vorkommen.
String lernModusThema(LernModus m) => switch (m) {
      LernModus.flaggenQuizBild ||
      LernModus.flaggenQuizMultiple ||
      LernModus.flaggenQuizEingabe =>
        'flaggen',
      LernModus.umrissBild ||
      LernModus.umrissMultiple ||
      LernModus.umrissEingabe =>
        'umriss',
      LernModus.hauptstaedteMultiple ||
      LernModus.hauptstaedteEingabe =>
        'hauptstaedte',
      LernModus.waehrungsQuiz || LernModus.waehrungZuLand => 'waehrung',
      LernModus.sortierSpiel => 'sortieren',
      LernModus.preisSchaetzen => 'preis',
      LernModus.wirtschaftssektoren => 'wirtschaft',
      LernModus.nachbarland => 'nachbarland',
      LernModus.bipGesamt => 'bip',
      LernModus.flaeche => 'flaeche',
      LernModus.extremFrage || LernModus.extremFrageLeicht => 'extrem',
      LernModus.zufallsFakt => 'fakt',
      LernModus.bekanntesGebaeude => 'gebaeude',
      LernModus.grenzkettenRaetsel => 'grenzketten',
    };

/// Bevorzugt bei Gleichstand die noch selten genutzte Variante eines Themas.
int _variantenPrioritaet(LernModus m, Map<LernModus, int> zaehler) =>
    zaehler[m] ?? 0;

/// Mindestanzahl an leichteren Varianten desselben Themas, die in diesem
/// Abschnitt schon vorgekommen sein müssen, bevor die Eingabe-Variante
/// selbst gezogen werden darf (aufsteigende Schwierigkeit: Bild/Multiple
/// zuerst, Eingabe erst danach — einheitlich mindestens einmal pro Thema).
int? _eingabeVorbedingung(LernModus m) => switch (m) {
      LernModus.hauptstaedteEingabe => 1,
      LernModus.flaggenQuizEingabe => 1,
      LernModus.umrissEingabe => 1,
      _ => null,
    };

/// Prüft, ob [m] (falls es eine Eingabe-Variante ist) in der bisherigen
/// Sequenz dieses Abschnitts schon genug leichtere Varianten desselben
/// Themas gesehen hat, um selbst gezogen werden zu dürfen.
bool _eingabeErlaubt(LernModus m, List<LernModus> bisher) {
  final vorbedingung = _eingabeVorbedingung(m);
  if (vorbedingung == null) return true;
  final thema = lernModusThema(m);
  final leichtereBisher =
      bisher.where((x) => x != m && lernModusThema(x) == thema).length;
  return leichtereBisher >= vorbedingung;
}

/// Erzeugt eine gut durchmischte Modus-Sequenz für einen Abschnitt:
/// nie derselbe Modus und nie dasselbe Thema zweimal direkt hintereinander,
/// Round-Robin über die verfügbaren Modi für eine gleichmäßige Verteilung.
/// Die allererste Station im gesamten Lernpfad ist immer flaggenQuizBild.
List<LernModus> erzeugeModusSequenz(
  int stationsAnzahl,
  int abschnittLevel,
  bool istAllerErsterAbschnitt,
) {
  final pool = modiFuerLevel(abschnittLevel);
  final sequenz = <LernModus>[];
  LernModus? letzter;
  String? letztesThema;
  final zaehler = <LernModus, int>{};

  for (int i = 0; i < stationsAnzahl; i++) {
    // Allererste Station im ganzen Pfad: immer flaggenQuizBild.
    if (istAllerErsterAbschnitt && i == 0) {
      sequenz.add(LernModus.flaggenQuizBild);
      letzter = LernModus.flaggenQuizBild;
      letztesThema = 'flaggen';
      zaehler[LernModus.flaggenQuizBild] = 1;
      continue;
    }

    // Kandidaten: nicht der letzte Modus UND nicht dasselbe Thema wie
    // zuletzt (damit z.B. nicht Flagge-Bild direkt auf Flagge-Multiple folgt)
    // UND (falls Eingabe-Variante) noch genug leichtere Varianten gesehen.
    var kandidaten = pool
        .where((m) =>
            m != letzter &&
            lernModusThema(m) != letztesThema &&
            _eingabeErlaubt(m, sequenz))
        .toList();

    // Falls dadurch leer (kleiner Pool): nur "nicht letzter Modus" erzwingen,
    // Eingabe-Gate bleibt aber bestehen.
    if (kandidaten.isEmpty) {
      kandidaten =
          pool.where((m) => m != letzter && _eingabeErlaubt(m, sequenz)).toList();
    }

    // Äußerster Rand-Fall (z.B. Pool besteht praktisch nur noch aus
    // gesperrten Eingabe-Varianten): Gate ignorieren, damit die Sequenz nie
    // leer bleibt.
    if (kandidaten.isEmpty) {
      kandidaten = pool.where((m) => m != letzter).toList();
    }
    if (kandidaten.isEmpty) kandidaten = pool;

    // Unter den Kandidaten: die mit dem niedrigsten Zähler bevorzugen
    // (gleichmäßige Verteilung).
    kandidaten.sort((a, b) => (zaehler[a] ?? 0).compareTo(zaehler[b] ?? 0));

    // Bei Gleichstand: bevorzugt die noch nicht genutzte Variante eines
    // Themas (z.B. flaggenQuizMultiple, wenn flaggenQuizBild schon kam).
    final minZaehler = zaehler[kandidaten.first] ?? 0;
    final beste =
        kandidaten.where((m) => (zaehler[m] ?? 0) == minZaehler).toList();
    beste.sort((a, b) => _variantenPrioritaet(a, zaehler)
        .compareTo(_variantenPrioritaet(b, zaehler)));

    final gewaehlt = beste.first;
    sequenz.add(gewaehlt);
    zaehler[gewaehlt] = (zaehler[gewaehlt] ?? 0) + 1;
    letzter = gewaehlt;
    letztesThema = lernModusThema(gewaehlt);
  }
  return sequenz;
}

// ── Länderlisten ──────────────────────────────────────────────────────────────
//
// Jeder Block-Kontinent (alles außer Welt) hat drei DISJUNKTE Länder-Blöcke
// (A/B/C, sortiert nach Land.schwierigkeit aus alle_laender.dart) für seine
// ersten Abschnitte — kein Land kommt in mehr als einem Block vor. Der
// jeweils LETZTE Abschnitt eines Kontinents ist der Wiederholungs-Abschnitt:
// er nutzt die volle "*All"-Liste (alle Blöcke gemischt, keine Grenzen mehr).
// Bei Südamerika/Ozeanien (nur 2 Blöcke, 3 Abschnitte) übernimmt Block B den
// zweiten und der volle Kontinent den dritten (Wiederholungs-)Abschnitt.

const _europaBlockA = [
  'DE', 'FR', 'IT', 'ES', 'PT', 'GB', 'SE', 'NO', 'PL', 'RU',
  'NL', 'BE', 'CH', 'AT', 'IE', 'DK',
];
const _europaBlockB = [
  'FI', 'IS', 'CZ', 'SK', 'HU', 'RO', 'BG', 'HR', 'GR', 'UA',
  'CY', 'LT', 'EE', 'LV', 'SI',
];
const _europaBlockC = [
  'LU', 'MC', 'AD', 'LI', 'SM', 'MT', 'VA', 'RS', 'BA', 'ME',
  'MK', 'AL', 'MD', 'BY', 'XK',
];
const _europaAll = [..._europaBlockA, ..._europaBlockB, ..._europaBlockC];

const _suedamBlockA = ['BR', 'AR', 'CL', 'CO', 'PE', 'VE'];
const _suedamBlockB = ['EC', 'BO', 'PY', 'UY', 'GY', 'SR'];
const _suedamAll = [..._suedamBlockA, ..._suedamBlockB];

const _nordamBlockA = ['US', 'CA', 'MX', 'CU', 'GT', 'PA', 'JM', 'DO'];
const _nordamBlockB = ['BZ', 'HN', 'SV', 'NI', 'CR', 'HT', 'TT', 'BB'];
const _nordamBlockC = ['LC', 'VC', 'GD', 'AG', 'DM', 'KN', 'BS'];
const _nordamAll = [..._nordamBlockA, ..._nordamBlockB, ..._nordamBlockC];

const _afrikaBlockA = [
  'NG', 'EG', 'ZA', 'MA', 'DZ', 'TN', 'LY', 'SD', 'ET', 'KE',
  'TZ', 'GH', 'CD', 'AO', 'MG', 'ZW', 'UG', 'RW',
];
const _afrikaBlockB = [
  'SS', 'CG', 'MZ', 'CM', 'CI', 'NE', 'ML', 'BF', 'SN', 'ZM',
  'BI', 'SO', 'ER', 'DJ', 'MW', 'BW', 'NA', 'LS',
];
const _afrikaBlockC = [
  'SZ', 'GA', 'GQ', 'CF', 'TD', 'MR', 'GM', 'GW', 'GN', 'SL',
  'LR', 'TG', 'BJ', 'CV', 'ST', 'KM', 'SC', 'MU',
];
const _afrikaAll = [..._afrikaBlockA, ..._afrikaBlockB, ..._afrikaBlockC];

const _asienBlockA = [
  'CN', 'JP', 'IN', 'SA', 'TR', 'ID', 'KR', 'TH', 'VN', 'PK',
  'BD', 'PH', 'MY', 'AE', 'IL', 'KZ',
];
const _asienBlockB = [
  'NP', 'IQ', 'IR', 'AF', 'MN', 'SG', 'MM', 'KH', 'LA', 'LK',
  'SY', 'JO', 'LB', 'KW', 'QA', 'BH',
];
const _asienBlockC = [
  'OM', 'YE', 'UZ', 'TM', 'AZ', 'GE', 'AM', 'TJ', 'KG', 'KP',
  'TW', 'BT', 'MV', 'BN', 'TL', 'PS',
];
const _asienAll = [..._asienBlockA, ..._asienBlockB, ..._asienBlockC];

const _ozeanienBlockA = ['AU', 'NZ', 'FJ', 'PG', 'WS', 'VU', 'SB'];
const _ozeanienBlockB = ['TO', 'KI', 'FM', 'PW', 'MH', 'NR', 'TV'];
const _ozeanienAll = [..._ozeanienBlockA, ..._ozeanienBlockB];

const _weltA1 = [
  'DE', 'FR', 'GB', 'IT', 'ES', 'US', 'CA', 'CN', 'JP', 'IN',
  'BR', 'AU', 'RU', 'ZA', 'MX', 'KR', 'ID', 'SA', 'AR', 'NG',
  'EG', 'TH', 'PL', 'NL', 'SE', 'CH', 'BE', 'AT', 'NO', 'DK',
  'FI', 'PT', 'GR', 'CZ', 'IR', 'VN', 'MA', 'IL', 'SG', 'CL',
  'CO', 'AE', 'PH', 'BD', 'PK', 'UA', 'RO', 'KE', 'NZ', 'ET',
];
const _weltA2 = [
  'DE', 'FR', 'GB', 'IT', 'ES', 'US', 'CA', 'CN', 'JP', 'IN',
  'BR', 'AU', 'RU', 'ZA', 'MX', 'KR', 'ID', 'SA', 'AR', 'NG',
  'EG', 'TH', 'PL', 'NL', 'SE', 'CH', 'BE', 'AT', 'NO', 'DK',
  'FI', 'PT', 'GR', 'CZ', 'IR', 'VN', 'MA', 'IL', 'SG', 'CL',
  'CO', 'AE', 'PH', 'BD', 'PK', 'UA', 'RO', 'KE', 'NZ', 'ET',
  'GH', 'TZ', 'DZ', 'TN', 'CM', 'AO', 'SD', 'ML', 'SN', 'IQ',
  'QA', 'KW', 'OM', 'MY', 'MM', 'KH', 'LK', 'NP', 'AF', 'UZ',
  'KZ', 'MN', 'BY', 'HU', 'CU', 'DO', 'PE', 'VE', 'EC', 'GT',
  'PA', 'CR', 'HN', 'BO', 'UY', 'PY', 'JM', 'HT', 'TT', 'IS',
  'IE', 'HR', 'SK', 'LT', 'LV', 'EE', 'SI', 'RS', 'LU', 'BG',
];

/// Alle Länder mit Datensatz — löst den '*'-Platzhalter für die
/// Welt-Abschnitte "Profi" und "Meister" auf (vorher unaufgelöst: die
/// Stationen dort erzeugten 0 Fragen und hingen im Ladespinner fest).
final _weltAlle = countries.map((c) => c.iso2).toList();

// ── Station-Hilfsfunktionen ───────────────────────────────────────────────────

LernStation _st(
  String wid, int a, int i, LernModus m, List<String> l, int fragenProStation, {
  List<String> k = const [],
}) {
  return LernStation(
    id: '${wid}_${a}_${i.toString().padLeft(2, '0')}',
    modus: m,
    fragenAnzahl: m == LernModus.sortierSpiel ? 3 : fragenProStation,
    laenderCodes: l,
    kategorien: k,
    schwierigkeitsgrad: a,
  );
}

/// Baut die Stationsliste eines Abschnitts. [anzahl] wird bei Bedarf um 1-3
/// echte, spielbare Stationen aufgestockt, damit der Zickzack-Pfad exakt
/// mittig vor dem Checkpoint endet (siehe home_screen.dart _Pfad) — früher
/// wurde das mit rein dekorativen, nicht spielbaren Füll-Punkten gelöst,
/// jetzt bekommen auch diese Positionen einen vollen, funktionierenden
/// Modus aus derselben Verteilungslogik wie jede andere Station.
///
/// [modusPoolLevel] überschreibt den für die Modus-Verteilung genutzten
/// Level-Pool (unabhängig von [stufe], die weiterhin den
/// Schwierigkeitsgrad/das Label der Station bestimmt) — genutzt für "Welt",
/// wo von Anfang an der VOLLE Modus-Satz (inkl. aller Unterhaltungs-Modi)
/// zur Verfügung stehen soll, weil Welt keine Block-Vollrotation pro
/// Abschnitt braucht und dadurch mehr Raum für Abwechslung hat.
List<LernStation> _baueAbschnitt(
  String wid, int stufe, List<String> laender, int anzahl, {
  bool istAllerErsterAbschnitt = false,
  int fragenProStation = 8,
  int? modusPoolLevel,
}) {
  final polster = anzahl == 0 ? 0 : ((1 - anzahl) % 4 + 4) % 4;
  final gesamt = anzahl + polster;
  final modi = erzeugeModusSequenz(
      gesamt, modusPoolLevel ?? stufe, istAllerErsterAbschnitt);
  return [
    for (int i = 0; i < gesamt; i++)
      _st(wid, stufe, i + 1, modi[i], laender, fragenProStation),
  ];
}

// ── WELT 1 — EUROPA ───────────────────────────────────────────────────────────

final _europaA1St = _baueAbschnitt('europa', 1, _europaBlockA, 21,
    istAllerErsterAbschnitt: true);
final _europaA2St = _baueAbschnitt('europa', 2, _europaBlockB, 22);
final _europaA3St = _baueAbschnitt('europa', 3, _europaBlockC, 22);
final _europaA4St = _baueAbschnitt('europa', 4, _europaAll, 25);

// ── WELT 2 — SÜDAMERIKA ───────────────────────────────────────────────────────

final _suedamA1St =
    _baueAbschnitt('suedamerika', 1, _suedamBlockA, 10, fragenProStation: 6);
final _suedamA2St =
    _baueAbschnitt('suedamerika', 2, _suedamBlockB, 12, fragenProStation: 6);
final _suedamA3St =
    _baueAbschnitt('suedamerika', 3, _suedamAll, 14, fragenProStation: 6);

// ── WELT 3 — NORDAMERIKA ──────────────────────────────────────────────────────

final _nordamA1St = _baueAbschnitt('nordamerika', 1, _nordamBlockA, 12);
final _nordamA2St = _baueAbschnitt('nordamerika', 2, _nordamBlockB, 14);
final _nordamA3St = _baueAbschnitt('nordamerika', 3, _nordamBlockC, 18);
final _nordamA4St = _baueAbschnitt('nordamerika', 4, _nordamAll, 20);

// ── WELT 4 — AFRIKA ───────────────────────────────────────────────────────────

final _afrikaA1St =
    _baueAbschnitt('afrika', 1, _afrikaBlockA, 18, fragenProStation: 9);
final _afrikaA2St =
    _baueAbschnitt('afrika', 2, _afrikaBlockB, 22, fragenProStation: 9);
final _afrikaA3St =
    _baueAbschnitt('afrika', 3, _afrikaBlockC, 26, fragenProStation: 9);
final _afrikaA4St =
    _baueAbschnitt('afrika', 4, _afrikaAll, 30, fragenProStation: 9);

// ── WELT 5 — ASIEN ────────────────────────────────────────────────────────────

final _asienA1St = _baueAbschnitt('asien', 1, _asienBlockA, 20);
final _asienA2St = _baueAbschnitt('asien', 2, _asienBlockB, 20);
final _asienA3St = _baueAbschnitt('asien', 3, _asienBlockC, 24);
final _asienA4St = _baueAbschnitt('asien', 4, _asienAll, 28);

// ── WELT 6 — OZEANIEN ─────────────────────────────────────────────────────────

final _ozeanienA1St =
    _baueAbschnitt('ozeanien', 1, _ozeanienBlockA, 10, fragenProStation: 7);
final _ozeanienA2St =
    _baueAbschnitt('ozeanien', 2, _ozeanienBlockB, 12, fragenProStation: 7);
final _ozeanienA3St =
    _baueAbschnitt('ozeanien', 3, _ozeanienAll, 14, fragenProStation: 7);

// ── WELT 7 — DIE WELT ────────────────────────────────────────────────────────

final _weltA1St = _baueAbschnitt('welt', 1, _weltA1, 25,
    fragenProStation: 12, modusPoolLevel: 4);
final _weltA2St = _baueAbschnitt('welt', 2, _weltA2, 30,
    fragenProStation: 12, modusPoolLevel: 4);
final _weltA3St = _baueAbschnitt('welt', 3, _weltAlle, 35,
    fragenProStation: 12, modusPoolLevel: 4);
final _weltA4St = _baueAbschnitt('welt', 4, _weltAlle, 40,
    fragenProStation: 12, modusPoolLevel: 4);

// ── Hauptliste ────────────────────────────────────────────────────────────────

final List<LernWelt> lernwelten = [
  LernWelt(
    id: 'europa', name: 'Europa', emoji: '🇪🇺',
    kontinent: 'Europa', totalLaender: 46, laenderCodes: _europaAll,
    reihenfolge: 1,
    abschnitte: [
      LernAbschnitt(id: 'europa_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Die großen Länder Westeuropas', stationen: _europaA1St),
      LernAbschnitt(id: 'europa_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Nord- und Osteuropa', stationen: _europaA2St),
      LernAbschnitt(id: 'europa_3', stufe: 3, titel: 'Profi',
        untertitel: 'Kleinstaaten & der Balkan', stationen: _europaA3St),
      LernAbschnitt(id: 'europa_4', stufe: 4, titel: 'Meister',
        untertitel: 'Europa-Experte werden', stationen: _europaA4St,
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'suedamerika', name: 'Südamerika', emoji: '🌎',
    kontinent: 'Südamerika', totalLaender: 12, laenderCodes: _suedamAll,
    reihenfolge: 2,
    abschnitte: [
      LernAbschnitt(id: 'suedamerika_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Der Kontinent des Regenwalds', stationen: _suedamA1St),
      LernAbschnitt(id: 'suedamerika_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Wirtschaft und Währungen', stationen: _suedamA2St),
      LernAbschnitt(id: 'suedamerika_3', stufe: 3, titel: 'Profi',
        untertitel: 'Südamerika-Experte', stationen: _suedamA3St,
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'nordamerika', name: 'Nordamerika', emoji: '🗽',
    kontinent: 'Nordamerika', totalLaender: 23, laenderCodes: _nordamAll,
    reihenfolge: 3,
    abschnitte: [
      LernAbschnitt(id: 'nordamerika_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'USA, Kanada & Mittelamerika', stationen: _nordamA1St),
      LernAbschnitt(id: 'nordamerika_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Karibik & ganz Mittelamerika', stationen: _nordamA2St),
      LernAbschnitt(id: 'nordamerika_3', stufe: 3, titel: 'Profi',
        untertitel: 'Die kleinen Karibikstaaten', stationen: _nordamA3St),
      LernAbschnitt(id: 'nordamerika_4', stufe: 4, titel: 'Meister',
        untertitel: 'Nordamerika-Experte', stationen: _nordamA4St,
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'afrika', name: 'Afrika', emoji: '🌍',
    kontinent: 'Afrika', totalLaender: 54, laenderCodes: _afrikaAll,
    reihenfolge: 4,
    abschnitte: [
      LernAbschnitt(id: 'afrika_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Die größten Länder Afrikas', stationen: _afrikaA1St),
      LernAbschnitt(id: 'afrika_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Zentral- und Ostafrika', stationen: _afrikaA2St),
      LernAbschnitt(id: 'afrika_3', stufe: 3, titel: 'Profi',
        untertitel: 'Westafrika & Inselstaaten', stationen: _afrikaA3St),
      LernAbschnitt(id: 'afrika_4', stufe: 4, titel: 'Meister',
        untertitel: 'Afrika-Experte werden', stationen: _afrikaA4St,
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'asien', name: 'Asien', emoji: '🌏',
    kontinent: 'Asien', totalLaender: 48, laenderCodes: _asienAll,
    reihenfolge: 5,
    abschnitte: [
      LernAbschnitt(id: 'asien_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Die Wirtschaftsmächte Asiens', stationen: _asienA1St),
      LernAbschnitt(id: 'asien_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Naher Osten & Südostasien', stationen: _asienA2St),
      LernAbschnitt(id: 'asien_3', stufe: 3, titel: 'Profi',
        untertitel: 'Zentralasien & der Kaukasus', stationen: _asienA3St),
      LernAbschnitt(id: 'asien_4', stufe: 4, titel: 'Meister',
        untertitel: 'Asien-Experte werden', stationen: _asienA4St,
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'ozeanien', name: 'Ozeanien', emoji: '🏝️',
    kontinent: 'Ozeanien', totalLaender: 14, laenderCodes: _ozeanienAll,
    reihenfolge: 6,
    abschnitte: [
      LernAbschnitt(id: 'ozeanien_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Australien & die Pazifikinseln', stationen: _ozeanienA1St),
      LernAbschnitt(id: 'ozeanien_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Die entlegenen Inselstaaten', stationen: _ozeanienA2St),
      LernAbschnitt(id: 'ozeanien_3', stufe: 3, titel: 'Profi',
        untertitel: 'Ozeanien-Experte', stationen: _ozeanienA3St,
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'welt', name: 'Die Welt', emoji: '🌐',
    kontinent: 'Welt', totalLaender: 197, laenderCodes: const ['*'],
    reihenfolge: 7,
    abschnitte: [
      LernAbschnitt(id: 'welt_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Die 50 bekanntesten Länder', stationen: _weltA1St),
      LernAbschnitt(id: 'welt_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: '100 Länder weltweit', stationen: _weltA2St),
      LernAbschnitt(id: 'welt_3', stufe: 3, titel: 'Profi',
        untertitel: 'Alle 195 Länder der Erde', stationen: _weltA3St),
      LernAbschnitt(id: 'welt_4', stufe: 4, titel: 'Meister',
        untertitel: 'Weltmeister der Geographie', stationen: _weltA4St,
        hatTimer: true),
    ],
  ),
];

// ── Hilfsfunktionen für UI ────────────────────────────────────────────────────

String lernModusLabel(LernModus m) => t(switch (m) {
  LernModus.flaggenQuizBild      => 'Flaggen-Quiz (Bild)',
  LernModus.flaggenQuizMultiple  => 'Flaggen-Quiz (Multiple)',
  LernModus.hauptstaedteMultiple => 'Hauptstädte (Multiple Choice)',
  LernModus.hauptstaedteEingabe  => 'Hauptstädte (Eingabe)',
  LernModus.umrissBild           => 'Umriss-Quiz (Bild)',
  LernModus.umrissMultiple       => 'Umriss-Quiz (Multiple)',
  LernModus.flaggenQuizEingabe   => 'Flaggen-Quiz (Eingabe)',
  LernModus.umrissEingabe        => 'Umriss-Quiz (Eingabe)',
  LernModus.waehrungsQuiz        => 'Währungs-Quiz',
  LernModus.sortierSpiel         => 'Sortier-Spiel',
  LernModus.preisSchaetzen       => 'Das große Schätzen',
  LernModus.wirtschaftssektoren  => 'Wirtschaftssektoren',
  LernModus.nachbarland          => 'Länder-Quiz (Nachbarn)',
  LernModus.bipGesamt            => 'BIP-Quiz (Gesamt)',
  LernModus.flaeche              => 'Flächen-Quiz (Größe)',
  LernModus.extremFrage          => 'Superlativ-Quiz (Extrem)',
  LernModus.waehrungZuLand       => 'Währungs-Quiz (Land)',
  LernModus.extremFrageLeicht    => 'Superlativ-Quiz (Leicht)',
  LernModus.zufallsFakt          => 'Wissens-Quiz (Fun-Fact)',
  LernModus.bekanntesGebaeude    => 'Wahrzeichen-Quiz',
  LernModus.grenzkettenRaetsel   => 'Grenzketten-Rätsel',
});

/// Zeitlimit in Sekunden für [modus] in Abschnitt 4 (Meister) — 0 bedeutet
/// kein Timer. Nach Modus-Kategorie gestaffelt: schnelle Bild-/Multiple-
/// Erkennung bekommt am wenigsten Zeit, Eingabe-Modi (Tippen kostet Zeit) und
/// komplexe Multi-Schritt-Modi am meisten. preisSchaetzen/zufallsFakt/
/// bekanntesGebaeude sind bewusst ohne Timer (freies Nachdenken/Schätzen).
/// bipGesamt/flaeche/extremFrageLeicht fallen mangels eigener Kategorie auf
/// den Sicherheits-Fallback (kein Timer) zurück.
int timerSekundenFuerModus(LernModus modus) {
  const schnell = {
    LernModus.flaggenQuizBild,
    LernModus.flaggenQuizMultiple,
    LernModus.umrissBild,
    LernModus.umrissMultiple,
  };
  const mittel = {
    LernModus.hauptstaedteMultiple,
    LernModus.waehrungsQuiz,
    LernModus.nachbarland,
    LernModus.extremFrage,
  };
  const eingabe = {
    LernModus.flaggenQuizEingabe,
    LernModus.umrissEingabe,
    LernModus.hauptstaedteEingabe,
  };
  const komplex = {
    LernModus.sortierSpiel,
    LernModus.grenzkettenRaetsel,
    LernModus.wirtschaftssektoren,
  };

  if (schnell.contains(modus)) return 15;
  if (mittel.contains(modus)) return 20;
  if (eingabe.contains(modus)) return 30;
  if (komplex.contains(modus)) return 40;
  return 0; // Sicherheits-Fallback: unbekannter/nicht gelisteter Modus
  // bekommt keinen Timer statt zu crashen (preisSchaetzen, zufallsFakt,
  // bekanntesGebaeude, bipGesamt, flaeche, extremFrageLeicht).
}

String lernModusFragenLabel(LernStation s) =>
    s.modus == LernModus.sortierSpiel
        ? t('{n} Runden', {'n': '${s.fragenAnzahl}'})
        : t('{n} Fragen', {'n': '${s.fragenAnzahl}'});

LernStation? stationById(String id) {
  for (final w in lernwelten) {
    for (final a in w.abschnitte) {
      for (final s in a.stationen) {
        if (s.id == id) return s;
      }
    }
  }
  return null;
}

LernAbschnitt? abschnittById(String id) {
  for (final w in lernwelten) {
    for (final a in w.abschnitte) {
      if (a.id == id) return a;
    }
  }
  return null;
}

LernWelt? weltById(String id) {
  for (final w in lernwelten) {
    if (w.id == id) return w;
  }
  return null;
}

(LernWelt, LernAbschnitt, LernStation)? stationKontext(String stationId) {
  for (final w in lernwelten) {
    for (final a in w.abschnitte) {
      for (final s in a.stationen) {
        if (s.id == stationId) return (w, a, s);
      }
    }
  }
  return null;
}
