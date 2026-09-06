import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/screens/rangliste_screen.dart';
import 'package:geomania/services/locale_service.dart';
import 'package:geomania/services/rangliste_service.dart';

/// Die Portfolio-Tagesrangliste.
///
/// ══ WAS HIER FESTGEHALTEN WIRD ═════════════════════════════════════════════
///
/// Sortiert wird nach der PROZENTUALEN Tagesrendite — fair unabhängig davon,
/// wer mit wie viel Kapital angetreten ist. Die Zeile muss deshalb dieselbe
/// Zahl gross zeigen: Eine Liste, die nach einem Wert sortiert und einen
/// anderen betont, sieht für den Spieler nach einem Fehler aus (der
/// Zweitplatzierte hätte scheinbar mehr verdient als der Erste).
///
/// Der Dollar-Betrag gehört dazu, aber klein und grau — er beantwortet die
/// zweite Frage, nicht die erste.
///
/// Für die Rangliste gab es bis hierher überhaupt keinen Test.
void main() {
  /// Baut eine Zeile in einem engen Fenster mit grosser Schrift.
  ///
  /// 320 px ist das schmalste Gerät, mit dem zu rechnen ist; 1,5 die
  /// Schriftskala, die ein Spieler mit eingeschränktem Sehvermögen einstellt.
  /// Beides zusammen ist der Fall, in dem eine Zeile bricht.
  Future<void> zeige(
    WidgetTester tester,
    RanglistenEintrag eintrag, {
    bool mitVorzeichen = true,
    double skala = 1.5,
    String sprache = 'de',
  }) async {
    LocaleService.sprache.value = sprache;
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(skala)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: RangZeile(
              eintrag: eintrag,
              istGeld: true,
              mitVorzeichen: mitVorzeichen,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  RanglistenEintrag eintrag({
    num wert = 4.2,
    num? zusatzWert = 42,
    String name = 'Sebastian',
  }) =>
      RanglistenEintrag(
        rang: 1,
        uid: 'u1',
        name: name,
        wert: wert,
        istIch: false,
        zusatzWert: zusatzWert,
      );

  group('Was gross steht', () {
    testWidgets('Der Prozentwert, nicht der Dollar-Betrag', (tester) async {
      await zeige(tester, eintrag());

      final prozent = tester.widget<Text>(find.textContaining('%'));
      final dollar = tester.widget<Text>(find.textContaining(r'$'));

      expect(prozent.style!.fontSize!, greaterThan(dollar.style!.fontSize!),
          reason: 'Sortiert wird nach Prozent — dann muss Prozent auch die '
              'grosse Zahl sein');
      expect(prozent.style!.fontWeight, FontWeight.w900);
    });

    testWidgets('Der Dollar-Betrag steht klein und grau darunter',
        (tester) async {
      await zeige(tester, eintrag());
      final dollar = tester.widget<Text>(find.textContaining(r'$'));
      expect(dollar.style!.color, const Color(0xFF888888));
      expect(dollar.style!.fontWeight, isNot(FontWeight.w900));
      // Darunter, nicht daneben: Prozent und Betrag sitzen in derselben
      // Spalte, rechtsbündig.
      final prozentOben = tester.getTopLeft(find.textContaining('%')).dy;
      expect(tester.getTopLeft(find.textContaining(r'$')).dy,
          greaterThan(prozentOben));
    });

    testWidgets('Beide tragen ein Vorzeichen', (tester) async {
      await zeige(tester, eintrag());
      expect(find.textContaining('+'), findsNWidgets(2));
    });

    testWidgets('Auch ein Verlust ist als solcher zu lesen', (tester) async {
      await zeige(tester, eintrag(wert: -3.5, zusatzWert: -35));
      expect(find.textContaining('+'), findsNothing);
      expect(find.textContaining('−').evaluate().length +
          find.textContaining('-').evaluate().length,
          greaterThanOrEqualTo(2));
    });
  });

  group('Der Reiter "Gesamt" bleibt beim absoluten Wert', () {
    testWidgets('Dort steht das Kapital, kein Prozent', (tester) async {
      // Allzeit-Kapital: Da IST der absolute Wert die richtige Grösse, und
      // sortiert wird auch danach.
      await zeige(tester, eintrag(wert: 1337, zusatzWert: null),
          mitVorzeichen: false);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining(r'$'), findsOneWidget);
    });

    testWidgets('Ein Alt-Eintrag ohne Prozentwert fällt sauber zurück',
        (tester) async {
      // Einträge aus der Zeit vor der Umstellung tragen den Dollar-Betrag als
      // 'punkte' und gar keinen zusatzWert. Sie dürfen nicht als Prozent
      // gelesen werden — der Rückfall zeigt sie als Betrag.
      await zeige(tester, eintrag(wert: 42, zusatzWert: null));
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining(r'$'), findsOneWidget);
    });
  });

  group('Eng und gross', () {
    for (final sprache in ['de', 'en']) {
      testWidgets('320 px, Skala 1,5, $sprache — nichts läuft über',
          (tester) async {
        // Ein langer Name ist der harte Fall: Er darf schrumpfen, die Zahlen
        // rechts nicht.
        await zeige(tester, eintrag(name: 'Maximiliane Schwarzenberger'),
            sprache: sprache);
        expect(tester.takeException(), isNull);
        expect(find.textContaining('%'), findsOneWidget);
        expect(find.textContaining(r'$'), findsOneWidget);
      });
    }

    testWidgets('Auch ein vierstelliger Betrag passt noch', (tester) async {
      await zeige(tester, eintrag(wert: 12.7, zusatzWert: 1270));
      expect(tester.takeException(), isNull);
    });
  });

  tearDown(() => LocaleService.sprache.value = 'de');
}
