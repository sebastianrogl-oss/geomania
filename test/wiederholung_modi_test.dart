import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/data/lernpfad_data.dart';

// ── Wer kommt in die Wiederholungsrunde? ─────────────────────────────────────
//
// Die Wiederholungsrunde am Ende eines Abschnitts legt falsch beantwortete
// Fragen noch einmal vor. Das lohnt nur bei Fakten, die man auswendig lernt:
// Flagge, Umriss, Hauptstadt. Wer eine Einwohnerzahl daneben geschätzt hat,
// lernt nichts daraus, dieselbe Schätzfrage gleich noch einmal zu sehen.
//
// Dieser Test hält die Zuordnung für JEDEN Modus fest. Ein neuer Modus taucht
// hier zwangsläufig auf und muss bewusst einsortiert werden.

void main() {
  test('Nur Flagge, Umriss und Hauptstadt werden wiederholt', () {
    expect(kModiMitWiederholung, {
      LernModus.flaggenQuizBild,
      LernModus.flaggenQuizMultiple,
      LernModus.flaggenQuizEingabe,
      LernModus.umrissBild,
      LernModus.umrissMultiple,
      LernModus.umrissEingabe,
      LernModus.hauptstaedteMultiple,
      LernModus.hauptstaedteEingabe,
    });
  });

  test('Jeder Modus steht auf genau einer Seite', () {
    for (final m in LernModus.values) {
      final mit = kModiMitWiederholung.contains(m);
      final ohne = kOhneWiederholung.contains(m);
      expect(mit != ohne, isTrue,
          reason: '${m.name} steht auf beiden Seiten oder auf keiner');
    }
    expect(kModiMitWiederholung.length + kOhneWiederholung.length,
        LernModus.values.length);
  });

  test('Ein neuer Modus landet ohne Zutun bei "keine Wiederholung"', () {
    // Die Sperre wird aus der Positiv-Liste abgeleitet. Damit ist die
    // Wiederholung eine bewusste Entscheidung, kein Versehen.
    final erwartetOhne = LernModus.values
        .where((m) => !kModiMitWiederholung.contains(m))
        .toSet();
    expect(kOhneWiederholung, erwartetOhne);
  });

  group('Die Modi, die frisch dazugekommen sind', () {
    // Sie liefen bis eben in die Wiederholung. Der Test nennt sie einzeln,
    // damit ein versehentliches Zurückrutschen auffällt.
    const neuOhne = [
      LernModus.waehrungsQuiz,
      LernModus.waehrungZuLand,
      LernModus.nachbarland,
      LernModus.wirtschaftssektoren,
      LernModus.bekanntesGebaeude,
      LernModus.sortierSpiel,
      LernModus.preisSchaetzen,
      LernModus.bipGesamt,
      LernModus.flaeche,
      LernModus.extremFrage,
      LernModus.extremFrageLeicht,
      LernModus.zufallsFakt,
      LernModus.grenzkettenRaetsel,
    ];
    for (final m in neuOhne) {
      test(m.name, () => expect(kOhneWiederholung.contains(m), isTrue));
    }
  });

  group('Die fünf, die schon vorher ausgenommen waren', () {
    const schonOhne = [
      LernModus.flaechenVergleich,
      LernModus.zweiWahrheiten,
      LernModus.wasGehoertNichtDazu,
      LernModus.laenderRanking,
      LernModus.nachbarschaftsKette,
    ];
    for (final m in schonOhne) {
      test(m.name, () => expect(kOhneWiederholung.contains(m), isTrue));
    }
  });
}
