import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/screens/station_quiz_screen.dart';

// ── Aus dem Eingabefeld muss man wieder herauskommen ─────────────────────────
//
// Die drei Eingabe-Modi holen sich den Fokus per autofocus, und Android
// schliesst die Tastatur von sich aus nicht. Ohne einen Tipp-Fänger blieb die
// halbe Spielfläche verdeckt — dasselbe Problem wie beim Namensfeld des
// ersten Starts (siehe namensfeld_tastatur_test.dart).
//
// Geprüft wird der Fokus, nicht die Tastatur selbst: Im Test gibt es keine
// Systemtastatur, sie hängt aber genau an diesem Fokus.
//
// umrissEingabe fehlt hier bewusst — der Modus wartet auf ein
// rootBundle-Asset, das im Widget-Test nie ankommt, und baut die Oberfläche
// gar nicht erst auf (siehe eingabe_bestaetigen_test.dart). Alle drei teilen
// sich dieselbe _EingabeUI.

LernStation _station(LernModus modus, List<String> laender) => LernStation(
      id: 'test_tastatur_${modus.name}',
      modus: modus,
      fragenAnzahl: 1,
      laenderCodes: laender,
      kategorien: const [],
      schwierigkeitsgrad: 2,
    );

Future<void> _pump(WidgetTester tester, LernStation station) async {
  SharedPreferences.setMockInitialValues({
    for (final m in LernModus.values) 'onboarding_modus_${m.name}': true,
  });
  await tester.pumpWidget(MaterialApp(
    home: StationQuizScreen(key: ValueKey(station.id), station: station),
  ));
  await tester.pumpAndSettle();
}

bool _feldHatFokus(WidgetTester tester) =>
    tester.state<EditableTextState>(find.byType(EditableText))
        .widget
        .focusNode
        .hasFocus;

void main() {
  const faelle = {
    LernModus.hauptstaedteEingabe: ['DE'],
    LernModus.flaggenQuizEingabe: ['FR'],
  };

  faelle.forEach((modus, laender) {
    testWidgets('${modus.name}: Tipp daneben gibt den Fokus ab',
        (tester) async {
      await _pump(tester, _station(modus, laender));
      expect(_feldHatFokus(tester), isTrue,
          reason: 'autofocus greift nicht mehr');

      // Linker Rand der Spielflaeche: freie Flaeche, kein eigenes Ziel. Die
      // AppBar taugt nicht — sie liegt ausserhalb des Body und damit
      // ausserhalb des Faengers, voellig zu Recht.
      await tester.tapAt(const Offset(20, 300));
      await tester.pump();

      expect(_feldHatFokus(tester), isFalse,
          reason: 'Der Fokus klebt im Feld, die Tastatur bliebe stehen');
    });

    testWidgets('${modus.name}: Der Bestätigen-Knopf funktioniert weiterhin',
        (tester) async {
      // Der Fänger liegt über dem ganzen Body — die Kinder müssen ihre Tipps
      // behalten.
      await _pump(tester, _station(modus, laender));
      await tester.enterText(find.byType(TextField), 'Irgendwas');
      await tester.pump();
      await tester.tap(find.text('Bestätigen'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Bestätigen'), findsNothing,
          reason: 'Die Eingabe wurde nicht bewertet — der Tipp kam nicht an');
    });
  });
}
