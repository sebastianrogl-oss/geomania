import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/screens/anzeigename_screen.dart';
import 'package:geomania/services/locale_service.dart';
import 'package:geomania/theme/app_theme.dart';

/// AUS DEM NAMENSFELD MUSS MAN WIEDER HERAUSKOMMEN.
///
/// Wer auf das Feld tippte, bekam die Tastatur — und wurde sie nicht mehr
/// los: Ein Tipp daneben nahm den Fokus nicht, und auf diesem Screen gibt es
/// weder einen Zurück-Pfeil noch sonst etwas, das ihn abgeben würde. Android
/// schliesst die Tastatur von sich aus nicht.
///
/// Geprüft wird der Fokus des Textfelds, nicht die Tastatur selbst: Im Test
/// gibt es keine echte Systemtastatur, sie hängt aber genau an diesem Fokus.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> baue(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    LocaleService.sprache.value = 'de';
    addTearDown(() => LocaleService.sprache.value = 'de');
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: AnzeigenameScreen(onFertig: () {}),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Hat das Namensfeld den Fokus — hinge also die Tastatur davor?
  bool feldHatFokus(WidgetTester tester) =>
      tester.state<EditableTextState>(find.byType(EditableText))
          .widget
          .focusNode
          .hasFocus;

  testWidgets('Ein Tipp neben das Feld gibt den Fokus wieder ab',
      (tester) async {
    await baue(tester);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(feldHatFokus(tester), isTrue,
        reason: 'Das Feld bekommt beim Antippen keinen Fokus');

    // Irgendwo daneben — die Überschrift oben ist reine Fläche.
    await tester.tap(find.text('Wie sollen wir dich nennen?'));
    await tester.pump();
    expect(feldHatFokus(tester), isFalse,
        reason: 'Der Fokus klebt im Feld, die Tastatur bliebe stehen');
  });

  testWidgets('Der Tipp-Fänger nimmt den Kindern ihre Tipps nicht weg',
      (tester) async {
    // Er liegt über dem ganzen Screen. Ein Kind, das seinen Tipp behalten
    // muss und ohne Firebase auskommt: der Sprachumschalter oben rechts.
    await baue(tester);
    await tester.enterText(find.byType(TextField), 'Sebastian');
    await tester.pump();

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(LocaleService.sprache.value, 'en');
    // Der Name im Feld übersteht den Sprachwechsel.
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Sebastian');
    // Den Fokus behält das Feld dabei: Der Umschalter gewinnt den Tipp für
    // sich, der Fänger darüber kommt gar nicht zum Zug. Genau so soll es
    // sein — wer die Sprache umstellt, will nicht auch noch die Tastatur
    // zuklappen.
  });
}
