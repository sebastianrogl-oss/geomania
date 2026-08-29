import 'dart:async';

import 'package:flutter/material.dart';

import '../data/lernpfad_data.dart';
import '../services/knopf_rueckmeldung.dart';

// ── Timing der Druck-Bewegung ────────────────────────────────────────────────
//
// Vorher sank der Kreis in 50 ms und federte in 100 ms zurück — beides
// gemessen ab dem Zustandswechsel. Bei einem kurzen Tipp liegen Aufsetzen und
// Loslassen aber nur rund 60 ms auseinander: Die Abwärtsbewegung bekam den
// Rückweg zugewiesen, bevor sie unten ankam, und der Kreis wackelte nur.
//
// Zwei Änderungen zusammen lösen das. Erstens sinkt er schneller. Zweitens
// bleibt er eine Mindestzeit unten, auch wenn der Finger längst weg ist —
// sonst hilft keine noch so kurze Dauer, weil das Ziel schon wieder wechselt.

/// Wie schnell der Kreis auf den Sockel sinkt.
const Duration kSinken = Duration(milliseconds: 40);

/// Wie schnell er zurückfedert.
const Duration kSteigen = Duration(milliseconds: 90);

/// Wie lange er nach dem Aufsetzen mindestens unten bleibt.
///
/// Etwas mehr als [kSinken], damit die Endlage kurz zu sehen ist und nicht
/// nur die Bewegung dorthin.
const Duration kMindestensUnten = Duration(milliseconds: 60);

/// Symbol eines Modus auf dem Stationsbutton des Lernpfads.
///
/// Stand als `_modusIcon` in home_screen.dart und ist hierher gewandert,
/// damit der Button außerhalb des Lernpfads gezeigt werden kann, ohne ihn
/// nachzubauen (Willkommens-Screen).
IconData lernpfadModusIcon(LernModus m) => switch (m) {
  LernModus.flaggenQuizBild => Icons.flag_rounded,
  LernModus.flaggenQuizMultiple => Icons.flag_rounded,
  LernModus.hauptstaedteMultiple => Icons.account_balance_rounded,
  LernModus.hauptstaedteEingabe => Icons.account_balance_rounded,
  LernModus.waehrungsQuiz => Icons.monetization_on_rounded,
  LernModus.sortierSpiel => Icons.sort_rounded,
  LernModus.preisSchaetzen => Icons.sell_rounded,
  LernModus.wirtschaftssektoren => Icons.factory_rounded,
  LernModus.umrissBild => Icons.map_rounded,
  LernModus.umrissMultiple => Icons.map_rounded,
  LernModus.flaggenQuizEingabe => Icons.flag_rounded,
  LernModus.umrissEingabe => Icons.map_rounded,
  LernModus.nachbarland => Icons.explore_rounded,
  LernModus.bipGesamt => Icons.trending_up_rounded,
  LernModus.flaeche => Icons.crop_square_rounded,
  LernModus.extremFrage => Icons.emoji_events_rounded,
  LernModus.waehrungZuLand => Icons.monetization_on_rounded,
  LernModus.extremFrageLeicht => Icons.emoji_events_rounded,
  LernModus.zufallsFakt => Icons.lightbulb_rounded,
  LernModus.bekanntesGebaeude => Icons.temple_buddhist_rounded,
  LernModus.grenzkettenRaetsel => Icons.route_rounded,
  LernModus.flaechenVergleich => Icons.crop_square_rounded,
  LernModus.zweiWahrheiten => Icons.psychology_alt_rounded,
  LernModus.wasGehoertNichtDazu => Icons.filter_alt_off_rounded,
  LernModus.laenderRanking => Icons.leaderboard_rounded,
  LernModus.nachbarschaftsKette => Icons.alt_route_rounded,
};

// ── Maße des Stationsbuttons ─────────────────────────────────────────────────
//
// Leitgröße ist der Kreisdurchmesser. Sockel und Symbol sind Anteile davon,
// damit der Button auch in anderer Größe stimmig bleibt; bei der Normalgröße
// 82 ergeben sie exakt die Werte, die der Lernpfad seit jeher zeigt (Sockel
// 5, Symbol 32).

/// Durchmesser im Lernpfad.
const double kStationsButtonGroesse = 82;

/// Sockelhöhe als Anteil des Durchmessers — 5 px bei 82.
const double _kSockelAnteil = 5 / 82;

