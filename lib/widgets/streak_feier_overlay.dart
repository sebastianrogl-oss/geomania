import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import 'package:vibration/vibration.dart';
import '../l10n/uebersetzungen.dart';
import '../services/einstellungen_service.dart';
import '../services/fortschritt_service.dart';

/// Erhöht den Tages-Streak und zeigt die Feier, falls er dabei gestiegen ist.
///
/// Das ist der EINZIGE Einstiegspunkt für die Streak-Feier: sowohl der echte
/// Level-Abschluss (station_quiz_screen.dart `_stationFertig`) als auch der
/// Debug-Button in den Einstellungen rufen ausschließlich diese Funktion auf.
/// Es gibt bewusst keine zweite, parallele Variante für Testzwecke — Änderungen
/// am Ablauf oder am Design wirken sich dadurch automatisch auf beide Wege aus.
///
/// Gibt `(vorher, nachher)` zurück, damit Aufrufer protokollieren können, was
/// passiert ist.
Future<(int, int)> streakErhoehenUndFeiern(BuildContext context) async {
  final (alterStreak, neuerStreak) =
      await FortschrittService.streakAktualisieren();
  // Die Feier erscheint nur, wenn der Streak tatsächlich gestiegen ist — also
  // beim ersten abgeschlossenen Level eines neuen Tages. Blockiert, bis der
  // Nutzer sie weggetippt hat.
  if (neuerStreak > alterStreak && context.mounted) {
    await StreakFeierOverlay.zeigen(
      context,
      alterStreak: alterStreak,
      neuerStreak: neuerStreak,
    );
  }
  return (alterStreak, neuerStreak);
}

// ── Streak-Feier ──────────────────────────────────────────────────────────────
//
// Vollbild-Moment beim Steigen des Tages-Streaks, im Geist von Duolingos
// Streak-Screen: eine große, ruhige, zentrierte Bühne — oben die dominante
// Flamme, dicht darunter die Streak-Zahl, sonst nichts. Der Moment bleibt
// stehen, bis der Nutzer irgendwo tippt (bewusst kein Auto-Dismiss).
//
// Der Tages-Streak erhöht sich nur beim ERSTEN abgeschlossenen Level eines
// Tages (FortschrittService.streakAktualisieren kehrt bei diff == 0 sofort
// zurück) — dieses Overlay erscheint also höchstens einmal pro Tag.
class StreakFeierOverlay extends StatefulWidget {
  final int alterStreak;
  final int neuerStreak;

  const StreakFeierOverlay({
    super.key,
    required this.alterStreak,
    required this.neuerStreak,
  });

  /// Zeigt die Feier als undurchsichtige Route über dem aktuellen Screen und
  /// kehrt zurück, sobald der Nutzer sie weggetippt hat.
  static Future<void> zeigen(
    BuildContext context, {
    required int alterStreak,
    required int neuerStreak,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        // Das Overlay bringt seine eigenen Ein-/Ausblendungen mit, deshalb
        // hier keine zusätzliche Routen-Transition.
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            StreakFeierOverlay(
              alterStreak: alterStreak,
              neuerStreak: neuerStreak,
            ),
      ),
    );
  }

  @override
  State<StreakFeierOverlay> createState() => _StreakFeierOverlayState();
}

// ── Timing (alle Werte an einer Stelle) ──────────────────────────────────────
//
// Bewusst langsam gehalten: der Moment soll Gewicht haben statt zu hetzen.
const _kEinblenden = Duration(milliseconds: 400);
const _kAusblenden = Duration(milliseconds: 300);
// Ruhephase, in der die Flamme einfach lodert, bevor etwas passiert. Zusammen
// mit _kEinblenden ergibt das die geforderten ~1200ms bis zum Ausholen.
const _kRuhePhase = Duration(milliseconds: 800);
// Die Zahl poppt kurz nach der Flamme, damit beide zusammen "atmen".
const _kZahlPopVersatz = Duration(milliseconds: 150);
// Fall B: Tempokurve der Lottie-Loop (hoch, halten, weich zurück).
const _kTempoKurve = Duration(milliseconds: 1400);
const _kZahlWechsel = Duration(milliseconds: 900);
const _kHinweisEin = Duration(milliseconds: 400);

