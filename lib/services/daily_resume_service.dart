import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Speichert den Zwischenstand einer Tages-Challenge-Runde, damit ein
/// abgebrochenes Spiel beim nächsten Öffnen genau dort weitermacht, statt
/// neu zu starten. Pro Tag ein eigener Schlüssel (wie ChallengeRekordService/
/// DailyChallenge) — am nächsten Tag ist ohnehin eine neue Challenge fällig,
/// ein alter Zwischenstand wird dann nie mehr gelesen.
class DailyResumeService {
  static String _key(String id) {
    final n = DateTime.now();
    return 'ch_resume_${id}_${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  static Future<void> speichern(String id, Map<String, dynamic> zustand) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(id), jsonEncode(zustand));
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

  static Future<void> loeschen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(id));
  }
}
