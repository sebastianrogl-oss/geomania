import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verwaltet das auswählbare Profilbild — nutzt die bereits vorhandenen
/// Kontinent-Deko-/Maskottchen-Icons aus assets/icons/deko/ statt neuer Assets.
class ProfilbildService {
  static const _key = 'profilbild_pfad';

  /// Wird hochgezählt, sobald sich das Profilbild ändert — damit andere,
  /// dauerhaft lebende Screens (z.B. HomeScreen, per IndexedStack nie neu
  /// aufgebaut) es ohne kompletten Reload nachziehen können.
  static final geaendert = ValueNotifier<int>(0);

  static const List<String> verfuegbareBilder = [
    'assets/icons/deko/globus_normal.png',
    'assets/icons/deko/globus_winken.png',
    'assets/icons/deko/globus_denken.png',
    'assets/icons/deko/globus_ueberrascht.png',
    'assets/icons/deko/coin_normal.png',
    'assets/icons/deko/coin_winken.png',
    'assets/icons/deko/coin_denken.png',
    'assets/icons/deko/coin_ueberrascht.png',
    'assets/icons/deko/afrika_elefant.png',
    'assets/icons/deko/afrika_giraffe.png',
    'assets/icons/deko/afrika_nashorn.png',
    'assets/icons/deko/asien_panda.png',
    'assets/icons/deko/nordamerika_adler.png',
    'assets/icons/deko/nordamerika_baer.png',
    'assets/icons/deko/ozeanien_kaenguru.png',
    'assets/icons/deko/ozeanien_koala.png',
    'assets/icons/deko/ozeanien_shark.png',
    'assets/icons/deko/suedamerika_jaguar.png',
    'assets/icons/deko/suedamerika_lama.png',
    'assets/icons/deko/suedamerika_tukan.png',
    'assets/icons/deko/welt_rakete.png',
    'assets/icons/deko/welt_kompass.png',
  ];

  static const String standard = 'assets/icons/deko/globus_normal.png';

