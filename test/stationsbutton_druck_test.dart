import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/widgets/lernpfad_station_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Die Druck-Bewegung des Stationsbuttons ───────────────────────────────────
//
// Geprüft wird der Fall, an dem es lag: EIN SEHR KURZER TIPP. Aufsetzen und
// Loslassen liegen dabei fast im selben Augenblick, und vorher bekam die
// Abwärtsbewegung ihren Rückweg zugewiesen, bevor sie unten angekommen war —
// zu sehen war nur ein Wackeln.
//
// Gemessen wird die Lage des Kreises im Kasten: oben (0) heisst ungedrückt,
// unten (Sockelhöhe) heisst vollständig eingedrückt.

void main() {
  const sockel = 5.0;
  const kreis = 90.0;
  const inhaltKey = ValueKey('inhalt');

  /// Baut den Knopf und meldet die y-Lage des Kreises relativ zum Kasten.
  Future<double Function()> pumpe(WidgetTester tester,
      {VoidCallback? onTap}) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Druckbar3DButton(
            kreisGroesse: kreis,
            sockelHoehe: sockel,
            sockelFarbe: const Color(0xFF3D8B3D),
            onTap: onTap ?? () {},
            inhalt: const SizedBox(key: inhaltKey, width: kreis, height: kreis),
          ),
        ),
      ),
    ));
    final kasten = find.byType(Druckbar3DButton);
    return () =>
        tester.getTopLeft(find.byKey(inhaltKey)).dy -
        tester.getTopLeft(kasten).dy;
  }

  testWidgets('Ein sehr kurzer Tipp zeigt die Bewegung trotzdem',
      (tester) async {
    final lage = await pumpe(tester);
    expect(lage(), 0.0, reason: 'In Ruhe steht der Kreis oben');

    // Aufsetzen und im selben Moment loslassen — der kürzestmögliche Tipp.
    await tester.tap(find.byType(Druckbar3DButton));

    // Erst ein Frame ohne Zeitsprung: Er baut den gedrückten Zustand und
    // startet damit die Bewegung. Erst der nächste Frame lässt Zeit
    // vergehen — sonst misst man den Startpunkt statt der Bewegung.
    await tester.pump();

    // Nach dem Sinken muss er unten stehen. Ohne die Mindestzeit hätte hier
    // längst der Rückweg begonnen.
    await tester.pump(kSinken + const Duration(milliseconds: 5));
    expect(lage(), moreOrLessEquals(sockel, epsilon: 0.5),
        reason: 'Der Kreis erreicht den Sockel nicht — die Bewegung ist '
            'unsichtbar');

    // Und danach federt er von selbst zurück: ein Frame lässt die Mindestzeit
    // ablaufen und baut den gelösten Zustand, der nächste lässt die
    // Rückbewegung laufen.
    await tester.pump(kMindestensUnten);
    await tester.pump(kSteigen + const Duration(milliseconds: 20));
    expect(lage(), moreOrLessEquals(0.0, epsilon: 0.5),
        reason: 'Der Kreis bleibt unten stehen');
  });

  testWidgets('Die Aktion wartet nicht auf die Animation', (tester) async {
    var geloest = false;
    await pumpe(tester, onTap: () => geloest = true);

    await tester.tap(find.byType(Druckbar3DButton));
    // Kein pump dazwischen: Der Aufruf gehört zum Loslassen, nicht zum Ende
    // der Bewegung. Ein Sheet, das erst nach der Animation aufginge, fühlte
    // sich träge an.
    expect(geloest, isTrue);

    await tester.pumpAndSettle();
  });

  testWidgets('Ohne onTap bleibt der Knopf stehen', (tester) async {
    // Der gesperrte Zustand im Lernpfad und die Vorschau im Willkommens-
    // Screen zeigen denselben Knopf ohne Aktion — er darf sich dann nicht
    // eindrücken lassen.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Druckbar3DButton(
            kreisGroesse: kreis,
            sockelHoehe: sockel,
            sockelFarbe: const Color(0xFFB0AEA8),
            inhalt: const SizedBox(key: inhaltKey, width: kreis, height: kreis),
          ),
        ),
      ),
    ));
    final kasten = find.byType(Druckbar3DButton);
    double lage() =>
        tester.getTopLeft(find.byKey(inhaltKey)).dy -
        tester.getTopLeft(kasten).dy;

    await tester.tap(kasten);
    await tester.pump(kSinken + const Duration(milliseconds: 5));
    expect(lage(), 0.0);
  });

  test('Die Mindestzeit deckt die Sinkbewegung ab', () {
    // Sonst wäre der Kreis wieder auf dem Rückweg, bevor er unten war —
    // genau der Zustand, den dieser Umbau beseitigt hat.
    expect(kMindestensUnten, greaterThanOrEqualTo(kSinken));
  });
}
