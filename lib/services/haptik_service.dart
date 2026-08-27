import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:vibration/vibration.dart';

import 'einstellungen_service.dart';

/// Die Haptik der App — eine Stelle für alle Vibrationen.
///
/// ── Warum ein eigener Dienst ──────────────────────────────────────────────
///
/// Vorher rief jede Stelle das vibration-Paket direkt auf, mit eigener
/// Dauer und eigener Amplitude: 18 ms bei 35 an einer Skalenmarke, 150 ms bei
/// 220 beim Aufprall einer Münze. Sieben Dateien, jede mit ihrer eigenen
/// Vorab-Prüfung auf Schalter und Amplitudenfähigkeit. Das war nicht nur
/// doppelt geschrieben — es legte auch fest, WIE vibriert wird, statt WOFÜR.
///
/// Hier steht jetzt das Wofür ([HaptikArt]), und der Dienst entscheidet das
/// Wie je nach Plattform.
///
/// ── Android: echte Haptik-Primitive statt Brummen ─────────────────────────
///
/// Ab Android 12 (API 30) gibt es VibrationEffect.Composition mit
/// abgestimmten Primitiven (Tick, Click, Thud …). Sie fühlen sich deutlich
/// feiner an als ein Motor, der schlicht für n Millisekunden läuft. Genau das
/// nutzt das Paket haptic_feedback und ahmt damit die iOS-Muster nach.
///
/// SEIN RÜCKFALLWEG, absteigend:
///  * API 30 und neuer UND Primitive vom Motor unterstützt: Composition,
///  * sonst mit Amplitudensteuerung: Waveform mit Amplituden,
///  * sonst: einfache Dauer-Vibration mit den Zeiten des Pakets.
///
/// ── Warum die unterste Stufe NICHT genügt ─────────────────────────────────
///
/// Gemessen auf einem SM A136B (Android 12): der Motor meldet
/// mSupportedPrimitives=[PRIMITIVE_NOOP] und mCapabilities=[] — also weder
/// Primitive noch Amplitudensteuerung. Das Paket landet dort auf der
/// untersten Stufe und spielt seine iOS-Zeiten als nackte Dauer ab. Die sind
/// aber deutlich kürzer als das, was hier vorher lief:
///
///   Art      vorher     Paket-Rückfall
///   stark    180 ms  ->  55 ms
///   mittel    90 ms  ->  51 ms
///   auswahl   18 ms  ->  41 ms
///
/// Ohne Amplitudensteuerung läuft der Motor immer auf voller Stärke; die
/// einzige spürbare Größe ist die Dauer. Aus 180 ms werden 55 ms — der
/// Aufprall einer Münze fühlt sich damit schwächer an als vorher. Genau das
/// soll nicht passieren.
///
/// DESHALB entscheidet [initialisieren] zur Laufzeit, welcher Weg gilt, und
/// nimmt die Amplitudensteuerung als Anzeiger: Ein Motor ohne sie hat auch
/// keine Primitive (die setzen sie voraus), dort bleibt es beim alten Weg mit
/// den gewohnten Dauern. Ein Motor mit ihr bekommt das Paket — der landet
/// entweder auf den Primitiven (besser) oder auf der Waveform mit Amplituden
/// (mindestens gleichwertig). Schlechter als vorher wird es auf keinem Gerät.
///
/// WICHTIG, und der Grund, warum HIER kein Flutter-HapticFeedback steht:
/// Flutters HapticFeedback.* ruft auf Android View.performHapticFeedback()
/// auf. Das hängt an der System-Einstellung "Tipp-/Berührungs-Feedback" und
/// bleibt auf vielen Geräten (u.a. Samsung One UI) stumm, wenn sie aus ist —
/// trotz erteilter VIBRATE-Berechtigung. haptic_feedback spricht in seiner
/// Voreinstellung den Vibrator direkt an (VibratorManager) und umgeht das.
/// Der Schalter useAndroidHapticConstants würde genau in diese Falle führen
/// und bleibt deshalb aus.
///
/// ── iOS bleibt, wie es war ────────────────────────────────────────────────
///
/// Dort ist die Haptik von Haus aus gut, und die App klingt dort seit jeher
/// über das vibration-Paket. Der Zweig unten hält das unverändert — die
/// Umstellung betrifft ausschliesslich Android, und auch dort nur Geräte, die
/// tatsächlich etwas davon haben.
enum HaptikArt {
  /// Eine Rastung — der Griff überfährt eine Skalenmarke. Das Feinste, was
  /// es gibt: spürbar, aber kein Stoß.
  auswahl(HapticsType.selection, 18, 35),

  /// Ein leichter Stoß. Anfang einer ansteigenden Kette.
  leicht(HapticsType.light, 40, 60),

  /// Der Normalfall: eine Auswahl wurde übernommen.
  mittel(HapticsType.medium, 90, 130),

  /// Der Höhepunkt — Aufprall einer Münze, Ende einer Feier.
  stark(HapticsType.heavy, 180, 255),

  /// Richtige Antwort.
  erfolg(HapticsType.success, 40, 90),

