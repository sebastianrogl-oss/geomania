import 'dart:async';
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

/// Ausgang eines Anmeldeversuchs — samt dem, was das Gerät WIRKLICH gemeldet
/// hat.
///
/// ══ WARUM DER TECHNISCHE TEXT MIT DURCH MUSS ════════════════════════════════
///
/// [AnmeldeErgebnis] ist eine grobe Einteilung für die Oberfläche, und für die
/// Oberfläche reicht sie auch. Für die Fehlersuche aus der Ferne reicht sie
/// nicht: "nicht eingerichtet" deckt ein fehlendes Entitlement, ein zu altes
/// Provisioning-Profil, einen in Firebase nicht freigeschalteten Anbieter und
/// eine unpassende Client-ID gleichermassen ab. Wer nur diesen Satz gemeldet
/// bekommt, kann die vier Fälle nicht auseinanderhalten und rät.
///
/// [befund] ist deshalb der Rohtext: 'apple/notHandled',
/// 'firebase/invalid-credential', 'google/clientConfigurationError'. Er steht
/// klein unter der freundlichen Meldung, ist absichtlich NICHT übersetzt und
/// absichtlich nicht schön — er wird abfotografiert und weitergeschickt.
class AnmeldeAusgang {
  final AnmeldeErgebnis ergebnis;

  /// null nur bei Erfolg und beim Abbruch durch den Nutzer.
  final String? befund;

  const AnmeldeAusgang(this.ergebnis, {this.befund});

  static const erfolgreich = AnmeldeAusgang(AnmeldeErgebnis.erfolgreich);
  static const abgebrochen = AnmeldeAusgang(AnmeldeErgebnis.abgebrochen);
}

/// Ausgang eines Löschversuchs für ein ECHTES Konto.
///
/// [erneutAnmelden] ist kein Fehler, sondern eine Zwischenstation: Firebase
/// verlangt für das Löschen eines Kontos eine frische Anmeldung
/// ('requires-recent-login'). Wer seit Wochen angemeldet ist, muss sich also
/// einmal neu ausweisen — und der Nutzer muss erfahren, WARUM plötzlich
/// wieder ein Google-Dialog aufgeht.
enum KontoLoeschErgebnis { erfolgreich, erneutAnmelden, fehler }

/// Die Stufen der Löschkette, in genau der Reihenfolge, in der sie ablaufen.
///
/// Steht mit im Fehlertext auf dem Gerät. Ohne diese Angabe ist ein
/// 'permission-denied' nicht zu deuten: Es könnte die Namens-Reservierung
/// sein, der Cloud-Spielstand oder das Spieler-Dokument — drei verschiedene
/// Regeln, drei verschiedene Ursachen.
enum KontoLoeschSchritt {
  reservierung('1 Namens-Reservierung'),
  spielstand('2 Cloud-Spielstand'),
  spielerDokument('3 Spieler-Dokument'),
  konto('4 Auth-Konto');

  const KontoLoeschSchritt(this.bezeichnung);

  /// Bewusst unübersetzt: Dieser Text ist für einen Fehlerbericht, nicht für
  /// den Spieler.
  final String bezeichnung;
}

/// Ausgang eines Löschversuchs — mit Stufe und Fehlercode.
class KontoLoeschAusgang {
  final KontoLoeschErgebnis ergebnis;

  /// Woran es lag. null bei Erfolg.
  final KontoLoeschSchritt? schritt;

  /// Der Rohtext des Fehlers, siehe [AnmeldeAusgang.befund].
  final String? befund;

  const KontoLoeschAusgang(this.ergebnis, {this.schritt, this.befund});

  static const erfolgreich = KontoLoeschAusgang(KontoLoeschErgebnis.erfolgreich);