/// Symbolgröße als Anteil des Durchmessers — 32 px bei 82.
const double _kSymbolAnteil = 32 / 82;

const _kGruenHell = Color(0xFF5DBB63);
const _kGruenDunkel = Color(0xFF4A9E4A);
const _kSockelGruen = Color(0xFF3D8B3D);

/// Der freigeschaltete Stationsbutton des Lernpfads.
///
/// Dasselbe Widget, das home_screen.dart auf dem Pfad zeichnet — nicht eine
/// zweite Fassung davon. Der Willkommens-Screen zeigt ihn (ohne [onTap], also
/// ohne Druck-Animation) als Beispiel für eine Station.
class LernpfadStationButton extends StatelessWidget {
  final LernModus modus;
  final VoidCallback? onTap;
  final double groesse;

  const LernpfadStationButton({
    super.key,
    required this.modus,
    this.onTap,
    this.groesse = kStationsButtonGroesse,
  });

  @override
  Widget build(BuildContext context) {
    return Druckbar3DButton(
      kreisGroesse: groesse,
      sockelHoehe: groesse * _kSockelAnteil,
      sockelFarbe: _kSockelGruen,
      inhalt: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [_kGruenHell, _kGruenDunkel],
            center: Alignment(-0.3, -0.3),
            radius: 0.8,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(lernpfadModusIcon(modus),
              color: Colors.white, size: groesse * _kSymbolAnteil),
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Runder Knopf, dessen Hauptkreis beim Drücken auf seinen Sockel sinkt.
///
/// Grundlage aller vier Stationszustände im Lernpfad (frei, aktuell,
/// erledigt, gesperrt). Ohne [onTap] bleibt er stehen und reagiert nicht.
class Druckbar3DButton extends StatefulWidget {
  final double kreisGroesse;
  final double sockelHoehe;
  final Color sockelFarbe;
  final Widget inhalt;
  final VoidCallback? onTap;

  const Druckbar3DButton({
    super.key,
    required this.kreisGroesse,
    required this.sockelHoehe,
    required this.sockelFarbe,
    required this.inhalt,
    this.onTap,
  });

  @override
  State<Druckbar3DButton> createState() => _Druckbar3DButtonState();
}

class _Druckbar3DButtonState extends State<Druckbar3DButton> {
  bool _gedrueckt = false;

  /// Wann der Finger aufgesetzt hat — Grundlage für [kMindestensUnten].
  DateTime? _seit;

  /// Bringt den Kreis nach der Mindestzeit zurück nach oben.
  Timer? _zurueck;

  @override
  void dispose() {
    _zurueck?.cancel();
    super.dispose();
  }

  void _loslassen() {
    _zurueck?.cancel();
    final seit = _seit;
    final schon = seit == null
        ? kMindestensUnten
        : DateTime.now().difference(seit);
    final rest = kMindestensUnten - schon;
    if (rest <= Duration.zero) {
      if (mounted) setState(() => _gedrueckt = false);
      return;
    }
    _zurueck = Timer(rest, () {
      if (mounted) setState(() => _gedrueckt = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.kreisGroesse;
    final s = widget.sockelHoehe;

    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) {
              _zurueck?.cancel();
              _seit = DateTime.now();
              setState(() => _gedrueckt = true);
            }
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              // Die Aktion läuft SOFORT los, nicht erst nach der Animation —
              // der Kreis federt währenddessen zurück. Ein Sheet, das 100 ms
              // später aufginge, fühlte sich träge an.
              knopfRueckmeldung();
              widget.onTap!();
              _loslassen();
            }
          : null,
      // Abgebrochene Geste: sofort zurück. Hier wurde nichts ausgelöst, also
      // gibt es auch nichts zu zeigen.
      onTapCancel: () {
        _zurueck?.cancel();
        if (mounted) setState(() => _gedrueckt = false);
      },
      child: SizedBox(
        width: g,
        height: g + s,
        child: Stack(
          children: [
            // Sockel
            Positioned(
              top: s,
              left: 0,
              right: 0,
              child: SizedBox(
                width: g,
                height: g,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.sockelFarbe,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            // Haupt-Kreis (sinkt beim Drücken)
            AnimatedPositioned(
              duration: _gedrueckt ? kSinken : kSteigen,
              curve: Curves.easeOut,
              top: _gedrueckt ? s : 0,
              left: 0,
              right: 0,
              height: g,
              child: widget.inhalt,
            ),
          ],
        ),
      ),
    );
  }
}
