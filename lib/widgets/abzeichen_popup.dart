import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../data/abzeichen_data.dart';
import '../l10n/uebersetzungen.dart';
import '../services/einstellungen_service.dart';
import '../services/sound_service.dart';
import 'muenze_widget.dart';

/// Erfolgs-Overlay direkt nach Abschluss einer Challenge/Station, BEVOR der
/// jeweilige Ergebnis-Screen final angezeigt wird — eines nacheinander pro neu
/// freigeschaltetem Abzeichen (meist genau eines).
///
/// Dunkles Vollbild-Overlay, keine Karte/kein Button. Es bleibt stehen, bis der
/// Nutzer irgendwo tippt (bewusst kein Auto-Dismiss mehr — genau wie bei der
/// Streak-Feier, siehe streak_feier_overlay.dart).
///
/// Das ist der EINZIGE Einstiegspunkt: sowohl der echte Spielbetrieb als auch
/// der Debug-Button in den Einstellungen rufen ausschließlich diese Methode
/// auf, damit es keine zweite, parallel zu pflegende Variante gibt.
class AbzeichenPopup {
  static Future<void> zeigen(BuildContext context, List<Abzeichen> neue) async {
    for (var i = 0; i < neue.length; i++) {
      if (!context.mounted) return;
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Abzeichen',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, _, _) => _AbzeichenDialogInhalt(
          abzeichen: neue[i],
          nummer: i + 1,
          gesamt: neue.length,
        ),
        transitionBuilder: (ctx, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      );
    }
  }
}

// ── Timing ───────────────────────────────────────────────────────────────────
//
// Ein Haupt-Controller (_kGesamt) treibt Fall, Ankunft, Blitz und Namen über
// Intervalle; Aufprallwelle und Hinweistext hängen an eigenen Controllern,
// weil sie erst durch ein Ereignis ausgelöst werden.
//
//   Phase              Anteil          Zeit
//   Vorlauf         0.00 - 0.15      0 -  195ms   leer, siehe _kMuenzeStart
//   Münze sichtbar  0.15 - 0.23    195 -  299ms
//   Fall            0.15 - 0.66    195 -  858ms
//   Aufprall             0.66            858ms    Welle + Blitz + Vibration
//   Ankunft         0.66 - 0.74    858 -  962ms   Überschwingen
//   Blitz/Funkeln   0.66 - 0.89    858 - 1157ms
//   Name            0.74 - 1.00    962 - 1300ms
//   Hinweis          nach Ende     1300 - 1700ms
const _kGesamt = Duration(milliseconds: 1300);
const _kWelle = Duration(milliseconds: 500);
const _kHinweisEin = Duration(milliseconds: 400);
const _kAusblenden = Duration(milliseconds: 400);

// Die Münze startet erst hier. Der Vorsprung stammt aus dem früheren
// Schatten-Vorlauf; seit dessen Entfernung passiert in diesen ~195ms nichts
// mehr. Auf 0.0 gesetzt beginnt der Fall unmittelbar.
const _kMuenzeStart = 0.15;
const _kMuenzeSichtbar = 0.23;
// Erster Bodenkontakt: Welle, Blitz und Vibration starten.
const _kAufprall = 0.66;
const _kAnkunftEnde = 0.74;
const _kBlitzEnde = 0.89;

// Fall B der Streak-Feier nutzt 255; die Münze schlägt etwas weicher auf.
const _kVibrationsDauerMs = 150;
const _kVibrationsStaerke = 220;

// ── Größen ───────────────────────────────────────────────────────────────────
//
// DIE MÜNZGRÖSSE IST DER EINZIGE HEBEL FÜR DIE GESAMTGRÖSSE.
//
// Sämtliche Effektmaße unten — Schatten, Aufprallwelle, Lichtblitz, Funkeln,
// Bühnenrand, Name und Abstände — sind reine VERHÄLTNISSE zur Münzgröße und
// werden zur Laufzeit daraus berechnet. Es gibt keine festen Pixelwerte mehr.
// Wer die Animation künftig größer oder kleiner haben will, ändert allein
// _kGesamtSkalierung (oder die Münzformel darunter); Schatten, Welle, Blitz
// und Funkeln folgen automatisch und bleiben in Position und Proportion
// stimmig, ohne dass irgendein Wert manuell nachgezogen werden muss.
//
// Die Timings bleiben davon unberührt — sie stehen weiter oben bei _kGesamt.
const _kGesamtSkalierung = 0.54;

