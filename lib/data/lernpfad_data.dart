import 'countries.dart';
import '../l10n/uebersetzungen.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum LernModus {
  flaggenQuizBild,      // Flagge sehen → Land wählen (MC)
  flaggenQuizMultiple,  // Land sehen → richtige Flagge wählen
  hauptstaedteMultiple, // Hauptstadt Multiple Choice
  hauptstaedteEingabe,  // Hauptstadt Texteingabe
  umrissBild,           // Umriss sehen → Land wählen
  umrissMultiple,       // Land sehen → Umriss wählen
  flaggenQuizEingabe,   // Flagge sehen → Ländername eintippen
  umrissEingabe,        // Umriss sehen → Ländername eintippen
  waehrungsQuiz,
  sortierSpiel,
  preisSchaetzen,
  wirtschaftssektoren,
  nachbarland,          // "Welches Land grenzt an X?"
  bipGesamt,            // "Wie hoch ist das BIP von X?"
  flaeche,              // "Wie groß ist die Fläche von X?"
  extremFrage,          // Superlativ: größte/kleinste/bevölkerungsreichste
  waehrungZuLand,       // "Welches Land nutzt Währung X?" (umgekehrtes Währungsquiz)
  extremFrageLeicht,    // Superlativ, aber nur unter sehr bekannten Ländern
  zufallsFakt,          // Rätsel-artiger Fun-Fact → gesuchtes Land erraten
  bekanntesGebaeude,    // "In welchem Land steht [Bauwerk]?"
  grenzkettenRaetsel,   // "Durch welches Land MUSST du NICHT fahren?"
  // ── Noch nicht im Lernpfad ────────────────────────────────────────────────
  // Die folgenden Modi sind fertig gebaut, stehen aber bewusst in KEINER der
  // Modi-Listen der Level (_modiEinsteiger … _modiMeister). Sie werden
  // ausschliesslich ueber den Debug-Bereich der Einstellungen geoeffnet und
  // koennen dadurch keine echte Station belegen.
  flaechenVergleich,    // "Wie oft passt X in Y?" — zwei Umrisse massstabsgetreu
  zweiWahrheiten,       // "Welche Aussage stimmt NICHT?" — 2 wahre, 1 erfundene
  wasGehoertNichtDazu,  // Vier Laender, drei teilen ein Merkmal — welches nicht?
  laenderRanking,       // "Welchen Platz belegt X?" — Eingabe per Zahlenschloss
  nachbarschaftsKette,  // Weg von A nach B ueber Nachbarlaender selbst bauen
}

/// Modi, deren falsch beantwortete Fragen NICHT in die Wiederholungsrunde
/// wandern.
///
/// Es sind Unterhaltungsmodi, keine reinen Lernabfragen: die Fragen entstehen
/// aus zufälligen Länderkombinationen. Wer dieselbe Kombination oder dieselbe
/// erfundene Aussage ein zweites Mal vorgelegt bekommt, erinnert die Antwort,
/// statt etwas dazuzulernen.
///
/// Steht bewusst hier beim Enum und nicht in einem der Services: sowohl der
/// Sitzungs-Service (beim Merken) als auch der Fortschritts-Service (beim
/// Einsammeln) greifen darauf zu, und beide importieren diese Datei ohnehin.
/// Weitere Modi lassen sich hier eintragen, ohne andere Stellen anzufassen.
const Set<LernModus> kOhneWiederholung = {
  LernModus.flaechenVergleich,
  LernModus.zweiWahrheiten,
  LernModus.wasGehoertNichtDazu,
  LernModus.laenderRanking,
  LernModus.nachbarschaftsKette,
};

// ── Klassen ───────────────────────────────────────────────────────────────────

class LernStation {
  final String id;
  final LernModus modus;
  final int fragenAnzahl;        // 8 Quiz / 3 Sortieren
  final List<String> laenderCodes;
  final List<String> kategorien;
  final int schwierigkeitsgrad;  // 1-4

  const LernStation({
    required this.id,
    required this.modus,
    required this.fragenAnzahl,
    required this.laenderCodes,
    required this.kategorien,
    required this.schwierigkeitsgrad,
  });
}

class LernAbschnitt {
  final String id;
  final int stufe;
  final String titel;
  final String untertitel;
  final List<LernStation> stationen;
  final bool hatTimer;           // true bei stufe 4
  final int maxWiederholungen;

  const LernAbschnitt({
    required this.id,
    required this.stufe,
    required this.titel,
    required this.untertitel,
    required this.stationen,
    this.hatTimer = false,
    this.maxWiederholungen = 20,
  });
}

class LernWelt {
  final String id;
  final String name;
  final String emoji;
  final String kontinent;
  final int totalLaender;
  final List<String> laenderCodes;
  final List<LernAbschnitt> abschnitte;
  final int reihenfolge;
  final bool hatTimer;

  const LernWelt({
    required this.id,
    required this.name,
    required this.emoji,
    required this.kontinent,
    required this.totalLaender,
    required this.laenderCodes,
    required this.abschnitte,
    required this.reihenfolge,
    this.hatTimer = true,
  });
}

// ── Modus-Verteilung ────────────────────────────────────────────────────────
//
// Pro Abschnittslevel (1=Einsteiger … 4=Meister) ein Pool erlaubter Modi.
// Jedes Thema mit zwei Varianten (Flaggen, Umriss, Hauptstädte, Währung)
// wird schrittweise komplettiert: die leichtere Variante ist von Anfang an
// dabei, die zweite kommt in einem späteren Level dazu. Level 4 enthält
// den vollständigen Modus-Satz.
//
// Die 3 Eingabe-Varianten (flaggenQuizEingabe, umrissEingabe,
// hauptstaedteEingabe) sind grundsätzlich schon ab Level 1 (Einsteiger)
// verfügbar — die INNERHALB EINES ABSCHNITTS geltende Reihenfolge-Regel
// (_eingabeVorbedingung/_eingabeErlaubt, siehe unten) sorgt weiterhin
// dafür, dass sie erst gezogen werden, nachdem die leichtere Variante
// desselben Themas in genau diesem Abschnitt schon vorkam.

/// Modi mit eigener Mechanik oder Denkaufgabe. Alles Uebrige gilt als
/// ABFRAGE-Modus (Frage zeigen, Antwort waehlen).
///
/// Zentrale Zuordnung: von hier haengen die Gewichtung im Round-Robin und die
/// Obergrenze fuer Abfrage-Ketten ab. Ein neuer Modus muss nur hier
/// einsortiert werden.
const Set<LernModus> kSpielModi = {
  LernModus.sortierSpiel,
  LernModus.preisSchaetzen,
  LernModus.grenzkettenRaetsel,
  LernModus.zweiWahrheiten,
  LernModus.laenderRanking,
  LernModus.nachbarschaftsKette,
  LernModus.flaechenVergleich,
  LernModus.wasGehoertNichtDazu,
};

