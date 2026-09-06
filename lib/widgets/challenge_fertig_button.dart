import 'package:flutter/material.dart';
import '../l10n/uebersetzungen.dart';
import '../services/challenge_panel_signal.dart';
import '../services/knopf_rueckmeldung.dart';
import 'streak_feier_overlay.dart';

/// Einheitlicher Abschluss-Button für alle Tages-Challenge-Ergebnis-Screens
/// — Stil und Text ("Fertig") vom Portfolio-Auflösungs-Screen übernommen,
/// ersetzt die vorher je Challenge unterschiedlichen "Weiter"-Buttons.
///
/// Der Knopfklang sitzt bewusst HIER und nicht in den vier Challenges: der
/// Button ist ohnehin schon der gemeinsame Baustein für ihren Abschluss, und
/// so kann keine Challenge ihn beim nächsten Umbau vergessen.
///
/// ── Und aus demselben Grund die Streak-Feier ──────────────────────────────
///
/// Seit die Tages-Challenges den Streak mitzählen, gehört ihnen auch die
/// Feier. Sie hier einzuhängen ist die einzige Stelle, die alle vier ohne
/// Kopie erreicht: [DailyChallenge.markDone] zählt den Tag (hat aber keinen
/// BuildContext), dieser Knopf zeigt den Moment.
///
/// BEIM VERLASSEN und nicht beim Erscheinen der Ergebnis-Ansicht: Ein
/// Vollbild-Moment, der über dem gerade erspielten Ergebnis aufgeht, nimmt
/// ihm das Gewicht. Erst das Ergebnis, dann die Feier, dann zurück zum Panel.
class ChallengeFertigButton extends StatelessWidget {
  final VoidCallback? onTap;

  const ChallengeFertigButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        knopfRueckmeldung();
        // Blockiert, bis der Nutzer die Feier weggetippt hat — steht heute
        // keine aus, kehrt der Aufruf sofort zurück.
        await streakFeierNachChallenge(context);
        if (!context.mounted) return;
        if (onTap != null) {
          onTap!();
        } else {
          ChallengePanelSignal.zurueckZumPanel(context);
        }
      },
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
