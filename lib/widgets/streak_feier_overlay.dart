import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';
import '../l10n/uebersetzungen.dart';
import '../services/haptik_service.dart';
import '../services/fortschritt_service.dart';
import '../services/streak_ziel_service.dart';

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
    // Ist mit diesem Tag zugleich das persönliche Ziel erreicht? Dann bekommt
    // DIESELBE Feier einen zweiten Teil — bewusst kein eigenes Overlay
    // hinterher, siehe StreakZielService.
    final erreicht = await StreakZielService.zielGeradeErreicht(neuerStreak);
    // VOR der Feier merken, nicht danach: Bricht dazwischen etwas ab, fällt
    // eine Feier aus. Andersherum käme sie ab jetzt jeden Tag wieder.
    if (erreicht != null) await StreakZielService.merkeZielGefeiert(erreicht);
    if (!context.mounted) return (alterStreak, neuerStreak);
    await StreakFeierOverlay.zeigen(
      context,
      alterStreak: alterStreak,
      neuerStreak: neuerStreak,
      erreichtesZiel: erreicht,
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

  /// Gesetzt, wenn mit diesem Tag zugleich das persönliche Ziel erreicht
  /// wurde — dann folgt auf die Feier ihr zweiter Teil.
  ///
  /// Bewusst ein Zusatz zu DIESEM Overlay und kein zweites dahinter: Zwei
  /// Vollbild-Momente hintereinander nehmen sich gegenseitig das Gewicht, und
  /// der zweite wirkt wie ein Dialog, den man wegklicken muss.
  final int? erreichtesZiel;

  const StreakFeierOverlay({
    super.key,
    required this.alterStreak,
    required this.neuerStreak,
    this.erreichtesZiel,
  });

  /// Zeigt die Feier als undurchsichtige Route über dem aktuellen Screen und
  /// kehrt zurück, sobald der Nutzer sie weggetippt hat.
  static Future<void> zeigen(
    BuildContext context, {
    required int alterStreak,
    required int neuerStreak,
    int? erreichtesZiel,
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
              erreichtesZiel: erreichtesZiel,
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

// ── Zweiter Teil: das erreichte Ziel ─────────────────────────────────────────
//
// Kommt NACH der eigentlichen Feier, nicht mit ihr. Die Zahl in der Flamme ist
// der Moment; die Zielmeldung ist die Einordnung dazu. Beides gleichzeitig
// einzublenden hiesse, sich selbst ins Wort zu fallen.
const _kZielPause = Duration(milliseconds: 500);
const _kZielEin = Duration(milliseconds: 500);

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

// ── Fall A: ansteigende Impulskette ──────────────────────────────────────────
//
// Fünf Stöße in immer kürzeren Abständen, abgeschlossen vom kräftigen
// Höhepunkt.
//
// DIE ZEITPUNKTE STAMMEN AUS DEM FRÜHEREN SYSTEM-MUSTER, das aus Pausen und
// Dauern bestand und vom Betriebssystem am Stück abgespielt wurde. Seit die
// Haptik über benannte Primitive läuft (siehe [HaptikService]), plant der
// Dienst je Stoß einen Zeitpunkt — die Tabelle bleibt die Rechengrundlage:
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
// Zur Kontrolle: Summe aller Werte vor dem letzten Stoß.
const _kVibrationHoehepunktMs = 750;

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
  // Der zweite Teil: die Zielmeldung samt Anschlussfrage.
  late final AnimationController _zielCtrl;

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
  /// Die laufende Haptik-Kette von Fall A — in dispose() abzubrechen, falls
  /// die Feier vorzeitig weggetippt wurde. Sonst schlagen die Impulse noch
  /// los, wenn längst etwas anderes auf dem Schirm steht.
  HaptikFolge? _haptik;

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

  /// Läuft der zweite Teil schon? Solange er läuft, schliesst ein Tipp die
  /// Feier NICHT mehr — sonst wischt ein Nutzer, der den Hinweis "Tippen für
  /// weiter" noch im Kopf hat, die Anschlussfrage weg, bevor er sie gelesen
  /// hat. Beendet wird von hier an nur noch über die Knöpfe.
  bool _zielPhase = false;

  /// Die angebotenen Anschlussziele. Leer heisst: keine Frage, nur die
  /// Meldung — siehe [StreakZielService.naechsteZiele].
  ///
  /// Massgeblich ist der GRÖSSERE von erreichtem Ziel und aktueller Serie,
  /// nicht bloss das Ziel. Der Unterschied fällt nur in einem Fall auf, dafür
  /// dort deutlich: Wer sich früh 7 Tage vornimmt, dann eine Weile nicht
  /// spielt und bei Serie 20 wieder einsteigt, hat sein Ziel erreicht — bekäme
  /// aber 14 angeboten, also weniger als er ohnehin schon hat. Er wäre damit
  /// am nächsten Tag sofort wieder "am Ziel", ohne etwas dafür getan zu haben.
  List<int> get _angebote {
    final ziel = widget.erreichtesZiel ?? 0;
    final basis = widget.neuerStreak > ziel ? widget.neuerStreak : ziel;
    return StreakZielService.naechsteZiele(basis);
  }

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
    _zielCtrl = AnimationController(vsync: this, duration: _kZielEin);
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



    _ablaufStarten();
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
    HaptikService.spiele(HaptikArt.stark);
  }

  // Fall A: eine ansteigende Kette, die mit dem kräftigen Stoß endet — er
  // fällt zeitlich auf den Farbwechsel (siehe _kVibrationHoehepunktMs).
  //
  // FRÜHER WAR DAS EIN EINZIGES SYSTEM-MUSTER: eine Liste aus Pausen und
  // Dauern samt Intensitäten, die das Betriebssystem selbstständig abspielte.
  // Das ging nur, solange die Haptik in Millisekunden Motorlauf gedacht war.
  // Ein Haptik-Primitiv hat keine Dauer, es ist ein fertiges Gefühl — also
  // plant der [HaptikService] jetzt je Stoß einen Zeitpunkt.
  //
  // Die ZEITPUNKTE sind aus dem alten Muster übernommen, nicht neu erfunden:
  // Sie ergeben sich aus dessen Pausen und Dauern aufsummiert, sodass der
  // Höhepunkt weiterhin exakt bei 750ms liegt. Aus den Amplituden 60/85/115/
  // 150/190/255 sind die drei benannten Stärken geworden.
  void _vibrationsketteStarten() {
    _haptik = HaptikService.folge(const [
      HaptikSchritt(0, HaptikArt.leicht),
      HaptikSchritt(186, HaptikArt.leicht),
      HaptikSchritt(350, HaptikArt.mittel),
      HaptikSchritt(498, HaptikArt.mittel),
      HaptikSchritt(629, HaptikArt.mittel),
      HaptikSchritt(_kVibrationHoehepunktMs, HaptikArt.stark),
    ]);
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

    // Ohne erreichtes Ziel endet die Feier hier wie bisher: der dezente
    // Hinweis erscheint, ein Tipp schliesst.
    if (widget.erreichtesZiel == null) {
      _hinweisCtrl.forward();
      return;
    }

    // Mit Ziel: kurz Luft holen, dann den zweiten Teil. Der Hinweis "Tippen
    // für weiter" bleibt aus — hier wird nicht weggetippt, sondern gewählt.
    await Future.delayed(_kZielPause);
    if (!mounted) return;
    setState(() => _zielPhase = true);
    _zielCtrl.forward();
    HaptikService.spiele(HaptikArt.mittel);
  }

  /// Ein neues Ziel gewählt — speichern und die Feier beenden.
  Future<void> _neuesZiel(int tage) async {
    await StreakZielService.setzeZiel(tage);
    // Das neue Ziel gilt als noch nicht gefeiert: Es liegt über dem gerade
    // erreichten, und merkeZielGefeiert hat nur diesen Wert gespeichert.
    // Erreicht der Spieler auch das neue, feiert es erneut.
    if (mounted) await _schliessen();
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
    // Eine noch laufende Impulskette abbrechen, falls die Feier vorzeitig
    // weggetippt wurde — sie liefe sonst im Hintergrund weiter.
    _haptik?.abbrechen();
    _popCtrl.removeListener(_pruefePopHoehepunkt);
    _einblendCtrl.dispose();
    _zahlCtrl.dispose();
    _hinweisCtrl.dispose();
    _zielCtrl.dispose();
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
        // In der Ziel-Phase nimmt der Hintergrund keinen Tipp mehr entgegen:
        // Wer eben noch "Tippen für weiter" gelesen hat, würde die
        // Anschlussfrage sonst wegwischen, bevor er sie überhaupt gesehen
        // hat. Beendet wird von dort an über die Knöpfe.
        onTap: _zielPhase ? null : _schliessen,
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
                // Die untere Zone gehört entweder dem dezenten Hinweis oder —
                // wenn ein Ziel erreicht wurde — dem zweiten Teil der Feier.
                // Nie beiden: Ein "Tippen für weiter" unter einer Frage mit
                // Knöpfen wäre eine widersprüchliche Aufforderung.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _zielPhase
                      ? FadeTransition(
                          opacity: _zielCtrl,
                          child: _zielTeil(),
                        )
                      : FadeTransition(
                          opacity: _hinweisCtrl,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            // Formulierung, Größe und Deckkraft identisch zum
                            // Abzeichen-Popup (widgets/abzeichen_popup.dart),
                            // damit sich beide Overlays gleich anfühlen.
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

  /// Der zweite Teil: was erreicht wurde, und die Frage nach dem nächsten.
  ///
  /// Steht unten, wo sonst der Hinweis steht — die Flamme mit ihrer Zahl
  /// bleibt oben unangetastet stehen. Sie ist der Moment; hier steht nur, was
  /// er bedeutet.
  Widget _zielTeil() {
    final ziel = widget.erreichtesZiel!;
    final angebote = _angebote;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t('Ziel erreicht!'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t('{tage} Tage am Stück.', {'tage': '$ziel'}),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          // Am oberen Ende der Leiter gibt es nichts mehr anzubieten. Dann
          // bleibt es bei der Meldung und einem Knopf zum Weitermachen —
          // besser als ein ausgedachtes Ziel, nur damit die Frage kommt.
          if (angebote.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text(
              t('Neues Ziel?'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 12),
            // Wrap statt Row: Bei grosser Systemschrift oder dreistelligen
            // Zielen ("365 Tage") passen drei Knöpfe nicht mehr
            // nebeneinander — sie rutschen dann in die nächste Zeile, statt
            // überzulaufen.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tage in angebote)
                  _ZielKnopf(
                    beschriftung:
                        // Zahl und Wort zusammen im Schlüssel: Im Englischen
                        // steht "days" hinter der Zahl, aber eine Sprache mit
                        // anderer Stellung liesse sich sonst nicht abbilden.
                        t('{tage} Tage', {'tage': '$tage'}),
                    onTap: () => _neuesZiel(tage),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          // Der Ausweg. Ohne ihn wäre die Feier eine Sackgasse, in der man
          // sich etwas vornehmen MUSS, um weiterzukommen.
          TextButton(
            onPressed: _schliessen,
            child: Text(
              angebote.isEmpty ? t('Weiter') : t('Kein neues Ziel'),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
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

/// Ein Knopf der Zielauswahl im zweiten Teil der Feier.
///
/// Heller Umriss auf dunklem Grund statt gefüllter Fläche: Die Feier lebt von
/// der Flamme, und drei kräftige Flächen darunter würden ihr den Blick
/// abziehen. Gefüllt wäre ausserdem eine Empfehlung — hier soll aber keines
/// der Ziele das naheliegende sein.
class _ZielKnopf extends StatelessWidget {
  final String beschriftung;
  final VoidCallback onTap;

  const _ZielKnopf({required this.beschriftung, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Text(
            beschriftung,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
