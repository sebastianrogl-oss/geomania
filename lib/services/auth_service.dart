import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AnzeigenameErgebnis { erfolgreich, bereitsVergeben, fehler }

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

  // Anonyme Anmeldung beim ersten Start
  static Future<User?> anonymAnmelden() async {
    try {
      if (_auth.currentUser != null) {
        return _auth.currentUser;
      }
      final result = await _auth.signInAnonymously();
      return result.user;
    } catch (e) {
      print('Anmelde-Fehler: $e');
      return null;
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

        if (vorhandenesDoc.exists &&
            vorhandenesDoc.data()?['uid'] != u.uid) {
          // Name ist von JEMAND ANDEREM bereits vergeben.
          throw _NameVergebenException();
        }
        // Falls vorhandeneUid == eigene uid: eigener Name wird nur
        // aktualisiert (z.B. Groß-/Kleinschreibung geändert) — erlaubt.

        final alterName = altesSpielerDoc.data()?['anzeigename'] as String?;
        if (alterName != null) {
          final alterNormalisiert = _normalisiereName(alterName);
          if (alterNormalisiert.isNotEmpty && alterNormalisiert != normalisiert) {
            transaction.delete(_db
                .collection('anzeigenamen_reserviert')
                .doc(alterNormalisiert));
          }
        }

        transaction.set(docRef, {
          'uid': u.uid,
          'anzeigename': neuerName,
          'reserviertAm': FieldValue.serverTimestamp(),
        });
        transaction
            .set(spielerRef, {'anzeigename': neuerName}, SetOptions(merge: true));
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
          'anzeigename': u.displayName ?? 'Spieler',
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
