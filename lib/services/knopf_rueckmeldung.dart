import 'haptik_service.dart';
import 'sound_service.dart';

/// Die Rückmeldung auf einen Knopfdruck: ein feiner haptischer Klick — und
/// wenn der nicht ankommt, der Knopfton.
///
/// ── Warum die beiden sich abwechseln statt zusammenzuklingen ──────────────
///
/// Ein Knopf soll EINE Antwort geben, nicht zwei. Der Klick ist die bessere:
/// Er kommt am Finger an, wo der Druck stattfand, er stört niemanden im Raum,
/// und er funktioniert auch bei stummgeschaltetem Gerät — auf iOS schweigen
/// unsere Klänge beim Stummschalter (Kategorie ambient), der Knopf wäre dort
/// sonst ohne jede Antwort.
///
/// ── Warum es den Rückfall überhaupt braucht ───────────────────────────────
///
/// Ohne ihn verlöre der Knopf jede Rückmeldung, sobald die Vibration aus ist
/// oder das Gerät gar keinen Motor hat — der Ton war ja vorher das Einzige,
/// und er wäre ersatzlos verschwunden. [HaptikService.kannVibrieren] kennt
/// beide Fälle: den Schalter aus den Einstellungen und die Frage, ob der
/// Motor überhaupt existiert (beim Start einmal ermittelt).
///
/// Der Ton hängt weiterhin am Ton-Schalter, die Vibration am
/// Vibrations-Schalter. Wer beides abstellt, bekommt bewusst nichts.
///
/// ── Warum an EINER Stelle ─────────────────────────────────────────────────
///
/// Der Knopfton stand an dreizehn Stellen verstreut. Die Entscheidung
/// "Klick oder Ton" hier zu treffen heisst: Sie lässt sich an einer Stelle
/// ändern, und keine Stelle kann sie beim nächsten Umbau vergessen.
/// ── Warum [HaptikArt.leicht] und nicht die feinste Stufe ──────────────────
///
/// Zuerst stand hier [HaptikArt.auswahl] — die Stufe, mit der auch der Regler
/// rastet. Auf Geräten ohne Haptik-Hardware ist das nur ein 18-ms-Motorlauf,
/// und der ging als Knopf-Rückmeldung unter. Eine Stufe höher sind es 40 ms
/// bzw. auf Geräten mit Primitiven ein kräftigeres Tick.
void knopfRueckmeldung() {
  if (HaptikService.kannVibrieren) {
    HaptikService.spiele(HaptikArt.leicht);
  } else {
    SoundService.spiele(Klang.knopf);
  }
}
