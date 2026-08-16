// Grenzketten-Rätsel: "Auf dem Landweg von A nach B, durch welches dieser
// Länder MUSST du dabei NICHT fahren?" — 3 echte Pflicht-Transitländer
// (mussDurchIso) als Ablenker, 1 Land das nicht auf der Route liegt
// (keinTransitIso) als richtige Antwort.
//
// Jede Kette wurde gegen die echte Nachbarn-Map (laender_nachbarn.dart)
// per Breitensuche verifiziert: sie ist der EINZIGE kürzeste Landweg
// zwischen vonLandIso und nachLandIso (4 Grenzübertritte, also genau
// 3 Zwischenländer) — siehe test/grenzketten_check.dart.
//
// Südamerika fehlt bewusst komplett: der Kontinent ist in der Nachbarn-Map
// so dicht vernetzt (maximale Distanz zwischen irgendzwei Ländern: 3
// Grenzübertritte), dass keine einzige eindeutige 4-Kanten-Route existiert.
// Nordamerika hat nur 7 statt der sonst üblichen 8-10 Einträge — der
// nutzbare Festland-Korridor ist dort fast eine einzige lineare Kette
// (US–MX–GT–BZ–HN–SV–NI–CR–PA), Karibikinseln haben keine Landgrenzen.
class GrenzkettenRaetsel {
  final String vonLandIso;
  final String nachLandIso;
  final List<String> mussDurchIso; // genau 3, in Reihenfolge von → nach
  final String keinTransitIso; // die richtige Antwort
  final String kontinent;
  final String? erklaerung;

  const GrenzkettenRaetsel({
    required this.vonLandIso,
    required this.nachLandIso,
    required this.mussDurchIso,
    required this.keinTransitIso,
    required this.kontinent,
    this.erklaerung,
  });

  /// Eindeutige ID für Anti-Wiederholung innerhalb eines Abschnitts.
  String get id => '${vonLandIso}_$nachLandIso';
}

