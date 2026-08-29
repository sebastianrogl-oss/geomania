import 'haptik_service.dart';

/// Die Rastung eines Reglers — ein feiner Stoss beim Überfahren eines
/// Rastpunkts.
///
/// ── Nur Haptik, kein Ton ──────────────────────────────────────────────────
///
/// Hier lag bis eben zusätzlich ein Klickgeräusch (blopp.wav), dessen
/// Lautstärke mit dem Zieh-Tempo stieg. Es ist raus: Beim Ziehen über einen
/// Balken kommen die Rastungen dicht, und eine hörbare Klickfolge wurde als
/// aufdringlich empfunden. Am Finger bleibt sie dezent.
///
/// Mit dem Ton entfiel auch die Tempo-Messung. Sie hatte nur zwei Abnehmer:
/// die Lautstärke des Klangs und die Wahl zwischen zwei Stossstärken. Der
/// Stoss ist jetzt immer der feinste, den der Dienst kennt
/// ([HaptikArt.auswahl], 18 ms bzw. ein TICK-Primitiv) — damit hatte die
/// Messung keinen Abnehmer mehr und ist mit ausgebaut.
///
/// ── Warum ein gemeinsamer Baustein ────────────────────────────────────────
///
/// Zwei Regler nutzen sie: der Rang-Balken im Länder-Ranking und der Regler
/// beim grossen Schätzen. Beide zeigen denselben [SchaetzBalken], also soll
/// sich beides auch gleich anfühlen.
///
/// Jeder Regler hält eine eigene Instanz: Die letzte Marke gehört zu einer
/// bestimmten Ziehbewegung, nicht zur App.
///
/// ── Woran die Rastpunkte hängen ───────────────────────────────────────────
///
/// An einem EIGENEN, feinen Raster über den ganzen Balken — nicht an der
/// sichtbaren Skala und nicht an der Einheit des Reglers.
///
/// Vorher rastete es an den gezeichneten Strichen: beim Rang-Balken alle fünf
/// Plätze, beim Schätz-Regler alle 10 % der Strecke. Das fühlte sich leer an,
/// weil eine kleine Fingerbewegung gar nichts auslöste — und beim Schätzen
/// kamen über den ganzen Balken nur zehn Klicks.
///
/// Jetzt liegen [kSchritte] Rastpunkte über der Strecke, unabhängig davon,
/// wie viele Striche gezeichnet sind. Beide Regler fühlen sich dadurch gleich
/// an, und die Dichte ist eine Zahl an einer Stelle statt einer Folge aus der
/// jeweiligen Skala.
///
class ReglerRastung {
  /// Mindestpause zwischen zwei Impulsen.
  ///
  /// UNVERÄNDERT aus dem Rang-Balken übernommen und die harte Untergrenze:
  /// Ein schneller Wisch über 40 Marken wären sonst 40 Klicks in einer
  /// Viertelsekunde — Dauerrauschen statt Ratsche.
  static const kPause = Duration(milliseconds: 55);

  /// Rastpunkte über die ganze Balkenlänge.
  ///
  /// AM GERÄT AUSGEMESSEN (SM A136B, Balken 344 dp breit), gezogen über den
  /// ganzen Balken; angegeben ist der mittlere Abstand zwischen zwei Stössen:
  ///
  ///   Zugdauer     n=40     n=120    n=200
  ///   6,0 s          —      82 ms    70 ms
  ///   3,0 s       89 ms     70 ms    64 ms
  ///   1,0 s       72 ms     64 ms    69 ms
  ///   0,25 s      56 ms     63 ms    59 ms
  ///
  /// 40 ist die alte Dichte: ein Rastpunkt alle 8,6 dp, und wer nur ein
  /// kleines Stück zieht, löst gar nichts aus — genau das leere Gefühl.
  ///
  /// 200 liegt schon beim langsamsten Zug bei 70 ms und damit fast auf der
  /// Mindestpause. Die Folge reagiert dann kaum noch auf das Tempo,
  /// weil ohnehin immer die Pause bestimmt, wann der nächste kommt —
  /// gleichmässiges Rauschen statt Ratsche.
  ///
  /// 120 behält den Abstand zur Pause (82 ms beim langsamen Zug) und liegt
  /// bei 2,9 dp je Rastpunkt: kleiner als jede bewusste Fingerbewegung, also
  /// rastet es beim Feinjustieren fortlaufend, ohne dass die Pause eingreift.
  /// Erst beim zügigen Ziehen übernimmt sie.
  static const int kSchritte = 120;

  int? _letzteMarke;
  DateTime _letzterImpuls = DateTime.fromMillisecondsSinceEpoch(0);

  /// Setzt die Bewegung zurück — neue Frage, neue Runde.
  ///
  /// Nicht zurückgesetzt wird [_letzterImpuls]: Die Mindestpause gilt über
  /// den Wechsel hinweg, sonst käme direkt nach einem Klick noch einer.
  void ruecksetzen() {
    _letzteMarke = null;
  }

  /// Bei jeder Zieh-Meldung aufzurufen.
  ///
  /// [anteil] ist die Position von 0 bis 1. Mehr braucht es nicht: In welcher
  /// Einheit der Regler rechnet, ist für die Rastung ohne Belang.
  void ziehen({required double anteil}) {
    final marke = (anteil.clamp(0.0, 1.0) * kSchritte).floor();
    if (marke == _letzteMarke) return;
    _letzteMarke = marke;
    final jetzt = DateTime.now();
    if (jetzt.difference(_letzterImpuls) < kPause) return;
    _letzterImpuls = jetzt;

    HaptikService.spiele(HaptikArt.auswahl);
  }
}
