// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Datenmodell (Phase 1)
// Länderprofile, Markt-News-Pool und Makro-Trend-Pool für das Portfolio-Spiel.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart' show Color, HSLColor;
import '../l10n/uebersetzungen.dart';
import 'country_rankings.dart';

String landName(String iso) =>
    countryRankings.firstWhere((c) => c.iso2 == iso).name;

// ── Sektoren ─────────────────────────────────────────────────────────────────

class PortfolioSektor {
  final String id;
  final String name;
  final String emoji;
  const PortfolioSektor({required this.id, required this.name, required this.emoji});
}

const List<PortfolioSektor> portfolioSektoren = [
  PortfolioSektor(id: 'technologie',    name: 'Technologie',    emoji: '💻'),
  PortfolioSektor(id: 'energie',        name: 'Energie',        emoji: '⚡'),
  PortfolioSektor(id: 'industrie',      name: 'Industrie',      emoji: '🏭'),
  PortfolioSektor(id: 'finanzen',       name: 'Finanzen',       emoji: '🏦'),
  PortfolioSektor(id: 'rohstoffe',      name: 'Rohstoffe',      emoji: '⛏️'),
  PortfolioSektor(id: 'landwirtschaft', name: 'Landwirtschaft', emoji: '🌾'),
];

const Map<String, Color> portfolioSektorFarben = {
  'technologie':    Color(0xFF4A90D9),
  'energie':        Color(0xFFF9A825),
  'industrie':      Color(0xFF546E7A),
  'finanzen':       Color(0xFF4A9E4A),
  'rohstoffe':      Color(0xFF8D6E63),
  'landwirtschaft': Color(0xFF8BC34A),
};

/// Dunklere Variante einer Sektorfarbe (reduzierte Helligkeit über HSL) für
/// Text auf hellem, leicht eingefärbtem Hintergrund — hellere Basisfarben
/// wie landwirtschaft (0xFF8BC34A) wären als Text sonst schlecht lesbar.
Color sektorFarbeDunkel(String? sektorId) {
  final basis = portfolioSektorFarben[sektorId] ?? const Color(0xFF888888);
  final hsl = HSLColor.fromColor(basis);
  return hsl.withLightness((hsl.lightness * 0.65).clamp(0.0, 1.0)).toColor();
}

/// Relative Stärke (0.0-1.0) eines Sektors in einem Land, basierend auf der
/// Reihenfolge in LandProfil.sektoren (Index 0 = stärkster Sektor).
double getLandSektorStaerke(String iso, String sektorId) {
  final sektoren = landProfile[iso]?.sektoren ?? const [];
  final index = sektoren.indexOf(sektorId);
  if (index == -1) return 0.0;
  return index == 0 ? 1.0 : 0.55;
}

// ── Länderprofil ─────────────────────────────────────────────────────────────

class LandProfil {
  final String iso;
  final double basisWachstum; // erwartete Tagesrendite in % (-1.0 bis +2.5)
  final double risiko;        // Volatilität 0.0-1.0 (entwickelt niedrig, Schwellenland hoch)
  final List<String> sektoren; // 1-3 Hauptsektoren des Landes

  const LandProfil({
    required this.iso,
    required this.basisWachstum,
    required this.risiko,
    required this.sektoren,
  });
}

