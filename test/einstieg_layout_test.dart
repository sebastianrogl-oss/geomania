import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/screens/anmelde_screen.dart';
import 'package:geomania/screens/anzeigename_screen.dart';
import 'package:geomania/screens/willkommen_screen.dart';
import 'package:geomania/services/locale_service.dart';
import 'package:geomania/theme/app_theme.dart';

/// Die drei Einstiegs-Screens müssen auf kleinen Geräten passen — auch bei
/// grosser Systemschrift, und auch mit der Deko-Ebene im Hintergrund.
///
/// Die Deko liegt in einem Stack und ist absolut positioniert, sie KANN das
/// Layout des Inhalts also nicht verschieben. Genau das prüft dieser Test
/// nach: dass sie nichts anfasst, was vorher gepasst hat.
///
/// Zum Messaufbau siehe willkommen_screen_test.dart — ohne echte Poppins und
/// ohne AppTheme misst das Test-Binding mit einer Ersatzschrift und liegt um
/// rund 40 % daneben.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final schrift = FontLoader('Poppins')
      ..addFont(rootBundle.load('fonts/Poppins-Bold.ttf'))
      ..addFont(rootBundle.load('fonts/Poppins-Regular.ttf'));
    await schrift.load();
  });

  const groessen = <String, Size>{
    '320x480': Size(320, 480),
    '320x568': Size(320, 568),
    '360x640': Size(360, 640),
    '412x915': Size(412, 915),
  };

  final screens = <String, Widget Function()>{
    'Anmelden': () => AnmeldeScreen(onAngemeldet: () {}),
    'Name': () => AnzeigenameScreen(onFertig: () {}),
    'Willkommen': () => WillkommenScreen(onFertig: () {}),
  };

  /// Baut einen Screen und gibt zurück, welche Layout-Fehler dabei anfielen.
  ///
  /// FlutterError.onError statt tester.takeException(): letzteres liefert nur
  /// den ERSTEN Fehler, und ein überlaufendes Layout wirft pro Frame und pro
  /// betroffener Box je einen. Innerhalb der Umleitung darf kein expect()
  /// stehen — ein fehlschlagendes expect würde von der eigenen Fehlerliste
  /// verschluckt, und das Binding bricht danach mit "A test overrode
  /// FlutterError.onError" ab.
  Future<List<String>> baue(
      WidgetTester tester, Widget screen, Size groesse, double skala) async {
    final fehler = <String>[];
    final vorher = FlutterError.onError;
    FlutterError.onError = (details) => fehler.add(details.exceptionAsString());
    try {
      tester.view.physicalSize = groesse;
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: MediaQuery(
          data: MediaQueryData(
            size: groesse,
            textScaler: TextScaler.linear(skala),
          ),
          child: screen,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1200));
    } finally {
      FlutterError.onError = vorher;
    }
    return fehler;
  }

  // Der Willkommens-Screen war hier lange ausgeklammert: Er lief auf 320x480
  // bei Schriftskala 1.5 um 19 px über. Mit dem Umbau auf fünf wischbare
  // Karten ist das erledigt — die Karte hat eine vorab gerechnete Höhe, und
  // die Grafik darin gibt nach, wenn der Text mehr Platz braucht. Die Karten
  // einzeln prüft willkommen_screen_test.dart; hier steht der Screen nur noch
  // in der Reihe der drei Einstiegs-Screens.

  for (final sprache in ['de', 'en']) {
    for (final screen in screens.entries) {
      for (final g in groessen.entries) {
        for (final skala in [1.0, 1.5]) {
          testWidgets(
              'kein Überlauf: ${screen.key}, ${g.key}, Skala $skala, $sprache',
              (tester) async {
            LocaleService.sprache.value = sprache;
            addTearDown(() => LocaleService.sprache.value = 'de');
            addTearDown(tester.view.reset);

            final fehler =
                await baue(tester, screen.value(), g.value, skala);

            expect(fehler, isEmpty,
                reason: 'Layout läuft über: ${fehler.take(2).join(" | ")}');
          });
        }
      }
    }
  }
}
