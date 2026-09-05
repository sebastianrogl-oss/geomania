import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/theme/scroll_verhalten.dart';

/// Einheitliches Nachfedern.
///
/// Im Profil zitterte der Screen beim Überziehen, im Lernpfad nicht — obwohl
/// beide dieselbe Voreinstellung benutzten. Ursache war der Dehn-Effekt von
/// Android, der auf einer ruhigen Fläche wie ein Federn aussieht und
/// zwischen Karten mit Rändern und Schatten wie ein Zittern.
void main() {
  const verhalten = AppScrollVerhalten();

  testWidgets('Gefedert wird auf beiden Plattformen gleich', (tester) async {
    // Der eigentliche Punkt: NICHT die Plattform entscheidet. Auf Android
    // wäre die Voreinstellung ClampingScrollPhysics.
    late BuildContext ktx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ktx = c;
        return const SizedBox();
      }),
    ));
    expect(verhalten.getScrollPhysics(ktx), isA<BouncingScrollPhysics>());
  });

  testWidgets('Kein Leuchten und kein Dehnen obendrauf', (tester) async {
    // Beides ist die Android-Antwort auf hart stehenden Inhalt. Mit
    // federnder Physik bewegt sich der Inhalt selbst — ein Anzeiger darüber
    // wäre die zweite Antwort auf dieselbe Frage.
    late BuildContext ktx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ktx = c;
        return const SizedBox();
      }),
    ));
    const kind = SizedBox(key: ValueKey('kind'));
    final raus = verhalten.buildOverscrollIndicator(
      ktx,
      kind,
      const ScrollableDetails(direction: AxisDirection.down),
    );
    expect(identical(raus, kind), isTrue,
        reason: 'Der Anzeiger wurde nicht unterdrückt');
  });

  test('Die MaterialApp benutzt es auch', () {
    // Ohne diese Zeile wirkt die ganze Datei nicht — und das faellt beim
    // Bauen nicht auf, sondern nur am Geraet.
    final quelle = File('lib/main.dart').readAsStringSync();
    expect(quelle.contains('scrollBehavior: const AppScrollVerhalten()'),
        isTrue);
  });

  group('Ausdrücklich gesetzte Physik gewinnt weiterhin', () {
    test('unbeweglich bleibt unbeweglich', () {
      // Die inneren Seiten der Münzmappe und des Willkommens-Screens dürfen
      // nicht plötzlich mitfedern.
      final zusammen = const NeverScrollableScrollPhysics()
          .applyTo(const BouncingScrollPhysics());
      expect(zusammen.shouldAcceptUserOffset(_metrik()), isFalse);
    });

    test('die Notbremse in den Wischkarten bleibt klemmend', () {
      // Wenige Pixel Überlauf INNERHALB einer festen Karte. Ein federnder
      // Inhalt sähe dort nach Fehler aus.
      final quelle =
          File('lib/widgets/ergebnis_karten.dart').readAsStringSync();
      expect(quelle.contains('ClampingScrollPhysics'), isTrue,
          reason: 'Die Notbremse soll ausdrücklich klemmend bleiben');
    });
  });
}

ScrollMetrics _metrik() => FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 100,
      pixels: 0,
      viewportDimension: 100,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1.0,
    );
