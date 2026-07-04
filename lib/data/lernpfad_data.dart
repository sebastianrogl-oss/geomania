import 'countries.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum LernModus {
  flaggenQuizBild,      // Flagge sehen → Land wählen (MC)
  flaggenQuizMultiple,  // Land sehen → richtige Flagge wählen
  hauptstaedteMultiple, // Hauptstadt Multiple Choice
  hauptstaedteEingabe,  // Hauptstadt Texteingabe
  umrissBild,           // Umriss sehen → Land wählen
  umrissMultiple,       // Land sehen → Umriss wählen
  waehrungsQuiz,
  sortierSpiel,
  preisSchaetzen,
  wirtschaftssektoren,
  nachbarland,          // "Welches Land grenzt an X?"
  bipGesamt,            // "Wie hoch ist das BIP von X?"
  flaeche,              // "Wie groß ist die Fläche von X?"
  extremFrage,          // Superlativ: größte/kleinste/bevölkerungsreichste
  waehrungZuLand,       // "Welches Land nutzt Währung X?" (umgekehrtes Währungsquiz)
  hauptstadtZuLand,     // "Welches Land hat die Hauptstadt X?" (umgekehrtes Hauptstädte-Quiz)
  groessteStadt,        // "Was ist die größte Stadt von X?"
  flaggenFarbe,         // "Welche Farben hat die Flagge von X?"
  extremFrageLeicht,    // Superlativ, aber nur unter sehr bekannten Ländern
  zufallsFakt,          // Rätsel-artiger Fun-Fact → gesuchtes Land erraten
  bekanntesGebaeude,    // "In welchem Land steht [Bauwerk]?"
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

const List<LernModus> _modiEinsteiger = [
  LernModus.flaggenQuizBild,
  LernModus.flaggenQuizMultiple,
  LernModus.hauptstaedteMultiple,
  LernModus.hauptstadtZuLand,
  LernModus.waehrungsQuiz,
  LernModus.umrissBild,
  LernModus.bipGesamt,
  LernModus.flaeche,
  LernModus.flaggenFarbe,
  LernModus.extremFrageLeicht,
  LernModus.groessteStadt,
  LernModus.nachbarland,
];

const List<LernModus> _modiFortgeschritten = [
  ..._modiEinsteiger,
  LernModus.umrissMultiple,
  LernModus.sortierSpiel,
  LernModus.waehrungZuLand,
  LernModus.zufallsFakt,
  LernModus.bekanntesGebaeude,
];

const List<LernModus> _modiProfi = [
  ..._modiFortgeschritten,
  LernModus.hauptstaedteEingabe,
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
      LernModus.flaggenFarbe =>
        'flaggen',
      LernModus.umrissBild || LernModus.umrissMultiple => 'umriss',
      LernModus.hauptstaedteMultiple ||
      LernModus.hauptstaedteEingabe ||
      LernModus.hauptstadtZuLand =>
        'hauptstaedte',
      LernModus.waehrungsQuiz || LernModus.waehrungZuLand => 'waehrung',
      LernModus.sortierSpiel => 'sortieren',
      LernModus.preisSchaetzen => 'preis',
      LernModus.wirtschaftssektoren => 'wirtschaft',
      LernModus.nachbarland => 'nachbarland',
      LernModus.bipGesamt => 'bip',
      LernModus.flaeche => 'flaeche',
      LernModus.extremFrage || LernModus.extremFrageLeicht => 'extrem',
      LernModus.groessteStadt => 'groessteStadt',
      LernModus.zufallsFakt => 'fakt',
      LernModus.bekanntesGebaeude => 'gebaeude',
    };

/// Bevorzugt bei Gleichstand die noch selten genutzte Variante eines Themas.
int _variantenPrioritaet(LernModus m, Map<LernModus, int> zaehler) =>
    zaehler[m] ?? 0;

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
    // zuletzt (damit z.B. nicht Flagge-Bild direkt auf Flagge-Multiple folgt).
    var kandidaten = pool
        .where((m) => m != letzter && lernModusThema(m) != letztesThema)
        .toList();

    // Falls dadurch leer (kleiner Pool): nur "nicht letzter Modus" erzwingen.
    if (kandidaten.isEmpty) {
      kandidaten = pool.where((m) => m != letzter).toList();
    }

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

