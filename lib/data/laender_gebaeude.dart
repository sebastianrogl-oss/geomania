// ============================================================
// laender_gebaeude.dart
// Bekannte Bauwerke & Wahrzeichen für den Quiz-Modus
// "bekanntesGebaeude" (Text-Variante).
// Frage: "In welchem Land steht [Bauwerk]?"
// Jedes Bauwerk ist weltbekannt und eindeutig einem Land
// zuzuordnen. Ablenker möglichst aus derselben Region.
// Der FragenGenerator kann Ablenker auch dynamisch aus dem
// Kontinent ziehen; die hier angegebenen sind gute Vorschläge.
// ============================================================

class LandGebaeude {
  final String bauwerk;
  final String richtigesLandIso;
  final List<String> ablenkerIso; // 3 plausible falsche
  final String kontinent;

  const LandGebaeude({
    required this.bauwerk,
    required this.richtigesLandIso,
    required this.ablenkerIso,
    required this.kontinent,
  });
}

const List<LandGebaeude> laenderGebaeude = [

  // ---------------- EUROPA ----------------
  LandGebaeude(
    bauwerk: 'der Eiffelturm',
    richtigesLandIso: 'FR',
    ablenkerIso: ['IT', 'ES', 'BE'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'das Kolosseum',
    richtigesLandIso: 'IT',
    ablenkerIso: ['GR', 'ES', 'FR'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'der Big Ben',
    richtigesLandIso: 'GB',
    ablenkerIso: ['IE', 'FR', 'NL'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'die Sagrada Família',
    richtigesLandIso: 'ES',
    ablenkerIso: ['PT', 'IT', 'FR'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'das Brandenburger Tor',
    richtigesLandIso: 'DE',
    ablenkerIso: ['AT', 'PL', 'CZ'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'der Schiefe Turm von Pisa',
    richtigesLandIso: 'IT',
    ablenkerIso: ['ES', 'GR', 'FR'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'die Akropolis',
    richtigesLandIso: 'GR',
    ablenkerIso: ['IT', 'TR', 'ES'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'Stonehenge',
    richtigesLandIso: 'GB',
    ablenkerIso: ['IE', 'FR', 'DE'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'die Windmühlen von Kinderdijk',
    richtigesLandIso: 'NL',
    ablenkerIso: ['BE', 'DE', 'DK'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'der Petersdom',
    richtigesLandIso: 'VA',
    ablenkerIso: ['IT', 'ES', 'SM'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'die Karlsbrücke',
    richtigesLandIso: 'CZ',
    ablenkerIso: ['AT', 'HU', 'PL'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'das Atomium',
    richtigesLandIso: 'BE',
    ablenkerIso: ['NL', 'FR', 'DE'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'die Kleine Meerjungfrau',
    richtigesLandIso: 'DK',
    ablenkerIso: ['SE', 'NO', 'NL'],
    kontinent: 'europa',
  ),
  LandGebaeude(
    bauwerk: 'das Schloss Neuschwanstein',
    richtigesLandIso: 'DE',
    ablenkerIso: ['AT', 'CH', 'FR'],
    kontinent: 'europa',
  ),

  // ---------------- ASIEN ----------------
  LandGebaeude(
    bauwerk: 'das Taj Mahal',
    richtigesLandIso: 'IN',
    ablenkerIso: ['PK', 'BD', 'NP'],
    kontinent: 'asien',
  ),
  LandGebaeude(
    bauwerk: 'die Chinesische Mauer',
    richtigesLandIso: 'CN',
    ablenkerIso: ['MN', 'KR', 'JP'],
    kontinent: 'asien',
  ),
  LandGebaeude(
    bauwerk: 'der Burj Khalifa',
    richtigesLandIso: 'AE',
    ablenkerIso: ['SA', 'QA', 'KW'],
    kontinent: 'asien',
  ),
  LandGebaeude(
    bauwerk: 'der Berg Fuji',
    richtigesLandIso: 'JP',
    ablenkerIso: ['KR', 'CN', 'TW'],
    kontinent: 'asien',
  ),
  LandGebaeude(
    bauwerk: 'die Tempelanlage Angkor Wat',
    richtigesLandIso: 'KH',
    ablenkerIso: ['TH', 'VN', 'LA'],
    kontinent: 'asien',
  ),
  LandGebaeude(
    bauwerk: 'die Petronas Towers',
    richtigesLandIso: 'MY',
    ablenkerIso: ['SG', 'ID', 'TH'],
    kontinent: 'asien',
  ),
  LandGebaeude(
    bauwerk: 'die Felsenstadt Petra',
    richtigesLandIso: 'JO',
    ablenkerIso: ['IL', 'SA', 'EG'],
    kontinent: 'asien',
  ),
  LandGebaeude(
    bauwerk: 'die Blaue Moschee',
    richtigesLandIso: 'TR',
    ablenkerIso: ['SA', 'IR', 'AE'],
    kontinent: 'asien',
  ),
  LandGebaeude(
    bauwerk: 'der Marina Bay Sands',
    richtigesLandIso: 'SG',
    ablenkerIso: ['MY', 'TH', 'ID'],
    kontinent: 'asien',
  ),
  LandGebaeude(
    bauwerk: 'der Tempel Borobudur',
    richtigesLandIso: 'ID',
    ablenkerIso: ['MY', 'TH', 'KH'],
    kontinent: 'asien',
  ),

  // ---------------- AFRIKA ----------------
  LandGebaeude(
    bauwerk: 'die Pyramiden von Gizeh',
    richtigesLandIso: 'EG',
    ablenkerIso: ['SD', 'LY', 'MA'],
    kontinent: 'afrika',
  ),
  LandGebaeude(
    bauwerk: 'die Große Sphinx',
    richtigesLandIso: 'EG',
    ablenkerIso: ['SD', 'LY', 'DZ'],
    kontinent: 'afrika',
  ),
  LandGebaeude(
    bauwerk: 'die Felsenkirchen von Lalibela',
    richtigesLandIso: 'ET',
    ablenkerIso: ['ER', 'SD', 'KE'],
    kontinent: 'afrika',
  ),
  LandGebaeude(
    bauwerk: 'der Tafelberg',
    richtigesLandIso: 'ZA',
    ablenkerIso: ['NA', 'BW', 'ZW'],
    kontinent: 'afrika',
  ),
  LandGebaeude(
    bauwerk: 'die Medina von Marrakesch',
    richtigesLandIso: 'MA',
    ablenkerIso: ['TN', 'DZ', 'EG'],
    kontinent: 'afrika',
  ),
  LandGebaeude(
    bauwerk: 'die Victoriafälle',
    richtigesLandIso: 'ZM',
    ablenkerIso: ['ZW', 'BW', 'MZ'],
    kontinent: 'afrika',
  ),
  LandGebaeude(
    bauwerk: 'die Lehmmoschee von Djenné',
    richtigesLandIso: 'ML',
    ablenkerIso: ['NE', 'BF', 'SN'],
    kontinent: 'afrika',
  ),

  // ---------------- NORDAMERIKA ----------------
  LandGebaeude(
    bauwerk: 'die Freiheitsstatue',
    richtigesLandIso: 'US',
    ablenkerIso: ['CA', 'MX', 'CU'],
    kontinent: 'nordamerika',
  ),
  LandGebaeude(
    bauwerk: 'der Grand Canyon',
    richtigesLandIso: 'US',
    ablenkerIso: ['CA', 'MX', 'GT'],
    kontinent: 'nordamerika',
  ),
  LandGebaeude(
    bauwerk: 'die Maya-Pyramide von Chichén Itzá',
    richtigesLandIso: 'MX',
    ablenkerIso: ['GT', 'BZ', 'HN'],
    kontinent: 'nordamerika',
  ),
  LandGebaeude(
    bauwerk: 'der CN Tower',
    richtigesLandIso: 'CA',
    ablenkerIso: ['US', 'MX', 'CU'],
    kontinent: 'nordamerika',
  ),
  LandGebaeude(
    bauwerk: 'der Panamakanal',
    richtigesLandIso: 'PA',
    ablenkerIso: ['CR', 'NI', 'CO'],
    kontinent: 'nordamerika',
  ),
  LandGebaeude(
    bauwerk: 'die Altstadt von Havanna',
    richtigesLandIso: 'CU',
    ablenkerIso: ['DO', 'JM', 'MX'],
    kontinent: 'nordamerika',
  ),

  // ---------------- SÜDAMERIKA ----------------
  LandGebaeude(
    bauwerk: 'die Christusstatue Cristo Redentor',
    richtigesLandIso: 'BR',
    ablenkerIso: ['AR', 'CO', 'PE'],
    kontinent: 'suedamerika',
  ),
  LandGebaeude(
    bauwerk: 'die Inka-Stadt Machu Picchu',
    richtigesLandIso: 'PE',
    ablenkerIso: ['BO', 'EC', 'CL'],
    kontinent: 'suedamerika',
  ),
  LandGebaeude(
    bauwerk: 'die Salzwüste Salar de Uyuni',
    richtigesLandIso: 'BO',
    ablenkerIso: ['PE', 'CL', 'AR'],
    kontinent: 'suedamerika',
  ),
  LandGebaeude(
    bauwerk: 'die Iguazú-Wasserfälle',
    richtigesLandIso: 'AR',
    ablenkerIso: ['BR', 'PY', 'UY'],
    kontinent: 'suedamerika',
  ),
  LandGebaeude(
    bauwerk: 'die Osterinsel-Statuen (Moai)',
    richtigesLandIso: 'CL',
    ablenkerIso: ['PE', 'AR', 'EC'],
    kontinent: 'suedamerika',
  ),
  LandGebaeude(
    bauwerk: 'die Galápagos-Inseln',
    richtigesLandIso: 'EC',
    ablenkerIso: ['PE', 'CO', 'CL'],
    kontinent: 'suedamerika',
  ),

  // ---------------- OZEANIEN ----------------
  LandGebaeude(
    bauwerk: 'das Opernhaus von Sydney',
    richtigesLandIso: 'AU',
    ablenkerIso: ['NZ', 'FJ', 'PG'],
    kontinent: 'ozeanien',
  ),
  LandGebaeude(
    bauwerk: 'der Uluru (Ayers Rock)',
    richtigesLandIso: 'AU',
    ablenkerIso: ['NZ', 'PG', 'FJ'],
    kontinent: 'ozeanien',
  ),
  LandGebaeude(
    bauwerk: 'die Milford-Sound-Fjorde',
    richtigesLandIso: 'NZ',
    ablenkerIso: ['AU', 'FJ', 'PG'],
    kontinent: 'ozeanien',
  ),
  LandGebaeude(
    bauwerk: 'die Harbour Bridge',
    richtigesLandIso: 'AU',
    ablenkerIso: ['NZ', 'FJ', 'SB'],
    kontinent: 'ozeanien',
  ),
];
