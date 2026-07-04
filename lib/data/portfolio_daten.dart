// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Datenmodell (Phase 1)
// Länderprofile, Markt-News-Pool und Makro-Trend-Pool für das Portfolio-Spiel.
// ══════════════════════════════════════════════════════════════════════════════

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

String kontinentName(String iso) {
  switch (landKontinent[iso]) {
    case 'europa':   return 'Europa';
    case 'asien':    return 'Asien';
    case 'amerika':  return 'Amerika';
    case 'afrika':   return 'Afrika';
    case 'ozeanien': return 'Ozeanien';
    default:         return 'Andere';
  }
}

// ── Markt-News ───────────────────────────────────────────────────────────────

class MarktNews {
  final String titel;
  final String klartext;
  final List<String> gewinner;
  final List<String> verlierer;
  final String sektor;
  final double staerke;

  const MarktNews({
    required this.titel,
    required this.klartext,
    required this.gewinner,
    required this.verlierer,
    required this.sektor,
    required this.staerke,
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
];

// ── Makro-Trend ──────────────────────────────────────────────────────────────

class MakroTrend {
  final String name;
  final String beschreibung; // kurzer Klartext für das Banner, z.B. "Tech profitiert"
  final String sektor;
  final double staerke;      // Bonus pro Tag in %
  final int dauerTage;       // 5-7 Tage

  const MakroTrend({
    required this.name,
    required this.beschreibung,
    required this.sektor,
    required this.staerke,
    required this.dauerTage,
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
    dauerTage: 5,
  ),
  MakroTrend(
    name: 'KI-Revolution',
    beschreibung: 'Tech profitiert',
    sektor: 'technologie',
    staerke: 2.0,
    dauerTage: 7,
  ),
  MakroTrend(
    name: 'Rohstoff-Superzyklus',
    beschreibung: 'Rohstoffe profitieren',
    sektor: 'rohstoffe',
    staerke: 1.8,
    dauerTage: 6,
  ),
  MakroTrend(
    name: 'Globale Ernährungssicherheit',
    beschreibung: 'Landwirtschaft profitiert',
    sektor: 'landwirtschaft',
    staerke: 1.5,
    dauerTage: 5,
  ),
  MakroTrend(
    name: 'Rüstungs-Ära',
    beschreibung: 'Industrie profitiert',
    sektor: 'industrie',
    staerke: 1.6,
    dauerTage: 6,
  ),
];