const Map<String, LandProfil> landProfile = {
  // ── Entwickelte Länder (niedriges Risiko) ─────────────────────────────────
  'US': LandProfil(iso: 'US', basisWachstum: 1.2, risiko: 0.25, sektoren: ['technologie', 'finanzen']),
  'DE': LandProfil(iso: 'DE', basisWachstum: 0.4, risiko: 0.20, sektoren: ['industrie', 'technologie']),
  'JP': LandProfil(iso: 'JP', basisWachstum: 0.3, risiko: 0.20, sektoren: ['technologie', 'industrie']),
  'GB': LandProfil(iso: 'GB', basisWachstum: 0.6, risiko: 0.25, sektoren: ['finanzen', 'technologie']),
  'FR': LandProfil(iso: 'FR', basisWachstum: 0.5, risiko: 0.20, sektoren: ['industrie', 'finanzen']),
  'CH': LandProfil(iso: 'CH', basisWachstum: 0.8, risiko: 0.15, sektoren: ['finanzen', 'technologie']),
  'NL': LandProfil(iso: 'NL', basisWachstum: 0.7, risiko: 0.20, sektoren: ['finanzen', 'industrie']),
  'SE': LandProfil(iso: 'SE', basisWachstum: 0.9, risiko: 0.20, sektoren: ['technologie', 'industrie']),
  'CA': LandProfil(iso: 'CA', basisWachstum: 0.9, risiko: 0.25, sektoren: ['rohstoffe', 'energie']),
  'AU': LandProfil(iso: 'AU', basisWachstum: 1.0, risiko: 0.30, sektoren: ['rohstoffe', 'energie']),
  'NZ': LandProfil(iso: 'NZ', basisWachstum: 0.8, risiko: 0.25, sektoren: ['landwirtschaft', 'rohstoffe']),
  'SG': LandProfil(iso: 'SG', basisWachstum: 1.3, risiko: 0.20, sektoren: ['finanzen', 'technologie']),
  'KR': LandProfil(iso: 'KR', basisWachstum: 1.4, risiko: 0.30, sektoren: ['technologie', 'industrie']),
  'NO': LandProfil(iso: 'NO', basisWachstum: 0.7, risiko: 0.25, sektoren: ['energie', 'rohstoffe']),
  'DK': LandProfil(iso: 'DK', basisWachstum: 0.9, risiko: 0.20, sektoren: ['energie', 'technologie']),
  'IL': LandProfil(iso: 'IL', basisWachstum: 1.5, risiko: 0.35, sektoren: ['technologie', 'finanzen']),
  'AE': LandProfil(iso: 'AE', basisWachstum: 1.6, risiko: 0.30, sektoren: ['energie', 'finanzen']),
  'SA': LandProfil(iso: 'SA', basisWachstum: 1.3, risiko: 0.35, sektoren: ['energie', 'rohstoffe']),
  'QA': LandProfil(iso: 'QA', basisWachstum: 1.2, risiko: 0.30, sektoren: ['energie', 'finanzen']),
  'IT': LandProfil(iso: 'IT', basisWachstum: 0.2, risiko: 0.30, sektoren: ['industrie', 'landwirtschaft']),
  'ES': LandProfil(iso: 'ES', basisWachstum: 0.9, risiko: 0.30, sektoren: ['landwirtschaft', 'industrie']),
  'PL': LandProfil(iso: 'PL', basisWachstum: 1.6, risiko: 0.35, sektoren: ['industrie', 'technologie']),

  // ── Schwellenländer (mittleres bis hohes Risiko) ──────────────────────────
  'CN': LandProfil(iso: 'CN', basisWachstum: 2.0, risiko: 0.50, sektoren: ['industrie', 'technologie']),
  'IN': LandProfil(iso: 'IN', basisWachstum: 2.3, risiko: 0.55, sektoren: ['technologie', 'landwirtschaft']),
  'BR': LandProfil(iso: 'BR', basisWachstum: 1.0, risiko: 0.65, sektoren: ['landwirtschaft', 'rohstoffe']),
  'MX': LandProfil(iso: 'MX', basisWachstum: 1.1, risiko: 0.55, sektoren: ['industrie', 'energie']),
  'ID': LandProfil(iso: 'ID', basisWachstum: 1.8, risiko: 0.60, sektoren: ['landwirtschaft', 'industrie']),
  'VN': LandProfil(iso: 'VN', basisWachstum: 2.2, risiko: 0.60, sektoren: ['industrie', 'landwirtschaft']),
  'TH': LandProfil(iso: 'TH', basisWachstum: 1.3, risiko: 0.55, sektoren: ['landwirtschaft', 'industrie']),
  'ZA': LandProfil(iso: 'ZA', basisWachstum: 0.6, risiko: 0.70, sektoren: ['rohstoffe', 'industrie']),
  'NG': LandProfil(iso: 'NG', basisWachstum: 1.0, risiko: 0.85, sektoren: ['energie', 'landwirtschaft']),
  'EG': LandProfil(iso: 'EG', basisWachstum: 1.4, risiko: 0.75, sektoren: ['landwirtschaft', 'energie']),
  'TR': LandProfil(iso: 'TR', basisWachstum: 0.5, risiko: 0.85, sektoren: ['industrie', 'finanzen']),
  'AR': LandProfil(iso: 'AR', basisWachstum: -0.5, risiko: 0.90, sektoren: ['landwirtschaft', 'rohstoffe']),
  'UY': LandProfil(iso: 'UY', basisWachstum: 1.0, risiko: 0.40, sektoren: ['landwirtschaft', 'rohstoffe']),
  'CL': LandProfil(iso: 'CL', basisWachstum: 1.0, risiko: 0.60, sektoren: ['rohstoffe', 'landwirtschaft']),
  'PE': LandProfil(iso: 'PE', basisWachstum: 1.2, risiko: 0.65, sektoren: ['rohstoffe', 'landwirtschaft']),
  'CO': LandProfil(iso: 'CO', basisWachstum: 1.1, risiko: 0.65, sektoren: ['energie', 'rohstoffe']),
  'KE': LandProfil(iso: 'KE', basisWachstum: 1.5, risiko: 0.70, sektoren: ['landwirtschaft', 'technologie']),
  'GH': LandProfil(iso: 'GH', basisWachstum: 1.6, risiko: 0.75, sektoren: ['rohstoffe', 'landwirtschaft']),
  'PK': LandProfil(iso: 'PK', basisWachstum: 0.7, risiko: 0.80, sektoren: ['landwirtschaft', 'industrie']),
  'BD': LandProfil(iso: 'BD', basisWachstum: 2.0, risiko: 0.70, sektoren: ['landwirtschaft', 'industrie']),
  'KZ': LandProfil(iso: 'KZ', basisWachstum: 1.0, risiko: 0.70, sektoren: ['energie', 'rohstoffe']),
  'UA': LandProfil(iso: 'UA', basisWachstum: -1.0, risiko: 1.00, sektoren: ['landwirtschaft', 'industrie']),
  'RU': LandProfil(iso: 'RU', basisWachstum: -0.3, risiko: 0.90, sektoren: ['energie', 'rohstoffe']),
};

// ── Kontinent-Zuordnung ────────────────────────────────────────────────────────

const Map<String, String> landKontinent = {
  'DE': 'europa', 'GB': 'europa', 'FR': 'europa', 'CH': 'europa', 'NL': 'europa',
  'SE': 'europa', 'NO': 'europa', 'DK': 'europa', 'IT': 'europa', 'ES': 'europa',
  'PL': 'europa', 'UA': 'europa', 'RU': 'europa',
  'JP': 'asien', 'SG': 'asien', 'KR': 'asien', 'IL': 'asien', 'AE': 'asien',
  'SA': 'asien', 'QA': 'asien', 'CN': 'asien', 'IN': 'asien', 'ID': 'asien',
  'VN': 'asien', 'TH': 'asien', 'TR': 'asien', 'PK': 'asien', 'BD': 'asien',
  'KZ': 'asien',
  'US': 'amerika', 'CA': 'amerika', 'MX': 'amerika', 'BR': 'amerika',
  'AR': 'amerika', 'UY': 'amerika', 'CL': 'amerika', 'PE': 'amerika', 'CO': 'amerika',
  'ZA': 'afrika', 'NG': 'afrika', 'EG': 'afrika', 'KE': 'afrika', 'GH': 'afrika',
  'AU': 'ozeanien', 'NZ': 'ozeanien',
};

String kontinentName(String iso) => kontinentNameFuerId(landKontinent[iso]);

/// Wie kontinentName(), nimmt aber direkt eine Kontinent-ID entgegen (z.B.
/// aus MarktNews.allianzKontinente) statt eines Länder-ISO-Codes.
String kontinentNameFuerId(String? kontinentId) {
  switch (kontinentId) {
    case 'europa':   return t('Europa');
    case 'asien':    return t('Asien');
    case 'amerika':  return t('Amerika');
    case 'afrika':   return t('Afrika');
    case 'ozeanien': return t('Ozeanien');
    default:         return t('Andere');
  }
}

/// Einzige Quelle für Kontinent-Badge-Farben — von den Länderkarten
/// (portfolio_investieren_screen.dart) UND den Allianz-News-Badges
/// (portfolio_marktbriefing_screen.dart) gemeinsam genutzt, keine Duplikation.
const Map<String, Color> kontinentFarben = {
  'europa': Color(0xFF1565C0),
  'asien': Color(0xFF7C3AED),
  'amerika': Color(0xFF2E7D32),
  'afrika': Color(0xFFE65100),
  'ozeanien': Color(0xFF00838F),
};

Color kontinentFarbeFuerId(String? kontinentId) =>
    kontinentFarben[kontinentId] ?? const Color(0xFF888888);

// ── Markt-News ───────────────────────────────────────────────────────────────

