import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geomania/data/countries.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/screens/station_quiz_screen.dart';
import 'package:geomania/services/station_session_service.dart';

void main() {
  test('Sortierspiel-Länder kommen immer aus dem Kontinent des Abschnitts', () async {
    // Über den gesamten Lernpfad: für jede sortierSpiel-Station müssen alle
    // in den Fragen verwendeten Länder zum Kontinent der Welt gehören
    // (bei "Welt"-Abschnitten ist Kontinent-Mix erlaubt).
    int stationenGeprueft = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.sortierSpiel) continue;
          stationenGeprueft++;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          for (final f in fragen) {
            final laender = (f.meta['laenderCodes'] as List).cast<String>();
            if (welt.kontinent == 'Welt') continue; // Mix ist dort ok
            for (final iso2 in laender) {
              final co = countries.firstWhere((c) => c.iso2 == iso2);
              expect(co.region, welt.kontinent,
                  reason: '${s.id}: $iso2 (${co.region}) passt nicht zu ${welt.kontinent}');
            }
          }
        }
      }
    }
    expect(stationenGeprueft, greaterThan(0));
  });

  test('Sortierspiel-Kategorie hat für alle 5 gezeigten Länder echte Daten (keine 0-Fallbacks)', () async {
    int fragenGeprueft = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.sortierSpiel) continue;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          for (final f in fragen) {
            fragenGeprueft++;
            final werte = (f.meta['werte'] as Map).cast<String, dynamic>();
            for (final v in werte.values) {
              expect(v, isNotNull, reason: '${f.id}: fehlender Wert für Kategorie ${f.meta['kategorie']}');
            }
          }
        }
      }
    }
    expect(fragenGeprueft, greaterThan(0));
  });

  test('Sortierspiel nutzt mehrere verschiedene Kategorien (nicht nur Bevölkerung)', () async {
    final gefundeneKategorien = <String>{};
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.sortierSpiel) continue;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          for (final f in fragen) {
            gefundeneKategorien.add(f.meta['kategorie'] as String);
          }
        }
      }
    }
    // ignore: avoid_print
    print('Gefundene Sortier-Kategorien: $gefundeneKategorien');
    expect(gefundeneKategorien.length, greaterThan(1));
  });

  test('Sortierspiel sortiert absteigend (größte zuerst)', () async {
    int fragenGeprueft = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.sortierSpiel) continue;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          for (final f in fragen) {
            fragenGeprueft++;
            final laender = f.richtigeAntwort.split(',');
            final werte = (f.meta['werte'] as Map).cast<String, dynamic>();
            for (int i = 1; i < laender.length; i++) {
              final vorher = (werte[laender[i - 1]] as num).toDouble();
              final jetzt = (werte[laender[i]] as num).toDouble();
              expect(vorher >= jetzt, true,
                  reason: '${f.id}: nicht absteigend sortiert (${laender[i-1]}=$vorher vor ${laender[i]}=$jetzt)');
            }
          }
        }
      }
    }
    expect(fragenGeprueft, greaterThan(0));
  });

  test('Kategorie-Header ist "Sortiere nach: X (größte zuerst)" und bleibt pro Frage konstant', () async {
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.sortierSpiel) continue;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          for (final f in fragen) {
            expect(f.frage, startsWith('Sortiere nach: '));
            expect(f.frage, contains('(größte zuerst)'));
            expect(f.frage, contains(f.meta['kategorieLabel'] as String));
          }
        }
      }
    }
  });

  test('Sortierspiel nutzt EINE Kategorie für die ganze Station (alle Runden gleich)', () async {
    int stationenGeprueft = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.sortierSpiel) continue;
          stationenGeprueft++;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          final kategorien = fragen.map((f) => f.meta['kategorie']).toSet();
          expect(kategorien.length, 1,
              reason: '${s.id}: Runden nutzen unterschiedliche Kategorien: $kategorien');
        }
      }
    }
    expect(stationenGeprueft, greaterThan(0));
  });

  testWidgets('Sortierspiel-UI: nach Prüfen erscheint korrekte Reihenfolge mit Werten + Weiter-Button, kein Auto-Advance',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final station = LernStation(
      id: 'test_sortier',
      modus: LernModus.sortierSpiel,
      fragenAnzahl: 3,
      laenderCodes: const ['DE', 'FR', 'IT', 'ES', 'PL', 'SE', 'NO', 'GR'],
      kategorien: const [],
      schwierigkeitsgrad: 2,
    );
    await tester.pumpWidget(MaterialApp(home: StationQuizScreen(station: station)));
    await tester.pumpAndSettle();

    expect(find.text('Reihenfolge prüfen'), findsOneWidget);
    // Kategorie bleibt während der Runde sichtbar und konstant.
    expect(find.textContaining('Sortiere nach:'), findsOneWidget);
    expect(find.textContaining('(größte zuerst)'), findsOneWidget);
    await tester.tap(find.text('Reihenfolge prüfen'));
    await tester.pump();
    // Direkt nach dem Tap: Ergebnis-Ansicht mit korrekter Reihenfolge, OHNE
    // dass automatisch weitergesprungen wird (kein Timer mehr).
    expect(find.textContaining('Richtig (nach'), findsOneWidget);
    expect(find.text('Weiter'), findsOneWidget);

    // Auch nach 3 Sekunden warten: UI bleibt stehen (kein Auto-Advance).
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Richtig (nach'), findsOneWidget);

    // Erst der manuelle Tap auf "Weiter" bringt die nächste Frage.
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Richtig (nach'), findsNothing);
  });
}
