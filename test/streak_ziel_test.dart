import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/l10n/uebersetzungen.dart';
import 'package:geomania/screens/streak_ziel_screen.dart';
import 'package:geomania/services/benachrichtigungs_service.dart';
import 'package:geomania/services/locale_service.dart';
import 'package:geomania/services/streak_ziel_service.dart';
import 'package:geomania/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Der Streak-Ziel-Screen ───────────────────────────────────────────────────
//
// Zwei Fragen: Passt er auf den kleinsten Schirm, den die App bedient, ohne
// dass etwas überläuft oder gescrollt werden muss? Und stimmt die Logik, die
// entscheidet, wann er überhaupt erscheint?

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Poppins nachladen, sonst misst der Test mit einer Ersatzschrift und
    // andere Zeilenumbrüche als auf dem Gerät.
    final schrift = FontLoader('Poppins')
      ..addFont(rootBundle.load('fonts/Poppins-Bold.ttf'))
      ..addFont(rootBundle.load('fonts/Poppins-Regular.ttf'));
    await schrift.load();
  });

  // ── Layout ────────────────────────────────────────────────────────────────

  const schirme = [
    (320.0, 480.0, '320x480 (sehr klein)'),
    (320.0, 568.0, '320x568 (iPhone SE)'),
    (360.0, 640.0, '360x640 (verbreitetes Android)'),
  ];
  const skalen = [1.0, 1.5];
  const sprachen = ['de', 'en'];

  for (final (breite, hoehe, name) in schirme) {
    for (final skala in skalen) {
      for (final sprache in sprachen) {
        testWidgets('kein Überlauf: $name, Skala $skala, $sprache',
            (tester) async {
          SharedPreferences.setMockInitialValues({});
          await LocaleService.setzeSprache(sprache);
          addTearDown(() => LocaleService.setzeSprache('de'));

          tester.view.physicalSize = Size(breite, hoehe);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final fehler = <FlutterErrorDetails>[];
          final vorher = FlutterError.onError;
          FlutterError.onError = fehler.add;

          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.theme,
            home: MediaQuery(
              data: MediaQueryData.fromView(tester.view)
                .copyWith(textScaler: TextScaler.linear(skala)),
              child: const StreakZielScreen(),
            ),
          ));
          await tester.pump();

          FlutterError.onError = vorher;
          expect(fehler, isEmpty,
              reason: 'Überlauf auf $name bei Skala $skala ($sprache): '
                  '${fehler.map((f) => f.exception).join(' | ')}');

          // Alle vier Ziele stehen da und liegen innerhalb des Schirms —
          // gescrollt werden kann hier nichts.
          for (final tage in StreakZielService.zielTage) {
            final feld = find.text('$tage');
            expect(feld, findsOneWidget);
            final kasten = tester.getRect(feld);
            expect(kasten.top, greaterThanOrEqualTo(0.0));
            expect(kasten.bottom, lessThanOrEqualTo(hoehe));
          }

          // Knopf und Später-Link ebenfalls vollständig sichtbar.
          for (final text in ['Ziel setzen', 'Später entscheiden']) {
            final feld = find.text(t(text));
            expect(feld, findsOneWidget, reason: '"$text" fehlt');
            expect(tester.getRect(feld).bottom, lessThanOrEqualTo(hoehe),
                reason: '"$text" ragt unten heraus');
          }
        });
      }
    }
  }

  // ── Bedienung ─────────────────────────────────────────────────────────────

  testWidgets('erst mit Auswahl speichert der Knopf', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: const StreakZielScreen(),
    ));
    await tester.pump();

    // Ohne Auswahl tut der Knopf nichts.
    await tester.tap(find.text(t('Ziel setzen')));
    await tester.pump();
    expect(await StreakZielService.ziel(), isNull);
    expect(await StreakZielService.stand(), ZielStand.offen);

    // Mit Auswahl wird gespeichert und die Abfrage ist erledigt.
    await tester.tap(find.text('30'));
    await tester.pump();
    await tester.tap(find.text(t('Ziel setzen')));
    await tester.pumpAndSettle();
    expect(await StreakZielService.ziel(), 30);
    expect(await StreakZielService.stand(), ZielStand.erledigt);
  });

  testWidgets('"Später" speichert kein Ziel', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: const StreakZielScreen(),
    ));
    await tester.pump();

    await tester.tap(find.text(t('Später entscheiden')));
    await tester.pumpAndSettle();
    expect(await StreakZielService.ziel(), isNull);
    expect(await StreakZielService.stand(), ZielStand.spaeter);
  });

  // ── Wann der Screen erscheint ─────────────────────────────────────────────

  group('Auslöser', () {
    Future<void> stationen(int n) async {
      for (var i = 0; i < n; i++) {
        await StreakZielService.stationAbgeschlossen();
      }
    }

    test('erst ab der zweiten abgeschlossenen Station', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await StreakZielService.sollScreenZeigen(), isFalse);
      await stationen(1);
      expect(await StreakZielService.sollScreenZeigen(), isFalse);
      await stationen(1);
      expect(await StreakZielService.sollScreenZeigen(), isTrue);
    });

    test('ein verpasster Moment geht nicht verloren', () async {
      // Wer die App genau nach dem zweiten Abschluss schliesst, bekommt den
      // Screen beim nächsten — deshalb >= und nicht ==.
      SharedPreferences.setMockInitialValues({});
      await stationen(4);
      expect(await StreakZielService.sollScreenZeigen(), isTrue);
    });

    test('nach "Später" erst wieder bei 6', () async {
      SharedPreferences.setMockInitialValues({});
      await stationen(2);
      await StreakZielService.vertagt();
      expect(await StreakZielService.stand(), ZielStand.spaeter);
      expect(await StreakZielService.sollScreenZeigen(), isFalse);
      await stationen(3); // 5
      expect(await StreakZielService.sollScreenZeigen(), isFalse);
      await stationen(1); // 6
      expect(await StreakZielService.sollScreenZeigen(), isTrue);
    });

    test('zweimal "Später" ist Schluss', () async {
      SharedPreferences.setMockInitialValues({});
      await stationen(6);
      await StreakZielService.vertagt();
      await StreakZielService.vertagt();
      expect(await StreakZielService.stand(), ZielStand.erledigt);
      await stationen(20);
      expect(await StreakZielService.sollScreenZeigen(), isFalse);
    });

    test('ein gesetztes Ziel beendet die Abfrage', () async {
      SharedPreferences.setMockInitialValues({});
      await stationen(2);
      await StreakZielService.setzeZiel(14);
      expect(await StreakZielService.sollScreenZeigen(), isFalse);
      await stationen(10);
      expect(await StreakZielService.sollScreenZeigen(), isFalse);
    });

    test('keine Schwelle trifft eine der Erlaubnis-Abfrage', () {
      // Beide Abfragen zählen dasselbe (abgeschlossene Stationen) und beide
      // sind Vollbild. Fielen zwei Schwellen zusammen, käme nach derselben
      // Station erst der eine, dann der andere Schirm.
      final erlaubnis = {
        BenachrichtigungsService.kStationenBisErsteFrage,
        BenachrichtigungsService.kStationenBisZweiteFrage,
      };
      final ziel = {
        StreakZielService.kStationenBisFrage,
        StreakZielService.kStationenBisZweiteFrage,
      };
      expect(erlaubnis.intersection(ziel), isEmpty,
          reason: 'Erlaubnis fragt bei $erlaubnis, das Ziel bei $ziel');
    });

    test('das Ziel kommt nach der Erlaubnis, nicht davor', () {
      // Reihenfolge im Ablauf: erst die Erlaubnis (Schwelle 1), dann das Ziel
      // (Schwelle 2). Andersherum stünde die Frage nach dem Durchhalten vor
      // der Frage, ob überhaupt erinnert werden darf.
      expect(StreakZielService.kStationenBisFrage,
          greaterThan(BenachrichtigungsService.kStationenBisErsteFrage));
      expect(StreakZielService.kStationenBisZweiteFrage,
          greaterThan(BenachrichtigungsService.kStationenBisZweiteFrage));
    });
  });
}