enum NewsTyp {
  standard,          // Sektor + mehrere Länder (Alt-Typ, seit dem festen
                     // 3-Slot-Aufbau nicht mehr Teil der täglichen Ziehung —
                     // siehe getHeutigeNews in portfolio_markt_service.dart)
  einzelLand,        // genau EIN benanntes Land, kein Cluster
  sektorKombination, // wirkt nur als Portfolio-Bonus (siehe berechneSektorKomboBonus),
                     // wenn in BEIDE genannten Sektoren investiert wurde
  kontinentsAllianz, // wirkt nur als Portfolio-Bonus (siehe berechneAllianzBonus),
                     // kein Effekt auf einzelne Länder-Renditen
  extremEreignis,    // Bandbreite statt fixem Wert, tatsächlicher Effekt wird
                     // seed-basiert innerhalb der Spanne gezogen
}

class MarktNews {
  final NewsTyp typ;
  final String titel;
  final String klartext;
  final List<String> gewinner;
  final List<String> verlierer;
  // Bei standard/einzelLand gesetzt; bei kontinentsAllianz/extremEreignis null,
  // da dort sektor bzw. staerke keine Bedeutung haben (siehe unten).
  final String? sektor;
  final double? staerke; // Prozentpunkte, wie der Rest der Engine sie erwartet

  // NUR bei kontinentsAllianz: Bonus wirkt, wenn das Portfolio je mind. 1 Land
  // aus JEDEM genannten Kontinent enthält (siehe berechneAllianzBonus).
  final List<String>? allianzKontinente;
  final double? allianzBonus; // Prozentpunkte

  // NUR bei sektorKombination: Bonus wirkt, wenn in BEIDE genannten Sektoren
  // tatsächlich investiert wurde (siehe berechneSektorKomboBonus).
  final List<String>? sektorKombo; // genau 2 Sektor-IDs
  final double? sektorKomboBonus; // Prozentpunkte

  // NUR bei extremEreignis: die dem Spieler VORAB gezeigte Bandbreite
  // (Prozentpunkte). Der tatsächliche Effekt wird seed-basiert innerhalb
  // dieser Spanne gezogen (siehe extremEreignisWert in
  // portfolio_rendite_service.dart) und erst im Ergebnis sichtbar.
  final double? bandbreiteMin;
  final double? bandbreiteMax;

  const MarktNews({
    this.typ = NewsTyp.standard,
    required this.titel,
    required this.klartext,
    required this.gewinner,
    required this.verlierer,
    this.sektor,
    this.staerke,
    this.allianzKontinente,
    this.allianzBonus,
    this.sektorKombo,
    this.sektorKomboBonus,
    this.bandbreiteMin,
    this.bandbreiteMax,
  });
}

