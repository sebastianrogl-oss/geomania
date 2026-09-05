import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Die iOS-Anmeldung, an ihren Konfigurationsdateien geprüft.
///
/// ══ WARUM ES DIESEN TEST GIBT ═══════════════════════════════════════════
///
/// Im TestFlight-Build schlug beides fehl: Google mit "hat nicht geklappt",
/// Apple mit "noch nicht eingerichtet". Beides waren fehlende Einträge in
/// Konfigurationsdateien — und beides fällt beim Bauen NICHT auf. Der Build
/// läuft durch, die App startet, und erst beim Anmeldeversuch auf dem Gerät
/// zeigt sich, dass etwas fehlt.
///
/// Diese Prüfungen kosten Millisekunden und hätten die Runde über TestFlight
/// erspart.
void main() {
  final plist = File('ios/Runner/GoogleService-Info.plist').readAsStringSync();
  final info = File('ios/Runner/Info.plist').readAsStringSync();

  /// Liest den Wert eines <key>/<string>-Paars aus einer plist.
  String? wert(String inhalt, String schluessel) {
    final treffer = RegExp(
      '<key>$schluessel</key>\\s*<string>([^<]*)</string>',
      multiLine: true,
    ).firstMatch(inhalt);
    return treffer?.group(1);
  }

  group('Google-Anmeldung', () {
    test('Die plist enthält einen OAuth-Client', () {
      // GENAU DAS FEHLTE. Eine plist, die heruntergeladen wurde, bevor die
      // Google-Anmeldung für die iOS-App eingerichtet war, hat weder
      // CLIENT_ID noch REVERSED_CLIENT_ID — sie ist dann rund 350 Bytes
      // kleiner und sieht sonst völlig normal aus.
      expect(wert(plist, 'CLIENT_ID'), isNotNull,
          reason: 'CLIENT_ID fehlt — plist neu aus der Firebase-Konsole laden');
      expect(wert(plist, 'REVERSED_CLIENT_ID'), isNotNull,
          reason: 'REVERSED_CLIENT_ID fehlt — dieselbe Ursache');
    });

    test('Die BUNDLE_ID passt zur App', () {
      expect(wert(plist, 'BUNDLE_ID'), 'com.northlight.geomania');
    });

    test('REVERSED_CLIENT_ID ist die umgedrehte CLIENT_ID', () {
      // Gegenprobe gegen eine plist aus einem anderen Projekt: Passen die
      // beiden nicht zueinander, stammen sie nicht aus derselben Quelle.
      final cid = wert(plist, 'CLIENT_ID')!;
      final rid = wert(plist, 'REVERSED_CLIENT_ID')!;
      expect(rid, cid.split('.').reversed.join('.'));
    });

    test('Der URL-Typ in Info.plist trägt genau diese REVERSED_CLIENT_ID', () {
      // DIE ZWEITE FALLE: Der Wert steht doppelt im Projekt — einmal in der
      // GoogleService-Info.plist, einmal als URL-Schema. Wer die plist
      // austauscht und das Schema vergisst, bekommt einen Build, der
      // durchläuft und erst am Gerät scheitert.
      final rid = wert(plist, 'REVERSED_CLIENT_ID')!;
      expect(info.contains('CFBundleURLTypes'), isTrue,
          reason: 'Ohne URL-Typ findet die Google-Anmeldung nicht zurück');
      expect(info.contains('<string>$rid</string>'), isTrue,
          reason: 'Das URL-Schema in Info.plist passt nicht zur '
              'REVERSED_CLIENT_ID der GoogleService-Info.plist');
    });
  });

  group('Apple-Anmeldung', () {
    final pbxproj =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    test('Die Entitlements-Datei trägt das Sign-in-Recht', () {
      final ent = File('ios/Runner/Runner.entitlements');
      expect(ent.existsSync(), isTrue,
          reason: 'Ohne Entitlement meldet iOS "nicht eingerichtet"');
      expect(ent.readAsStringSync().contains('com.apple.developer.applesignin'),
          isTrue);
    });

    test('Sie ist in ALLEN Build-Konfigurationen eingehängt', () {
      // Debug, Release und Profile. Nur eine davon zu setzen ist der
      // klassische Fall "im Testbuild geht es, im Store nicht" — und der
      // faellt genau einmal auf, naemlich zu spaet.
      final anzahl = 'CODE_SIGN_ENTITLEMENTS'.allMatches(pbxproj).length;
      expect(anzahl, 3,
          reason: 'CODE_SIGN_ENTITLEMENTS steht $anzahl-mal statt dreimal');
    });
  });

  test('Die GoogleService-Info.plist liegt im Resources-Schritt', () {
    // Sonst landet sie nicht im fertigen Programm, und Firebase findet beim
    // Start seine Konfiguration nicht.
    final pbxproj =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(pbxproj.contains('GoogleService-Info.plist in Resources'), isTrue);
  });
}
