import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/screens/ranking_game_screen.dart';

// ── Der Ländername im Ranking Quiz ───────────────────────────────────────────
//
// Er stand neben der Flagge in einer zentrierten Row ohne Flexible. Lange
// Namen liefen darüber hinaus, und Flutter malte den gelb-schwarzen
// Überlaufbalken über die Zeile.
//
// Welches Land drankommt, entscheidet der Tagesseed — ein langer Name lässt
// sich im Test nicht bestellen. Deshalb wird das Widget einzeln gebaut.
//
// Die Flagge kommt aus einem Asset, das im Test nicht geladen wird; das ist
// hier egal, weil ihr Kasten eine feste Grösse hat (72x48) und nur diese in
// die Breitenrechnung eingeht.

/// Die längsten Ländernamen der App, deutsch und englisch.
const _lang = [
  'Demokratische Republik Kongo',
  'Vereinigte Arabische Emirate',
  'Zentralafrikanische Republik',
  'Bosnien und Herzegowina',
  'Saint Vincent und die Grenadinen',
  'Democratic Republic of the Congo',
  'Saint Vincent and the Grenadines',
];

Future<void> _pump(
  WidgetTester tester,
  String name, {
  double breite = 320,
  double skala = 1.0,
}) async {
  tester.view.physicalSize = Size(breite, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(skala)),
        child: Scaffold(
          body: Padding(
            // Derselbe Seitenrand wie im Kopfbereich des Screens.
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RankingLandKopf(iso2: 'CD', name: name),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('Lange Ländernamen laufen nicht über', () {
    for (final name in _lang) {
      testWidgets('$name — 320 px', (tester) async {
        await _pump(tester, name);
        expect(tester.takeException(), isNull);
      });

      testWidgets('$name — 320 px, Skala 1.5', (tester) async {
        await _pump(tester, name, skala: 1.5);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('Ein kurzer Name bleibt einzeilig', (tester) async {
    await _pump(tester, 'Italien');
    final text = tester.widget<Text>(find.text('Italien'));
    expect(text.maxLines, 2, reason: 'die Erlaubnis gilt, der Zwang nicht');

    // Die tatsächliche Höhe zeigt, dass nur eine Zeile gesetzt wurde: Der
    // Kasten der Flagge ist 48 hoch, der Text darf ihn bei einer Zeile nicht
    // überragen.
    final hoehe = tester.getSize(find.text('Italien')).height;
    expect(hoehe, lessThan(48));
  });

  testWidgets('Ein langer Name nutzt die zweite Zeile, statt zu kürzen',
      (tester) async {
    const name = 'Demokratische Republik Kongo';
    await _pump(tester, name);
    final hoehe = tester.getSize(find.text(name)).height;
    // Zwei Zeilen à 20er Schrift sind rund 46 hoch, eine rund 23.
    expect(hoehe, greaterThan(35),
        reason: 'der Name wurde auf eine Zeile gekürzt statt umgebrochen');
  });

  testWidgets('Auf einem breiten Schirm bleibt alles wie bisher',
      (tester) async {
    await _pump(tester, 'Demokratische Republik Kongo', breite: 768);
    expect(tester.takeException(), isNull);
    final hoehe =
        tester.getSize(find.text('Demokratische Republik Kongo')).height;
    expect(hoehe, lessThan(35), reason: 'auf dem Tablet passt eine Zeile');
  });
}