bool istSpielModus(LernModus m) => kSpielModi.contains(m);

/// Modi, die nicht als ERSTE Station einer Lernwelt taugen.
///
/// Nicht "Spiel-Modus" ist das Kriterium, sondern eine eigene Bedienung:
/// Sortieren zieht Karten in eine Reihenfolge, Preis-Schaetzen und
/// Laender-Ranking brauchen Regler beziehungsweise Zahlenschloss, die
/// Nachbarschafts-Kette baut einen Weg Schritt fuer Schritt. Wer eine Welt
/// betritt, soll zuerst etwas antippen duerfen.
///
/// Zwei Wahrheiten, Was gehoert nicht dazu, Flaechen-Vergleich und das
/// Grenzketten-Raetsel stehen bewusst NICHT hier: sie sind zwar Spiel-Modi,
/// bedient werden sie aber wie jedes Quiz — durch Antippen einer Karte.
const Set<LernModus> kNichtAlsWelteinstieg = {
  LernModus.sortierSpiel,
  LernModus.preisSchaetzen,
  LernModus.laenderRanking,
  LernModus.nachbarschaftsKette,
};

// Nicht mehr in den Pools, die Generatoren bleiben aber erhalten:
// bipGesamt, flaeche, extremFrageLeicht (vorher Einsteiger),
// bekanntesGebaeude (Fortgeschritten) und extremFrage (Profi). Sie liessen
// sich jederzeit wieder eintragen — extremFrage bleibt ausserdem als
// Funktion in Gebrauch, siehe die Fallback-Kette im Fragen-Generator.
//
// Die Reihenfolge der Listen ist NICHT beliebig: erzeugeModusSequenz waehlt
// bei Gleichstand der Zaehler den ersten passenden Eintrag, und zu Beginn
// eines Abschnitts stehen alle Zaehler auf 0. Standen die Abfrage-Modi wie
// frueher geblockt am Anfang, begann JEDER Abschnitt JEDER Welt mit
// derselben Zehnerfolge aus reiner Abfrage. Spiel-Modi sind deshalb
// eingestreut — etwa jede dritte Position.
const List<LernModus> _modiEinsteiger = [
  LernModus.flaggenQuizBild,
  LernModus.zweiWahrheiten, // Spiel
  LernModus.hauptstaedteMultiple,
  LernModus.umrissBild,
  LernModus.laenderRanking, // Spiel
  LernModus.waehrungsQuiz,
  LernModus.flaggenQuizMultiple,
  LernModus.nachbarland,
  LernModus.umrissMultiple,
  LernModus.hauptstaedteEingabe,
  LernModus.flaggenQuizEingabe,
  LernModus.umrissEingabe,
];

// Bewusst ausgeschrieben statt [..._modiEinsteiger, …]: die fuenf neuen
// Spiel-Modi und die zwei neuen Abfrage-Modi sollen zwischen den vorhandenen
// stehen, nicht hinter ihnen.
const List<LernModus> _modiFortgeschritten = [
  LernModus.flaggenQuizBild,
  LernModus.zweiWahrheiten, // Spiel
  LernModus.hauptstaedteMultiple,
  LernModus.umrissBild,
  LernModus.laenderRanking, // Spiel
  LernModus.waehrungsQuiz,
  LernModus.flaggenQuizMultiple,
  LernModus.sortierSpiel, // Spiel
  LernModus.nachbarland,
  LernModus.umrissMultiple,
  LernModus.grenzkettenRaetsel, // Spiel
  LernModus.hauptstaedteEingabe,
  LernModus.waehrungZuLand,
  LernModus.nachbarschaftsKette, // Spiel
  LernModus.flaggenQuizEingabe,
  LernModus.zufallsFakt,
  LernModus.flaechenVergleich, // Spiel
  LernModus.umrissEingabe,
  LernModus.wasGehoertNichtDazu, // Spiel
];

const List<LernModus> _modiProfi = [
  ..._modiFortgeschritten,
  LernModus.preisSchaetzen, // Spiel
];

// Meister enthält den vollständigen Modus-Satz.
const List<LernModus> _modiMeister = [
  ..._modiProfi,
  LernModus.wirtschaftssektoren,
];

/// Modi, die in einer bestimmten Lernwelt NICHT gezogen werden duerfen.
///
/// Nicht jeder Modus traegt in jeder Welt: der Laenderpool einer Station ist
/// ein Block des Kontinents, und manche Modi brauchen mehr Vielfalt, als ein
/// solcher Block hergibt. Ohne Sperre wuerde der Generator dort auf einen
/// anderen Modus ausweichen — der Spieler bekaeme ein anderes Spiel als
/// angekuendigt.
///
/// Die Werte sind gemessen, nicht geschaetzt (je Welt ueber alle ihre
/// Stationen geprueft, ob 8 Fragen ohne Wiederholung und ohne Ausweichen
/// entstehen):
/// - nachbarschaftsKette braucht einen zusammenhaengenden Grenzgraphen im
///   Block. Karibikinseln haben keine Landgrenze, in Ozeanien hat genau ein
///   Land eine — dort scheitert der Modus auf JEDER Fragenzahl.
/// - flaechenVergleich braucht Laenderpaare mit Groessenverhaeltnis 2 bis
///   100. In Europa sind sich die Laender dafuer zu aehnlich, in den kleinen
///   Welten fehlen die Paare ganz.
/// - wasGehoertNichtDazu braucht Merkmale, die INNERHALB des Quartetts
///   trennen. In einem Kontinent-Block sind Kontinent und Halbkugel fuer
///   alle gleich, damit bleibt fast nie genau ein begruendbarer Aussenseiter
///   uebrig.
/// grenzkettenRaetsel steht zusaetzlich in Suedamerika und Ozeanien: dort gibt
/// es KEINE kuratierten Raetsel (laender_grenzketten.dart fuehrt nur Europa,
/// Afrika, Asien und Nordamerika), der Generator wiche also sofort auf das
/// Flaggen-Quiz aus. Vor der Pool-Umstellung fiel das nicht auf, weil die
/// groesseren Pools den Modus in diesen beiden Welten nie gezogen hatten.
const Map<String, Set<LernModus>> kModusSperrenProWelt = {
  'europa': {LernModus.flaechenVergleich, LernModus.wasGehoertNichtDazu},
  'suedamerika': {
    LernModus.flaechenVergleich,
    LernModus.wasGehoertNichtDazu,
    LernModus.grenzkettenRaetsel,
  },
  'nordamerika': {
    LernModus.nachbarschaftsKette,
    LernModus.flaechenVergleich,
    LernModus.wasGehoertNichtDazu,
  },
  'afrika': {LernModus.wasGehoertNichtDazu},
  'asien': {LernModus.flaechenVergleich, LernModus.wasGehoertNichtDazu},
  'ozeanien': {
    LernModus.nachbarschaftsKette,
    LernModus.flaechenVergleich,
    LernModus.wasGehoertNichtDazu,
    LernModus.grenzkettenRaetsel,
  },
  'welt': {},
};

