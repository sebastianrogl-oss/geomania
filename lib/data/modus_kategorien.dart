import 'package:flutter/material.dart';

import 'lernpfad_data.dart';

// ── Lern-Fortschritt: Modus → Kategorie ───────────────────────────────────────
//
// DIE EINE STELLE, an der steht, welcher Modus in welchem Fortschrittsbalken
// des Profils zählt. Ein neuer Modus wird ausschliesslich hier eingetragen —
// der Profil-Screen liest die Liste, er kennt keine einzelnen Modi mehr.
//
// Warum das eine eigene Datei ist: Die Zuordnung lebte vorher als lose
// Konstanten im Profil-Screen. Als fünf Modi in den Lernpfad kamen, wurde sie
// dort schlicht vergessen — 138 der 594 Stationen (23 % des Pfads) tauchten in
// KEINEM Balken auf, ohne dass irgendwo etwas aufgefallen wäre. Die Prozente
// blieben plausibel, sie beschrieben nur einen kleineren Pfad als den echten.
// Genau dagegen steht [unzugeordneteModi] weiter unten, geprüft von
// test/modus_kategorien_test.dart.

/// Ein Fortschrittsbalken im Profil: mehrere verwandte Modi unter einem Namen.
class ModusKategorie {
  /// Deutscher Anzeigename; wird beim Rendern durch `t()` geschickt.
  final String label;

  /// Farbe des Balkens.
  final Color farbe;

  /// Modus, dessen Emoji die Zeile bebildert (nur zur Anzeige).
  final LernModus symbolModus;

  /// Alle Modi, deren Stationen in diesen Balken zählen.
  final Set<LernModus> modi;

  const ModusKategorie({
    required this.label,
    required this.farbe,
    required this.symbolModus,
    required this.modi,
  });
}

/// Die Balken des Lern-Fortschritts, in Anzeigereihenfolge.
///
/// Gruppiert nach Thema, nicht nach Spielmechanik: Wer wissen will, wie gut er
/// Nachbarländer kennt, interessiert sich nicht dafür, ob die Frage als Quiz
/// oder als Kettenspiel gestellt wurde.
const List<ModusKategorie> kModusKategorien = [
  ModusKategorie(
    label: 'Flaggen',
    farbe: Color(0xFF4A90D9),
    symbolModus: LernModus.flaggenQuizBild,
    modi: {
      LernModus.flaggenQuizBild,
      LernModus.flaggenQuizMultiple,
      LernModus.flaggenQuizEingabe,
    },
  ),
  ModusKategorie(
    label: 'Hauptstädte',
    farbe: Color(0xFF7C3AED),
    symbolModus: LernModus.hauptstaedteMultiple,
    modi: {
      LernModus.hauptstaedteMultiple,
      LernModus.hauptstaedteEingabe,
    },
  ),
  ModusKategorie(
    label: 'Umrisse',
    farbe: Color(0xFF4A9E4A),
    symbolModus: LernModus.umrissBild,
    modi: {
      LernModus.umrissBild,
      LernModus.umrissMultiple,
      LernModus.umrissEingabe,
    },
  ),
  ModusKategorie(
    label: 'Nachbarn & Grenzen',
    farbe: Color(0xFF00897B),
    symbolModus: LernModus.nachbarland,
    modi: {
      LernModus.nachbarland,
      LernModus.grenzkettenRaetsel,
      LernModus.nachbarschaftsKette,
    },
  ),
  ModusKategorie(
    label: 'Länder-Daten',
    farbe: Color(0xFFF9A825),
    symbolModus: LernModus.preisSchaetzen,
    modi: {
      LernModus.preisSchaetzen,
      LernModus.wirtschaftssektoren,
      LernModus.waehrungsQuiz,
      LernModus.waehrungZuLand,
    },
  ),
  ModusKategorie(
    label: 'Wissen & Rätsel',
    farbe: Color(0xFFC0185A),
    symbolModus: LernModus.zufallsFakt,
    modi: {
      LernModus.zufallsFakt,
      LernModus.zweiWahrheiten,
      LernModus.wasGehoertNichtDazu,
    },
  ),
  ModusKategorie(
    label: 'Ordnen & Vergleichen',
    farbe: Color(0xFF1565C0),
    symbolModus: LernModus.sortierSpiel,
    modi: {
      LernModus.sortierSpiel,
      LernModus.laenderRanking,
      LernModus.flaechenVergleich,
    },
  ),
];

/// Modi ausser Dienst: gebaut, aber in keiner Level-Modiliste des Lernpfads.
///
/// Sie stehen bewusst in KEINER Kategorie — ein Balken, der sie mitzählt,
/// bliebe für immer bei seinem alten Wert stehen. Der Eintrag hier ist die
/// Erlaubnis dafür: [unzugeordneteModi] meldet jeden Modus, der weder in einer
/// Kategorie noch in dieser Liste steht.
///
/// Gespeicherter Fortschritt zu ihren früheren Stationen geht davon NICHT
/// verloren. Er liegt unter der Stations-ID in den Einstellungen; die
/// Auswertung läuft über den heutigen Pfad und liest ihn schlicht nicht.
/// Kommt ein Modus zurück, zählt er wieder mit — dann gehört er aber auch
/// wieder in eine Kategorie.
const Set<LernModus> kAusserDienstModi = {
  LernModus.flaeche,
  LernModus.bipGesamt,
  LernModus.extremFrage,
  LernModus.extremFrageLeicht,
  LernModus.bekanntesGebaeude,
};

/// Modi, die in keiner Kategorie stehen und auch nicht als ausser Dienst
/// gemeldet sind — leer, solange die Zuordnung vollständig ist.
///
/// Das ist die Prüfung gegen den Fehler von oben: Wer einen Modus in den
/// Lernpfad aufnimmt und hier nicht einträgt, bekommt einen roten Test statt
/// still verschwindender Prozentpunkte.
Set<LernModus> get unzugeordneteModi {
  final zugeordnet = <LernModus>{
    for (final k in kModusKategorien) ...k.modi,
    ...kAusserDienstModi,
  };
  return LernModus.values.toSet().difference(zugeordnet);
}

/// Modi, die in mehr als einer Kategorie stehen — jeder Modus darf nur einmal
/// zählen, sonst überzeichnet er den Gesamtfortschritt.
Set<LernModus> get mehrfachZugeordneteModi {
  final gesehen = <LernModus>{};
  final doppelt = <LernModus>{};
  for (final k in kModusKategorien) {
    for (final m in k.modi) {
      if (!gesehen.add(m)) doppelt.add(m);
    }
  }
  return doppelt;
}
