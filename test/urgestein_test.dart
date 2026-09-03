import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/services/abzeichen_service.dart';
import 'package:geomania/services/urgestein_service.dart';

/// Das Urgestein für Bestandsspieler.
///
/// Geprüft wird in BEIDE Richtungen, und die zweite ist die wichtigere: Ein
/// Bestandsspieler, der leer ausgeht, ist ärgerlich — ein Neuling, der die
/// Ehrung "Du warst von Anfang an dabei" am ersten Tag bekommt, macht sie für
/// alle wertlos.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<bool> hatUrgestein() async =>
      (await AbzeichenService.getFreigeschaltete()).contains('urgestein');

  group('Bestandsspieler bekommt es', () {
    test('mit Sternen im Lernpfad', () async {
      SharedPreferences.setMockInitialValues({'lp_gesamt_richtig': 42});
      await UrgesteinService.pruefeBeimStart();
      expect(await hatUrgestein(), isTrue);
      expect(await UrgesteinService.popupOffen(), isTrue);
    });

    test('mit einer abgeschlossenen Station, aber ohne Sterne', () async {
      // Sterne gibt es erst beim ERSTEN Abschluss einer Station; wer eine
      // Station wiederholt hat, kann abgeschlossene Stationen ohne
      // Sternzuwachs haben.
      SharedPreferences.setMockInitialValues({'lp_s_done_europa_1_01': true});
      await UrgesteinService.pruefeBeimStart();
      expect(await hatUrgestein(), isTrue);
    });

    test('wenn nur Tages-Challenges gespielt wurden', () async {
      // Wer den Lernpfad nie angefasst hat, ist trotzdem ein
      // Bestandsspieler.
      SharedPreferences.setMockInitialValues({'anzahlGespielt_preis': 3});
      await UrgesteinService.pruefeBeimStart();
      expect(await hatUrgestein(), isTrue);
    });
  });

  group('Ein frischer Nutzer bekommt es NICHT', () {
    test('beim allerersten Start mit leeren Einstellungen', () async {
      await UrgesteinService.pruefeBeimStart();
      expect(await hatUrgestein(), isFalse);
      expect(await UrgesteinService.popupOffen(), isFalse);
    });

    test('auch nicht, wenn er gleich danach die erste Station spielt',
        () async {
      // DER KERNFALL. Die Prüfung läuft beim Start; danach spielt er. Beim
      // nächsten Start liegt Fortschritt vor — aber die Frage ist längst
      // beantwortet.
      await UrgesteinService.pruefeBeimStart();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lp_gesamt_richtig', 8);
      await prefs.setBool('lp_s_done_europa_1_01', true);

      await UrgesteinService.pruefeBeimStart(); // nächster Start
      expect(await hatUrgestein(), isFalse);
    });

    test('auch nicht nach vielen weiteren Starts', () async {
      await UrgesteinService.pruefeBeimStart();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lp_gesamt_richtig', 500);
      for (var i = 0; i < 5; i++) {
        await UrgesteinService.pruefeBeimStart();
      }
      expect(await hatUrgestein(), isFalse);
    });

    test('der Einstieg allein zählt nicht als Fortschritt', () async {
      // Wer sich nur durch Willkommens-Screen und Namenswahl getippt hat,
      // hat noch nichts gespielt.
      SharedPreferences.setMockInitialValues({
        'onboarding_willkommen': true,
        'einstellung_sprache': 'de',
        'erinnerung_aktiv': true,
      });
      await UrgesteinService.pruefeBeimStart();
      expect(await hatUrgestein(), isFalse);
    });
  });

  group('Die Prüfung läuft genau einmal', () {
    test('der Merker wird auch ohne Verleihung gesetzt', () async {
      // Sonst liefe die Prüfung beim nächsten Start erneut — und ein
      // inzwischen spielender Neuling erschiene als Bestandsspieler.
      await UrgesteinService.pruefeBeimStart();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('urgestein_geprueft'), isTrue);
    });

    test('ein zweiter Aufruf verleiht nichts doppelt', () async {
      SharedPreferences.setMockInitialValues({'lp_gesamt_richtig': 42});
      await UrgesteinService.pruefeBeimStart();
      await UrgesteinService.popupErledigt();
      await UrgesteinService.pruefeBeimStart();
      // Popup bleibt erledigt — es taucht nicht wieder auf.
      expect(await UrgesteinService.popupOffen(), isFalse);
      expect(await hatUrgestein(), isTrue);
    });

    test('wer das Abzeichen schon hat, bekommt kein Popup', () async {
      // Etwa über die Cloud-Zusammenführung von einem anderen Gerät.
      SharedPreferences.setMockInitialValues({
        'lp_gesamt_richtig': 42,
        'abzeichen_freigeschaltet': ['urgestein'],
      });
      await UrgesteinService.pruefeBeimStart();
      expect(await UrgesteinService.popupOffen(), isFalse,
          reason: 'Das Abzeichen war schon da — kein zweites Popup');
    });
  });

  group('Das Popup überlebt einen Neustart', () {
    test('bleibt offen, bis es gezeigt wurde', () async {
      // Zwischen Verleihung und Popup liegen bei einem Bestandsspieler
      // Anmeldung, Namenswahl und Willkommen. Wer dazwischen schliesst, soll
      // es beim nächsten Mal bekommen.
      SharedPreferences.setMockInitialValues({'lp_gesamt_richtig': 42});
      await UrgesteinService.pruefeBeimStart();
      expect(await UrgesteinService.popupOffen(), isTrue);

      await UrgesteinService.pruefeBeimStart(); // App neu gestartet
      expect(await UrgesteinService.popupOffen(), isTrue);

      await UrgesteinService.popupErledigt();
      expect(await UrgesteinService.popupOffen(), isFalse);
    });
  });
}
