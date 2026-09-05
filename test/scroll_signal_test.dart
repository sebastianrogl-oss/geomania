import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/services/scroll_signal.dart';
import 'package:geomania/widgets/statistik_kacheln.dart';

/// Die Streak-Flamme steht still, solange gescrollt wird.
///
/// ══ WORUM ES GEHT ═══════════════════════════════════════════════════════
///
/// Das Lottie-Widget baut sich bei JEDEM Animationsframe neu auf — rund
/// 30-mal pro Sekunde, dauerhaft. Beim Überziehen am Listenende trifft das
/// auf den federnd verschobenen Inhalt, und das Ergebnis war auf iOS ein
/// sichtbares Zittern. Belegt mit einem Versuchs-Build: mit stehendem Bild
/// statt Animation war das Profil ruhig, sonst unverändert.
///
/// ══ WARUM DIESE TESTS SO AUSSEHEN ═══════════════════════════════════════
///
/// Ein früherer Anlauf zählte, wie oft ein NACHBAR-Widget neu gezeichnet
/// wird. Diese Messung war wertlos: Der Nachbar liegt in der Wurzelebene und
/// wird neu gezeichnet, sobald überhaupt irgendein Frame entsteht — sie
/// zeigte also nur, dass die Animation läuft, und blieb bei jeder
/// Gegenmassnahme bei derselben Zahl.
///
/// Geprüft wird deshalb der Zustand des Signals und dass die Screens es
/// setzen. Was daraus folgt — kein Ticker, keine Neubauten — steht im
/// Lottie-Paket und ist nicht Sache dieses Tests.
void main() {
  setUp(() => ScrollSignal.laeuft.value = false);

  testWidgets('Beim Ziehen an, nach dem Nachfedern wieder aus',
      (tester) async {
    final verlauf = <bool>[];
    ScrollSignal.laeuft.addListener(() => verlauf.add(ScrollSignal.laeuft.value));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScrollSignal.beobachte(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(children: [
              for (var i = 0; i < 20; i++)
                Container(height: 100, color: Colors.grey.shade200),
            ]),
          ),
        ),
      ),
    ));

    expect(ScrollSignal.laeuft.value, isFalse, reason: 'im Ruhezustand aus');

    final geste = await tester.startGesture(const Offset(200, 300));
    await geste.moveBy(const Offset(0, -60));
    await tester.pump();
    expect(ScrollSignal.laeuft.value, isTrue,
        reason: 'Während des Ziehens muss die Animation stehen');

    await geste.up();
    // Nicht pumpAndSettle: Die Flamme läuft danach weiter, der Baum kommt
    // also nie zur Ruhe.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(ScrollSignal.laeuft.value, isFalse,
        reason: 'Nach dem Nachfedern muss sie wieder laufen');

    expect(verlauf, [true, false],
        reason: 'Genau ein Wechsel hin und einer zurück — kein Flattern');
  });

  testWidgets('Das Überziehen am Ende zählt noch als Bewegung',
      (tester) async {
    // Der eigentliche Problemfall: Am Anschlag weiterziehen. Solange die
    // Feder läuft, darf die Animation nicht wieder anspringen.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScrollSignal.beobachte(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(children: [
              for (var i = 0; i < 20; i++)
                Container(height: 100, color: Colors.grey.shade200),
            ]),
          ),
        ),
      ),
    ));

    final geste = await tester.startGesture(const Offset(200, 300));
    // Nach unten ziehen, obwohl schon oben — reines Überziehen.
    for (var i = 0; i < 10; i++) {
      await geste.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 16));
      expect(ScrollSignal.laeuft.value, isTrue,
          reason: 'Beim Überziehen muss die Animation stehen');
    }
    await geste.up();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(ScrollSignal.laeuft.value, isFalse);
  });

  testWidgets('Die Meldung läuft weiter zu anderen Hörern', (tester) async {
    // Der Beobachter darf die Benachrichtigung nicht schlucken — sonst
    // bekämen andere Hörer im selben Baum sie nie zu sehen.
    var fremdeMeldungen = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NotificationListener<ScrollNotification>(
          onNotification: (_) {
            fremdeMeldungen++;
            return false;
          },
          child: ScrollSignal.beobachte(
            child: SingleChildScrollView(
              child: Column(children: [
                for (var i = 0; i < 20; i++)
                  Container(height: 100, color: Colors.grey.shade200),
              ]),
            ),
          ),
        ),
      ),
    ));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pump();
    expect(fremdeMeldungen, greaterThan(0));
  });

  test('Beide scrollenden Screens mit Flamme melden ihre Bewegung', () {
    // Ohne diese Zeilen wirkt das Signal nicht — und das fällt beim Bauen
    // nicht auf, sondern erst am Gerät.
    for (final datei in [
      'lib/screens/profil_screen.dart',
      'lib/screens/home_screen.dart',
    ]) {
      expect(File(datei).readAsStringSync().contains('ScrollSignal.beobachte'),
          isTrue,
          reason: '$datei meldet seine Scroll-Bewegung nicht');
    }
  });

  test('Die Flamme hört auf das Signal', () {
    final quelle = File('lib/widgets/streak_flamme.dart').readAsStringSync();
    expect(quelle.contains('valueListenable: ScrollSignal.laeuft'), isTrue);
    expect(quelle.contains('animate: !scrollt'), isTrue,
        reason: 'Ohne animate bleibt der Ticker laufen');
  });

  testWidgets('Die Kacheln sehen unverändert aus', (tester) async {
    // Die Flamme steht still, sie verschwindet nicht: Grösse, Zahl und
    // Beschriftungen bleiben, wie sie waren.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatistikKacheln(streak: 12, stationen: 42, abzeichen: 31),
      ),
    ));
    ScrollSignal.laeuft.value = true;
    await tester.pump();
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
  });
}
