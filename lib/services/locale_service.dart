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
  ///
  /// Ohne gespeicherte Wahl entscheidet die Systemsprache des Geräts. Vorher
  /// fiel die App hart auf Deutsch zurück — ein englischsprachiger Nutzer
  /// startete also auf Deutsch und musste die Umstellung erst in den
  /// Einstellungen finden.
  static Future<void> laden() async {
    final prefs = await SharedPreferences.getInstance();
    final gewaehlt = prefs.getString(_kSprache);
    // Die eigene Wahl hat immer Vorrang und wird nie überschrieben.
    if (gewaehlt != null) {
      sprache.value = gewaehlt;
      return;
    }
    sprache.value = _systemSprache();
  }

  /// Deutsch nur bei einer deutschsprachigen Systemeinstellung, sonst
  /// Englisch — die App kann nur diese zwei Sprachen, und Englisch ist für
  /// alle übrigen die bessere Näherung.
  ///
  /// Geprüft wird der reine Sprachcode, nicht das ganze Gebietsschema: de_AT
  /// und de_CH sollen genauso Deutsch bekommen wie de_DE.
  ///
  /// Bewusst wird hier NICHTS gespeichert. Der Schlüssel bleibt leer, bis der
  /// Nutzer selbst wählt; stellt er sein Gerät zwischenzeitlich um, zieht die
  /// App beim nächsten Start mit.
  static String _systemSprache() {
    try {
      final code =
          PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      return code.startsWith('de') ? 'de' : 'en';
    } catch (_) {
      // Kein Gebietsschema ermittelbar (z.B. in Tests ohne Binding) — dann
      // bleibt es bei der bisherigen Vorgabe.
      return 'de';
    }
  }

  static Future<void> setzeSprache(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSprache, code);
    sprache.value = code;
  }
}
