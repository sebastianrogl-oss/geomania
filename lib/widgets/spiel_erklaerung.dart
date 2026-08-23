import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Wiederverwendbarer "?"-Hilfe-Button + Erklärungs-Sheet für die 4 Tages-
// Challenges — gemeinsame Optik/Verhalten statt 4x dieselbe Dialog-Logik.
// ══════════════════════════════════════════════════════════════════════════════

/// Runder "?"-Button, passend zum bestehenden Zurück-Pfeil-Look der
/// Challenge-Header (heller Kreis-/Quadrat-Hintergrund, dunkles Icon).
class ErklaerungButton extends StatelessWidget {
  final String titel;
  final List<String> abschnitte;
  final Color farbe;

  const ErklaerungButton({
    super.key,
    required this.titel,
    required this.abschnitte,
    required this.farbe,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => zeigeSpielErklaerung(
        context,
        titel: titel,
        abschnitte: abschnitte,
        farbe: farbe,
      ),
      // Der sichtbare Knopf bleibt 36 px, die Tippfläche wächst auf 44 —
      // dasselbe Muster wie beim Fragezeichen-Knopf im Quiz.
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAE5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              color: Color(0xFF1A1A1A),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Zeigt die schriftliche Spielerklärung als Bottom-Sheet mit X-Schließen-
/// Button oben — [abschnitte] sind einzelne Absätze/Regeln, nacheinander
/// dargestellt.
///
/// Gibt das Future des Sheets zurück, damit ein Aufrufer warten kann, bis es
/// geschlossen wurde — der Lernpfad startet den Countdown erst danach.
Future<void> zeigeSpielErklaerung(
  BuildContext context, {
  required String titel,
  required List<String> abschnitte,
  required Color farbe,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: kHintergrund,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(ctx),
                    // Der sichtbare Kreis bleibt 32 px; getroffen werden muss
                    // er mit einem Finger, deshalb liegt eine 44er Fläche
                    // darum. Ohne opaque wäre der freie Rand nicht tippbar.
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAEAE5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF888888),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                itemCount: abschnitte.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: farbe, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(abschnitte[i],
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFF3A3A3A))),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
