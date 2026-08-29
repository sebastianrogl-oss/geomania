import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/screens/anmelde_screen.dart';
import 'package:geomania/screens/anzeigename_screen.dart';
import 'package:geomania/theme/app_theme.dart';
import 'package:geomania/widgets/gradnetz.dart';
import 'package:geomania/widgets/sprach_umschalter.dart';

/// Der Einstieg darf beim Wechsel nicht seitlich springen.
///
/// Zum Messaufbau siehe willkommen_screen_test.dart — ohne echte Poppins misst
/// das Test-Binding mit einer Ersatzschrift und liegt um rund 40 % daneben.
void main() {
  const breite = 384.0;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final schrift = FontLoader('Poppins')
      ..addFont(rootBundle.load('fonts/Poppins-Bold.ttf'))
      ..addFont(rootBundle.load('fonts/Poppins-Regular.ttf'));
    await schrift.load();
  });

  setUp(() {});

  /// Der äusserste Stack ist der aus GradnetzHintergrund. Seine Breite ist
  /// zugleich die Breite von Hintergrundfläche, Gradnetz und Deko-Ebene:
  /// Alle drei hängen als Positioned.fill daran.
  Rect flaeche(WidgetTester tester) =>
      tester.getRect(find.byType(Stack).first);

  testWidgets('Beide Screens sind seitlich deckungsgleich', (tester) async {
    tester.view.physicalSize = const Size(breite, 805);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<Map<String, Rect>> messe(Widget screen) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.theme, home: screen));
      await tester.pump(const Duration(milliseconds: 300));
      return {
        'Umschalter': tester.getRect(find.byType(SprachUmschalter)),
        'Flaeche': flaeche(tester),
      };
    }

    final anmelde = await messe(AnmeldeScreen(onAngemeldet: () {}));
    final name = await messe(AnzeigenameScreen(onFertig: () {}));

    for (final schluessel in anmelde.keys) {
      expect(name[schluessel]!.left, anmelde[schluessel]!.left,
          reason: '$schluessel steht links unterschiedlich');
      expect(name[schluessel]!.right, anmelde[schluessel]!.right,
          reason: '$schluessel steht rechts unterschiedlich');
    }
  });


  testWidgets('Hintergrund UND Scrollbereich bleiben bildschirmbreit',
      (tester) async {
    tester.view.physicalSize = const Size(breite, 805);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Derselbe Aufbau wie in den Einstiegs-Screens, nur mit einem Inhalt, der
    // KEIN Kind mit voller Breite enthält — genau der Zustand, den der
    // Anmelde-Screen annimmt, sobald der Ladekreis den Knopfblock ersetzt.
    //
    // Geprüft werden BEIDE Stacks: der in GradnetzHintergrund und der im
    // Screen. Ohne fit schrumpft jeder von beiden auf die Inhaltsbreite und
    // bleibt linksbündig stehen — der zentrierte Inhalt springt dann seitlich.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: Scaffold(
        body: GradnetzHintergrund(
          schritt: 0,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                fit: StackFit.expand,
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight - 48),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Text('kurz')],
                      ),
                    ),
                  ),
                  const Positioned(top: 0, right: 24, child: SprachUmschalter()),
                ],
              ),
            ),
          ),
        ),
      ),
    ));

    final f = flaeche(tester);
    final scroll = tester.getRect(find.byType(SingleChildScrollView));
    expect(f.width, breite,
        reason: 'Der Hintergrund schrumpft auf die Inhaltsbreite');
    expect(f.left, 0.0, reason: 'Der Hintergrund haengt links an');
    expect(scroll.width, breite,
        reason: 'Der Scrollbereich schrumpft auf die Inhaltsbreite');
    expect(scroll.left, 0.0, reason: 'Der Scrollbereich haengt links an');
  });
}
