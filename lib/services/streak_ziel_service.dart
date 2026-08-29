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
/// ── Was hier (noch) NICHT passiert ────────────────────────────────────────
///
/// Vorerst wird das Ziel nur gespeichert. Ob es später die Erinnerungen
/// beeinflusst oder eine reine Zielmarke im Profil bleibt, ist offen — bis
/// dahin liest niemand ausser dem Screen selbst diesen Wert.
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

  /// Nach so vielen abgeschlossenen Stationen erscheint der Screen zum ersten
  /// Mal.
  static const int kStationenBisFrage = 2;

  /// Und nach so vielen, wenn beim ersten Mal "Später" gewählt wurde.
  static const int kStationenBisZweiteFrage = 6;

  /// Die vier Ziele zur Auswahl, in dieser Reihenfolge.
  static const List<int> zielTage = [7, 14, 30, 60];

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
  }
}
