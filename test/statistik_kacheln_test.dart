import 'package:flutter/material.dart';
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

  testWidgets('Kacheln sind quadratisch', (tester) async {
    await baue(tester, const Size(412, 915));
    for (final label in ['Streak', 'Stationen', 'Abzeichen']) {
      final kachel = find.ancestor(
          of: find.text(label), matching: find.byType(AspectRatio));
      final g = tester.getSize(kachel.first);
      expect(g.width, moreOrLessEquals(g.height, epsilon: 0.5),
          reason: 'Kachel "$label" ist ${g.width} x ${g.height}');
    }
  });

  testWidgets('die drei Beschriftungen stehen auf einer Linie', (tester) async {
    await baue(tester, const Size(412, 915));
    final oben = tester.getTopLeft(find.text('Streak')).dy;
    for (final label in ['Stationen', 'Abzeichen']) {
      expect(tester.getTopLeft(find.text(label)).dy,
          moreOrLessEquals(oben, epsilon: 0.5),
          reason: '"$label" steht nicht auf Höhe von "Streak"');
    }
  });

  testWidgets('Flamme und Münze zeigen ihre Zahl gleich groß, der Button '
      'anteilig kleiner', (tester) async {
    await baue(tester, const Size(412, 915));
    final streak = gerendert(tester, '7');
    final abzeichen = gerendert(tester, '12');
    final stationen = gerendert(tester, '128');

    expect(abzeichen, moreOrLessEquals(streak, epsilon: 0.5),
        reason: 'Streak $streak vs. Abzeichen $abzeichen');
    // Der Button ist 0.8-mal so groß wie das Grundmaß, seine Zahl ebenso.
    expect(stationen, moreOrLessEquals(streak * 0.8, epsilon: 0.6),
        reason: 'Stationen $stationen, erwartet ${streak * 0.8}');
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
}
