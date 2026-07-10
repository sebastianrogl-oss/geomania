import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Dekorative, endlos loopende Maskottchen-Animation (Lottie, kein Video) —
/// läuft automatisch, lautlos, ohne jede Steuerelemente, wirkt wie ein
/// animiertes GIF. Runder Rahmen mit Schatten, Bildinhalt füllt den Kreis
/// per BoxFit.cover komplett aus (kein Letterboxing/Farbrand mehr, da der
/// Kreis überschüssigen Bildrand statt Hintergrundfläche zeigt). Fällt bei
/// Ladefehler auf das statische coin_winken.png zurück, im selben Rahmen.
class MaskottchenAnimation extends StatelessWidget {
  final double groesse;
  const MaskottchenAnimation({super.key, this.groesse = 100});

  static const _rahmenFarbe = Color(0xFF1a1a1a);

  BoxDecoration get _rahmenDekoration => BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _rahmenFarbe, width: 3),
        boxShadow: [
          BoxShadow(
            color: _rahmenFarbe.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: groesse,
      height: groesse,
      decoration: _rahmenDekoration,
      child: ClipOval(
        // Lottie's alignment steht bereits auf dem Maximum (-1.0) -> für
        // noch mehr Verschiebung ohne Zoom bleibt nur ein zusätzlicher
        // Transform.translate auf das fertig zugeschnittene Ergebnis. Ohne
        // zusätzlichen Zoom kann dabei ab einem gewissen Versatz am rechten
        // Rand ein leerer/durchsichtiger Bereich sichtbar werden, da kein
        // weiterer Bildinhalt mehr vorhanden ist.
        child: Transform.translate(
          offset: const Offset(-75, 0),
          child: Lottie.asset(
            'assets/icons/deko/coin_dance.json',
            width: groesse,
            height: groesse,
            fit: BoxFit.cover,
            alignment: const Alignment(-1.0, 0.0),
            repeat: true,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/icons/deko/coin_winken.png',
              width: groesse,
              height: groesse,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) =>
                  SizedBox(width: groesse, height: groesse),
            ),
          ),
        ),
      ),
    );
  }
}
