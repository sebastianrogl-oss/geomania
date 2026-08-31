import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/services/spielstand_speicher.dart';

/// Die Prefs-Ebene. Geprüft wird vor allem das, was in der Praxis wehtut:
/// dass Geräte-Einstellungen nicht mitfahren, und dass ein Zahlentyp nicht
/// still umkippt.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Lesen', () {
    test('nimmt nur mit, was in die Cloud gehört', () async {
      SharedPreferences.setMockInitialValues({
        'lp_s_done_europa_1_01': true,
        'lp_gesamt_richtig': 42,
        // Diese drei gehören ans Gerät und dürfen nicht auftauchen:
        'einstellung_sound': false,
        'lp_s_richtig_europa_1_01': 7,
        'lp_rr_europa_flaggen': '["de","fr"]',
      });

      final stand = await SpielstandSpeicher.lesen();

      expect(stand['lp_s_done_europa_1_01'], true);
      expect(stand['lp_gesamt_richtig'], 42);
      expect(stand.containsKey('einstellung_sound'), isFalse);
      expect(stand.containsKey('lp_s_richtig_europa_1_01'), isFalse);
      expect(stand.containsKey('lp_rr_europa_flaggen'), isFalse);
    });

    test('ein nie gesetzter Schlüssel fehlt, statt null zu sein', () async {
      // Der Unterschied ist beim Zusammenführen entscheidend: "fehlt" heisst
      // "die andere Seite gewinnt", "ist null" hiesse "leer".
      final stand = await SpielstandSpeicher.lesen();
      expect(stand.containsKey('lp_streak'), isFalse);
      expect(stand['version'], isNotNull);
    });

    test('Listen kommen als eigene Kopie zurück', () async {
      SharedPreferences.setMockInitialValues({
        'abzeichen_freigeschaltet': ['a', 'b'],
      });
      final stand = await SpielstandSpeicher.lesen();
      (stand['abzeichen_freigeschaltet'] as List).add('c');
      // Der Cache der Prefs darf davon nichts mitbekommen.
      final nochmal = await SpielstandSpeicher.lesen();
      expect(nochmal['abzeichen_freigeschaltet'], ['a', 'b']);
    });
  });

  group('Schreiben', () {
    test('legt neue Werte typrichtig an', () async {
      await SpielstandSpeicher.schreiben({
        'lp_s_done_a': true,
        'lp_gesamt_richtig': 7,
        'pf_kapital': 1450.5,
        'lp_letzte_akt': '2026-08-30T10:00:00.000',
        'abzeichen_freigeschaltet': ['x'],
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('lp_s_done_a'), true);
      expect(prefs.getInt('lp_gesamt_richtig'), 7);
      expect(prefs.getDouble('pf_kapital'), 1450.5);
      expect(prefs.getString('lp_letzte_akt'), '2026-08-30T10:00:00.000');
      expect(prefs.getStringList('abzeichen_freigeschaltet'), ['x']);
    });

    test('eine Kommazahl bleibt eine Kommazahl, auch wenn sie ganz ankommt',
        () async {
      // Der gefährlichste Fall der ganzen Ebene: Über JSON wird aus 1450.0
      // schnell einmal die Ganzzahl 1450. Würde die per setInt geschrieben,
      // liefe jedes spätere getDouble('pf_kapital') auf eine Typausnahme —
      // und zwar erst irgendwann später, mitten im Portfolio.
      SharedPreferences.setMockInitialValues({'pf_kapital': 1000.0});
      await SpielstandSpeicher.schreiben({'pf_kapital': 1450});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('pf_kapital'), 1450.0);
    });

    test('eine Ganzzahl bleibt eine Ganzzahl', () async {
      SharedPreferences.setMockInitialValues({'lp_gesamt_richtig': 10});
      await SpielstandSpeicher.schreiben({'lp_gesamt_richtig': 99});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('lp_gesamt_richtig'), 99);
    });

    test('zählt nur, was sich wirklich ändert', () async {
      SharedPreferences.setMockInitialValues({
        'lp_gesamt_richtig': 10,
        'lp_s_done_a': true,
        'abzeichen_freigeschaltet': ['a'],
      });

      final unveraendert = await SpielstandSpeicher.schreiben({
        'lp_gesamt_richtig': 10,
        'lp_s_done_a': true,
        'abzeichen_freigeschaltet': ['a'],
      });
      expect(unveraendert, 0);

      final eines = await SpielstandSpeicher.schreiben({
        'lp_gesamt_richtig': 10,
        'abzeichen_freigeschaltet': ['a', 'b'],
      });
      expect(eines, 1);
    });

    test('Hin und zurück ändert nichts', () async {
      final start = {
        'lp_s_done_a': true,
        'lp_gesamt_richtig': 42,
        'pf_kapital': 1450.5,
        'abzeichen_freigeschaltet': ['a', 'b'],
        'lp_letzte_akt': '2026-08-30T10:00:00.000',
      };
      await SpielstandSpeicher.schreiben(start);
      final gelesen = await SpielstandSpeicher.lesen();
      expect(await SpielstandSpeicher.schreiben(gelesen), 0);
    });
  });

  test('Zurücksetzen räumt den Fortschritt weg, nicht die Einstellungen',
      () async {
    SharedPreferences.setMockInitialValues({
      'lp_s_done_a': true,
      'lp_gesamt_richtig': 42,
      'abzeichen_freigeschaltet': ['a'],
      'einstellung_sound': false,
      'einstellung_sprache': 'de',
      'erinnerung_aktiv': true,
    });

    await SpielstandSpeicher.loescheSyncSchluessel();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('lp_s_done_a'), isNull);
    expect(prefs.getInt('lp_gesamt_richtig'), isNull);
    expect(prefs.getStringList('abzeichen_freigeschaltet'), isNull);
    // Ton, Sprache und Erinnerungen überleben — sie gehören ans Gerät, nicht
    // zum Fortschritt.
    expect(prefs.getBool('einstellung_sound'), false);
    expect(prefs.getString('einstellung_sprache'), 'de');
    expect(prefs.getBool('erinnerung_aktiv'), true);
  });
}
