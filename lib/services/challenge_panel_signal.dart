import 'package:flutter/material.dart';

/// Signalisiert dem Home-Screen, das Challenge-Panel (die 4 Tages-Challenge-
/// Karten) wieder zu öffnen. Genutzt vom finalen "Weiter"-Button in den
/// Ergebnis-Screens aller 4 Challenges, damit man nach Abschluss direkt
/// wieder in der Challenge-Übersicht landet statt nur auf dem Lernpfad.
class ChallengePanelSignal {
  static final oeffnen = ValueNotifier<int>(0);

  /// Navigiert gezielt zurück zum Challenge-Panel auf dem Home-Screen (die 4
  /// Tages-Challenge-Karten) — poppt bis zur ersten Route und signalisiert
  /// danach, das Panel wieder zu öffnen. Einzige Stelle, die diese Navigation
  /// implementiert, damit der Zurück-Pfeil im Start-/Ergebnis-Screen und der
  /// finale "Weiter"-Button in allen 4 Challenges garantiert gleich bleiben.
  static void zurueckZumPanel(BuildContext context) {
    oeffnen.value++;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
