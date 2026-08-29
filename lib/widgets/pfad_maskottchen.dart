import 'package:flutter/material.dart';
import 'pfad_deko_layer.dart' show pfadIconAbstandVonMitte;

const _coinVarianten = [
  'coin_normal',
  'coin_winken',
  'coin_denken',
  'coin_ueberrascht',
];

const _globusVarianten = [
  'globus_normal',
  'globus_winken',
  'globus_denken',
  'globus_ueberrascht',
];

List<Widget> _maskottchenOverlays({
  required List<({Offset pos, int stufe})> abschnitte,
  required double screenWidth,
  required List<String> varianten,
  required String fehlerLabel,
  double size = 315.0,
  double abstandOffset = 0.0,
  double ueberstand = 0.0,
}) {
  final overlays = <Widget>[];
  final mitte = screenWidth / 2;
  final abstand = pfadIconAbstandVonMitte + abstandOffset;

  for (final a in abschnitte) {
    final variant = varianten[(a.stufe - 1).clamp(0, varianten.length - 1)];
    // Seite (links/rechts) weiterhin von der zugehörigen Stationsposition
    // abgeleitet, die DISTANZ von der Mitte bis zur Icon-Innenkante ist aber
    // jetzt ein fixer, mit den Wahrzeichen-Icons geteilter Wert (siehe
    // pfadIconAbstandVonMitte in pfad_deko_layer.dart) statt eines
    // stationsrelativen Gaps — das war zuvor der Grund, warum Coin/Globus
    // optisch näher an der Mitte saßen als die Wahrzeichen. abstandOffset
    // erlaubt einen bewussten Versatz gegenüber diesem gemeinsamen Basiswert
    // (z.B. Coins etwas weiter außen als Wahrzeichen).
    // Der Klammergriff am Bildschirmrand darf um [ueberstand] gelockert
    // werden. Das ist der eigentliche Hebel für die Aussenlage: Auf jedem
    // Handy ist [abstand] so gross, dass die Klammer ohnehin greift — der
    // Kasten liegt bündig am Rand, und ein grösserer abstandOffset änderte
    // dort gar nichts. Beides zusammen verschiebt die Figur auf schmalen wie
    // auf breiten Bildschirmen gleich weit nach aussen.
    final links = a.pos.dx > mitte;
    final left = links
        ? (mitte - abstand - size).clamp(-ueberstand, screenWidth - size)
        : (mitte + abstand).clamp(0.0, screenWidth - size + ueberstand);
    overlays.add(Positioned(
      left: left,
      top: a.pos.dy - size / 2,
      width: size,
      height: size,
      // KEINE TIPPS ABFANGEN — sonst frisst die Figur die Stationsbuttons.
      //
      // Der Kasten ist quadratisch und so gross wie die längste Kante der
      // Datei (677x369, die Figur darin nur 238x273) — der grösste Teil davon
      // ist durchsichtiger Rand. Diese Overlays hängt der Lernpfad ZULETZT in
      // seinen Stack, und zuletzt gezeichnet heisst in Flutter: zuerst
      // getroffen. RenderImage.hitTestSelf liefert dabei auch für vollständig
      // durchsichtige Pixel true.
      //
      // Zusammen ergab das eine unsichtbare tote Zone über den Nachbarn des
      // Ankers: Am Gerät gemessen war die untere rechte Ecke des
      // Stationsbuttons eine Position über der Figur nicht mehr antippbar,
      // rund 40 % seiner Fläche. Das las sich als "der Button reagiert oft
      // erst beim zweiten Tippen" — wer oben links traf, kam durch.
      //
      // Die Figuren sind reine Dekoration und haben keinen eigenen Tipp-Zweck,
      // deshalb fallen Tipps hier einfach durch. Siehe den Test in
      // test/pfad_deko_tippdurchlass_test.dart.
      child: IgnorePointer(
        child: Image.asset(
          'assets/icons/deko/$variant.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) {
            debugPrint('$fehlerLabel FEHLER: $err');
            return const SizedBox.shrink();
          },
        ),
      ),
    ));
  }

  return overlays;
}

/// Wie weit die Coiny-Figuren weiter nach aussen rücken als zuvor.
///
/// Sie sassen sichtbar weiter innen als die übrigen Karikaturen am Rand.
///
/// ABGESCHNITTEN WIRD DABEI NICHTS: Die coin_*.png sind 677x369 gross, die
/// Figur darin sitzt bei (220,70) und ist 238x273 gross. Bei der Anzeigegrösse
/// 264,6 (BoxFit.contain, also Faktor 264,6/677 = 0,391) bleiben links wie
/// rechts durchsichtiger Rand — am knappsten bei coin_winken mit 55,9 px.
/// Die 30 px Überstand liegen vollständig darin. Siehe den Test in
/// test/pfad_maskottchen_test.dart, der den Rand aus der Datei nachmisst,
/// statt sich auf diese Zahlen zu verlassen.
const double _kCoinyNachAussen = 30.0;

/// Gibt eine Abschnitts-Münze pro Sektion zurück, neben der Anker-Position.
List<Widget> pfadMaskottchenOverlays({
  required List<({Offset pos, int stufe})> abschnitte,
  required double screenWidth,
}) => _maskottchenOverlays(
      abschnitte: abschnitte,
      screenWidth: screenWidth,
      varianten: _coinVarianten,
      fehlerLabel: 'MÜNZE',
      size: 264.6,
      abstandOffset: 60.0 + _kCoinyNachAussen,
      ueberstand: _kCoinyNachAussen,
    );

/// Gibt einen Globus pro Sektion zurück, neben der Anker-Position.
List<Widget> pfadGlobusOverlays({
  required List<({Offset pos, int stufe})> abschnitte,
  required double screenWidth,
}) => _maskottchenOverlays(
      abschnitte: abschnitte,
      screenWidth: screenWidth,
      varianten: _globusVarianten,
      fehlerLabel: 'GLOBUS',
      size: 220.5,
    );
