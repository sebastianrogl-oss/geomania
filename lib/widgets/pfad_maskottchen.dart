import 'package:flutter/material.dart';

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
}) {
  final overlays = <Widget>[];
  const buttonHalf = 45.0;
  const gap = 50.0;
  final mitte = screenWidth / 2;

  for (final a in abschnitte) {
    final variant = varianten[(a.stufe - 1).clamp(0, varianten.length - 1)];
    final left = a.pos.dx > mitte
        ? (a.pos.dx - buttonHalf - gap - size).clamp(0.0, screenWidth - size)
        : (a.pos.dx + buttonHalf + gap).clamp(0.0, screenWidth - size);
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
