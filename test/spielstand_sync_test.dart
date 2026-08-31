import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/services/spielstand_sync.dart';

/// Die Debug-Sperre.
///
/// Sie ist der Grund, warum am Entwicklungsgerät nichts Schlimmes passieren
/// kann: Dort wird der Spielstand ständig künstlich verbogen — Streak setzen,
/// alles freischalten, zurücksetzen —, und die Zusammenführ-Regeln kennen nur
/// Wachstum. Was einmal in der Cloud steht, bekommt man nicht mehr heraus.
///
/// Der Test läuft selbst im Debug-Modus und prüft die Sperre deshalb direkt.
void main() {
  tearDown(() {
    SpielstandSync.debugSyncErlaubt = false;
    SpielstandSync.debugZuruecksetzen();
  });

  test('Im Debug-Build ist die Synchronisierung aus', () {
    expect(kDebugMode, isTrue,
        reason: 'Testläufe sind Debug-Builds — sonst prüft der Test nichts');
    // Kommt gar nicht erst bis zu Firebase: Die Sperre greift davor. Genau
    // deshalb kann dieser Test ohne initialisiertes Firebase laufen.
    expect(SpielstandSync.aktiv, isFalse);
  });

  test('merkeAenderung tut im Debug-Build nichts', () {
    // Würde die Sperre hier nicht greifen, liefe der Aufruf in AuthService
    // und damit in ein nicht initialisiertes Firebase — der Test bliebe mit
    // einer Ausnahme stehen.
    SpielstandSync.merkeAenderung();
  });

  test('Sichern und Cloud-Löschen sind im Debug-Build folgenlos', () async {
    await SpielstandSync.jetztSichern();
    await SpielstandSync.loescheCloudStand();
  });

  test('Der Debug-Schalter ist voreingestellt aus', () {
    // Ein versehentlich eingecheckter true-Wert wäre genau der Fehler, den
    // niemand bemerkt.
    expect(SpielstandSync.debugSyncErlaubt, isFalse);
  });
}
