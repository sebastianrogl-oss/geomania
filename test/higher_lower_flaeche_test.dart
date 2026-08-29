import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/data/country_rankings.dart';
import 'package:geomania/screens/higher_lower_screen.dart';
import 'package:geomania/theme/app_theme.dart';

/// Die aufgedeckte Kartenhälfte muss ihre Hälfte VOLLSTÄNDIG füllen.
///
/// Vorher tat sie das nicht: Der Standard-Layoutbuilder von AnimatedSwitcher
/// setzt seine Kinder in einen Stack mit StackFit.loose, und die Hälfte gibt
/// nur ihre Breite vor. Sie schrumpfte deshalb auf die Höhe ihres Inhalts und
/// wurde mittig gesetzt — über und unter der Färbung blieb der
/// Scaffold-Hintergrund als heller Balken stehen.
///
/// Gemessen wird deshalb die Fläche gegen ihren Platz, nicht das Aussehen.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final schrift = FontLoader('Poppins')
      ..addFont(rootBundle.load('fonts/Poppins-Bold.ttf'))
      ..addFont(rootBundle.load('fonts/Poppins-Regular.ttf'));
    await schrift.load();
  });

  Future<void> starte(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: const HigherLowerScreen(),
    ));
    // Die Lade-Futures laufen ausserhalb von initState weiter.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Den Ländernamen aus einer Hälfte lesen.
  ///
  /// Er ist der einzige Text der Karte in 20 px und Schriftfarbe 0xFF1A1A1A —
  /// die "? ? ?" der verdeckten Hälfte haben dieselbe Größe, aber Grau.
  String land(WidgetTester tester, Finder haelfte) {
    final texte = tester.widgetList<Text>(
        find.descendant(of: haelfte, matching: find.byType(Text)));
    return texte
        .firstWhere((t) =>
            t.style?.fontSize == 20 &&
            t.style?.color == const Color(0xFF1A1A1A))
        .data!;
  }

  /// Die Kategorie aus der Beschriftung der Karte ableiten.
  RankingCategory kategorie(WidgetTester tester, Finder haelfte) {
    final texte = tester.widgetList<Text>(
        find.descendant(of: haelfte, matching: find.byType(Text)));
    final label = texte.firstWhere((t) => t.style?.fontSize == 13).data!;
    return rankingCategories.firstWhere((k) => k.label == label);
  }

  /// RICHTIG antworten — sonst endet die Runde sofort, und der Game-Over-Weg
  /// schreibt in die Rangliste, wozu im Test kein Firebase bereitsteht.
  /// Welche Richtung stimmt, lässt sich aus den öffentlichen Ranglisten-Daten
  /// ausrechnen: unten tippen heisst "höher", oben tippen heisst "niedriger".
  Future<void> antworteRichtig(WidgetTester tester) async {
    final schalter = [find.byKey(kHlObenKey), find.byKey(kHlUntenKey)];
    final kat = kategorie(tester, schalter[0]);
    final oben = countryRankings
        .firstWhere((c) => c.name == land(tester, schalter[0]));
    final unten = countryRankings
        .firstWhere((c) => c.name == land(tester, schalter[1]));
    final hoeher = kat.getValue(unten)! >= kat.getValue(oben)!;

    await tester.tapAt(tester.getRect(schalter[hoeher ? 1 : 0]).center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Der Screen stellt nach einer Antwort einen 1100-ms-Timer auf die nächste
  /// Runde. Bliebe er offen, meldete der Test einen "pending timer" statt des
  /// eigentlichen Ergebnisses — also erst auslaufen lassen, dann prüfen.
  Future<void> laufeAus(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1200));
    // Danach läuft die Wisch-Bewegung (450 ms). Auch die muss durch sein,
    // bevor der Test weitertippt: Solange sie läuft, ist die Fläche gesperrt
    // und ein Tipp verpufft.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Aufgedeckte Hälfte füllt ihren Platz von Kante zu Kante',
      (tester) async {
    await starte(tester);

    final schalter = [find.byKey(kHlObenKey), find.byKey(kHlUntenKey)];
    for (final h in schalter) {
      expect(h, findsOneWidget, reason: 'Es müssen zwei Hälften da sein');
    }

    await antworteRichtig(tester);

    final platz = tester.getRect(schalter[1]);
    final flaeche = tester.getRect(find
        .descendant(of: schalter[1], matching: find.byType(AnimatedContainer))
        .first);
    await laufeAus(tester);

    expect(flaeche.top, moreOrLessEquals(platz.top, epsilon: 0.01),
        reason: 'Oben bleibt ein Balken stehen');
    expect(flaeche.bottom, moreOrLessEquals(platz.bottom, epsilon: 0.01),
        reason: 'Unten bleibt ein Balken stehen');
    expect(flaeche.left, moreOrLessEquals(platz.left, epsilon: 0.01));
    expect(flaeche.right, moreOrLessEquals(platz.right, epsilon: 0.01));
  });

  /// Die gefärbte Fläche soll an der Trennlinie enden — nicht davor aufhören
  /// und nicht darüber hinweg.
  ///
  /// Geprüft wird an der Linie selbst: Beide Hälften müssen mit ihrer Kante
  /// an ihr anliegen, und zwischen den beiden Kanten darf höchstens die
  /// Linienstärke liegen. Früher klaffte dort das ganze VS-Band.
  testWidgets('Farbfläche endet an der Trennlinie', (tester) async {
    await starte(tester);
    // Auch auf dem schmalsten Schirm, den die App bedient: Die Hälften werden
    // aus der Resthöhe gerechnet, und die ist hier am knappsten.
    tester.view.physicalSize = const Size(320, 480);
    await tester.pump();

    final oben = tester.getRect(find.byKey(kHlObenKey));
    final unten = tester.getRect(find.byKey(kHlUntenKey));
    final linie = tester.getRect(find.byType(Divider).first);

    expect(oben.bottom, lessThanOrEqualTo(linie.center.dy),
        reason: 'Die obere Fläche läuft über die Linie hinweg');
    expect(unten.top, greaterThanOrEqualTo(linie.center.dy),
        reason: 'Die untere Fläche läuft über die Linie hinweg');

    final spalt = unten.top - oben.bottom;
    expect(spalt, lessThanOrEqualTo(1.01),
        reason: 'Zwischen den Flächen klafft eine Lücke von $spalt dp — '
            'sie sollen an der Linie zusammenstossen');
    expect(spalt, greaterThanOrEqualTo(0.0),
        reason: 'Die Flächen überlappen sich');
  });

  /// Während die Karten wischen, darf ein Tipp nichts auslösen.
  ///
  /// Sonst rät man auf ein Land, das gerade erst hereinkommt — die Karte, die
  /// unter dem Finger liegt, ist im nächsten Frame eine andere.
  testWidgets('Kein Tipp während der Wisch-Bewegung', (tester) async {
    await starte(tester);
    await antworteRichtig(tester);

    // 1100 ms bis zum Weiterschalten, danach läuft die Bewegung.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 150));

    final standVorher = tester.widget<Text>(find.text('1')).data;
    expect(standVorher, '1', reason: 'Nach einer richtigen Antwort steht 1');

    // Mitten in die Bewegung tippen — beide Hälften.
    await tester.tapAt(tester.getRect(find.byKey(kHlObenKey)).center);
    await tester.tapAt(tester.getRect(find.byKey(kHlUntenKey)).center);
    await tester.pump(const Duration(milliseconds: 100));

    // Der Punktestand darf sich nicht bewegt haben, und es darf keine
    // Auflösung angestossen worden sein.
    expect(find.text('1'), findsOneWidget,
        reason: 'Ein Tipp während der Bewegung hat gezählt');

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1'), findsOneWidget,
        reason: 'Nach der Bewegung steht der Stand unverändert bei 1');
  });

  testWidgets('Kein Haken bei der richtigen Antwort', (tester) async {
    await starte(tester);
    await antworteRichtig(tester);

    final haken = find.byIcon(Icons.check_circle_rounded).evaluate().length;
    await laufeAus(tester);

    expect(haken, 0, reason: 'Die grüne Fläche allein trägt die Rückmeldung');
  });

  for (final b in [320.0, 384.0]) {
    for (final skala in [1.0, 1.5]) {
      // Geprüft wird die Trefferzahl, nicht mehr der Spielname: Der Titel ist
      // aus den Kopfzeilen aller vier Challenges verschwunden, und an seine
      // Stelle in der Mitte ist die laufende Serie gerückt.
      testWidgets('Trefferzahl mittig und ohne Überlappung: ${b.toInt()} px, '
          'Skala $skala', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(b, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.theme,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(b, 844),
              textScaler: TextScaler.linear(skala),
            ),
            child: const HigherLowerScreen(),
          ),
        ));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.text('Higher or Lower'), findsNothing,
            reason: 'Der Spielname gehört nicht mehr in die Kopfzeile');

        // Die Serie steht bei 0, solange nichts geraten wurde.
        final treffer = tester.getRect(find.text('0'));
        final zurueck = tester.getRect(find.byIcon(Icons.arrow_back_rounded));
        final hilfe = tester.getRect(find.byIcon(Icons.help_outline_rounded));

        // ignore: avoid_print
        print('${b.toInt()}px/$skala  Treffer ${treffer.left.toStringAsFixed(1)}'
            '–${treffer.right.toStringAsFixed(1)} '
            '(Mitte ${treffer.center.dx.toStringAsFixed(1)}, Soll ${b / 2}) '
            '| zurück bis ${zurueck.right.toStringAsFixed(1)} '
            '| Hilfe ab ${hilfe.left.toStringAsFixed(1)}');

        expect(treffer.center.dx, moreOrLessEquals(b / 2, epsilon: 0.5),
            reason: 'Die Trefferzahl steht nicht in der Mitte');
        expect(treffer.left, greaterThan(zurueck.right),
            reason: 'Die Trefferzahl überlappt den Zurück-Knopf');
        expect(treffer.right, lessThan(hilfe.left),
            reason: 'Die Trefferzahl überlappt den Erklärungs-Knopf');
      });
    }
  }

  testWidgets('Keine Rekord-Zeile im Kopf', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HigherLowerScreen()));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining('Rekord'), findsNothing);
  });

  /// Die Rückmeldung muss auf der ANGETIPPTEN Hälfte landen.
  ///
  /// Der kaputte Fall war: oben tippen ("der verdeckte Wert ist NIEDRIGER"),
  /// recht haben — und die Bestätigung trotzdem unten sehen, an einer Karte,
  /// die man gar nicht gewählt hatte.
  ///
  /// Ob "oben" heute gleich in der ersten Runde die richtige Antwort ist,
  /// hängt am Tagesseed. Der Test spielt deshalb richtig weiter, bis so eine
  /// Runde kommt — falsch antworten geht nicht, das beendet die Runde und
  /// schriebe in die Rangliste, wozu im Test kein Firebase bereitsteht.
  testWidgets('Gefärbt wird die angetippte Seite, nicht immer die untere',
      (tester) async {
    await starte(tester);

    final schalter = [find.byKey(kHlObenKey), find.byKey(kHlUntenKey)];
    final kat = kategorie(tester, schalter[0]);

    // Die aufgedeckte Hälfte färbt über eine AnimatedContainer-Dekoration,
    // die verdeckte über einen schlichten Container. Seit die beiden Hälften
    // nicht mehr in AnimatedSwitchern liegen, steht in der verdeckten Hälfte
    // KEIN AnimatedContainer mehr — vorher fand sich dort während der
    // Überblendung noch der ausgehende aufgedeckte. Der Test liest deshalb
    // beide Bauarten.
    Color? flaechenFarbe(int haelfte) {
      final farbig = find.descendant(
        of: schalter[haelfte],
        matching: find.byWidgetPredicate((w) =>
            (w is AnimatedContainer && w.decoration is BoxDecoration) ||
            (w is Container && w.color != null)),
      );
      final w = tester.widget(farbig.first);
      if (w is AnimatedContainer) {
        return (w.decoration as BoxDecoration).color;
      }
      return (w as Container).color;
    }

    for (var runde = 0; runde < 12; runde++) {
      final oben = countryRankings
          .firstWhere((c) => c.name == land(tester, schalter[0]));
      final unten = countryRankings
          .firstWhere((c) => c.name == land(tester, schalter[1]));
      final obenIstRichtig = kat.getValue(unten)! <= kat.getValue(oben)!;

      await tester.tapAt(tester.getRect(schalter[obenIstRichtig ? 0 : 1]).center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      if (obenIstRichtig) {
        final obenFarbe = flaechenFarbe(0);
        final untenFarbe = flaechenFarbe(1);
        await laufeAus(tester);

        expect(obenFarbe, kHlRichtigFlaeche,
            reason: 'Oben getippt und richtig — oben muss grün sein');
        expect(untenFarbe, kHintergrund,
            reason: 'Die nicht gewählte Hälfte bleibt ungefärbt');
        return;
      }
      await laufeAus(tester);
    }
    fail('In 12 Runden kam kein Fall vor, in dem "oben" die richtige '
        'Antwort ist — der eigentliche Fall wurde nicht geprüft.');
  });
}