const List<MarktNews> newsPool = [
  MarktNews(
    titel: 'Notenbank senkt Zinsen',
    klartext: 'Billiges Geld beflügelt Wachstumsmärkte und Aktien.',
    gewinner: ['US', 'IN', 'BR', 'ID'],
    verlierer: [],
    sektor: 'finanzen',
    staerke: 2.0,
  ),
  MarktNews(
    titel: 'Lieferketten-Störung in Asien',
    klartext: 'Produktion stockt — Industrieländer leiden kurzfristig.',
    gewinner: [],
    verlierer: ['CN', 'VN', 'TH', 'DE'],
    sektor: 'industrie',
    staerke: -1.8,
  ),
  MarktNews(
    titel: 'Rekord-Ernte in Südamerika',
    klartext: 'Agrar-Exporteure verdienen kräftig mit.',
    gewinner: ['BR', 'AR', 'UY'],
    verlierer: [],
    sektor: 'landwirtschaft',
    staerke: 1.6,
  ),
  MarktNews(
    titel: 'Ölpreis bricht ein',
    klartext: 'Öl-Exporteure verlieren, Importländer atmen auf.',
    gewinner: ['JP', 'IN', 'DE'],
    verlierer: ['SA', 'RU', 'NG'],
    sektor: 'energie',
    staerke: -2.0,
  ),
  MarktNews(
    titel: 'KI-Boom beschleunigt sich',
    klartext: 'Tech-Konzerne stecken Milliarden in KI-Infrastruktur.',
    gewinner: ['US', 'KR', 'SG', 'IL'],
    verlierer: [],
    sektor: 'technologie',
    staerke: 2.2,
  ),
  MarktNews(
    titel: 'Goldpreis erreicht Rekordhoch',
    klartext: 'Anleger flüchten in sichere Häfen — Förderländer profitieren.',
    gewinner: ['ZA', 'AU', 'PE'],
    verlierer: [],
    sektor: 'rohstoffe',
    staerke: 1.9,
  ),
  MarktNews(
    titel: 'Handelskrieg eskaliert',
    klartext: 'Neue Zölle bremsen den Welthandel — Exportnationen trifft es hart.',
    gewinner: [],
    verlierer: ['CN', 'DE', 'KR'],
    sektor: 'industrie',
    staerke: -1.5,
  ),
  MarktNews(
    titel: 'Dürre in Ostafrika',
    klartext: 'Missernten treiben Nahrungsmittelpreise — Landwirtschaft leidet.',
    gewinner: [],
    verlierer: ['KE', 'GH', 'NG'],
    sektor: 'landwirtschaft',
    staerke: -1.7,
  ),
  MarktNews(
    titel: 'Batterie-Rohstoffboom',
    klartext: 'E-Auto-Boom treibt die Nachfrage nach Lithium und Kupfer.',
    gewinner: ['CL', 'PE', 'CO'],
    verlierer: [],
    sektor: 'rohstoffe',
    staerke: 2.1,
  ),
  MarktNews(
    titel: 'Chip-Nachfrage übertrifft Erwartungen',
    klartext: 'Halbleiterhersteller melden Rekordgewinne.',
    gewinner: ['KR', 'US', 'JP'],
    verlierer: [],
    sektor: 'technologie',
    staerke: 1.8,
  ),
  MarktNews(
    titel: 'Zinswende in den USA',
    klartext: 'Höhere US-Zinsen stärken den Dollar — Schwellenländer mit Dollarschulden leiden.',
    gewinner: ['US'],
    verlierer: ['TR', 'AR', 'ZA'],
    sektor: 'finanzen',
    staerke: -1.4,
  ),
  MarktNews(
    titel: 'Erneuerbaren-Ausbau übertrifft Plan',
    klartext: 'Grüne Energie wird schneller ausgebaut als erwartet — Ölländer verlieren Boden.',
    gewinner: ['DK', 'NO', 'DE'],
    verlierer: ['SA', 'RU'],
    sektor: 'energie',
    staerke: 1.7,
  ),
  MarktNews(
    titel: 'Reshoring-Welle',
    klartext: 'Firmen verlagern Produktion näher an westliche Absatzmärkte.',
    gewinner: ['MX', 'VN', 'PL'],
    verlierer: ['CN'],
    sektor: 'industrie',
    staerke: 1.6,
  ),
  MarktNews(
    titel: 'Safe-Haven-Zuflüsse',
    klartext: 'Unsicherheit treibt Kapital in stabile Finanzplätze.',
    gewinner: ['CH', 'SG', 'US'],
    verlierer: [],
    sektor: 'finanzen',
    staerke: 1.3,
  ),
  MarktNews(
    titel: 'Globale Ernährungssicherheits-Initiative',
    klartext: 'Investitionen in Agrartechnik sollen Ernteerträge absichern.',
    gewinner: ['IN', 'VN', 'TH', 'BD'],
    verlierer: [],
    sektor: 'landwirtschaft',
    staerke: 1.5,
  ),
  MarktNews(
    titel: 'Ölschwemme durch Überproduktion',
    klartext: 'Angebotsüberschuss drückt den Ölpreis — Importländer profitieren.',
    gewinner: ['IN', 'JP'],
    verlierer: ['SA', 'RU', 'NG', 'AE'],
    sektor: 'energie',
    staerke: -1.6,
  ),
  MarktNews(
    titel: 'Rohstoffpreise brechen ein',
    klartext: 'Nachfrageschwäche in China trifft Bergbau- und Agrarnationen.',
    gewinner: [],
    verlierer: ['AU', 'CL', 'ZA', 'PE'],
    sektor: 'rohstoffe',
    staerke: -1.4,
  ),
  MarktNews(
    titel: 'Regulierung bremst Big Tech',
    klartext: 'Neue Kartellauflagen belasten große Technologiekonzerne.',
    gewinner: [],
    verlierer: ['US', 'CN'],
    sektor: 'technologie',
    staerke: -1.3,
  ),

  // ── Zusätzliche Nachrichten: konkrete Details, Gerüchte, Zwei-Sektor-Kombos ──
  MarktNews(
    titel: 'IWF senkt Finanzierungskosten-Prognose',
    klartext: 'Der Internationale Währungsfonds erwartet 2,3 Prozentpunkte '
        'niedrigere Kreditkosten für Schwellenländer.',
    gewinner: ['BR', 'ID', 'ZA'],
    verlierer: [],
    sektor: 'finanzen',
    staerke: 1.4,
  ),
  MarktNews(
    titel: 'Foxconn kündigt 12-Milliarden-Dollar-Werk an',
    klartext: 'Der taiwanesische Auftragsfertiger baut eine neue '
        'Chipfabrik — Zulieferer jubeln.',
    gewinner: ['VN', 'IN', 'US'],
    verlierer: [],
    sektor: 'technologie',
    staerke: 1.9,
  ),
  MarktNews(
    titel: 'Gerücht: OPEC+ plant Förderkürzung um 2 Mio. Barrel',
    klartext: 'Berichten zufolge beraten Saudi-Arabien und Russland eine '
        'drastische Drosselung — noch unbestätigt.',
    gewinner: ['SA', 'RU', 'AE', 'QA'],
    verlierer: ['JP', 'IN', 'DE'],
    sektor: 'energie',
    staerke: 1.7,
  ),
  MarktNews(
    titel: 'Weltbank vergibt 4-Milliarden-Kredit für Agrar-Infrastruktur',
    klartext: 'Bewässerungsprojekte auf drei Kontinenten sollen die Ernten '
        'um 15 % steigern.',
    gewinner: ['KE', 'GH', 'BD', 'VN'],
    verlierer: [],
    sektor: 'landwirtschaft',
    staerke: 1.3,
  ),
  MarktNews(
    titel: 'Halbleiter-Exportverbot trifft Zulieferer hart',
    klartext: 'Neue US-Kontrollen bremsen Chip-Lieferungen — Rohstoffländer '
        'für Seltene Erden gewinnen an Bedeutung.',
    gewinner: ['AU', 'CL'],
    verlierer: ['CN', 'KR'],
    sektor: 'technologie',
    staerke: -1.6,
  ),
  MarktNews(
    titel: 'Gerücht: Norwegischer Staatsfonds erhöht Öl-Anteil',
    klartext: 'Noch unbestätigt, aber Insider sprechen von einer '
        'Umschichtung von 18 Milliarden Dollar Richtung Energie.',
    gewinner: ['NO', 'SA', 'AE'],
    verlierer: [],
    sektor: 'energie',
    staerke: 1.5,
  ),
  MarktNews(
    titel: 'Rekordinflation in der Türkei erreicht 68 %',
    klartext: 'Die Zentralbank kämpft mit Kapitalflucht — die Lira gerät '
        'weiter unter Druck.',
    gewinner: [],
    verlierer: ['TR'],
    sektor: 'finanzen',
    staerke: -1.8,
  ),
  MarktNews(
    titel: '5G-Ausbau in Südostasien beschleunigt sich',
    klartext: 'Vietnam und Thailand vergeben Lizenzen im Wert von '
        '3,5 Milliarden Dollar.',
    gewinner: ['VN', 'TH', 'KR'],
    verlierer: [],
    sektor: 'technologie',
    staerke: 1.6,
  ),
  MarktNews(
    titel: 'Kupferpreis explodiert nach Minenstreik in Chile',
    klartext: 'Die weltgrößte Kupfermine steht still — Industrieländer mit '
        'hohem Kupferbedarf leiden.',
    gewinner: ['CL', 'PE'],
    verlierer: ['DE', 'JP', 'KR'],
    sektor: 'rohstoffe',
    staerke: 1.9,
  ),
  MarktNews(
    titel: 'Gerücht: EZB erwägt weitere Zinssenkung',
    klartext: 'Berichten zufolge wird eine Senkung um 0,25 Prozentpunkte im '
        'nächsten Quartal diskutiert — offiziell dementiert.',
    gewinner: ['DE', 'FR', 'IT', 'ES', 'NL'],
    verlierer: [],
    sektor: 'finanzen',
    staerke: 1.2,
  ),
  MarktNews(
    titel: 'Dürre am Panamakanal verzögert Welthandel',
    klartext: 'Niedrige Wasserstände zwingen zu Frachtbeschränkungen — '
        'Exportnationen spüren Verzögerungen.',
    gewinner: [],
    verlierer: ['MX', 'CO', 'CL'],
    sektor: 'industrie',
    staerke: -1.5,
  ),
  MarktNews(
    titel: 'Saudi-Arabiens NEOM-Projekt vergibt 8-Milliarden-Auftrag',
    klartext: 'Bauunternehmen aus mehreren Ländern profitieren vom '
        'Wüstenstadt-Megaprojekt.',
    gewinner: ['SA', 'AE', 'KR'],
    verlierer: [],
    sektor: 'industrie',
    staerke: 1.7,
  ),
  MarktNews(
    titel: 'Sojabohnen-Ernte in Brasilien übertrifft Erwartungen um 9 %',
    klartext: 'Ideales Wetter beschert eine Rekordernte — Exporteure '
        'sichern sich neue Marktanteile.',
    gewinner: ['BR', 'AR'],
    verlierer: [],
    sektor: 'landwirtschaft',
    staerke: 1.6,
  ),
  MarktNews(
    titel: 'Gerücht: Apple verlagert weitere Produktion nach Indien',
    klartext: 'Noch unbestätigt, aber Zulieferer berichten von neuen '
        'Kapazitäten im Wert von 2 Milliarden Dollar.',
    gewinner: ['IN', 'VN'],
    verlierer: ['CN'],
    sektor: 'industrie',
    staerke: 1.4,
  ),
  MarktNews(
    titel: 'Grüner-Wasserstoff-Deal zwischen EU und Nahost',
    klartext: 'Milliarden-Investitionen in Wasserstoff-Exportterminals — '
        'klassische Öl-Einnahmen geraten unter Druck.',
    gewinner: ['AE', 'QA', 'DE', 'DK'],
    verlierer: ['RU'],
    sektor: 'energie',
    staerke: 1.5,
  ),
  MarktNews(
    titel: 'Bankenkrise in Argentinien: Kapitalverkehr verschärft',
    klartext: 'Die Zentralbank begrenzt Dollar-Abflüsse auf 200 Dollar pro '
        'Monat und Person.',
    gewinner: [],
    verlierer: ['AR'],
    sektor: 'finanzen',
    staerke: -1.6,
  ),
  MarktNews(
    titel: 'Vietnam unterzeichnet neues Freihandelsabkommen',
    klartext: 'Zollfreier Zugang für Textil- und Elektronikexporte im '
        'Volumen von 6 Milliarden Euro.',
    gewinner: ['VN', 'TH'],
    verlierer: [],
    sektor: 'industrie',
    staerke: 1.5,
  ),

  // ── Wildcards: seltene Großereignisse mit doppelter Stärke ──────────────────
  // Erkennbar über staerke.abs() >= 3.0 (siehe istGrossereignisNews) — alle
  // regulären Einträge oben bleiben deutlich darunter (max. 2,2).
  MarktNews(
    titel: 'Gerücht: Notenbanken planen koordinierte Mega-Zinssenkung',
    klartext: 'Berichten zufolge bereiten Fed, EZB und BoJ eine gemeinsame '
        'Senkung um einen vollen Prozentpunkt vor — historisch beispiellos.',
    gewinner: ['US', 'DE', 'JP', 'GB', 'FR'],
    verlierer: [],
    sektor: 'finanzen',
    staerke: 3.6,
  ),
  MarktNews(
    titel: 'Fusionsreaktor-Durchbruch: Netto-Energiegewinn im Dauerbetrieb',
    klartext: 'Ein internationales Forscherteam meldet einen historischen '
        'Durchbruch — die Energiemärkte geraten in Aufruhr.',
    gewinner: ['US', 'KR', 'JP', 'FR'],
    verlierer: ['SA', 'RU', 'AE'],
    sektor: 'energie',
    staerke: 3.8,
  ),
  MarktNews(
    titel: 'Globaler Chip-Lieferstopp nach Taiwan-Spannungen',
    klartext: 'Eskalierende Spannungen in der Straße von Taiwan legen die '
        'weltweit wichtigste Chipfertigung lahm.',
    gewinner: ['KR', 'US', 'IN'],
    verlierer: ['CN', 'JP', 'DE'],
    sektor: 'technologie',
    staerke: -4.0,
  ),
];

