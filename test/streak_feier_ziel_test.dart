import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/services/streak_ziel_service.dart';
import 'package:geomania/widgets/streak_feier_overlay.dart';

/// Der zweite Teil der Streak-Feier: das erreichte Ziel.
///
/// ── WARUM HIER KEIN pumpAndSettle STEHT ────────────────────────────────────
///
/// Die Feier hält eine Lottie-Flamme in einer Endlosschleife. `pumpAndSettle`
/// wartet darauf, dass keine Animation mehr läuft — das passiert hier nie, es
/// liefe in sein Zeitlimit. Deshalb wird von Hand in Schritten weitergepumpt,
/// und zwar länger, als der Ablauf braucht (rund 2,6 s bis zum zweiten Teil).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Zeigt das Overlay und läuft bis hinter den zweiten Teil.
  ///
  /// Über eine ECHTE Route, nicht als schlichtes Widget: Die Feier beendet
  /// sich mit `Navigator.pop()`. Ohne eine Route darunter liefe der Aufruf
  /// ins Leere, und ein Test aufs Schliessen wäre wertlos — er hätte
  /// bewiesen, dass etwas stehen bleibt, was gar nicht gehen konnte.
  Future<void> zeige(
    WidgetTester tester, {
    required int neuerStreak,
    int? erreichtesZiel,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (kontext) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => StreakFeierOverlay.zeigen(
                kontext,
                alterStreak: neuerStreak - 1,
                neuerStreak: neuerStreak,
                erreichtesZiel: erreichtesZiel,
              ),
              child: const Text('los'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('los'));
    await tester.pump();
    // In Schritten statt in einem Sprung: Die Ablaufkette besteht aus
    // mehreren Future.delayed, die nacheinander abgearbeitet werden wollen.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('Ohne erreichtes Ziel bleibt alles wie bisher', (tester) async {
    await zeige(tester, neuerStreak: 5);
    expect(find.text('Tippen für weiter'), findsOneWidget);
    expect(find.text('Ziel erreicht!'), findsNothing);
  });

  testWidgets('Mit erreichtem Ziel erscheint der zweite Teil', (tester) async {
    await zeige(tester, neuerStreak: 14, erreichtesZiel: 14);
    expect(find.text('Ziel erreicht!'), findsOneWidget);
    expect(find.text('14 Tage am Stück.'), findsOneWidget);
    // Kein zweites Overlay: Die Flamme und ihre Zahl stehen weiter da.
    expect(find.text('14'), findsWidgets);
  });

  testWidgets('Der Hinweis zum Wegtippen bleibt dann aus', (tester) async {
    // Sonst stünde eine Aufforderung zum Wegtippen unter einer Frage mit
    // Knöpfen — zwei widersprüchliche Anweisungen nebeneinander.
    await zeige(tester, neuerStreak: 14, erreichtesZiel: 14);
    expect(find.text('Tippen für weiter'), findsNothing);
  });

  testWidgets('Die Anschlussziele stehen zur Wahl', (tester) async {
    await zeige(tester, neuerStreak: 14, erreichtesZiel: 14);
    expect(find.text('Neues Ziel?'), findsOneWidget);
    expect(find.text('30 Tage'), findsOneWidget);
    expect(find.text('60 Tage'), findsOneWidget);
    expect(find.text('100 Tage'), findsOneWidget);
    // Und ein Ausweg, der zu nichts verpflichtet.
    expect(find.text('Kein neues Ziel'), findsOneWidget);
  });

  testWidgets('Kein Angebot unterhalb der schon laufenden Serie',
      (tester) async {
    // Ziel 7, aber die Serie steht bei 20 — jemand hat sich früh etwas
    // vorgenommen, war eine Weile weg und ist wieder eingestiegen. Ihm 14
    // Tage anzubieten hiesse, ihn am nächsten Tag sofort wieder zu feiern.
    await zeige(tester, neuerStreak: 20, erreichtesZiel: 7);
    expect(find.text('14 Tage'), findsNothing);
    expect(find.text('30 Tage'), findsOneWidget);
    expect(find.text('60 Tage'), findsOneWidget);
  });

  testWidgets('Am oberen Ende der Leiter wird nichts mehr angeboten',
      (tester) async {
    await zeige(tester, neuerStreak: 365, erreichtesZiel: 365);
    expect(find.text('Ziel erreicht!'), findsOneWidget);
    expect(find.text('Neues Ziel?'), findsNothing);
    // Statt "Kein neues Ziel" — wo nichts angeboten wird, gibt es auch nichts
    // abzulehnen.
    expect(find.text('Weiter'), findsOneWidget);
  });

  testWidgets('Ein Tipp daneben schliesst die Frage NICHT weg',
      (tester) async {
    // Der eigentliche Grund für die gesperrte Fläche: Wer eben noch "Tippen
    // für weiter" gelesen hat, tippt reflexhaft weiter — und hätte die Frage
    // nie gesehen.
    await zeige(tester, neuerStreak: 14, erreichtesZiel: 14);
    await tester.tapAt(const Offset(20, 60));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ziel erreicht!'), findsOneWidget);
  });

  testWidgets('Ein gewähltes Ziel wird gespeichert', (tester) async {
    await zeige(tester, neuerStreak: 14, erreichtesZiel: 14);
    await tester.tap(find.text('30 Tage'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(await StreakZielService.ziel(), 30);
  });

  testWidgets('Ohne erreichtes Ziel schliesst ein Tipp wie bisher',
      (tester) async {
    await zeige(tester, neuerStreak: 5);
    await tester.tapAt(const Offset(20, 60));
    // Das Ausblenden dauert _kAusblenden (300ms), danach ist die Route weg.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Tippen für weiter'), findsNothing);
  });
}
