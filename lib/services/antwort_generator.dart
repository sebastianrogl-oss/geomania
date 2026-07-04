import 'dart:math';
import '../data/countries.dart';

// Hinweis: Die Preisschätzen-Skalen im Lernpfad kommen seit der adaptiven
// Umstellung aus SkalaService.fuerKategorie() (pro Land berechnet, wie bei
// der Tages-Challenge) — die frühere statische Kontinent-Tabelle wurde
// entfernt, weil sie dieselbe Aufgabe schlechter (nicht adaptiv) löste.

// ── Antwort-Optionen Generator ────────────────────────────────────────────────

class AntwortGenerator {
  static final _rng = Random();

  // Bevölkerungsgrenzen für Schwierigkeitsstufen (als Proxy für Bekanntheit)
  static const _bekanntheitsSchwellen = [5000000, 2000000, 500000, 0];

  static List<Country> _laenderFuerKontinent(String kontinent) {
    if (kontinent == 'Welt') return countries;
    return countries.where((c) => c.region == kontinent).toList();
  }

  static List<Country> _filteredByDifficulty(
      List<Country> pool, int schwierigkeit) {
    final schwelle = _bekanntheitsSchwellen[schwierigkeit.clamp(1, 4) - 1];
    if (schwelle == 0) return pool;
    final gefiltert = pool.where((c) => c.population >= schwelle).toList();
    // Fallback: nimm mindestens 6 Länder (für kleine Kontinente)
    return gefiltert.length >= 6
        ? gefiltert
        : (pool..sort((a, b) => b.population.compareTo(a.population)))
            .take(6)
            .toList();
  }

  /// Gibt 4 Antwort-ISO2-Codes zurück (richtige Antwort + 3 Distraktoren).
  /// Alle kommen aus demselben Kontinent wie [richtigesLand].
  static List<String> generiereOptionen(
    String richtigesLand,
    String kontinent,
    int schwierigkeit, {
    int anzahlOptionen = 4,
  }) {
    final alleKontinentLaender = _laenderFuerKontinent(kontinent);
    final pool = _filteredByDifficulty(alleKontinentLaender, schwierigkeit)
        .where((c) => c.iso2 != richtigesLand)
        .toList();

    pool.shuffle(_rng);

    final distraktoren = pool
        .take(anzahlOptionen - 1)
        .map((c) => c.iso2)
        .toList();

    final optionen = [richtigesLand, ...distraktoren]..shuffle(_rng);
    return optionen;
  }

  /// Variante mit expliziter Kandidatenliste (für kontinent-spezifische
  /// Stationen, die nur bestimmte Länder enthalten).
  static List<String> generiereOptionenAusListe(
    String richtigesLand,
    List<String> kandidaten, {
    int anzahlOptionen = 4,
  }) {
    final pool = kandidaten.where((id) => id != richtigesLand).toList()
      ..shuffle(_rng);

    // Wenn zu wenige im Pool: fill-up aus globalem Kontinent
    List<String> distraktoren = pool.take(anzahlOptionen - 1).toList();
    if (distraktoren.length < anzahlOptionen - 1) {
      final country = countries.firstWhere(
        (c) => c.iso2 == richtigesLand,
        orElse: () => countries.first,
      );
      final extra = _laenderFuerKontinent(country.region)
          .where((c) => c.iso2 != richtigesLand && !distraktoren.contains(c.iso2))
          .map((c) => c.iso2)
          .toList()
        ..shuffle(_rng);
      distraktoren.addAll(extra.take(anzahlOptionen - 1 - distraktoren.length));
    }

    return [richtigesLand, ...distraktoren]..shuffle(_rng);
  }
}
