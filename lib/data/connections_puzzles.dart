import 'package:flutter/material.dart' show Color;

const Color kCnYellow = Color(0xFFF9C74F);
const Color kCnGreen  = Color(0xFF4A9E4A);
const Color kCnBlue   = Color(0xFF4A90D9);
const Color kCnPurple = Color(0xFF8B5CF6);

class ConnectionsGroup {
  final String label;
  final List<String> iso2s;
  final Color color;
  final int difficulty; // 0=easiest … 3=hardest

  const ConnectionsGroup({
    required this.label,
    required this.iso2s,
    required this.color,
    required this.difficulty,
  });
}

class ConnectionsPuzzle {
  final String title;
  final List<ConnectionsGroup> groups; // exactly 4

  const ConnectionsPuzzle({required this.title, required this.groups});
}

const List<ConnectionsPuzzle> connectionsPuzzles = [
  // ── Puzzle 0 ─────────────────────────────────────────────────────────────
  ConnectionsPuzzle(
    title: 'Wirtschaftsblöcke I',
    groups: [
      ConnectionsGroup(label: 'Eurozone-Gründungsländer (1999)', iso2s: ['DE','FR','IT','ES'], color: kCnYellow, difficulty: 0),
      ConnectionsGroup(label: 'G7-Mitglieder außerhalb Europas',  iso2s: ['US','CA','JP','GB'], color: kCnGreen,  difficulty: 1),
      ConnectionsGroup(label: 'OPEC-Mitglieder am Golf',           iso2s: ['SA','IR','IQ','KW'], color: kCnBlue,   difficulty: 2),
      ConnectionsGroup(label: 'BIP pro Kopf > 80.000 USD',         iso2s: ['NO','CH','SG','LU'], color: kCnPurple, difficulty: 3),
    ],
  ),
  // ── Puzzle 1 ─────────────────────────────────────────────────────────────
  ConnectionsPuzzle(
    title: 'Weltregionen & Allianzen',
    groups: [
      ConnectionsGroup(label: 'BRICS-Mitglieder (4 von 5)',         iso2s: ['BR','RU','IN','ZA'], color: kCnYellow, difficulty: 0),
      ConnectionsGroup(label: 'ASEAN-Mitglieder',                    iso2s: ['TH','MY','ID','VN'], color: kCnGreen,  difficulty: 1),
      ConnectionsGroup(label: 'Nordafrikanische Länder',             iso2s: ['EG','MA','DZ','LY'], color: kCnBlue,   difficulty: 2),
      ConnectionsGroup(label: 'Staatsfonds > 500 Mrd. USD',         iso2s: ['CN','AE','NO','SG'], color: kCnPurple, difficulty: 3),
    ],
  ),
  // ── Puzzle 2 ─────────────────────────────────────────────────────────────
  ConnectionsPuzzle(
    title: 'Währungen der Welt',
    groups: [
      ConnectionsGroup(label: 'Länder mit eigenem "Dollar"',        iso2s: ['US','CA','AU','NZ'], color: kCnYellow, difficulty: 0),
      ConnectionsGroup(label: 'Länder mit eigenem "Peso"',          iso2s: ['MX','AR','CL','PH'], color: kCnGreen,  difficulty: 1),
      ConnectionsGroup(label: 'Länder mit Krone/Krona/Koruna',      iso2s: ['SE','DK','IS','CZ'], color: kCnBlue,   difficulty: 2),
      ConnectionsGroup(label: 'Golfrat (GCC)-Mitglieder',          iso2s: ['SA','QA','BH','OM'], color: kCnPurple, difficulty: 3),
    ],
  ),
  // ── Puzzle 3 ─────────────────────────────────────────────────────────────
  ConnectionsPuzzle(
    title: 'Afrika – Wirtschaft & Ressourcen',
    groups: [
      ConnectionsGroup(label: 'Größte Volkswirtschaften Afrikas',   iso2s: ['NG','EG','ZA','ET'], color: kCnYellow, difficulty: 0),
      ConnectionsGroup(label: 'OPEC-Mitglieder in Afrika',          iso2s: ['DZ','LY','GA','CG'], color: kCnGreen,  difficulty: 1),
      ConnectionsGroup(label: 'Südafrikanische Zollunion (SACU)',   iso2s: ['ZA','NA','BW','LS'], color: kCnBlue,   difficulty: 2),
      ConnectionsGroup(label: 'Nutzen den CFA-Franc (BCEAO)',       iso2s: ['SN','CI','CM','BJ'], color: kCnPurple, difficulty: 3),
    ],
  ),
  // ── Puzzle 4 ─────────────────────────────────────────────────────────────
  ConnectionsPuzzle(
    title: 'Europa & Asien – Blöcke',
    groups: [
      ConnectionsGroup(label: 'Seit 2010 zur Eurozone beigetreten', iso2s: ['EE','LV','LT','HR'], color: kCnYellow, difficulty: 0),
      ConnectionsGroup(label: 'ASEAN-Gründungsmitglieder (1967)',   iso2s: ['ID','MY','PH','TH'], color: kCnGreen,  difficulty: 1),
      ConnectionsGroup(label: 'Staatsverschuldung > 130 % des BIP', iso2s: ['JP','GR','IT','PT'], color: kCnBlue,   difficulty: 2),
      ConnectionsGroup(label: 'G20-Mitglieder in Amerika',          iso2s: ['US','CA','BR','AR'], color: kCnPurple, difficulty: 3),
    ],
  ),
  // ── Puzzle 5 ─────────────────────────────────────────────────────────────
  ConnectionsPuzzle(
    title: 'Energie & Bevölkerung',
    groups: [
      ConnectionsGroup(label: 'Nordische Länder (Norden Europas)',  iso2s: ['SE','NO','DK','FI'], color: kCnYellow, difficulty: 0),
      ConnectionsGroup(label: 'BRICS-Neue Mitglieder (2024)',       iso2s: ['EG','ET','IR','AE'], color: kCnGreen,  difficulty: 1),
      ConnectionsGroup(label: 'Bevölkerung > 200 Mio. Einwohner',  iso2s: ['CN','IN','ID','PK'], color: kCnBlue,   difficulty: 2),
      ConnectionsGroup(label: 'Größte Erdölreserven der Welt',      iso2s: ['SA','VE','CA','IQ'], color: kCnPurple, difficulty: 3),
    ],
  ),
  // ── Puzzle 6 ─────────────────────────────────────────────────────────────
  ConnectionsPuzzle(
    title: 'Währungsgruppen II',
    groups: [
      ConnectionsGroup(label: 'Länder mit Rupie als Währung',       iso2s: ['IN','PK','LK','NP'], color: kCnYellow, difficulty: 0),
      ConnectionsGroup(label: 'Länder mit Dinar als Währung',       iso2s: ['DZ','TN','IQ','LY'], color: kCnGreen,  difficulty: 1),
      ConnectionsGroup(label: 'Länder mit Rial/Riyal als Währung',  iso2s: ['SA','IR','OM','QA'], color: kCnBlue,   difficulty: 2),
      ConnectionsGroup(label: 'Sowohl G20 als auch NATO',           iso2s: ['US','DE','GB','FR'], color: kCnPurple, difficulty: 3),
    ],
  ),
  // ── Puzzle 7 ─────────────────────────────────────────────────────────────
  ConnectionsPuzzle(
    title: 'Handelsmächte & Ressourcen',
    groups: [
      ConnectionsGroup(label: 'Visegrád-Gruppe (EU-Beitritt 2004)', iso2s: ['PL','HU','CZ','SK'], color: kCnYellow, difficulty: 0),
      ConnectionsGroup(label: 'Bedeutende Ölproduzenten Afrikas',   iso2s: ['NG','AO','GA','GQ'], color: kCnGreen,  difficulty: 1),
      ConnectionsGroup(label: 'BIP > 1 Bio.\$ (nicht G7, kein CN)', iso2s: ['KR','AU','RU','BR'], color: kCnBlue,   difficulty: 2),
      ConnectionsGroup(label: 'Landlocked Asien > 10 Mio. Einw.',  iso2s: ['AF','KZ','UZ','NP'], color: kCnPurple, difficulty: 3),
    ],
  ),
  // ── Puzzle 8 ─────────────────────────────────────────────────────────────
  ConnectionsPuzzle(
    title: 'Karibik & Pazifik',
    groups: [
      ConnectionsGroup(label: 'Karibische Inselstaaten',            iso2s: ['CU','JM','TT','DO'], color: kCnYellow, difficulty: 0),
      ConnectionsGroup(label: 'Größte Volkswirtschaften Ozeaniens', iso2s: ['AU','NZ','PG','FJ'], color: kCnGreen,  difficulty: 1),
      ConnectionsGroup(label: 'Bevölkerungsreichste Demokratien',   iso2s: ['IN','US','BR','ID'], color: kCnBlue,   difficulty: 2),
      ConnectionsGroup(label: 'Länder mit Flat Tax',                iso2s: ['EE','LV','LT','RO'], color: kCnPurple, difficulty: 3),
    ],
  ),
  // ── Puzzle 9 ─────────────────────────────────────────────────────────────
  ConnectionsPuzzle(
    title: 'Schulden & Niedrige Geburtenraten',
    groups: [
      ConnectionsGroup(label: 'Maghreb-Länder',                     iso2s: ['MA','DZ','TN','LY'], color: kCnYellow, difficulty: 0),
      ConnectionsGroup(label: 'Größte Erdölreserven (andere)',      iso2s: ['VE','RU','KW','AE'], color: kCnGreen,  difficulty: 1),
      ConnectionsGroup(label: 'Niedrigste Geburtenraten weltweit',  iso2s: ['KR','JP','IT','ES'], color: kCnBlue,   difficulty: 2),
      ConnectionsGroup(label: 'Asiatische Wirtschaftsmächte G20',   iso2s: ['CN','JP','KR','IN'], color: kCnPurple, difficulty: 3),
    ],
  ),
];
