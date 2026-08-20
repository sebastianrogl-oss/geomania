import 'dart:math';

import '../widgets/ergebnis_video.dart';

/// Sprüche für den Halbzeit-Moment (widgets/halbzeit_overlay.dart).
///
/// Coiny spricht — der Ton darf frech und persönlich sein, nicht bloß
/// sachlich-motivierend. Je Ergebnis-Kategorie mehrere Varianten, damit sich
/// der Moment auch bei vielen Stationen nicht abnutzt.
///
/// Die deutschen Texte sind die Schlüssel; die englischen Fassungen stehen in
/// l10n/uebersetzungen_lernpfad.dart und sind sinngemäß übersetzt, nicht
/// wörtlich — der Ton soll erhalten bleiben.
class HalbzeitSprueche {
  static const alleRichtig = [
    'Keine einzige daneben. Respekt!',
    'Du machst das echt zu leicht.',
    'Makellos. Weiter so!',
    'Fehlerfrei — beeindruckend!',
    'Okay, du kannst das offensichtlich.',
    'Perfekt bisher. Bleibt das so?',
    'Nicht ein Fehler. Stark!',
    'Du bist auf einem Lauf!',
  ];

  static const stark = [
    'Läuft richtig gut!',
    'Stark unterwegs!',
    'Das sieht gut aus!',
    'Gut in Fahrt — weiter so!',
    'Fast alles richtig!',
    'Solide Halbzeit!',
    'Da geht noch was, aber stark!',
    'Bleib dran, das passt!',
  ];

  static const solide = [
    'Halbzeit geschafft!',
    'Auf gutem Weg!',
    'Solide bisher!',
    'Geht doch!',
    'Zweite Hälfte, jetzt zeigst du es!',
    'Noch ist alles drin!',
    'Gut dabei — weiter!',
    'Läuft. Bleib dran!',
  ];

  static const aufholen = [
    'Zweite Hälfte, neue Chance!',
    'Nicht aufgeben — du packst das!',
    'Jetzt erst recht!',
    'Aufwärmen ist vorbei!',
    'Das wird noch!',
    'Kopf hoch, weiter geht\'s!',
    'Die zweite Hälfte gehört dir!',
    'Dranbleiben lohnt sich!',
  ];

  static final _rng = Random();
  /// Zuletzt gezeigter Spruch — verhindert zweimal denselben hintereinander.
  static String? _zuletzt;

  /// Wählt einen Spruch passend zum bisherigen Ergebnis.
  static String fuer(int richtig, int beantwortet) {
    final liste = _liste(richtig, beantwortet);
    // Bei nur einer verbleibenden Möglichkeit ist Wiederholung unvermeidbar.
    final auswahl = liste.where((s) => s != _zuletzt).toList();
    final quelle = auswahl.isEmpty ? liste : auswahl;
    final spruch = quelle[_rng.nextInt(quelle.length)];
    _zuletzt = spruch;
    return spruch;
  }

  // Die Schwellen selbst stehen in ergebnis_video.dart — dieselbe Funktion
  // wählt auch das Video. So können Spruch und Video nicht auseinanderlaufen.
  static List<String> _liste(int richtig, int beantwortet) {
    switch (ergebnisStufe(richtig, beantwortet)) {
      case ErgebnisStufe.perfekt:
        return alleRichtig;
      case ErgebnisStufe.stark:
        return stark;
      case ErgebnisStufe.solide:
        return solide;
      case ErgebnisStufe.aufholen:
        return aufholen;
    }
  }
}