// Ungeskalierte Basis: dieselbe Formel wie die Flamme der Streak-Feier
// (streak_feier_overlay.dart), damit beide Momente vergleichbar auftreten.
const _kMuenzeAnteilHoehe = 0.42;
const _kMuenzeMin = 345.0;
const _kMuenzeMax = 525.0;

double _muenzGroesse(Size schirm) =>
    (schirm.height * _kMuenzeAnteilHoehe * _kGesamtSkalierung).clamp(
      _kMuenzeMin * _kGesamtSkalierung,
      _kMuenzeMax * _kGesamtSkalierung,
    );

// ── Verhältnisse zur Münzgröße ───────────────────────────────────────────────

// Rand um die Münze; Welle und Blitz ragen bewusst darüber hinaus (Clip.none).
const _kBuehneZuMuenze = 1.25;
// Als Anteil der Münzgröße gewählt, sodass sie exakt die bisherigen absoluten
// Werte fortschreiben (Name 23.04 / Abstand 11.52 bei Münze 378) und damit
// dieselbe Verkleinerung mitmachen wie alles andere.
const _kAbstandMuenzeName = 0.042;
const _kNameGroesse = 0.108;

// Aufprallwelle: startet unterhalb der Münzbreite und endet knapp über
// Münzgröße, statt auf das Doppelte hinauszulaufen.
const _kWellenStart = 0.75;
const _kWellenEnde = 1.45;
const _kWellenStrichstaerke = 0.024;

// Lichtblitz: bleibt dicht an der Münze und damit innerhalb der Welle.
const _kBlitzStart = 0.55;
const _kBlitzEndeGroesse = 1.15;

// Funkeln: mittlerer Abstand vom Mittelpunkt und mittlere Sterngröße.
const _kFunkelDistanz = 0.58;
const _kFunkelGroesse = 0.07;
const _kFunkelAnzahl = 5;

class _AbzeichenDialogInhalt extends StatefulWidget {
  final Abzeichen abzeichen;
  final int nummer;
  final int gesamt;

  const _AbzeichenDialogInhalt({
    required this.abzeichen,
    required this.nummer,
    required this.gesamt,
  });

  @override
  State<_AbzeichenDialogInhalt> createState() => _AbzeichenDialogInhaltState();
}