/// Obergrenze der Fragenzahl je Modus, verrechnet mit der Weltvorgabe per
/// Minimum (siehe [_st]).
///
/// Bewusst eine Liste je MODUS und keine Modus-mal-Welt-Matrix: letztere
/// haette 21 x 7 Felder, von denen fast alle denselben Wert truegen, und
/// muesste bei jedem neuen Modus komplett durchgesehen werden.
/// nachbarschaftsKette steht bewusst NICHT hier: gemessen liegt ihre Grenze
/// bei 10, der Modus läuft aber nur in Welten mit höchstens 9 Fragen
/// (Europa 8, Asien 8, Welt 8, Afrika 9, Südamerika über die Ausnahme
/// unten). Ein Eintrag wäre wirkungslos. Bekäme eine Welt je mehr als 10
/// Fragen, müsste er nachgetragen werden — darüber wiederholen sich
/// Start-Ziel-Paare im selben Länderblock.
const Map<LernModus, int> kFragenObergrenze = {
  // Fuenf Laender sortieren dauert laenger als eine Frage beantworten.
  LernModus.sortierSpiel: 3,
  // Mehr Paare mit brauchbarem Groessenverhaeltnis gibt Afrika nicht her.
  LernModus.flaechenVergleich: 7,
};

/// Einzige Ausnahme von [kFragenObergrenze]: In Suedamerika liegen zwischen
/// zwei beliebigen Laendern hoechstens drei Grenzuebertritte, der Graph ist
/// zu dicht fuer mehr Aufgaben. Ein zweiter Eintrag dieser Art waere der
/// Punkt, an dem sich eine richtige Tabelle lohnt.
const int kKetteFragenSuedamerika = 4;

List<LernModus> modiFuerLevel(int level) => switch (level) {
      1 => _modiEinsteiger,
      2 => _modiFortgeschritten,
      3 => _modiProfi,
      _ => _modiMeister,
    };

/// Ordnet jedem Modus sein Thema zu — Modi mit demselben Thema sind zwei
/// Varianten derselben Fragestellung (Bild/Multiple, Multiple/Eingabe, …)
/// und dürfen nie direkt hintereinander vorkommen.
String lernModusThema(LernModus m) => switch (m) {
      LernModus.flaggenQuizBild ||
      LernModus.flaggenQuizMultiple ||
      LernModus.flaggenQuizEingabe =>
        'flaggen',
      LernModus.umrissBild ||
      LernModus.umrissMultiple ||
      LernModus.umrissEingabe =>
        'umriss',
      LernModus.hauptstaedteMultiple ||
      LernModus.hauptstaedteEingabe =>
        'hauptstaedte',
      LernModus.waehrungsQuiz || LernModus.waehrungZuLand => 'waehrung',
      LernModus.sortierSpiel => 'sortieren',
      LernModus.preisSchaetzen => 'preis',
      LernModus.wirtschaftssektoren => 'wirtschaft',
      LernModus.nachbarland => 'nachbarland',
      LernModus.bipGesamt => 'bip',
      LernModus.flaeche => 'flaeche',
      LernModus.extremFrage || LernModus.extremFrageLeicht => 'extrem',
      LernModus.zufallsFakt => 'fakt',
      LernModus.bekanntesGebaeude => 'gebaeude',
      LernModus.grenzkettenRaetsel => 'grenzketten',
      LernModus.flaechenVergleich => 'flaeche',
      LernModus.zweiWahrheiten => 'fakt',
      LernModus.wasGehoertNichtDazu => 'geografie',
      LernModus.laenderRanking => 'ranking',
      LernModus.nachbarschaftsKette => 'nachbarland',
    };

/// Bevorzugt bei Gleichstand die noch selten genutzte Variante eines Themas.
int _variantenPrioritaet(LernModus m, Map<LernModus, int> zaehler) =>
    zaehler[m] ?? 0;

/// Mindestanzahl an leichteren Varianten desselben Themas, die in diesem
/// Abschnitt schon vorgekommen sein müssen, bevor die Eingabe-Variante
/// selbst gezogen werden darf (aufsteigende Schwierigkeit: Bild/Multiple
/// zuerst, Eingabe erst danach — einheitlich mindestens einmal pro Thema).
int? _eingabeVorbedingung(LernModus m) => switch (m) {
      LernModus.hauptstaedteEingabe => 1,
      LernModus.flaggenQuizEingabe => 1,
      LernModus.umrissEingabe => 1,
      _ => null,
    };

/// Prüft, ob [m] (falls es eine Eingabe-Variante ist) in der bisherigen
/// Sequenz dieses Abschnitts schon genug leichtere Varianten desselben
/// Themas gesehen hat, um selbst gezogen werden zu dürfen.
bool _eingabeErlaubt(LernModus m, List<LernModus> bisher) {
  final vorbedingung = _eingabeVorbedingung(m);
  if (vorbedingung == null) return true;
  final thema = lernModusThema(m);
  final leichtereBisher =
      bisher.where((x) => x != m && lernModusThema(x) == thema).length;
  return leichtereBisher >= vorbedingung;
}

/// Erzeugt eine gut durchmischte Modus-Sequenz für einen Abschnitt:
/// nie derselbe Modus und nie dasselbe Thema zweimal direkt hintereinander,
/// Round-Robin über die verfügbaren Modi für eine gleichmäßige Verteilung.
/// Die allererste Station im gesamten Lernpfad ist immer flaggenQuizBild.
/// Hoechstzahl aufeinanderfolgender Abfrage-Stationen.
///
/// Vier Stationen sind etwa fuenf Minuten Spielzeit — danach soll etwas
/// anderes kommen. Ohne diese Grenze entstanden Ketten von bis zu zwanzig,
/// weil ein Abschnitt mit Abfrage endete und der naechste damit begann.
const int kMaxAbfrageKette = 4;