  /// Reserviert für Warnungen; derzeit ungenutzt, aber Teil des Satzes,
  /// damit die Zuordnung vollständig bleibt.
  warnung(HapticsType.warning, 60, 120),

  /// Falsche Antwort oder abgelaufene Zeit.
  fehler(HapticsType.error, 70, 160);

  const HaptikArt(this.typ, this.dauerMs, this.staerke);

  /// Die Entsprechung im haptic_feedback-Paket (Android).
  final HapticsType typ;

  /// Dauer und Amplitude für den iOS-Weg über das vibration-Paket. Die Werte
  /// stammen aus den Aufrufstellen, die es vor der Umstellung gab — dort
  /// ändert sich dadurch nichts.
  final int dauerMs;
  final int staerke;
}

/// Ein Schritt einer haptischen Folge: [abMs] nach dem Start, in [art].
class HaptikSchritt {
  final int abMs;
  final HaptikArt art;

  const HaptikSchritt(this.abMs, this.art);
}

/// Eine laufende Folge. Wird sie nicht mehr gebraucht (Screen verlassen),
/// muss sie abgebrochen werden — sonst schlagen die Impulse noch los, wenn
/// längst etwas anderes auf dem Schirm steht.
class HaptikFolge {
  final List<Timer> _timer;

  HaptikFolge._(this._timer);

  void abbrechen() {
    for (final t in _timer) {
      t.cancel();
    }
    _timer.clear();
  }
}

class HaptikService {
  /// Zwischengespeicherter Schalterstand.
  ///
  /// [EinstellungenService.vibrationAktiv] liest SharedPreferences, und das
  /// ist asynchron. Zwischen Auslöser und Stoß darf aber kein await liegen,
  /// sonst kommt die Haptik hörbar zu spät — dasselbe Vorgehen wie beim
  /// SoundService.
  static bool _an = false;

  static bool _hatVibrator = false;
  static bool _bereit = false;

  /// Läuft die Haptik über haptic_feedback? Erst nach [initialisieren]
  /// aussagekräftig — die Entscheidung fällt anhand des Motors, siehe oben.
  static bool _ueberPaket = false;

  /// Einmalig beim App-Start aufzurufen — vor dem ersten möglichen Stoß.
  static Future<void> initialisieren() async {
    if (_bereit) return;
    _bereit = true;
    _an = await EinstellungenService.vibrationAktiv;
    var amplitude = false;
    try {
      _hatVibrator = await Vibration.hasVibrator();
      amplitude = _hatVibrator && await Vibration.hasAmplitudeControl();
      _ueberPaket = !kIsWeb &&
          Platform.isAndroid &&
          amplitude &&
          await Haptics.canVibrate();
    } catch (e) {
      _hatVibrator = false;
      _ueberPaket = false;
      debugPrint('[Haptik] Prüfung fehlgeschlagen: $e');
    }
    debugPrint('[Haptik] bereit — Weg: '
        '${_ueberPaket ? 'haptic_feedback (Primitive/Waveform)' : 'vibration-Paket (Dauer)'}'
        ', Vibrator: $_hatVibrator, Amplitude: $amplitude, Schalter: $_an');
  }

  /// Übernimmt den Schalter aus den Einstellungen.
  static void setzeAktiv(bool aktiv) => _an = aktiv;

  /// Ein einzelner Stoß.
  ///
  /// Bewusst NICHT awaited aufzurufen: Die Haptik ist Beiwerk und soll den
  /// Ablauf auf dem Schirm nicht aufhalten. Fehler werden verschluckt — ein
  /// stummer Stoß ist besser als eine Ausnahme mitten im Spiel.
  static void spiele(HaptikArt art) {
    if (!_an || !_hatVibrator) return;
    if (_ueberPaket) {
      Haptics.vibrate(art.typ).catchError((Object e) {
        debugPrint('[Haptik] ${art.name} nicht abspielbar: $e');
      });
      return;
    }
    Vibration.vibrate(duration: art.dauerMs, amplitude: art.staerke);
  }

  /// Eine Folge von Stössen zu festen Zeitpunkten.
  ///
  /// Ersetzt die früheren Vibration.vibrate(pattern:)-Aufrufe. Der Unterschied
  /// steckt in der Zuständigkeit: Ein Muster übergab dem System eine Liste von
  /// Pausen und Dauern und lief dort ab; hier plant der Dienst je Schritt
  /// einen Timer und löst einen benannten Stoss aus. Nur so kommen die
  /// Primitive überhaupt zum Zug — eine Composition kennt keine
  /// Millisekunden-Dauern.
  ///
  /// Der Aufrufer hält die Rückgabe fest und bricht sie in dispose() ab.
  static HaptikFolge folge(List<HaptikSchritt> schritte) {
    final timer = <Timer>[];
    if (!_an || !_hatVibrator) return HaptikFolge._(timer);
    for (final s in schritte) {
      timer.add(Timer(Duration(milliseconds: s.abMs), () => spiele(s.art)));
    }
    return HaptikFolge._(timer);
  }
}