/// Seltene "Großereignis"-News wirken doppelt so stark wie reguläre News
/// (staerke.abs() >= 3.0 statt der üblichen ~1.3-2.2) — daran werden sie
/// klassifiziert, ohne dass MarktNews ein eigenes Flag-Feld braucht.
bool istGrossereignisNews(MarktNews n) => (n.staerke ?? 0).abs() >= 3.0;

// ── Einzelland-News ──────────────────────────────────────────────────────────
// GENAU EIN benanntes Land (kein Cluster wie bei newsPool) — konzentrierter,
// daher spürbar stärkere Werte als die diffusen Standard-News.

const List<MarktNews> einzelLandPool = [
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Japan kündigt Mega-Konjunkturprogramm an',
    klartext: 'Die japanische Regierung pumpt umgerechnet 200 Milliarden '
        'Dollar in die Wirtschaft.',
    gewinner: ['JP'],
    verlierer: [],
    staerke: 5.0,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Argentinien vor Staatspleite-Sorgen',
    klartext: 'Ratingagenturen senken Argentiniens Kreditwürdigkeit weiter ab.',
    gewinner: [],
    verlierer: ['AR'],
    staerke: -4.0,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Deutschland meldet Export-Rekord',
    klartext: 'Der deutsche Maschinenbau verzeichnet das stärkste Quartal '
        'seit einem Jahrzehnt.',
    gewinner: ['DE'],
    verlierer: [],
    staerke: 3.5,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Türkische Lira stürzt weiter ab',
    klartext: 'Die Währungskrise verschärft sich trotz Notenbank-Eingriffen.',
    gewinner: [],
    verlierer: ['TR'],
    staerke: -5.5,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Südkorea meldet Halbleiter-Exportboom',
    klartext: 'Samsung und SK Hynix verzeichnen Rekordbestellungen aus aller Welt.',
    gewinner: ['KR'],
    verlierer: [],
    staerke: 4.5,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Nigeria meldet neuen Ölfund vor der Küste',
    klartext: 'Geologen schätzen die neuen Reserven auf mehrere Milliarden Barrel.',
    gewinner: ['NG'],
    verlierer: [],
    staerke: 6.0,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Ratingagentur stuft Großbritannien herab',
    klartext: 'Hohe Staatsverschuldung und schwaches Wachstum belasten die Bonität.',
    gewinner: [],
    verlierer: ['GB'],
    staerke: -3.0,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Vietnams Auslandsinvestitionen verdoppeln sich',
    klartext: 'Internationale Konzerne verlagern massiv Produktion nach Vietnam.',
    gewinner: ['VN'],
    verlierer: [],
    staerke: 4.0,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Ägypten erhält IWF-Rettungspaket',
    klartext: 'Ein Kredit über 8 Milliarden Dollar soll die Devisenkrise entschärfen.',
    gewinner: ['EG'],
    verlierer: [],
    staerke: 3.0,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Neue Sanktionswelle trifft Russland',
    klartext: 'Weitere Banken werden vom internationalen Zahlungsverkehr abgeschnitten.',
    gewinner: [],
    verlierer: ['RU'],
    staerke: -6.0,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Brasiliens Zentralbank überrascht mit Zinssenkung',
    klartext: 'Die Selic-Rate fällt stärker als von Analysten erwartet.',
    gewinner: ['BR'],
    verlierer: [],
    staerke: 3.5,
  ),
  MarktNews(
    typ: NewsTyp.einzelLand,
    titel: 'Frankenaufwertung belastet Schweizer Exporteure',
    klartext: 'Der starke Franken verteuert Schweizer Produkte im Ausland spürbar.',
    gewinner: [],
    verlierer: ['CH'],
    staerke: -2.5,
  ),
];

