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
/// Sie stehen in GLEICHEM ABSTAND: Der Sprung vom Emoji zur Flamme ist so
/// gross wie der von der Flamme zum Stern und der vom Stern zum Profilbild.
///
/// Zwischenzeitlich standen Flamme und Stern eng als Paar in der Mitte. Auf
/// dem Gerät wirkten sie dadurch zusammengedrängt, während aussen Luft blieb
/// — deshalb wieder gleichmäßig. Das Emoji steht dabei ohne die 44er Fläche,
/// die das Paar-Layout brauchte: Ihr Leerraum käme zur ersten Lücke dazu und
/// liesse sie doppelt so gross aussehen wie die anderen beiden.
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
    testWidgets('Gleiche Lücken zwischen allen vieren — ${breite.toInt()} px',
        (tester) async {
      await baue(tester, Size(breite, 800));

      final emoji =
          imKopf(tester, find.text(lernwelten.first.emoji), 'Welt-Emoji');
      final flamme = imKopf(tester, find.byType(StreakFlamme), 'Flamme');
      final serie = imKopf(tester, find.text('7'), 'Seriezahl');
      final stern = imKopf(tester, find.text('⭐'), 'Stern');

      // Der Stern steht rechts von der Flamme, nicht umgekehrt.
      expect(stern.left, greaterThan(flamme.right));

      // DREI GLEICHE LÜCKEN — der eigentliche Punkt.
      //
      // GEMESSEN WIRD VON KASTEN ZU KASTEN, nicht von Zeichen zu Zeichen:
      // Innerhalb ihrer Kästen sitzen die Zeichen bewusst verschoben — die
      // Streak-Zahl rückt in den durchsichtigen Rand der Flamme hinein, das
      // Profilbild sitzt mit 38 px mittig in seiner 44er Tippfläche. Das sind
      // optische Entscheidungen; sie dürfen den Test nicht ausschlagen
      // lassen, und mit einer grosszügigen Toleranz wäre er stumpf. Die
      // Verteilung selbst — drei gleiche [Spacer] — muss dagegen auf den
      // Pixel stimmen.
      final flammeKasten = imKopf(tester,
          find.ancestor(
              of: find.byType(StreakFlamme), matching: find.byType(SizedBox)),
          'Flammen-Kasten');
      final sternKasten = imKopf(tester,
          find.ancestor(
              of: find.text('⭐'), matching: find.byType(ConstrainedBox)),
          'Stern-Kasten');
      final profilKasten = imKopf(tester,
          find.ancestor(
              of: find.byType(ClipOval), matching: find.byType(SizedBox)),
          'Profil-Kasten');

      final ersteLuecke = flammeKasten.left - emoji.right;
      final mittlereLuecke = sternKasten.left - flammeKasten.right;
      final letzteLuecke = profilKasten.left - sternKasten.right;
      expect(mittlereLuecke, moreOrLessEquals(ersteLuecke, epsilon: 1.0),
          reason: 'erste $ersteLuecke, mittlere $mittlereLuecke');
      expect(letzteLuecke, moreOrLessEquals(ersteLuecke, epsilon: 1.0),
          reason: 'erste $ersteLuecke, letzte $letzteLuecke');

      // Und die Zahl steckt tatsächlich im Rand der Flamme, statt rechts
      // daneben zu stehen: Ohne den Versatz begänne sie erst hinter ihr.
      expect(serie.left, lessThan(flamme.right),
          reason: 'Die Streak-Zahl ist nicht an die Flamme herangerückt');
      // Der Stern bleibt trotzdem frei — die Zahl darf nicht in ihn laufen.
      expect(serie.right, lessThan(stern.left));
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
