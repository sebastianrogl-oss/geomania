import 'package:shared_preferences/shared_preferences.dart';

import 'abzeichen_service.dart';

/// Verleiht das Urgestein-Abzeichen an alle, die schon vor diesem Update
/// gespielt haben.
///
/// ══ WORAN MAN EINEN BESTANDSSPIELER ERKENNT ═════════════════════════════
///
/// An zwei Dingen ZUSAMMEN, und beide sind nötig:
///
///   1. [_kGeprueft] fehlt — dieser Schlüssel wird erst von dieser Version
///      geschrieben. Fehlt er, ist dies der ALLERERSTE Start nach der
///      Installation bzw. dem Update.
///   2. Es liegt bereits Spielfortschritt vor.
///
/// ── Warum kein Neuling es bekommt ───────────────────────────────────────
///
/// Eine frische Installation startet mit leeren Einstellungen. Beim ersten
/// Start greift zwar Bedingung 1, aber Bedingung 2 nicht — es gibt noch
/// keinen Fortschritt. Der Schlüssel wird dabei GESETZT, und zwar unabhängig
/// vom Ausgang. Spielt derselbe Nutzer danach seine erste Station, ist die
/// Prüfung längst gelaufen und wiederholt sich nie.
///
/// Entscheidend ist der Zeitpunkt: Die Prüfung läuft in `main()` VOR
/// `runApp()`. Zu diesem Moment kann auf einer frischen Installation
/// unmöglich Fortschritt vorliegen — es gab noch keine Oberfläche, auf der
/// man hätte spielen können.
///
/// ── Warum kein Bestandsspieler leer ausgeht ─────────────────────────────
///
/// Die alte Version kannte [_kGeprueft] nicht und hat ihn nie geschrieben.
/// Nach dem Update fehlt er also zwangsläufig, während der Fortschritt in
/// denselben SharedPreferences unverändert liegt — ein Update ersetzt das
/// Programm, nicht die Daten.
///
/// Geprüft wird dabei auf JEDE Art zu spielen (siehe [_hatFortschritt]),
/// nicht nur auf den Lernpfad: Wer bisher ausschliesslich Tages-Challenges
/// gespielt hat, ist genauso ein Bestandsspieler.
///
/// ── Die eine Lücke, und warum sie hinnehmbar ist ────────────────────────
///
/// Wer die alte Version installiert, aber NIE etwas gespielt hat, bekommt
/// das Abzeichen nicht. Von einer frischen Installation ist dieser Fall
/// nicht zu unterscheiden — in den Einstellungen steht in beiden Fällen
/// nichts. Und "war von Anfang an dabei" trifft auf jemanden, der nie
/// gespielt hat, ohnehin kaum zu.
class UrgesteinService {
  /// Wird bei JEDEM Ausgang der Prüfung gesetzt — auch wenn nichts verliehen
  /// wurde. Er bedeutet nicht "hat das Abzeichen", sondern "die Frage ist
  /// beantwortet".
  static const _kGeprueft = 'urgestein_geprueft';

  /// Das Abzeichen wurde verliehen, das Popup steht aber noch aus.
  ///
  /// Als eigener Schlüssel und nicht als Variable im Speicher: Zwischen
  /// Verleihung und Popup liegen bei einem Bestandsspieler mehrere Screens
  /// — Anmeldung, Namenswahl, Willkommen. Wer die App dazwischen schliesst,
  /// hätte das Abzeichen sonst still im Album, ohne je erfahren zu haben,
  /// wofür.
  static const _kPopupOffen = 'urgestein_popup_offen';

  /// Einmalige Prüfung beim Programmstart. Muss VOR `runApp()` laufen.
  static Future<void> pruefeBeimStart() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kGeprueft) ?? false) return;

    final alt = _hatFortschritt(prefs);
    // ZUERST merken, dass geprüft wurde — und zwar in beiden Fällen. Sonst
    // liefe die Prüfung beim nächsten Start erneut, und ein inzwischen
    // spielender Neuling erschiene dann als Bestandsspieler.
    await prefs.setBool(_kGeprueft, true);
    if (!alt) return;

    // Idempotent: Ein zweiter Aufruf verleiht nichts doppelt. Das Popup
    // steht nur an, wenn das Abzeichen wirklich neu war.
    if (await AbzeichenService.verleihen('urgestein')) {
      await prefs.setBool(_kPopupOffen, true);
    }
  }

  /// Liegt ein Abzeichen vor, das noch gezeigt werden muss?
  static Future<bool> popupOffen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPopupOffen) ?? false;
  }

  /// Nach dem Zeigen aufzurufen.
  static Future<void> popupErledigt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPopupOffen);
  }

  /// Hat auf diesem Gerät schon jemand gespielt?
  ///
  /// Bewusst NICHT `onboarding_willkommen` oder ähnliche Schlüssel: Die
  /// setzt auch ein Neuling, der bloss durch den Einstieg getippt hat.
  /// Gezählt wird nur, was ein Spiel voraussetzt.
  static bool _hatFortschritt(SharedPreferences prefs) {
    // Sterne im Lernpfad — der häufigste Fall.
    if ((prefs.getInt('lp_gesamt_richtig') ?? 0) > 0) return true;

    for (final schluessel in prefs.getKeys()) {
      // Eine abgeschlossene Station.
      if (schluessel.startsWith('lp_s_done_') &&
          (prefs.getBool(schluessel) ?? false)) {
        return true;
      }
      // Eine gespielte Tages-Challenge. Wer nur die gespielt hat, ist
      // genauso ein Bestandsspieler.
      if (schluessel.startsWith('anzahlGespielt_') &&
          (prefs.getInt(schluessel) ?? 0) > 0) {
        return true;
      }
    }
    return false;
  }

  /// Nur für Tests und den Debug-Bereich: macht die Prüfung wieder möglich.
  static Future<void> debugZuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kGeprueft);
    await prefs.remove(_kPopupOffen);
  }
}