/// Gewicht im Round-Robin. Ein Spiel-Modus "verbraucht" pro Einsatz nur
/// halb so viel wie ein Abfrage-Modus und kommt dadurch frueher wieder an
/// die Reihe — ohne dass die Abfrage-Modi ihre Mehrheit verlieren.
double _gewicht(LernModus m) => istSpielModus(m) ? 0.5 : 1.0;

/// Zaehlt, wie oft [kMaxAbfrageKette] gelockert werden musste, weil kein
/// Spiel-Modus verfuegbar war. Nur fuer Messungen.
int lockerungenAbfrageKette = 0;

/// Startversatz in der Pool-Liste je Lernwelt.
///
/// Ohne ihn beginnt jede Welt mit derselben Abfolge: das Verfahren ist
/// deterministisch, und bei gleichem Pool und lauter Zaehlern auf 0
/// entscheidet allein die Listenreihenfolge. Europa und Afrika waren dadurch
/// Station fuer Station identisch.
///
/// Der Versatz ROTIERT die Liste, er mischt sie nicht. Die relativen
/// Abstaende zwischen den Spiel-Modi bleiben damit erhalten — die
/// Verschraenkung wirkt weiter, nur an anderer Stelle beginnend.
///
/// Feste Werte statt einer Ableitung aus dem Namen: so laesst sich jede Welt
/// einzeln nachjustieren, und ein umbenannter Weltschluessel aendert nicht
/// unbemerkt den ganzen Lernpfad.
const Map<String, int> kPoolVersatzProWelt = {
  'europa': 0,
  'suedamerika': 2,
  'nordamerika': 4,
  'afrika': 6,
  'asien': 8,
  'ozeanien': 10,
  'welt': 12,
};

List<LernModus> erzeugeModusSequenz(
  int stationsAnzahl,
  int abschnittLevel,
  bool istAllerErsterAbschnitt, {
  /// Lernwelt, fuer die die Sequenz gebaut wird — entscheidet ueber die
  /// Sperren aus [kModusSperrenProWelt]. Ohne Angabe gilt kein Ausschluss
  /// (genutzt von Tests und Debug-Werkzeugen).
  String? weltId,

  /// Wie viele Abfrage-Stationen unmittelbar VOR diesem Abschnitt lagen.
  /// Sorgt dafuer, dass die Vierer-Regel ueber Abschnittsgrenzen hinweg
  /// greift statt bei jedem Abschnitt neu zu zaehlen.
  int ketteVorher = 0,

  /// Nimmt die Laenge der Abfrage-Kette am ENDE dieses Abschnitts entgegen,
  /// damit der naechste Abschnitt dort weiterzaehlen kann.
  void Function(int)? ketteNachher,

  /// Ob dies der erste Abschnitt seiner Lernwelt ist. Dann darf die erste
  /// Station kein Modus mit eigener Bedienung sein — siehe
  /// [kNichtAlsWelteinstieg].
  bool istErsterAbschnittDerWelt = false,
}) {
  final gesperrt = weltId == null
      ? const <LernModus>{}
      : (kModusSperrenProWelt[weltId] ?? const <LernModus>{});
  final gefiltert =
      modiFuerLevel(abschnittLevel).where((m) => !gesperrt.contains(m)).toList();
  // Rotation um den Weltversatz — siehe kPoolVersatzProWelt.
  final versatz = weltId == null
      ? 0
      : (kPoolVersatzProWelt[weltId] ?? 0) % gefiltert.length;
  final pool = versatz == 0
      ? gefiltert
      : [...gefiltert.sublist(versatz), ...gefiltert.sublist(0, versatz)];
  final sequenz = <LernModus>[];
  LernModus? letzter;
  String? letztesThema;
  final zaehler = <LernModus, int>{};
  var kette = ketteVorher;

  for (int i = 0; i < stationsAnzahl; i++) {
    // Allererste Station im ganzen Pfad: immer flaggenQuizBild.
    if (istAllerErsterAbschnitt && i == 0) {
      sequenz.add(LernModus.flaggenQuizBild);
      letzter = LernModus.flaggenQuizBild;
      letztesThema = 'flaggen';
      zaehler[LernModus.flaggenQuizBild] = 1;
      kette = 1;
      continue;
    }

    // Kandidaten: nicht der letzte Modus UND nicht dasselbe Thema wie
    // zuletzt (damit z.B. nicht Flagge-Bild direkt auf Flagge-Multiple folgt)
    // UND (falls Eingabe-Variante) noch genug leichtere Varianten gesehen.
    var kandidaten = pool
        .where((m) =>
            m != letzter &&
            lernModusThema(m) != letztesThema &&
            _eingabeErlaubt(m, sequenz))
        .toList();

    // Falls dadurch leer (kleiner Pool): nur "nicht letzter Modus" erzwingen,
    // Eingabe-Gate bleibt aber bestehen.
    if (kandidaten.isEmpty) {
      kandidaten =
          pool.where((m) => m != letzter && _eingabeErlaubt(m, sequenz)).toList();
    }

    // Äußerster Rand-Fall (z.B. Pool besteht praktisch nur noch aus
    // gesperrten Eingabe-Varianten): Gate ignorieren, damit die Sequenz nie
    // leer bleibt.
    if (kandidaten.isEmpty) {
      kandidaten = pool.where((m) => m != letzter).toList();
    }
    if (kandidaten.isEmpty) kandidaten = pool;

    // Erste Station einer Welt: kein Modus mit eigener Bedienung. Ohne diese
    // Regel entschied der Weltversatz darueber, und in Asien stand das
    // Sortier-Spiel an Position 1 — der mechanisch anspruchsvollste Modus als
    // Allererstes. Steht vor der Vierer-Regel, weil beim ersten Zug ohnehin
    // noch keine Abfrage-Kette gelaufen sein kann.
    if (istErsterAbschnittDerWelt && i == 0) {
      final zugaenglich =
          kandidaten.where((m) => !kNichtAlsWelteinstieg.contains(m)).toList();
      if (zugaenglich.isNotEmpty) kandidaten = zugaenglich;
    }

    // Vierer-Regel: sind schon genug Abfrage-Stationen gelaufen, MUSS die
    // naechste ein Spiel sein. Greift NACH allen Sperren — ist unter den
    // erlaubten Kandidaten kein Spiel-Modus, wird die Regel gelockert statt
    // die Sequenz zu blockieren.
    if (kette >= kMaxAbfrageKette) {
      final spiele = kandidaten.where(istSpielModus).toList();
      if (spiele.isNotEmpty) {
        kandidaten = spiele;
      } else {
        lockerungenAbfrageKette++;
      }
    }

    // Unter den Kandidaten: den mit dem niedrigsten GEWICHTETEN Zähler
    // bevorzugen. Ein Spiel-Modus zaehlt pro Einsatz nur halb, steht nach
    // einem Einsatz also gleichauf mit einem Abfrage-Modus, der noch gar
    // nicht dran war.
    double last(LernModus m) => (zaehler[m] ?? 0) * _gewicht(m);
    kandidaten.sort((a, b) => last(a).compareTo(last(b)));

    // Bei Gleichstand: bevorzugt die noch nicht genutzte Variante eines
    // Themas (z.B. flaggenQuizMultiple, wenn flaggenQuizBild schon kam).
    final minLast = last(kandidaten.first);
    final beste = kandidaten.where((m) => last(m) == minLast).toList();
    beste.sort((a, b) => _variantenPrioritaet(a, zaehler)
        .compareTo(_variantenPrioritaet(b, zaehler)));

    final gewaehlt = beste.first;
    sequenz.add(gewaehlt);
    zaehler[gewaehlt] = (zaehler[gewaehlt] ?? 0) + 1;
    letzter = gewaehlt;
    letztesThema = lernModusThema(gewaehlt);
    kette = istSpielModus(gewaehlt) ? 0 : kette + 1;
  }
  ketteNachher?.call(kette);
  return sequenz;
}

