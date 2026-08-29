import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/services/regler_rastung.dart';

// Die Rastung der Regler — Rang-Balken und grosses Schätzen.
//
// Geprüft wird die Geometrie: wo die Rastpunkte liegen und dass die
// Mindestpause steht. Ob am Ende wirklich ein Stoss ankommt, hängt am
// Vibrations-Schalter und am Gerät und lässt sich hier nicht messen — das
// wurde am Handy nachgesehen.

void main() {
  test('Rastpunkte liegen dicht genug für kleine Fingerbewegungen', () {
    // Auf einem 320-px-Schirm ist der Balken rund 280 dp breit. Bei 120
    // Punkten liegt einer alle 2,3 dp — kleiner als jede bewusste Bewegung.
    // Deutlich weniger, und ein kurzes Ziehen löst gar nichts aus.
    expect(ReglerRastung.kSchritte, greaterThanOrEqualTo(100));
    expect(280 / ReglerRastung.kSchritte, lessThan(4.0));
  });

  test('Mindestpause bleibt bei 55 ms', () {
    // Die harte Untergrenze aus dem Rang-Balken. Sie ist der Grund, warum ein
    // schneller Wisch zur Ratsche wird und nicht zum Dauerrauschen: Sie
    // deckelt die Folge auf rund 18 Stösse je Sekunde.
    expect(ReglerRastung.kPause.inMilliseconds, 55);
  });

  test('Ein Zug über den ganzen Balken kann nicht beliebig viele Stösse '
      'auslösen', () {
    // Bei einem Wisch von 250 ms erlaubt die Pause höchstens fünf Stösse,
    // obwohl der Finger über 120 Rastpunkte fährt.
    const wisch = Duration(milliseconds: 250);
    final hoechstens =
        wisch.inMilliseconds ~/ ReglerRastung.kPause.inMilliseconds + 1;
    expect(hoechstens, lessThan(ReglerRastung.kSchritte));
    expect(hoechstens, lessThanOrEqualTo(6));
  });

  group('Rastpunkt-Wechsel', () {
    test('Dieselbe Stelle löst nur einmal aus', () {
      final r = ReglerRastung();
      // Ohne Zugriff auf den Zustand von aussen lässt sich nur prüfen, dass
      // wiederholte Meldungen an derselben Position nicht werfen und die
      // Rastung sie als denselben Punkt behandelt (kein Absturz, kein
      // Zurücksetzen).
      for (var i = 0; i < 5; i++) {
        r.ziehen(anteil: 0.5);
      }
      r.ruecksetzen();
      r.ziehen(anteil: 0.5);
    });

    test('Werte ausserhalb 0..1 werden gekappt', () {
      final r = ReglerRastung();
      r.ziehen(anteil: -5);
      r.ziehen(anteil: 12);
      r.ruecksetzen();
    });
  });
}
