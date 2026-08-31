import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/widgets/statistik_kacheln.dart';

/// Die drei Statistik-Kacheln im Profil.
///
/// Das Streak-Ziel stand hier einmal als eigene Zeile mit Balken drin. Es ist
/// wieder heraus — die Kachel ist eine Kennzahl auf einen Blick, das Ziel
/// steht in der Erklärung, die ein Tipp öffnet (siehe
/// streak_erklaerung_ziel_test.dart).
///
/// Der Test hält beides fest: dass die Kachel wieder schlicht ist, UND dass
/// die Höhenrechnung dadurch wieder stimmt. Die Ziel-Zeile hatte in allen drei
/// Kacheln Platz reserviert; bleibt davon ein Rest stehen, stünden die
/// Beschriftungen nicht mehr auf einer Kante.
void main() {
  /// Baut die Kacheln und liefert die dabei gemeldeten Layout-Fehler.
  ///
  /// Über [FlutterError.onError] gesammelt statt über `takeException` —
  /// dasselbe Muster wie in willkommen_screen_test.dart. Der Unterschied ist
  /// nicht kosmetisch: `takeException` gibt nur den ERSTEN Fehler heraus, und
  /// ein Überlauf, der erst nach einem anderen auftritt, bliebe unsichtbar.
  Future<List<String>> baue(
    WidgetTester tester, {
    int streak = 3,
    int stationen = 42,
    int abzeichen = 7,
    VoidCallback? onStreakTipp,
    Size groesse = const Size(412, 915),
    double skala = 1.0,
  }) async {
    final fehler = <String>[];
    final vorher = FlutterError.onError;
    FlutterError.onError = (details) => fehler.add(details.exceptionAsString());
    try {
      await tester.binding.setSurfaceSize(groesse);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: groesse,
              textScaler: TextScaler.linear(skala),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: StatistikKacheln(
                  streak: streak,
                  stationen: stationen,
                  abzeichen: abzeichen,
                  onStreakTipp: onStreakTipp,
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      FlutterError.onError = vorher;
    }
    return fehler;
  }

  /// Die Höhe einer Kachel, über ihre Beschriftung gefunden. Der nächste
  /// Container-Vorfahr eines Etiketts IST die Kachel.
  double kachelHoehe(WidgetTester tester, String label) => tester
      .getSize(find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first)
      .height;

  /// Die Unterkante der Beschriftung — daran hängt der sichtbare Eindruck.
  double labelKante(WidgetTester tester, String label) =>
      tester.getBottomLeft(find.text(label)).dy;

  const labels = ['Streak', 'Stationen', 'Abzeichen'];

  testWidgets('Die Kachel zeigt kein Ziel mehr', (tester) async {
    await baue(tester, streak: 3);
    // Weder "3/14" noch irgendein anderer Bruch.
    expect(find.textContaining('/'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('Die drei Kacheln sind gleich hoch', (tester) async {
    await baue(tester);
    final hoehen = [for (final l in labels) kachelHoehe(tester, l)];
    expect(hoehen[0], closeTo(hoehen[1], 0.01));
    expect(hoehen[1], closeTo(hoehen[2], 0.01));
  });

  testWidgets('Vom reservierten Ziel-Platz ist nichts übrig', (tester) async {
    // Die Kachel ist bei Schriftskala 1 im Wesentlichen quadratisch (siehe
    // _kSeitenverhaeltnis). NICHT auf den Pixel genau: Die gemessene
    // Beschriftung überragt das Quadrat um rund einen Viertelpixel, und die
    // Kachel wächst dann mit — so war es auch vor dem Ziel-Versuch, der
    // Vergleich mit dem letzten Commit bestätigt es.
    //
    // Die Grenze liegt deshalb grosszügig bei zwei Pixeln. Sie hat trotzdem
    // Zähne: Eine reservierte Ziel-Zeile war rund 14 px hoch — ein Rest davon
    // fiele hier sofort durch.
    await baue(tester);
    final breite = tester
        .getSize(find
            .ancestor(of: find.text('Streak'), matching: find.byType(Container))
            .first)
        .width;
    expect(kachelHoehe(tester, 'Streak'), lessThan(breite + 2));
  });

  testWidgets('Die drei Beschriftungen stehen auf einer Linie', (tester) async {
    await baue(tester);
    final kanten = [for (final l in labels) labelKante(tester, l)];
    expect(kanten[0], closeTo(kanten[1], 0.01));
    expect(kanten[1], closeTo(kanten[2], 0.01));
  });

  group('Der Tipp auf die Streak-Kachel', () {
    testWidgets('löst die Erklärung aus', (tester) async {
      var getippt = 0;
      await baue(tester, onStreakTipp: () => getippt++);
      await tester.tap(find.text('Streak'));
      expect(getippt, 1);
    });

    testWidgets('greift auf der ganzen Kachel, nicht nur auf der Schrift',
        (tester) async {
      // Auch die Flamme darüber und die Lücken dazwischen — eine Zeile Text
      // wäre ein zu kleines Ziel für einen Finger.
      var getippt = 0;
      await baue(tester, onStreakTipp: () => getippt++);
      final kachel = find
          .ancestor(of: find.text('Streak'), matching: find.byType(Container))
          .first;
      await tester.tapAt(tester.getCenter(kachel));
      expect(getippt, 1);
    });

    testWidgets('die anderen beiden Kacheln reagieren nicht', (tester) async {
      // Nur zur Serie gibt es etwas zu erklären. Ein Tipp auf "Stationen"
      // darf nicht die Serien-Erklärung öffnen.
      var getippt = 0;
      await baue(tester, onStreakTipp: () => getippt++);
      await tester.tap(find.text('Stationen'));
      await tester.tap(find.text('Abzeichen'));
      expect(getippt, 0);
    });

    testWidgets('ohne Rückruf ist die Kachel nicht antippbar', (tester) async {
      await baue(tester);
      await tester.tap(find.text('Streak'));
      expect(tester.takeException(), isNull);
    });
  });

  // Kein Überlauf — über die Grössen und Schriftskalen, an denen die Kacheln
  // schon einmal angelaufen sind, mit dreistelligen Zahlen in allen dreien.
  for (final (name, groesse) in const [
    ('320x480 (sehr klein)', Size(320, 480)),
    ('360x640 (verbreitetes Android)', Size(360, 640)),
    ('412x915 (aktuelles Handy)', Size(412, 915)),
    ('768x1024 (Tablet)', Size(768, 1024)),
  ]) {
    for (final skala in const [1.0, 1.3, 1.5]) {
      testWidgets('kein Überlauf: $name, Skala $skala, dreistellig',
          (tester) async {
        final fehler = await baue(tester,
            streak: 365,
            stationen: 593,
            abzeichen: 120,
            groesse: groesse,
            skala: skala);
        expect(fehler, isEmpty,
            reason: 'Layout läuft über: ${fehler.take(2).join(" | ")}');
      });
    }
  }
}
