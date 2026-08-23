import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/screens/station_abschluss_screen.dart';
import 'package:geomania/services/locale_service.dart';
import 'package:geomania/theme/app_theme.dart';

/// Die Schluss-Ansicht soll ohne Wischen auf einen Blick passen.
///
/// Gemessen wird nicht "sieht gut aus", sondern der Scrollrest: bleibt
/// maxScrollExtent bei 0, ist der ganze Inhalt gleichzeitig sichtbar. Vorher
/// fehlten auf 360 x 640 rund 204 px und auf 412 x 915 noch 68 px — man musste
/// bis zur Kontinent-Karte scrollen.
///
/// Bei sehr grosser Systemschrift darf die Ansicht wieder scrollen; geprüft
/// wird dort nur, dass nichts überläuft.
///
/// ZWEI FALLEN, die dieser Test beide getreten hat und die er deshalb
/// ausdrücklich vermeidet:
///
///  * FlutterError.onError MUSS zurückgesetzt sein, BEVOR expect() läuft.
///    Sonst landet ein fehlschlagendes expect in der eigenen Fehlerliste
///    statt den Test rot zu machen, und das Binding bricht mit "A test
///    overrode FlutterError.onError" ab — der eigentliche Fehler bleibt
///    unsichtbar.
///  * Ohne echte Poppins und ohne AppTheme misst das Binding mit einer rund
///    40 % breiteren Ersatzschrift, und ohne view.physicalSize meldet
///    MediaQuery weiterhin 800 x 600.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final schrift = FontLoader('Poppins')
      ..addFont(rootBundle.load('fonts/Poppins-Bold.ttf'))
      ..addFont(rootBundle.load('fonts/Poppins-Regular.ttf'));
    await schrift.load();
  });

  /// Baut die Ansicht und liefert (Scrollrest, aufgetretene Layout-Fehler).
  /// FlutterError.onError ist beim Rückkehren bereits wiederhergestellt.
  Future<(double, List<FlutterErrorDetails>)> baueUndMiss(
    WidgetTester tester,
    Size groesse,
    double skala,
  ) async {
    SharedPreferences.setMockInitialValues({});
    LocaleService.sprache.value = 'de';
    tester.view.physicalSize = groesse;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fehler = <FlutterErrorDetails>[];
    final vorher = FlutterError.onError;
    FlutterError.onError = fehler.add;
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(skala)),
          child: w!,
        ),
        home: StationAbschlussScreen(
          welt: lernwelten.first,
          richtig: 8,
          gesamtFragen: 10,
          sterne: 8,
          dauer: const Duration(seconds: 95),
          gelerntVorher: const {},
        ),
      ));
      // Bis nach der letzten Einblendung (Weiter-Button bei 4000 ms).
      await tester.pump(const Duration(milliseconds: 5000));
      final pos =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      return (pos.maxScrollExtent, fehler);
    } finally {
      FlutterError.onError = vorher;
    }
  }

  const handys = <String, Size>{
    '360x640 (verbreitetes Android)': Size(360, 640),
    '412x915 (aktuelles Handy)': Size(412, 915),
  };

  for (final eintrag in handys.entries) {
    testWidgets('passt ohne Scrollen: ${eintrag.key}', (tester) async {
      final (rest, fehler) = await baueUndMiss(tester, eintrag.value, 1.0);
      expect(fehler.map((f) => f.exception.toString()), isEmpty);
      // Unter einem Pixel statt exakt 0: die Höhen entstehen aus Anteilen
      // (0,35 / 0,65) des freien Platzes, und da bleibt gelegentlich ein
      // Rest im Bereich von 1e-14 stehen. Sichtbar scrollen lässt sich das
      // nicht.
      expect(rest, lessThan(1.0),
          reason: 'Es bleiben ${rest.toStringAsFixed(1)} px unterhalb des '
              'Bildschirms — die Ansicht ist wieder scrollpflichtig geworden.');
    });

    for (final skala in [1.3, 1.5]) {
      testWidgets('kein Überlauf: ${eintrag.key}, Skala $skala',
          (tester) async {
        // Scrollen ist hier ausdrücklich erlaubt, Überlaufen nicht.
        final (_, fehler) = await baueUndMiss(tester, eintrag.value, skala);
        expect(fehler.map((f) => f.exception.toString()), isEmpty);
      });
    }
  }
}
