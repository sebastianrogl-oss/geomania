import 'package:flutter/material.dart';
import '../services/challenge_panel_signal.dart';

/// Einheitliche obere Zeile für die Ergebnis-Screens ALLER Tages-Challenges
/// (Das große Schätzen, Higher/Lower, Ranking-Quiz, Portfolio): Zurück-Button
/// links, Titel + optional Kategorie darunter zentriert — ersetzt die vorher
/// je Challenge unterschiedlichen "Sprüche" (z.B. "Spiel vorbei!",
/// "Ausgezeichnet!") und Kopfzeilen.
class ChallengeErgebnisHeader extends StatelessWidget {
  final String titel;
  final String? kategorie;

  const ChallengeErgebnisHeader({super.key, required this.titel, this.kategorie});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
            onPressed: () => ChallengePanelSignal.zurueckZumPanel(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(titel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                if (kategorie != null)
                  Text(kategorie!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // Balanciert den IconButton links, damit der Titel wirklich mittig
          // sitzt (wie AppBar mit centerTitle: true).
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
