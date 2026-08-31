// Übersetzungen für home_screen.dart (der tatsächlich aktive Lernpfad-Screen
// — lernpfad_screen.dart ist unbenutzter Alt-Code, siehe dortiger Header)
// + lernpfad_data.dart (Modus-Labels).
const Map<String, String> uebersetzungenLernpfad = {
  'Lernpfad': 'Learning path',
  // Die Überschriften im Lernpfad-Kopf tragen nur noch den Weltnamen bzw.
  // die Abschnittsnummer — "Welt 1 — Europa" und "Abschnitt 1 — Einsteiger"
  // sind entfallen.
  'Abschnitt {n}': 'Section {n}',
  '15-Sekunden-Timer pro Frage': '15-second timer per question',
  'Fortsetzen ({a}/{b})': 'Resume ({a}/{b})',
  'Welten': 'Worlds',

  // Abschnitt gegen Werbung öffnen (Schloss im Abschnitts-Band).
  // Der englische Text muss dieselbe Klarheit haben wie der deutsche: nur die
  // erste Station, der Rest bleibt zu, nichts gilt als erledigt.
  'Abschnitt {n} öffnen?': 'Open section {n}?',
  'Sieh ein kurzes Video an, dann kannst du die ERSTE Station dieses Abschnitts sofort spielen.':
      'Watch a short video and you can play the FIRST station of this section '
          'right away.',
  'Alle weiteren Stationen bleiben gesperrt. Sie öffnen sich wie immer nacheinander, sobald du die vorherige geschafft hast.':
      'Every other station stays locked. They open one after another as usual, '
          'each once you have finished the one before it.',
  'Nichts davon zählt als erledigt: Es gibt keine Sterne, keine Abzeichen, und dein Fortschritt bleibt, wie er ist.':
      'None of this counts as completed: no stars, no badges, and your '
          'progress stays exactly as it is.',
  'Video ansehen': 'Watch video',
  'Alle Welten': 'All worlds',

  // Streak-Feier (widgets/streak_feier_overlay.dart) und Abzeichen-Popup
  // (widgets/abzeichen_popup.dart) — bewusst derselbe Text in beiden.
  'Tippen für weiter': 'Tap to continue',

  // Zweiter Teil der Streak-Feier: das erreichte Ziel und die Frage nach dem
  // nächsten. {tage} steht in beiden Sprachen für die Zahl.
  'Ziel erreicht!': 'Goal reached!',
  '{tage} Tage am Stück.': '{tage} days in a row.',
  'Neues Ziel?': 'A new goal?',
  '{tage} Tage': '{tage} days',
  'Kein neues Ziel': 'No new goal',

  // ── Neue Modi, vorerst nur ueber den Debug-Bereich erreichbar ───────────
  // Modusnamen (data/lernpfad_data.dart)
  'Flächen-Vergleich': 'Area comparison',
  'Zwei Wahrheiten, eine Lüge': 'Two truths, one lie',

  // Flächen-Vergleich (services/station_session_service.dart)
  'Wie oft passt {klein} in {gross}?':
      'How many times does {klein} fit into {gross}?',

  // Zwei Wahrheiten, eine Lüge — Fragetext und die vier Aussage-Vorlagen.
  // Die Platzhalter werden mit bereits lokalisierten Werten gefüllt
  // (Country.name/.capital, t(currencyName), SkalaService-Format).
  'Welche Aussage über {land} stimmt NICHT?':
      'Which statement about {land} is FALSE?',
  'Die Hauptstadt ist {stadt}.': 'The capital is {stadt}.',
  'Die Währung heißt {waehrung}.': 'The currency is called {waehrung}.',
  'Ein Nachbarland ist {nachbar}.': 'One neighbouring country is {nachbar}.',
  // Ohne Satzpunkt: die formatierte Zahl endet je nach Groessenordnung selbst
  // auf einen ("3.4M"), der Punkt kommt in _bevoelkerungsAussage dazu.
  'Die Bevölkerung liegt bei etwa {n}': 'The population is around {n}',

  // Begründungen der Lüge (Zwei Wahrheiten) — entstehen beim Erzeugen der
  // Lüge, wo echter und ausgetauschter Wert beide vorliegen.
  'Die Hauptstadt ist {richtig}, nicht {falsch}.':
      'The capital is {richtig}, not {falsch}.',
  'Die Währung ist {richtig}, nicht {falsch}.':
      'The currency is the {richtig}, not the {falsch}.',
  '{land} und {falsch} haben keine gemeinsame Grenze.':
      '{land} and {falsch} do not share a border.',
  'Die Bevölkerung liegt bei etwa {richtig}, nicht bei {falsch}':
      'The population is around {richtig}, not {falsch}',

  // Was gehört nicht dazu? (services/station_session_service.dart)
  'Was gehört nicht dazu?': 'Odd one out',
  'Welches Land passt nicht zu den anderen?':
      'Which country doesn\'t belong?',
  'Die anderen drei liegen alle in {wert}.':
      'The other three are all in {wert}.',
  'Die anderen drei bezahlen alle mit {wert}.':
      'The other three all pay with the {wert}.',
  'Die anderen drei sind alle EU-Mitglied.':
      'The other three are all EU members.',
  'Die anderen drei sind alle kein EU-Mitglied.':
      'None of the other three is an EU member.',
  'Die anderen drei sind alle Binnenstaaten ohne Meereszugang.':
      'The other three are all landlocked.',
  'Die anderen drei haben alle einen Meereszugang.':
      'The other three all have a coastline.',
  'Die anderen drei liegen alle auf der Nordhalbkugel.':
      'The other three are all in the northern hemisphere.',
  'Die anderen drei liegen alle auf der Südhalbkugel.':
      'The other three are all in the southern hemisphere.',
  'Die anderen drei leben hauptsächlich von: {wert}.':
      'The other three all live mainly from: {wert}.',
  'Die anderen drei grenzen alle an {land}.':
      'The other three all border {land}.',

  // Hilfe-Dialog: Kategorienamen kommen aus _Merkmal.label im Generator.
  'Kategorien': 'Categories',
  'Mögliche Gemeinsamkeiten': 'Possible connections',
  'Drei der vier Länder teilen genau eines dieser Merkmale.':
      'Three of the four countries share exactly one of these.',
  'Kontinent': 'Continent',
  'Währung': 'Currency',
  'EU-Mitgliedschaft': 'EU membership',
  'Binnenstaat oder Küste': 'Landlocked or coastal',
  'Nord- oder Südhalbkugel': 'Northern or southern hemisphere',
  'Wichtigster Wirtschaftssektor': 'Main economic sector',
  'Gemeinsame Grenze zu einem Land': 'A shared border with one country',
  'Schließen': 'Close',

  // Länder-Ranking mit Rang-Balken
  'Länder-Ranking': 'Country ranking',
  'Welchen Platz belegt {land} in der Kategorie {kategorie}?':
      'What rank does {land} hold for {kategorie}?',
  'Platz 1 = höchster Wert · {n} Länder gewertet':
      'Rank 1 = highest value · {n} countries ranked',
  'Platz {n}': 'Rank {n}',
  'Genau richtig!': 'Spot on!',
  '{n} Plätze daneben · {p} Punkte': 'Off by {n} ranks · {p} points',
  'Bestätigen': 'Confirm',

  // Nachbarschafts-Kette
  'Nachbarschafts-Kette': 'Border chain',
  'Finde einen Weg von {start} nach {ziel} — nur über Nachbarländer.':
      'Find a route from {start} to {ziel} — through neighbouring countries only.',
  'Dein Weg · {n} Schritte': 'Your route · {n} steps',
  'Nachbarn von {land}': 'Neighbours of {land}',
  'Schritt zurück': 'Undo step',
  'Von hier geht es nicht weiter — nimm einen Schritt zurück.':
      'Dead end — take a step back.',
  'Kürzester Weg!': 'Shortest route!',
  'Ziel erreicht · {p} Punkte': 'Destination reached · {p} points',
  'Der kürzeste Weg braucht {n} Schritte — du hast {m} gebraucht.':
      'The shortest route takes {n} steps — you took {m}.',
  'Der kürzeste Weg:': 'The shortest route:',

  // Debug-Auswahl (screens/settings_screen.dart)
  'Neue Modi testen (Debug)': 'Test new modes (debug)',
  'Welchen Modus testen?': 'Which mode do you want to test?',

  // Profilbild-Freischaltung mit Sternen (screens/profil_screen.dart)
  'Dieses Profilbild für {n} Sterne freischalten?':
      'Unlock this profile picture for {n} stars?',
  'Freischalten': 'Unlock',
  'Noch {n} Sterne nötig': '{n} more stars needed',
  'Verfügbare Sterne': 'Available stars',

  // Schluss-Ansicht nach einer Station (screens/station_abschluss_screen.dart)
  'Perfekt!': 'Perfect!',
  'Stark gemacht!': 'Well played!',
  'Gut gemacht!': 'Nice work!',
  'Weiter üben!': 'Keep practicing!',
  'Zeit': 'Time',
  'Richtige': 'Correct',
  'Sterne': 'Stars',
  'Du hast {n} Länderfakten gelernt': 'You\'ve learned {n} country facts',
  '{a} von {b} Ländern in {welt}': '{a} of {b} countries in {welt}',

  // ── Halbzeit-Sprüche (data/halbzeit_sprueche.dart) ──────────────────────
  // Sinngemäß übersetzt, nicht wörtlich — der freche Ton soll erhalten
  // bleiben.

  // Alle richtig
  'Keine einzige daneben. Respekt!': 'Not a single miss. Respect!',
  'Du machst das echt zu leicht.': 'You\'re making this look easy.',
  'Makellos. Weiter so!': 'Flawless. Keep it going!',
  'Fehlerfrei — beeindruckend!': 'Not one slip — impressive!',
  'Okay, du kannst das offensichtlich.': 'Okay, you clearly know your stuff.',
  'Perfekt bisher. Bleibt das so?': 'Perfect so far. Can you hold it?',
  'Nicht ein Fehler. Stark!': 'Zero mistakes. Nice one!',
  'Du bist auf einem Lauf!': 'You\'re on a roll!',

  // 75% oder mehr
  'Läuft richtig gut!': 'This is going great!',
  'Stark unterwegs!': 'Strong start!',
  'Das sieht gut aus!': 'Looking good!',
  'Gut in Fahrt — weiter so!': 'Nice momentum — keep it up!',
  'Fast alles richtig!': 'Almost all of them!',
  'Solide Halbzeit!': 'Solid first half!',
  'Da geht noch was, aber stark!': 'Room to grow, but strong!',
  'Bleib dran, das passt!': 'Stick with it, you\'ve got this!',

  // 50-74%
  'Halbzeit geschafft!': 'Halfway done!',
  'Auf gutem Weg!': 'On the right track!',
  'Solide bisher!': 'Solid so far!',
  'Geht doch!': 'There you go!',
  'Zweite Hälfte, jetzt zeigst du es!': 'Second half — now show them!',
  'Noch ist alles drin!': 'It\'s all still up for grabs!',
  'Gut dabei — weiter!': 'Doing fine — keep going!',
  'Läuft. Bleib dran!': 'It\'s working. Stay with it!',

  // Unter 50%
  'Zweite Hälfte, neue Chance!': 'Second half, fresh start!',
  'Nicht aufgeben — du packst das!': 'Don\'t give up — you\'ve got this!',
  'Jetzt erst recht!': 'Now more than ever!',
  'Aufwärmen ist vorbei!': 'Warm-up\'s over!',
  'Das wird noch!': 'It\'ll come together!',
  'Kopf hoch, weiter geht\'s!': 'Chin up, here we go!',
  'Die zweite Hälfte gehört dir!': 'The second half is yours!',
  'Dranbleiben lohnt sich!': 'Sticking with it pays off!',

  'Abschluss ✅': 'Finale ✅',
  'Abschluss': 'Finale',
  'Abschnitt ✅': 'Section ✅',
  'Checkpoint': 'Checkpoint',
  'Wiederholung starten': 'Start review',

  'Bereits abgeschlossen': 'Already completed',
  'Nochmal spielen': 'Play again',
  'START': 'START',
  // 'Abbrechen' ist bereits in uebersetzungen_settings.dart definiert.

  '{n} Runden': '{n} rounds',
  '{n} Fragen': '{n} questions',

  // ── Modus-Anzeigenamen (lernModusLabel) ───────────────────────────────────
  //
  // Ohne Klammerzusatz, wie im Deutschen: mehrere Modi teilen sich denselben
  // Namen, weil im Spiel immer nur einer davon zu sehen ist.
  //
  // Vier dieser Namen stehen bereits in anderen Teiltabellen und fehlen hier
  // absichtlich, damit jeder deutsche Schlüssel genau eine Fassung hat:
  // 'Flaggen-Quiz' (uebersetzungen_flagquiz), 'Umriss-Quiz'
  // (uebersetzungen_outlinequiz), 'BIP-Quiz' (uebersetzungen_gdpquiz),
  // 'Hauptstädte' (uebersetzungen_profil).
  'Währungs-Quiz': 'Currency quiz',
  'Sortier-Spiel': 'Sorting game',
  // 'Das große Schätzen' steht in uebersetzungen_schaetzen.dart, bei den
  // übrigen Texten dieses Spiels.
  'Wirtschaftssektoren': 'Economic sectors',
  'Nachbarländer': 'Neighbours',
  'Flächen-Quiz': 'Area quiz',
  'Superlativ-Quiz': 'Superlative quiz',
  'Wissens-Quiz': 'Knowledge quiz',
  'Wahrzeichen-Quiz': 'Landmark quiz',
  'Grenzketten-Rätsel': 'Border chain puzzle',
};
