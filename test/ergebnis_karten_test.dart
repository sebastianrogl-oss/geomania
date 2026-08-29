import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/widgets/ergebnis_karten.dart';

// ── Der wischbare Kartenstapel ───────────────────────────────────────────────
//
// Die Bauform, die der Willkommens-Screen und die Ergebnis-Ansichten der vier
// Tages-Challenges sich teilen. Geprüft wird, was die Bauform zusichert:
//
//   * EINE BILDSCHIRMHÖHE JE KARTE. Jede Karte bekommt denselben Kasten, egal
//     wie viel darin steht — sonst wanderte die Punktreihe beim Wischen.
//   * DER FERTIG-KNOPF IST IMMER DA, nicht erst auf der letzten Karte.
//   * KEIN ÜBERLAUF auf 320x480 bei Schriftskala 1.5.

const _kEng = Size(320, 480);

Future<void> _pump(
  WidgetTester tester, {
  required int anzahl,
  required Widget Function(BuildContext, double) karte,
  Size groesse = _kEng,
  double skala = 1.0,
}) async {
  tester.view.physicalSize = groesse;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        // fromView + copyWith, NICHT MediaQueryData(textScaler:) — das
        // ersetzte die ganze MediaQuery und die Bildschirmgrösse fiele auf 0.
        data: MediaQueryData.fromView(tester.view)
            .copyWith(textScaler: TextScaler.linear(skala)),
        child: Scaffold(
          body: WischKartenStapel(
            karten: [for (var i = 0; i < anzahl; i++) karte],
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

/// Eine Karte mit [zeilen] gleichartigen Zeilen — stellvertretend für die
/// Runden-Zeilen einer Challenge.
Widget Function(BuildContext, double) _zeilenKarte(int zeilen) =>
    (context, hoehe) => WischKarte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Runden 1–5',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (var i = 0; i < zeilen; i++)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF4A9E4A)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Deutschland vs Frankreich',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        );

void main() {
  testWidgets('Alle Karten bekommen denselben Kasten', (tester) async {
    final hoehen = <double>[];
    await _pump(
      tester,
      anzahl: 3,
      karte: (context, hoehe) {
        hoehen.add(hoehe);
        return const WischKarte(child: SizedBox.shrink());
      },
    );
    // Der PageView baut zunächst nur die sichtbare Seite. Also einmal
    // weiterwischen, damit auch die zweite gemessen wird.
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(hoehen.length, greaterThanOrEqualTo(2),
        reason: 'es wurde nur eine Karte gebaut: $hoehen');
    expect(hoehen.toSet().length, 1,
        reason: 'unterschiedliche Kartenhöhen: $hoehen');
  });

  testWidgets('Was unter dem Stapel steht, bleibt beim Wischen stehen',
      (tester) async {
    // Der Stapel bringt selbst KEINEN Abschluss-Knopf mit — er ersetzt nur
    // eine gescrollte Liste innerhalb einer Ansicht. Der Fertig-Knopf gehört
    // dem Aufrufer, steht ausserhalb des PageView und ist damit ab der ersten
    // Karte erreichbar.
    var getippt = false;
    tester.view.physicalSize = _kEng;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: WischKartenStapel(
                karten: [
                  for (var i = 0; i < 5; i++)
                    (context, hoehe) =>
                        const WischKarte(child: SizedBox.shrink()),
                ],
              ),
            ),
            TextButton(
              onPressed: () => getippt = true,
              child: const Text('Fertig'),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Fertig'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Fertig'), findsOneWidget,
        reason: 'er darf beim Wischen nicht mitwandern');
    await tester.tap(find.text('Fertig'));
    expect(getippt, isTrue);
  });

  testWidgets('Die Punktreihe zeigt so viele Punkte wie Karten',
      (tester) async {
    await _pump(
      tester,
      anzahl: 7,
      karte: (context, hoehe) => const WischKarte(child: SizedBox.shrink()),
    );
    final reihe = tester.widget<WischPunktreihe>(find.byType(WischPunktreihe));
    expect(reihe.anzahl, 7);
    expect(reihe.aktiv, 0);
  });

  group('Kein Überlauf auf 320x480', () {
    for (final skala in [1.0, 1.5]) {
      testWidgets('Skala $skala — so viele Zeilen, wie die Rechnung erlaubt',
          (tester) async {
        // Erst die Zahl holen, mit der die Challenges rechnen …
        late int proKarte;
        tester.view.physicalSize = _kEng;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQueryData.fromView(tester.view)
                  .copyWith(textScaler: TextScaler.linear(skala)),
              child: Builder(builder: (c) {
                proKarte = wischZeilenProKarte(c, zeilenHoehe: 46);
                return const SizedBox.shrink();
              }),
            ),
          ),
        ));

        // … und dann eine Karte mit genau so vielen Zeilen bauen.
        await _pump(
          tester,
          anzahl: 3,
          karte: _zeilenKarte(proKarte),
          skala: skala,
        );
        expect(tester.takeException(), isNull,
            reason: '$proKarte Zeilen laufen bei Skala $skala über');
      });
    }

    testWidgets('Die Rechnung geht nie unter zwei Zeilen', (tester) async {
      // Auch auf einem sehr kleinen Schirm bei sehr grosser Schrift: Eine
      // Karte mit einer einzigen Zeile wäre kein Stapel mehr, sondern eine
      // Diashow.
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      late int proKarte;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQueryData.fromView(tester.view)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: Builder(builder: (c) {
              proKarte = wischZeilenProKarte(c, zeilenHoehe: 46);
              return const SizedBox.shrink();
            }),
          ),
        ),
      ));
      expect(proKarte, greaterThanOrEqualTo(2));
    });
  });
}
