import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/services/spielstand_speicher.dart';
import 'package:geomania/services/station_session_service.dart';
import 'package:geomania/services/update_neustart_service.dart';

/// Die Rotations-Tracker beim Löschen.
///
/// ══ WARUM ES DIESEN TEST GIBT ═══════════════════════════════════════════════
///
/// Auf dem iPhone stand nach dem einmaligen Neustart als erste Station des
/// Lernpfads ein Nachbarland-Quiz — obwohl der Pfad dort fest ein Flaggen-Quiz
/// vorsieht und ein Test das bestätigte.
///
/// Der Pfad war auch unverändert. Stehen geblieben war `lp_rr_*`: die
/// Buchführung darüber, welche Länder je Welt und Modus schon abgefragt
/// wurden. Diese Schlüssel gehören ans Gerät und nicht in die Cloud — also
/// räumte `loescheSyncSchluessel` sie nicht mit weg. Der Fortschritt war
/// gelöscht, der Zeiger auf den abgearbeiteten Zyklus nicht, und ein
/// Kern-Modus, der laut Zeiger "alles durch" ist, wird zur Spielzeit durch
/// einen Unterhaltungs-Modus ersetzt.
///
/// Gemessen wird deshalb an [FragenGenerator.ermittleTatsaechlichenModus]
/// — der Sicht, die der Spieler wirklich bekommt.
void main() {
  /// Der Schlüssel, unter dem der Tracker eines Modus liegt.
  ///
  /// Bei "Welt" ist er welt-weit, bei den sechs Block-Kontinenten je
  /// Abschnitt — dieselbe Aufteilung wie in StationSessionService._rrModusKey.
  String trackerSchluessel(LernWelt welt, LernAbschnitt abschnitt,
          LernModus modus) =>
      welt.id == 'welt'
          ? 'lp_rr_${welt.id}_${modus.name}'
          : 'lp_rr_${welt.id}_${abschnitt.id}_${modus.name}';

  /// Ein Gerät, auf dem der Flaggen-Modus jeder Welt seinen Zyklus schon
  /// vollständig durchlaufen hat — dazu etwas Fortschritt, damit der Neustart
  /// überhaupt etwas zu tun findet.
  Map<String, Object> benutztesGeraet() {
    final werte = <String, Object>{
      'lp_gesamtpunkte': 4200,
      'lp_streak': 9,
      'lp_s_done_europa_1_01': true,
    };
    for (final welt in lernwelten) {
      final abschnitt = welt.abschnitte.first;
      final station = abschnitt.stationen.first;
      final pool = welt.id == 'welt' ? welt.laenderCodes : station.laenderCodes;
      werte[trackerSchluessel(welt, abschnitt, station.modus)] =
          jsonEncode(pool);
    }
    return werte;
  }

  Future<void> erwarteFlaggenUeberall() async {
    for (final welt in lernwelten) {
      final erste = welt.abschnitte.first.stationen.first;
      expect(await FragenGenerator.ermittleTatsaechlichenModus(erste),
          LernModus.flaggenQuizBild,
          reason: '${welt.id} wird als etwas anderes gespielt');
    }
  }

  test('Ohne den Fix ersetzt der stehen gebliebene Tracker den Modus',
      () async {
    // Die Gegenprobe. Ohne sie wäre nicht zu sehen, ob der Test unten
    // überhaupt etwas prüft — ein Gerät ohne Tracker liefert das erwartete
    // Ergebnis nämlich von allein.
    SharedPreferences.setMockInitialValues(benutztesGeraet());
    final ersetzt = <String>[];
    for (final welt in lernwelten) {
      final erste = welt.abschnitte.first.stationen.first;
      final modus =
          await FragenGenerator.ermittleTatsaechlichenModus(erste);
      if (modus != LernModus.flaggenQuizBild) ersetzt.add('${welt.id}→${modus.name}');
    }
    expect(ersetzt, isNotEmpty,
        reason: 'Der Aufbau löst die Ersetzung gar nicht aus — dann prüft der '
            'Test darunter nichts');
  });

  test('Nach dem Neustart ist Station 1 jeder Welt wieder ein Flaggen-Quiz',
      () async {
    SharedPreferences.setMockInitialValues(benutztesGeraet());
    await UpdateNeustartService.pruefeBeimStart();
    await erwarteFlaggenUeberall();
  });

  test('Nach der Kontolöschung ebenso', () async {
    // Schritt 5 der Löschkette ruft genau diese Funktion auf — geprüft in
    // konto_loeschen_test.dart. Das Konto selbst braucht Firebase und lässt
    // sich hier nicht löschen; die Wirkung auf dem Gerät schon.
    SharedPreferences.setMockInitialValues(benutztesGeraet());
    await SpielstandSpeicher.loescheSyncSchluessel();
    await erwarteFlaggenUeberall();
  });

  test('Die Tracker sind danach wirklich weg', () async {
    SharedPreferences.setMockInitialValues(benutztesGeraet());
    await SpielstandSpeicher.loescheSyncSchluessel();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('lp_rr_')), isEmpty);
  });

  test('Die Einstellungen des Geräts bleiben stehen', () async {
    // Der Dialog der Kontolöschung verspricht das ausdrücklich.
    SharedPreferences.setMockInitialValues({
      ...benutztesGeraet(),
      'sound_aktiv': false,
      'vibration_aktiv': false,
      'sprache': 'en',
    });
    await SpielstandSpeicher.loescheSyncSchluessel();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('sound_aktiv'), isFalse);
    expect(prefs.getBool('vibration_aktiv'), isFalse);
    expect(prefs.getString('sprache'), 'en');
  });

  test('Beide Seiten nennen dasselbe Präfix', () {
    // SpielstandSpeicher importiert bewusst nichts aus dem Fortschritt und
    // wiederholt die Zeichenkette deshalb. Laufen die beiden auseinander,
    // löscht der Neustart wieder an den Trackern vorbei.
    final speicher =
        File('lib/services/spielstand_speicher.dart').readAsStringSync();
    final fortschritt =
        File('lib/services/fortschritt_service.dart').readAsStringSync();
    expect(speicher.contains("_kRotationsPraefix = 'lp_rr_'"), isTrue);
    expect(fortschritt.contains("_rrPrefix = 'lp_rr_'"), isTrue);
  });
}