// ── Fall A: eine durchgehende Skalierungskurve ───────────────────────────────
//
// Ausholen und Wachsen sind EINE Sequenz auf EINEM Controller, die den
// gesamten Flammen-Stack skaliert — nicht zwei getrennte Animationen. Nur so
// ist der Übergang von grau nach rot nahtlos: es gibt keinen Punkt, an dem
// zwei Skalierungen aufeinandertreffen könnten.
//
//   Gewicht  Verlauf        Kurve           Zeit (von 1750ms)
//   40       1.00 -> 1.15   easeOut           0 -  400ms   ausholen
//   35       1.15 -> 0.92   easeInOut       400 -  750ms   zusammenziehen
//   45       0.92 -> 1.28   easeOutCubic    750 - 1200ms   aufpoppen
//   55       1.28 -> 1.00   easeOutBack    1200 - 1750ms   zurückfedern
//
// Die Gesamtdauer ist so gewählt, dass der tiefste Punkt (0.92) exakt bei
// 750ms liegt — dort beginnt der Farbwechsel und dort sitzt der kräftige
// Vibrations-Höhepunkt aus der Impulskette.
const _kPopNeustart = Duration(milliseconds: 1750);
const _kGewichtAusholen = 40.0;
const _kGewichtZusammen = 35.0;
const _kGewichtAufpopp = 45.0;
const _kGewichtZurueck = 55.0;
const _kGewichtGesamt =
    _kGewichtAusholen + _kGewichtZusammen + _kGewichtAufpopp + _kGewichtZurueck;
// Tiefster Punkt (0.92): Start des Farbwechsels.
const _kTiefpunkt =
    (_kGewichtAusholen + _kGewichtZusammen) / _kGewichtGesamt; // 0.4286
// Höhepunkt (1.28): größte Skalierung.
const _kHoehepunkt =
    (_kGewichtAusholen + _kGewichtZusammen + _kGewichtAufpopp) /
        _kGewichtGesamt; // 0.6857
// Farbwechsel: 500ms ab dem tiefsten Punkt (500/1750 der Gesamtsequenz).
const _kFarbwechselEnde = _kTiefpunkt + 500 / 1750; // 0.7143
// Der Zahlenwechsel setzt kurz nach dem Höhepunkt ein.
const _kZahlNachHoehepunkt = Duration(milliseconds: 150);

// ── Fall A: ansteigendes Vibrationsmuster ────────────────────────────────────
//
// Echtes Muster über das vibration-Paket statt einer Kette einzelner
// HapticFeedback-Impulse: fünf immer längere Stöße in immer kürzeren Abständen,
// abgeschlossen vom kräftigen Höhepunkt.
//
// Das Muster wechselt Pause und Vibration ab:
//   [Pause, Stoß, Pause, Stoß, …]
//
//   Pause  Stoß   Stoß beginnt bei   Amplitude
//     0     40           0ms             60
//   146     45         186ms             85
//   119     55         350ms            115
//    93     65         498ms            150
//    66     75         629ms            190
//    46    200         750ms            255   <- Höhepunkt
//
// Die Pausen sind gegenüber der ursprünglichen Vorlage gestaucht (220/180/140/
// 100/70 -> 146/119/93/66/46, Faktor 0.662), damit der kräftige Stoß exakt bei
// 750ms einsetzt: das ist der Moment, in dem die Animation ihren tiefsten Punkt
// (0.92) erreicht und der Farbwechsel beginnt (siehe _kTiefpunkt). Die
// Abstufung — kürzer werdende Abstände, länger und stärker werdende Stöße —
// bleibt dabei erhalten.
const _kVibrationsMuster = [0, 40, 146, 45, 119, 55, 93, 65, 66, 75, 46, 200];
const _kVibrationsStaerken = [0, 60, 0, 85, 0, 115, 0, 150, 0, 190, 0, 255];
// Zur Kontrolle: Summe aller Werte vor dem letzten Stoß.
const _kVibrationHoehepunktMs = 750;