// ── Länderlisten ──────────────────────────────────────────────────────────────
//
// Jeder Block-Kontinent (alles außer Welt) hat drei DISJUNKTE Länder-Blöcke
// (A/B/C, sortiert nach Land.schwierigkeit aus alle_laender.dart) für seine
// ersten Abschnitte — kein Land kommt in mehr als einem Block vor. Der
// jeweils LETZTE Abschnitt eines Kontinents ist der Wiederholungs-Abschnitt:
// er nutzt die volle "*All"-Liste (alle Blöcke gemischt, keine Grenzen mehr).
// Bei Südamerika/Ozeanien (nur 2 Blöcke, 3 Abschnitte) übernimmt Block B den
// zweiten und der volle Kontinent den dritten (Wiederholungs-)Abschnitt.

const _europaBlockA = [
  'DE', 'FR', 'IT', 'ES', 'PT', 'GB', 'SE', 'NO', 'PL', 'RU',
  'NL', 'BE', 'CH', 'AT', 'IE', 'DK',
];
const _europaBlockB = [
  'FI', 'IS', 'CZ', 'SK', 'HU', 'RO', 'BG', 'HR', 'GR', 'UA',
  'CY', 'LT', 'EE', 'LV', 'SI',
];
const _europaBlockC = [
  'LU', 'MC', 'AD', 'LI', 'SM', 'MT', 'VA', 'RS', 'BA', 'ME',
  'MK', 'AL', 'MD', 'BY', 'XK',
];
const _europaAll = [..._europaBlockA, ..._europaBlockB, ..._europaBlockC];

const _suedamBlockA = ['BR', 'AR', 'CL', 'CO', 'PE', 'VE'];
const _suedamBlockB = ['EC', 'BO', 'PY', 'UY', 'GY', 'SR'];
const _suedamAll = [..._suedamBlockA, ..._suedamBlockB];

const _nordamBlockA = ['US', 'CA', 'MX', 'CU', 'GT', 'PA', 'JM', 'DO'];
const _nordamBlockB = ['BZ', 'HN', 'SV', 'NI', 'CR', 'HT', 'TT', 'BB'];
const _nordamBlockC = ['LC', 'VC', 'GD', 'AG', 'DM', 'KN', 'BS'];
const _nordamAll = [..._nordamBlockA, ..._nordamBlockB, ..._nordamBlockC];

const _afrikaBlockA = [
  'NG', 'EG', 'ZA', 'MA', 'DZ', 'TN', 'LY', 'SD', 'ET', 'KE',
  'TZ', 'GH', 'CD', 'AO', 'MG', 'ZW', 'UG', 'RW',
];
const _afrikaBlockB = [
  'SS', 'CG', 'MZ', 'CM', 'CI', 'NE', 'ML', 'BF', 'SN', 'ZM',
  'BI', 'SO', 'ER', 'DJ', 'MW', 'BW', 'NA', 'LS',
];
const _afrikaBlockC = [
  'SZ', 'GA', 'GQ', 'CF', 'TD', 'MR', 'GM', 'GW', 'GN', 'SL',
  'LR', 'TG', 'BJ', 'CV', 'ST', 'KM', 'SC', 'MU',
];
const _afrikaAll = [..._afrikaBlockA, ..._afrikaBlockB, ..._afrikaBlockC];

const _asienBlockA = [
  'CN', 'JP', 'IN', 'SA', 'TR', 'ID', 'KR', 'TH', 'VN', 'PK',
  'BD', 'PH', 'MY', 'AE', 'IL', 'KZ',
];
const _asienBlockB = [
  'NP', 'IQ', 'IR', 'AF', 'MN', 'SG', 'MM', 'KH', 'LA', 'LK',
  'SY', 'JO', 'LB', 'KW', 'QA', 'BH',
];
const _asienBlockC = [
  'OM', 'YE', 'UZ', 'TM', 'AZ', 'GE', 'AM', 'TJ', 'KG', 'KP',
  'TW', 'BT', 'MV', 'BN', 'TL', 'PS',
];
const _asienAll = [..._asienBlockA, ..._asienBlockB, ..._asienBlockC];

const _ozeanienBlockA = ['AU', 'NZ', 'FJ', 'PG', 'WS', 'VU', 'SB'];
const _ozeanienBlockB = ['TO', 'KI', 'FM', 'PW', 'MH', 'NR', 'TV'];
const _ozeanienAll = [..._ozeanienBlockA, ..._ozeanienBlockB];