class _AbzeichenDialogInhaltState extends State<_AbzeichenDialogInhalt>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  // Aufprallwelle: eigener Controller, da sie erst beim Bodenkontakt startet
  // und länger läuft als die verbleibende Hauptanimation.
  late final AnimationController _wellenCtrl;
  late final Animation<double> _welle;
  // Hinweistext, erscheint erst nach der kompletten Animation.
  late final AnimationController _hinweisCtrl;

  List<_Funkelpunkt> _funkelpunkte = const [];
  bool _bodenkontaktAusgeloest = false;
  bool _sichtbar = true;
  bool _geschlossen = false;

  // Vorab geladen, damit beim Aufprall kein await zwischen Ereignis und
  // Vibration liegt (gleiches Vorgehen wie in streak_feier_overlay.dart).
  bool _vibrationErlaubt = false;
  bool _hatAmplitude = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _kGesamt);
    _ctrl.addListener(_aufBodenkontaktPruefen);
    _wellenCtrl = AnimationController(vsync: this, duration: _kWelle);
    _welle = CurvedAnimation(parent: _wellenCtrl, curve: Curves.easeOut);
    _hinweisCtrl = AnimationController(vsync: this, duration: _kHinweisEin);

    _vibrationVorbereiten();

    // Kein Auto-Dismiss mehr: nach der Animation erscheint nur der Hinweis,
    // geschlossen wird per Tap (siehe _schliessen).
    _ctrl.forward().whenComplete(() {
      if (mounted) _hinweisCtrl.forward();
    });
  }

  Future<void> _vibrationVorbereiten() async {
    final erlaubt = await EinstellungenService.vibrationAktiv;
    if (!erlaubt || !mounted) return;
    final amplitude = await Vibration.hasAmplitudeControl();
    if (!mounted) return;
    _vibrationErlaubt = true;
    _hatAmplitude = amplitude;
  }

  @override
  void dispose() {
    if (_vibrationErlaubt) Vibration.cancel();
    _ctrl.removeListener(_aufBodenkontaktPruefen);
    _ctrl.dispose();
    _wellenCtrl.dispose();
    _hinweisCtrl.dispose();
    super.dispose();
  }

  /// Feuert exakt einmal, genau beim ERSTEN Erreichen der Zielposition.
  void _aufBodenkontaktPruefen() {
    if (_bodenkontaktAusgeloest || _ctrl.value < _kAufprall) return;
    _bodenkontaktAusgeloest = true;
    _funkelpunkte = _erzeugeFunkelpunkte();
    _wellenCtrl.forward(from: 0);
    // Der Klang gehört zum AUFPRALL, nicht zum Fall davor: diese Methode
    // feuert genau einmal, im Moment des ersten Bodenkontakts (siehe
    // _kAufprall). Während des Schatten-Vorlaufs bleibt es still.
    SoundService.spiele(Klang.muenze);
    _vibrieren();
  }

  // Ein einzelner, kräftiger Stoß — die Münze schlägt einmal auf, kein
  // Aufbau wie bei der Streak-Feier.
  void _vibrieren() {
    if (!_vibrationErlaubt) return;
    if (kDebugMode) {
      debugPrint('[Abzeichen] Aufprall-Vibration ${_kVibrationsDauerMs}ms '
          '(Amplitude ${_hatAmplitude ? _kVibrationsStaerke : 'n/a'})');
    }
    if (_hatAmplitude) {
      Vibration.vibrate(
        duration: _kVibrationsDauerMs,
        amplitude: _kVibrationsStaerke,
      );
    } else {
      Vibration.vibrate(duration: _kVibrationsDauerMs);
    }
  }

  // Gleichmäßig um die Münze verteilt: jeder Punkt bekommt sein eigenes
  // Kreissegment (360° / Anzahl) und darf darin nur leicht streuen. Rein
  // zufällige Winkel konnten mehrere Sterne dicht nebeneinander legen, was
  // bei kleiner Münze als Überlappung auffiel.
  //
  // Distanz und Größe werden als ANTEIL der Münzgröße gespeichert und erst
  // beim Zeichnen in Pixel umgerechnet — dadurch skalieren sie automatisch mit.
  List<_Funkelpunkt> _erzeugeFunkelpunkte() {
    final rng = Random();
    const segment = 2 * pi / _kFunkelAnzahl;
    return List.generate(_kFunkelAnzahl, (i) {
      // Streuung auf ±20% des Segments begrenzt, damit die Abstände wahrbar
      // gleichmäßig bleiben.
      final streuung = (rng.nextDouble() - 0.5) * segment * 0.4;
      return _Funkelpunkt(
        winkel: i * segment + streuung,
        distanzAnteil: _kFunkelDistanz * (0.85 + rng.nextDouble() * 0.3),
        groesseAnteil: _kFunkelGroesse * (0.8 + rng.nextDouble() * 0.4),
      );
    });
  }

  /// Schließt das Overlay (idempotent).
  void _schliessen() {
    if (_geschlossen || !mounted) return;
    _geschlossen = true;
    setState(() => _sichtbar = false);
    Future.delayed(_kAusblenden, () {
      if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
    });
  }

  double _phase(double start, double end) =>
      Interval(start, end).transform(_ctrl.value);

  @override
  Widget build(BuildContext context) {
    final a = widget.abzeichen;
    return GestureDetector(
      // opaque: der ganze Screen nimmt den Tap entgegen, nicht nur der Inhalt.
      behavior: HitTestBehavior.opaque,
      onTap: _schliessen,
      child: SizedBox.expand(
        child: AnimatedOpacity(
          opacity: _sichtbar ? 1.0 : 0.0,
          duration: _kAusblenden,
          child: Container(
            color: Colors.black.withValues(alpha: 0.75),
            child: Stack(
              children: [
                Center(
                  // Die Bühne hat eine feste Layout-Größe (Münze + Rand +
                  // Name); scaleDown greift nur, wenn sie auf einem niedrigen
                  // Screen nicht passt. Da die überlaufenden Effekte per
                  // Clip.none aus dem Layout heraus sind, bleibt der
                  // Skalierungsfaktor über die Animation konstant — kein
                  // Zappeln.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_ctrl, _wellenCtrl]),
                      builder: (context, _) => _buehne(a),
                    ),
                  ),
                ),
                // Zähler nur, wenn tatsächlich mehrere Abzeichen anstehen.
                if (widget.gesamt > 1)
                  Positioned(
                    top: 24,
                    right: 24,
                    child: SafeArea(
                      child: Text(
                        '${widget.nummer} / ${widget.gesamt}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.5),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                // Hinweis identisch zur Streak-Feier: gleiche Formulierung,
                // Größe und Deckkraft, damit sich beide Overlays gleich
                // anfühlen.
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FadeTransition(
                    opacity: _hinweisCtrl,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Text(
                        t('Tippen für weiter'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                          decoration: TextDecoration.none,
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

  Widget _buehne(Abzeichen a) {
    // Materialisieren + Fall aus der Tiefe: EIN durchgehender
    // Tiefen-Fortschritt statt zweier separater Phasen, damit am Übergang
    // kein Sprung entsteht — die Münze ist am Anfang (t≈0, z≈-800) bereits
    // winzig UND per Opacity unsichtbar.
    final tOpacity = _phase(_kMuenzeStart, _kMuenzeSichtbar);
    final tTiefe =
        Curves.easeIn.transform(_phase(_kMuenzeStart, _kAufprall));
    final z = -800 + tTiefe * 800;
    final taumelX = sin(tTiefe * pi * 3) * 0.15 * (1 - tTiefe);
    final rotationYFall = tTiefe * (2 * pi * 1.5);

    // Ankunft: Taumeln klingt separat auf exakt 0 ab (easeOut), während die
    // Größe kurz überschwingt (elasticOut).
    final tAnkunft = _phase(_kAufprall, _kAnkunftEnde);
    final rotationY = tAnkunft <= 0
        ? rotationYFall
        : (2 * pi * 1.5) * (1 - Curves.easeOut.transform(tAnkunft));
    final ueberschwingIntensitaet = Curves.elasticOut.transform(tAnkunft);
    final skalierung = 1.0 + ueberschwingIntensitaet * 0.08;

    // Blitz + Funkeln, startet exakt beim Bodenkontakt.
    final tBlitz = _phase(_kAufprall, _kBlitzEnde);
    final funkelIntensitaet = sin(tBlitz.clamp(0.0, 1.0) * pi);

    // Name erst nach der Landung.
    final tName = _phase(_kAnkunftEnde, 1.0);

    final muenze = _muenzGroesse(MediaQuery.of(context).size);
    final buehne = muenze * _kBuehneZuMuenze;
    // Mittelpunkt der Bühne = Mittelpunkt der Münze: der Stack zentriert alle
    // Kinder, Welle und Blitz gehen dadurch exakt vom Münzzentrum aus. Die
    // Funkelpunkte werden von hier aus positioniert.
    final mitte = buehne / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: buehne,
          height: buehne,
          child: Stack(
            alignment: Alignment.center,
            // Welle und Funkeln dürfen über die Bühne hinausragen, statt an
            // ihrem Rand abgeschnitten zu werden.
            clipBehavior: Clip.none,
            children: [
              if (_wellenCtrl.isAnimating || _wellenCtrl.isCompleted)
                _aufprallWelle(muenze),
              if (tBlitz > 0)
                for (final fp in _funkelpunkte)
                  Positioned(
                    left: mitte +
                        cos(fp.winkel) * fp.distanzAnteil * muenze -
                        fp.groesseAnteil * muenze / 2,
                    top: mitte +
                        sin(fp.winkel) * fp.distanzAnteil * muenze -
                        fp.groesseAnteil * muenze / 2,
                    child: Opacity(
                      opacity: funkelIntensitaet.clamp(0.0, 1.0),
                      child: Icon(Icons.star_rounded,
                          size: fp.groesseAnteil * muenze,
                          color: Colors.white),
                    ),
                  ),
              if (tBlitz > 0 && tBlitz < 1)
                Container(
                  width: muenze *
                      (_kBlitzStart +
                          tBlitz * (_kBlitzEndeGroesse - _kBlitzStart)),
                  height: muenze *
                      (_kBlitzStart +
                          tBlitz * (_kBlitzEndeGroesse - _kBlitzStart)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: (1 - tBlitz) * 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              Transform(
                alignment: Alignment.center,
                // z bleibt unskaliert: die perspektivische Verkleinerung
                // (1 / (1 + |z| * 0.0025)) ist ein Verhältnis und wirkt
                // dadurch bei jeder Münzgröße gleich stark.
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0025)
                  ..translateByDouble(0.0, 0.0, z, 1.0)
                  ..rotateX(taumelX)
                  ..rotateY(rotationY),
                child: Opacity(
                  opacity: tOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: skalierung,
                    child: MuenzenWidget(
                        abzeichen: a, groesse: muenze, erreicht: true),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: muenze * _kAbstandMuenzeName),
        // Normale App-Typografie statt Neon-Glow: kein umgebender Container
        // mit BoxShadow und kein shadows-Parameter mehr. Das Fade-in nach der
        // Landung (tName) bleibt unverändert.
        //
        // 'Poppins' wird hier explizit gesetzt, obwohl app_theme.dart es
        // global vorgibt: der Dialog hängt an showGeneralDialog ohne
        // Material-Vorfahr, dort greift DefaultTextStyle.fallback() statt des
        // Themes — deshalb steht aus demselben Grund auch das
        // TextDecoration.none hier. Gleiches Vorgehen wie in
        // preis_schaetzen_screen.dart und rangliste_ergebnis_karte.dart.
        Opacity(
          opacity: tName,
          // Seitlicher Rand, damit lange Abzeichennamen umbrechen statt über
          // den Bildschirmrand zu laufen.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              a.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: muenze * _kNameGroesse,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Ring, der sich im Moment des Aufpralls vom Landepunkt nach außen
  // ausbreitet und dabei verblasst — läuft gleichzeitig mit dem Lichtblitz.
  Widget _aufprallWelle(double muenze) {
    final t = _welle.value;
    // Kein Positioned/Align: der Stack zentriert den Ring, er geht damit vom
    // exakt selben Mittelpunkt aus wie die Münze.
    final durchmesser =
        muenze * (_kWellenStart + t * (_kWellenEnde - _kWellenStart));
    return Container(
      width: durchmesser,
      height: durchmesser,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFF9A825).withValues(alpha: (1 - t) * 0.7),
          width: muenze * _kWellenStrichstaerke * (1 - t),
        ),
      ),
    );
  }
}

// ── Funkelpunkte ───────────────────────────────────────────────────────────────
//
// Kurzes, dezentes Aufblitzen an festen Positionen um die Münze — kein
// wegfliegendes Konfetti mehr, nur Ein-/Ausblenden.

class _Funkelpunkt {
  final double winkel;
  /// Abstand vom Mittelpunkt, als Anteil der Münzgröße.
  final double distanzAnteil;
  /// Sterngröße, als Anteil der Münzgröße.
  final double groesseAnteil;

  const _Funkelpunkt({
    required this.winkel,
    required this.distanzAnteil,
    required this.groesseAnteil,
  });
}
