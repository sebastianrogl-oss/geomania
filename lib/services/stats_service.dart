import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  static const _cats = ['flags', 'capitals', 'economy', 'map'];

  // ── Daily challenge ──────────────────────────────────────────────────────────

  static Future<void> saveResult({
    required String category,
    required bool isDaily,
    required int score,
    required int total,
  }) async {
    if (total == 0) return;
    final pct = (score / total * 100).round();
    final prefs = await SharedPreferences.getInstance();

    if (isDaily) {
      final key = 'dc_$category';
      final date = _today();
      final entries = _listMap(prefs.getString(key));
      if (!entries.any((e) => e['date'] == date)) {
        entries.add({'date': date, 'pct': pct});
        await prefs.setString(key, jsonEncode(entries));
      }
    }
  }

  static Future<DailyCatStats> getDailyStats(String cat) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _listMap(prefs.getString('dc_$cat'));
    if (entries.isEmpty) return DailyCatStats.empty();
    final n = entries.length;
    final sumPct = entries.fold<int>(0, (s, e) => s + (e['pct'] as int));
    final perfect = entries.where((e) => (e['pct'] as int) == 100).length;
    return DailyCatStats(completions: n, avgPct: sumPct ~/ n, perfect: perfect);
  }

  static Future<Map<String, DailyCatStats>> allDailyStats() async {
    final m = <String, DailyCatStats>{};
    for (final c in _cats) {
      m[c] = await getDailyStats(c);
    }
    return m;
  }

  // Streak = consecutive days where ALL 4 daily challenges were done
  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    Set<String>? common;
    for (final cat in _cats) {
      final dates = _listMap(prefs.getString('dc_$cat'))
          .map((e) => e['date'] as String)
          .toSet();
      common = common == null ? dates : common.intersection(dates);
    }
    if (common == null || common.isEmpty) return 0;
    int streak = 0;
    var day = DateTime.now();
    while (common.contains(_fmt(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ── Lernen progress (per-country streak tracking) ────────────────────────────

  /// Call after every lernen quiz with the per-country results.
  /// [answers]: iso2 → wasCorrect
  static Future<void> saveCountryAnswers({
    required String category,
    required Map<String, bool> answers,
  }) async {
    if (answers.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'progress_$category';
    final raw = prefs.getString(key);
    final data = raw != null
        ? (jsonDecode(raw) as Map<String, dynamic>)
        : <String, dynamic>{};

    for (final e in answers.entries) {
      final cur = (data[e.key] as int?) ?? 0;
      data[e.key] = e.value ? cur + 1 : 0;
    }

    await prefs.setString(key, jsonEncode(data));
  }

  static Future<LernenProgress> getLernenProgress(String cat) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('progress_$cat');
    if (raw == null) return LernenProgress.empty();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    int seen = 0, mastered = 0;
    for (final v in data.values) {
      final s = v as int;
      if (s >= 1) seen++;
      if (s >= 3) mastered++;
    }
    return LernenProgress(seenCount: seen, masteredCount: mastered);
  }

  static Future<Map<String, LernenProgress>> allLernenProgress() async {
    final m = <String, LernenProgress>{};
    for (final c in _cats) {
      m[c] = await getLernenProgress(c);
    }
    return m;
  }

  static Future<Map<String, int>> getRawProgressMap(String cat) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('progress_$cat');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));
  }

  static LernenProgress progressForIso2s(
      Map<String, int> rawMap, List<String> iso2s) {
    int seen = 0, mastered = 0;
    for (final iso2 in iso2s) {
      final s = rawMap[iso2] ?? 0;
      if (s >= 1) seen++;
      if (s >= 3) mastered++;
    }
    return LernenProgress(
        seenCount: seen, masteredCount: mastered, total: iso2s.length);
  }

  // ── Lernen streak (consecutive days all 4 categories played) ─────────────────

  static Future<void> saveLernenDoneToday(String cat) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final key = 'lernen_days_$cat';
    final days = _parseDays(prefs.getString(key));
    if (!days.contains(today)) {
      days.add(today);
      await prefs.setString(key, jsonEncode(days));
    }
  }

  static Future<bool> allLernenDoneToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    for (final cat in _cats) {
      if (!_parseDays(prefs.getString('lernen_days_$cat')).contains(today)) {
        return false;
      }
    }
    return true;
  }

  static Future<int> getLernenStreak() async {
    final prefs = await SharedPreferences.getInstance();
    Set<String>? common;
    for (final cat in _cats) {
      final days = _parseDays(prefs.getString('lernen_days_$cat')).toSet();
      common = common == null ? days : common.intersection(days);
    }
    if (common == null || common.isEmpty) return 0;
    int streak = 0;
    var day = DateTime.now();
    while (common.contains(_fmt(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _today() => _fmt(DateTime.now());
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<String> _parseDays(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _listMap(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class DailyCatStats {
  final int completions, avgPct, perfect;
  const DailyCatStats(
      {required this.completions,
      required this.avgPct,
      required this.perfect});
  factory DailyCatStats.empty() =>
      const DailyCatStats(completions: 0, avgPct: 0, perfect: 0);
  bool get hasData => completions > 0;
}

class LernenProgress {
  final int seenCount;
  final int masteredCount;
  final int total;

  const LernenProgress({required this.seenCount, required this.masteredCount, this.total = 195});
  factory LernenProgress.empty({int total = 195}) =>
      LernenProgress(seenCount: 0, masteredCount: 0, total: total);

  bool get hasData => seenCount > 0;
  double get seenFraction => total > 0 ? seenCount / total : 0;
  double get masteredFraction => total > 0 ? masteredCount / total : 0;
  int get seenPct => total > 0 ? (seenCount / total * 100).round() : 0;
  int get masteredPct => total > 0 ? (masteredCount / total * 100).round() : 0;
}

// Keep for any remaining daily-challenge usages
class LernenStats {
  final int sessions, avgPct;
  const LernenStats({required this.sessions, required this.avgPct});
  factory LernenStats.empty() => const LernenStats(sessions: 0, avgPct: 0);
  bool get hasData => sessions > 0;
}