const _weltA1 = [
  'DE', 'FR', 'GB', 'IT', 'ES', 'US', 'CA', 'CN', 'JP', 'IN',
  'BR', 'AU', 'RU', 'ZA', 'MX', 'KR', 'ID', 'SA', 'AR', 'NG',
  'EG', 'TH', 'PL', 'NL', 'SE', 'CH', 'BE', 'AT', 'NO', 'DK',
  'FI', 'PT', 'GR', 'CZ', 'IR', 'VN', 'MA', 'IL', 'SG', 'CL',
  'CO', 'AE', 'PH', 'BD', 'PK', 'UA', 'RO', 'KE', 'NZ', 'ET',
];
const _weltA2 = [
  'DE', 'FR', 'GB', 'IT', 'ES', 'US', 'CA', 'CN', 'JP', 'IN',
  'BR', 'AU', 'RU', 'ZA', 'MX', 'KR', 'ID', 'SA', 'AR', 'NG',
  'EG', 'TH', 'PL', 'NL', 'SE', 'CH', 'BE', 'AT', 'NO', 'DK',
  'FI', 'PT', 'GR', 'CZ', 'IR', 'VN', 'MA', 'IL', 'SG', 'CL',
  'CO', 'AE', 'PH', 'BD', 'PK', 'UA', 'RO', 'KE', 'NZ', 'ET',
  'GH', 'TZ', 'DZ', 'TN', 'CM', 'AO', 'SD', 'ML', 'SN', 'IQ',
  'QA', 'KW', 'OM', 'MY', 'MM', 'KH', 'LK', 'NP', 'AF', 'UZ',
  'KZ', 'MN', 'BY', 'HU', 'CU', 'DO', 'PE', 'VE', 'EC', 'GT',
  'PA', 'CR', 'HN', 'BO', 'UY', 'PY', 'JM', 'HT', 'TT', 'IS',
  'IE', 'HR', 'SK', 'LT', 'LV', 'EE', 'SI', 'RS', 'LU', 'BG',
];

/// Alle Länder mit Datensatz — löst den '*'-Platzhalter für die
/// Welt-Abschnitte "Profi" und "Meister" auf (vorher unaufgelöst: die
/// Stationen dort erzeugten 0 Fragen und hingen im Ladespinner fest).
final _weltAlle = countries.map((c) => c.iso2).toList();

// ── Station-Hilfsfunktionen ───────────────────────────────────────────────────

LernStation _st(
  String wid, int a, int i, LernModus m, List<String> l, int fragenProStation, {
  List<String> k = const [],
}) {
  // Obergrenze des Modus gegen die Vorgabe der Welt — die kleinere gewinnt.
  // Eine Welt mit 6 Fragen bekommt also keine 10, nur weil der Modus sie
  // vertragen wuerde.
  final grenze = (m == LernModus.nachbarschaftsKette && wid == 'suedamerika')
      ? kKetteFragenSuedamerika
      : kFragenObergrenze[m];
  return LernStation(
    id: '${wid}_${a}_${i.toString().padLeft(2, '0')}',
    modus: m,
    fragenAnzahl: grenze == null
        ? fragenProStation
        : (grenze < fragenProStation ? grenze : fragenProStation),
    laenderCodes: l,
    kategorien: k,
    schwierigkeitsgrad: a,
  );
}

/// Baut die Stationsliste eines Abschnitts. [anzahl] wird bei Bedarf um 1-3
/// echte, spielbare Stationen aufgestockt, damit der Zickzack-Pfad exakt
/// mittig vor dem Checkpoint endet (siehe home_screen.dart _Pfad) — früher
/// wurde das mit rein dekorativen, nicht spielbaren Füll-Punkten gelöst,
/// jetzt bekommen auch diese Positionen einen vollen, funktionierenden
/// Modus aus derselben Verteilungslogik wie jede andere Station.
///
/// [modusPoolLevel] überschreibt den für die Modus-Verteilung genutzten
/// Level-Pool (unabhängig von [stufe], die weiterhin den
/// Schwierigkeitsgrad/das Label der Station bestimmt) — genutzt für "Welt",
/// wo von Anfang an der VOLLE Modus-Satz (inkl. aller Unterhaltungs-Modi)
/// zur Verfügung stehen soll, weil Welt keine Block-Vollrotation pro
/// Abschnitt braucht und dadurch mehr Raum für Abwechslung hat.
List<LernStation> _baueAbschnitt(
  String wid, int stufe, List<String> laender, int anzahl, {
  bool istAllerErsterAbschnitt = false,
  bool istErsterAbschnittDerWelt = false,
  int fragenProStation = 8,
  int? modusPoolLevel,
}) {
  final polster = anzahl == 0 ? 0 : ((1 - anzahl) % 4 + 4) % 4;
  final gesamt = anzahl + polster;
  final modi = erzeugeModusSequenz(
      gesamt, modusPoolLevel ?? stufe, istAllerErsterAbschnitt,
      weltId: wid,
      ketteVorher: _laufendeKette,
      ketteNachher: (k) => _laufendeKette = k,
      istErsterAbschnittDerWelt: istErsterAbschnittDerWelt);
  return [
    for (int i = 0; i < gesamt; i++)
      _st(wid, stufe, i + 1, modi[i], laender, fragenProStation),
  ];
}

// ── Alle Abschnitte, in EINEM Durchlauf ──────────────────────────────────────
//
// Bewusst eine Funktion statt 26 einzelner `final`: die Vierer-Regel muss
// ueber Abschnitts- UND Weltgrenzen hinweg greifen (genau dort entstanden die
// langen Ketten), dafuer braucht die Erzeugung einen laufenden Zaehler. Bei
// einzelnen top-level `final` haengt die Auswertungsreihenfolge davon ab, wer
// sie zuerst liest — der Lernpfad saehe je nach Zugriffsweg anders aus. Hier
// ist die Reihenfolge festgeschrieben und damit reproduzierbar.

/// Laufende Abfrage-Kette zwischen zwei Abschnitten. Nur waehrend des Aufbaus
/// in [_baueAlleAbschnitte] beschrieben.
int _laufendeKette = 0;

final Map<String, List<LernStation>> _abschnitte = _baueAlleAbschnitte();

