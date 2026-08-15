import 'package:flutter/material.dart';
import 'flaggen_widget.dart' show zeigeFlagge;

/// Länderflagge mit dünnem, dezenten Rand — hebt weißlastige Flaggen (z.B.
/// Japan) vom weißen Kartenhintergrund ab. Einheitliche Darstellung für alle
/// Flaggen-Vorkommen im Portfolio-Spiel (Nachrichtenkarten, Länderauswahl),
/// statt den Rand an jeder Stelle einzeln zu duplizieren.
class PortfolioFlagge extends StatelessWidget {
  final String iso;
  final double width;
  final double height;
  final double radius;

  const PortfolioFlagge({
    super.key,
    required this.iso,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  // zeigeFlagge()/CountryFlag.fromCountryCode rendert intern IMMER mit BoxFit.contain
  // (nicht überschreibbar) — bei abweichendem Flaggen-Seitenverhältnis bleibt
  // dadurch transparenter Rand links/rechts oder oben/unten übrig, wodurch
  // der Rahmen sichtbar außerhalb der eigentlichen Flagge zu schweben scheint
  // statt direkt an ihr zu liegen. Fix: die Flagge in einem großen neutralen
  // Quadrat anfordern (füllt darin garantiert mind. eine Achse voll aus) und
  // per FittedBox(cover) + dem äußeren ClipRRect auf die Zielgröße zuschneiden
  // — dadurch füllt die Flagge IMMER die komplette Box, der Rahmen liegt
  // exakt an ihrem sichtbaren Rand.
  static const double _referenzGroesse = 100;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFD0CEC8), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((radius - 1).clamp(0, radius)),
        child: FittedBox(
          fit: BoxFit.cover,
          child: zeigeFlagge(iso,
              width: _referenzGroesse, height: _referenzGroesse),
        ),
      ),
    );
  }
}
