import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/data/spieler_titel.dart';

/// Der Titel unter dem Namen im Profil hängt an den abgeschlossenen
/// Stationen. Vorher stand dort eine fest eingetippte Zeile, die sich nie
/// änderte — der Test hält fest, dass sie es jetzt tut, und zwar an den
/// richtigen Stellen.
void main() {
  test('Die Staffel steigt lückenlos und beginnt bei 0', () {
    expect(spielerTitel.first.schwelle, 0,
        reason: 'Ohne Schwelle 0 hätte ein neuer Spieler gar keinen Titel');
    for (var i = 1; i < spielerTitel.length; i++) {
      expect(spielerTitel[i].schwelle,
          greaterThan(spielerTitel[i - 1].schwelle),
          reason: 'Stufe $i liegt nicht über der davor');
    }
  });

  test('Jede Stufe ist im Pfad überhaupt erreichbar', () {
    // Die höchste Schwelle muss unter der Gesamtzahl der Stationen liegen,
    // sonst gäbe es einen Titel, den niemand je sieht.
    final stationen =
        lernwelten.expand((w) => w.abschnitte).expand((a) => a.stationen).length;
    expect(spielerTitel.last.schwelle, lessThan(stationen),
        reason: 'Höchster Titel ab ${spielerTitel.last.schwelle}, '
            'der Pfad hat nur $stationen Stationen');
  });

  test('Der Titel wechselt genau an der Schwelle', () {
    for (final stufe in spielerTitel) {
      expect(titelFuerStationen(stufe.schwelle), stufe.titel,
          reason: 'Bei genau ${stufe.schwelle} Stationen');
      if (stufe.schwelle > 0) {
        expect(titelFuerStationen(stufe.schwelle - 1), isNot(stufe.titel),
            reason: 'Eine Station vor ${stufe.schwelle} gilt noch der alte');
      }
    }
  });

  test('Auch über der letzten Schwelle bleibt der höchste Titel stehen', () {
    expect(titelFuerStationen(100000), spielerTitel.last.titel);
  });
}