const _europaA1 = ['DE', 'FR', 'IT', 'ES', 'GB', 'PT', 'NL', 'BE', 'CH', 'AT'];
const _europaA2 = [
  'DE', 'FR', 'IT', 'ES', 'GB', 'PT', 'NL', 'BE', 'CH', 'AT',
  'PL', 'SE', 'NO', 'DK', 'FI', 'IE', 'GR', 'CZ', 'HU', 'RO',
];
const _europaAll = [
  'DE', 'FR', 'GB', 'IT', 'ES', 'PT', 'NL', 'BE', 'CH', 'AT',
  'SE', 'NO', 'DK', 'FI', 'PL', 'CZ', 'HU', 'GR', 'RO', 'HR',
  'RS', 'BG', 'UA', 'RU', 'TR', 'AL', 'AD', 'BA', 'BY', 'CY',
  'EE', 'IE', 'IS', 'LI', 'LT', 'LU', 'LV', 'MC', 'MD', 'ME',
  'MK', 'MT', 'SI', 'SK', 'SM', 'VA', 'XK',
];

const _suedamAll = [
  'BR', 'AR', 'CO', 'CL', 'PE', 'VE', 'EC', 'BO', 'UY', 'PY', 'GY', 'SR',
];

const _nordamA1  = ['US', 'CA', 'MX', 'CU', 'GT', 'CR', 'PA', 'JM'];
const _nordamAll = [
  'US', 'CA', 'MX', 'CU', 'DO', 'HT', 'GT', 'HN', 'SV', 'NI',
  'CR', 'PA', 'BZ', 'JM', 'TT', 'BB', 'BS', 'AG', 'DM', 'GD',
  'KN', 'LC', 'VC',
];

const _afrikaA1  = ['NG', 'EG', 'ZA', 'KE', 'ET', 'GH', 'MA', 'TZ', 'DZ', 'TN'];
const _afrikaA2  = [
  'NG', 'EG', 'ZA', 'KE', 'ET', 'GH', 'MA', 'TZ', 'DZ', 'TN',
  'CM', 'CI', 'AO', 'MZ', 'MG', 'SD', 'ML', 'NE', 'CD', 'SN',
  'TD', 'SO', 'UG', 'BI', 'RW',
];
const _afrikaAll = [
  'NG', 'ET', 'EG', 'ZA', 'KE', 'GH', 'TZ', 'MA', 'DZ', 'TN',
  'SN', 'CM', 'CI', 'MG', 'AO', 'BF', 'BI', 'BJ', 'BW', 'CD',
  'CF', 'CG', 'CV', 'DJ', 'ER', 'GA', 'GM', 'GN', 'GQ', 'GW',
  'KM', 'LR', 'LS', 'LY', 'ML', 'MR', 'MU', 'MW', 'MZ', 'NA',
  'NE', 'RW', 'SC', 'SD', 'SL', 'SO', 'SS', 'ST', 'SZ', 'TD',
  'TG', 'UG', 'ZM', 'ZW',
];

const _asienA1  = ['CN', 'JP', 'IN', 'KR', 'TH', 'VN', 'ID', 'SA', 'AE', 'IR'];
const _asienA2  = [
  'CN', 'JP', 'IN', 'KR', 'TH', 'VN', 'ID', 'SA', 'AE', 'IR',
  'PK', 'BD', 'PH', 'MY', 'SG', 'IQ', 'IL', 'JO', 'KW', 'QA',
  'OM', 'YE', 'AF', 'UZ', 'KZ',
];
const _asienAll = [
  'CN', 'JP', 'IN', 'KR', 'ID', 'TH', 'VN', 'PH', 'MY', 'SG',
  'PK', 'BD', 'NP', 'MM', 'KZ', 'UZ', 'GE', 'AM', 'AZ', 'AF',
  'KG', 'TJ', 'TM', 'MN', 'LA', 'KH', 'BT', 'LK', 'MV', 'TL',
  'BN', 'SA', 'AE', 'IR', 'IQ', 'IL', 'JO', 'LB', 'QA', 'KW',
  'OM', 'YE', 'BH', 'SY', 'PS',
];

const _ozeanienA1  = ['AU', 'NZ', 'PG', 'FJ', 'SB', 'VU', 'WS', 'TO'];
const _ozeanienAll = [
  'AU', 'NZ', 'PG', 'FJ', 'SB', 'VU', 'WS', 'TO',
  'FM', 'PW', 'MH', 'KI', 'TV', 'NR',
];

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
  String wid, int a, int i, LernModus m, List<String> l, {
  List<String> k = const [],
}) {
  return LernStation(
    id: '${wid}_${a}_${i.toString().padLeft(2, '0')}',
    modus: m,
    fragenAnzahl: m == LernModus.sortierSpiel ? 3 : 8,
    laenderCodes: l,
    kategorien: k,
    schwierigkeitsgrad: a,
  );
}

