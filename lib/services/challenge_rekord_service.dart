import 'package:shared_preferences/shared_preferences.dart';

class ChallengeRekordService {
  static String _rekordKey(String id) => 'ch_rekord_$id';
  static String _heuteKey(String id) {
    final n = DateTime.now();
    return 'ch_heute_${id}_${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  static Future<int?> getRekord(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_rekordKey(id));
    return v;
  }

  static Future<bool> setzeFallsBesser(String id, int punkte) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _rekordKey(id);
    final aktuell = prefs.getInt(key);
    if (aktuell == null || punkte > aktuell) {
      await prefs.setInt(key, punkte);
      return true;
    }
    return false;
  }

  static Future<int?> getHeutigePunkte(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_heuteKey(id));
  }

  static Future<void> speichereHeutigePunkte(String id, int punkte) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_heuteKey(id), punkte);
  }
}
