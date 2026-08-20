import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../data/halbzeit_sprueche.dart';
import '../l10n/uebersetzungen.dart';
import '../services/einstellungen_service.dart';
import 'ergebnis_video.dart';

// ── Halbzeit-Moment im Lernpfad-Quiz ─────────────────────────────────────────
//
// Bewusst KEIN eigener Screen und kein Overlay, sondern nur der Inhaltsbereich:
// dieses Widget ersetzt im station_quiz_screen die Frage, während AppBar,
// Fortschrittsbalken, Skip-Button und Weiter-Button unverändert stehen
// bleiben. Für den Spieler fühlt es sich dadurch an wie eine weitere "Frage",
// nur eben ohne Frage — kein Screenwechsel, kein Bruch im Ablauf.
//
// Der Weiter-Button gehört deshalb dem Quiz-Screen und ist hier nicht
// enthalten.

/// In der Mitte läuft ein Video, das zum bisherigen Ergebnis passt — welches,
/// entscheidet halbzeitVideo() in widgets/ergebnis_video.dart, dieselbe
/// Einstufung, nach der auch der Spruch gewählt wird.
///
/// Dieses Bild springt ein, solange das Video lädt, und falls es gar nicht
/// lädt. So bleibt an der Stelle immer etwas stehen, nie eine leere Fläche.
const kHalbzeitBild = 'assets/icons/deko/coin_normal.png';

// ── Größen ───────────────────────────────────────────────────────────────────
// Das Bild nimmt den Platz ein, an dem sonst Frage und Antwortoptionen
// stehen — es ist der zentrale Inhalt dieses Moments.
const _kBildAnteilHoehe = 0.38;
const _kBildMin = 220.0;
const _kBildMax = 340.0;
/// Der Spruch sitzt als Bildunterschrift dicht unter dem Bild.
const _kAbstandBildSpruch = 22.0;

// ── Timing ───────────────────────────────────────────────────────────────────
// Kürzer als bei einem echten Screenwechsel: es tauscht nur der Inhalt, die
// Leiste darüber bleibt stehen.
const _kInhaltEin = Duration(milliseconds: 200);
const _kBildDauer = Duration(milliseconds: 350);
const _kSpruchDauer = Duration(milliseconds: 250);
const kHalbzeitBildAb = 150;
const _kSpruchAb = 450;
/// Ab hier zeigt der Quiz-Screen den Weiter-Button.
const kHalbzeitButtonAb = 650;

// Dezenter Stups beim Erscheinen des Bildes — der Moment ist zu klein für mehr.
const _kVibrationsDauerMs = 80;
const _kVibrationsStaerke = 110;

const _cDunkel = Color(0xFF1A1A1A);

class HalbzeitInhalt extends StatefulWidget {
  final int richtigBisher;
  final int beantwortet;

  const HalbzeitInhalt({
    super.key,
    required this.richtigBisher,
    required this.beantwortet,
  });

  @override
  State<HalbzeitInhalt> createState() => _HalbzeitInhaltState();
}

class _HalbzeitInhaltState extends State<HalbzeitInhalt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _inhaltCtrl;
  // Einmal gewählt und festgehalten, damit ein Rebuild nicht mitten im Moment
  // einen anderen Spruch einblendet.
  late final String _spruch;

  @override
  void initState() {
    super.initState();
    _spruch = HalbzeitSprueche.fuer(widget.richtigBisher, widget.beantwortet);
    _inhaltCtrl = AnimationController(vsync: this, duration: _kInhaltEin)
      ..forward();
    // Zeitgleich mit dem Erscheinen des Bildes.
    Future.delayed(const Duration(milliseconds: kHalbzeitBildAb), () {
      if (mounted) _vibrieren();
    });
  }

  @override
  void dispose() {
    _inhaltCtrl.dispose();
    super.dispose();
  }

  Future<void> _vibrieren() async {
    if (!await EinstellungenService.vibrationAktiv) return;
    final hatAmplitude = await Vibration.hasAmplitudeControl();
    if (!mounted) return;
    if (hatAmplitude) {
      Vibration.vibrate(
        duration: _kVibrationsDauerMs,
        amplitude: _kVibrationsStaerke,
      );
    } else {
      Vibration.vibrate(duration: _kVibrationsDauerMs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bildHoehe = (MediaQuery.of(context).size.height * _kBildAnteilHoehe)
        .clamp(_kBildMin, _kBildMax);

    return FadeTransition(
      opacity: _inhaltCtrl,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Auftritt(
            verzoegerungMs: kHalbzeitBildAb,
            dauer: _kBildDauer,
            mitScale: true,
            child: ErgebnisVideo(
              pfad: halbzeitVideo(widget.richtigBisher, widget.beantwortet),
              hoehe: bildHoehe,
              platzhalterBild: kHalbzeitBild,
            ),
          ),
          const SizedBox(height: _kAbstandBildSpruch),
          _Auftritt(
            verzoegerungMs: _kSpruchAb,
            dauer: _kSpruchDauer,
            child: Text(
              t(_spruch),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _cDunkel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Blendet sein Kind nach [verzoegerungMs] ein, wahlweise mit Hineinwachsen.
class _Auftritt extends StatefulWidget {
  final int verzoegerungMs;
  final Duration dauer;
  final bool mitScale;
  final Widget child;

  const _Auftritt({
    required this.verzoegerungMs,
    required this.dauer,
    required this.child,
    this.mitScale = false,
  });

  @override
  State<_Auftritt> createState() => _AuftrittState();
}

class _AuftrittState extends State<_Auftritt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.dauer);
    Future.delayed(Duration(milliseconds: widget.verzoegerungMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget inhalt = widget.child;
    if (widget.mitScale) {
      inhalt = ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0)
            .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
        child: inhalt,
      );
    }
    return FadeTransition(opacity: _ctrl, child: inhalt);
  }
}
