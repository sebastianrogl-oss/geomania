// ============================================================
// laender_fakten.dart
// Kuratierte Fun-Facts für den Quiz-Modus "zufallsFakt".
// Jeder Fakt ist wahr und lehrreich, aber nicht albern.
// Format: Frage + richtiges Land (ISO) + 3 plausible
// Ablenker (ISO), alle möglichst aus derselben Region.
// Der FragenGenerator kann die Ablenker auch dynamisch
// aus dem Kontinent ziehen; die hier angegebenen sind
// gute Vorschläge.
// ============================================================

class LandFakt {
  final String frage;
  final String richtigesLandIso;
  final List<String> ablenkerIso; // 3 plausible falsche
  final String kontinent;         // fuer Ablenker-Fallback

  const LandFakt({
    required this.frage,
    required this.richtigesLandIso,
    required this.ablenkerIso,
    required this.kontinent,
  });
}

const List<LandFakt> laenderFakten = [

  // ---------------- EUROPA ----------------
  LandFakt(
    frage: 'Welches Land hat die meisten Zeitzonen der Welt '
        '(durch seine Überseegebiete)?',
    richtigesLandIso: 'FR',
    ablenkerIso: ['GB', 'ES', 'RU'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'In welchem Land gibt es keine einzige Moschee, '
        'Kirche oder festes Gotteshaus mit Minarett – dafür '
        'aber die höchste Dichte an Schafen in Europa?',
    richtigesLandIso: 'IS',
    ablenkerIso: ['NO', 'IE', 'FI'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'Welches Land hat mehr Seen als jedes andere Land '
        'in Europa (über 180.000)?',
    richtigesLandIso: 'FI',
    ablenkerIso: ['SE', 'NO', 'EE'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'Welches Land ist so klein, dass es komplett von '
        'einer einzigen anderen Nation umschlossen wird und '
        'in Rom liegt?',
    richtigesLandIso: 'VA',
    ablenkerIso: ['SM', 'MC', 'AD'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'Welches Land hat die älteste noch bestehende '
        'Verfassungsrepublik der Welt (seit dem Jahr 301)?',
    richtigesLandIso: 'SM',
    ablenkerIso: ['CH', 'VA', 'MC'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'In welchem Land wurde die Sauna erfunden und es '
        'gibt dort mehr Saunen als Autos?',
    richtigesLandIso: 'FI',
    ablenkerIso: ['SE', 'NO', 'EE'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'Welches Land besteht aus mehr als 1.000 Inseln, '
        'von denen aber nur rund 60 bewohnt sind, und liegt '
        'in der Adria?',
    richtigesLandIso: 'HR',
    ablenkerIso: ['GR', 'IT', 'ME'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'Welches Land hat die weltweit höchste Dichte an '
        'Burgen und Schlössern pro Fläche?',
    richtigesLandIso: 'DE',
    ablenkerIso: ['FR', 'AT', 'CZ'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'In welchem Land liegt der tiefste noch begehbare '
        'Punkt Kontinentaleuropas und es gibt keine Berge '
        'über 323 Metern?',
    richtigesLandIso: 'NL',
    ablenkerIso: ['BE', 'DK', 'DE'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'Welches Land verbraucht pro Kopf am meisten '
        'Schokolade weltweit?',
    richtigesLandIso: 'CH',
    ablenkerIso: ['BE', 'DE', 'AT'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'In welchem Land steht mit dem Kolosseum eines '
        'der berühmtesten antiken Bauwerke der Welt?',
    richtigesLandIso: 'IT',
    ablenkerIso: ['GR', 'ES', 'FR'],
    kontinent: 'europa',
  ),
  LandFakt(
    frage: 'Welches Land hat keine offizielle Armee, sondern '
        'wird von seinem Nachbarland Frankreich verteidigt?',
    richtigesLandIso: 'MC',
    ablenkerIso: ['AD', 'SM', 'LI'],
    kontinent: 'europa',
  ),

  // ---------------- ASIEN ----------------
  LandFakt(
    frage: 'Welches Land ist das bevölkerungsreichste der '
        'Welt?',
    richtigesLandIso: 'IN',
    ablenkerIso: ['CN', 'ID', 'PK'],
    kontinent: 'asien',
  ),
  LandFakt(
    frage: 'In welchem Land gibt es über 6.800 Inseln, aber '
        'die meisten Menschen leben auf nur vier davon?',
    richtigesLandIso: 'JP',
    ablenkerIso: ['PH', 'ID', 'KR'],
    kontinent: 'asien',
  ),
  LandFakt(
    frage: 'Welches Land besteht aus über 17.000 Inseln und '
        'ist damit der größte Inselstaat der Welt?',
    richtigesLandIso: 'ID',
    ablenkerIso: ['PH', 'JP', 'MY'],
    kontinent: 'asien',
  ),
  LandFakt(
    frage: 'Welches Land hat mit dem Burj Khalifa das höchste '
        'Gebäude der Welt?',
    richtigesLandIso: 'AE',
    ablenkerIso: ['SA', 'QA', 'KW'],
    kontinent: 'asien',
  ),
  LandFakt(
    frage: 'In welchem Land liegt der höchste Berg der Erde, '
        'der Mount Everest, auf der Grenze?',
    richtigesLandIso: 'NP',
    ablenkerIso: ['IN', 'CN', 'BT'],
    kontinent: 'asien',
  ),
  LandFakt(
    frage: 'Welches Land misst seinen Wohlstand offiziell mit '
        'dem "Bruttonationalglück" statt nur mit Wirtschaft?',
    richtigesLandIso: 'BT',
    ablenkerIso: ['NP', 'LK', 'MV'],
    kontinent: 'asien',
  ),
  LandFakt(
    frage: 'Welches Land ist mit Abstand das flächenmäßig '
        'größte der Welt und erstreckt sich über zwei '
        'Kontinente?',
    richtigesLandIso: 'RU',
    ablenkerIso: ['CN', 'KZ', 'CA'],
    kontinent: 'asien',
  ),
  LandFakt(
    frage: 'In welchem Land liegt die Stadt-Insel mit einem '
        'der geschäftigsten Häfen der Welt und es ist selbst '
        'ein Stadtstaat?',
    richtigesLandIso: 'SG',
    ablenkerIso: ['MY', 'BN', 'TH'],
    kontinent: 'asien',
  ),
  LandFakt(
    frage: 'Welches Land war jahrhundertelang das einzige '
        'auf der Welt, das nie von einer Kolonialmacht '
        'besetzt wurde in Südostasien?',
    richtigesLandIso: 'TH',
    ablenkerIso: ['VN', 'MM', 'KH'],
    kontinent: 'asien',
  ),

  // ---------------- AFRIKA ----------------
  LandFakt(
    frage: 'In welchem Land stehen die berühmten Pyramiden '
        'von Gizeh?',
    richtigesLandIso: 'EG',
    ablenkerIso: ['SD', 'LY', 'MA'],
    kontinent: 'afrika',
  ),
  LandFakt(
    frage: 'Welches Land hat mehr Pyramiden als Ägypten, '
        'auch wenn sie weniger bekannt sind?',
    richtigesLandIso: 'SD',
    ablenkerIso: ['EG', 'ET', 'LY'],
    kontinent: 'afrika',
  ),
  LandFakt(
    frage: 'Welches Land ist das bevölkerungsreichste in '
        'Afrika?',
    richtigesLandIso: 'NG',
    ablenkerIso: ['ET', 'EG', 'CD'],
    kontinent: 'afrika',
  ),
  LandFakt(
    frage: 'In welchem Land liegt die Quelle des längsten '
        'Flusses Afrikas und es war nie europäische Kolonie?',
    richtigesLandIso: 'ET',
    ablenkerIso: ['UG', 'KE', 'SD'],
    kontinent: 'afrika',
  ),
  LandFakt(
    frage: 'Welches Land besteht fast vollständig aus '
        'Wüste (Sahara) und ist das größte in Afrika?',
    richtigesLandIso: 'DZ',
    ablenkerIso: ['LY', 'SD', 'ML'],
    kontinent: 'afrika',
  ),
  LandFakt(
    frage: 'In welchem Land leben die meisten Menschenaffen '
        'in freier Wildbahn und liegt der zweitgrößte '
        'Regenwald der Welt?',
    richtigesLandIso: 'CD',
    ablenkerIso: ['CG', 'GA', 'CM'],
    kontinent: 'afrika',
  ),
  LandFakt(
    frage: 'Welches Land ist eine Insel vor der Ostküste '
        'Afrikas mit Tieren, die es nirgends sonst gibt '
        '(z.B. Lemuren)?',
    richtigesLandIso: 'MG',
    ablenkerIso: ['MZ', 'TZ', 'KM'],
    kontinent: 'afrika',
  ),
  LandFakt(
    frage: 'In welchem Land liegt der höchste freistehende '
        'Berg der Welt, der Kilimandscharo?',
    richtigesLandIso: 'TZ',
    ablenkerIso: ['KE', 'UG', 'RW'],
    kontinent: 'afrika',
  ),

  // ---------------- NORDAMERIKA ----------------
  LandFakt(
    frage: 'Welches Land ist flächenmäßig das zweitgrößte '
        'der Welt, hat aber nur rund 40 Millionen Einwohner?',
    richtigesLandIso: 'CA',
    ablenkerIso: ['US', 'MX', 'RU'],
    kontinent: 'nordamerika',
  ),
  LandFakt(
    frage: 'In welchem Land steht die Freiheitsstatue?',
    richtigesLandIso: 'US',
    ablenkerIso: ['CA', 'MX', 'CU'],
    kontinent: 'nordamerika',
  ),
  LandFakt(
    frage: 'Welches Land schaffte 1948 seine Armee komplett '
        'ab und investiert das Geld in Bildung und Umwelt?',
    richtigesLandIso: 'CR',
    ablenkerIso: ['PA', 'NI', 'GT'],
    kontinent: 'nordamerika',
  ),
  LandFakt(
    frage: 'Durch welches Land verläuft ein berühmter Kanal, '
        'der Atlantik und Pazifik verbindet?',
    richtigesLandIso: 'PA',
    ablenkerIso: ['CR', 'NI', 'CO'],
    kontinent: 'nordamerika',
  ),
  LandFakt(
    frage: 'Welches Land besteht aus über 700 Inseln in der '
        'Karibik, von denen nur etwa 30 bewohnt sind?',
    richtigesLandIso: 'BS',
    ablenkerIso: ['CU', 'JM', 'DO'],
    kontinent: 'nordamerika',
  ),

  // ---------------- SÜDAMERIKA ----------------
  LandFakt(
    frage: 'In welchem Land liegt der größte Teil des '
        'Amazonas-Regenwaldes?',
    richtigesLandIso: 'BR',
    ablenkerIso: ['PE', 'CO', 'VE'],
    kontinent: 'suedamerika',
  ),
  LandFakt(
    frage: 'Welches Land ist das längste und schmalste der '
        'Welt und reicht von der Wüste bis fast zur Antarktis?',
    richtigesLandIso: 'CL',
    ablenkerIso: ['AR', 'PE', 'EC'],
    kontinent: 'suedamerika',
  ),
  LandFakt(
    frage: 'In welchem Land liegt die berühmte Inka-Stätte '
        'Machu Picchu?',
    richtigesLandIso: 'PE',
    ablenkerIso: ['BO', 'EC', 'CL'],
    kontinent: 'suedamerika',
  ),
  LandFakt(
    frage: 'Welches Land hat zwei Hauptstädte – eine für die '
        'Regierung, eine für die Justiz – hoch in den Anden?',
    richtigesLandIso: 'BO',
    ablenkerIso: ['PE', 'EC', 'PY',],
    kontinent: 'suedamerika',
  ),
  LandFakt(
    frage: 'In welchem Land liegt der höchste Wasserfall der '
        'Welt, der Salto Ángel?',
    richtigesLandIso: 'VE',
    ablenkerIso: ['CO', 'BR', 'GY'],
    kontinent: 'suedamerika',
  ),
  LandFakt(
    frage: 'Welches Land ist das zweitkleinste Südamerikas '
        'und die meisten Menschen sprechen dort Niederländisch?',
    richtigesLandIso: 'SR',
    ablenkerIso: ['GY', 'UY', 'EC'],
    kontinent: 'suedamerika',
  ),

  // ---------------- OZEANIEN ----------------
  LandFakt(
    frage: 'In welchem Land steht das berühmte Opernhaus von '
        'Sydney?',
    richtigesLandIso: 'AU',
    ablenkerIso: ['NZ', 'FJ', 'PG'],
    kontinent: 'ozeanien',
  ),
  LandFakt(
    frage: 'Welches Land hat mehr Schafe als Menschen – rund '
        'fünf Schafe pro Einwohner?',
    richtigesLandIso: 'NZ',
    ablenkerIso: ['AU', 'FJ', 'PG'],
    kontinent: 'ozeanien',
  ),
  LandFakt(
    frage: 'Welches Land ist ein Kontinent für sich und '
        'beherbergt Tiere wie Kängurus und Koalas?',
    richtigesLandIso: 'AU',
    ablenkerIso: ['NZ', 'ID', 'PG'],
    kontinent: 'ozeanien',
  ),
  LandFakt(
    frage: 'Welches Land ist eines der wenigen der Welt, in '
        'dem über 800 verschiedene Sprachen gesprochen werden?',
    richtigesLandIso: 'PG',
    ablenkerIso: ['ID', 'FJ', 'SB'],
    kontinent: 'ozeanien',
  ),
  LandFakt(
    frage: 'Welches winzige Inselland gehört zu den kleinsten '
        'Staaten der Welt und lebte lange vom Phosphat-Abbau?',
    richtigesLandIso: 'NR',
    ablenkerIso: ['TV', 'KI', 'PW'],
    kontinent: 'ozeanien',
  ),
];
