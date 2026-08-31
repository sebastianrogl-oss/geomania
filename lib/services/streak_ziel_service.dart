import 'package:shared_preferences/shared_preferences.dart';

/// Stand der Ziel-Abfrage. Bewusst dieselbe Dreiteilung wie bei der
/// Erlaubnis-Abfrage ([ErlaubnisStand] in benachrichtigungs_service.dart) —
/// dasselbe Muster, dieselben Fallstricke schon einmal durchdacht.
enum ZielStand {
  /// Noch nie gefragt.
  offen,

  /// Der Spieler hat einmal "Später" gewählt — ein zweites Angebot folgt.
  spaeter,

  /// Endgültig abgeschlossen: Ziel gesetzt, oder zweimal vertagt.
  erledigt,
}

/// Das persönliche Streak-Ziel: Wie viele Tage in Folge sich der Spieler
/// vorgenommen hat.
///
/// ── Wo das Ziel sichtbar wird ─────────────────────────────────────────────
///
/// An genau zwei Stellen, und an keiner dritten:
///
///  1. In der Serien-Erklärung, die ein Tipp auf die Flamme öffnet — im
///     Lernpfad-Kopf wie in der Profil-Kachel. Dort steht das Ziel mit Balken
///     und Fortschritt (`3/14`).
///  2. Beim Erreichen — in der BESTEHENDEN Streak-Feier, die dafür einen
///     zweiten Teil bekommt. Bewusst kein eigenes Overlay: Zwei
///     Vollbild-Momente hintereinander nehmen sich gegenseitig das Gewicht.
///
/// NICHT in der Kachel selbst. Dort stand es kurzzeitig als eigene Zeile;
/// eine Kachel im Profil ist aber eine Kennzahl auf einen Blick, und ein
/// Balken mit "3/14" darunter macht daraus eine kleine Tabelle.
///
/// Reisst die Serie, passiert nichts. Wer sein Ziel verfehlt, braucht keine
/// Meldung darüber — er sieht es beim nächsten Blick in die Erklärung.
///
/// ── Warum ein eigener Zähler ──────────────────────────────────────────────
///
/// Der Screen kommt "nach der zweiten Station", und das heisst: nach dem
/// zweiten ABSCHLUSS, nicht bei der Station mit der Nummer 2. Wer Station 1
/// überspringt, mit einer Tages-Challenge anfängt oder die Reihenfolge im
/// Pfad anders läuft, kommt trotzdem hierher.
///
/// Der Zähler ist absichtlich NICHT der der Erlaubnis-Abfrage
/// ([BenachrichtigungsService.stationsZaehler]), obwohl beide dasselbe
/// zählen: Zwei Abfragen mit einem gemeinsamen Zustand hängen aneinander —
/// ein Zurücksetzen der einen verschöbe die andere. Getrennte Schlüssel
/// kosten ein paar Zeilen und halten beide unabhängig.
///
/// ── Warum die Schwellen 2 und 6 sind ──────────────────────────────────────
///
/// Die Erlaubnis-Abfrage liegt bei 1 und (nach einem "Später") bei 5. Läge
/// das Streak-Ziel ebenfalls bei 5, kämen nach derselben Station zwei
/// Vollbild-Abfragen hintereinander. Deshalb 6.
class StreakZielService {
  static const _kZiel = 'streak_ziel_tage';
  static const _kStand = 'streak_ziel_stand';
  static const _kStationsZaehler = 'streak_ziel_stationen';

  /// Das zuletzt GEFEIERTE Ziel, als Tageszahl.
  ///
  /// Ohne diesen Wert käme die Feier jeden Tag wieder: Wer sein 14-Tage-Ziel
  /// erreicht hat, hat es an Tag 15 immer noch erreicht. Gespeichert wird die
  /// Zahl und nicht bloss ein Häkchen, damit ein neu gesetztes, höheres Ziel
  /// wieder gefeiert werden kann.
  static const _kGefeiert = 'streak_ziel_gefeiert';

  /// Nach so vielen abgeschlossenen Stationen erscheint der Screen zum ersten
  /// Mal.
  static const int kStationenBisFrage = 2;

  /// Und nach so vielen, wenn beim ersten Mal "Später" gewählt wurde.
  static const int kStationenBisZweiteFrage = 6;

  /// Die vier Ziele zur Auswahl, in dieser Reihenfolge.
  static const List<int> zielTage = [7, 14, 30, 60];

  /// Die vollständige Leiter, einschliesslich der Sprossen oberhalb der
  /// Erstauswahl. Sie greift erst, wenn jemand ein Ziel erreicht hat und ein
  /// neues angeboten bekommt — beim ersten Mal wären 365 Tage keine Zielmarke,
  /// sondern eine Drohung.
  static const List<int> zielLeiter = [7, 14, 30, 60, 100, 180, 365];

