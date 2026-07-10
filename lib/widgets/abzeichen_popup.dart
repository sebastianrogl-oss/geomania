import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/abzeichen_data.dart';
import '../services/einstellungen_service.dart';
import 'muenze_widget.dart';

/// Kurzes Erfolgs-Overlay direkt nach Abschluss einer Challenge/Station,
/// BEVOR der jeweilige Ergebnis-Screen final angezeigt wird — eines
/// nacheinander pro neu freigeschaltetem Abzeichen (meist genau eines).
/// Dunkles Vollbild-Overlay, keine Karte/kein Button — schließt sich nach
/// ca. 2-3 Sekunden automatisch selbst (oder per Tap sofort).
class AbzeichenPopup {
  static Future<void> zeigen(BuildContext context, List<Abzeichen> neue) async {
    for (final a in neue) {
      if (!context.mounted) return;
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Abzeichen',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, _, _) => _AbzeichenDialogInhalt(abzeichen: a),
        transitionBuilder: (ctx, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      );
    }
  }
}

class _AbzeichenDialogInhalt extends StatefulWidget {
  final Abzeichen abzeichen;
  const _AbzeichenDialogInhalt({required this.abzeichen});

  @override
  State<_AbzeichenDialogInhalt> createState() => _AbzeichenDialogInhaltState();
}

class _AbzeichenDialogInhaltState extends State<_AbzeichenDialogInhalt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  List<_Funkelpunkt> _funkelpunkte = const [];
  bool _bodenkontaktAusgeloest = false;
  bool _sichtbar = true;
  bool _geschlossen = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _ctrl.addListener(_aufBodenkontaktPruefen);
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2200), _schliessen);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Feuert exakt einmal, genau beim ERSTEN Erreichen der Zielposition
  /// (Übergang Fall- -> Ankunfts-Phase bei 60% der Gesamtanimation).
  void _aufBodenkontaktPruefen() {
    if (_bodenkontaktAusgeloest || _ctrl.value < 0.60) return;
    _bodenkontaktAusgeloest = true;
    _funkelpunkte = _erzeugeFunkelpunkte();
    _vibrieren();
  }

  Future<void> _vibrieren() async {
    if (await EinstellungenService.vibrationAktiv) {
      HapticFeedback.mediumImpact();
    }
  }

  List<_Funkelpunkt> _erzeugeFunkelpunkte() {
    final rng = Random();
    return List.generate(5, (i) {
      return _Funkelpunkt(
        winkel: rng.nextDouble() * 2 * pi,
        distanz: 50 + rng.nextDouble() * 40,
        groesse: 8 + rng.nextDouble() * 6,
      );
    });
  }

  /// Schließt das Overlay (idempotent) — sowohl vom Auto-Dismiss-Timer als
  /// auch vom optionalen Tap-to-dismiss aufrufbar, ohne doppeltes Pop.
  void _schliessen() {
    if (_geschlossen || !mounted) return;
    _geschlossen = true;
    setState(() => _sichtbar = false);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
    });
  }

  double _phase(double start, double end) =>
      Interval(start, end).transform(_ctrl.value);

  @override
  Widget build(BuildContext context) {
    final a = widget.abzeichen;
    return GestureDetector(
      onTap: _schliessen,
      child: SizedBox.expand(
        child: AnimatedOpacity(
          opacity: _sichtbar ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            color: Colors.black.withValues(alpha: 0.75),
            child: Center(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  // Materialisieren + Fall aus der Tiefe (0-60%): EIN
                  // durchgehender Tiefen-Fortschritt statt zweier separater
                  // Phasen, damit am Übergang 10% kein Sprung entsteht — die
                  // Münze ist am Anfang (t≈0, z≈-800) bereits winzig UND per
                  // Opacity unsichtbar, das Fade-in läuft nur über die
                  // ersten 10% der Gesamtanimation.
                  final tOpacity = _phase(0.0, 0.10);
                  final tTiefe = Curves.easeIn.transform(_phase(0.0, 0.60));
                  final z = -800 + tTiefe * 800;
                  final taumelX = sin(tTiefe * pi * 3) * 0.15 * (1 - tTiefe);
                  final rotationYFall = tTiefe * (2 * pi * 1.5);

                  // Schatten-Vorlauf (0-55%) — unabhängig von der Münze selbst.
                  final tSchatten = _phase(0.0, 0.55);

                  // Ankunft (60-70%): Taumeln klingt separat auf exakt 0 ab
                  // (easeOut), während die Größe kurz überschwingt (elasticOut)
                  // — zwei unterschiedliche Bewegungen derselben Phase.
                  final tAnkunft = _phase(0.60, 0.70);
                  final rotationY = tAnkunft <= 0
                      ? rotationYFall
                      : (2 * pi * 1.5) * (1 - Curves.easeOut.transform(tAnkunft));
                  final ueberschwingIntensitaet = Curves.elasticOut.transform(tAnkunft);
                  final skalierung = 1.0 + ueberschwingIntensitaet * 0.08;

                  // Blitz + Funkeln (60-90%), startet exakt beim Bodenkontakt.
                  final tBlitz = _phase(0.60, 0.90);
                  final funkelIntensitaet = sin(tBlitz.clamp(0.0, 1.0) * pi);

                  // Name erst nach der Landung (70-100%).
                  final tName = _phase(0.70, 1.0);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (tSchatten > 0)
                              Positioned(
                                bottom: 10,
                                child: Opacity(
                                  opacity: (tSchatten * 0.4).clamp(0.0, 1.0),
                                  child: Container(
                                    width: 60 + tSchatten * 60,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black,
                                      boxShadow: [
                                        BoxShadow(color: Colors.black, blurRadius: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            if (tBlitz > 0)
                              for (final f in _funkelpunkte)
                                Positioned(
                                  left: 110 + cos(f.winkel) * f.distanz - f.groesse / 2,
                                  top: 110 + sin(f.winkel) * f.distanz - f.groesse / 2,
                                  child: Opacity(
                                    opacity: funkelIntensitaet.clamp(0.0, 1.0),
                                    child: Icon(Icons.star_rounded,
                                        size: f.groesse, color: Colors.white),
                                  ),
                                ),
                            if (tBlitz > 0 && tBlitz < 1)
                              Container(
                                width: 60 + tBlitz * 140,
                                height: 60 + tBlitz * 140,
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
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0025)
                                ..translateByDouble(0.0, 0.0, z, 1.0)
                                ..rotateX(taumelX)
                                ..rotateY(rotationY),
                              child: Opacity(
                                opacity: tOpacity.clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: skalierung,
                                  child: MuenzenWidget(abzeichen: a, groesse: 150, erreicht: true),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Opacity(
                        opacity: tName,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF9A825).withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            a.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                decoration: TextDecoration.none),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
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
  final double distanz;
  final double groesse;
  const _Funkelpunkt({required this.winkel, required this.distanz, required this.groesse});
}