/// Baut die Stationsliste eines Abschnitts: [anzahl] bleibt exakt wie
/// vorgegeben, nur die Modus-Verteilung kommt aus [erzeugeModusSequenz].
List<LernStation> _baueAbschnitt(
  String wid, int stufe, List<String> laender, int anzahl, {
  bool istAllerErsterAbschnitt = false,
}) {
  final modi = erzeugeModusSequenz(anzahl, stufe, istAllerErsterAbschnitt);
  return [
    for (int i = 0; i < anzahl; i++) _st(wid, stufe, i + 1, modi[i], laender),
  ];
}

// ── WELT 1 — EUROPA ───────────────────────────────────────────────────────────

final _europaA1St = _baueAbschnitt('europa', 1, _europaA1, 17,
    istAllerErsterAbschnitt: true);
final _europaA2St = _baueAbschnitt('europa', 2, _europaA2, 18);
final _europaA3St = _baueAbschnitt('europa', 3, _europaAll, 22);
final _europaA4St = _baueAbschnitt('europa', 4, _europaAll, 25);

// ── WELT 2 — SÜDAMERIKA ───────────────────────────────────────────────────────

final _suedamA1St = _baueAbschnitt('suedamerika', 1, _suedamAll, 10);
final _suedamA2St = _baueAbschnitt('suedamerika', 2, _suedamAll, 12);
final _suedamA3St = _baueAbschnitt('suedamerika', 3, _suedamAll, 14);
final _suedamA4St = _baueAbschnitt('suedamerika', 4, _suedamAll, 16);

// ── WELT 3 — NORDAMERIKA ──────────────────────────────────────────────────────

final _nordamA1St = _baueAbschnitt('nordamerika', 1, _nordamA1, 12);
final _nordamA2St = _baueAbschnitt('nordamerika', 2, _nordamAll, 14);
final _nordamA3St = _baueAbschnitt('nordamerika', 3, _nordamAll, 18);
final _nordamA4St = _baueAbschnitt('nordamerika', 4, _nordamAll, 20);

// ── WELT 4 — AFRIKA ───────────────────────────────────────────────────────────

final _afrikaA1St = _baueAbschnitt('afrika', 1, _afrikaA1, 18);
final _afrikaA2St = _baueAbschnitt('afrika', 2, _afrikaA2, 22);
final _afrikaA3St = _baueAbschnitt('afrika', 3, _afrikaAll, 26);
final _afrikaA4St = _baueAbschnitt('afrika', 4, _afrikaAll, 30);

// ── WELT 5 — ASIEN ────────────────────────────────────────────────────────────

final _asienA1St = _baueAbschnitt('asien', 1, _asienA1, 16);
final _asienA2St = _baueAbschnitt('asien', 2, _asienA2, 20);
final _asienA3St = _baueAbschnitt('asien', 3, _asienAll, 24);
final _asienA4St = _baueAbschnitt('asien', 4, _asienAll, 28);

// ── WELT 6 — OZEANIEN ─────────────────────────────────────────────────────────

final _ozeanienA1St = _baueAbschnitt('ozeanien', 1, _ozeanienA1, 10);
final _ozeanienA2St = _baueAbschnitt('ozeanien', 2, _ozeanienAll, 12);
final _ozeanienA3St = _baueAbschnitt('ozeanien', 3, _ozeanienAll, 14);
final _ozeanienA4St = _baueAbschnitt('ozeanien', 4, _ozeanienAll, 16);

// ── WELT 7 — DIE WELT ────────────────────────────────────────────────────────

final _weltA1St = _baueAbschnitt('welt', 1, _weltA1, 25);
final _weltA2St = _baueAbschnitt('welt', 2, _weltA2, 30);
final _weltA3St = _baueAbschnitt('welt', 3, _weltAlle, 35);
final _weltA4St = _baueAbschnitt('welt', 4, _weltAlle, 40);

// ── Hauptliste ────────────────────────────────────────────────────────────────