  /// Die nächsten Sprossen über [erreicht] — höchstens drei, damit die
  /// Auswahl in der Feier nicht zur Liste wird.
  ///
  /// Am oberen Ende leer: Wer 365 Tage geschafft hat, bekommt die Feier ohne
  /// Anschlussfrage. Ein ausgedachtes Ziel darüber wäre nur noch eine Zahl.
  static List<int> naechsteZiele(int erreicht) =>
      zielLeiter.where((t) => t > erreicht).take(3).toList();

  /// Das dezent hervorgehobene Ziel — weit genug, um etwas zu heissen, nah
  /// genug, um erreichbar zu wirken.
  static const int empfohlen = 14;

  // ── Zustand ───────────────────────────────────────────────────────────────

  /// Das gewählte Ziel in Tagen, oder null, solange nichts gewählt wurde.
  static Future<int?> ziel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kZiel);
  }

  static Future<ZielStand> stand() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_kStand)) {
      'spaeter' => ZielStand.spaeter,
      'erledigt' => ZielStand.erledigt,
      _ => ZielStand.offen,
    };
  }

  static Future<void> _setzeStand(ZielStand neu) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStand, neu.name);
  }

  /// Der Spieler hat sich entschieden. Damit ist die Abfrage erledigt — das
  /// Ziel lässt sich danach nur noch bewusst ändern, nicht durch ein erneutes
  /// Auftauchen dieses Screens.
  static Future<void> setzeZiel(int tage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kZiel, tage);
    await _setzeStand(ZielStand.erledigt);
  }

  /// "Später entscheiden". Beim ersten Mal folgt ein zweites Angebot, beim
  /// zweiten Mal ist Schluss — gefragt wird höchstens zweimal.
  static Future<void> vertagt() async {
    await _setzeStand(await stand() == ZielStand.offen
        ? ZielStand.spaeter
        : ZielStand.erledigt);
  }

  // ── Ziel erreicht ─────────────────────────────────────────────────────────

  /// Ist mit [streak] gerade ein Ziel erreicht worden, das noch nicht gefeiert
  /// wurde? Liefert dann die Zieltage, sonst null.
  ///
  /// Der Vergleich ist `>=`, nicht `==`. Wer sein Ziel auf 7 gesetzt hat und
  /// zwischendurch mehrere Tage ohne die App war, kommt sonst nie in die
  /// Feier — die Serie springt beim Wiedereinstieg auf 1 und wächst an dem
  /// Tag, an dem sie 7 überschreitet, womöglich gar nicht auf exakt 7.
  static Future<int?> zielGeradeErreicht(int streak) async {
    final zielTage = await ziel();
    if (zielTage == null || streak < zielTage) return null;
    final gefeiert = await gefeiertesZiel();
    if (gefeiert != null && gefeiert >= zielTage) return null;
    return zielTage;
  }

  /// Das zuletzt gefeierte Ziel, oder null.
  static Future<int?> gefeiertesZiel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kGefeiert);
  }

  /// Merkt, dass [tage] gefeiert wurde.
  ///
  /// Wird gesetzt, BEVOR die Feier läuft, nicht danach. Bricht dazwischen
  /// etwas ab, fällt eine Feier aus — das ist deutlich weniger schlimm, als
  /// sie ab jetzt jeden Tag erneut zu bekommen.
  static Future<void> merkeZielGefeiert(int tage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kGefeiert, tage);
  }

  // ── Auslöser ──────────────────────────────────────────────────────────────

  static Future<int> stationsZaehler() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kStationsZaehler) ?? 0;
  }

  /// Nach JEDEM Stationsabschluss aufzurufen.
  static Future<void> stationAbgeschlossen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStationsZaehler, (await stationsZaehler()) + 1);
  }

  /// Soll der Screen jetzt erscheinen?
  ///
  /// Der Vergleich ist bewusst `>=` und nicht `==`: Wer die App genau nach
  /// dem zweiten Abschluss schliesst, soll den Screen beim nächsten Abschluss
  /// bekommen statt gar nicht.
  static Future<bool> sollScreenZeigen() async {
    final aktuell = await stand();
    if (aktuell == ZielStand.erledigt) return false;
    final zaehler = await stationsZaehler();
    return aktuell == ZielStand.offen
        ? zaehler >= kStationenBisFrage
        : zaehler >= kStationenBisZweiteFrage;
  }

  /// Für den Fortschritts-Reset und den Debug-Knopf.
  static Future<void> zuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kZiel);
    await prefs.remove(_kStand);
    await prefs.remove(_kStationsZaehler);
    await prefs.remove(_kGefeiert);
  }
}
