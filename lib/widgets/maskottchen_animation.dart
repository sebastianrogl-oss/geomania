import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Dekorative, endlos loopende Maskottchen-Animation (Lottie, kein Video) —
/// läuft automatisch, lautlos, ohne jede Steuerelemente, wirkt wie ein
/// animiertes GIF. Runder Rahmen mit Schatten, Bildinhalt füllt den Kreis
/// komplett aus (kein Letterboxing/Farbrand, da der Kreis überschüssigen
/// Bildrand statt Hintergrundfläche zeigt). Fällt bei Ladefehler auf das
/// statische coin_winken.png zurück, im selben Rahmen.
class MaskottchenAnimation extends StatelessWidget {
  final double groesse;
  const MaskottchenAnimation({super.key, this.groesse = 100});

  static const _rahmenFarbe = Color(0xFF1a1a1a);

  /// Seitenverhältnis der Lottie-Leinwand (720 × 405). Muss zur Datei passen —
  /// bei einem Austausch der Animation hier mitziehen. Ein Vertippen fällt
  /// nicht schlimm aus: durch BoxFit.contain unten entsteht dann ein kleiner
  /// Rand, aber keine verzerrte Münze.
  static const _leinwandVerhaeltnis = 720 / 405;

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
    // Die Leinwand ist breiter als hoch, der Kreis ist quadratisch — es muss
    // also links und rechts etwas abgeschnitten werden. Das erledigt hier
    // BEWUSST NICHT Lottie, sondern Flutter:
    //
    // Lottie beherrscht BoxFit.cover nicht richtig. In lottie_drawable.dart
    // wird der Ausschnitt zwar berechnet (sourceRect, bei uns ab x=157,5),
    // beim Zeichnen aber nie angewendet — die Leinwand landet immer ab x=0 auf
    // dem Canvas, also linksbündig statt mittig. Bei uns hiess das: die Münze
    // rutschte nach rechts aus dem Kreis heraus und wurde angeschnitten.
    // (Genau dagegen stand hier frueher ein Transform.translate um feste
    // -75 Pixel — die Kompensation stimmte nur bei einer einzigen Groesse.)
    //
    // Statt den Versatz erneut selbst nachzurechnen, bekommt Lottie eine Box
    // im Seitenverhaeltnis der Leinwand, in der nichts zu beschneiden ist.
    // Diese zu breite Box zentriert die OverflowBox über dem Kreis, und das
    // ClipOval schneidet links und rechts gleich viel ab — bei jeder Groesse.
    final breite = groesse * _leinwandVerhaeltnis;

    return Container(
      width: groesse,
      height: groesse,
      decoration: _rahmenDekoration,
      child: ClipOval(
        child: OverflowBox(
          maxWidth: breite,
          maxHeight: groesse,
          child: Lottie.asset(
            'assets/icons/deko/coin_dance.json',
            width: breite,
            height: groesse,
            fit: BoxFit.contain,
            repeat: true,
            // Das Ersatzbild bleibt quadratisch und wird von derselben
            // OverflowBox mittig gesetzt — es erbt den Versatz also nicht.
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
