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

  test('DIE GANZE KETTE: Altstand lokal UND in der Cloud', () async {
    // Der Fall, der auf dem TestFlight-Geraet schiefging.
    //
    // Die Cloud wird hier nachgestellt, nicht angesprochen: Firestore
    // braeuchte eine Anmeldung, und die gibt es im Test nicht. Geprueft wird
    // deshalb der Zustand, der die Loeschung ausloest — die Notiz — und
    // dass alles Lokale weg ist. Dass der Abgleich sie vor dem
    // Zusammenfuehren abarbeitet, sichert der Test weiter unten ueber die
    // Reihenfolge im Code.
    SharedPreferences.setMockInitialValues(altStand());

    await appStart();

    // 1. Lokal ist alles weg.
    final prefs = await SharedPreferences.getInstance();
    for (final k in [
      'lp_s_done_europa_1_01',
      'lp_gesamt_richtig',
      'lp_streak',
      'ch_rekord_preis',
      'pf_kapital',
    ]) {
      expect(prefs.get(k), isNull, reason: '$k liegt noch da');
    }

    // 2. Die Cloud ist vorgemerkt — der naechste Anmelde-Abgleich loescht
    //    das Dokument, statt es zurueckzuholen.
    expect(await UpdateNeustartService.cloudLoeschenOffen(), isTrue);

    // 3. Das Urgestein hat beides ueberlebt.
    expect(await abzeichen(), {'urgestein'});
  });

  group('Der Cloud-Stand wird mitgelöscht', () {
    test('nach einem echten Neustart steht die Notiz', () async {
      // Der Neustart kann das Cloud-Dokument nicht selbst loeschen — er
      // laeuft vor der Anmeldung, es gibt keine uid. Also hinterlaesst er
      // eine Notiz, die der erste Anmelde-Abgleich abarbeitet.
      SharedPreferences.setMockInitialValues(altStand());
      await appStart();
      expect(await UpdateNeustartService.cloudLoeschenOffen(), isTrue);
    });

    test('OHNE Altstand steht sie NICHT', () async {
      // DER GEFÄHRLICHE FALL. Wer die App frisch auf einem NEUEN Gerät
      // installiert, hat lokal nichts — der Neustart raeumt nichts weg.
      // Stuende die Notiz trotzdem, loeschte der erste Anmelde-Abgleich die
      // Cloud-Sicherung, mit der dieser Spieler seinen Fortschritt vom alten
      // Geraet holen wollte. Aus der Absicherung wuerde der schlimmste
      // Datenverlust, den diese App kennt.
      await appStart(); // leere Einstellungen
      expect(await UpdateNeustartService.cloudLoeschenOffen(), isFalse);
    });

    test('die Notiz bleibt, bis sie abgehakt wird', () async {
      SharedPreferences.setMockInitialValues(altStand());
      await appStart();
      await appStart(); // App neu gestartet, Anmeldung war noch nicht dran
      expect(await UpdateNeustartService.cloudLoeschenOffen(), isTrue,
          reason: 'Ohne Netz muss der naechste Versuch es nachholen');

      await UpdateNeustartService.cloudGeloescht();
      expect(await UpdateNeustartService.cloudLoeschenOffen(), isFalse);
    });

    test('der Neustart läuft nach der Umbenennung noch einmal', () async {
      // Geraete, die Build 13 bis 16 schon gestartet haben, tragen den ALTEN
      // Merker. Mit dem neuen Namen greift der Neustart dort erneut — und
      // diesmal mit Cloud-Notiz.
      SharedPreferences.setMockInitialValues({
        ...altStand(),
        'neustart_110_erledigt': true, // der alte Name
      });
      await appStart();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('lp_gesamt_richtig'), isNull,
          reason: 'Der alte Merker hat den Neustart blockiert');
      expect(await UpdateNeustartService.cloudLoeschenOffen(), isTrue);
      expect(prefs.getBool('neustart_110b_erledigt'), isTrue);
    });

    test('sie überlebt das Aufräumen des Neustarts', () async {
      // Die Notiz gehoert zu den Geraete-Schluesseln. Stuende sie unter den
      // Cloud-Schluesseln, wuerde der Neustart sie im selben Atemzug
      // wegraeumen, in dem er sie setzt.
      final quelle = File('lib/services/spielstand.dart').readAsStringSync();
      expect(quelle.indexOf("'neustart_110_cloud_offen'"),
          greaterThan(quelle.indexOf('nurGeraetPraefixe')));
    });

    test('Der Abgleich löscht, statt zusammenzuführen', () {
      // Die Reihenfolge im Code: Die Notiz muss VOR dem Lesen und
      // Zusammenfuehren abgearbeitet werden. Danach waere der Altstand
      // laengst zurueck — die Zusammenfuehrung kennt nur Wachstum.
      final quelle =
          File('lib/services/spielstand_sync.dart').readAsStringSync();
      final ab = quelle.indexOf('static Future<bool> beimAnmelden');
      final rumpf = quelle.substring(ab, ab + 2500);
      final notiz = rumpf.indexOf('cloudLoeschenOffen()');
      final zusammen = rumpf.indexOf('spielstandZusammenfuehren');
      expect(notiz, greaterThan(0), reason: 'Die Notiz wird nicht geprüft');
      expect(notiz, lessThan(zusammen),
          reason: 'Erst zusammenführen, dann löschen — damit ist der '
              'Altstand schon zurück');
      expect(rumpf.contains('loescheCloudStand()'), isTrue,
          reason: 'Es soll derselbe Weg sein wie bei "Fortschritt '
              'zurücksetzen"');
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
    expect(quelle.indexOf("'neustart_110b_erledigt'"), greaterThan(geraet),
        reason: 'Der Merker steht nicht in nurGeraetPraefixe');
  });
}