const List<GrenzkettenRaetsel> grenzkettenRaetsel = [
  // ── Europa ────────────────────────────────────────────────────────────────
  GrenzkettenRaetsel(
    vonLandIso: 'PT',
    nachLandIso: 'PL',
    mussDurchIso: ['ES', 'FR', 'DE'],
    keinTransitIso: 'IT',
    kontinent: 'europa',
    erklaerung: 'Der direkte Landweg führt über Spanien, Frankreich und '
        'Deutschland — Italien liegt nicht auf dieser Route.',
  ),
  // DE→TR und FR→NO (bis August 2026 hier): beide nutzten PL→RU als Kanten-
  // Übergang der Route. Seit die Kaliningrad-bedingte PL/RU-Nachbarschaft aus
  // laender_nachbarn.dart entfernt wurde (siehe Konsistenz mit dem Umriss-
  // Quiz, das Kaliningrad bereits per Flächenfilter ausschließt), ist der
  // kürzeste Weg zwischen beiden Länderpaaren 5 statt 4 Kanten lang und nicht
  // mehr eindeutig (mehrere gleich kurze Routen) — beide Einträge entfernt,
  // da sich das Puzzle-Format (genau 3 Zwischenländer, eindeutiger kürzester
  // Weg) sonst nicht mehr erfüllen lässt.
  GrenzkettenRaetsel(
    vonLandIso: 'DK',
    nachLandIso: 'PT',
    mussDurchIso: ['DE', 'FR', 'ES'],
    keinTransitIso: 'IT',
    kontinent: 'europa',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'CZ',
    nachLandIso: 'PT',
    mussDurchIso: ['DE', 'FR', 'ES'],
    keinTransitIso: 'IT',
    kontinent: 'europa',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'FI',
    nachLandIso: 'HR',
    mussDurchIso: ['RU', 'UA', 'HU'],
    keinTransitIso: 'PL',
    kontinent: 'europa',
    erklaerung: 'Von Finnland aus geht es über Russland, die Ukraine und '
        'Ungarn nach Kroatien — Polen liegt nicht auf dieser Route.',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'AL',
    nachLandIso: 'IT',
    mussDurchIso: ['ME', 'HR', 'SI'],
    keinTransitIso: 'GR',
    kontinent: 'europa',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'BA',
    nachLandIso: 'FR',
    mussDurchIso: ['HR', 'SI', 'IT'],
    keinTransitIso: 'DE',
    kontinent: 'europa',
  ),
  // EE→FR (bis August 2026 hier): nutzte RU→PL als Kanten-Übergang, aus
  // demselben Grund wie oben entfernt.
  GrenzkettenRaetsel(
    vonLandIso: 'HR',
    nachLandIso: 'NO',
    mussDurchIso: ['HU', 'UA', 'RU'],
    keinTransitIso: 'PL',
    kontinent: 'europa',
  ),

  // ── Afrika ────────────────────────────────────────────────────────────────
  GrenzkettenRaetsel(
    vonLandIso: 'EG',
    nachLandIso: 'GH',
    mussDurchIso: ['LY', 'NE', 'BF'],
    keinTransitIso: 'ML',
    kontinent: 'afrika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'ET',
    nachLandIso: 'ZA',
    mussDurchIso: ['KE', 'TZ', 'MZ'],
    keinTransitIso: 'ZM',
    kontinent: 'afrika',
    erklaerung: 'Von Äthiopien führt die Route über Kenia, Tansania und '
        'Mosambik nach Südafrika — Sambia liegt nicht auf diesem Weg.',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'MA',
    nachLandIso: 'SL',
    mussDurchIso: ['DZ', 'ML', 'GN'],
    keinTransitIso: 'SN',
    kontinent: 'afrika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'NG',
    nachLandIso: 'SO',
    mussDurchIso: ['TD', 'SD', 'ET'],
    keinTransitIso: 'KE',
    kontinent: 'afrika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'CM',
    nachLandIso: 'ZA',
    mussDurchIso: ['CG', 'AO', 'NA'],
    keinTransitIso: 'ZW',
    kontinent: 'afrika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'AO',
    nachLandIso: 'BJ',
    mussDurchIso: ['CG', 'CM', 'NG'],
    keinTransitIso: 'GH',
    kontinent: 'afrika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'GM',
    nachLandIso: 'NG',
    mussDurchIso: ['SN', 'ML', 'NE'],
    keinTransitIso: 'TD',
    kontinent: 'afrika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'TN',
    nachLandIso: 'UG',
    mussDurchIso: ['LY', 'SD', 'SS'],
    keinTransitIso: 'KE',
    kontinent: 'afrika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'LS',
    nachLandIso: 'RW',
    mussDurchIso: ['ZA', 'MZ', 'TZ'],
    keinTransitIso: 'UG',
    kontinent: 'afrika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'SO',
    nachLandIso: 'ZA',
    mussDurchIso: ['KE', 'TZ', 'MZ'],
    keinTransitIso: 'ZW',
    kontinent: 'afrika',
  ),

  // ── Asien ─────────────────────────────────────────────────────────────────
  GrenzkettenRaetsel(
    vonLandIso: 'IN',
    nachLandIso: 'SA',
    mussDurchIso: ['PK', 'IR', 'IQ'],
    keinTransitIso: 'AF',
    kontinent: 'asien',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'AE',
    nachLandIso: 'PK',
    mussDurchIso: ['SA', 'IQ', 'IR'],
    keinTransitIso: 'OM',
    kontinent: 'asien',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'ID',
    nachLandIso: 'IN',
    mussDurchIso: ['MY', 'TH', 'MM'],
    keinTransitIso: 'VN',
    kontinent: 'asien',
    erklaerung: 'Von Indonesien geht es über Malaysia, Thailand und '
        'Myanmar nach Indien — Vietnam liegt nicht auf dieser Route.',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'BD',
    nachLandIso: 'ID',
    mussDurchIso: ['MM', 'TH', 'MY'],
    keinTransitIso: 'VN',
    kontinent: 'asien',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'JO',
    nachLandIso: 'KZ',
    mussDurchIso: ['IQ', 'IR', 'TM'],
    keinTransitIso: 'SA',
    kontinent: 'asien',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'MN',
    nachLandIso: 'SY',
    mussDurchIso: ['RU', 'GE', 'TR'],
    keinTransitIso: 'AM',
    kontinent: 'asien',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'LA',
    nachLandIso: 'TL',
    mussDurchIso: ['TH', 'MY', 'ID'],
    keinTransitIso: 'VN',
    kontinent: 'asien',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'AM',
    nachLandIso: 'BD',
    mussDurchIso: ['IR', 'PK', 'IN'],
    keinTransitIso: 'AF',
    kontinent: 'asien',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'PK',
    nachLandIso: 'QA',
    mussDurchIso: ['IR', 'IQ', 'SA'],
    keinTransitIso: 'AE',
    kontinent: 'asien',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'KW',
    nachLandIso: 'KZ',
    mussDurchIso: ['IQ', 'IR', 'TM'],
    keinTransitIso: 'SA',
    kontinent: 'asien',
  ),

  // ── Nordamerika ───────────────────────────────────────────────────────────
  GrenzkettenRaetsel(
    vonLandIso: 'CA',
    nachLandIso: 'HN',
    mussDurchIso: ['US', 'MX', 'GT'],
    keinTransitIso: 'PA',
    kontinent: 'nordamerika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'CA',
    nachLandIso: 'SV',
    mussDurchIso: ['US', 'MX', 'GT'],
    keinTransitIso: 'HN',
    kontinent: 'nordamerika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'GT',
    nachLandIso: 'PA',
    mussDurchIso: ['HN', 'NI', 'CR'],
    keinTransitIso: 'MX',
    kontinent: 'nordamerika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'NI',
    nachLandIso: 'US',
    mussDurchIso: ['HN', 'GT', 'MX'],
    keinTransitIso: 'CA',
    kontinent: 'nordamerika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'CR',
    nachLandIso: 'MX',
    mussDurchIso: ['NI', 'HN', 'GT'],
    keinTransitIso: 'PA',
    kontinent: 'nordamerika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'PA',
    nachLandIso: 'SV',
    mussDurchIso: ['CR', 'NI', 'HN'],
    keinTransitIso: 'GT',
    kontinent: 'nordamerika',
  ),
  GrenzkettenRaetsel(
    vonLandIso: 'BZ',
    nachLandIso: 'CR',
    mussDurchIso: ['GT', 'HN', 'NI'],
    keinTransitIso: 'MX',
    kontinent: 'nordamerika',
  ),
];
