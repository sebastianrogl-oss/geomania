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
    final links = a.pos.dx > mitte;
    final left = links
        ? (mitte - abstand - size).clamp(0.0, screenWidth - size)
        : (mitte + abstand).clamp(0.0, screenWidth - size);
    overlays.add(Positioned(
      left: left,
      top: a.pos.dy - size / 2,
      width: size,
      height: size,
      child: Image.asset(
        'assets/icons/deko/$variant.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) {
          // ignore: avoid_print
          print('$fehlerLabel FEHLER: $err');
          return const SizedBox.shrink();
        },
      ),
    ));
  }

  return overlays;
}

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
      abstandOffset: 60.0,
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
