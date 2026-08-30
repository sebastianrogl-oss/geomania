import '../l10n/uebersetzungen.dart';

/// Der Titel unter dem Namen im Profil — gekoppelt an die abgeschlossenen
/// Stationen des Lernpfads.
///
/// Vorher stand dort eine fest eingetippte Zeile: "Geo-Anfänger" für jeden
/// Spieler, bei jedem Fortschritt, für immer. Sie sah aus wie ein Rang, war
/// aber keiner.
///
/// GEKOPPELT AN STATIONEN, nicht an Sterne: Sterne zählen einzelne richtige
/// Antworten und wachsen deshalb auch, wenn jemand eine Station mehrfach
/// spielt. Abgeschlossene Stationen sind die Strecke, die tatsächlich hinter
/// einem liegt — und dieselbe Zahl steht in der Kachel daneben, der Titel ist
/// damit nachvollziehbar statt geraten.
///
/// KEIN AUFSTIEGS-MOMENT: Der Titel wechselt still, wenn die Schwelle fällt.
/// Keine Feier, kein Popup — genau wie beim Portfolio-Rang, dessen
/// Aufstiegs-Animation aus demselben Grund entfernt wurde. Der Moment gehört
/// dem Stationsabschluss, nicht einer zweiten Meldung darüber.
class SpielerTitel {
  /// Ab wie vielen abgeschlossenen Stationen der Titel gilt.
  final int schwelle;
  final String titel;

  const SpielerTitel({required this.schwelle, required this.titel});
}

/// Die Staffel, aufsteigend sortiert.
///
/// Rund alle hundert Stationen ein neuer Titel — bei 598 Stationen im ganzen
/// Pfad sind das sechs Stufen plus den Abschluss. Die letzte Schwelle liegt
/// bewusst NICHT bei 598, sondern bei 550: Die letzten Stationen der
/// Welt-Welt sind die zähesten, und ein Titel, den praktisch niemand je
/// sieht, ist keine Belohnung, sondern Deko.
const List<SpielerTitel> spielerTitel = [
  SpielerTitel(schwelle: 0, titel: 'Geo-Neuling 🌱'),
  SpielerTitel(schwelle: 100, titel: 'Geo-Anfänger 🌍'),
  SpielerTitel(schwelle: 200, titel: 'Kartenleser 🗺️'),
  SpielerTitel(schwelle: 300, titel: 'Weltenbummler 🧭'),
  SpielerTitel(schwelle: 400, titel: 'Länderkenner 🏔️'),
  SpielerTitel(schwelle: 500, titel: 'Geo-Profi 🎓'),
  SpielerTitel(schwelle: 550, titel: 'Weltmeister 🏆'),
];

/// Der Titel für [abgeschlosseneStationen] — der höchste, dessen Schwelle
/// erreicht ist. Gibt immer einen zurück, weil die erste Schwelle 0 ist.
String titelFuerStationen(int abgeschlosseneStationen) {
  var gefunden = spielerTitel.first.titel;
  for (final t in spielerTitel) {
    if (abgeschlosseneStationen >= t.schwelle) gefunden = t.titel;
  }
  return t(gefunden);
}
