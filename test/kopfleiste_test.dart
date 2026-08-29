import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/screens/home_screen.dart';
import 'package:geomania/theme/app_theme.dart';
import 'package:geomania/widgets/streak_flamme.dart';

/// Die grüne Kopfleiste des Lernpfads trägt vier Zeichen: Welt-Emoji,
/// Flamme mit Serie, Stern mit Punktestand, Profilbild.
///
/// Flamme und Stern gehören zusammen und stehen deshalb als PAAR in der
/// Mitte — vorher waren alle vier gleichmäßig über die Leiste verteilt, und
/// die beiden lasen sich dadurch als Einzelposten.
///
/// Mittig heisst: in der Mitte der LEISTE, nicht in der Mitte des Restplatzes
/// zwischen Emoji und Profilbild. Beide Aussenzeichen belegen dafür eine
/// gleich breite Fläche; ohne die sässe das Paar um die halbe Differenz
/// (Profilbild 44, Emoji gut 22) nach links versetzt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Höhe der grünen Leiste (siehe `_GreenHeader`). Alles darüber gehört zu
  /// ihr — der Lernpfad darunter trägt dieselben Zeichen noch einmal (Sterne
  /// an den Stationen, Flammen in der Deko), deshalb wird hier gefiltert.
  const kopfHoehe = 56.0;

  Future<void> baue(WidgetTester tester, Size schirm) async {
    SharedPreferences.setMockInitialValues({
      'lp_streak': 7,
      'lp_gesamt_richtig': 128,
    });
    tester.view.physicalSize = schirm;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: const HomeScreen(),
    ));
    // Statt pumpAndSettle in kleinen Schritten: Der Pulsier-Ring der aktiven
    // Station läuft dauerhaft, ein pumpAndSettle liefe in die
    // Zeitüberschreitung — und die Scroll-Animation zur aktuellen Station
    // braucht ihre 100 ms Vorlauf plus 800 ms Lauf (siehe
    // pfad_oberkante_test.dart).
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Das gesuchte Zeichen IN der Kopfleiste — das erste, dessen Oberkante
  /// noch in den oberen [kopfHoehe] Pixeln liegt.
  Rect imKopf(WidgetTester tester, Finder finder, String was) {
    for (final element in finder.evaluate()) {
      final box = element.renderObject as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.top < kopfHoehe) return rect;
    }
    fail('"$was" steht nicht in der Kopfleiste');
  }

  for (final breite in [320.0, 360.0, 412.0]) {
    testWidgets('Flamme und Stern stehen mittig — ${breite.toInt()} px',
        (tester) async {
      await baue(tester, Size(breite, 800));

      final emoji =
          imKopf(tester, find.text(lernwelten.first.emoji), 'Welt-Emoji');
      final flamme = imKopf(tester, find.byType(StreakFlamme), 'Flamme');
      final serie = imKopf(tester, find.text('7'), 'Seriezahl');
      final stern = imKopf(tester, find.text('⭐'), 'Stern');
      final sterneZahl = imKopf(tester, find.text('128'), 'Sternezahl');
      final profil = imKopf(tester, find.byType(ClipOval), 'Profilbild');

      // Von der linken Kante der Flamme bis zur rechten Kante der Sternezahl.
      final mittePaar = (flamme.left + sterneZahl.right) / 2;
      expect(mittePaar, moreOrLessEquals(breite / 2, epsilon: 6.0),
          reason: 'Paar-Mitte $mittePaar, Leisten-Mitte ${breite / 2}');

      // Der Stern steht rechts von der Flamme, nicht umgekehrt.
      expect(stern.left, greaterThan(flamme.right));

      // DAS EIGENTLICHE PAAR: innen deutlich enger als aussen. Ohne diese
      // Prüfung ginge der Test auch mit gleichmäßiger Verteilung durch —
      // Flamme und Stern liegen dort ebenso symmetrisch zur Mitte, nur eben
      // weit auseinander.
      final innen = stern.left - serie.right;
      final linksAussen = flamme.left - emoji.right;
      final rechtsAussen = profil.left - sterneZahl.right;
      // Fester, kleiner Abstand im Inneren (der Seitenrand der Leiste, 16) —
      // aussen dehnt sich der Rest.
      expect(innen, lessThanOrEqualTo(20.0), reason: 'innen $innen');
      expect(innen, lessThan(linksAussen),
          reason: 'innen $innen, links aussen $linksAussen');
      expect(innen, lessThan(rechtsAussen),
          reason: 'innen $innen, rechts aussen $rechtsAussen');
    });
  }

  testWidgets('das Welt-Emoji bleibt am linken Rand', (tester) async {
    await baue(tester, const Size(412, 800));
    // 16 px Seitenrand der Leiste: Das Emoji sitzt linksbündig in seiner
    // Fläche und rückt durch sie also nicht nach innen.
    final emoji =
        imKopf(tester, find.text(lernwelten.first.emoji), 'Welt-Emoji');
    expect(emoji.left, moreOrLessEquals(16, epsilon: 1.0));
  });
}