Map<String, List<LernStation>> _baueAlleAbschnitte() {
  _laufendeKette = 0;
  lockerungenAbfrageKette = 0;
  final r = <String, List<LernStation>>{};

  final weltenGesehen = <String>{};
  void bau(String wid, int stufe, List<String> laender, int anzahl,
      {bool erster = false, int fragen = 8, int? poolLevel}) {
    // Der erste Aufruf je Welt ist deren Einstiegs-Abschnitt.
    final ersterDerWelt = weltenGesehen.add(wid);
    r['${wid}_$stufe'] = _baueAbschnitt(wid, stufe, laender, anzahl,
        istAllerErsterAbschnitt: erster,
        istErsterAbschnittDerWelt: ersterDerWelt,
        fragenProStation: fragen,
        modusPoolLevel: poolLevel);
  }

  bau('europa', 1, _europaBlockA, 21, erster: true);
  bau('europa', 2, _europaBlockB, 22);
  bau('europa', 3, _europaBlockC, 22);
  bau('europa', 4, _europaAll, 25);

  bau('suedamerika', 1, _suedamBlockA, 10, fragen: 6);
  bau('suedamerika', 2, _suedamBlockB, 12, fragen: 6);
  bau('suedamerika', 3, _suedamAll, 14, fragen: 6);

  bau('nordamerika', 1, _nordamBlockA, 12);
  bau('nordamerika', 2, _nordamBlockB, 14);
  bau('nordamerika', 3, _nordamBlockC, 18);
  bau('nordamerika', 4, _nordamAll, 20);

  bau('afrika', 1, _afrikaBlockA, 18, fragen: 9);
  bau('afrika', 2, _afrikaBlockB, 22, fragen: 9);
  bau('afrika', 3, _afrikaBlockC, 26, fragen: 9);
  bau('afrika', 4, _afrikaAll, 30, fragen: 9);

  bau('asien', 1, _asienBlockA, 20);
  bau('asien', 2, _asienBlockB, 20);
  bau('asien', 3, _asienBlockC, 24);
  bau('asien', 4, _asienAll, 28);

  bau('ozeanien', 1, _ozeanienBlockA, 10, fragen: 7);
  bau('ozeanien', 2, _ozeanienBlockB, 12, fragen: 7);
  bau('ozeanien', 3, _ozeanienAll, 14, fragen: 7);

  bau('welt', 1, _weltA1, 25, poolLevel: 4);
  bau('welt', 2, _weltA2, 30, poolLevel: 4);
  bau('welt', 3, _weltAlle, 35, poolLevel: 4);
  bau('welt', 4, _weltAlle, 40, poolLevel: 4);

  return r;
}

List<LernStation> _st4(String id) => _abschnitte[id]!;

// ── Hauptliste ────────────────────────────────────────────────────────────────