// ── Kontinents-Allianz-News ──────────────────────────────────────────────────
// Wirken NICHT auf einzelne Länder-Renditen, sondern nur als zusätzlicher,
// vom bestehenden "gleicher Kontinent"-Bonus (kontinentsBonusProzent)
// unabhängiger Portfolio-Bonus — siehe berechneAllianzBonus() in
// portfolio_rendite_service.dart.

const List<MarktNews> kontinentsAllianzPool = [
  MarktNews(
    typ: NewsTyp.kontinentsAllianz,
    titel: 'Historischer Dreier-Deal',
    klartext: 'Amerika, Asien und Europa einigen sich auf ein neues '
        'Freihandelsabkommen. Wer in allen drei Regionen investiert ist, '
        'profitiert von Zoll-Erleichterungen.',
    gewinner: [],
    verlierer: [],
    allianzKontinente: ['amerika', 'asien', 'europa'],
    allianzBonus: 4.0,
  ),
  MarktNews(
    typ: NewsTyp.kontinentsAllianz,
    titel: 'Rohstoff-Süd-Bündnis',
    klartext: 'Amerika und Afrika bündeln ihre Rohstoff-Exporte in einem '
        'neuen Bündnis — beide Regionen gemeinsam im Portfolio zahlt sich aus.',
    gewinner: [],
    verlierer: [],
    allianzKontinente: ['amerika', 'afrika'],
    allianzBonus: 3.5,
  ),
  MarktNews(
    typ: NewsTyp.kontinentsAllianz,
    titel: 'Pazifik-Allianz erneuert',
    klartext: 'Asien und Ozeanien vertiefen ihre Wirtschaftsbeziehungen. '
        'Investitionen in beiden Regionen gleichzeitig werden belohnt.',
    gewinner: [],
    verlierer: [],
    allianzKontinente: ['asien', 'ozeanien'],
    allianzBonus: 3.0,
  ),
  MarktNews(
    typ: NewsTyp.kontinentsAllianz,
    titel: 'Europa-Afrika-Partnerschaft',
    klartext: 'Ein neues Investitionsabkommen verknüpft europäische und '
        'afrikanische Märkte enger als je zuvor.',
    gewinner: [],
    verlierer: [],
    allianzKontinente: ['europa', 'afrika'],
    allianzBonus: 3.2,
  ),
  MarktNews(
    typ: NewsTyp.kontinentsAllianz,
    titel: 'Transatlantische Achse',
    klartext: 'Europa und Amerika bauen ihre Handelsbeziehungen mit einem '
        'neuen Rahmenabkommen weiter aus.',
    gewinner: [],
    verlierer: [],
    allianzKontinente: ['europa', 'amerika'],
    allianzBonus: 3.3,
  ),
  MarktNews(
    typ: NewsTyp.kontinentsAllianz,
    titel: 'Weltgipfel-Abkommen',
    klartext: 'Drei Kontinente einigen sich auf ein gemeinsames '
        'Klima-Investitionspaket — ein seltener Schulterschluss mit '
        'entsprechend großer Belohnung für breit aufgestellte Portfolios.',
    gewinner: [],
    verlierer: [],
    // Max. 3 Kontinente: ein Portfolio hat nur 3 Länder, ein Bonus mit mehr
    // geforderten Kontinenten wäre nie erreichbar.
    allianzKontinente: ['amerika', 'europa', 'afrika'],
    allianzBonus: 5.0,
  ),
  MarktNews(
    typ: NewsTyp.kontinentsAllianz,
    titel: 'Süd-Ost-Kooperation',
    klartext: 'Afrika und Asien gründen eine gemeinsame Handelskammer für '
        'aufstrebende Märkte.',
    gewinner: [],
    verlierer: [],
    allianzKontinente: ['afrika', 'asien'],
    allianzBonus: 3.0,
  ),
  MarktNews(
    typ: NewsTyp.kontinentsAllianz,
    titel: 'Ozeanien-Amerika-Brücke',
    klartext: 'Ein neues Rohstoff-Abkommen verbindet Ozeanien und Amerika '
        'über den Pazifik hinweg.',
    gewinner: [],
    verlierer: [],
    allianzKontinente: ['ozeanien', 'amerika'],
    allianzBonus: 2.8,
  ),
  MarktNews(
    typ: NewsTyp.kontinentsAllianz,
    titel: 'Rohstoff-Achse Süd',
    klartext: 'Afrika und Ozeanien koordinieren ihre Förderpolitik bei '
        'kritischen Rohstoffen.',
    gewinner: [],
    verlierer: [],
    allianzKontinente: ['afrika', 'ozeanien'],
    allianzBonus: 3.0,
  ),
  MarktNews(
    typ: NewsTyp.kontinentsAllianz,
    titel: 'Globaler Konsens',
    klartext: 'Drei weit voneinander entfernte Weltregionen einigen sich '
        'auf ein gemeinsames Wirtschaftsabkommen — ein seltener Moment für '
        'global breit gestreute Portfolios.',
    gewinner: [],
    verlierer: [],
    // Max. 3 Kontinente (siehe oben) — bewusst eine andere 3er-Kombination
    // als "Weltgipfel-Abkommen" und "Historischer Dreier-Deal".
    allianzKontinente: ['asien', 'afrika', 'ozeanien'],
    allianzBonus: 5.5,
  ),
];

// ── Sektor-Kombinations-News ──────────────────────────────────────────────────
// Wirken NICHT auf einzelne Länder-Renditen, sondern nur als Portfolio-Bonus,
// wenn tatsächlich in BEIDE genannten Sektoren investiert wurde (Gewicht > 0%)
// — siehe berechneSektorKomboBonus() in portfolio_rendite_service.dart.

