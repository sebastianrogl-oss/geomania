import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:geomania/services/auth_service.dart';

/// Der technische Befund unter der freundlichen Meldung.
///
/// ══ WARUM ES DIESEN TEST GIBT ═══════════════════════════════════════════════
///
/// Zwei TestFlight-Runden sind an derselben Stelle verloren gegangen: Die App
/// meldete "Die Anmeldung ist noch nicht eingerichtet" — und dieser eine Satz
/// deckt vier grundverschiedene Ursachen ab (Entitlement fehlt in der App-ID,
/// Provisioning-Profil ist zu alt, Anbieter in Firebase nicht freigeschaltet,
/// Client-ID passt nicht). Vom Rechner aus lässt sich keine davon ausschliessen.
/// Also wurde geraten, gebaut, hochgeladen — und wieder geraten.
///
/// Der Fehlercode beendet das. `apple/notHandled` zeigt auf das Profil,
/// `firebase/invalid-credential` auf die Konsole. Diese Prüfungen halten fest,
/// dass er auch wirklich bis auf den Bildschirm durchkommt.
void main() {
  group('Der Rohtext nennt Quelle und Code', () {
    test('Apple-Codes kommen mit Namen durch', () {
      // Der wichtigste Fall überhaupt: notHandled heisst, dass iOS die
      // Anfrage gar nicht erst angenommen hat — der Fingerabdruck eines
      // Programms, dessen Provisioning-Profil das Sign-in-Recht nicht kennt.
      expect(
        AuthService.befundVon(const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.notHandled,
          message: 'The operation couldn’t be completed.',
        )),
        startsWith('apple/notHandled'),
      );
      expect(
        AuthService.befundVon(const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.unknown,
          message: 'x',
        )),
        startsWith('apple/unknown'),
      );
    });

    test('Ein nicht unterstütztes Apple-Login ist ein eigener Fall', () {
      expect(
        AuthService.befundVon(
            const SignInWithAppleNotSupportedException(message: 'iOS 12')),
        startsWith('apple/'),
      );
    });

    test('Firebase-Codes stehen unverändert drin', () {
      expect(
        AuthService.befundVon(FirebaseAuthException(code: 'invalid-credential')),
        startsWith('firebase/invalid-credential'),
      );
      expect(
        AuthService.befundVon(
            FirebaseAuthException(code: 'requires-recent-login')),
        contains('requires-recent-login'),
      );
    });

    test('Ein hängender Aufruf heisst Zeitüberschreitung', () {
      // Der Fall, der bisher überhaupt nichts anzeigte.
      expect(AuthService.befundVon(TimeoutException('x')),
          'zeitueberschreitung');
    });

    test('Auch ein unbekannter Fehler liefert etwas Verwertbares', () {
      // Kein leerer Text, egal was kommt — sonst steht auf dem Gerät wieder
      // nur die freundliche Meldung.
      expect(AuthService.befundVon(StateError('kaputt')), isNotEmpty);
      expect(AuthService.befundVon('nur ein String'), isNotEmpty);
    });

    test('Der Text passt auf einen Bildschirm', () {
      // Firebase-Meldungen können sehr lang werden. Ein Befund, der über den
      // Rand hinausläuft, ist keiner mehr.
      final lang = AuthService.befundVon(
          FirebaseAuthException(code: 'x', message: 'y' * 500));
      expect(lang.length, lessThanOrEqualTo(160));
      expect(lang, startsWith('firebase/x'));
    });
  });

  group('Der Befund kommt bis auf den Bildschirm', () {
    final anmelde = File('lib/screens/anmelde_screen.dart').readAsStringSync();

    test('Der Anmelde-Screen zeigt ihn an', () {
      expect(anmelde.contains('ausgang.befund'), isTrue,
          reason: 'Der Screen liest den Befund gar nicht aus');
      expect(RegExp(r'SelectableText\(\s*_befund!').hasMatch(anmelde), isTrue,
          reason: 'Ein Fehlercode, den man abtippen muss, kommt falsch an '
              'oder gar nicht — er muss auswählbar sein');
    });

    test('Ein Abbruch zeigt keinen Befund', () {
      // Wer den Apple-Dialog wegwischt, hat nichts falsch gemacht und soll
      // keinen Fehlercode sehen.
      expect(AnmeldeAusgang.abgebrochen.befund, isNull);
      expect(AnmeldeAusgang.erfolgreich.befund, isNull);
    });
  });
}
