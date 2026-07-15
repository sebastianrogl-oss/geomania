import 'package:flutter/material.dart';
import '../l10n/uebersetzungen.dart';
import '../services/challenge_panel_signal.dart';

/// Einheitlicher Abschluss-Button für alle Tages-Challenge-Ergebnis-Screens
/// — Stil und Text ("Fertig") vom Portfolio-Auflösungs-Screen übernommen,
/// ersetzt die vorher je Challenge unterschiedlichen "Weiter"-Buttons.
class ChallengeFertigButton extends StatelessWidget {
  final VoidCallback? onTap;

  const ChallengeFertigButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => ChallengePanelSignal.zurueckZumPanel(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF4A9E4A),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: const Color(0xFF1A1A1A), width: 2.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Text(t('Fertig'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}