const List<MarktNews> sektorKombinationPool = [
  MarktNews(
    typ: NewsTyp.sektorKombination,
    titel: 'Agrar-Industrie-Boom',
    klartext: 'Landmaschinen-Hersteller und Großbauern profitieren gemeinsam '
        'von neuen Subventionen. Wer in beide Sektoren investiert, verdient '
        'doppelt.',
    gewinner: [],
    verlierer: [],
    sektorKombo: ['landwirtschaft', 'industrie'],
    sektorKomboBonus: 3.0,
  ),
  MarktNews(
    typ: NewsTyp.sektorKombination,
    titel: 'Tech-Finanz-Symbiose',
    klartext: 'Fintech-Investitionen beflügeln sowohl Technologie- als auch '
        'Finanzunternehmen gleichzeitig.',
    gewinner: [],
    verlierer: [],
    sektorKombo: ['technologie', 'finanzen'],
    sektorKomboBonus: 3.5,
  ),
  MarktNews(
    typ: NewsTyp.sektorKombination,
    titel: 'Energie-Rohstoff-Achse',
    klartext: 'Energiekonzerne und Rohstoffförderer schließen sich zu '
        'gemeinsamen Fördergroßprojekten zusammen.',
    gewinner: [],
    verlierer: [],
    sektorKombo: ['energie', 'rohstoffe'],
    sektorKomboBonus: 3.2,
  ),
  MarktNews(
    typ: NewsTyp.sektorKombination,
    titel: 'Schwerindustrie-Aufschwung',
    klartext: 'Stahlhersteller und Bergbaukonzerne verzeichnen gemeinsam '
        'steigende Auftragsbücher.',
    gewinner: [],
    verlierer: [],
    sektorKombo: ['industrie', 'rohstoffe'],
    sektorKomboBonus: 3.0,
  ),
  MarktNews(
    typ: NewsTyp.sektorKombination,
    titel: 'Rohstoff-Finanzierungswelle',
    klartext: 'Banken vergeben günstige Kredite an Rohstoffförderer — beide '
        'Branchen profitieren von der neuen Liquidität.',
    gewinner: [],
    verlierer: [],
    sektorKombo: ['finanzen', 'rohstoffe'],
    sektorKomboBonus: 2.8,
  ),
  MarktNews(
    typ: NewsTyp.sektorKombination,
    titel: 'Automatisierungs-Schub',
    klartext: 'Industrieroboter-Hersteller und Softwarekonzerne treiben '
        'gemeinsam die Fabrik-Automatisierung voran.',
    gewinner: [],
    verlierer: [],
    sektorKombo: ['technologie', 'industrie'],
    sektorKomboBonus: 3.3,
  ),
  MarktNews(
    typ: NewsTyp.sektorKombination,
    titel: 'Grüne Investitionswelle',
    klartext: 'Investmentfonds stecken Milliarden gezielt in erneuerbare '
        'Energieprojekte.',
    gewinner: [],
    verlierer: [],
    sektorKombo: ['energie', 'finanzen'],
    sektorKomboBonus: 3.0,
  ),
  MarktNews(
    typ: NewsTyp.sektorKombination,
    titel: 'Agrar-Rohstoff-Verbund',
    klartext: 'Düngemittelhersteller und Agrarbetriebe profitieren '
        'gemeinsam von steigenden Weltmarktpreisen.',
    gewinner: [],
    verlierer: [],
    sektorKombo: ['landwirtschaft', 'rohstoffe'],
    sektorKomboBonus: 2.9,
  ),
  MarktNews(
    typ: NewsTyp.sektorKombination,
    titel: 'CleanTech-Boom',
    klartext: 'Batterie-Technologie und Energiekonzerne treiben gemeinsam '
        'die Energiewende voran.',
    gewinner: [],
    verlierer: [],
    sektorKombo: ['technologie', 'energie'],
    sektorKomboBonus: 3.6,
  ),
  MarktNews(
    typ: NewsTyp.sektorKombination,
    titel: 'Agrar-Finanzierungspaket',
    klartext: 'Neue Förderkredite erleichtern Landwirten den Zugang zu '
        'Kapital für Investitionen.',
    gewinner: [],
    verlierer: [],
    sektorKombo: ['landwirtschaft', 'finanzen'],
    sektorKomboBonus: 2.7,
  ),
];

// ── Extremereignis-News ──────────────────────────────────────────────────────
// Statt eines fixen Werts wird eine Bandbreite gezeigt — der tatsächliche
// Effekt wird seed-basiert innerhalb dieser Spanne gezogen (siehe
// extremEreignisWert() in portfolio_rendite_service.dart) und bleibt bis zur
// Auflösung verborgen. Manche Spannen sind eindeutig gerichtet (nur Verlust
// oder nur Gewinn möglich), andere echt gemischt (Spanne überschreitet 0).

