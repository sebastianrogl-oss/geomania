import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
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

/// Ausgang eines Löschversuchs für ein ECHTES Konto.
///
/// [erneutAnmelden] ist kein Fehler, sondern eine Zwischenstation: Firebase
/// verlangt für das Löschen eines Kontos eine frische Anmeldung
/// ('requires-recent-login'). Wer seit Wochen angemeldet ist, muss sich also
/// einmal neu ausweisen — und der Nutzer muss erfahren, WARUM plötzlich
/// wieder ein Google-Dialog aufgeht.
enum KontoLoeschErgebnis { erfolgreich, erneutAnmelden, fehler }

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
      // MIT ZEITLIMIT, und das ist der Unterschied zwischen "kurz warten" und
      // "die App startet nicht".
      //
      // Der StartWrapper hängt an dieser Antwort und zeigt bis dahin nur den
      // Gradnetz-Hintergrund. Ein FEHLER kam bisher schon durch (unten im
      // catch), aber eine hängende Verbindung ist kein Fehler: Firestore
      // wartet dann, ohne je zu antworten — Hotel-WLAN, Funkloch mit
      // Balkenanzeige, Portal-Anmeldung. Am Gerät gemessen dauert der Zugriff
      // sonst rund 1,2 s; vier Sekunden sind reichlich Luft und trotzdem eine
      // Grenze.
      //
      // Der Rückfall ist dabei nicht geraten: [hatAnzeigename] liest den
      // Namen aus dem lokal zwischengespeicherten Konto. Wer schon einen hat,
      // spielt weiter; wer keinen hat, bekommt die Namensabfrage — die ohne
      // Verbindung ohnehin nicht durchginge, aber dann wenigstens etwas zeigt.
      final daten = (await _db
              .collection('spieler')
              .doc(u.uid)
              .get()
              .timeout(const Duration(seconds: 4)))
          .data();
      if (daten == null) return false;
      if (daten['nameGewaehlt'] == true) return true;
      // Rückfall für Dokumente aus der Zeit vor diesem Feld: ein gespeicherter
      // Name, der nicht der Platzhalter ist, war eine bewusste Wahl.
      final name = (daten['anzeigename'] as String? ?? '').trim();
      return name.isNotEmpty && name != _kNamensPlatzhalter;
    } catch (_) {
      // Kein Netz, oder das Zeitlimit oben ist abgelaufen: lieber
      // weiterspielen lassen als vor einer Namensabfrage festhängen.
      return hatAnzeigename;
    }
  }

  /// Anmeldung über ein anonymes Konto — das Testkonto des Debug-Knopfes.
  static bool get istTestkonto => _auth.currentUser?.isAnonymous ?? false;

  /// Ändert sich bei An- und Abmeldung. Der StartWrapper hängt daran, damit
  /// ein Abmelden aus den Einstellungen sofort auf den Anmelde-Screen führt.
  static Stream<User?> get anmeldeStand => _auth.authStateChanges();

  /// Gilt der aktuelle Stand als angemeldet?
  ///
  /// Ein anonymes Konto zählt NUR im Debug-Build. Damit fällt zweierlei
  /// zusammen: Der Test-Knopf lässt einen normal weiterspielen, und wer aus
  /// einer alten Version aktualisiert — die meldete jeden beim Start still
  /// anonym an — landet im Release-Build auf dem Anmelde-Screen statt in einem
  /// Konto, aus dem er nie wieder herauskäme. Sein Fortschritt geht dabei
  /// nicht verloren, siehe [_anmeldenOderVerknuepfen].
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
        OAuthProvider('apple.com').credential(idToken: token, rawNonce: roh),
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

  /// Test-Anmeldung des Debug-Knopfes: ein echtes, anonymes Firebase-Konto.
  ///
  /// Es hat eine vollwertige uid, deshalb läuft danach ALLES normal weiter —
  /// Namensreservierung, Spieler-Dokument, Rangliste, Cloud-Fortschritt. Die
  /// Firestore-Regeln fragen nur `request.auth != null`, nicht nach dem
  /// Anbieter.
  static Future<AnmeldeErgebnis> testAnmeldung() async {
    try {
      await _auth.signInAnonymously();
      return AnmeldeErgebnis.erfolgreich;
    } catch (e) {
      return _deute(e);
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
  ///
  /// ══ DAS IST EINE ENTSCHEIDUNG, KEIN VERGESSEN ═══════════════════════════
  ///
  /// Seit der Cloud-Synchronisierung hat das eine Nebenwirkung: Meldet sich
  /// auf demselben Telefon danach ein ANDERES Konto an, wandert der liegen
  /// gebliebene Fortschritt beim Abgleich in dieses zweite Konto — und von
  /// dort auf dessen andere Geräte. Naheliegende Gegenmassnahme wäre, hier
  /// lokal zu löschen.
  ///
  /// Bewusst nicht getan. Der häufigere Fall ist nicht "zwei Menschen teilen
  /// sich ein Handy", sondern "jemand hat sich versehentlich abgemeldet" —
  /// und der stünde dann vor einem leeren Lernpfad. Ein Spielstand, der beim
  /// Wiederanmelden einfach wieder da ist, wiegt schwerer als der seltene
  /// Fall vermischter Konten.
  ///
  /// Wer hier später "aufräumen" will: Das ist der Grund, warum es so
  /// aussieht.
  static Future<void> abmelden() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nicht mit Google angemeldet gewesen — kein Grund, das Abmelden
      // scheitern zu lassen.
    }
    await _auth.signOut();
  }

  /// Löscht das Testkonto samt reserviertem Namen und Spieler-Dokument.
  ///
  /// Damit lässt sich der ganze Ablauf — Anmelden, Namen wählen, Willkommen —
  /// beliebig oft von vorne durchspielen. Bewusst auf anonyme Konten begrenzt:
  /// ein echtes Google-Konto so wegzuräumen wäre eine Falle.
  ///
  /// Reihenfolge ist wichtig: erst die Firestore-Dokumente, dann das
  /// Auth-Konto. Andersherum wäre man nach dem Löschen nicht mehr angemeldet
  /// und die Regeln liessen das Aufräumen nicht mehr zu — der reservierte Name
  /// bliebe für immer belegt.
  static Future<bool> testkontoLoeschen() async {
    final u = _auth.currentUser;
    if (u == null || !u.isAnonymous) return false;
    try {
      final name = u.displayName;
      if (name != null && _normalisiereName(name).isNotEmpty) {
        await _db
            .collection('anzeigenamen_reserviert')
            .doc(_normalisiereName(name))
            .delete();
      }
      await _db.collection('spieler').doc(u.uid).delete();
      await u.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Löscht das Konto des angemeldeten Spielers — endgültig.
  ///
  /// ══ WARUM ES DAS GEBEN MUSS ═════════════════════════════════════════════
  ///
  /// Apple verlangt es in Guideline 5.1.1(v), Google Play in den
  /// Datenlöschungs-Vorgaben: Wer in einer App ein Konto anlegen kann, muss es
  /// dort auch wieder löschen können — nicht bloss abmelden, und nicht über
  /// einen Umweg per E-Mail. Ohne diese Funktion wird die App abgelehnt.
  ///
  /// ══ DIE REIHENFOLGE IST NICHT BELIEBIG ══════════════════════════════════
  ///
  /// Erst alles, was NUR der Besitzer löschen darf, zuletzt das Konto selbst:
  ///
  ///   1. Namens-Reservierung — sonst bliebe der Name für immer belegt und
  ///      niemand könnte ihn je wieder wählen.
  ///   2. Spieler-Dokument (Rangliste, Anzeigename).
  ///   3. Cloud-Spielstand unter spieler/{uid}/stand/aktuell.
  ///   4. Das Auth-Konto.
  ///
  /// Andersherum wäre man nach Schritt 4 nicht mehr angemeldet, und die
  /// Firestore-Regeln liessen das Aufräumen nicht mehr zu: Alles unter
  /// spieler/{uid} verlangt `request.auth.uid == uid`. Übrig bliebe
  /// verwaister Datenmüll, den niemand mehr wegbekommt — genau das, was die
  /// Vorgaben verhindern sollen.
  ///
  /// Die lokalen SharedPreferences bleiben unangetastet: Sie hängen am Gerät,
  /// nicht am Konto (siehe [abmelden]). Wer die App danach neu einrichtet,
  /// findet seinen Fortschritt am Gerät wieder — in der Cloud liegt nichts
  /// mehr.
  static Future<KontoLoeschErgebnis> kontoLoeschen() async {
    final u = _auth.currentUser;
    if (u == null) return KontoLoeschErgebnis.fehler;
    try {
      final name = u.displayName;
      if (name != null && _normalisiereName(name).isNotEmpty) {
        await _db
            .collection('anzeigenamen_reserviert')
            .doc(_normalisiereName(name))
            .delete();
      }
      // Der Spielstand liegt in einer UNTERkollektion. Ein Dokument zu
      // löschen räumt seine Unterkollektionen NICHT mit weg — das ist eine
      // der bekanntesten Fallen in Firestore. Deshalb ausdrücklich zuerst.
      await _db
          .collection('spieler')
          .doc(u.uid)
          .collection('stand')
          .doc('aktuell')
          .delete();
      await _db.collection('spieler').doc(u.uid).delete();
      await u.delete();
      // Die Google-Sitzung bleibt sonst am Gerät stehen und der nächste
      // Anmeldeversuch nimmt sie wortlos wieder — der Spieler landete dann
      // in einem Konto, das er gerade gelöscht hat.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // War kein Google-Konto.
      }
      return KontoLoeschErgebnis.erfolgreich;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return KontoLoeschErgebnis.erneutAnmelden;
      }
      debugPrint('Kontolöschung fehlgeschlagen: ${e.code}');
      return KontoLoeschErgebnis.fehler;
    } catch (e) {
      debugPrint('Kontolöschung fehlgeschlagen: $e');
      return KontoLoeschErgebnis.fehler;
    }
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

        // Die alte Reservierung freigeben — aber NUR, wenn es sie wirklich
        // gibt und sie mir gehört.
        //
        // Vorher wurde blind gelöscht, sobald im spieler-Dokument ein anderer
        // Name stand. Genau daran scheiterte jeder allererste Name:
        // spielerAnlegen() trägt den Platzhalter "Spieler" ein, den niemand
        // je reserviert hat. Der Löschversuch traf also ein Dokument, das gar
        // nicht existiert — und firestore.rules prüfen für "delete"
        // `resource.data.uid == request.auth.uid`. Ohne resource ist diese
        // Bedingung falsch, die GANZE Transaktion flog mit permission-denied
        // heraus, und der Screen zeigte nur "Etwas ist schiefgelaufen".
        //
        // Der Blick ins Dokument deckt beide Fälle ab: nicht vorhanden und
        // fremd. Ein Existenz-Test allein täte es nicht — eine Reservierung,
        // die inzwischen jemand anderem gehört, dürfte ich ebenso wenig
        // löschen.
        final alterName = altesSpielerDoc.data()?['anzeigename'] as String?;
        final alterNormalisiert =
            alterName == null ? '' : _normalisiereName(alterName);
        DocumentReference<Map<String, dynamic>>? freizugeben;
        if (alterNormalisiert.isNotEmpty &&
            alterNormalisiert != normalisiert) {
          final alteRef =
              _db.collection('anzeigenamen_reserviert').doc(alterNormalisiert);
          final alteReservierung = await transaction.get(alteRef);
          if (alteReservierung.exists &&
              alteReservierung.data()?['uid'] == u.uid) {
            freizugeben = alteRef;
          }
        }
        if (freizugeben != null) transaction.delete(freizugeben);

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
            {
              'anzeigename': neuerName,
              'nameGewaehlt': true,
              // Beim allerersten Namen die Standardfelder gleich mit
              // anlegen. Sie kamen bisher nie an: spielerAnlegen() weiter
              // unten schreibt sie nur, wenn das Dokument noch NICHT
              // existiert — nach dieser Transaktion existiert es aber
              // immer. Wessen Konto also erst hier ein spieler-Dokument
              // bekam, dem fehlten erstelltAm und das Startkapital
              // dauerhaft.
              if (!altesSpielerDoc.exists) ...{
                'erstelltAm': FieldValue.serverTimestamp(),
                'portfolioKapital': 1000.0,
                'portfolioRekord': 1000.0,
              },
            },
            SetOptions(merge: true));
      });
    } on _NameVergebenException {
      return AnzeigenameErgebnis.bereitsVergeben;
    } catch (e) {
      debugPrint('Namens-Reservierung fehlgeschlagen: $e');
      return AnzeigenameErgebnis.fehler;
    }

    try {
      await u.updateDisplayName(neuerName);
      await u.reload();
    } catch (e) {
      debugPrint('Name-Fehler: $e');
    }
    // Hält den Anzeigenamen im Dokument mit dem Konto gleich. Die
    // Standardfelder legt inzwischen die Transaktion oben an — hier kämen
    // sie zu spät, weil das Dokument dann längst existiert.
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
        // Nur schreiben, wenn das Konto wirklich einen Namen trägt. Sonst
        // ersetzte ein fehlgeschlagenes updateDisplayName() den gerade
        // gewählten Namen im Dokument stillschweigend durch den Platzhalter.
        final name = (u.displayName ?? '').trim();
        if (name.isNotEmpty) {
          await ref.update({'anzeigename': name});
        }
      }
    } catch (e) {
      debugPrint('Spieler-Anlegen-Fehler: $e');
    }
  }
}