  static Future<String> getProfilbild() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? standard;
  }

  static Future<void> setProfilbild(String pfad) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pfad);
    geaendert.value++;
  }

  // Globus-/Coin-Assets sind breite 677x369-Bilder (statt quadratisch wie die
  // übrigen Deko-Icons) -> unter BoxFit.contain in einem quadratischen Kreis
  // werden sie oben/unten stark gestaucht und wirken viel kleiner als die
  // anderen Profilbild-Optionen. BoxFit.cover füllt den Kreis stattdessen voll.
  static bool istWeitformat(String pfad) =>
      pfad.contains('/globus_') || pfad.contains('/coin_');

  // ── Werbe-Freischaltung ────────────────────────────────────────────────────
  //
  // Coin/Globus bleiben immer kostenlos (Standard-Auswahl + einfachster
  // Einstieg). Die restlichen Kontinent-Tier-Icons sind per Rewarded-Ad
  // (1 Werbung) dauerhaft freischaltbar — eigenständig vom Abzeichen-System
  // (freigeschalteteAbzeichen), das eine andere Belohnungsquelle betrifft.
  static const _kFreigeschaltetPrefix = 'profilbild_freigeschaltet_';

  static bool istImmerKostenlos(String pfad) => istWeitformat(pfad);

  static Future<bool> istFreigeschaltet(String pfad) async {
    if (istImmerKostenlos(pfad)) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kFreigeschaltetPrefix$pfad') ?? false;
  }

  static Future<void> schalteFrei(String pfad) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kFreigeschaltetPrefix$pfad', true);
  }

  // ── Sterne-Freischaltung ───────────────────────────────────────────────────
  //
  // Die dritte Reihe des Auswahl-Rasters (4 Bilder, direkt unter den
  // kostenlosen Globus-/Coin-Reihen) wird über Sterne statt über Werbung
  // freigeschaltet — für diese vier entfällt der Rewarded-Ad-Weg damit.
  // Alle übrigen Icons bleiben unverändert per Werbung erhältlich.
  //
  // Zur Einordnung der Preise: im gesamten Lernpfad sind 4480 Sterne
  // erreichbar (ausgezählt über alle 594 Stationen, ein Stern je erstmalig
  // richtiger Frage).
  //
  // Verlauf: 5151 vor der Modus-Umstellung, 5095 danach, 4605 nach der
  // Kürzung der Welt-Welt auf 8 Fragen, 4480 seit der Rhythmus-Umstellung —
  // dort kommt sortierSpiel häufiger vor, und das hat immer nur 3 Fragen.
  //
  // Grundlage sind fragenProStation je Welt, kFragenObergrenze je Modus und
  // die Modus-Verteilung selbst, alle in lernpfad_data.dart. Wer dort etwas
  // ändert, sollte die Zahl hier nachrechnen.
  //
  // Die Preise wurden gegen 4605 nachkalibriert (vorher 150/500/1200/2500
  // gegen 5151). Sie treffen die urspruenglich gewollten Anteile weiterhin:
  // das teuerste Bild kostet 49 % aller erreichbaren Sterne, alle vier
  // zusammen 85 %.
  //
  // ACHTUNG: Diese Anteile sind der eigentliche Massstab, nicht die absoluten
  // Zahlen. Sinkt die Gesamtzahl erneut — etwa weil eine Welt weniger Fragen
  // pro Station bekommt — werden die Preise still teurer, ohne dass jemand
  // sie anfasst. Genau so ist die Staffel zwischenmal auf 94 % gerutscht.
  static const sternePreise = <String, int>{
    'assets/icons/deko/afrika_elefant.png': 150,
    'assets/icons/deko/afrika_giraffe.png': 450,
    'assets/icons/deko/afrika_nashorn.png': 1000,
    'assets/icons/deko/asien_panda.png': 2200,
  };

  /// Bereits ausgegebene Sterne. Der Gesamtstand (lp_gesamt_richtig in
  /// FortschrittService) bleibt davon unberührt und sinkt nie — er dient
  /// weiterhin Statistiken und dem Header. Bezahlt wird mit der Differenz.
  static const _kAusgegeben = 'sterne_ausgegeben';

  static bool kostetSterne(String pfad) => sternePreise.containsKey(pfad);

  static Future<int> ausgegebeneSterne() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kAusgegeben) ?? 0;
  }

  /// Verdiente minus ausgegebene Sterne — der Stand, mit dem bezahlt wird.
  static Future<int> verfuegbareSterne(int verdient) async {
    final ausgegeben = await ausgegebeneSterne();
    return (verdient - ausgegeben).clamp(0, verdient);
  }

  /// Zieht den Preis ab und schaltet das Bild dauerhaft frei.
  ///
  /// Gibt false zurück, wenn das Bild keinen Preis hat oder die Sterne nicht
  /// reichen — der Aufrufer hat das zwar schon geprüft, aber die Buchung soll
  /// sich nicht darauf verlassen.
  static Future<bool> kaufeMitSternen(String pfad, int verfuegbar) async {
    final preis = sternePreise[pfad];
    if (preis == null || verfuegbar < preis) return false;
    final prefs = await SharedPreferences.getInstance();
    final ausgegeben = prefs.getInt(_kAusgegeben) ?? 0;
    await prefs.setInt(_kAusgegeben, ausgegeben + preis);
    await prefs.setBool('$_kFreigeschaltetPrefix$pfad', true);
    return true;
  }

  /// Nur für den Debug-Bereich: setzt die ausgegebenen Sterne zurück und
  /// entfernt die über Sterne gekauften Profilbilder, damit der Kaufvorgang
  /// mehrfach durchgespielt werden kann.
  ///
  /// Nutzt dieselben Keys wie der echte Kauf — es gibt keine getrennte
  /// Test-Haltung. Über Werbung freigeschaltete Bilder bleiben unberührt.
  static Future<void> debugSterneKaeufeZuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAusgegeben);
    for (final pfad in sternePreise.keys) {
      await prefs.remove('$_kFreigeschaltetPrefix$pfad');
    }
  }
}
