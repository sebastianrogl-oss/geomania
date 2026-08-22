// Übersetzungen für station_quiz_screen.dart (UI-Chrome: Buttons, Feedback,
// Snackbars, hartkodierte Fragetexte bei Bild-basierten Modi) UND die
// dynamisch in station_session_service.dart erzeugten Fragetexte.
//
// Letztere waren früher ausgeklammert ("eigene, spätere Lokalisierungsrunde
// für die Datenebene") — diese Runde hat sie nachgezogen, siehe den Block
// "Fragetexte aus der Datenebene" weiter unten.
const Map<String, String> uebersetzungenStationQuiz = {
  '🔄 Wiederholungsrunde': '🔄 Review round',
  '🎉 Abschnitt vollständig abgeschlossen!': '🎉 Section fully completed!',
  '🎉 Perfekt! Abschnitt abgeschlossen!': '🎉 Perfect! Section completed!',
  '🔄 Weiter zur Wiederholungsrunde!': '🔄 On to the review round!',

  'Welchem Land gehört diese Flagge?': 'Which country does this flag belong to?',
  'Auf dem Landweg von {von} nach {nach}: durch welches dieser Länder MUSST du dabei NICHT fahren?':
      'Traveling by land from {von} to {nach}: which of these countries do you NOT have to pass through?',
  'Welchem Land gehört dieser Umriss?': 'Which country does this outline belong to?',
  'Welcher Umriss gehört zu {emoji} {name}?': 'Which outline belongs to {emoji} {name}?',
  'Kein Umriss verfügbar': 'No outline available',

  'Die richtige Route:': 'The correct route:',
  'Land eingeben…': 'Enter country…',
  'Hauptstadt eingeben…': 'Enter capital…',

  '✅ Richtig!': '✅ Correct!',
  '❌ Richtig war: {a}': '❌ Correct answer: {a}',
  'Bestätigen': 'Confirm',
  'Reihenfolge prüfen': 'Check order',
  'Weiter': 'Next',
  'Überspringen': 'Skip',
  // Fester Begriff, im Deutschen wie im Englischen. Das große L bleibt nur
  // auf der deutschen Seite — dort ist "Level" ein Substantiv. Im Englischen
  // gilt wie überall sonst in der App Satz-Schreibung.
  'Skip Level': 'Skip level',

  '↑ Größtes oben  |  Kleinstes unten ↓': '↑ Largest on top  |  Smallest at bottom ↓',
  'Richtig (nach {kategorie}, größte zuerst):': 'Correct (by {kategorie}, largest first):',
  'Richtige Reihenfolge:': 'Correct order:',
  '✅ Perfekte Reihenfolge!': '✅ Perfect order!',
  '{a} von {b} richtig sortiert': '{a} of {b} sorted correctly',

  'Schätzung bestätigen': 'Confirm estimate',
  'Deine Schätzung: {v}': 'Your estimate: {v}',
  '✅ Richtig! (±20%)': '✅ Correct! (±20%)',
  '❌ Daneben': '❌ Off target',
  'Tatsächlicher Wert: {v}': 'Actual value: {v}',
  'Du lagst {p}% zu {richtung}': 'You were {p}% too {richtung}',
  'hoch': 'high',
  'niedrig': 'low',

  // ── Fragetexte aus der Datenebene ─────────────────────────────────────────
  // Erzeugt in station_session_service.dart. Platzhalter bewusst identisch
  // benannt wie im Deutschen — t() ersetzt sie nach der Übersetzung.
  'Was ist die Hauptstadt von {land}?': 'What is the capital of {land}?',
  'Welche Flagge gehört zu {land}?': 'Which flag belongs to {land}?',
  'Wie groß ist die Fläche von {land}?': 'What is the area of {land}?',
  'Wie hoch ist das BIP (Bruttoinlandsprodukt) von {land}?':
      'What is the GDP (gross domestic product) of {land}?',
  'Welches Land nutzt {w}?': 'Which country uses the {w}?',
  'Welches Land grenzt an {land}?': 'Which country borders {land}?',
  'Schätze: {k} von {land}': 'Estimate: {k} of {land}',
  'Sortiere nach: {k} (größte zuerst)': 'Sort by: {k} (largest first)',
  '(Platz {n})': '(rank {n})',

  // ── Superlativ-Quiz (_extremFrageText) ────────────────────────────────────
  // Sinngemäß statt wörtlich: "die meisten Einwohner" wird zu "the largest
  // population", nicht zu "the most inhabitants".
  'Welches dieser Länder hat die wenigsten Einwohner?':
      'Which of these countries has the smallest population?',
  'Welches dieser Länder hat die meisten Einwohner?':
      'Which of these countries has the largest population?',
  'Welches dieser Länder ist am kleinsten (Fläche)?':
      'Which of these countries is the smallest by area?',
  'Welches dieser Länder ist am größten (Fläche)?':
      'Which of these countries is the largest by area?',
  'Welches dieser Länder hat die kleinste Wirtschaft (BIP)?':
      'Which of these countries has the smallest economy (GDP)?',
  'Welches dieser Länder hat die größte Wirtschaft (BIP)?':
      'Which of these countries has the largest economy (GDP)?',
  'Welches dieser Länder hat das niedrigste BIP pro Kopf?':
      'Which of these countries has the lowest GDP per capita?',
  'Welches dieser Länder hat das höchste BIP pro Kopf?':
      'Which of these countries has the highest GDP per capita?',
  'Welches dieser Länder hat die niedrigste Lebenserwartung?':
      'Which of these countries has the lowest life expectancy?',
  'Welches dieser Länder hat die höchste Lebenserwartung?':
      'Which of these countries has the highest life expectancy?',
  'Welches dieser Länder hat die kürzeste Küste?':
      'Which of these countries has the shortest coastline?',
  'Welches dieser Länder hat die längste Küste?':
      'Which of these countries has the longest coastline?',
  'Welches dieser Länder hat den niedrigsten Mindestlohn?':
      'Which of these countries has the lowest minimum wage?',
  'Welches dieser Länder hat den höchsten Mindestlohn?':
      'Which of these countries has the highest minimum wage?',
};
