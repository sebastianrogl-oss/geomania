import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/services/abzeichen_service.dart';
import 'package:geomania/services/update_neustart_service.dart';
import 'package:geomania/services/urgestein_service.dart';

/// Der einmalige Neustart beim Update auf 1.1.0 — und vor allem seine
/// Reihenfolge.
///
/// Der [UrgesteinService] erkennt Bestandsspieler AM ALTEN FORTSCHRITT, und
/// der Neustart räumt genau den weg. Läuft er zuerst, geht jeder leer aus.
/// Diese Kette ist der Grund für die Datei.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Der echte Startablauf aus main(), in derselben Reihenfolge.
  Future<void> appStart() async {
    await UrgesteinService.pruefeBeimStart();
    await UpdateNeustartService.pruefeBeimStart();
  }

  Future<Set<String>> abzeichen() => AbzeichenService.getFreigeschaltete();

  /// Ein voller Alt-Stand quer durch alle Bereiche.
  Map<String, Object> altStand() => {
        'lp_s_done_europa_1_01': true,
        'lp_gesamt_richtig': 128,
        'lp_streak': 12,
        'ch_rekord_preis': 4200,
        'besteStreak_preis': 9,
        'anzahlGespielt_preis': 30,
        'pf_kapital': 5400.0,
        'pf_rekord_kapital': 5400.0,
        'abzeichen_freigeschaltet': ['streak_3', 'streak_7'],
        'einstellung_sound': false,
        'einstellung_sprache': 'en',
      };

  group('Die Kette beim ersten Start nach dem Update', () {
    test('Urgestein ist da UND der Fortschritt ist weg', () async {
      SharedPreferences.setMockInitialValues(altStand());
      await appStart();

      expect(await abzeichen(), contains('urgestein'),
          reason: 'Der Bestandsspieler wurde nicht erkannt');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('lp_s_done_europa_1_01'), isNull);
      expect(prefs.getInt('lp_gesamt_richtig'), isNull);
      expect(prefs.getInt('lp_streak'), isNull);
      expect(prefs.getInt('ch_rekord_preis'), isNull);
      expect(prefs.getInt('besteStreak_preis'), isNull);
      expect(prefs.getInt('anzahlGespielt_preis'), isNull);
      expect(prefs.getDouble('pf_kapital'), isNull);
      expect(prefs.getDouble('pf_rekord_kapital'), isNull);
    });

    test('Das Popup steht an — die Ehrung wird auch gezeigt', () async {
      SharedPreferences.setMockInitialValues(altStand());
      await appStart();
      expect(await UrgesteinService.popupOffen(), isTrue);
    });

    test('Erspielte Abzeichen gehen mit, das Urgestein bleibt', () async {
      // "Alles auf Anfang" heisst auch: keine Abzeichen für Leistungen, die
      // es so nicht mehr gibt. Nur die Ehrung überlebt.
      SharedPreferences.setMockInitialValues(altStand());
      await appStart();
      expect(await abzeichen(), {'urgestein'});
    });

    test('Geräte-Einstellungen bleiben unangetastet', () async {
      // Ton, Sprache und Erinnerungen gehören zum Gerät, nicht zum
      // Spielstand — sie zurückzusetzen wäre eine Zumutung ohne Nutzen.
      SharedPreferences.setMockInitialValues(altStand());
      await appStart();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('einstellung_sound'), false);
      expect(prefs.getString('einstellung_sprache'), 'en');
    });
  });

  group('Beim zweiten Start passiert nichts mehr', () {
    test('neuer Fortschritt überlebt den nächsten Start', () async {
      SharedPreferences.setMockInitialValues(altStand());
      await appStart();

      // Der Spieler fängt neu an.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lp_gesamt_richtig', 5);
      await prefs.setBool('lp_s_done_europa_1_01', true);

      await appStart(); // zweiter Start

      expect(prefs.getInt('lp_gesamt_richtig'), 5,
          reason: 'Der Neustart lief ein zweites Mal');
      expect(prefs.getBool('lp_s_done_europa_1_01'), isTrue);
      expect(await abzeichen(), contains('urgestein'));
    });

    test('auch nach vielen weiteren Starts nicht', () async {
      SharedPreferences.setMockInitialValues(altStand());
      await appStart();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lp_gesamt_richtig', 77);
      for (var i = 0; i < 5; i++) {
        await appStart();
      }
      expect(prefs.getInt('lp_gesamt_richtig'), 77);
    });
  });

  group('Ein frischer Nutzer', () {
    test('bekommt kein Urgestein und verliert nichts', () async {
      await appStart(); // leere Einstellungen
      expect(await abzeichen(), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lp_gesamt_richtig', 8);

      await appStart(); // nächster Start
      expect(await abzeichen(), isEmpty,
          reason: 'Ein Neuling bekam die Ehrung');
      expect(prefs.getInt('lp_gesamt_richtig'), 8,
          reason: 'Dem Neuling wurde sein Fortschritt weggeräumt');
    });
  });

  test('Die Reihenfolge in main() stimmt', () {
    // Der Test oben prüft die Kette über die Dienste. Er würde aber grün
    // bleiben, wenn jemand die beiden Zeilen in main() vertauscht — deshalb
    // hier zusätzlich die Datei selbst.
    final quelle = File('lib/main.dart').readAsStringSync();
    final urgestein = quelle.indexOf('UrgesteinService.pruefeBeimStart()');
    final neustart = quelle.indexOf('UpdateNeustartService.pruefeBeimStart()');
    expect(urgestein, greaterThan(0));
    expect(neustart, greaterThan(0));
    expect(urgestein, lessThan(neustart),
        reason: 'Der Neustart läuft VOR der Urgestein-Prüfung — damit geht '
            'jeder Bestandsspieler leer aus');
  });

  test('Der Merker des Neustarts überlebt sein eigenes Aufräumen', () {
    // Er darf nicht unter den Cloud-Schlüsseln stehen: Der Neustart löscht
    // genau die, würde sich also selbst entfernen und beim nächsten Start
    // erneut laufen.
    final quelle = File('lib/services/spielstand.dart').readAsStringSync();
    final geraet = quelle.indexOf('nurGeraetPraefixe');
    expect(quelle.indexOf("'neustart_110_erledigt'"), greaterThan(geraet),
        reason: 'Der Merker steht nicht in nurGeraetPraefixe');
  });
}
