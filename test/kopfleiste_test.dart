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
/// Die ersten drei stehen LINKSBÜNDIG in festem Abstand, der freie Platz
/// sammelt sich vor dem Profilbild. Zwischenzeitlich waren alle vier
/// gleichmäßig verteilt — die drei Zusammengehörigen standen dadurch weit
/// auseinander.
///
/// Der feste Abstand ist mehr als Geschmack: Der Stern hängt damit am ENDE
/// der Streak-Zahl. Wächst sie um eine Stelle, rückt er um deren Breite nach
/// rechts, statt dass die Ziffer in ihn hineinläuft.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Höhe der grünen Leiste (siehe `_GreenHeader`). Alles darüber gehört zu
  /// ihr — der Lernpfad darunter trägt dieselben Zeichen noch einmal (Sterne
  /// an den Stationen, Flammen in der Deko), deshalb wird hier gefiltert.
  const kopfHoehe = 56.0;

  /// Seitenrand der Leiste, zugleich der Abstand zwischen den drei linken
  /// Zeichen (`_kLeisteRand` in home_screen.dart).
  const rand = 16.0;

  /// Abstand zwischen den Zeichen (_kZeichenAbstand in home_screen.dart).
  /// Kleiner als der Rand, weil die Kaesten breiter sind als ihr Inhalt.
  const zeichenAbstand = 6.0;

  Future<void> baue(WidgetTester tester, Size schirm, {int streak = 7}) async {
    SharedPreferences.setMockInitialValues({
      'lp_streak': streak,
      'lp_gesamt_richtig': 128,
    });
    tester.view.physicalSize = schirm;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      // Eigener Key je Aufbau: Ohne ihn uebernaehme ein zweites pumpWidget den
      // bestehenden State samt schon geladenem Fortschritt, und ein geaenderter
      // Streak käme gar nicht an (siehe pfad_oberkante_test.dart).
      home: HomeScreen(key: ValueKey(streak)),
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

  Rect flammenKasten(WidgetTester tester) => imKopf(
      tester,
      find.ancestor(
          of: find.byType(StreakFlamme), matching: find.byType(SizedBox)),
      'Flammen-Kasten');

  Rect sternKasten(WidgetTester tester) => imKopf(
      tester,
      find.ancestor(of: find.text('⭐'), matching: find.byType(ConstrainedBox)),
      'Stern-Kasten');

  for (final breite in [320.0, 360.0, 412.0]) {
    testWidgets('Links gebündelt, Profilbild rechts — ${breite.toInt()} px',
        (tester) async {
      await baue(tester, Size(breite, 800));

      final emoji =
          imKopf(tester, find.text(lernwelten.first.emoji), 'Welt-Emoji');
      final flamme = flammenKasten(tester);
      final stern = sternKasten(tester);
      final profil = imKopf(
          tester,
          find.ancestor(
              of: find.byType(ClipOval), matching: find.byType(SizedBox)),
          'Profil-Kasten');

      // BEIDE LÜCKEN GLEICH — und zwar im Layout gleich, weil beide Kästen
      // ihren Inhalt unterschiedlich weit einrücken. Die Flamme hat rundum
      // durchsichtigen Rand, die Streak-Zahl ist zusätzlich nach links
      // gerückt; nur deshalb sehen 6 px hier wie 16 aus.
      expect(flamme.left - emoji.right,
          moreOrLessEquals(zeichenAbstand, epsilon: 1.0),
          reason: 'Emoji → Flamme');

      // ZWISCHEN FLAMME UND STERN ZÄHLT DER SICHTBARE ABSTAND, nicht der im
      // Layout. Die Streak-Zahl ist 10 px nach links in den durchsichtigen
      // Rand der Flamme gerückt; ihr Kasten endet also 10 px weiter rechts,
      // als die Ziffer aufhört. Mit dem vollen Seitenrand dazwischen klaffte
      // sichtbar eine Lücke von 26 px, wo überall sonst 16 stehen.
      //
      // Gemessen wird deshalb von der Ziffer zum Sternzeichen — genau das,
      // was man sieht.
      final serie = imKopf(tester, find.text('7'), 'Seriezahl');
      final sternZeichen = imKopf(tester, find.text('⭐'), 'Sternzeichen');
      expect(sternZeichen.left - serie.right,
          moreOrLessEquals(rand, epsilon: 1.5),
          reason: 'Sichtbare Lücke zwischen Serie und Stern');
      // Der Kasten-Abstand ist entsprechend kleiner — hier steht er, damit
      // eine Änderung am Versatz nicht unbemerkt beide Werte verschiebt.
      expect(stern.left - flamme.right,
          moreOrLessEquals(zeichenAbstand, epsilon: 1.0),
          reason: 'Flamme → Stern im Layout');

      // Das Profilbild steht am rechten Rand, der freie Platz liegt davor.
      expect(breite - profil.right, moreOrLessEquals(rand, epsilon: 1.0),
          reason: 'Profilbild am rechten Rand');
      expect(profil.left - stern.right, greaterThan(rand * 2),
          reason: 'Der freie Platz sammelt sich vor dem Profilbild');
    });
  }

  testWidgets('das Welt-Emoji bleibt am linken Rand', (tester) async {
    await baue(tester, const Size(412, 800));
    final emoji =
        imKopf(tester, find.text(lernwelten.first.emoji), 'Welt-Emoji');
    expect(emoji.left, moreOrLessEquals(rand, epsilon: 1.0));
  });

  /// DER EIGENTLICHE GRUND FÜR DEN FESTEN ABSTAND.
  ///
  /// Mit verteilten Lücken hing die Position des Sterns am freien Platz —
  /// eine breitere Streak-Zahl schob ihn kaum. Jetzt hängt er am Ende der
  /// Zahl und rückt genau um deren Zuwachs nach rechts.
  testWidgets('Eine Stelle mehr in der Serie rückt den Stern nach rechts',
      (tester) async {
    await baue(tester, const Size(412, 800), streak: 7);
    final schmalerStern = sternKasten(tester).left;
    final schmaleZahl = imKopf(tester, find.text('7'), 'Seriezahl').width;

    await baue(tester, const Size(412, 800), streak: 128);
    final breiterStern = sternKasten(tester).left;
    final breiteZahl = imKopf(tester, find.text('128'), 'Seriezahl').width;

    expect(breiterStern, greaterThan(schmalerStern),
        reason: 'Der Stern ist nicht mitgewandert');
    // Und zwar um GENAU den Zuwachs der Zahl — nicht um weniger (Lücken, die
    // sich neu verteilen) und nicht um mehr.
    expect(breiterStern - schmalerStern,
        moreOrLessEquals(breiteZahl - schmaleZahl, epsilon: 1.0));
  });
}
