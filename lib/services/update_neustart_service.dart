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

  /// Der Cloud-Stand muss noch weg.
  ///
  /// ══ WARUM DAS NICHT SOFORT GEHT ═══════════════════════════════════════
  ///
  /// Der Neustart läuft in `main()` vor `runApp()` — also bevor die
  /// Anmeldung steht. Ohne uid gibt es kein Cloud-Dokument, das man löschen
  /// könnte. Ein Versuch an dieser Stelle liefe ins Leere, und der Merker
  /// stünde danach trotzdem auf erledigt.
  ///
  /// Deshalb hinterlässt der Neustart hier eine Notiz, und der erste
  /// Anmelde-Abgleich arbeitet sie ab: Er LÖSCHT das Dokument, statt es
  /// zusammenzuführen (siehe [SpielstandSync.beimAnmelden]).
  ///
  /// ══ WARUM ER NUR BEI ECHTEM ALTSTAND GESETZT WIRD ═════════════════════
  ///
  /// Weil er sonst Daten vernichtet, die niemand vernichten wollte: Wer die
  /// App frisch auf einem NEUEN Gerät installiert, hat lokal nichts — der
  /// Neustart findet nichts vor und räumt nichts weg. Stünde die Notiz
  /// trotzdem, würde beim ersten Anmelden die Cloud-Sicherung gelöscht, mit
  /// der dieser Spieler gerade seinen Fortschritt vom alten Gerät holen
  /// wollte. Aus einer Absicherung würde der schlimmste Datenverlust, den
  /// diese App kennt.
  static const _kCloudOffen = 'neustart_110_cloud_offen';

  /// Einmaliger Neustart. Muss NACH [UrgesteinService.pruefeBeimStart]
  /// laufen — siehe Klassenkommentar.
  static Future<void> pruefeBeimStart() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kErledigt) ?? false) return;

    // Vor dem Abräumen merken, ob das Urgestein da ist. Es liegt in
    // 'abzeichen_freigeschaltet' und wird gleich mit gelöscht.
    final hatUrgestein =
        (await AbzeichenService.getFreigeschaltete()).contains('urgestein');

    // Lag hier überhaupt ein Stand? Ausser 'version' steht in einem frisch
    // installierten Gerät nichts. Nur wenn wirklich etwas weggeräumt wird,
    // darf die Cloud-Notiz gesetzt werden — die Begründung bei [_kCloudOffen].
    final vorher = await SpielstandSpeicher.lesen();
    final hatteStand = vorher.keys.any((k) => k != 'version');

    await SpielstandSpeicher.loescheSyncSchluessel();

    if (hatUrgestein) await AbzeichenService.verleihen('urgestein');
    if (hatteStand) await prefs.setBool(_kCloudOffen, true);

    // ZULETZT. Bricht etwas dazwischen ab, läuft der Neustart beim nächsten
    // Start noch einmal — auf einem schon geleerten Stand ist das folgenlos,
    // und das Urgestein wird dann erneut zurückgegeben.
    await prefs.setBool(_kErledigt, true);
  }

  /// Steht die Cloud-Notiz noch offen?
  ///
  /// Gefragt wird vom Anmelde-Abgleich, bevor er zusammenführt.
  static Future<bool> cloudLoeschenOffen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kCloudOffen) ?? false;
  }

  /// Das Cloud-Dokument ist weg — Notiz abhaken.
  ///
  /// Erst NACH der erfolgreichen Löschung aufzurufen. Schlägt sie fehl (kein
  /// Netz), bleibt die Notiz stehen und der nächste Anmelde-Abgleich holt es
  /// nach. Andersherum wäre der Altstand für immer in der Cloud.
  static Future<void> cloudGeloescht() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCloudOffen);
  }

  /// Nur für Tests und den Debug-Bereich.
  static Future<void> debugZuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kErledigt);
    await prefs.remove(_kCloudOffen);
  }
}
