import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/services/auth_service.dart';

/// Die Zugangsdaten der Apple-Anmeldung.
///
/// ══ WARUM ES DIESEN TEST GIBT ═══════════════════════════════════════════════
///
/// Auf dem iPhone lief der Apple-Dialog sauber durch, und danach lehnte
/// Firebase das Token ab:
///
///   firebase/invalid-credential — Invalid OAuth response from apple.com
///
/// Die Ursache lag nicht am Nonce, sondern eine Ebene tiefer: Der Code baute
/// das Zugangsdatum über den ALLGEMEINEN OAuth-Weg statt über den
/// Apple-eigenen. Die native Seite von firebase_auth verzweigt nach dem
/// signInMethod, nicht nach der providerId — 'oauth' und 'apple.com' landen
/// dort in zwei verschiedenen Aufrufen des Firebase-SDK.
///
/// Beides ist von aussen nicht zu sehen und im Quelltext eine Zeile
/// Unterschied. Deshalb steht es hier fest.
void main() {
  final quelle = File('lib/services/auth_service.dart').readAsStringSync();
  final apple = _rumpf(quelle, 'static Future<AnmeldeAusgang> mitAppleAnmelden');

  group('Der Nonce', () {
    test('Ist zufällig und lang genug', () {
      final a = AuthService.zufallsNonce();
      final b = AuthService.zufallsNonce();
      expect(a.length, 32);
      expect(a, isNot(b), reason: 'Zwei Anläufe liefern denselben Nonce');
    });

    test('Enthält nur Zeichen, die den Weg unverändert überstehen', () {
      // Der Nonce läuft durch Apple und Firebase. Alles ausserhalb dieses
      // Vorrats müsste unterwegs kodiert werden — und käme auf der anderen
      // Seite womöglich anders wieder heraus.
      final erlaubt = RegExp(r'^[0-9A-Za-z\-._]+$');
      for (var i = 0; i < 50; i++) {
        expect(erlaubt.hasMatch(AuthService.zufallsNonce()), isTrue);
      }
    });

    test('Apple bekommt den Abdruck, Firebase den Klartext', () {
      // Vertauscht, doppelt gehasht oder auf einer Seite weggelassen ergibt
      // genau die gemeldete Firebase-Meldung.
      expect(apple.contains('nonce: sha256.convert(utf8.encode(roh)).toString()'),
          isTrue,
          reason: 'Apple bekommt nicht den SHA-256-Abdruck des Nonce');
      expect(RegExp(r'credentialWithIDToken\(\s*token,\s*roh,').hasMatch(apple),
          isTrue,
          reason: 'Firebase bekommt nicht den Klartext-Nonce');
    });

    test('Genau einmal gehasht', () {
      // Das Plugin reicht den Nonce unverändert an
      // ASAuthorizationAppleIDRequest weiter und hasht nichts nach. Ein
      // zweiter Aufruf hier wäre einer zu viel.
      expect('sha256.convert'.allMatches(apple).length, 1);
    });

    test('Die Rechnung stimmt mit der, die Firebase anstellt', () {
      // Firebase bildet SHA-256 über den rawNonce und vergleicht mit dem
      // nonce-Feld im Apple-Token. Kleingeschriebene Hex-Darstellung, 64
      // Zeichen — dasselbe, was Digest.toString() liefert.
      final roh = AuthService.zufallsNonce();
      final abdruck = sha256.convert(utf8.encode(roh)).toString();
      expect(abdruck, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  group('Der Weg zu Firebase', () {
    test('Über den Apple-eigenen Anbieter, nicht über den allgemeinen', () {
      // DAS WAR DER FEHLER. Die native Seite von firebase_auth verzweigt
      // nach signInMethod:
      //   OAuthProvider(...).credential()  -> 'oauth'     -> credentialWith-
      //                                                      ProviderID:...
      //   AppleAuthProvider.credentialWithIDToken(...) -> 'apple.com'
      //                                                -> appleCredential-
      //                                                   WithIDToken:...
      expect(apple.contains('AppleAuthProvider.credentialWithIDToken'), isTrue,
          reason: 'Ohne den Apple-eigenen Weg lehnt Firebase das Token mit '
              '"Invalid OAuth response from apple.com" ab');
      // Ohne Kommentarzeilen: Der alte Weg steht dort ausdrücklich als
      // Warnung, und die soll stehen bleiben dürfen.
      expect(_ohneKommentare(apple).contains("OAuthProvider('apple.com')"),
          isFalse,
          reason: 'Der allgemeine OAuth-Weg ist zurück');
    });

    test('Der Name wird mitgegeben', () {
      // Apple liefert Vor- und Nachnamen NUR bei der allerersten Anmeldung.
      // Wer ihn dort wegwirft, bekommt ihn nie wieder — auch nicht nach
      // einer Neuinstallation.
      expect(apple.contains('givenName: apple.givenName'), isTrue);
      expect(apple.contains('familyName: apple.familyName'), isTrue);
    });

    test('Ohne Token wird gar nicht erst angefragt', () {
      expect(apple.contains("befund: 'apple/kein-identityToken'"), isTrue);
    });
  });
}

/// Streicht Kommentarzeilen, damit eine Warnung im Text nicht als Code zählt.
String _ohneKommentare(String quelle) => quelle
    .split('\n')
    .where((z) => !z.trimLeft().startsWith('//'))
    .join('\n');

/// Liest den Rumpf einer Methode — von ihrer Signatur bis zur nächsten.
String _rumpf(String quelle, String signatur) {
  final ab = quelle.indexOf(signatur);
  if (ab < 0) throw StateError('Nicht gefunden: $signatur');
  final bis = quelle.indexOf('\n  static ', ab + signatur.length);
  return quelle.substring(ab, bis < 0 ? quelle.length : bis);
}
