import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/screens/willkommen_screen.dart';
import 'package:geomania/services/locale_service.dart';
import 'package:geomania/theme/app_theme.dart';

/// Der Willkommens-Screen soll ohne Scrollen auf einen Blick passen — er hat
/// deshalb keinen SingleChildScrollView mehr, der zu viel Inhalt auffangen
/// würde. Genau darum muss er auf JEDER realistischen Grösse hineinpassen:
/// ein Überlauf wäre hier kein abgeschnittener Rand, sondern ein
/// gelb-schwarzer Balken im ersten Bildschirm, den ein neuer Nutzer sieht.
///
/// Geprüft werden die engen Fälle: 320 px Breite (kleinste ernsthaft genutzte
/// Handybreite), dazu ein schmal-hohes Format, das die Flaggenzeile aus der
/// Zeile drücken würde, wenn ihre Grösse an der Höhe hinge statt an der
/// Breite. Beide Sprachen, weil die englischen Zeilen anders lang sind.
///
/// DAMIT DER TEST MISST, WAS AUF DEM GERÄT STEHT, sind drei Dinge nötig, die
/// hier zunächst fehlten und den Screen um bis zu 45 px zu gross erscheinen
/// liessen:
///
///  * tester.view.physicalSize statt setSurfaceSize — letzteres ändert nur die
///    Layout-Fläche, MediaQuery meldet weiter 800x600. Alles, was seine Masse
///    aus MediaQuery rechnet, baut sonst für ein Tablet.
///  * Poppins laden — ohne echte Schrift misst das Test-Binding mit einer
///    Ersatzschrift, die JEDE Glyphe 1 em breit setzt. Texte sind damit rund
///    40 % zu breit, brechen früher um und türmen Höhe auf, die es nicht gibt.
///  * AppTheme.theme setzen — sonst fordert gar kein Text Poppins an, und die
///    geladene Schrift bliebe wirkungslos.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final schrift = FontLoader('Poppins')
      ..addFont(rootBundle.load('fonts/Poppins-Bold.ttf'))
      ..addFont(rootBundle.load('fonts/Poppins-Regular.ttf'));
    await schrift.load();
  });

  const groessen = <String, Size>{
    '320x480 (sehr klein)': Size(320, 480),
    '320x568 (iPhone SE)': Size(320, 568),
    '320x800 (schmal und hoch)': Size(320, 800),
    '360x640 (verbreitetes Android)': Size(360, 640),
    '412x915 (aktuelles Handy)': Size(412, 915),
    '768x1024 (Tablet)': Size(768, 1024),
  };

  for (final sprache in ['de', 'en']) {
    for (final eintrag in groessen.entries) {
      testWidgets('kein Überlauf: ${eintrag.key}, $sprache', (tester) async {
        LocaleService.sprache.value = sprache;
        addTearDown(() => LocaleService.sprache.value = 'de');

        tester.view.physicalSize = eintrag.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.theme,
            home: WillkommenScreen(onFertig: () {}),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1200)); // Flaggen-Einblenden

        expect(tester.takeException(), isNull,
            reason: 'Layout läuft über oder wirft');
      });
    }
  }

  testWidgets('Knopf löst aus', (tester) async {
    var getippt = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.theme,
        home: WillkommenScreen(onFertig: () => getippt = true),
      ),
    );
    await tester.tap(find.text('Los geht\'s'));
    expect(getippt, isTrue);
  });
}
