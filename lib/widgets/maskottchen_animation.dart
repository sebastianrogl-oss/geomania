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
        // BoxFit.cover mit der voreingestellten mittigen Ausrichtung — mehr
        // braucht es nicht, um die Münze im Kreis zu zentrieren.
        //
        // Hier stand vorher alignment: Alignment(-1.0, 0.0) (also linksbündig)
        // plus ein Transform.translate um FESTE -75 Pixel zurück nach rechts.
        // Zusammen ergab das ungefähr die Mitte — aber nur bei einer einzigen
        // Größe: die Lottie-Leinwand ist 720x405, unter BoxFit.cover in einem
        // Quadrat der Kantenlänge G also 1,778*G breit. Mittig wäre eine
        // Verschiebung von 0,389*G, und das sind bei G=200 (Anzeigename-
        // Screen) 77,8 Pixel — nahe genug an den 75, dass es dort nie
        // auffiel.
        //
        // Bei jeder anderen Größe stimmt der feste Wert nicht: beim
        // Willkommens-Screen (96 bis 170) schob er die Münze 9 bis 38 Pixel
        // zu weit nach links. Der Versatz gehörte also nie an eine absolute
        // Zahl, und statt ihn auf 0,389*G umzurechnen, entfällt er ganz —
        // denn genau das tut die mittige Ausrichtung von sich aus, bei jeder
        // Größe.
        //
        // Nebenbei behoben: das Ersatzbild im errorBuilder lag mit im
        // Transform und wurde dadurch ebenfalls verschoben.
        child: Lottie.asset(
          'assets/icons/deko/coin_dance.json',
          width: groesse,
          height: groesse,
          fit: BoxFit.cover,
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
    );
  }
}
