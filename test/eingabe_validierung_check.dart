import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/data/laender_aliase.dart';
import 'package:geomania/screens/station_quiz_screen.dart';

void main() {
  test('normalisiereEingabe ist case-insensitive', () {
    expect(normalisiereEingabe('Deutschland'), normalisiereEingabe('deutschland'));
    expect(normalisiereEingabe('DEUTSCHLAND'), normalisiereEingabe('deutschland'));
  });

  test('normalisiereEingabe toleriert Umlaute/Akzente', () {
    expect(normalisiereEingabe('Suedafrika'), normalisiereEingabe('Südafrika'));
    expect(normalisiereEingabe('Cote d Ivoire'), normalisiereEingabe("Côte d'Ivoire"));
    expect(normalisiereEingabe('Perou'), normalisiereEingabe('Pérou'));
  });

  test('normalisiereEingabe toleriert überflüssige Leerzeichen', () {
    expect(normalisiereEingabe('  Deutschland  '), normalisiereEingabe('Deutschland'));
    expect(normalisiereEingabe('Neu   Seeland'), normalisiereEingabe('Neu Seeland'));
  });

  test('laenderAliase: gängige alternative Schreibweisen sind hinterlegt', () {
    expect(laenderAliase['US'], contains('usa'));
    expect(laenderAliase['GB'], contains('england'));
    expect(laenderAliase['CZ'], contains('tschechei'));
  });

  test('laenderAliase-Werte sind bereits normalisiert (kein Match-Mismatch)', () {
    for (final entry in laenderAliase.entries) {
      for (final alias in entry.value) {
        expect(normalisiereEingabe(alias), alias,
            reason: '${entry.key}: Alias "$alias" ist nicht in normalisierter Form '
                '(sollte bereits klein/ohne Umlaute geschrieben sein)');
      }
    }
  });
}
