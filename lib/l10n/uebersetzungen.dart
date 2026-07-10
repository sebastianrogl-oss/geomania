import '../services/locale_service.dart';
import 'uebersetzungen_settings.dart';

// Zentrale Übersetzungstabelle (Deutsch -> Englisch). Statt eines
// offiziellen ARB-/gen-l10n-Setups (zu viel Umbau-Overhead für eine bereits
// fertige, komplett deutschsprachige Codebase) wird jeder deutsche String
// zur Laufzeit über diese Tabelle nachgeschlagen. Auf mehrere Teil-Dateien
// aufgeteilt (pro Datenquelle/Screen-Gruppe), damit parallele Bearbeitung
// an unabhängigen Dateien möglich ist, ohne dass sich Änderungen an EINER
// riesigen Map gegenseitig überschreiben.
final Map<String, String> uebersetzungen = {
  ...uebersetzungenSettings,
};

/// Übersetzt [de] nach Englisch, wenn LocaleService.istEnglisch — sonst wird
/// [de] unverändert zurückgegeben. [p] ersetzt {platzhalter} im Ergebnis
/// (für Strings mit interpolierten Werten, z.B. t('{n} Punkte', {'n': '5'})).
String t(String de, [Map<String, String>? p]) {
  var s = LocaleService.istEnglisch ? (uebersetzungen[de] ?? de) : de;
  if (p != null) {
    for (final e in p.entries) {
      s = s.replaceAll('{${e.key}}', e.value);
    }
  }
  return s;
}
