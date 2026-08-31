import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/services/streak_ziel_service.dart';
import 'package:geomania/widgets/kennzahl_erklaerung.dart';

/// Der Ziel-Bereich in der Serien-Erklärung.
///
/// Er ersetzt die Zeile, die kurzzeitig in der Profil-Kachel stand. Geprüft
/// wird vor allem, WANN er erscheint: Drei Zustände der Zielabfrage führen zu
/// drei verschiedenen Antworten, und der mittlere — "noch offen" — ist der,
/// den man leicht falsch macht.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> oeffne(
    WidgetTester tester, {
    required int streak,
    VoidCallback? onZielSetzen,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (kontext) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => zeigeStreakErklaerung(
                kontext,
                streak: streak,
                onZielSetzen: onZielSetzen,
              ),
              child: const Text('los'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('los'));
    // Die Erklärung liest das Ziel selbst aus den Einstellungen — der Dialog
    // erscheint deshalb erst nach dem nächsten Durchlauf.
    await tester.pumpAndSettle();
  }

  testWidgets('Die Erklärung selbst steht unverändert da', (tester) async {
    await oeffne(tester, streak: 3);
    expect(find.text('Deine Serie'), findsOneWidget);
    expect(find.text('Alles klar'), findsOneWidget);
  });

  group('Ziel gesetzt', () {
    testWidgets('Balken und Fortschritt erscheinen', (tester) async {
      await StreakZielService.setzeZiel(14);
      await oeffne(tester, streak: 3);

      expect(find.text('Dein Ziel'), findsOneWidget);
      expect(find.text('3/14'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Noch 11 Tage bis zu deinem Ziel von 14 Tagen.'),
          findsOneWidget);
    });

    testWidgets('der Balken zeigt den Anteil', (tester) async {
      await StreakZielService.setzeZiel(14);
      await oeffne(tester, streak: 7);
      final balken = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(balken.value, closeTo(0.5, 0.001));
    });

    testWidgets('über dem Ziel: echter Wert, voller Balken', (tester) async {
      await StreakZielService.setzeZiel(14);
      await oeffne(tester, streak: 20);

      // "20/14" liest sich als "darüber". Ein bei 14 angehaltener Zähler sähe
      // aus wie ein Fehler.
      expect(find.text('20/14'), findsOneWidget);
      expect(find.text('Geschafft — 14 Tage am Stück.'), findsOneWidget);
      final balken = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(balken.value, 1.0);
    });

    testWidgets('genau auf dem Ziel gilt schon als geschafft', (tester) async {
      await StreakZielService.setzeZiel(7);
      await oeffne(tester, streak: 7);
      expect(find.text('Geschafft — 7 Tage am Stück.'), findsOneWidget);
    });
  });

  group('Kein Ziel', () {
    testWidgets('solange die Frage noch aussteht: gar nichts', (tester) async {
      // Der Fall, den man leicht falsch macht. Die App fragt nach ein paar
      // Stationen von sich aus; hier schon einen Hinweis zu setzen hiesse,
      // dieselbe Frage zweimal zu stellen.
      await oeffne(tester, streak: 3, onZielSetzen: () {});
      expect(find.text('Dein Ziel'), findsNothing);
      expect(find.text('Ziel setzen'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('nach einmal "Später" immer noch nichts', (tester) async {
      // Ein zweites Angebot kommt automatisch — auch hier nicht vorgreifen.
      await StreakZielService.vertagt();
      await oeffne(tester, streak: 3, onZielSetzen: () {});
      expect(find.text('Ziel setzen'), findsNothing);
    });

    testWidgets('nach zweimal "Später" gibt es einen Weg zurück',
        (tester) async {
      // Jetzt fragt die App nie wieder von selbst. Ohne diesen Weg käme man
      // an ein Ziel gar nicht mehr heran.
      await StreakZielService.vertagt();
      await StreakZielService.vertagt();
      expect(await StreakZielService.stand(), ZielStand.erledigt);

      await oeffne(tester, streak: 3, onZielSetzen: () {});
      expect(find.text('Ziel setzen'), findsOneWidget);
    });

    testWidgets('der Weg zurück löst aus', (tester) async {
      await StreakZielService.vertagt();
      await StreakZielService.vertagt();
      var getippt = 0;
      await oeffne(tester, streak: 3, onZielSetzen: () => getippt++);
      await tester.tap(find.text('Ziel setzen'));
      expect(getippt, 1);
    });

    testWidgets('der Weg zurück schliesst NUR den Dialog', (tester) async {
      // Der Dialog liegt in einem GestureDetector, der bei jedem Tipp
      // daneben schliesst. Löste der beim Tipp auf "Ziel setzen" mit aus,
      // würde zweimal geschlossen: einmal der Dialog und einmal der Screen
      // darunter — im Profil flöge man dabei aus dem Profil heraus.
      //
      // Der Rückruf hier macht genau das, was der echte macht: Er schliesst
      // den Dialog. Bleibt der Screen darunter stehen, hat nur einer der
      // beiden Erkenner ausgelöst.
      await StreakZielService.vertagt();
      await StreakZielService.vertagt();
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (kontext) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => zeigeStreakErklaerung(
                  kontext,
                  streak: 3,
                  onZielSetzen: () => Navigator.of(kontext).pop(),
                ),
                child: const Text('los'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      expect(find.text('Ziel setzen'), findsOneWidget);

      await tester.tap(find.text('Ziel setzen'));
      await tester.pumpAndSettle();

      expect(find.text('Deine Serie'), findsNothing, reason: 'Dialog ist zu');
      expect(find.text('los'), findsOneWidget, reason: 'Screen steht noch');
    });

    testWidgets('ohne Rückruf wird auch nichts angeboten', (tester) async {
      // Ein Angebot, hinter dem nichts passiert, wäre schlechter als keines.
      await StreakZielService.vertagt();
      await StreakZielService.vertagt();
      await oeffne(tester, streak: 3);
      expect(find.text('Ziel setzen'), findsNothing);
    });
  });

  testWidgets('Kein Überlauf bei kleinem Schirm und grosser Schrift',
      (tester) async {
    // Der Dialog hat einen Rollbereich; der Ziel-Bereich steht bewusst darin
    // und nicht darunter, damit er den Knopf nicht aus dem Bild schiebt.
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await StreakZielService.setzeZiel(365);

    final fehler = <String>[];
    final vorher = FlutterError.onError;
    FlutterError.onError = (details) => fehler.add(details.exceptionAsString());
    try {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Builder(
            builder: (kontext) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () =>
                      zeigeStreakErklaerung(kontext, streak: 100),
                  child: const Text('los'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = vorher;
    }
    expect(fehler, isEmpty,
        reason: 'Layout läuft über: ${fehler.take(2).join(" | ")}');
    expect(find.text('100/365'), findsOneWidget);
  });
}
