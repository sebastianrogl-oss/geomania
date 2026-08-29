import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/screens/willkommen_screen.dart';
import 'package:geomania/services/locale_service.dart';
import 'package:geomania/theme/app_theme.dart';

/// Der Willkommens-Screen ist eine Folge von fünf wischbaren Karten. Er hat
/// keinen Scrollbereich — was nicht hineinpasst, wäre ein gelb-schwarzer
/// Balken im ersten Bildschirm, den ein neuer Nutzer sieht.
///
/// Geprüft wird deshalb JEDE Karte einzeln, auf jeder engen Grösse und bei
/// beiden Schriftskalen. Die längste Karte ist nicht immer dieselbe: mal
/// entscheidet der Text, mal der Knopf auf der letzten Karte.
///
/// DAMIT DER TEST MISST, WAS AUF DEM GERÄT STEHT, sind drei Dinge nötig:
///
///  * tester.view.physicalSize statt setSurfaceSize — letzteres ändert nur die
///    Layout-Fläche, MediaQuery meldet weiter 800x600.
///  * Poppins laden — ohne echte Schrift misst das Test-Binding mit einer
///    Ersatzschrift, die JEDE Glyphe 1 em breit setzt. Texte sind damit rund
///    40 % zu breit, brechen früher um und türmen Höhe auf, die es nicht gibt.
///  * AppTheme.theme setzen — sonst fordert gar kein Text Poppins an.
/// Statt pumpAndSettle: Die Streak-Flamme auf Karte 4 animiert dauerhaft, ein
/// pumpAndSettle liefe deshalb in die Zeitüberschreitung. Feste Pumpen reichen
/// — der PageView rastet in rund 300 ms ein.
Future<void> _setzen(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

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
    '360x640 (verbreitetes Android)': Size(360, 640),
    '412x915 (aktuelles Handy)': Size(412, 915),
    '768x1024 (Tablet)': Size(768, 1024),
  };

  /// Baut den Screen und wischt bis zur Karte [karte].
  ///
  /// FlutterError.onError statt tester.takeException(): letzteres liefert nur
  /// den ERSTEN Fehler, und ein überlaufendes Layout wirft pro Frame und pro
  /// betroffener Box je einen. Innerhalb der Umleitung darf kein expect()
  /// stehen — ein fehlschlagendes expect würde von der eigenen Fehlerliste
  /// verschluckt.
  Future<List<String>> baue(
    WidgetTester tester, {
    required Size groesse,
    required double skala,
    required int karte,
  }) async {
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
          child: WillkommenScreen(onFertig: () {}),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1200)); // Flaggen
      for (var i = 0; i < karte; i++) {
        await tester.drag(
            find.byType(PageView), Offset(-groesse.width, 0));
        await _setzen(tester);
      }
    } finally {
      FlutterError.onError = vorher;
    }
    return fehler;
  }

  for (final sprache in ['de', 'en']) {
    for (final eintrag in groessen.entries) {
      for (final skala in [1.0, 1.5]) {
        for (var karte = 0; karte < 5; karte++) {
          testWidgets(
              'kein Überlauf: Karte ${karte + 1}, ${eintrag.key}, '
              'Skala $skala, $sprache', (tester) async {
            LocaleService.sprache.value = sprache;
            addTearDown(() => LocaleService.sprache.value = 'de');
            addTearDown(tester.view.reset);

            final fehler = await baue(tester,
                groesse: eintrag.value, skala: skala, karte: karte);

            expect(fehler, isEmpty,
                reason: 'Layout läuft über: ${fehler.take(2).join(" | ")}');
          });
        }
      }
    }
  }

  testWidgets('Überspringen führt direkt weiter', (tester) async {
    var fertig = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: WillkommenScreen(onFertig: () => fertig = true),
    ));
    await tester.tap(find.text('Überspringen'));
    expect(fertig, isTrue);
  });

  testWidgets('Der Knopf steht erst auf der letzten Karte', (tester) async {
    var fertig = false;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: WillkommenScreen(onFertig: () => fertig = true),
    ));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Los geht\'s'), findsNothing,
        reason: 'Auf Karte 1 gibt es noch nichts abzuschliessen');

    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(PageView), const Offset(-360, 0));
      await _setzen(tester);
    }

    expect(find.text('Los geht\'s'), findsOneWidget);
    await tester.tap(find.text('Los geht\'s'));
    expect(fertig, isTrue);
  });

  testWidgets('Der Hintergrund bleibt beim Wischen gleich gross',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: WillkommenScreen(onFertig: () {}),
    ));
    await tester.pump(const Duration(milliseconds: 1200));

    // Der äusserste Stack ist der aus GradnetzHintergrund. An ihm hängen
    // Hintergrundfläche, Gradnetz und Deko-Ebene als Positioned.fill —
    // schrumpft er, springt der ganze Screen.
    Rect flaeche() => tester.getRect(find.byType(Stack).first);
    final erste = flaeche();

    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(PageView), const Offset(-360, 0));
      await _setzen(tester);
      expect(flaeche(), erste,
          reason: 'Die Hintergrundfläche wandert auf Karte ${i + 2}');
    }
  });

  /// Der Text liegt auf allen fünf Karten auf einem grauen Feld. Er ist nur
  /// dann lesbar, wenn dieses Feld ihn VOLLSTÄNDIG unterlegt — ragte eine
  /// Zeile darüber hinaus, stünde sie auf Karte 1 und 2 auf Flaggen und
  /// Wahrzeichen.
  ///
  /// Geprüft im engsten Fall: 320x480 bei Schriftskala 1.5, wo der Text am
  /// meisten Platz braucht.
  for (final karte in [0, 1, 2, 3, 4]) {
    for (final sprache in ['de', 'en']) {
      testWidgets(
          'Text liegt ganz auf dem grauen Feld: Karte ${karte + 1}, '
          '320x480, Skala 1.5, $sprache', (tester) async {
        LocaleService.sprache.value = sprache;
        addTearDown(() => LocaleService.sprache.value = 'de');
        addTearDown(tester.view.reset);

        const groesse = Size(320, 480);
        tester.view.physicalSize = groesse;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.theme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: groesse,
              textScaler: TextScaler.linear(1.5),
            ),
            child: WillkommenScreen(onFertig: () {}),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 1200));
        for (var i = 0; i < karte; i++) {
          await tester.drag(find.byType(PageView), const Offset(-320, 0));
          await _setzen(tester);
        }

        // Nicht über die Farbe allein gesucht: Auf Karte 3 und 5 tragen auch
        // die nachgestellten Antwortknöpfe AppTheme.card. Das Textfeld ist der
        // graue Kasten ÜBER dem Titel, und den erkennt man am Schriftschnitt
        // w900 — sprachunabhängig, anders als der Titeltext selbst.
        final feld = find.ancestor(
          of: find.byWidgetPredicate(
              (w) => w is Text && w.style?.fontWeight == FontWeight.w900),
          matching: find.byWidgetPredicate((w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == AppTheme.card),
        );
        expect(feld, findsWidgets, reason: 'Das graue Textfeld fehlt');
        final feldRect = tester.getRect(feld.first);

        // Beide Zeilen müssen innerhalb liegen.
        for (final text in tester
            .widgetList<Text>(
                find.descendant(of: feld.first, matching: find.byType(Text)))
            .map((w) => w.data!)) {
          final r = tester.getRect(find.text(text));
          expect(
              feldRect.contains(r.topLeft) && feldRect.contains(r.bottomRight),
              isTrue,
              reason: '"$text" ragt über das graue Feld hinaus: '
                  'Text $r, Feld $feldRect');
        }
      });
    }
  }

  // ── Der Text sitzt auf allen fünf Karten gleich hoch ───────────────────────
  //
  // Der eigentliche Zweck der gemeinsamen Textkante: Beim Wischen darf der
  // Text nicht wandern. Vorher ergab sich seine Lage aus der Motivhöhe, und
  // die ist je Karte anders — gemessen lag der Titel zwischen 20 % und 78 %
  // der Kartenhöhe.
  //
  // Geprüft wird die Oberkante des TITELS, nicht die des grauen Feldes: Auf
  // den vollflächigen Karten steht der Text in einem Kasten mit Innenrand, und
  // sichtbar ausgerichtet ist die Schrift, nicht der Kasten.
  for (final eintrag in groessen.entries) {
    for (final skala in [1.0, 1.5]) {
      testWidgets(
          'Text auf gleicher Höhe: ${eintrag.key}, Skala $skala',
          (tester) async {
        addTearDown(tester.view.reset);
        const titel = [
          '195 Länder entdecken',
          'Station für Station',
          'Immer anders gefragt',
          'Dranbleiben lohnt sich',
          'Jeden Tag etwas Neues',
        ];

        // EINMAL bauen und durchwischen, nicht je Karte neu: Ein zweites
        // pumpWidget übernimmt den bestehenden State samt PageController, die
        // Karte bliebe stehen und die Wischbewegungen liefen ins Leere.
        tester.view.physicalSize = eintrag.value;
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.theme,
          home: MediaQuery(
            data: MediaQueryData(
              size: eintrag.value,
              textScaler: TextScaler.linear(skala),
            ),
            child: WillkommenScreen(onFertig: () {}),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 1200));

        final lagen = <double>[];
        final felder = <String>[];
        for (var karte = 0; karte < 5; karte++) {
          if (karte > 0) {
            await tester.drag(
                find.byType(PageView), Offset(-eintrag.value.width, 0));
            await _setzen(tester);
          }
          final flaeche = tester.getRect(find.byType(PageView));
          lagen.add(tester.getRect(find.text(titel[karte])).top - flaeche.top);

          // Das graue Feld ist der Vorfahr des Titels, der AppTheme.card
          // trägt — über den Titel gesucht, weil auf Karte 3 und 5 auch die
          // nachgestellten Antwortknöpfe dieselbe Farbe haben.
          final feld = tester.getRect(find.ancestor(
            of: find.text(titel[karte]),
            matching: find.byWidgetPredicate((w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == AppTheme.card),
          ).first);
          felder.add('${(feld.top - flaeche.top).toStringAsFixed(1)} / '
              '${feld.width.toStringAsFixed(1)}');
        }

        for (var i = 1; i < lagen.length; i++) {
          expect(lagen[i], closeTo(lagen[0], 0.5),
              reason: 'Karte ${i + 1} setzt den Titel auf ${lagen[i]}, '
                  'Karte 1 auf ${lagen[0]} — Lagen: $lagen');
        }

        // Und das graue Feld darunter genauso: gleiche Oberkante, gleiche
        // Breite. Es ist dasselbe Bauteil auf allen fünf Karten, nicht
        // fünfmal etwas Ähnliches.
        for (var i = 1; i < felder.length; i++) {
          expect(felder[i], felder[0],
              reason: 'Das graue Feld sitzt auf Karte ${i + 1} anders: '
                  '${felder[i]} statt ${felder[0]}');
        }
      });
    }
  }
}