// ── Fall B: ein einzelner kräftiger Stoß ─────────────────────────────────────
const _kImpulsDauerMs = 180;
const _kImpulsStaerke = 255;

// ── Fall B ───────────────────────────────────────────────────────────────────
const _kPopWachstum = Duration(milliseconds: 800);
// Fortschritt der Fall-B-Sequenz mit der größten Skalierung (1.30), dort löst
// die Vibration aus: (20+40) / (20+40+40) = 0.60.
const _kPopHoehepunktWachstum = 0.60;

// ── Größe der Zahl ───────────────────────────────────────────────────────────
// Proportional zur Flamme gewählt (siehe flammenHoehe in build): beide wurden
// gemeinsam verkleinert, damit das Verhältnis stimmig bleibt.
const _kZahlGroesse = 78.0;
// Ausschnitt, durch den die beiden Zahlen fahren — muss mit der Schriftgröße
// mitwachsen, sonst werden die Zahlen oben/unten beschnitten (Verhältnis wie
// bisher: 1.2x der Schriftgröße).
const _kZahlHoehe = 94.0;
// Abstand Flamme -> Zahl.
const _kAbstandFlammeZahl = 69.0;
// Seitlicher Versatz der Zahl (positiv = nach rechts). Als Transform statt
// Padding, damit sich nur die Darstellung verschiebt und das Layout der
// zentrierten Spalte unberührt bleibt.
const _kZahlVersatzRechts = 5.0;

