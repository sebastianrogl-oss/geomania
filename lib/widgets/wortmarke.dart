import 'package:flutter/material.dart';

// ── Wortmarke ────────────────────────────────────────────────────────────────
//
// "GeoMania" als reiner Schriftzug.
//
// Coiny stand hier zunächst daneben, ausgemessen auf die sichtbare Münze und
// auf die Versalhöhe abgestimmt. Er ist wieder raus: Neben dem Namen wurde er
// zu einem zweiten Blickfang, wo der Einstieg nur einen braucht — und im Spiel
// selbst ist er ohnehin ständig da. Der Schriftzug allein sitzt jetzt
// tatsächlich in der Mitte; mit der Münze davor lag die Schrift immer etwas
// rechts davon.

class Wortmarke extends StatelessWidget {
  /// Schriftgröße des Schriftzugs.
  final double groesse;
  final Color farbe;

  const Wortmarke({
    super.key,
    this.groesse = 32,
    this.farbe = const Color(0xFF1A1A1A),
  });

  @override
  Widget build(BuildContext context) {
    // Verkleinern, wenn es nicht passt — bei grosser Systemschrift ist der
    // Schriftzug auf einem 320-px-Gerät sonst zu breit. scaleDown vergrössert
    // nie, passt es also, tut die FittedBox nichts.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'GeoMania',
        // Der Name wird NICHT übersetzt — er ist in jeder Sprache derselbe.
        style: TextStyle(
          fontSize: groesse,
          fontWeight: FontWeight.w900,
          color: farbe,
          height: 1.0,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
