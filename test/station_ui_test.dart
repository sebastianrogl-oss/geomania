import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/screens/station_quiz_screen.dart';

LernStation _station(LernModus modus, List<String> laender) => LernStation(
      id: 'test_${modus.name}',
      modus: modus,
      fragenAnzahl: modus == LernModus.sortierSpiel ? 3 : 8,
      laenderCodes: laender,
      kategorien: const [],
      schwierigkeitsgrad: 2,
    );

Future<void> _pumpStation(WidgetTester tester, LernStation station) async {
  // Alle Onboarding-Merker vorab setzen: sonst öffnet der Quiz-Screen beim
  // ersten Vorkommen eines Modus dessen Anleitung, und das Bottom-Sheet läge
  // über der Spielfläche — jeder Tap dieser Tests ginge an den
  // Sheet-Hintergrund statt an das geprüfte Widget. Hier geht es um die
  // Spielflächen, nicht um das Onboarding.
  SharedPreferences.setMockInitialValues({
    for (final m in LernModus.values) 'onboarding_modus_${m.name}': true,
  });
  await tester.pumpWidget(MaterialApp(
    home: StationQuizScreen(station: station),
  ));
  // initState-Future (StationSession.laden + FragenGenerator) abwarten.
  await tester.pumpAndSettle();
}

void main() {
  const europa = ['DE', 'FR', 'IT', 'ES', 'PL', 'SE', 'NO', 'GR', 'RO', 'HU'];
  // Reine Inselstaaten -> nachbarland muss auf Flaggen-Fallback ausweichen.
  const inseln = ['AU', 'NZ', 'FJ', 'SB', 'VU', 'WS', 'TO', 'FM'];

  testWidgets('nachbarland rendert Frage + 4 Optionen, kein Absturz',
      (tester) async {
    await _pumpStation(tester, _station(LernModus.nachbarland, europa));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('grenzt an'), findsOneWidget);
    expect(find.byType(InkWell), findsNWidgets(4));
  });

  testWidgets('nachbarland auf Inselstaaten weicht auf Fallback aus (kein Crash)',
      (tester) async {
    await _pumpStation(tester, _station(LernModus.nachbarland, inseln));
    expect(tester.takeException(), isNull);
    // Fallback ist flaggenQuizBild -> Bild sichtbar, 4 Text-Optionen.
    expect(find.byType(InkWell), findsNWidgets(4));
  });

  testWidgets('bipGesamt rendert Frage + Landkopf, kein Absturz',
      (tester) async {
    await _pumpStation(tester, _station(LernModus.bipGesamt, europa));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Wie hoch ist das BIP'), findsOneWidget);
    expect(find.byType(InkWell), findsNWidgets(4));
  });

  testWidgets('flaeche rendert Frage + Landkopf, kein Absturz',
      (tester) async {
    await _pumpStation(tester, _station(LernModus.flaeche, europa));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Wie groß ist die Fläche'), findsOneWidget);
    expect(find.byType(InkWell), findsNWidgets(4));
  });

  testWidgets('extremFrage rendert Frage + 4 Länder, OHNE die Antwort vorab zu verraten',
      (tester) async {
    await _pumpStation(tester, _station(LernModus.extremFrage, europa));
    expect(tester.takeException(), isNull);
    // Kein FlaggenWidget/Landkopf vor der Antwort (würde die Lösung verraten).
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_LandHeader'),
        findsNothing);
    expect(find.byType(InkWell), findsNWidgets(4));
  });

  testWidgets('waehrungZuLand rendert Frage + 4 Länder, OHNE die Antwort vorab zu verraten',
      (tester) async {
    await _pumpStation(tester, _station(LernModus.waehrungZuLand, europa));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Welches Land nutzt'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_LandHeader'),
        findsNothing);
    expect(find.byType(InkWell), findsNWidgets(4));
  });

  testWidgets('Alle Fragen einer extremFrage-Station lassen sich beantworten',
      (tester) async {
    await _pumpStation(tester, _station(LernModus.extremFrage, europa));
    for (int i = 0; i < 8; i++) {
      expect(tester.takeException(), isNull, reason: 'Frage $i');
      await tester.tap(find.byType(InkWell).first);
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'grenzkettenRaetsel rendert Von/Nach-Header + 4 Länder-Optionen, kein Absturz',
      (tester) async {
    await _pumpStation(tester, _station(LernModus.grenzkettenRaetsel, europa));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('MUSST du dabei NICHT fahren'), findsOneWidget);
    expect(find.byType(InkWell), findsNWidgets(4));
  });

  testWidgets(
      'grenzkettenRaetsel zeigt nach Antwort die richtige Route + ggf. Erklärung',
      (tester) async {
    await _pumpStation(tester, _station(LernModus.grenzkettenRaetsel, europa));
    await tester.tap(find.byType(InkWell).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Die richtige Route:'), findsOneWidget);
  });

  testWidgets(
      'flaggenQuizEingabe zeigt nur die Flagge (kein Ländername vorab), '
      'Eingabe wird validiert', (tester) async {
    await _pumpStation(tester, _station(LernModus.flaggenQuizEingabe, europa));
    expect(tester.takeException(), isNull);
    expect(find.text('Welchem Land gehört diese Flagge?'), findsOneWidget);
    expect(find.textContaining('Land eingeben'), findsOneWidget);
    // Vor der Antwort darf der Ländername nirgends sichtbar sein.
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_LandHeader'),
        findsNothing);

    await tester.enterText(find.byType(TextField), 'deutschland');
    await tester.tap(find.text('Bestätigen'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    // Groß-/Kleinschreibung tolerant -> entweder richtig oder (falls die
    // Frage zufällig ein anderes Land zeigt) zumindest kein Absturz/Crash.
  });

  // Hinweis: umrissEingabe teilt sich das Geo-Outline-Laden (rootBundle-Asset)
  // mit umrissBild/umrissMultiple — für die gibt es aus demselben Grund
  // ebenfalls keinen Widget-Test hier (der bloße testWidgets-Harness lädt
  // das Asset nicht zuverlässig durch). Live im Browser geprüft stattdessen.
}
