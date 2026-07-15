// Englische Sektor-Namen für wirtschaftssektoren.dart, Quiz-Modus
// "wirtschaftssektoren". sektorEmojisEn ist eine EIGENE, englisch-keyed
// Kopie von sektorEmojis (wirtschaftssektoren.dart) — die deutschen Keys
// dort bleiben unverändert (sie sind zugleich SektorData.mainSector-Werte,
// eine reine Daten-Vergleichsbasis), daher braucht die UI-Emoji-Suche
// (_labelFor in station_quiz_screen.dart) im Englisch-Modus eine eigene,
// englisch-keyed Variante statt einer Textübersetzung der deutschen Map.
const Map<String, String> wirtschaftssektorenEn = {
  'Öl & Gas': 'Oil & Gas',
  'Technologie': 'Technology',
  'Landwirtschaft': 'Agriculture',
  'Tourismus': 'Tourism',
  'Industrie & Produktion': 'Industry & Manufacturing',
  'Bergbau & Rohstoffe': 'Mining & Raw Materials',
  'Finanzdienstleistungen': 'Financial Services',
  'Handel & Logistik': 'Trade & Logistics',
};

const Map<String, String> sektorEmojisEn = {
  'Oil & Gas': '🛢️',
  'Technology': '💻',
  'Agriculture': '🌾',
  'Tourism': '🏖️',
  'Industry & Manufacturing': '🏭',
  'Mining & Raw Materials': '⛏️',
  'Financial Services': '💰',
  'Trade & Logistics': '🚢',
};