  /// Was im Dialog steht: "2 Cloud-Spielstand · firestore/permission-denied".
  String get technischerText {
    final teile = <String>[schritt?.bezeichnung ?? '', befund ?? ''];
    return teile.where((s) => s.isNotEmpty).join(' · ');
  }
}

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
  static Future<AnmeldeAusgang> _anmeldenOderVerknuepfen(
      AuthCredential zugangsdaten) async {
    final aktuell = _auth.currentUser;
    if (aktuell != null && aktuell.isAnonymous) {
      try {
        await aktuell.linkWithCredential(zugangsdaten);
        return AnmeldeAusgang.erfolgreich;
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
    return AnmeldeAusgang.erfolgreich;
  }

  /// Übersetzt Firebase-Fehlercodes in die grobe Einteilung von
  /// [AnmeldeErgebnis]. Die drei Codes unten bedeuten alle dasselbe: In der
  /// Konsole fehlt noch etwas.
  ///
  /// Der Rohtext geht IMMER mit — auch wenn die Einteilung ihn verschluckt.
  static AnmeldeAusgang _deute(Object fehler) {
    final befund = befundVon(fehler);
    if (fehler is FirebaseAuthException) {
      const konsole = {
        'operation-not-allowed',
        'invalid-credential',
        'configuration-not-found',
      };
      if (konsole.contains(fehler.code)) {
        return AnmeldeAusgang(AnmeldeErgebnis.nichtEingerichtet,
            befund: befund);
      }
    }
    return AnmeldeAusgang(AnmeldeErgebnis.fehler, befund: befund);
  }

  /// Der Rohtext eines Fehlers, kurz genug für einen Bildschirm.
  ///
  /// Jede der vier Quellen bringt ihren eigenen Code mit, und genau der wird
  /// gebraucht:
  ///
  ///   * `apple/notHandled` gegen `apple/unknown` — das erste zeigt auf ein
  ///     Provisioning-Profil ohne das Sign-in-Recht, das zweite eher auf den
  ///     Anbieter in Firebase.
  ///   * `firebase/invalid-credential` heisst, dass Apple geliefert hat und
  ///     Firebase das Token abgelehnt hat — dann ist das Profil in Ordnung
  ///     und die Konsole nicht.
  ///   * `google/clientConfigurationError` zeigt auf die plist, nicht auf die
  ///     Konsole.
  ///
  /// Absichtlich unübersetzt: Der Text ist für einen Fehlerbericht.
  ///
  /// Öffentlich, damit ein Test echte Ausnahmen hindurchschicken kann statt
  /// nur den Quelltext danach abzusuchen.
  static String befundVon(Object fehler) {
    final text = switch (fehler) {
      FirebaseAuthException e => 'firebase/${e.code}${_zusatz(e.message)}',
      FirebaseException e => '${e.plugin}/${e.code}${_zusatz(e.message)}',
      SignInWithAppleAuthorizationException e =>
        'apple/${e.code.name}${_zusatz(e.message)}',
      SignInWithAppleNotSupportedException e =>
        'apple/nicht-unterstuetzt${_zusatz(e.message)}',
      SignInWithAppleCredentialsException e =>
        'apple/credentials${_zusatz(e.message)}',
      GoogleSignInException e =>
        'google/${e.code.name}${_zusatz(e.description)}',
      TimeoutException _ => 'zeitueberschreitung',
      _ => '${fehler.runtimeType}: $fehler',
    };
    // Eine Meldung, die über den Rand hinausläuft, ist keine Meldung mehr.
    return text.length <= 160 ? text : '${text.substring(0, 157)}...';
  }

  static String _zusatz(String? meldung) {
    final m = (meldung ?? '').trim();
    return m.isEmpty ? '' : ' — $m';
  }

  static Future<AnmeldeAusgang> mitGoogleAnmelden() async {
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
        return const AnmeldeAusgang(AnmeldeErgebnis.nichtEingerichtet,
            befund: 'google/kein-idToken');
      }
      return await _anmeldenOderVerknuepfen(
          GoogleAuthProvider.credential(idToken: idToken));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return AnmeldeAusgang.abgebrochen;
      }
      // "serverClientId must be provided on Android" landet hier.
      return AnmeldeAusgang(AnmeldeErgebnis.nichtEingerichtet,
          befund: befundVon(e));
    } catch (e) {
      return _deute(e);
    }
  }

  /// Nur auf Apple-Plattformen aufrufen — siehe [appleVerfuegbar].
  static Future<AnmeldeAusgang> mitAppleAnmelden() async {
    try {
      // Firebase verlangt den Nonce doppelt: Apple bekommt den SHA-256-Abdruck
      // zu sehen, Firebase den Klartext. Nur so lässt sich prüfen, dass das
      // vorgelegte Token wirklich zu DIESER Anfrage gehört und nicht
      // abgefangen und wiederverwendet wurde.
      final roh = zufallsNonce();
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(roh)).toString(),
      );
      final token = apple.identityToken;
      if (token == null) {
        return const AnmeldeAusgang(AnmeldeErgebnis.fehler,
            befund: 'apple/kein-identityToken');
      }
      // ══ APPLE-EIGENER WEG, NICHT DER ALLGEMEINE OAUTH-WEG ════════════════
      //
      // Hier stand `OAuthProvider('apple.com').credential(...)`. Das sieht
      // gleichwertig aus, ist es auf iOS aber nicht — und genau daran
      // scheiterte die Anmeldung mit
      // "firebase/invalid-credential — Invalid OAuth response from apple.com",
      // obwohl der Apple-Dialog sauber durchlief.
      //
      // Der Grund steht im Plugin. Die native Seite verzweigt nicht nach der
      // providerId, sondern nach dem signInMethod des Zugangsdatums
      // (FLTFirebaseAuthPlugin.m):
      //
      //   OAuthProvider(...).credential()   -> signInMethod 'oauth'
      //       -> [FIROAuthProvider credentialWithProviderID:IDToken:
      //                                            rawNonce:accessToken:]
      //   AppleAuthProvider.credentialWithIDToken(...) -> 'apple.com'
      //       -> [FIROAuthProvider appleCredentialWithIDToken:rawNonce:
      //                                              fullName:]
      //
      // Zwei verschiedene Aufrufe des Firebase-SDK. Der zweite ist der für
      // Sign in with Apple vorgesehene; der erste ist der allgemeine Weg für
      // beliebige OAuth-Anbieter, und der Dienst bei Apple beantwortet ihn
      // nicht so, wie Firebase es dann erwartet.
      //
      // Der Nonce ist dabei unverändert richtig: Apple bekommt den
      // SHA-256-Abdruck zu sehen, Firebase den Klartext — einmal gehasht,
      // nicht vertauscht. Das Plugin reicht den Nonce unverändert an
      // ASAuthorizationAppleIDRequest weiter (nachgesehen in
      // SignInWithAppleAvailablePlugin.swift), hasht also nichts ein zweites
      // Mal.
      //
      // NEBENBEI GERETTET: der Name. Apple liefert Vor- und Nachnamen
      // ausschliesslich bei der ALLERERSTEN Anmeldung mit — danach nie
      // wieder, auch nicht nach einer Neuinstallation. Der allgemeine Weg
      // kennt kein Namensfeld, der Wert fiel also bisher weg, obwohl er
      // angefordert wurde.
      return await _anmeldenOderVerknuepfen(
        AppleAuthProvider.credentialWithIDToken(
          token,
          roh,
          AppleFullPersonName(
            givenName: apple.givenName,
            familyName: apple.familyName,
          ),
        ),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AnmeldeAusgang.abgebrochen;
      }
      // ══ HIER STEHT DIE ANTWORT AUF "APPLE IST NICHT EINGERICHTET" ═════════
      //
      // Alles ausser 'canceled' landete bisher wortlos auf "noch nicht
      // eingerichtet". Der Code darunter trennt aber genau die Fälle, die
      // sich vom Rechner aus nicht auseinanderhalten lassen:
      //
      //   notHandled  — iOS hat die Anfrage gar nicht erst angenommen. Das
      //                 ist der Fingerabdruck eines Programms, dessen
      //                 Provisioning-Profil das Sign-in-Recht nicht kennt:
      //                 Die Datei Runner.entitlements im Projekt reicht
      //                 nicht, das Recht muss auch in der App-ID im
      //                 Developer-Portal stehen und das Profil danach neu
      //                 erzeugt worden sein.
      //   unknown /
      //   failed      — der Dialog lief, Apple lehnte ab. Dann zeigt es eher
      //                 auf die Service-ID oder den Schlüssel in Firebase.
      //   invalidResponse — Apple antwortete, aber unbrauchbar.
      //
      // Erst mit diesem Code lässt sich sagen, wo gesucht werden muss.
      return AnmeldeAusgang(AnmeldeErgebnis.nichtEingerichtet,
          befund: befundVon(e));
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
  static Future<AnmeldeAusgang> testAnmeldung() async {
    try {
      await _auth.signInAnonymously();
      return AnmeldeAusgang.erfolgreich;
    } catch (e) {
      return _deute(e);
    }
  }

  /// Erzeugt den Klartext-Nonce für die Apple-Anmeldung.
  ///
  /// [Random.secure] und nicht [Random]: Der Nonce ist das Einzige, was ein
  /// abgefangenes und erneut vorgelegtes Apple-Token auffliegen lässt. Wäre
  /// er vorhersagbar, wäre er wertlos.
  ///
  /// Der Zeichenvorrat ist der aus Apples eigenem Beispiel — alles darin ist
  /// URL-sicher und übersteht den Weg durch Apple und Firebase unverändert.
  ///
  /// Öffentlich, damit ein Test ihn prüfen kann.
  static String zufallsNonce([int laenge = 32]) {
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
    await _googleSitzungBeenden();
    await _auth.signOut();
  }

  /// Beendet die Google-Sitzung am Gerät. Ein Fehlschlag ist folgenlos.
  ///
  /// ══ GEPRÜFT, WEIL ES ALS VERDÄCHTIGER GEHANDELT WURDE ═══════════════════
  ///
  /// Verdacht: Der Google-Abmelder könnte auf iOS werfen und die Löschkette
  /// aufhalten, bevor sie überhaupt anfängt. Nachgesehen im Plugin: Auf iOS
  /// tut `signOut` nichts weiter, als `[GIDSignIn signOut]` aufzurufen; die
  /// native Seite meldet dabei überhaupt keinen Fehler zurück
  /// (`signOutWithError:` setzt den Fehlerzeiger nie). Er kann also weder
  /// werfen noch hängen — und in der Löschkette steht er ohnehin erst NACH
  /// dem Konto.
  ///
  /// Das Zeitlimit bleibt trotzdem: Ein Aufruf, der nie zurückkehrt, würde
  /// den Erfolgsfall verschlucken und den Spieler auf dem Einstellungs-Screen
  /// stehen lassen — obwohl sein Konto längst gelöscht ist.
  static Future<void> _googleSitzungBeenden() async {
    try {
      await GoogleSignIn.instance.signOut().timeout(const Duration(seconds: 5));
    } catch (e) {
      // Nicht mit Google angemeldet gewesen — kein Grund, deshalb das
      // Abmelden oder Löschen scheitern zu lassen.
      debugPrint('Google-Sitzung blieb stehen: ${befundVon(e)}');
    }
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
  /// Zeitlimit für jeden einzelnen Schritt.
  ///
  /// ══ OHNE DAS PASSIERT BEI EINEM FEHLSCHLAG BUCHSTÄBLICH NICHTS ══════════
  ///
  /// Firestore nimmt Schreibvorgänge zuerst lokal entgegen und löst das
  /// Future erst auf, wenn der Server sie bestätigt hat. Ohne tragfähige
  /// Verbindung wartet es unbegrenzt — kein Fehler, keine Ausnahme, einfach
  /// nie eine Antwort. Der Spieler tippt "Endgültig löschen", und die App
  /// steht still da: kein Anmelde-Screen, keine Meldung, nichts.
  ///
  /// Das Zeitlimit macht daraus einen sichtbaren Fehler mit Stufenangabe.
  /// Fünfzehn Sekunden sind reichlich für einen Löschvorgang, der am Gerät
  /// sonst in unter einer Sekunde durch ist, und kurz genug, dass niemand
  /// glaubt, die App sei abgestürzt.
  static const _kSchrittZeitlimit = Duration(seconds: 15);

  /// Führt einen Schritt aus. Rückgabe null = geklappt.
  static Future<KontoLoeschAusgang?> _loeschSchritt(
      KontoLoeschSchritt schritt, Future<void> Function() tun) async {
    try {
      await tun().timeout(_kSchrittZeitlimit);
      return null;
    } on FirebaseAuthException catch (e) {
      // 'requires-recent-login' ist der wahrscheinlichste Fall überhaupt:
      // "recent" heisst bei Firebase wenige Minuten, nicht "seit dem letzten
      // Start angemeldet". Wer die Einstellungen erst nach einer Weile
      // öffnet, läuft hier zwangsläufig hinein.
      return KontoLoeschAusgang(
        e.code == 'requires-recent-login'
            ? KontoLoeschErgebnis.erneutAnmelden
            : KontoLoeschErgebnis.fehler,
        schritt: schritt,
        befund: befundVon(e),
      );
    } catch (e) {
      return KontoLoeschAusgang(KontoLoeschErgebnis.fehler,
          schritt: schritt, befund: befundVon(e));
    }
  }

  static Future<KontoLoeschAusgang> kontoLoeschen() async {
    final u = _auth.currentUser;
    if (u == null) {
      return const KontoLoeschAusgang(KontoLoeschErgebnis.fehler,
          befund: 'kein-konto-angemeldet');
    }
    final spieler = _db.collection('spieler').doc(u.uid);

    // ── 1. Namens-Reservierung ────────────────────────────────────────────
    //
    // ALS EINZIGER SCHRITT NICHT ABBRECHEND. Das Konto MUSS löschbar sein —
    // Apple 5.1.1(v) lässt keinen Fall zu, in dem der Spieler mit einem
    // unlöschbaren Konto dasteht. Ein liegen gebliebener reservierter Name
    // ist ärgerlich; ein Konto, das sich nicht löschen lässt, kostet die
    // Freigabe. Wenn hier etwas schiefgeht, geht die Kette weiter und der
    // Fall landet im Protokoll.
    final reservierung = await _loeschSchritt(
        KontoLoeschSchritt.reservierung, () => _reservierungFreigeben(u, spieler));

    // ── 2. Cloud-Spielstand ───────────────────────────────────────────────
    //
    // Der Spielstand liegt in einer UNTERkollektion. Ein Dokument zu löschen
    // räumt seine Unterkollektionen NICHT mit weg — das ist eine der
    // bekanntesten Fallen in Firestore. Deshalb ausdrücklich vor dem
    // Elterndokument.
    final stand = await _loeschSchritt(KontoLoeschSchritt.spielstand,
        () => spieler.collection('stand').doc('aktuell').delete());
    if (stand != null) return stand;

    // ── 3. Spieler-Dokument (Rangliste, Anzeigename) ──────────────────────
    final dokument =
        await _loeschSchritt(KontoLoeschSchritt.spielerDokument, spieler.delete);
    if (dokument != null) return dokument;

    // ── 4. Auth-Konto ─────────────────────────────────────────────────────
    final konto = await _loeschSchritt(KontoLoeschSchritt.konto, u.delete);
    if (konto != null) return konto;

    // Die Google-Sitzung bleibt sonst am Gerät stehen und der nächste
    // Anmeldeversuch nimmt sie wortlos wieder — der Spieler landete dann
    // in einem Konto, das er gerade gelöscht hat.
    await _googleSitzungBeenden();

    if (reservierung != null) {
      debugPrint('Konto gelöscht, aber der Name blieb belegt: '
          '${reservierung.technischerText}');
    }
    return KontoLoeschAusgang.erfolgreich;
  }

  /// Gibt den reservierten Anzeigenamen wieder frei.
  ///
  /// ══ ERST LESEN, DANN LÖSCHEN — UND DAS IST KEIN UMWEG ═══════════════════
  ///
  /// firestore.rules erlauben das Löschen einer Reservierung nur mit
  /// `resource.data.uid == request.auth.uid`. Auf ein Dokument, das es gar
  /// nicht gibt, ist `resource` null — die Bedingung ist damit falsch, und
  /// der Löschversuch scheitert mit permission-denied, obwohl schlicht
  /// nichts aufzuräumen war. Genau diese Falle hat schon einmal die
  /// Namensreservierung zerlegt (siehe [setzeAnzeigenameEindeutig]); vorher
  /// stand sie hier ein zweites Mal.
  ///
  /// Der Schlüssel kommt aus BEIDEN Quellen: Das spieler-Dokument führt den
  /// gewählten Namen, der Anzeigename des Kontos sollte derselbe sein — muss
  /// es aber nicht. `updateDisplayName` darf fehlschlagen, ohne dass die
  /// Reservierung ausbleibt, und dann steht im Konto noch der Klarname aus
  /// dem Google-Profil.
  static Future<void> _reservierungFreigeben(
      User u, DocumentReference<Map<String, dynamic>> spieler) async {
    final namen = <String>{_normalisiereName(u.displayName ?? '')};
    try {
      final daten = (await spieler.get()).data();
      namen.add(_normalisiereName(daten?['anzeigename'] as String? ?? ''));
    } catch (e) {
      // Ohne das Dokument bleibt der Anzeigename des Kontos.
      debugPrint('Spieler-Dokument nicht lesbar: ${befundVon(e)}');
    }
    for (final name in namen.where((n) => n.isNotEmpty)) {
      final ref = _db.collection('anzeigenamen_reserviert').doc(name);
      final vorhanden = await ref.get();
      if (vorhanden.exists && vorhanden.data()?['uid'] == u.uid) {
        await ref.delete();
      }
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
