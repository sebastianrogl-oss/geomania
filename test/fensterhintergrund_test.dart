import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/theme/app_theme.dart';

// ── Der Android-Fensterhintergrund ───────────────────────────────────────────
//
// Hinter der Flutter-Fläche liegt das Android-Fenster, und das hat eine eigene
// Hintergrundfarbe. Sie ist sichtbar, wo das Betriebssystem zeichnet und
// Flutter (noch) nicht: beim Start, und in dem Moment, in dem sich die Fläche
// neu einpasst — etwa wenn die Tastatur aufgeht.
//
// Voreingestellt war dort Weiss. Das ist die einzige weisse Fläche in der
// ganzen Kette und damit der einzige Kandidat für einen weissen Streifen über
// der Tastatur; in der App selbst kommt in den Eingabe-Modi kein Weiss vor.
//
// Dieser Test hält die vier Stellen mit der App-Farbe zusammen. Er liest die
// XML-Dateien im Klartext — genau so, wie Gradle sie später verarbeitet.

const _kRes = 'android/app/src/main/res';

String _lies(String pfad) => File(pfad).readAsStringSync();

void main() {
  test('colors.xml trägt genau die Farbe aus dem Flutter-Theme', () {
    final xml = _lies('$_kRes/values/colors.xml');
    final treffer =
        RegExp(r'name="geomania_hintergrund">#([0-9A-Fa-f]{6})<').firstMatch(xml);
    expect(treffer, isNotNull, reason: 'geomania_hintergrund fehlt');

    final ausXml = int.parse('FF${treffer!.group(1)!}', radix: 16);
    expect(
      ausXml,
      // ignore: deprecated_member_use
      kHintergrund.value,
      reason: 'Android-Fensterfarbe #${treffer.group(1)} weicht von '
          'kHintergrund ab — beim Start und beim Öffnen der Tastatur blitzt '
          'sie durch',
    );
  });

  group('Nichts zeigt mehr auf Weiss', () {
    const dateien = [
      '$_kRes/values/styles.xml',
      '$_kRes/values-night/styles.xml',
      '$_kRes/drawable/launch_background.xml',
      '$_kRes/drawable-v21/launch_background.xml',
    ];

    for (final d in dateien) {
      test(d.split('/').skip(4).join('/'), () {
        final xml = _lies(d);
        expect(xml, isNot(contains('@android:color/white')));
        // ?android:colorBackground ist in einem hellen System-Theme ebenfalls
        // weiss — es sieht nur nicht danach aus.
        expect(xml, isNot(contains('?android:colorBackground')));
      });
    }

    test('Der Dunkelmodus bekommt dieselbe Farbe', () {
      // Die App hat kein dunkles Thema — sie zeichnet immer hell. Bliebe hier
      // die System-Voreinstellung stehen, wäre der Streifen auf einem Handy
      // im Dunkelmodus schwarz statt weiss. Falsch ist beides.
      expect(_lies('$_kRes/values-night/styles.xml'),
          contains('@color/geomania_hintergrund'));
    });
  });
}
