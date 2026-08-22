/// Englische Fassungen für Onboarding, Modus-Anleitungen und die Erklärungen
/// zu Sternen und Serie.
///
/// Die Anleitungen sind sinngemäß übersetzt, nicht wörtlich — sie sollen sich
/// wie Anweisungen lesen, nicht wie eine Übersetzung. "Zieh die Länder mit dem
/// Finger" wird "Drag the countries with your finger", nicht "Pull".
///
/// Bei den Kurzanleitungen beginnt jede Zeile im Deutschen mit der Tätigkeit
/// (Tippe, Zieh, Schieb, Schreib, Stell, Bau). Im Englischen bleibt das so:
/// Tap, Drag, Slide, Type, Set, Build.
const Map<String, String> uebersetzungenOnboarding = {
  // ── Kurzanleitungen im Start-Sheet ─────────────────────────────────────────
  'Tippe das Land an, zu dem die gezeigte Flagge gehört.':
      'Tap the country the flag belongs to.',
  'Tippe die Flagge an, die zum genannten Land gehört.':
      'Tap the flag that belongs to the country shown.',
  'Tippe die Hauptstadt des genannten Landes an.':
      'Tap the capital of the country shown.',
  'Schreib die Hauptstadt des genannten Landes.':
      'Type the capital of the country shown.',
  'Tippe das Land an, zu dem der gezeigte Umriss gehört.':
      'Tap the country the outline belongs to.',
  'Tippe den Umriss an, der zum genannten Land gehört.':
      'Tap the outline that belongs to the country shown.',
  'Schreib das Land, zu dem die gezeigte Flagge gehört.':
      'Type the country the flag belongs to.',
  'Schreib das Land, zu dem der gezeigte Umriss gehört.':
      'Type the country the outline belongs to.',
  'Tippe die Währung an, mit der im gezeigten Land bezahlt wird.':
      'Tap the currency used in the country shown.',
  'Zieh die Länder mit dem Finger in die richtige Reihenfolge.':
      'Drag the countries into the right order with your finger.',
  'Schieb den Regler auf den Wert, den du schätzt.':
      'Slide the control to the value you are guessing.',
  'Tippe den Wirtschaftssektor an, der im Land am stärksten ist.':
      'Tap the economic sector that is strongest in the country.',
  'Tippe das Land an, das an das genannte grenzt.':
      'Tap the country that borders the one shown.',
  'Tippe die Wirtschaftsleistung an, die zum Land passt.':
      'Tap the economic output that matches the country.',
  'Tippe die Fläche an, die zum Land passt.':
      'Tap the area that matches the country.',
  'Tippe das Land an, auf das der Superlativ zutrifft.':
      'Tap the country the superlative applies to.',
  'Tippe das Land an, in dem mit dieser Währung bezahlt wird.':
      'Tap the country where this currency is used.',
  'Tippe das Land an, über das der Fakt spricht.':
      'Tap the country the fact is about.',
  'Tippe das Land an, in dem das Bauwerk steht.':
      'Tap the country the landmark stands in.',
  'Tippe das Land an, durch das der Weg NICHT führen muss.':
      'Tap the country the route does NOT have to pass through.',
  'Tippe an, wie oft das kleinere Land in das größere passt.':
      'Tap how many times the smaller country fits into the larger one.',
  'Tippe die Karte mit der Aussage an, die NICHT stimmt.':
      'Tap the card with the statement that is NOT true.',
  'Tippe das Land an, das nicht zu den anderen drei passt.':
      'Tap the country that does not fit with the other three.',
  'Stell am Zahlenschloss ein, auf welchem Platz das Land liegt.':
      'Set the number lock to the rank the country holds.',
  'Bau einen Weg vom Start zum Ziel — Nachbarland für Nachbarland.':
      'Build a route from start to finish — one neighbouring country at a time.',

  // ── Anleitung: Sortier-Spiel ───────────────────────────────────────────────
  'Du siehst fünf Länder in zufälliger Reihenfolge und darüber die Kategorie, nach der sortiert wird — zum Beispiel Bevölkerung oder Fläche.':
      'You see five countries in random order, with the category they are '
          'sorted by above them — population or area, for example.',
  'Halte ein Land gedrückt und zieh es nach oben oder unten. Die anderen rücken dabei von selbst zur Seite. Das größte gehört nach oben, das kleinste nach unten.':
      'Press and hold a country, then drag it up or down. The others move out '
          'of the way by themselves. The largest goes on top, the smallest at '
          'the bottom.',
  'Wenn die Reihenfolge steht, tippe auf "Prüfen". Danach siehst du die richtige Reihenfolge mit den echten Werten.':
      'Once the order looks right, tap "Check". You then see the correct order '
          'along with the real values.',
  'Die Kategorie bleibt für die ganze Station dieselbe — du musst dich also nur einmal darauf einstellen.':
      'The category stays the same for the whole station, so you only need to '
          'get used to it once.',

  // ── Anleitung: Das große Schätzen ──────────────────────────────────────────
  'Du siehst ein Land und eine Kategorie, zum Beispiel "Fläche von Brasilien". Gesucht ist der echte Wert.':
      'You see a country and a category — "area of Brazil", for example. You '
          'are looking for the real value.',
  'Schieb den Regler mit dem Finger nach links oder rechts. Über dem Regler siehst du dabei laufend, welchen Wert du gerade eingestellt hast.':
      'Slide the control left or right with your finger. Above it you can see '
          'the value you have set at any moment.',
  'Tippe auf "Schätzung bestätigen", wenn du zufrieden bist. Danach erscheint der tatsächliche Wert und wie weit du danebenlagst.':
      'Tap "Confirm guess" when you are happy with it. The actual value then '
          'appears, along with how far off you were.',
  'Du musst nicht genau treffen: alles innerhalb von 20 Prozent gilt als richtig.':
      'You do not have to be exact: anything within 20 per cent counts as '
          'correct.',

  // ── Anleitung: Länder-Ranking ──────────────────────────────────────────────
  'Gefragt ist, auf welchem Platz ein Land in einer Kategorie liegt — zum Beispiel "Welchen Platz belegt Kenia in der Kategorie Fläche?". Platz 1 ist immer der höchste Wert.':
      'The question is what rank a country holds in a category — "what rank '
          'does Kenya hold for area?", for example. Rank 1 is always the '
          'highest value.',
  'Die Zahl stellst du an einem Zahlenschloss ein: wisch die Walzen nach oben oder unten, bis deine Zahl in der Mitte steht. Die linke Walze ist die Zehnerstelle, die rechte die Einerstelle.':
      'You set the number on a number lock: swipe the wheels up or down until '
          'your number sits in the middle. The left wheel is the tens digit, '
          'the right one the units.',
  'Tippe auf "Bestätigen", wenn die Zahl stimmt. Wie viele Länder überhaupt gewertet werden, steht über dem Schloss.':
      'Tap "Confirm" once the number is right. How many countries are ranked '
          'at all is shown above the lock.',
  'Du musst nicht genau treffen: je näher du am richtigen Platz liegst, desto mehr Punkte gibt es.':
      'You do not have to be exact: the closer you are to the right rank, the '
          'more points you get.',

  // ── Anleitung: Nachbarschafts-Kette ────────────────────────────────────────
  'Du bekommst ein Startland und ein Zielland. Beide liegen auf demselben Kontinent, aber nicht nebeneinander.':
      'You are given a starting country and a destination. Both are on the '
          'same continent, but not next to each other.',
  'Unter der Karte stehen die Nachbarländer deines aktuellen Landes. Tippe eines an, um dorthin weiterzugehen — dein Weg wächst dadurch Schritt für Schritt.':
      'Below the map are the countries bordering the one you are on. Tap one '
          'to move there — your route grows step by step.',
  'Verläufst du dich, bringt dich "Schritt zurück" wieder eine Station zurück. Von manchen Ländern geht es nicht weiter, dann musst du diesen Weg ohnehin verlassen.':
      'If you take a wrong turn, "Step back" takes you back one country. From '
          'some countries there is no way on, and then you have to leave that '
          'route anyway.',
  'Sobald du am Ziel bist, ist die Frage vorbei. Je kürzer dein Weg, desto mehr Punkte — der kürzestmögliche gibt die volle Zahl.':
      'The question ends as soon as you reach the destination. The shorter '
          'your route, the more points — the shortest possible one scores '
          'full marks.',


  // ── Anleitung: Flaggen ─────────────────────────────────────────────────────
  'Du siehst eine Flagge. Darunter stehen vier Länder.':
      'You see a flag, with four countries below it.',
  'Tippe das Land an, zu dem die Flagge gehört. Deine Wahl färbt sich grün oder rot, und die richtige Antwort wird immer mit hervorgehoben.':
      'Tap the country the flag belongs to. Your choice turns green or red, '
          'and the correct answer is always highlighted as well.',
  'Diesmal andersherum: du siehst einen Ländernamen und vier Flaggen.':
      'The other way round this time: you see a country name and four flags.',
  'Tippe die Flagge an, die zu diesem Land gehört.':
      'Tap the flag that belongs to that country.',
  'Du siehst nur eine Flagge — ohne Auswahl. Der Ländername ist frei einzutippen.':
      'You see nothing but a flag — no options. The country name is yours to '
          'type.',
  'Schreib das Land ins Feld und tippe auf "Prüfen".':
      'Type the country into the field and tap "Check".',

  // ── Anleitung: Umrisse ─────────────────────────────────────────────────────
  'Du siehst den Umriss eines Landes, ohne Beschriftung und ohne Nachbarländer. Darunter stehen vier Namen zur Auswahl.':
      'You see the outline of a country, unlabelled and without its '
          'neighbours, with four names to choose from below it.',
  'Tippe den Namen an, der zu diesem Umriss gehört.':
      'Tap the name that belongs to that outline.',
  'Der Umriss ist immer gleich ausgerichtet, aber nicht immer gleich groß — auf die Form kommt es an, nicht auf die Größe.':
      'The outline always faces the same way, but is not always the same size '
          '— what matters is the shape, not how big it is.',
  'Diesmal andersherum: du siehst einen Ländernamen und vier Umrisse.':
      'The other way round this time: you see a country name and four '
          'outlines.',
  'Tippe den Umriss an, der zu diesem Land gehört.':
      'Tap the outline that belongs to that country.',
  'Du siehst nur einen Umriss — ohne Auswahl. Der Ländername ist frei einzutippen.':
      'You see nothing but an outline — no options. The country name is yours '
          'to type.',

  // ── Anleitung: Hauptstädte ─────────────────────────────────────────────────
  'Du siehst ein Land und vier Städte.': 'You see a country and four cities.',
  'Tippe die Stadt an, die seine Hauptstadt ist.':
      'Tap the city that is its capital.',
  'Die drei falschen Antworten sind echte Städte aus derselben Gegend — geraten hilft hier selten weiter.':
      'The three wrong answers are real cities from the same part of the '
          'world — guessing rarely gets you far here.',
  'Du siehst ein Land, aber keine Auswahl. Die Hauptstadt ist frei einzutippen.':
      'You see a country but no options. The capital is yours to type.',
  'Schreib die Stadt ins Feld und tippe auf "Prüfen".':
      'Type the city into the field and tap "Check".',

  // ── Anleitung: Eingabe-Hinweis (alle drei Eingabe-Modi) ────────────────────
  'Groß- und Kleinschreibung ist egal, und Umlaute darfst du umschreiben — "Suedafrika" gilt genauso wie "Südafrika". Gängige Zweitnamen wie "USA" oder "Holland" zählen ebenfalls.':
      'Capitals do not matter, and you may spell out accented letters — '
          '"Suedafrika" counts just as much as "Südafrika". Common alternative '
          'names such as "USA" or "Holland" are accepted too.',

  // ── Anleitung: Währungen ───────────────────────────────────────────────────
  'Du siehst ein Land und vier Währungen.':
      'You see a country and four currencies.',
  'Tippe die Währung an, mit der dort bezahlt wird.':
      'Tap the currency used there.',
  'Manche Währungen gelten in mehreren Ländern — der Euro etwa in zwanzig. Gesucht ist die des gezeigten Landes.':
      'Some currencies are used in several countries — the euro in twenty of '
          'them. The one you want is the currency of the country shown.',
  'Diesmal andersherum: du siehst eine Währung und vier Länder.':
      'The other way round this time: you see a currency and four countries.',

  // ── Anleitung: Länder und Nachbarn ─────────────────────────────────────────
  'Du siehst ein Land und vier weitere Länder zur Auswahl.':
      'You see a country, with four more to choose from.',
  'Tippe das Land an, das eine gemeinsame Grenze mit dem gezeigten hat.':
      'Tap the country that shares a border with the one shown.',
  'Gemeint ist immer eine LANDgrenze. Länder, die nur durch ein Meer getrennt sind, zählen nicht als Nachbarn.':
      'A LAND border is always what is meant. Countries separated only by sea '
          'do not count as neighbours.',
  'Du bekommst eine Reise von einem Land zu einem anderen, die ausschließlich über Land führt — und vier Länder zur Auswahl.':
      'You are given a journey from one country to another that goes entirely '
          'overland — and four countries to choose from.',
  'Tippe das Land an, durch das du dabei NICHT fahren musst. Die drei anderen liegen zwangsläufig auf dem Weg.':
      'Tap the country you do NOT have to travel through. The other three lie '
          'on the route by necessity.',
  'Achte auf das NICHT in der Frage: gesucht ist der Ausreißer, nicht eine Station der Reise.':
      'Watch for the NOT in the question: you are looking for the odd one '
          'out, not a stop along the way.',

  // ── Anleitung: Zahlen und Vergleiche ───────────────────────────────────────
  'Du siehst zwei Länder als Umrisse nebeneinander, maßstabsgetreu zueinander gezeichnet. Darunter stehen vier Zahlen.':
      'You see two countries side by side as outlines, drawn to scale with '
          'each other, with four numbers below them.',
  'Tippe die Zahl an, die angibt, wie oft das kleinere Land in das größere passt.':
      'Tap the number that says how many times the smaller country fits into '
          'the larger one.',
  'Es geht um die Fläche, nicht um die Form. Ein lang gezogenes Land kann kleiner sein, als es aussieht.':
      'This is about area, not shape. A long, drawn-out country can be '
          'smaller than it looks.',
  'Du siehst ein Land und vier Zahlen — gesucht ist seine jährliche Wirtschaftsleistung, das Bruttoinlandsprodukt.':
      'You see a country and four numbers — you are looking for its annual '
          'economic output, its gross domestic product.',
  'Tippe die Zahl an, die zum Land passt.':
      'Tap the number that matches the country.',
  'Gemeint ist die Leistung des GANZEN Landes, nicht die pro Kopf. Ein großes Land mit vielen Einwohnern liegt deshalb meist vorn.':
      'This is the output of the WHOLE country, not per person. A large '
          'country with many inhabitants therefore usually comes out ahead.',
  'Du siehst ein Land und vier Flächenangaben in Quadratkilometern.':
      'You see a country and four areas in square kilometres.',
  'Tippe die Angabe an, die zum Land passt.':
      'Tap the one that matches the country.',
  'Gesucht ist ein Rekordhalter: das größte, kleinste, höchste oder bevölkerungsreichste Land einer Gruppe.':
      'You are looking for a record holder: the largest, smallest, highest or '
          'most populous country of a group.',
  'Tippe das Land an, auf das die Beschreibung zutrifft.':
      'Tap the country the description applies to.',
  'Lies genau, in welche Richtung gefragt ist — zwischen "am meisten" und "am wenigsten" liegt die ganze Liste.':
      'Read carefully which way the question runs — the whole list lies '
          'between "most" and "least".',
  'Tippe das Land an, auf das die Beschreibung zutrifft. Zur Auswahl stehen hier nur sehr bekannte Länder.':
      'Tap the country the description applies to. Only very well-known '
          'countries appear here.',

  // ── Anleitung: Wissen ──────────────────────────────────────────────────────
  'Du siehst ein Land und vier Wirtschaftszweige — etwa Landwirtschaft, Industrie oder Tourismus.':
      'You see a country and four branches of industry — farming, '
          'manufacturing or tourism, for example.',
  'Tippe den Zweig an, der in diesem Land am stärksten ist.':
      'Tap the one that is strongest in that country.',
  'Du liest einen Fakt über ein Land, ohne dass sein Name fällt. Darunter stehen vier Länder.':
      'You read a fact about a country without its name being mentioned, with '
          'four countries below.',
  'Der Fakt nennt oft eine Besonderheit, die es nur einmal gibt — wer sie kennt, braucht nicht zu raten.':
      'The fact often names something that exists only once — if you know it, '
          'there is no need to guess.',
  'Du siehst ein bekanntes Bauwerk und vier Länder.':
      'You see a well-known landmark and four countries.',
  'Tippe das Land an, in dem es steht.': 'Tap the country it stands in.',
  'Du siehst drei Aussagen über ein Land. Zwei davon stimmen, eine ist erfunden.':
      'You see three statements about a country. Two of them are true, one is '
          'made up.',
  'Tippe die Karte mit der erfundenen Aussage an. Danach decken sich alle drei auf und zeigen, welche gelogen war.':
      'Tap the card with the made-up statement. All three then turn over and '
          'show which one was the lie.',
  'Die Lüge ist meist nah an der Wahrheit — eine leicht verschobene Zahl oder ein vertauschter Nachbar.':
      'The lie usually sits close to the truth — a number nudged slightly, or '
          'a neighbour swapped out.',
  'Du siehst vier Länder. Drei teilen genau ein Merkmal, das vierte nicht.':
      'You see four countries. Three share exactly one feature, the fourth '
          'does not.',
  'Tippe das Land an, das nicht dazugehört.':
      'Tap the country that does not belong.',
  'Welche Merkmale überhaupt in Frage kommen, zeigt der Knopf "Kategorien" neben dieser Anleitung.':
      'The "Categories" button next to these instructions shows which '
          'features are possible at all.',
  // ── Anleitungs-Knopf und Titel ─────────────────────────────────────────────
  'Anleitung': 'How to play',
  '{modus} — so geht es': '{modus} — how it works',

  // ── Sterne und Serie ───────────────────────────────────────────────────────
  'Alles klar': 'Got it',
  'Deine Sterne': 'Your stars',
  'Jede Frage, die du zum ersten Mal richtig beantwortest, gibt einen Stern. Dieselbe Frage noch einmal richtig zu beantworten gibt keinen weiteren — Sterne zeigen also, wie viel du schon kannst.':
      'Every question you answer correctly for the first time earns a star. '
          'Answering the same question correctly again earns nothing further, '
          'so your stars show how much you already know.',
  'Mit Sternen schaltest du im Profil neue Profilbilder frei. Sie werden dabei abgezogen, dein Gesamtstand oben bleibt aber stehen.':
      'You spend stars on new profile pictures in your profile. They are '
          'deducted when you do, but the total shown at the top stays as it '
          'is.',
  'Im ganzen Lernpfad sind {n} Sterne zu holen.':
      'There are {n} stars to collect across the whole learning path.',
  'Deine Serie': 'Your streak',
  'Die Flamme zählt die Tage, an denen du hintereinander gespielt hast. Eine einzige abgeschlossene Station am Tag genügt, um sie am Leben zu halten.':
      'The flame counts the days you have played in a row. A single completed '
          'station a day is enough to keep it alive.',
  'Setzt du einen Tag aus, fängt die Serie wieder bei 1 an. Verloren ist dabei nichts: Sterne, Abzeichen und dein Fortschritt im Lernpfad bleiben unberührt.':
      'Skip a day and the streak starts again at 1. Nothing is lost: your '
          'stars, badges and progress through the learning path are '
          'untouched.',
  'Für lange Serien gibt es ausserdem Abzeichen.':
      'Long streaks also earn you badges.',

  // ── Willkommens-Screen ─────────────────────────────────────────────────────
  'Schön, dass du da bist!': 'Good to have you here!',
  'Kurz, worum es geht:': 'Briefly, what this is about:',
  'Die Welt kennenlernen': 'Get to know the world',
  'Flaggen, Hauptstädte, Umrisse, Währungen und noch einiges mehr — immer spielerisch, nie als Vokabelliste.':
      'Flags, capitals, outlines, currencies and a good deal more — always as '
          'a game, never as a vocabulary list.',
  'Station für Station': 'One station at a time',
  'Der Lernpfad führt dich durch die Kontinente. Jede Station ist eine kurze Runde in einer anderen Spielart — die nächste wartet, sobald du fertig bist.':
      'The learning path takes you through the continents. Each station is a '
          'short round in a different kind of game — the next one is waiting '
          'as soon as you are done.',
  'Sterne sammeln': 'Collect stars',
  'Jede Frage, die du zum ersten Mal richtig hast, gibt einen Stern. Damit schaltest du später neue Profilbilder frei.':
      'Every question you get right for the first time earns a star. Later on '
          'you can spend them on new profile pictures.',
  'Serie halten': 'Keep your streak',
  'Spiel jeden Tag eine Station, dann wächst deine Serie. Tippe oben auf die Flamme oder den Stern, wenn du mehr wissen willst.':
      'Play one station a day and your streak grows. Tap the flame or the '
          'star at the top if you want to know more.',
  'Los geht\'s': 'Let\'s go',

  // ── Debug ──────────────────────────────────────────────────────────────────
  'Onboarding zurücksetzen (Debug)': 'Reset onboarding (debug)',
};