class _StreakFeierOverlayState extends State<StreakFeierOverlay>
    with TickerProviderStateMixin {
  // Blendet die gesamte Feier ein und beim Wegtippen wieder aus.
  late final AnimationController _einblendCtrl;
  // Treibt den Zahlenwechsel: alte Zahl raus, neue Zahl rein.
  late final AnimationController _zahlCtrl;
  // Der dezente Hinweis ganz unten, erscheint zuletzt.
  late final AnimationController _hinweisCtrl;

  // ── Flammen (Lottie) ────────────────────────────────────────────────────
  // Die graue Flamme läuft als schlichte Dauerschleife über ihren eigenen
  // Controller. Die rote wird dagegen von einem Ticker von Hand
  // weitergeschoben (siehe _tick), weil ihr Abspieltempo sich stufenlos
  // ändern soll: würde man dafür die Controller-Dauer umstellen und repeat()
  // neu aufrufen, spränge die Schleife jedes Mal an ihren Anfang zurück.
  late final AnimationController _roteLottieCtrl;
  late final AnimationController _graueLottieCtrl;
  late final Ticker _roteTicker;
  Duration? _roteGrunddauer;
  Duration? _letzterTick;
  double _tempo = 1.0;

  // Fall B: fährt _tempo auf 1.5x hoch, hält, und führt es weich zurück.
  late final AnimationController _tempoCtrl;
  late final Animation<double> _tempoVerlauf;

  // Überblendung grau -> rot. In Fall A ein Interval auf _popCtrl (damit
  // Farbwechsel und Skalierung nicht auseinanderlaufen können), in Fall B
  // konstant: dort ist die rote Flamme von Anfang an voll sichtbar.
  late final Animation<double> _roteOpacity;
  late final Animation<double> _graueOpacity;

  // Pop-Sequenzen: Flamme und (leicht versetzt) Zahl.
  late final AnimationController _popCtrl;
  late final AnimationController _zahlPopCtrl;
  late final Animation<double> _popScale;
  late final Animation<double> _zahlPopScale;

  late final Animation<Offset> _alteZahlPos;
  late final Animation<double> _alteZahlOpacity;
  late final Animation<Offset> _neueZahlPos;
  late final Animation<double> _neueZahlOpacity;

  bool _schliesst = false;
  // Fall B: sorgt dafür, dass die Vibration im Pop-Höhepunkt exakt einmal
  // auslöst und nicht bei jedem Frame danach erneut.
  bool _vibriert = false;
  // Nutzer-Einstellung, VORAB geladen (siehe _vibrationVorbereiten).
  bool _vibrationErlaubt = false;
  // Ob das Gerät die Amplitude steuern kann. Ohne diese Fähigkeit (u.a. iOS,
  // ältere Android-Geräte) läuft dasselbe Muster ohne Intensitäts-Abstufung.
  bool _hatAmplitude = false;

  /// Fall A ("Streak startet neu") vs. Fall B ("Streak wächst").
  ///
  /// Ausschlaggebend ist der NEUE Wert, nicht der alte: Fall A soll beim
  /// allerersten Spielen UND nach einem verpassten Tag greifen. Beim
  /// allerersten Spielen gilt zwar 0 → 1, nach einer Lücke von mehr als einem
  /// Tag setzt FortschrittService.streakAktualisieren den Streak aber auf 1
  /// ZURÜCK (`streak = diff == 1 ? streak + 1 : 1`) — der alte Wert ist dort
  /// z.B. 5, nicht 0. Eine Prüfung auf `alterStreak == 0` würde diesen
  /// zweiten Fall verfehlen. `neuerStreak == 1` deckt beide ab: ein Streak
  /// von 1 bedeutet immer "fängt gerade neu an".
  bool get _istNeustart => widget.neuerStreak == 1;

  Duration get _popDauer => _istNeustart ? _kPopNeustart : _kPopWachstum;

  // Fall A: ausholen (größer), zusammenziehen (kleiner), kräftig aufpoppen,
  // zurückfedern — eine durchgehende Kurve, siehe Tabelle bei _kPopNeustart.
  // Fall B: erst kurz zusammenziehen, dann kräftig aufpoppen und mit leichtem
  // Nachschwingen zurück.
  Animation<double> _popSequenz(AnimationController ctrl) {
    if (_istNeustart) {
      return TweenSequence<double>([
        TweenSequenceItem(
          weight: _kGewichtAusholen,
          tween: Tween(
            begin: 1.0,
            end: 1.15,
          ).chain(CurveTween(curve: Curves.easeOut)),
        ),
        TweenSequenceItem(
          weight: _kGewichtZusammen,
          tween: Tween(
            begin: 1.15,
            end: 0.92,
          ).chain(CurveTween(curve: Curves.easeInOut)),
        ),
        TweenSequenceItem(
          weight: _kGewichtAufpopp,
          tween: Tween(
            begin: 0.92,
            end: 1.28,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        TweenSequenceItem(
          weight: _kGewichtZurueck,
          tween: Tween(
            begin: 1.28,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
        ),
      ]).animate(ctrl);
    }
    return TweenSequence<double>([
      TweenSequenceItem(
        weight: 20,
        tween: Tween(
          begin: 1.0,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeIn)),
      ),
      TweenSequenceItem(
        weight: 40,
        tween: Tween(
          begin: 0.88,
          end: 1.30,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      TweenSequenceItem(
        weight: 40,
        tween: Tween(
          begin: 1.30,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
      ),
    ]).animate(ctrl);
  }

  @override
  void initState() {
    super.initState();

    _einblendCtrl = AnimationController(
      vsync: this,
      duration: _kEinblenden,
      reverseDuration: _kAusblenden,
    );
    _zahlCtrl = AnimationController(vsync: this, duration: _kZahlWechsel);
    _hinweisCtrl = AnimationController(vsync: this, duration: _kHinweisEin);
    _roteLottieCtrl = AnimationController(vsync: this);
    _graueLottieCtrl = AnimationController(vsync: this);
    _popCtrl = AnimationController(vsync: this, duration: _popDauer);
    _zahlPopCtrl = AnimationController(vsync: this, duration: _popDauer);
    _tempoCtrl = AnimationController(vsync: this, duration: _kTempoKurve);

    if (_istNeustart) {
      // Der Farbwechsel hängt am SELBEN Controller wie die Skalierung, als
      // Interval genau über die 500ms ab dem tiefsten Punkt. Ein eigener
      // Controller (oder ein Timer) könnte gegenüber der Skalierung driften —
      // so ist der Wechsel zwangsläufig framegenau auf 0.92 gesetzt.
      _roteOpacity = CurvedAnimation(
        parent: _popCtrl,
        curve: const Interval(
          _kTiefpunkt,
          _kFarbwechselEnde,
          curve: Curves.easeOut,
        ),
      );
      _graueOpacity =
          Tween<double>(begin: 1.0, end: 0.0).animate(_roteOpacity);
    } else {
      // Fall B kennt keine graue Flamme — die rote steht von Anfang an da.
      _roteOpacity = const AlwaysStoppedAnimation(1.0);
      _graueOpacity = const AlwaysStoppedAnimation(0.0);
    }

    _popScale = _popSequenz(_popCtrl);
    _zahlPopScale = _popSequenz(_zahlPopCtrl);

    // Nur Fall B vibriert über den Listener im Pop-Höhepunkt. Fall A nutzt
    // stattdessen die zeitgesteuerte Impulskette (_vibrationsketteStarten).
    if (!_istNeustart) {
      _popCtrl.addListener(_pruefePopHoehepunkt);
    }

    // Zahlen: beide Richtungen weich, damit der Wechsel gleitet statt zu
    // schnappen.
    _alteZahlPos = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.2),
    ).animate(CurvedAnimation(parent: _zahlCtrl, curve: Curves.easeInOutCubic));
    _alteZahlOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _zahlCtrl, curve: Curves.easeInOutCubic));
    _neueZahlPos = Tween<Offset>(
      begin: const Offset(0, 1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _zahlCtrl, curve: Curves.easeInOutCubic));
    _neueZahlOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _zahlCtrl, curve: Curves.easeInOutCubic));

    // Tempo: kurz hoch auf 1.5x, halten, dann weich zurück auf 1.0x.
    _tempoVerlauf = TweenSequence<double>([
      TweenSequenceItem(
        weight: 200,
        tween: Tween(
          begin: 1.0,
          end: 1.5,
        ).chain(CurveTween(curve: Curves.easeOut)),
      ),
      TweenSequenceItem(weight: 600, tween: ConstantTween(1.5)),
      TweenSequenceItem(
        weight: 600,
        tween: Tween(
          begin: 1.5,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      ),
    ]).animate(_tempoCtrl);
    _tempoCtrl.addListener(() => _tempo = _tempoVerlauf.value);

    _roteTicker = createTicker(_tick)..start();

    _vibrationVorbereiten();

    _ablaufStarten();
  }

  // Lädt Nutzer-Einstellung und Geräte-Fähigkeit vorab, damit beim Auslösen
  // kein await zwischen Animationsstart und Vibration liegt — sonst begänne
  // das Muster gegenüber der Animation verzögert. Die Ruhephase von 1200ms
  // reicht dafür weit aus; bis dahin wird nicht vibriert.
  //
  // Die Nutzer-Einstellung wird genauso abgefragt wie beim Abzeichen-Popup
  // (widgets/abzeichen_popup.dart), nur der Impulsgeber ist ein anderer.
  Future<void> _vibrationVorbereiten() async {
    final erlaubt = await EinstellungenService.vibrationAktiv;
    if (!erlaubt || !mounted) return;
    final amplitude = await Vibration.hasAmplitudeControl();
    if (!mounted) return;
    _vibrationErlaubt = true;
    _hatAmplitude = amplitude;
    if (kDebugMode) {
      debugPrint('[StreakFeier] Vibration bereit: '
          'hasAmplitudeControl=$amplitude');
    }
  }

  // Schiebt die rote Flammen-Loop mit dem aktuellen _tempo weiter und schlägt
  // am Ende sauber auf den Anfang um — so bleibt jeder Tempowechsel stufenlos.
  void _tick(Duration elapsed) {
    final grund = _roteGrunddauer;
    final vorher = _letzterTick;
    _letzterTick = elapsed;
    if (grund == null || vorher == null || grund.inMicroseconds == 0) return;
    final delta = (elapsed - vorher).inMicroseconds / grund.inMicroseconds;
    final neu = _roteLottieCtrl.value + delta * _tempo;
    _roteLottieCtrl.value = neu - neu.floorToDouble();
  }

  // Fall B: ein einzelner kräftiger Stoß im Höhepunkt der Pop-Sequenz (1.30).
  // Der Listener prüft den Zustand, statt bei jedem Frame zu feuern.
  void _pruefePopHoehepunkt() {
    if (_vibriert || _popCtrl.value < _kPopHoehepunktWachstum) return;
    _vibriert = true;
    if (!_vibrationErlaubt) return;
    if (kDebugMode) {
      debugPrint(
        '[StreakFeier] Vibration Fall B: einzelner Stoß ${_kImpulsDauerMs}ms '
        '(Amplitude ${_hatAmplitude ? _kImpulsStaerke : 'n/a'}) '
        'bei Fortschritt $_kPopHoehepunktWachstum',
      );
    }
    if (_hatAmplitude) {
      Vibration.vibrate(duration: _kImpulsDauerMs, amplitude: _kImpulsStaerke);
    } else {
      Vibration.vibrate(duration: _kImpulsDauerMs);
    }
  }

  // Fall A: ein einziges, ansteigendes Vibrationsmuster — es läuft nach dem
  // Start selbstständig durch und endet mit dem kräftigen Stoß, der zeitlich
  // auf den Farbwechsel fällt (siehe _kVibrationsMuster).
  //
  // Nutzer-Einstellung und Amplituden-Fähigkeit werden VORAB in initState
  // geladen, damit hier kein await zwischen Animationsstart und Vibration
  // liegt und beide zeitgleich beginnen.
  void _vibrationsketteStarten() {
    if (!_vibrationErlaubt) return;
    if (kDebugMode) {
      debugPrint(
        '[StreakFeier] Vibration Fall A: ansteigendes Muster, '
        'Amplitudensteuerung=$_hatAmplitude, '
        'Höhepunkt bei ${_kVibrationHoehepunktMs}ms',
      );
    }
    if (_hatAmplitude) {
      Vibration.vibrate(
        pattern: _kVibrationsMuster,
        intensities: _kVibrationsStaerken,
      );
    } else {
      // Geräte ohne Amplitudensteuerung (u.a. iOS): gleiches Timing, aber
      // ohne Intensitäts-Abstufung.
      Vibration.vibrate(pattern: _kVibrationsMuster);
    }
  }

  Future<void> _ablaufStarten() async {
    _einblendCtrl.forward();
    // Ruhephase: beide Fälle lassen ihre Flamme erst einmal ruhig lodern.
    await Future.delayed(_kEinblenden + _kRuhePhase);
    if (!mounted) return;

    // Eine Sequenz treibt in Fall A Ausholen, Farbwechsel und Aufpoppen
    // gemeinsam; in Fall B nur den Pop-Impuls.
    _popCtrl.forward(from: 0);

    if (_istNeustart) {
      _vibrationsketteStarten();
      // Der Zahlenwechsel setzt kurz nach dem Höhepunkt des Größer-Werdens
      // ein.
      await Future.delayed(
        Duration(
              milliseconds:
                  (_kHoehepunkt * _kPopNeustart.inMilliseconds).round(),
            ) +
            _kZahlNachHoehepunkt,
      );
      if (!mounted) return;
    } else {
      // Fall B: Auflodern und Zahlenwechsel sind EIN Ereignis und starten
      // gemeinsam.
      _tempoCtrl.forward(from: 0);
    }

    await _zahlWechselStarten();
    if (!mounted) return;
    _hinweisCtrl.forward();
  }

  Future<void> _zahlWechselStarten() {
    // Der Pop der Zahl setzt leicht versetzt ein, damit Flamme und Zahl
    // zusammen atmen statt im Gleichschritt zu springen.
    Future.delayed(_kZahlPopVersatz, () {
      if (mounted) _zahlPopCtrl.forward(from: 0);
    });
    return _zahlCtrl.forward(from: 0);
  }

  Future<void> _schliessen() async {
    if (_schliesst) return;
    _schliesst = true;
    await _einblendCtrl.reverse();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _roteTicker.dispose();
    // Ein noch laufendes Vibrationsmuster abbrechen, falls die Feier
    // vorzeitig weggetippt wurde — es liefe sonst im Hintergrund weiter.
    if (_vibrationErlaubt) Vibration.cancel();
    _popCtrl.removeListener(_pruefePopHoehepunkt);
    _einblendCtrl.dispose();
    _zahlCtrl.dispose();
    _hinweisCtrl.dispose();
    _roteLottieCtrl.dispose();
    _graueLottieCtrl.dispose();
    _popCtrl.dispose();
    _zahlPopCtrl.dispose();
    _tempoCtrl.dispose();
    super.dispose();
  }

  static const _zahlStil = TextStyle(
    fontSize: _kZahlGroesse,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    height: 1.0,
  );

  @override
  Widget build(BuildContext context) {
    final schirm = MediaQuery.of(context).size;
    // Deutlich kleiner als zuvor: die Flamme war auf dem Handy zu dominant.
    final flammenHoehe = (schirm.height * 0.42).clamp(345.0, 525.0);

    // Material umschließt den GESAMTEN Overlay-Inhalt (nicht einzelne Texte):
    // ohne einen Material-Vorfahren zeichnet Flutter unter jeden Text die
    // gelben Fehlstreifen. `transparency` liefert den Material-Kontext, ohne
    // eine eigene Fläche zu malen — die Abdunklung bleibt unser Container.
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        // opaque: der ganze Screen nimmt den Tap entgegen, nicht nur der
        // Inhalt.
        behavior: HitTestBehavior.opaque,
        onTap: _schliessen,
        child: FadeTransition(
          opacity: _einblendCtrl,
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
            child: Stack(
              // Die Flamme ragt bewusst über ihren Layout-Platz und die
              // Bildschirmränder hinaus — nicht wegschneiden.
              clipBehavior: Clip.none,
              children: [
                // Flamme und Zahl bilden zusammen die Bühne, mittig auf dem
                // Screen: Flamme oben, Zahl dicht darunter.
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _flamme(flammenHoehe, schirm.width),
                      const SizedBox(height: _kAbstandFlammeZahl),
                      Transform.translate(
                        offset: const Offset(_kZahlVersatzRechts, 0),
                        child: _zahlenWechsel(),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FadeTransition(
                    opacity: _hinweisCtrl,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      // Formulierung, Größe und Deckkraft identisch zum
                      // Abzeichen-Popup (widgets/abzeichen_popup.dart), damit
                      // sich beide Overlays gleich anfühlen.
                      child: Text(
                        t('Tippen für weiter'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _meldeGeladen(String datei, LottieComposition k) {
    if (!kDebugMode) return;
    debugPrint(
      '[StreakFeier] Lottie geladen: $datei — '
      '${k.duration.inMilliseconds}ms, ${k.startFrame.toInt()}-'
      '${k.endFrame.toInt()} @ ${k.frameRate.toInt()}fps',
    );
  }

  // Fällt eine der Dateien aus (fehlendes Asset, kaputtes JSON), bleibt der
  // Rest der Feier funktionsfähig: die Fläche bleibt einfach leer, statt die
  // gesamte Route mit einem roten Fehler-Widget zu ersetzen.
  Widget _ladeFehler(String datei, Object fehler) {
    if (kDebugMode) {
      debugPrint('[StreakFeier] Lottie FEHLER bei $datei: $fehler');
    }
    return const SizedBox.shrink();
  }

  // Die beiden Lottie-Flammen liegen deckungsgleich übereinander. In Fall A
  // blendet _ueberblendCtrl von grau auf rot über, in Fall B steht er von
  // Beginn an auf 1.0 und die graue Flamme wird gar nicht erst gebaut.
  Widget _flamme(double hoehe, double schirmBreite) {
    // Seitenverhältnis der Kompositionen: 300x250.
    final breite = hoehe * 300 / 250;

    // Die Komposition umschließt die eigentliche Flamme mit reichlich
    // Leerraum. Würde sie ihren vollen Rahmen im Layout beanspruchen, bliebe
    // für die Zahl kein Platz und die Flamme müsste kleingerechnet werden.
    // Stattdessen belegt sie nur einen Teil davon und darf über diesen
    // Ausschnitt hinausragen (OverflowBox) — so wird die Flamme selbst
    // wirklich groß, ohne das übrige Layout zu sprengen.
    final layoutHoehe = hoehe * 0.6;
    final layoutBreite = breite * 0.6 > schirmBreite
        ? schirmBreite
        : breite * 0.6;

    return SizedBox(
      width: layoutBreite,
      height: layoutHoehe,
      child: OverflowBox(
        maxWidth: breite,
        maxHeight: hoehe,
        // Die Skalierung liegt AUSSERHALB des Stacks und damit über beiden
        // Flammen gemeinsam. Würde jede Flamme einzeln skaliert, könnten die
        // beiden Skalierungen im Moment des Farbwechsels minimal auseinander-
        // laufen und der Übergang würde springen.
        child: ScaleTransition(
          scale: _popScale,
          child: SizedBox(
            width: breite,
            height: hoehe,
            // Beide Flammen sind deckungsgleich: identische Breite und Höhe,
            // beide füllen denselben Stack ohne Positioned/Align und ohne
            // eigenen Versatz. Die Kompositionen haben zudem dieselben Maße
            // (300x250, geprüft), sodass auch ihre Inhalte exakt
            // übereinanderliegen — die rote überdeckt die graue punktgenau.
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_istNeustart)
                  FadeTransition(
                    opacity: _graueOpacity,
                    child: Lottie.asset(
                      'assets/animations/flamme_grau.json',
                      controller: _graueLottieCtrl,
                      width: breite,
                      height: hoehe,
                      fit: BoxFit.fill,
                      errorBuilder: (context, fehler, stack) =>
                          _ladeFehler('flamme_grau.json', fehler),
                      onLoaded: (komposition) {
                        _meldeGeladen('flamme_grau.json', komposition);
                        // Normale Geschwindigkeit (1.0x) als Endlosschleife:
                        // die graue Flamme lodert von Anfang an genauso wie
                        // die rote, nur eben grau.
                        _graueLottieCtrl.duration = komposition.duration;
                        _graueLottieCtrl.repeat();
                      },
                    ),
                  ),
                FadeTransition(
                  opacity: _roteOpacity,
                  child: Lottie.asset(
                    'assets/animations/flamme_rot.json',
                    controller: _roteLottieCtrl,
                    width: breite,
                    height: hoehe,
                    fit: BoxFit.fill,
                    errorBuilder: (context, fehler, stack) =>
                        _ladeFehler('flamme_rot.json', fehler),
                    onLoaded: (komposition) {
                      _meldeGeladen('flamme_rot.json', komposition);
                      // Kein repeat() — die Loop treibt _tick von Hand weiter,
                      // damit das Tempo stufenlos änderbar bleibt.
                      _roteGrunddauer = komposition.duration;
                      _roteLottieCtrl.duration = komposition.duration;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _zahlenWechsel() {
    // Feste Höhe + ClipRect: die beiden Zahlen fahren übereinander durch
    // denselben Ausschnitt, sodass sie an dessen Kanten verschwinden statt
    // über den restlichen Inhalt zu laufen. Der Pop liegt AUSSERHALB des
    // Clips, damit die vergrößerte Zahl nicht beschnitten wird.
    return ScaleTransition(
      scale: _zahlPopScale,
      child: SizedBox(
        height: _kZahlHoehe,
        child: ClipRect(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SlideTransition(
                position: _alteZahlPos,
                child: FadeTransition(
                  opacity: _alteZahlOpacity,
                  child: Text('${widget.alterStreak}', style: _zahlStil),
                ),
              ),
              SlideTransition(
                position: _neueZahlPos,
                child: FadeTransition(
                  opacity: _neueZahlOpacity,
                  child: Text('${widget.neuerStreak}', style: _zahlStil),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
