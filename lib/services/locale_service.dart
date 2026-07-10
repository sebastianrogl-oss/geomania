import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-Sprache (Deutsch/Englisch) — rein lokal, kein Konto-Bezug. `sprache`
/// ist ein ValueNotifier (wie FortschrittService.resetSignal), damit ein
/// Sprachwechsel per Listener einen App-weiten Rebuild auslösen kann, ohne
/// dass jeder Screen einzeln auf SharedPreferences zugreifen muss.
class LocaleService {
  static const _kSprache = 'einstellung_sprache';

  static final sprache = ValueNotifier<String>('de');

  static bool get istEnglisch => sprache.value == 'en';

  /// Muss vor runApp() aufgerufen werden, damit die App gleich in der
  /// zuletzt gewählten Sprache startet statt kurz Deutsch aufzublitzen.
  static Future<void> laden() async {
    final prefs = await SharedPreferences.getInstance();
    sprache.value = prefs.getString(_kSprache) ?? 'de';
  }

  static Future<void> setzeSprache(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSprache, code);
    sprache.value = code;
  }
}
