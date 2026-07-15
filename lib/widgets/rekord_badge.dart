import 'package:flutter/material.dart';
import '../l10n/uebersetzungen.dart';

/// Einheitliche "Neuer Rekord"/"Rekord: X"-Anzeige für alle Tages-Challenge-
/// Ergebnis-Screens — sitzt konsistent zwischen ChallengeErgebnisHeader und
/// der Punktzahl-Karte (RanglisteErgebnisKarte).
class RekordBadge extends StatelessWidget {
  final bool neuerRekord;
  // z.B. "12 Richtige in Folge", "480 Pkt." — null wenn kein Rekord existiert.
  final String? rekordText;

  const RekordBadge({super.key, required this.neuerRekord, this.rekordText});

  @override
  Widget build(BuildContext context) {
    if (neuerRekord) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(12)),
          child: Text(t('🏆 Neuer Rekord!'),
              style: const TextStyle(
                  color: Color(0xFF856404),
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ),
      );
    }
    if (rekordText == null) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0xFFEAEAE5),
            borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('🏆 Rekord:'),
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text(rekordText!,
                style: const TextStyle(
                    color: Color(0xFFF9A825),
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