final List<LernWelt> lernwelten = [
  LernWelt(
    id: 'europa', name: 'Europa', emoji: '🇪🇺',
    kontinent: 'Europa', totalLaender: 46, laenderCodes: _europaAll,
    reihenfolge: 1,
    abschnitte: [
      LernAbschnitt(id: 'europa_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Die großen Länder Westeuropas', stationen: _st4('europa_1')),
      LernAbschnitt(id: 'europa_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Nord- und Osteuropa', stationen: _st4('europa_2')),
      LernAbschnitt(id: 'europa_3', stufe: 3, titel: 'Profi',
        untertitel: 'Kleinstaaten & der Balkan', stationen: _st4('europa_3')),
      LernAbschnitt(id: 'europa_4', stufe: 4, titel: 'Meister',
        untertitel: 'Europa-Experte werden', stationen: _st4('europa_4'),
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'suedamerika', name: 'Südamerika', emoji: '🌎',
    kontinent: 'Südamerika', totalLaender: 12, laenderCodes: _suedamAll,
    reihenfolge: 2,
    abschnitte: [
      LernAbschnitt(id: 'suedamerika_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Der Kontinent des Regenwalds', stationen: _st4('suedamerika_1')),
      LernAbschnitt(id: 'suedamerika_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Wirtschaft und Währungen', stationen: _st4('suedamerika_2')),
      LernAbschnitt(id: 'suedamerika_3', stufe: 3, titel: 'Profi',
        untertitel: 'Südamerika-Experte', stationen: _st4('suedamerika_3'),
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'nordamerika', name: 'Nordamerika', emoji: '🗽',
    kontinent: 'Nordamerika', totalLaender: 23, laenderCodes: _nordamAll,
    reihenfolge: 3,
    abschnitte: [
      LernAbschnitt(id: 'nordamerika_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'USA, Kanada & Mittelamerika', stationen: _st4('nordamerika_1')),
      LernAbschnitt(id: 'nordamerika_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Karibik & ganz Mittelamerika', stationen: _st4('nordamerika_2')),
      LernAbschnitt(id: 'nordamerika_3', stufe: 3, titel: 'Profi',
        untertitel: 'Die kleinen Karibikstaaten', stationen: _st4('nordamerika_3')),
      LernAbschnitt(id: 'nordamerika_4', stufe: 4, titel: 'Meister',
        untertitel: 'Nordamerika-Experte', stationen: _st4('nordamerika_4'),
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'afrika', name: 'Afrika', emoji: '🌍',
    kontinent: 'Afrika', totalLaender: 54, laenderCodes: _afrikaAll,
    reihenfolge: 4,
    abschnitte: [
      LernAbschnitt(id: 'afrika_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Die größten Länder Afrikas', stationen: _st4('afrika_1')),
      LernAbschnitt(id: 'afrika_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Zentral- und Ostafrika', stationen: _st4('afrika_2')),
      LernAbschnitt(id: 'afrika_3', stufe: 3, titel: 'Profi',
        untertitel: 'Westafrika & Inselstaaten', stationen: _st4('afrika_3')),
      LernAbschnitt(id: 'afrika_4', stufe: 4, titel: 'Meister',
        untertitel: 'Afrika-Experte werden', stationen: _st4('afrika_4'),
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'asien', name: 'Asien', emoji: '🌏',
    kontinent: 'Asien', totalLaender: 48, laenderCodes: _asienAll,
    reihenfolge: 5,
    abschnitte: [
      LernAbschnitt(id: 'asien_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Die Wirtschaftsmächte Asiens', stationen: _st4('asien_1')),
      LernAbschnitt(id: 'asien_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Naher Osten & Südostasien', stationen: _st4('asien_2')),
      LernAbschnitt(id: 'asien_3', stufe: 3, titel: 'Profi',
        untertitel: 'Zentralasien & der Kaukasus', stationen: _st4('asien_3')),
      LernAbschnitt(id: 'asien_4', stufe: 4, titel: 'Meister',
        untertitel: 'Asien-Experte werden', stationen: _st4('asien_4'),
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'ozeanien', name: 'Ozeanien', emoji: '🏝️',
    kontinent: 'Ozeanien', totalLaender: 14, laenderCodes: _ozeanienAll,
    reihenfolge: 6,
    abschnitte: [
      LernAbschnitt(id: 'ozeanien_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Australien & die Pazifikinseln', stationen: _st4('ozeanien_1')),
      LernAbschnitt(id: 'ozeanien_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: 'Die entlegenen Inselstaaten', stationen: _st4('ozeanien_2')),
      LernAbschnitt(id: 'ozeanien_3', stufe: 3, titel: 'Profi',
        untertitel: 'Ozeanien-Experte', stationen: _st4('ozeanien_3'),
        hatTimer: true),
    ],
  ),
  LernWelt(
    id: 'welt', name: 'Die Welt', emoji: '🌐',
    kontinent: 'Welt', totalLaender: 197, laenderCodes: const ['*'],
    reihenfolge: 7,
    abschnitte: [
      LernAbschnitt(id: 'welt_1', stufe: 1, titel: 'Einsteiger',
        untertitel: 'Die 50 bekanntesten Länder', stationen: _st4('welt_1')),
      LernAbschnitt(id: 'welt_2', stufe: 2, titel: 'Fortgeschritten',
        untertitel: '100 Länder weltweit', stationen: _st4('welt_2')),
      LernAbschnitt(id: 'welt_3', stufe: 3, titel: 'Profi',
        untertitel: 'Alle 195 Länder der Erde', stationen: _st4('welt_3')),
      LernAbschnitt(id: 'welt_4', stufe: 4, titel: 'Meister',
        untertitel: 'Weltmeister der Geographie', stationen: _st4('welt_4'),
        hatTimer: true),
    ],
  ),
];

// ── Hilfsfunktionen für UI ────────────────────────────────────────────────────

String lernModusLabel(LernModus m) => t(switch (m) {
  LernModus.flaggenQuizBild      => 'Flaggen-Quiz (Bild)',
  LernModus.flaggenQuizMultiple  => 'Flaggen-Quiz (Multiple)',
  LernModus.hauptstaedteMultiple => 'Hauptstädte (Multiple Choice)',
  LernModus.hauptstaedteEingabe  => 'Hauptstädte (Eingabe)',
  LernModus.umrissBild           => 'Umriss-Quiz (Bild)',
  LernModus.umrissMultiple       => 'Umriss-Quiz (Multiple)',
  LernModus.flaggenQuizEingabe   => 'Flaggen-Quiz (Eingabe)',
  LernModus.umrissEingabe        => 'Umriss-Quiz (Eingabe)',
  LernModus.waehrungsQuiz        => 'Währungs-Quiz',
  LernModus.sortierSpiel         => 'Sortier-Spiel',
  LernModus.preisSchaetzen       => 'Das große Schätzen',
  LernModus.wirtschaftssektoren  => 'Wirtschaftssektoren',
  LernModus.nachbarland          => 'Länder-Quiz (Nachbarn)',
  LernModus.bipGesamt            => 'BIP-Quiz (Gesamt)',
  LernModus.flaeche              => 'Flächen-Quiz (Größe)',
  LernModus.extremFrage          => 'Superlativ-Quiz (Extrem)',
  LernModus.waehrungZuLand       => 'Währungs-Quiz (Land)',
  LernModus.extremFrageLeicht    => 'Superlativ-Quiz (Leicht)',
  LernModus.zufallsFakt          => 'Wissens-Quiz (Fun-Fact)',
  LernModus.bekanntesGebaeude    => 'Wahrzeichen-Quiz',
  LernModus.grenzkettenRaetsel   => 'Grenzketten-Rätsel',
  LernModus.flaechenVergleich    => 'Flächen-Vergleich',
  LernModus.zweiWahrheiten       => 'Zwei Wahrheiten, eine Lüge',
  LernModus.wasGehoertNichtDazu  => 'Was gehört nicht dazu?',
  LernModus.laenderRanking       => 'Länder-Ranking',
  LernModus.nachbarschaftsKette  => 'Nachbarschafts-Kette',
});

/// Zeitlimit in Sekunden für [modus] in Abschnitt 4 (Meister) — 0 bedeutet
/// kein Timer. Nach Modus-Kategorie gestaffelt: schnelle Bild-/Multiple-
/// Erkennung bekommt am wenigsten Zeit, Eingabe-Modi (Tippen kostet Zeit) und
/// komplexe Multi-Schritt-Modi am meisten. preisSchaetzen/zufallsFakt/
/// bekanntesGebaeude sind bewusst ohne Timer (freies Nachdenken/Schätzen).
/// bipGesamt/flaeche/extremFrageLeicht fallen mangels eigener Kategorie auf
/// den Sicherheits-Fallback (kein Timer) zurück.
int timerSekundenFuerModus(LernModus modus) {
  const schnell = {
    LernModus.flaggenQuizBild,
    LernModus.flaggenQuizMultiple,
    LernModus.umrissBild,
    LernModus.umrissMultiple,
  };
  const mittel = {
    LernModus.hauptstaedteMultiple,
    LernModus.waehrungsQuiz,
    LernModus.nachbarland,
    LernModus.extremFrage,
  };
  const eingabe = {
    LernModus.flaggenQuizEingabe,
    LernModus.umrissEingabe,
    LernModus.hauptstaedteEingabe,
  };
  const komplex = {
    LernModus.sortierSpiel,
    LernModus.grenzkettenRaetsel,
    LernModus.wirtschaftssektoren,
  };

  if (schnell.contains(modus)) return 15;
  if (mittel.contains(modus)) return 20;
  if (eingabe.contains(modus)) return 30;
  if (komplex.contains(modus)) return 40;
  return 0; // Sicherheits-Fallback: unbekannter/nicht gelisteter Modus
  // bekommt keinen Timer statt zu crashen (preisSchaetzen, zufallsFakt,
  // bekanntesGebaeude, bipGesamt, flaeche, extremFrageLeicht).
}

String lernModusFragenLabel(LernStation s) =>
    s.modus == LernModus.sortierSpiel
        ? t('{n} Runden', {'n': '${s.fragenAnzahl}'})
        : t('{n} Fragen', {'n': '${s.fragenAnzahl}'});

LernStation? stationById(String id) {
  for (final w in lernwelten) {
    for (final a in w.abschnitte) {
      for (final s in a.stationen) {
        if (s.id == id) return s;
      }
    }
  }
  return null;
}

LernAbschnitt? abschnittById(String id) {
  for (final w in lernwelten) {
    for (final a in w.abschnitte) {
      if (a.id == id) return a;
    }
  }
  return null;
}

LernWelt? weltById(String id) {
  for (final w in lernwelten) {
    if (w.id == id) return w;
  }
  return null;
}

(LernWelt, LernAbschnitt, LernStation)? stationKontext(String stationId) {
  for (final w in lernwelten) {
    for (final a in w.abschnitte) {
      for (final s in a.stationen) {
        if (s.id == stationId) return (w, a, s);
      }
    }
  }
  return null;
}