final List<LernWelt> lernwelten = [
  LernWelt(
    id: 'europa', name: 'Europa', emoji: '🇪🇺',
    kontinent: 'Europa', totalLaender: 47, laenderCodes: _europaAll,
    reihenfolge: 1,
    abschnitte: [
      LernAbschnitt(id: 'europa_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Die großen Länder Westeuropas', stationen: _europaA1St),
      LernAbschnitt(id: 'europa_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Nord- und Osteuropa', stationen: _europaA2St),
      LernAbschnitt(id: 'europa_3', stufe: 3, titel: 'Profi',
        untertitel: 'Ganz Europa meistern', stationen: _europaA3St),
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
        untertitel: 'Alle 12 Länder beherrschen', stationen: _suedamA3St),
      LernAbschnitt(id: 'suedamerika_4', stufe: 4, titel: 'Meister',
        untertitel: 'Südamerika-Experte', stationen: _suedamA4St,
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
        untertitel: 'Alle 23 Länder meistern', stationen: _nordamA3St),
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
        untertitel: 'Ganz Afrika kennen', stationen: _afrikaA3St),
      LernAbschnitt(id: 'afrika_4', stufe: 4, titel: 'Meister',
        untertitel: 'Afrika-Experte werden', stationen: _afrikaA4St,
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'asien', name: 'Asien', emoji: '🌏',
    kontinent: 'Asien', totalLaender: 45, laenderCodes: _asienAll,
    reihenfolge: 5,
    abschnitte: [
      LernAbschnitt(id: 'asien_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Die Wirtschaftsmächte Asiens', stationen: _asienA1St),
      LernAbschnitt(id: 'asien_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Naher Osten & Südostasien', stationen: _asienA2St),
      LernAbschnitt(id: 'asien_3', stufe: 3, titel: 'Profi',
        untertitel: 'Ganz Asien meistern', stationen: _asienA3St),
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
        untertitel: 'Alle 14 Inselstaaten', stationen: _ozeanienA2St),
      LernAbschnitt(id: 'ozeanien_3', stufe: 3, titel: 'Profi',
        untertitel: 'Ozeanien-Profi werden', stationen: _ozeanienA3St),
      LernAbschnitt(id: 'ozeanien_4', stufe: 4, titel: 'Meister',
        untertitel: 'Ozeanien-Experte', stationen: _ozeanienA4St,
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'welt', name: 'Die Welt', emoji: '🌐',
    kontinent: 'Welt', totalLaender: 195, laenderCodes: const ['*'],
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

String lernModusLabel(LernModus m) => switch (m) {
  LernModus.flaggenQuizBild      => 'Flaggen-Quiz (Bild)',
  LernModus.flaggenQuizMultiple  => 'Flaggen-Quiz (Multiple)',
  LernModus.hauptstaedteMultiple => 'Hauptstädte (Multiple Choice)',
  LernModus.hauptstaedteEingabe  => 'Hauptstädte (Eingabe)',
  LernModus.umrissBild           => 'Umriss-Quiz (Bild)',
  LernModus.umrissMultiple       => 'Umriss-Quiz (Multiple)',
  LernModus.waehrungsQuiz        => 'Währungs-Quiz',
  LernModus.sortierSpiel         => 'Sortier-Spiel',
  LernModus.preisSchaetzen       => 'Das große Schätzen',
  LernModus.wirtschaftssektoren  => 'Wirtschaftssektoren',
  LernModus.nachbarland          => 'Länder-Quiz (Nachbarn)',
  LernModus.bipGesamt            => 'BIP-Quiz (Gesamt)',
  LernModus.flaeche              => 'Flächen-Quiz (Größe)',
  LernModus.extremFrage          => 'Superlativ-Quiz (Extrem)',
  LernModus.waehrungZuLand       => 'Währungs-Quiz (Land)',
  LernModus.hauptstadtZuLand     => 'Hauptstädte-Quiz (Land)',
  LernModus.groessteStadt        => 'Städte-Quiz (Größte)',
  LernModus.flaggenFarbe         => 'Flaggen-Quiz (Farben)',
  LernModus.extremFrageLeicht    => 'Superlativ-Quiz (Leicht)',
  LernModus.zufallsFakt          => 'Wissens-Quiz (Fun-Fact)',
  LernModus.bekanntesGebaeude    => 'Wahrzeichen-Quiz',
};

String lernModusFragenLabel(LernStation s) =>
    s.modus == LernModus.sortierSpiel
        ? '${s.fragenAnzahl} Runden'
        : '${s.fragenAnzahl} Fragen';

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
