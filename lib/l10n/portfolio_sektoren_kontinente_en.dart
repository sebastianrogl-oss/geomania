// Englische Übersetzungen für die Portfolio-Spiel-Sektoren (portfolioSektoren,
// portfolio_daten.dart) und -Kontinente (kontinentNameFuerId,
// portfolio_daten.dart). Eigene, dedizierte Maps statt Wiederverwendung von
// wirtschaftssektorenEn (wirtschaftssektoren_en.dart) — die dortigen 8
// Kategorien sind ein anderes Feature (Wirtschaftssektoren-Quiz) mit anderen
// Bezeichnungen (z.B. "Industrie & Produktion" statt "Industrie", "Bergbau &
// Rohstoffe" statt "Rohstoffe") und würden für die 6 Portfolio-Sektoren nur
// zufällig bei 2 von 6 Namen (Technologie, Landwirtschaft) übereinstimmen.
const Map<String, String> portfolioSektorenEn = {
  'Technologie': 'Technology',
  'Energie': 'Energy',
  'Industrie': 'Industry',
  'Finanzen': 'Finance',
  'Rohstoffe': 'Commodities',
  'Landwirtschaft': 'Agriculture',
};

const Map<String, String> portfolioKontinenteEn = {
  'Europa': 'Europe',
  'Asien': 'Asia',
  'Amerika': 'The Americas',
  'Afrika': 'Africa',
  'Ozeanien': 'Oceania',
  'Andere': 'Other',
};
