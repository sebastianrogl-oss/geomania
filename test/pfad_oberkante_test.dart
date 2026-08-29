import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/screens/home_screen.dart';
import 'package:geomania/theme/app_theme.dart';

/// Über der ersten Station steht eine START-Blase, solange diese Station noch
/// nicht abgeschlossen ist. Fällt sie weg, muss der Pfad um ihre Höhe nach
/// oben rücken — sonst bleibt oben eine leere Fläche stehen.
///
/// Geprüft wird beides zusammen:
///
///  * Die Gesamthöhe des Pfades schrumpft um genau diesen Betrag.
///  * Die Deko rückt um DENSELBEN Betrag mit. Sie hängt an den Wegpunkten der
///    Stationen; liefen die beiden auseinander, säßen Wahrzeichen, Coiny und
///    Globus plötzlich neben statt an ihren Stationen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// [_kBlasenPlatz] in home_screen.dart: 106 px Blasen-Oberkante minus
  /// 45 px Knopfradius.
  const blasenPlatz = 61.0;

  Future<({double hoehe, double deko, bool blase})> baue(
    WidgetTester tester, {
    required Map<String, Object> prefs,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = const Size(384, 805);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.theme,
      home: const HomeScreen(),
    ));
    // Statt pumpAndSettle: Der Pulsier-Ring der aktiven Station läuft
    // dauerhaft, ein pumpAndSettle liefe in die Zeitüberschreitung.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    final scroll = find.byType(SingleChildScrollView);
    final hoehe = tester
        .getSize(
            find.descendant(of: scroll, matching: find.byType(SizedBox)).first)
        .height;

    var oben = double.infinity;
    final bilder = find.descendant(of: scroll, matching: find.byType(Image));
    for (var i = 0; i < tester.widgetList(bilder).length; i++) {
      final r = tester.getRect(bilder.at(i));
      if (r.top < oben) oben = r.top;
    }

    return (
      hoehe: hoehe,
      deko: oben,
      blase: find.text('START').evaluate().isNotEmpty,
    );
  }

  // Zwei getrennte Tests statt zweier pumpWidget-Aufrufe in einem: Ein
  // zweites pumpWidget übernähme den bestehenden State des HomeScreen samt
  // geladenem Snapshot, der geänderte Fortschritt käme gar nicht an.
  ({double hoehe, double deko, bool blase})? mitBlase;

  testWidgets('Frischer Stand: die START-Blase steht', (tester) async {
    mitBlase = await baue(tester, prefs: {});
    expect(mitBlase!.blase, isTrue);
  });

  testWidgets('Ohne die START-Blase rückt der ganze Pfad nach oben',
      (tester) async {
    final erste = lernwelten.first.abschnitte.first.stationen.first.id;
    final ohneBlase = await baue(tester, prefs: {'lp_s_done_$erste': true});
    expect(ohneBlase.blase, isFalse,
        reason: 'Nach der ersten Station ist die Blase weg');

    final vorher = mitBlase!;
    expect(vorher.hoehe - ohneBlase.hoehe, closeTo(blasenPlatz, 0.5),
        reason: 'Der Pfad muss um die Höhe der Blase kürzer werden');
    expect(vorher.deko - ohneBlase.deko, closeTo(blasenPlatz, 0.5),
        reason: 'Die Deko muss um denselben Betrag mitwandern — sonst laufen '
            'Wegpunkte und Höhen auseinander');
  });
}
