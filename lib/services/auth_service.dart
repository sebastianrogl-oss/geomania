import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        print('Bereits angemeldet: ${_auth.currentUser!.uid}');
        return _auth.currentUser;
      }
      final result = await _auth.signInAnonymously();
      print('Anonym angemeldet: ${result.user?.uid}');
      return result.user;
    } catch (e) {
      print('Anmelde-Fehler: $e');
      return null;
    }
  }

  static Future<void> setzeAnzeigename(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name);
      await _auth.currentUser?.reload();
      print('Anzeigename gesetzt: $name');
    } catch (e) {
      print('Name-Fehler: $e');
    }
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
