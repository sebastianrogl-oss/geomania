import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/screens/anmelde_screen.dart';
import 'package:geomania/theme/app_theme.dart';
import 'package:geomania/widgets/wortmarke.dart';

/// Der Schriftzug steht seit dem Entfernen der Münze allein — und muss dann
/// auch wirklich mittig sitzen.
///
/// Mit der Münze davor war die Wortmarke als GANZES zentriert, die Schrift
/// selbst sass dadurch spürbar rechts der Mitte. Ohne sie darf sich das nicht
/// still ins Gegenteil verkehren, etwa durch das negative letterSpacing: Es
/// wird in Flutter auch NACH dem letzten Buchstaben angerechnet und macht die
/// Textbox schmaler als die Glyphenreihe.
///
/// Zum Messaufbau siehe willkommen_screen_test.dart — ohne echte Poppins misst
/// das Test-Binding mit einer Ersatzschrift und liegt um rund 40 % daneben.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final schrift = FontLoader('Poppins')
      ..addFont(rootBundle.load('fonts/Poppins-Bold.ttf'))
      ..addFont(rootBundle.load('fonts/Poppins-Regular.ttf'));
    await schrift.load();
  });

  const groessen = <String, Size>{
    '320x568': Size(320, 568),
    '360x640': Size(360, 640),
    '412x915': Size(412, 915),
  };

  for (final eintrag in groessen.entries) {
    testWidgets('Schriftzug sitzt mittig: ${eintrag.key}', (tester) async {
      tester.view.physicalSize = eintrag.value;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: AnmeldeScreen(onAngemeldet: () {}),
      ));

      final marke = tester.getRect(find.byType(Wortmarke));
      // Eine halbe Pixelbreite Spielraum: mehr wäre ein echter Versatz,
      // weniger ist bei gebrochenen Textbreiten nicht zu halten.
      expect(marke.center.dx,
          moreOrLessEquals(eintrag.value.width / 2, epsilon: 0.5),
          reason: 'Der Schriftzug steht nicht in der Bildschirmmitte');
    });
  }

  testWidgets('Keine Münze mehr im Schriftzug', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: AnmeldeScreen(onAngemeldet: () {}),
    ));

    expect(
        find.descendant(
            of: find.byType(Wortmarke), matching: find.byType(Image)),
        findsNothing,
        reason: 'Der Schriftzug soll allein stehen');
  });
}
