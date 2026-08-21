// Übersetzungen für die Vergleichskategorie-Labels, die von DREI Stellen
// geteilt werden: _SpielKategorie (station_session_service.dart, 7
// Kategorien für Sortier-Spiel/Preis-Schätzen im Lernpfad) und
// RankingCategory (country_rankings.dart, 20 Kategorien für Higher/Lower,
// Ranking-Quiz und die Preis-Schätzen-Tages-Challenge). Beide Klassen nutzen
// denselben t()-Getter-Mechanismus, daher genügt eine gemeinsame Map.
const Map<String, String> spielkategorienEn = {
  'Bevölkerung': 'Population',
  'BIP gesamt': 'Total GDP',
  'BIP pro Kopf': 'GDP per capita',
  'Fläche': 'Area',
  'Lebenserwartung': 'Life expectancy',
  'Küstenlänge': 'Coastline',
  'Küstenlinie': 'Coastline',
  'Mindestlohn': 'Minimum wage',
  'Internetgeschwindigkeit': 'Internet speed',
  'Korruptionsindex': 'Corruption index',
  'Pressefreiheitsindex': 'Press freedom index',
  'Glücksindex': 'Happiness index',
  'Tourismuseinnahmen': 'Tourism revenue',
  'Militärausgaben': 'Military spending',
  'Geburtenrate': 'Birth rate',
  'Waldanteil': 'Forest cover',
  'Alkoholkonsum': 'Alcohol consumption',
  'Olympia-Medaillen': 'Olympic medals',
  'Höchster Punkt': 'Highest point',
  'Inflationsrate': 'Inflation rate',
  'Staatsschulden': 'National debt',

  // Einheiten, die bis zuletzt ohne englische Fassung waren. "% BIP" braucht
  // das Länder-Ranking, die übrigen vier erscheinen in Higher/Lower und im
  // Ranking-Quiz.
  '% BIP': '% of GDP',
  'Mrd. USD': 'B USD',
  'Kinder/Frau': 'children/woman',
  'L/Kopf': 'L/person',
  'Medaillen': 'medals',

  'Einwohner': 'people',
  'Jahre': 'years',
  'USD/Monat': 'USD/month',
};
