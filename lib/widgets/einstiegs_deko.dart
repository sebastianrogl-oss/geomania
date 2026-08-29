import 'package:flutter/material.dart';

import '../data/lernpfad_data.dart';
import 'lernpfad_station_button.dart';

// ── Deko-Ebene des Einstiegs ─────────────────────────────────────────────────
//
// Motive aus der App, zurückgenommen hinter dem Inhalt der drei
// Einstiegs-Screens. Sie geben dem Gradnetz Gesellschaft, ohne mit ihm oder
// dem Text zu konkurrieren.
//
// DREI SORTEN, damit die Fläche abwechslungsreich wirkt statt gemustert:
//
//  * Stationsbuttons des Lernpfads — DERSELBE LernpfadStationButton, den der
//    Pfad zeichnet, kein Nachbau. Die wiedererkennbarste Form der App.
//  * Symbole der Tages-Challenges aus assets/icons/.
//  * Wahrzeichen aus assets/icons/deko/ — dieselben Bilder, die im Lernpfad
//    neben dem Weg stehen (Eiffelturm, Big Ben, Pyramide, Opernhaus).
//
// Die Wahrzeichen stammen NICHT aus dem Gebäude-Quiz: der Modus
// bekanntesGebaeude ist reine Textarbeit ("In welchem Land steht [Bauwerk]?",
// siehe laender_gebaeude.dart) und hatte nie eigene Bilder. Die Illustrationen
// gehören zur Pfad-Deko (pfad_deko_layer.dart).
//
// Neue Grafikdateien braucht es für all das keine.

/// Deckkraft der Stationsbuttons.
///
/// 0.16 statt der ersten 0.06. Am gerenderten Bildschirm nachgemessen liegt
/// ein Button damit rund 14 von 255 Helligkeitsstufen unter dem leeren
/// Untergrund; bei 0.06 waren es 4, und das ging auf dem Gerät unter.
///
/// Der Text bleibt trotzdem unangetastet: Auf der abgedunkelten Fläche hat
/// die Textfarbe 0xFF1A1A1A noch rund 13:1 Kontrast — WCAG AAA verlangt 7:1.
/// Lesbarkeit ist hier also nicht die Grenze, sondern der Eindruck: Deutlich
/// darüber liest das Auge Bilder statt Untergrund.
const double _kDeckkraftStation = 0.16;

/// Deckkraft der Bild-Motive — höher als bei den Buttons, und das ist kein
/// Widerspruch.
///
/// Massgeblich ist der KONTRAST auf dem Schirm, nicht die Zahl im Code. Das
/// Stationsgrün (0xFF4A9E4A) ist kräftig und dunkel, die Illustrationen sind
/// helle Pastelltöne. Bei 0.16 lag ein Button gemessene 14 Helligkeitsstufen
/// unter dem Grund, der Eiffelturm nur 4 — dieselbe Zahl, völlig verschiedene
/// Sichtbarkeit.
///
/// Jedes Motiv einzeln nachgerechnet: die PNG-Datei auf kHintergrund
/// zusammengesetzt und die mittlere Helligkeit gemessen. Fünf der sechs
/// liegen dicht beieinander (14 bis 19 Stufen bei voller Deckkraft), 0.22
/// bringt sie damit in dieselbe Gegend wie die Buttons.
const double _kDeckkraftBild = 0.22;

/// Motive, die von sich aus mehr Kontrast mitbringen, mit eigenem Wert.
///
/// Das Higher-or-Lower-Symbol misst bei voller Deckkraft 39,5 Stufen — das
/// 2,5-Fache der übrigen, weil es als einziges gesättigtes Rot enthält. Mit
/// dem gemeinsamen 0.22 sprang es aus der Fläche heraus.
const Map<String, double> _kDeckkraftAbweichend = {
  _kChallengeHoeher: 0.09,
};

/// Ein einzelnes Element, in Anteilen der Bildschirmfläche.
///
/// Mittelpunkte statt Kanten, und bewusst auch Werte nahe 0 und 1: Ein Element,
/// das über den Rand hinausragt, wirkt wie ein Ausschnitt aus einem größeren
/// Muster — genau das soll es sein. Ein vollständig sichtbarer Kreis in der
/// Ecke sähe dagegen platziert aus.
///
/// Entweder [station] ODER [bild] ist gesetzt.
class _DekoElement {
  final double x;
  final double y;

  /// Vielfaches der Lernpfad-Größe (82 px) — für Bilder die Bildhöhe.
  final double groesse;

  /// Stationsbutton dieses Modus.
  final LernModus? station;

  /// Pfad einer Bilddatei.
  final String? bild;

  /// Neigung im Bogenmaß. Klein gehalten — die Motive sollen gekippt wirken,
  /// nicht umgefallen.
  final double neigung;

  const _DekoElement({
    required this.x,
    required this.y,
    required this.groesse,
    this.station,
    this.bild,
    this.neigung = 0,
  });
}

