import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum AnzeigenameErgebnis { erfolgreich, bereitsVergeben, fehler }

/// Ausgang eines Anmeldeversuchs.
///
/// [abgebrochen] ist ausdrücklich KEIN Fehler: wer den Google-Dialog wegwischt,
/// soll keine rote Meldung sehen, sondern einfach wieder vor den Knöpfen
/// stehen.
///
/// [nichtEingerichtet] trennt den einen Fall ab, der beim ersten Ausprobieren
/// mit Abstand am wahrscheinlichsten ist: In der Firebase-Konsole ist der
/// Anbieter noch nicht freigeschaltet oder der SHA-Fingerabdruck fehlt. Ohne
/// diese Unterscheidung landet man bei "irgendwas ging schief" und sucht im
/// Code statt in der Konsole.
enum AnmeldeErgebnis { erfolgreich, abgebrochen, nichtEingerichtet, fehler }

/// Interner Signal-Typ, um "Name bereits von jemand anderem vergeben" aus
/// der Transaktion nach außen zu tragen — runTransaction() propagiert
/// geworfene Exceptions unverändert (keine automatischen Retries dafür,
/// die sind nur für Firestore-interne Kontentions-Fehler reserviert).
class _NameVergebenException implements Exception {}

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static String? get uid => _auth.currentUser?.uid;

  static bool get istAngemeldet => _auth.currentUser != null;

  static String? get anzeigename => _auth.currentUser?.displayName;

  static bool get hatAnzeigename =>
      (_auth.currentUser?.displayName ?? '').trim().isNotEmpty;

  /// Platzhalter, den [spielerAnlegen] einträgt, solange noch kein Name
  /// gewählt wurde.
  static const _kNamensPlatzhalter = 'Spieler';

  /// Hat der Spieler in GeoMania selbst einen Namen gewählt und reserviert?
  ///
  /// NICHT dasselbe wie [hatAnzeigename] — und das ist der Punkt: Google
  /// liefert bei der Anmeldung den Namen des Google-Kontos gleich mit, und
  /// Firebase trägt ihn als displayName ein. Wer nur auf displayName schaut,
  /// überspringt die Namensauswahl komplett: Der Spieler heisst dann in der
  /// Rangliste wie in seinem Google-Konto — mit Klarnamen — und der Name ist
  /// nie reserviert worden, kann also doppelt vorkommen.
  ///
  /// Massgeblich ist deshalb das eigene spieler-Dokument. `nameGewaehlt` setzt
  /// ausschliesslich die Reservierungs-Transaktion.
  static Future<bool> hatEigenenNamen() async {
    final u = _auth.currentUser;
    if (u == null) return false;
    try {
      final daten = (await _db.collection('spieler').doc(u.uid).get()).data();
      if (daten == null) return false;
      if (daten['nameGewaehlt'] == true) return true;
      // Rückfall für Dokumente aus der Zeit vor diesem Feld: ein gespeicherter
      // Name, der nicht der Platzhalter ist, war eine bewusste Wahl.
      final name = (daten['anzeigename'] as String? ?? '').trim();
      return name.isNotEmpty && name != _kNamensPlatzhalter;
    } catch (_) {
      // Kein Netz: lieber weiterspielen lassen als vor einer Namensabfrage
      // festhängen, die ohne Verbindung ohnehin nicht durchginge.
      return hatAnzeigename;
    }
  }

  /// Ändert sich bei An- und Abmeldung. Der StartWrapper hängt daran, damit
  /// ein Abmelden aus den Einstellungen sofort auf den Anmelde-Screen führt.
  static Stream<User?> get anmeldeStand => _auth.authStateChanges();

  /// Gilt der aktuelle Stand als angemeldet?
  ///
  /// Ein anonymes Konto zählt NUR im Debug-Build. Wer aus einer alten Version
  /// aktualisiert — die meldete jeden beim Start still anonym an — landet im
  /// Release-Build damit auf dem Anmelde-Screen statt in einem Konto, aus dem
  /// er nie wieder herauskäme. Sein Fortschritt geht dabei nicht verloren,
  /// siehe [_anmeldenOderVerknuepfen].
  static bool get istAngemeldetFuerApp {
    final u = _auth.currentUser;
    if (u == null) return false;
    return kDebugMode || !u.isAnonymous;
  }

  // ── Anmeldung ─────────────────────────────────────────────────────────────

  /// Meldet mit [zugangsdaten] an — und verknüpft sie, wenn gerade ein
  /// anonymes Konto aktiv ist.
  ///
  /// Das Verknüpfen ist der Kern der Aktualisierungs-Geschichte: Wer aus der
  /// alten Version kommt, hat ein anonymes Konto mit Anzeigenamen, reserviertem
  /// Namen und Spieler-Dokument. `linkWithCredential` behält die BESTEHENDE
  /// uid bei und hängt nur den Anbieter dazu — Name, Reservierung, Rangliste
  /// und Cloud-Fortschritt gehören danach demselben Konto wie vorher. Ein
  /// schlichtes `signInWithCredential` würde stattdessen eine neue uid
  /// erzeugen, und der alte Name bliebe als Karteileiche reserviert.
  ///
  /// Gehört das Google-/Apple-Konto bereits zu einem echten Konto (zweites
  /// Gerät, Neuinstallation), meldet Firebase 'credential-already-in-use'.
  /// Dann ist die Anmeldung dort richtig, und das leere anonyme Konto wird
  /// aufgegeben.
  static Future<AnmeldeErgebnis> _anmeldenOderVerknuepfen(
      AuthCredential zugangsdaten) async {
    final aktuell = _auth.currentUser;
    if (aktuell != null && aktuell.isAnonymous) {
      try {
        await aktuell.linkWithCredential(zugangsdaten);
        return AnmeldeErgebnis.erfolgreich;
      } on FirebaseAuthException catch (e) {
        const schonVergeben = {
          'credential-already-in-use',
          'email-already-in-use',
          'provider-already-linked',
        };
        if (!schonVergeben.contains(e.code)) rethrow;
      }
    }
    await _auth.signInWithCredential(zugangsdaten);
    return AnmeldeErgebnis.erfolgreich;
  }

  /// Übersetzt Firebase-Fehlercodes in die grobe Einteilung von
  /// [AnmeldeErgebnis]. Die drei Codes unten bedeuten alle dasselbe: In der
  /// Konsole fehlt noch etwas.
  static AnmeldeErgebnis _deute(Object fehler) {
    if (fehler is FirebaseAuthException) {
      const konsole = {
        'operation-not-allowed',
        'invalid-credential',
        'configuration-not-found',
      };
      if (konsole.contains(fehler.code)) return AnmeldeErgebnis.nichtEingerichtet;
    }
    return AnmeldeErgebnis.fehler;
  }

  static Future<AnmeldeErgebnis> mitGoogleAnmelden() async {
    try {
      // Ohne Argumente: Auf Android holt sich das Plugin die Web-Client-ID aus
      // der von google-services.json erzeugten String-Ressource
      // default_web_client_id, auf iOS aus der GoogleService-Info.plist. Es
      // muss also KEINE Client-ID im Code stehen — sie kommt aus den Dateien,
      // die die Firebase-Konsole ausliefert.
      await GoogleSignIn.instance.initialize();
      final konto = await GoogleSignIn.instance.authenticate();
      final idToken = konto.authentication.idToken;
      if (idToken == null) {
        // Genau der Fall "google-services.json enthält keinen oauth_client mit
        // client_type 3" — die Anmeldung selbst klappt, aber ohne Token ist
        // Firebase nichts anzubieten.
        return AnmeldeErgebnis.nichtEingerichtet;
      }
      return await _anmeldenOderVerknuepfen(
          GoogleAuthProvider.credential(idToken: idToken));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return AnmeldeErgebnis.abgebrochen;
      }
      // "serverClientId must be provided on Android" landet hier.
      return AnmeldeErgebnis.nichtEingerichtet;
    } catch (e) {
      return _deute(e);
    }
  }

  /// Nur auf Apple-Plattformen aufrufen — siehe [appleVerfuegbar].
  static Future<AnmeldeErgebnis> mitAppleAnmelden() async {
    try {
      // Firebase verlangt den Nonce doppelt: Apple bekommt den SHA-256-Abdruck
      // zu sehen, Firebase den Klartext. Nur so lässt sich prüfen, dass das
      // vorgelegte Token wirklich zu DIESER Anfrage gehört und nicht
      // abgefangen und wiederverwendet wurde.
      final roh = _zufallsNonce();
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(roh)).toString(),
      );
      final token = apple.identityToken;
      if (token == null) return AnmeldeErgebnis.fehler;
      return await _anmeldenOderVerknuepfen(
        OAuthProvider("apple.com").credential(idToken: token, rawNonce: roh),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AnmeldeErgebnis.abgebrochen;
      }
      return AnmeldeErgebnis.nichtEingerichtet;
    } catch (e) {
      return _deute(e);
    }
  }

  /// "Mit Apple anmelden" wird nur dort angeboten, wo es das System kennt.
  static bool get appleVerfuegbar {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  static String _zufallsNonce([int laenge = 32]) {
    const zeichen =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final zufall = Random.secure();
    return List.generate(
        laenge, (_) => zeichen[zufall.nextInt(zeichen.length)]).join();
  }

  /// Meldet ab. Der lokale Spielstand bleibt liegen — er hängt an
  /// SharedPreferences, nicht am Konto.
  static Future<void> abmelden() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nicht mit Google angemeldet gewesen — kein Grund, das Abmelden
      // scheitern zu lassen.
    }
    await _auth.signOut();
  }

  // trim() allein reicht nicht: mehrfache/innere Leerzeichen (z.B. "Anna  Maria"
  // mit doppeltem Leerzeichen vs. "Anna Maria") blieben sonst unterschiedliche
  // Schlüssel und könnten beide unabhängig voneinander reserviert werden —
  // zwei Spieler mit optisch fast identischem Namen in der Rangliste.
  static String _normalisiereName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Reserviert [neuerName] eindeutig für den aktuellen Spieler (Dokument-ID
  /// = normalisierter Name in der "anzeigenamen_reserviert"-Collection) und
  /// setzt ihn als Anzeigenamen. Läuft in einer Firestore-Transaktion, damit
  /// "prüfen ob frei" + "alte Reservierung freigeben" + "neue Reservierung
  /// anlegen" atomar zusammen passieren — zwei gleichzeitige Anfragen für
  /// denselben Namen können nicht beide durchkommen.
  ///
  /// Die eigentliche, serverseitig erzwungene Eindeutigkeits-Garantie kommt
  /// aus firestore.rules: ein Reservierungs-Dokument darf nur EINMAL per
  /// "create" angelegt werden (kein "update" erlaubt) — die Transaktion hier
  /// sorgt zusätzlich dafür, dass der alte Name beim Wechsel korrekt wieder
  /// freigegeben wird, ohne dass beide Schritte auseinanderlaufen können.
  static Future<AnzeigenameErgebnis> setzeAnzeigenameEindeutig(
      String neuerName) async {
    final u = _auth.currentUser;
    if (u == null) return AnzeigenameErgebnis.fehler;
    final normalisiert = _normalisiereName(neuerName);
    if (normalisiert.isEmpty) return AnzeigenameErgebnis.fehler;

    final docRef = _db.collection('anzeigenamen_reserviert').doc(normalisiert);
    final spielerRef = _db.collection('spieler').doc(u.uid);

    try {
      await _db.runTransaction((transaction) async {
        // Reihenfolge wichtig: Firestore-Transaktionen verlangen ALLE Reads
        // vor dem ersten Write.
        final vorhandenesDoc = await transaction.get(docRef);
        final altesSpielerDoc = await transaction.get(spielerRef);

        final schonMeins =
            vorhandenesDoc.exists && vorhandenesDoc.data()?['uid'] == u.uid;
        if (vorhandenesDoc.exists && !schonMeins) {
          // Name ist von JEMAND ANDEREM bereits vergeben.
          throw _NameVergebenException();
        }

        final alterName = altesSpielerDoc.data()?['anzeigename'] as String?;
        if (alterName != null) {
          final alterNormalisiert = _normalisiereName(alterName);
          if (alterNormalisiert.isNotEmpty && alterNormalisiert != normalisiert) {
            transaction.delete(_db
                .collection('anzeigenamen_reserviert')
                .doc(alterNormalisiert));
          }
        }

        // NUR anlegen, nie überschreiben. firestore.rules erlauben für
        // Reservierungen bewusst "create" und "delete", aber kein "update" —
        // sonst könnte jeder ein fremdes Reservierungsdokument mit der eigenen
        // uid überschreiben. Ein transaction.set() auf ein BESTEHENDES Dokument
        // ist für die Regeln ein Update und wurde abgewiesen: Wer seinen
        // eigenen Namen nur anders schrieb ("sebastian" -> "Sebastian"),
        // bekam deshalb einen Berechtigungsfehler statt einer Änderung. Gehört
        // die Reservierung schon mir, bleibt sie einfach stehen; die
        // Schreibweise für die Anzeige liegt ohnehin im spieler-Dokument und
        // im Anzeigenamen des Kontos.
        if (!schonMeins) {
          transaction.set(docRef, {
            'uid': u.uid,
            'anzeigename': neuerName,
            'reserviertAm': FieldValue.serverTimestamp(),
          });
        }
        transaction.set(
            spielerRef,
            {'anzeigename': neuerName, 'nameGewaehlt': true},
            SetOptions(merge: true));
      });
    } on _NameVergebenException {
      return AnzeigenameErgebnis.bereitsVergeben;
    } catch (e) {
      print('Namens-Reservierung fehlgeschlagen: $e');
      return AnzeigenameErgebnis.fehler;
    }

    try {
      await u.updateDisplayName(neuerName);
      await u.reload();
    } catch (e) {
      print('Name-Fehler: $e');
    }
    // Stellt bei einem allerersten Namen sicher, dass das spieler-Dokument
    // auch die restlichen Standardfelder bekommt (erstelltAm, Startkapital
    // etc.) — die Transaktion oben schreibt bewusst nur 'anzeigename', damit
    // sie so schmal wie möglich bleibt.
    await spielerAnlegen();
    return AnzeigenameErgebnis.erfolgreich;
  }

  // Spieler-Dokument in Firestore anlegen bzw. Anzeigename aktuell halten
  static Future<void> spielerAnlegen() async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      final ref = _db.collection('spieler').doc(u.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          // Bewusst NICHT der displayName des Anbieters: Google liefert den
          // Klarnamen mit, und der darf nicht ungefragt in der Rangliste
          // landen. Bis zur eigenen Wahl steht hier der Platzhalter.
          'anzeigename': _kNamensPlatzhalter,
          'nameGewaehlt': false,
          'erstelltAm': FieldValue.serverTimestamp(),
          'portfolioKapital': 1000.0,
          'portfolioRekord': 1000.0,
        });
      } else {
        await ref.update({
          'anzeigename': u.displayName ?? 'Spieler',
        });
      }
    } catch (e) {
      print('Spieler-Anlegen-Fehler: $e');
    }
  }
}
