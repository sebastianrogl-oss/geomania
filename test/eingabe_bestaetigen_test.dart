import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/screens/station_quiz_screen.dart';

// ── Der Bestätigen-Knopf in den Eingabe-Modi ─────────────────────────────────
//
// Nach der Bewertung ist die Eingabe abgeschlossen — dann gehört der Knopf
// weg. Vorher blieb er als grauer Klotz stehen und stand gleichzeitig mit dem
// Weiter-Knopf am Bildschirmfuß da: zwei Knöpfe, von denen einer nichts tut.
//
// Geprüft wird für alle drei Eingabe-Modi und für BEIDE Ausgänge. Richtig und
// falsch teilen sich dieselbe Bedingung, aber genau das ist der Punkt: Es
// soll gar nicht erst wieder auseinanderlaufen.
//
// Die richtige Antwort steht nirgends im Test. Sie wird der App abgelesen:
// Bei einem Länderpool aus genau einem Land ist die Frage eindeutig, und
// nach einer falschen Antwort nennt der Screen die Lösung („Richtig war: X").
// Der zweite Durchgang tippt sie ein. Damit hängt der Test an keiner
// Länderliste, die sich morgen ändern kann.

/// [lauf] unterscheidet zwei Durchgänge desselben Modus.
///
/// Der Screen merkt sich einen angefangenen Stand unter der Stations-ID. Ohne
/// eigene ID setzte der zweite Durchgang die schon beantwortete Frage fort,
/// statt neu anzufangen.
LernStation _station(LernModus modus, List<String> laender, {int lauf = 1}) =>
    LernStation(
      id: 'test_${modus.name}_$lauf',
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
  // Der Key gehört dazu: Ohne ihn erkennt Flutter beim zweiten Aufruf
  // denselben Widget-Typ an derselben Stelle, aktualisiert nur und behält den
  // alten State — der zweite Durchgang startete dann mit bereits bestätigter
  // Eingabe.
  await tester.pumpWidget(MaterialApp(
    home: StationQuizScreen(key: ValueKey(station.id), station: station),
  ));
  await tester.pumpAndSettle();
}

/// Die Lösung aus der Rückmeldezeile „Richtig war: X".
String _loesungAusRueckmeldung(WidgetTester tester) {
  final zeile = tester
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data ?? '')
      .firstWhere((s) => s.startsWith('Richtig war: '),
          orElse: () => throw StateError('keine Rückmeldezeile gefunden'));
  return zeile.substring('Richtig war: '.length);
}

void main() {
  // Je Modus ein Länderpool aus genau EINEM Land — damit ist die Frage
  // eindeutig und die Lösung wiederholbar.
  const faelle = {
    LernModus.hauptstaedteEingabe: ['DE'],
    LernModus.flaggenQuizEingabe: ['FR'],
  };

  faelle.forEach((modus, laender) {
    group(modus.name, () {
      testWidgets('vor der Antwort steht der Knopf da', (tester) async {
        await _pump(tester, _station(modus, laender));
        expect(find.text('Bestätigen'), findsOneWidget);
        expect(find.text('Weiter'), findsOneWidget,
            reason: 'der Weiter-Knopf ist immer im Baum, nur unsichtbar');
      });

      testWidgets('nach FALSCHER Antwort ist er weg', (tester) async {
        await _pump(tester, _station(modus, laender));
        await tester.enterText(find.byType(TextField), 'zzz-daneben');
        await tester.tap(find.text('Bestätigen'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('Bestätigen'), findsNothing,
            reason: 'der graue Klotz steht wieder unter dem Feedback');
        expect(find.textContaining('Richtig war: '), findsOneWidget);
        expect(find.text('Weiter'), findsOneWidget);
      });

      testWidgets('nach RICHTIGER Antwort ist er weg', (tester) async {
        // Erster Durchgang: absichtlich daneben, um die Lösung abzulesen.
        await _pump(tester, _station(modus, laender));
        await tester.enterText(find.byType(TextField), 'zzz-daneben');
        await tester.tap(find.text('Bestätigen'));
        await tester.pump(const Duration(milliseconds: 300));
        final loesung = _loesungAusRueckmeldung(tester);

        // Zweiter Durchgang, dieselbe Frage, diesmal richtig.
        await _pump(tester, _station(modus, laender, lauf: 2));
        await tester.enterText(find.byType(TextField), loesung);
        await tester.tap(find.text('Bestätigen'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.text('Richtig!'), findsOneWidget,
            reason: 'die abgelesene Lösung "$loesung" wurde nicht anerkannt');
        expect(find.text('Bestätigen'), findsNothing);
        expect(find.text('Weiter'), findsOneWidget);
      });
    });
  });

  // ── umrissEingabe fehlt hier, und zwar bewusst ────────────────────────────
  //
  // Der Modus wartet auf die Länderumrisse aus einem rootBundle-Asset. Im
  // Widget-Test kommen sie nie an, der Screen bleibt beim Ladekreisel stehen
  // und baut die Eingabe-Oberfläche gar nicht erst auf — dieselbe Ausnahme,
  // die in station_ui_test.dart für umrissBild/umrissMultiple vermerkt ist.
  //
  // Der Knopf steckt in _EingabeUI, und diese Oberfläche teilen sich alle
  // drei Eingabe-Modi. Was hier für Hauptstädte und Flaggen geprüft ist, gilt
  // damit auch für den Umriss; eigenes Verhalten hat er an dieser Stelle
  // nicht. Nachgesehen wurde er am Gerät.
}
