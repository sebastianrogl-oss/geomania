import 'package:shared_preferences/shared_preferences.dart';

class DailyChallenge {
  static String _key() {
    final n = DateTime.now();
    return 'daily_${n.year}_${n.month.toString().padLeft(2, '0')}_${n.day.toString().padLeft(2, '0')}';
  }

  static Future<Set<String>> completedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key()) ?? []).toSet();
  }

  static Future<void> markDone(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key();
    final done = (prefs.getStringList(key) ?? []).toSet()..add(id);
    await prefs.setStringList(key, done.toList());
  }

  static Duration untilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }
}