const _kChallengePreis = 'assets/icons/challenge_preis.png';
const _kChallengeHoeher = 'assets/icons/challenge_higher_lower.png';
const _kChallengeRanking = 'assets/icons/challenge_ranking.png';
const _kEiffelturm = 'assets/icons/deko/europa_eiffelturm.png';
const _kBigBen = 'assets/icons/deko/europa_bigben.png';
const _kPyramide = 'assets/icons/deko/afrika_pyramide.png';

/// Die Anordnung je Schritt — Anmelden, Name, Willkommen.
///
/// Vier Elemente pro Screen, auf die vier Ecken verteilt und je Screen aus
/// anderen Motiven gemischt: immer mindestens ein Stationsbutton, ein
/// Challenge-Symbol und ein Wahrzeichen. Sie gehören damit sichtbar zusammen,
/// ohne dass zwei Screens gleich aussehen.
///
/// Die Mitte bleibt frei: Auf allen drei Screens steht dort der Inhalt.
const List<List<_DekoElement>> _kAnordnung = [
  // Schritt 0 — Anmelden. Inhalt liegt etwa zwischen 35 % und 65 % der Höhe.
  [
    _DekoElement(
        x: 0.10, y: 0.12, groesse: 1.45, station: LernModus.flaggenQuizBild,
        neigung: -0.14),
    _DekoElement(x: 0.89, y: 0.20, groesse: 1.55, bild: _kEiffelturm),
    _DekoElement(
        x: 0.22, y: 0.87, groesse: 1.70, bild: _kChallengePreis,
        neigung: 0.10),
    _DekoElement(
        x: 0.94, y: 0.83, groesse: 1.05, station: LernModus.umrissBild,
        neigung: 0.16),
  ],
  // Schritt 1 — Namensauswahl. Gleiche freie Mitte, andere Gewichtung: das
  // Wahrzeichen wandert nach unten, das Challenge-Symbol nach oben.
  [
    _DekoElement(
        x: 0.12, y: 0.19, groesse: 1.10, station: LernModus.nachbarland,
        neigung: 0.16),
    _DekoElement(
        x: 0.90, y: 0.10, groesse: 1.45, bild: _kChallengeHoeher,
        neigung: -0.08),
    _DekoElement(x: 0.83, y: 0.88, groesse: 1.60, bild: _kBigBen),
    _DekoElement(
        x: 0.16, y: 0.92, groesse: 1.15, station: LernModus.waehrungsQuiz,
        neigung: -0.12),
  ],
  // Schritt 2 — Willkommen. Hier reicht der Inhalt fast über die ganze Höhe,
  // deshalb sitzen alle vier am äussersten Rand und ragen weit hinaus.
  [
    _DekoElement(
        x: 0.03, y: 0.05, groesse: 1.30, station: LernModus.hauptstaedteMultiple,
        neigung: 0.13),
    _DekoElement(
        x: 1.00, y: 0.28, groesse: 1.20, bild: _kChallengeRanking,
        neigung: -0.14),
    _DekoElement(x: 0.97, y: 0.72, groesse: 1.35, bild: _kPyramide),
    _DekoElement(
        x: 0.52, y: 1.00, groesse: 1.65, station: LernModus.flaggenQuizBild,
        neigung: 0.09),
  ],
];

/// Die Deko-Ebene für einen Einstiegs-Schritt.
///
/// Gehört zwischen Gradnetz und Inhalt in den Stack von GradnetzHintergrund.
class EinstiegsDeko extends StatelessWidget {
  final int schritt;

  const EinstiegsDeko({super.key, required this.schritt});

  @override
  Widget build(BuildContext context) {
    final elemente = _kAnordnung[schritt % _kAnordnung.length];

    return IgnorePointer(
      // Ändert sich nie — nicht bei jedem Tastendruck im Namensfeld neu
      // zeichnen. Die Opacity-Ebenen sind dafür der teurere Teil, nicht die
      // Motive selbst.
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, platz) => Stack(
            clipBehavior: Clip.none,
            children: [
              for (final e in elemente)
                _platziert(e, platz.maxWidth, platz.maxHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _platziert(_DekoElement e, double breite, double hoehe) {
    final d = kStationsButtonGroesse * e.groesse;
    return Positioned(
      left: breite * e.x - d / 2,
      top: hoehe * e.y - d / 2,
      child: Transform.rotate(
        angle: e.neigung,
        child: e.station != null
            ? Opacity(
                opacity: _kDeckkraftStation,
                // Ohne onTap bleibt der Button stumm stehen, siehe
                // LernpfadStationButton — die IgnorePointer-Ebene darüber
                // sorgt zusätzlich dafür, dass er keine Tipper abfängt.
                child: LernpfadStationButton(modus: e.station!, groesse: d),
              )
            : SizedBox(
                width: d,
                height: d,
                child: Image.asset(
                  e.bild!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  // Opacity direkt am Bild statt als eigene Ebene: erspart
                  // den Zwischenpuffer, den ein Opacity-Widget anlegt.
                  opacity: AlwaysStoppedAnimation(
                      _kDeckkraftAbweichend[e.bild!] ?? _kDeckkraftBild),
                ),
              ),
      ),
    );
  }
}
