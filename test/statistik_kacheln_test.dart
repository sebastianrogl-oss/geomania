import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/widgets/statistik_kacheln.dart';

/// Die drei Profil-Kacheln trugen ihre Zahlen einmal mit derselben
/// Schriftgröße — und zeigten sie trotzdem in drei verschiedenen Größen.
/// Ursache war die FittedBox um jedes Element: Flamme (Box 181), Münze (107)
/// und Button (82) standen in einer nur rund 88 px breiten Kachel und wurden
/// unterschiedlich stark heruntergerechnet, samt der Zahl darin.
///
/// Seitdem sind die Elemente bewusst verschieden groß (Button × 0.8, Münze
/// × 1.16, Flamme × 1.2 des gemeinsamen Grundmaßes). Was NICHT wieder
/// passieren darf, ist eine Größe, die erst beim Zeichnen entsteht: die Tests
/// messen deshalb, was am Ende auf dem Schirm steht — Layout-Größe mal
/// Skalierung aller Vorfahren.
void main() {
  setUpAll(() async {
    // Ohne echte Schrift misst der Test daneben: die Ersatzschrift des
    // Test-Bindings setzt JEDE Ziffer 1 em breit, dreistellige Zahlen wären
    // damit rund 40 % breiter als in Poppins und würden von der Notnagel-
    // FittedBox verkleinert — ein Fehlalarm, den es auf dem Gerät nicht gibt.
    TestWidgetsFlutterBinding.ensureInitialized();
    final schrift = FontLoader('Poppins')
      ..addFont(rootBundle.load('fonts/Poppins-Bold.ttf'))
      ..addFont(rootBundle.load('fonts/Poppins-Regular.ttf'));
    await schrift.load();
  });

  /// Gerenderte Höhe eines Texts — Layout-Höhe mal Skalierung der Vorfahren.
  double gerendert(WidgetTester tester, String text) {
    final box = tester.renderObject<RenderBox>(find.text(text));
    return box.size.height * box.getTransformTo(null).storage[0];
  }

  /// Skalierung, die auf einem Text liegt. 1.0 = nichts wurde nachträglich
  /// verkleinert.
  double skalierung(WidgetTester tester, String text) =>
      tester.renderObject<RenderBox>(find.text(text)).getTransformTo(null).storage[0];

  Future<void> baue(WidgetTester tester, Size schirm,
      {int streak = 7, int stationen = 128, int abzeichen = 12}) async {
    await tester.binding.setSurfaceSize(schirm);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          // Seitenränder wie im Profil-Screen.
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: StatistikKacheln(
              streak: streak, stationen: stationen, abzeichen: abzeichen),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Breite EINER Kachel: die Reihe abzüglich der beiden Abstände, durch drei.
  double kachelBreite(WidgetTester tester) =>
      (tester.getSize(find.byType(StatistikKacheln)).width - 2 * 8) / 3;

  testWidgets('Kacheln sind quadratisch bei normaler Schrift', (tester) async {
    await baue(tester, const Size(412, 915));
    final hoehe = tester.getSize(find.byType(StatistikKacheln)).height;
    expect(kachelBreite(tester), moreOrLessEquals(hoehe, epsilon: 0.5),
        reason: 'Kachel ist ${kachelBreite(tester)} breit und $hoehe hoch');
  });

  /// Die Grafik hängt an der Kachelbreite und ist von der Systemschrift
  /// unabhängig; die Beschriftung darunter wächst mit ihr. Bei Schriftskala 1
  /// blieben nach der letzten Größenanpassung rechnerisch 0,2 px übrig — jede
  /// größere Systemschrift lief deshalb unten aus der Kachel heraus, auf
  /// 412 px bei Skala 1.5 um 5,8 px.
  ///
  /// Weil die Größenverhältnisse von Grafik und Beschriftung bewusst so
  /// gewählt sind, darf die Lösung KEINE davon stauchen: Stattdessen wächst
  /// die Kachel. Quadratisch bleibt sie damit nur bei Skala 1.0 — darüber
  /// wird sie genau so viel höher, wie die Beschriftung an Höhe gewinnt.
  for (final skala in [1.3, 1.5]) {
    testWidgets('kein Überlauf bei Schriftskala $skala', (tester) async {
      final fehler = <FlutterErrorDetails>[];
      final vorher = FlutterError.onError;
      FlutterError.onError = fehler.add;
      late double breite;
      late double hoehe;
      try {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          builder: (kontext, kind) => MediaQuery(
            data: MediaQuery.of(kontext)
                .copyWith(textScaler: TextScaler.linear(skala)),
            child: kind!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: StatistikKacheln(
                  streak: 7, stationen: 128, abzeichen: 12),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        breite = kachelBreite(tester);
        hoehe = tester.getSize(find.byType(StatistikKacheln)).height;
      } finally {
        // Vor jedem expect zurücksetzen, sonst verschluckt die eigene
        // Fehlerliste den Fehlschlag.
        FlutterError.onError = vorher;
      }
      expect(fehler.map((f) => f.exception.toString()), isEmpty);
      // Gewachsen, nicht geschrumpft.
      expect(hoehe, greaterThanOrEqualTo(breite - 0.5));
    });
  }

  testWidgets('die drei Beschriftungen stehen auf einer Linie', (tester) async {
    await baue(tester, const Size(412, 915));
    final oben = tester.getTopLeft(find.text('Streak')).dy;
    for (final label in ['Stationen', 'Abzeichen']) {
      expect(tester.getTopLeft(find.text(label)).dy,
          moreOrLessEquals(oben, epsilon: 0.5),
          reason: '"$label" steht nicht auf Höhe von "Streak"');
    }
  });

  testWidgets('bei GLEICHER Stellenzahl sind alle drei Zahlen gleich groß',
      (tester) async {
    // Die Zahl im Stationsbutton war zwischenzeitlich absichtlich kleiner
    // (0.8 wie der Button selbst). Jetzt gilt für alle drei dieselbe Größe —
    // solange sie gleich viele Stellen haben. Unterschiedlich groß dürfen sie
    // nur durch die Stellen-Staffel werden, nie durch die Grafik dahinter.
    await baue(tester, const Size(412, 915),
        streak: 7, stationen: 8, abzeichen: 9);
    final streak = gerendert(tester, '7');
    final stationen = gerendert(tester, '8');
    final abzeichen = gerendert(tester, '9');

    expect(abzeichen, moreOrLessEquals(streak, epsilon: 0.5),
        reason: 'Streak $streak vs. Abzeichen $abzeichen');
    expect(stationen, moreOrLessEquals(streak, epsilon: 0.5),
        reason: 'Streak $streak vs. Stationen $stationen');
  });

  /// ── Die Stellen-Staffel ───────────────────────────────────────────────
  ///
  /// Je mehr Ziffern, desto breiter die Zeile — und desto näher rückt sie an
  /// den Rand ihrer Grafik. Die drei Grafiken vertragen dabei verschieden
  /// viel, deshalb zwei Staffeln (siehe statistik_kacheln.dart).
  ///
  /// Gemessen wird die GERENDERTE Höhe: Sie folgt der Schriftgröße, und genau
  /// dort greift die Staffel. Eine nachträgliche Stauchung durch die FittedBox
  /// würde der Test daneben (»keine Zahl wird nachträglich verkleinert«)
  /// abfangen.

  testWidgets('Die Flamme schrumpft ab der zweiten und ab der dritten Stelle',
      (tester) async {
    // Stationen und Abzeichen bekommen Werte, die mit keiner Streak-Zahl
    // zusammenfallen — sonst findet der Text-Finder zwei Treffer.
    await baue(tester, const Size(412, 915),
        streak: 7, stationen: 555, abzeichen: 44);
    final eine = gerendert(tester, '7');
    await baue(tester, const Size(412, 915),
        streak: 12, stationen: 555, abzeichen: 44);
    final zwei = gerendert(tester, '12');
    await baue(tester, const Size(412, 915),
        streak: 128, stationen: 555, abzeichen: 44);
    final drei = gerendert(tester, '128');

    expect(zwei, lessThan(eine),
        reason: 'zweistellig ($zwei) ist nicht kleiner als einstellig ($eine)');
    expect(drei, lessThan(zwei),
        reason: 'dreistellig ($drei) ist nicht kleiner als zweistellig ($zwei)');
  });

  testWidgets('Stationen und Abzeichen schrumpfen erst ab der dritten Stelle',
      (tester) async {
    // Geprüft am Stationsbutton; die Münze nutzt dieselbe Staffel.
    await baue(tester, const Size(412, 915),
        streak: 7, stationen: 8, abzeichen: 44);
    final eineStation = gerendert(tester, '8');
    await baue(tester, const Size(412, 915),
        streak: 7, stationen: 88, abzeichen: 44);
    final zweiStellen = gerendert(tester, '88');
    await baue(tester, const Size(412, 915),
        streak: 7, stationen: 888, abzeichen: 44);
    final dreiStellen = gerendert(tester, '888');

    // Zwei Ziffern stehen in den runden Flächen bequem — hier ändert sich
    // nichts, anders als bei der Flamme.
    expect(zweiStellen, moreOrLessEquals(eineStation, epsilon: 0.5),
        reason: 'zweistellig ($zweiStellen) vs. einstellig ($eineStation)');
    expect(dreiStellen, lessThan(zweiStellen),
        reason: 'dreistellig ($dreiStellen) ist nicht kleiner');
  });

  testWidgets('keine Zahl wird nachträglich verkleinert — ein-, zwei- und '
      'dreistellig', (tester) async {
    for (final werte in [
      (1, 9, 3),
      (12, 99, 30),
      (365, 594, 100),
    ]) {
      await baue(tester, const Size(412, 915),
          streak: werte.$1, stationen: werte.$2, abzeichen: werte.$3);
      for (final zahl in [werte.$1, werte.$2, werte.$3]) {
        expect(skalierung(tester, '$zahl'), moreOrLessEquals(1.0, epsilon: 0.01),
            reason: '"$zahl" wird gestaucht');
      }
    }
  });

  testWidgets('kein Überlauf auf schmalen Geräten', (tester) async {
    await baue(tester, const Size(320, 568));
    expect(tester.takeException(), isNull);
  });

  /// Die HÖHE wuchs mit der Systemschrift, die BREITE der Kachel nicht — und
  /// "Stationen" wie "Abzeichen" standen bei Skala 1.3 schon breiter da, als
  /// die Kachel ist. Abgeschnitten wurde stillschweigend: `maxLines: 1` ohne
  /// `overflow` schneidet hart ab, ohne Überlauf-Streifen und ohne Meldung im
  /// Log. Auf dem Gerät stand dort "Stationei".
  ///
  /// Geprüft wird deshalb nicht auf eine Fehlermeldung, sondern nachgemessen:
  /// Was der Text bräuchte, gegen das, was er bekommen hat.
  for (final skala in [1.0, 1.3, 1.5, 2.0]) {
    for (final breite in [320.0, 360.0, 412.0]) {
      testWidgets(
          'keine Beschriftung wird abgeschnitten — '
          '${breite.toInt()} px, Skala $skala', (tester) async {
        await tester.binding.setSurfaceSize(Size(breite, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          builder: (kontext, kind) => MediaQuery(
            data: MediaQuery.of(kontext)
                .copyWith(textScaler: TextScaler.linear(skala)),
            child: kind!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child:
                  StatistikKacheln(streak: 7, stationen: 128, abzeichen: 12),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 300));

        for (final label in ['Streak', 'Stationen', 'Abzeichen']) {
          final absatz = tester.renderObject<RenderParagraph>(find.text(label));
          expect(absatz.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(absatz.size.width + 0.5),
              reason: '"$label" wird abgeschnitten');
        }
      });
    }
  }
}