const List<MarktNews> extremEreignisPool = [
  MarktNews(
    typ: NewsTyp.extremEreignis,
    titel: 'Naturkatastrophe in Südostasien',
    klartext: 'Ein schweres Erdbeben trifft die Region — Ausmaß der '
        'wirtschaftlichen Folgen noch ungewiss.',
    gewinner: [],
    verlierer: ['ID', 'VN', 'TH'],
    bandbreiteMin: -20.0,
    bandbreiteMax: -3.0,
  ),
  MarktNews(
    typ: NewsTyp.extremEreignis,
    titel: 'Überraschender Rohstofffund',
    klartext: 'Geologen entdecken riesige Lithium-Vorkommen — die genauen '
        'Auswirkungen auf den Markt sind noch unklar.',
    gewinner: ['CL', 'AU', 'AR'],
    verlierer: [],
    bandbreiteMin: 5.0,
    bandbreiteMax: 35.0,
  ),
  MarktNews(
    typ: NewsTyp.extremEreignis,
    titel: 'Politischer Umsturz in der Türkei',
    klartext: 'Nach überraschenden Neuwahlen ist unklar, ob sich die Lage '
        'stabilisiert oder weiter zuspitzt.',
    gewinner: ['TR'],
    verlierer: [],
    bandbreiteMin: -15.0,
    bandbreiteMax: 5.0,
  ),
  MarktNews(
    typ: NewsTyp.extremEreignis,
    titel: 'Regionaler Krankheitsausbruch',
    klartext: 'Gesundheitsbehörden warnen vor einer möglichen Epidemie — '
        'das wirtschaftliche Ausmaß hängt von der Eindämmung ab.',
    gewinner: [],
    verlierer: ['IN', 'BD', 'PK'],
    bandbreiteMin: -18.0,
    bandbreiteMax: -2.0,
  ),
  MarktNews(
    typ: NewsTyp.extremEreignis,
    titel: 'Technologie-Durchbruch ungewisser Tragweite',
    klartext: 'Ein neuer Chip-Fertigungsprozess wird vorgestellt — ob er '
        'sich durchsetzt oder floppt, ist völlig offen.',
    gewinner: ['US', 'KR', 'IL'],
    verlierer: [],
    bandbreiteMin: -5.0,
    bandbreiteMax: 25.0,
  ),
  MarktNews(
    typ: NewsTyp.extremEreignis,
    titel: 'Zentralbank-Interventions-Gerücht',
    klartext: 'Berichten zufolge erwägt die EZB einen überraschenden '
        'Eingriff — die Marktreaktion ist kaum vorherzusagen.',
    gewinner: ['DE', 'FR', 'IT'],
    verlierer: [],
    bandbreiteMin: -8.0,
    bandbreiteMax: 12.0,
  ),
  MarktNews(
    typ: NewsTyp.extremEreignis,
    titel: 'Grenzkonflikt eskaliert möglicherweise',
    klartext: 'Truppenbewegungen sorgen für Nervosität — ob es zur '
        'offenen Eskalation kommt, ist noch unklar.',
    gewinner: [],
    verlierer: ['RU', 'UA'],
    bandbreiteMin: -25.0,
    bandbreiteMax: -5.0,
  ),
  MarktNews(
    typ: NewsTyp.extremEreignis,
    titel: 'Massive Auslandsinvestition unklarer Herkunft',
    klartext: 'Ein milliardenschwerer Investitionsfonds kündigt Engagement '
        'an — Details und Absichten bleiben vage.',
    gewinner: ['EG', 'KE', 'GH'],
    verlierer: [],
    bandbreiteMin: -3.0,
    bandbreiteMax: 20.0,
  ),
  MarktNews(
    typ: NewsTyp.extremEreignis,
    titel: 'Wahlentscheid mit ungewissen Marktfolgen',
    klartext: 'Der Wahlausgang in Mexiko ist völlig offen — beide möglichen '
        'Ergebnisse hätten spürbare, aber gegensätzliche Auswirkungen.',
    gewinner: ['MX'],
    verlierer: [],
    bandbreiteMin: -10.0,
    bandbreiteMax: 10.0,
  ),
];

// ── Makro-Trend ──────────────────────────────────────────────────────────────

class MakroTrend {
  final String name;
  final String beschreibung; // kurzer Klartext für das Banner, z.B. "Tech profitiert"
  final String sektor;
  final double staerke;      // Bonus für diesen Tag in %

  const MakroTrend({
    required this.name,
    required this.beschreibung,
    required this.sektor,
    required this.staerke,
  });
}

// ── Rang-Titel (Progression nach Kapital) ─────────────────────────────────────

class RangTitel {
  final double schwelle;
  final String titel;
  const RangTitel({required this.schwelle, required this.titel});
}

const List<RangTitel> rangTitel = [
  RangTitel(schwelle: 1000,   titel: 'Sparbuch-Anfänger'),
  RangTitel(schwelle: 2000,   titel: 'Junior-Analyst'),
  RangTitel(schwelle: 5000,   titel: 'Portfoliomanager'),
  RangTitel(schwelle: 10000,  titel: 'Fondsmanager'),
  RangTitel(schwelle: 25000,  titel: 'Investmentbanker'),
  RangTitel(schwelle: 50000,  titel: 'Hedgefonds-Stratege'),
  RangTitel(schwelle: 100000, titel: 'Wall-Street-Legende'),
];

typedef RangFortschritt = ({
  String titel,
  double? naechsteSchwelle,
  double fortschritt, // 0.0-1.0 bis zum nächsten Titel (1.0 = höchster Rang)
});

RangFortschritt rangFuerKapital(double kapital) {
  var aktuell = rangTitel.first;
  for (final r in rangTitel) {
    if (kapital >= r.schwelle) {
      aktuell = r;
    } else {
      break;
    }
  }
  final idx = rangTitel.indexOf(aktuell);
  if (idx == rangTitel.length - 1) {
    return (titel: aktuell.titel, naechsteSchwelle: null, fortschritt: 1.0);
  }
  final naechste = rangTitel[idx + 1];
  final spanne = naechste.schwelle - aktuell.schwelle;
  final fortschritt = ((kapital - aktuell.schwelle) / spanne).clamp(0.0, 1.0);
  return (titel: aktuell.titel, naechsteSchwelle: naechste.schwelle, fortschritt: fortschritt);
}

int _rangIndexFuerKapital(double kapital) {
  var idx = 0;
  for (var i = 0; i < rangTitel.length; i++) {
    if (kapital >= rangTitel[i].schwelle) idx = i;
  }
  return idx;
}

/// Gibt den neu erreichten Rang-Titel zurück, wenn [neuesKapital] gegenüber
/// [altesKapital] eine höhere Rang-Stufe erreicht hat — sonst null.
String? neuerRangBeiAufstieg(double altesKapital, double neuesKapital) {
  final alterIndex = _rangIndexFuerKapital(altesKapital);
  final neuerIndex = _rangIndexFuerKapital(neuesKapital);
  return neuerIndex > alterIndex ? rangTitel[neuerIndex].titel : null;
}

const List<MakroTrend> trendPool = [
  MakroTrend(
    name: 'Energiewende',
    beschreibung: 'Erneuerbare & Energie profitieren',
    sektor: 'energie',
    staerke: 1.5,
  ),
  MakroTrend(
    name: 'KI-Revolution',
    beschreibung: 'Tech profitiert',
    sektor: 'technologie',
    staerke: 2.0,
  ),
  MakroTrend(
    name: 'Rohstoff-Superzyklus',
    beschreibung: 'Rohstoffe profitieren',
    sektor: 'rohstoffe',
    staerke: 1.8,
  ),
  MakroTrend(
    name: 'Globale Ernährungssicherheit',
    beschreibung: 'Landwirtschaft profitiert',
    sektor: 'landwirtschaft',
    staerke: 1.5,
  ),
  MakroTrend(
    name: 'Rüstungs-Ära',
    beschreibung: 'Industrie profitiert',
    sektor: 'industrie',
    staerke: 1.6,
  ),
  MakroTrend(
    name: 'Kapitalflucht in Finanzplätze',
    beschreibung: 'Finanzsektor profitiert',
    sektor: 'finanzen',
    staerke: 1.4,
  ),
];
