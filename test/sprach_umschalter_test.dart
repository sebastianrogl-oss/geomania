import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/screens/anzeigename_screen.dart';
import 'package:geomania/services/locale_service.dart';
import 'package:geomania/theme/app_theme.dart';

import 'package:geomania/widgets/sprach_umschalter.dart';

/// Der Sprachumschalter sitzt auf dem allerersten Bildschirm der App — dem
/// Namensfeld. Zwei Dinge müssen dort stimmen, und beide sind leicht zu
/// übersehen:
///
///  * Er liegt in einem Stack ÜBER dem Inhalt. Wächst der Inhalt (grosse
///    Systemschrift, kurzer Bildschirm), kann er ihn verdecken — die Spalte
///    hält deshalb oben Platz frei, und dieser Test prüft, dass es reicht.
///  * Ein Tipp baut über LocaleService die GANZE App neu. Dass dabei der
///    schon eingetippte Name erhalten bleibt, hängt daran, dass die
///    Widget-Struktur gleich bleibt — ein Umbau des Screens könnte das
///    unbemerkt kaputt machen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final schrift = FontLoader('Poppins')
      ..addFont(rootBundle.load('fonts/Poppins-Bold.ttf'))
      ..addFont(rootBundle.load('fonts/Poppins-Regular.ttf'));
    await schrift.load();
  });

  /// Nachbau der App-Wurzel aus main.dart: dort hängt ein
  /// ValueListenableBuilder auf LocaleService.sprache, der bei jedem Wechsel
  /// alles neu baut.
  Widget app() => ValueListenableBuilder<String>(
        valueListenable: LocaleService.sprache,
        builder: (kontext, sprache, kind) => MaterialApp(
          theme: AppTheme.theme,
          home: AnzeigenameScreen(onFertig: () {}),
        ),
      );

  const groessen = <String, Size>{
    '320x480 (sehr klein)': Size(320, 480),
    '320x568 (iPhone SE)': Size(320, 568),
    '360x640 (verbreitetes Android)': Size(360, 640),
    '412x915 (aktuelles Handy)': Size(412, 915),
  };

  for (final eintrag in groessen.entries) {
    for (final skala in [1.0, 1.5]) {
      testWidgets('sichtbar und frei: ${eintrag.key}, Skala $skala',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        LocaleService.sprache.value = 'de';
        addTearDown(() => LocaleService.sprache.value = 'de');
        tester.view.physicalSize = eintrag.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final fehler = <FlutterErrorDetails>[];
        final vorher = FlutterError.onError;
        FlutterError.onError = fehler.add;
        late Rect umschalter;
        late Rect inhalt;
        try {
          await tester.pumpWidget(MediaQuery(
            data: MediaQueryData(
                size: eintrag.value, textScaler: TextScaler.linear(skala)),
            child: app(),
          ));
          await tester.pump(const Duration(milliseconds: 300));
          umschalter = tester.getRect(find.byType(SprachUmschalter));
          inhalt = tester.getRect(find.byType(TextField));
        } finally {
          // Muss vor jedem expect zurückgesetzt sein, sonst verschluckt die
          // eigene Fehlerliste den Fehlschlag.
          FlutterError.onError = vorher;
        }

        expect(fehler, isEmpty, reason: 'Layout wirft oder läuft über');
        expect(umschalter.left, greaterThanOrEqualTo(0));
        expect(umschalter.right,
            lessThanOrEqualTo(eintrag.value.width));
        expect(umschalter.top, greaterThanOrEqualTo(0));
        expect(umschalter.overlaps(inhalt), isFalse,
            reason: 'Der Umschalter liegt über dem Namensfeld');
        // Zugleich die Mindest-Tippfläche.
        expect(umschalter.height, greaterThanOrEqualTo(44));
      });
    }
  }

  testWidgets('Tippen wechselt die Sprache, speichert sie und behält den Namen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    LocaleService.sprache.value = 'de';
    addTearDown(() => LocaleService.sprache.value = 'de');
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Wie sollen wir dich nennen?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Sebastian');
    await tester.pump();

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(LocaleService.sprache.value, 'en');
    expect(find.text('What should we call you?'), findsOneWidget);
    // Derselbe Schlüssel wie in den Einstellungen — beide Wege müssen
    // denselben Wert schreiben, sonst widersprechen sie sich.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('einstellung_sprache'), 'en');
    // Der App-weite Rebuild darf den schon eingetippten Namen nicht verlieren.
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Sebastian');

    // Und wieder zurück.
    await tester.tap(find.text('DE'));
    await tester.pumpAndSettle();
    expect(LocaleService.sprache.value, 'de');
    expect(find.text('Wie sollen wir dich nennen?'), findsOneWidget);
  });
}
