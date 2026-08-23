import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/data/modus_kategorien.dart';

/// Wächter über die Zuordnung Modus → Fortschrittsbalken.
///
/// Der Anlass: Als flaechenVergleich, zweiWahrheiten, wasGehoertNichtDazu,
/// laenderRanking und nachbarschaftsKette in den Lernpfad kamen, wurden sie in
/// keine Profil-Kategorie eingetragen. 138 von 594 Stationen — 23 % des Pfads —
/// zählten danach in KEINEM Balken. Auffallen konnte das nicht: die
/// Prozentwerte blieben plausibel, sie beschrieben nur einen kleineren Pfad.
///
/// Diese Tests machen genau diesen Fall laut.
void main() {
  test('jeder Modus steht in einer Kategorie oder ist ausser Dienst', () {
    expect(unzugeordneteModi, isEmpty,
        reason: 'Diese Modi zählen in keinem Fortschrittsbalken mit. Trage sie '
            'in lib/data/modus_kategorien.dart ein — entweder in eine '
            'Kategorie oder, falls sie aus dem Lernpfad genommen wurden, in '
            'kAusserDienstModi.');
  });

  test('kein Modus steht in zwei Kategorien', () {
    expect(mehrfachZugeordneteModi, isEmpty,
        reason: 'Doppelt gezählte Modi überzeichnen den Fortschritt.');
  });

  test('Modi ausser Dienst kommen wirklich in keiner Station vor', () {
    final imPfad = <LernModus>{
      for (final w in lernwelten)
        for (final a in w.abschnitte)
          for (final s in a.stationen) s.modus,
    };
    final wiederAktiv = kAusserDienstModi.intersection(imPfad);
    expect(wiederAktiv, isEmpty,
        reason: 'Diese Modi stehen wieder im Lernpfad, sind aber als ausser '
            'Dienst gemeldet — ihre Stationen zählen dadurch nirgends. Sie '
            'gehören zurück in eine Kategorie.');
  });

  test('die Kategorien decken jede Station des Lernpfads genau einmal ab', () {
    final proModus = <LernModus, int>{};
    var gesamt = 0;
    for (final w in lernwelten) {
      for (final a in w.abschnitte) {
        for (final s in a.stationen) {
          proModus[s.modus] = (proModus[s.modus] ?? 0) + 1;
          gesamt++;
        }
      }
    }

    var summe = 0;
    final zeilen = <String>[];
    for (final k in kModusKategorien) {
      final n = k.modi.fold<int>(0, (sum, m) => sum + (proModus[m] ?? 0));
      summe += n;
      zeilen.add('${k.label.padRight(22)} $n');
    }
    // Bei einem Fehlschlag steht die Aufteilung direkt in der Ausgabe.
    printOnFailure('${zeilen.join('\n')}\n${'GESAMT'.padRight(22)} $summe '
        '(Lernpfad: $gesamt)');

    expect(summe, gesamt,
        reason: 'Die Balken zeigen zusammen nicht den ganzen Lernpfad.');
  });
}
