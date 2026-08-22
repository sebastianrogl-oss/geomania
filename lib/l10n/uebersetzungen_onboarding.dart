/// Englische Fassungen für die Modus-Anleitungen und die Erklärungen zu
/// Sternen und Serie.
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
};
