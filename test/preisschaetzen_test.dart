import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geomania/data/countries.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/screens/station_quiz_screen.dart';
import 'package:geomania/services/station_session_service.dart';

void main() {
  // Beides MUSS hier oben stehen, nicht erst im einzelnen Test: die Prüfungen
  // rufen den Fragen-Generator auf, der über
  // FortschrittService.istStationAbgeschlossen SharedPreferences liest. Ohne
  // initialisiertes Binding gibt es keinen Kanal für den Mock, und der Aufruf
  // scheitert mit MissingPluginException — nicht am Prüfgegenstand, sondern
  // am fehlenden Gerüst.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('Preisschätzen-Länder kommen immer aus dem Kontinent des Abschnitts', () async {
    int stationenGeprueft = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.preisSchaetzen) continue;
          stationenGeprueft++;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          if (welt.kontinent == 'Welt') continue; // Mix ist dort ok
          for (final f in fragen) {
            final co = countries.firstWhere((c) => c.iso2 == f.laenderCode);
            expect(co.region, welt.kontinent,
                reason: '${s.id}: ${f.laenderCode} (${co.region}) passt nicht zu ${welt.kontinent}');
          }
        }
      }
    }
    expect(stationenGeprueft, greaterThan(0));
  });

  test('Preisschätzen-Kategorie hat für das gezeigte Land immer echte Daten', () async {
    int fragenGeprueft = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.preisSchaetzen) continue;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          for (final f in fragen) {
            fragenGeprueft++;
            final wert = double.tryParse(f.richtigeAntwort);
            expect(wert, isNotNull, reason: '${f.id}: richtigeAntwort nicht parsebar');
            // Skala muss zum tatsächlichen Wert passen (kein 0-Fallback-Bereich).
            final min = (f.meta['min'] as num).toDouble();
            final max = (f.meta['max'] as num).toDouble();
            expect(wert! >= min && wert <= max * 1.01, true,
                reason: '${f.id}: Wert $wert außerhalb Skala [$min, $max] (Kategorie ${f.meta['kategorie']})');
          }
        }
      }
    }
    expect(fragenGeprueft, greaterThan(0));
  });

  test('Preisschätzen nutzt mehrere verschiedene Kategorien', () async {
    final gefunden = <String>{};
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.preisSchaetzen) continue;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          for (final f in fragen) {
            gefunden.add(f.meta['kategorie'] as String);
          }
        }
      }
    }
    // ignore: avoid_print
    print('Gefundene Preisschätzen-Kategorien: $gefunden');
    expect(gefunden.length, greaterThan(1));
    // kuestenlange hat keine kalibrierte Skala -> darf hier nie auftauchen.
    expect(gefunden.contains('kuestenlange'), false);
  });

  test('Skala ist adaptiv: kleines Land bekommt kleine Skala (nicht die feste Kontinent-Breite)', () async {
    // Vatikanstadt (Bevölkerung ~800) und Russland (Bevölkerung ~143 Mio)
    // sind beide in Europa — die Skalen dürfen sich nicht ähneln.
    //
    // Die 60 Fragen sind kein Selbstzweck: _preisSchaetzen zieht die Kategorie
    // je Frage ZUFÄLLIG aus allen, für die das Land echte Daten hat, und die
    // Station lässt sich nicht auf eine Kategorie festlegen. Mit den früheren
    // 20 Fragen war die Wahrscheinlichkeit, dass "bevoelkerung" bei Russland
    // (sieben gültige Kategorien) gar nicht vorkommt, rund 5 % — der Test
    // schlug damit etwa in jedem zwanzigsten Lauf fehl, ohne dass irgendetwas
    // kaputt war. Mit 60 Ziehungen liegt sie unter 0,1 Promille.
    const kZiehungen = 60;

    final vatikanFragen = await FragenGenerator.generiereFragenFuerStation(LernStation(
      id: 'test_va', modus: LernModus.preisSchaetzen, fragenAnzahl: kZiehungen,
      laenderCodes: const ['VA'], kategorien: const [], schwierigkeitsgrad: 1,
    ));
    final vatikan =
        vatikanFragen.where((f) => f.meta['kategorie'] == 'bevoelkerung').toList();
    final russlandFragen = await FragenGenerator.generiereFragenFuerStation(LernStation(
      id: 'test_ru', modus: LernModus.preisSchaetzen, fragenAnzahl: kZiehungen,
      laenderCodes: const ['RU'], kategorien: const [], schwierigkeitsgrad: 1,
    ));
    final russland =
        russlandFragen.where((f) => f.meta['kategorie'] == 'bevoelkerung').toList();

    expect(vatikan, isNotEmpty);
    expect(russland, isNotEmpty);
    final vatikanMax = (vatikan.first.meta['max'] as num).toDouble();
    final russlandMax = (russland.first.meta['max'] as num).toDouble();
    // ignore: avoid_print
    print('Vatikan-Skala max=$vatikanMax, Russland-Skala max=$russlandMax');
    expect(vatikanMax, lessThan(50000));
    expect(russlandMax, greaterThan(100000000));
  });

  test('Startwert liegt nicht in der Mitte der Skala', () async {
    int nichtMittigGezaehlt = 0;
    int gesamt = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.preisSchaetzen) continue;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          for (final f in fragen) {
            gesamt++;
            final min = (f.meta['min'] as num).toDouble();
            final max = (f.meta['max'] as num).toDouble();
            final start = (f.meta['start'] as num).toDouble();
            final mitte = (min + max) / 2;
            if ((start - mitte).abs() > 0.01 * (max - min)) nichtMittigGezaehlt++;
          }
        }
      }
    }
    // ignore: avoid_print
    print('$nichtMittigGezaehlt von $gesamt Startwerten sind nicht mittig');
    expect(nichtMittigGezaehlt, gesamt); // ausnahmslos alle
  });

  testWidgets('Preisschätzen-UI: nach Bestätigen erscheinen echter Wert + Abweichung + Weiter-Button, kein Auto-Advance',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final station = LernStation(
      id: 'test_preis',
      modus: LernModus.preisSchaetzen,
      fragenAnzahl: 3,
      laenderCodes: const ['DE', 'FR', 'IT', 'ES', 'PL', 'SE', 'NO', 'GR'],
      kategorien: const [],
      schwierigkeitsgrad: 2,
    );
    await tester.pumpWidget(MaterialApp(home: StationQuizScreen(station: station)));
    await tester.pumpAndSettle();

    expect(find.text('Schätzung bestätigen'), findsOneWidget);
    await tester.tap(find.text('Schätzung bestätigen'));
    await tester.pump();

    expect(find.textContaining('Tatsächlicher Wert'), findsOneWidget);
    expect(find.textContaining('Du lagst'), findsOneWidget);
    expect(find.text('Weiter'), findsOneWidget);
    // Slider ist in der Ergebnis-Ansicht nicht mehr da.
    expect(find.byType(Slider), findsNothing);

    // Kein Auto-Advance auch nach mehreren Sekunden.
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Tatsächlicher Wert'), findsOneWidget);

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tatsächlicher Wert'), findsNothing);
  });
}
