import 'package:shared_preferences/shared_preferences.dart';

import 'abzeichen_service.dart';
import 'spielstand_speicher.dart';

/// Einmaliger Neustart des Spielstands beim Update auf 1.1.0.
///
/// ══ WARUM ══════════════════════════════════════════════════════════════
///
/// Punktesystem und Lernpfad haben sich so geändert, dass alte Stände nicht
/// mehr vergleichbar sind — die früheren Challenge-Rekorde sind mit dem
/// neuen System nie wieder erreichbar. Ein Rekord, den man nicht mehr
/// schlagen kann, ist kein Ziel mehr, sondern eine Mauer.
///
/// ══ DIE REIHENFOLGE IST DER GANZE TRICK ═════════════════════════════════
///
/// Der [UrgesteinService] erkennt Bestandsspieler AM ALTEN FORTSCHRITT. Ein
/// Reset davor würde jeden leer ausgehen lassen — die App sähe lauter
/// frische Installationen. In `main()` steht deshalb:
///
///   1. UrgesteinService.pruefeBeimStart()   — verleiht das Abzeichen
///   2. UpdateNeustartService.pruefeBeimStart() — räumt danach ab
///
/// Beide tragen ihren EIGENEN Merker und laufen deshalb je genau einmal,
/// unabhängig voneinander. Wer die Reihenfolge in main() vertauscht, nimmt
/// allen Bestandsspielern die Ehrung; ein Test hält die Kette fest.
///
/// ══ WAS ERHALTEN BLEIBT ═════════════════════════════════════════════════
///
/// Das Urgestein-Abzeichen. Es wäre absurd, es eine Zeile vorher zu
/// verleihen und hier wieder einzukassieren.
///
/// Gelöscht wird über [SpielstandSpeicher.loescheSyncSchluessel] — denselben
/// Weg, den auch die Cloud-Sicherung kennt. Er trifft genau das, was den
/// Spielstand ausmacht, und lässt aus, was zum Gerät gehört: Ton,
/// Vibration, Sprache, Erinnerungs-Einstellungen. Und er lässt die beiden
/// Urgestein-Merker stehen, weil die als Geräte-Werte eingeordnet sind —
/// sonst liefe die Urgestein-Prüfung beim nächsten Start erneut.
///
/// ══ UND DIE CLOUD? ══════════════════════════════════════════════════════
///
/// Der Neustart räumt nur lokal auf. Das genügt hier, denn bis 1.1.0 gab es
/// keine Cloud-Sicherung: Die alte Version meldete jeden anonym an, und
/// anonyme Konten synchronisieren nicht (siehe SpielstandSync.aktiv). Es
/// gibt also keinen Cloud-Stand, der zurückkommen könnte.
///
/// SOLLTE DAS JE ANDERS SEIN, ist hier die Falle: Die Zusammenführung kennt
/// nur Wachstum. Ein lokal geleerter Stand plus ein voller Cloud-Stand ergibt
/// beim nächsten Anmelden wieder den vollen — der Neustart wäre wirkungslos.
/// Dann müsste zusätzlich das Cloud-Dokument weg, so wie es
/// "Fortschritt zurücksetzen" in den Einstellungen macht.
class UpdateNeustartService {
  /// Trägt die Version im Namen: Ein späterer Neustart bei 1.2.0 bekäme
  /// einen eigenen Schlüssel und liefe dadurch von selbst noch einmal,
  /// ohne dass jemand einen bestehenden Merker löschen müsste.
  static const _kErledigt = 'neustart_110_erledigt';

  /// Einmaliger Neustart. Muss NACH [UrgesteinService.pruefeBeimStart]
  /// laufen — siehe Klassenkommentar.
  static Future<void> pruefeBeimStart() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kErledigt) ?? false) return;

    // Vor dem Abräumen merken, ob das Urgestein da ist. Es liegt in
    // 'abzeichen_freigeschaltet' und wird gleich mit gelöscht.
    final hatUrgestein =
        (await AbzeichenService.getFreigeschaltete()).contains('urgestein');

    await SpielstandSpeicher.loescheSyncSchluessel();

    if (hatUrgestein) await AbzeichenService.verleihen('urgestein');

    // ZULETZT. Bricht etwas dazwischen ab, läuft der Neustart beim nächsten
    // Start noch einmal — auf einem schon geleerten Stand ist das folgenlos,
    // und das Urgestein wird dann erneut zurückgegeben.
    await prefs.setBool(_kErledigt, true);
  }

  /// Nur für Tests und den Debug-Bereich.
  static Future<void> debugZuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kErledigt);
  }
}
