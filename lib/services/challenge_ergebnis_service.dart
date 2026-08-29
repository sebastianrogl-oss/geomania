import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Speichert die vollständige Detail-Aufschlüsselung des heutigen Ergebnisses
/// einer Tages-Challenge (z.B. falsch geratenes Land, gewählte Zuordnungen),
/// damit "Ergebnisse ansehen" das echte Tagesergebnis rekonstruieren kann.
/// Anders als DailyResumeService wird dieser Eintrag NICHT beim Abschluss
/// gelöscht — er bleibt für den restlichen Tag als "nur ansehen"-Quelle.
class ChallengeErgebnisService {
  static String _key(String id) {
    final n = DateTime.now();
    return 'ch_ergebnis_${id}_${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  static Future<void> speichern(String id, Map<String, dynamic> detail) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(id), jsonEncode(detail));
  }

  /// DEBUG: Wirft das gespeicherte Detail-Ergebnis von heute weg.
  static Future<void> debugLoeschen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(id));
  }

  static Future<Map<String, dynamic>?> laden(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(id));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
