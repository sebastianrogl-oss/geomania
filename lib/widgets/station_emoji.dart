import 'package:flutter/material.dart';
import '../data/lernpfad_data.dart';

// StatefulWidget damit nach Font-Load automatisch neu gerendert wird.
// RepaintBoundary ABSICHTLICH entfernt — es cached die Rasterisierung
// vor dem Font-Load und verhindert das spätere Update.
class EmojiText extends StatefulWidget {
  final String emoji;
  final double fontSize;

  const EmojiText(this.emoji, {super.key, this.fontSize = 28});

  @override
  State<EmojiText> createState() => _EmojiTextState();
}

class _EmojiTextState extends State<EmojiText> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.emoji,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: widget.fontSize,
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }
}

enum StationStatus { erledigt, aktuell, gesperrt }

// ── Emoji-Auswahl pro Modus ───────────────────────────────────────────────────

String modusEmoji(LernModus modus) {
  switch (modus) {
    case LernModus.flaggenQuizBild:
    case LernModus.flaggenQuizMultiple:
      return '🚩';
    case LernModus.hauptstaedteMultiple:
    case LernModus.hauptstaedteEingabe:
      return '🏛️';
    case LernModus.waehrungsQuiz:
      return '💰';
    case LernModus.sortierSpiel:
      return '🔀';
    case LernModus.preisSchaetzen:
      return '🏷️';
    case LernModus.wirtschaftssektoren:
      return '🏭';
    case LernModus.umrissBild:
    case LernModus.umrissMultiple:
    case LernModus.umrissEingabe:
      return '🗺️';
    case LernModus.flaggenQuizEingabe:
      return '🚩';
    case LernModus.nachbarland:
      return '🧭';
    case LernModus.bipGesamt:
      return '📈';
    case LernModus.flaeche:
      return '📐';
    case LernModus.extremFrage:
      return '🏆';
    case LernModus.waehrungZuLand:
      return '💱';
    case LernModus.extremFrageLeicht:
      return '🏆';
    case LernModus.zufallsFakt:
      return '💡';
    case LernModus.bekanntesGebaeude:
      return '🗿';
    case LernModus.grenzkettenRaetsel:
      return '🛂';
    case LernModus.flaechenVergleich:
      return '📐';
    case LernModus.zweiWahrheiten:
      return '🤔';
    case LernModus.wasGehoertNichtDazu:
      return '🧩';
    case LernModus.laenderRanking:
      return '🏅';
    case LernModus.nachbarschaftsKette:
      return '🧭';
  }
}

// ── StationEmoji — Emoji mit Status-Filter ────────────────────────────────────

class StationEmoji extends StatelessWidget {
  final LernModus modus;
  final StationStatus status;
  final double fontSize;

  const StationEmoji({
    super.key,
    required this.modus,
    required this.status,
    this.fontSize = 26,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = modusEmoji(modus);

    switch (status) {
      // Erledigt → weiß via ColorFilter
      case StationStatus.erledigt:
        return ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          child: RepaintBoundary(child: EmojiText(emoji, fontSize: fontSize)),
        );

      // Gesperrt → Graustufen-Matrix
      case StationStatus.gesperrt:
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      1, 0,
          ]),
          child: Opacity(
            opacity: 0.55,
            child: RepaintBoundary(child: EmojiText(emoji, fontSize: fontSize * 0.9)),
          ),
        );

      // Aktuell spielbar → farbig
      case StationStatus.aktuell:
        return EmojiText(emoji, fontSize: fontSize);
    }
  }
}

// ── StationButton — runder Button mit 3D-Sockel ───────────────────────────────

class StationButton extends StatelessWidget {
  final LernModus modus;
  final StationStatus status;

  const StationButton({
    super.key,
    required this.modus,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case StationStatus.erledigt:
        return _ErledigtButton(modus: modus);
      case StationStatus.aktuell:
        return _AktuellButton(modus: modus);
      case StationStatus.gesperrt:
        return _GesperrtButton(modus: modus);
    }
  }
}

// Grüner Button — erledigt
class _ErledigtButton extends StatelessWidget {
  final LernModus modus;
  const _ErledigtButton({required this.modus});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 3D-Sockel
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2E7D32),
            ),
          ),
          // Hauptkreis
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4A9E4A),
              border: Border.all(color: const Color(0xFF1a1a1a), width: 2.5),
            ),
            child: Center(
              child: StationEmoji(
                modus: modus,
                status: StationStatus.erledigt,
                fontSize: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Grüner Button — aktuell spielbar (mit Puls-Effekt)
class _AktuellButton extends StatefulWidget {
  final LernModus modus;
  const _AktuellButton({required this.modus});

  @override
  State<_AktuellButton> createState() => _AktuellButtonState();
}

class _AktuellButtonState extends State<_AktuellButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _puls;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _puls = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsierender Außenring
          AnimatedBuilder(
            animation: _puls,
            builder: (context, _) => Container(
              width: 64 * _puls.value,
              height: 64 * _puls.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A9E4A).withValues(alpha: 0.3),
              ),
            ),
          ),
          // 3D-Sockel
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2E7D32),
            ),
          ),
          // Hauptkreis (etwas größer als erledigt)
          Container(
            width: 52,
            height: 52,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4A9E4A),
              border: Border.all(color: const Color(0xFF1a1a1a), width: 3.0),
            ),
            child: Center(
              child: StationEmoji(
                modus: widget.modus,
                status: StationStatus.aktuell,
                fontSize: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Grauer Button — gesperrt
class _GesperrtButton extends StatelessWidget {
  final LernModus modus;
  const _GesperrtButton({required this.modus});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 3D-Sockel
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFB0AEA8),
            ),
          ),
          // Hauptkreis
          Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD0CEC8),
              border: Border.all(color: const Color(0xFF1a1a1a), width: 2.0),
            ),
            child: Center(
              child: StationEmoji(
                modus: modus,
                status: StationStatus.gesperrt,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meilenstein-Button ────────────────────────────────────────────────────────

class MeilensteinButton extends StatelessWidget {
  final bool istErreicht;

  const MeilensteinButton({super.key, required this.istErreicht});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sockel
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: istErreicht
                  ? const Color(0xFFC17F00)
                  : const Color(0xFFB0AEA8),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          // Hauptfläche
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: istErreicht
                  ? const Color(0xFFF9A825)
                  : const Color(0xFFD0CEC8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1a1a1a), width: 2.5),
            ),
            child: Center(
              child: istErreicht
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                          Colors.white, BlendMode.srcIn),
                      child: const RepaintBoundary(
                        child: Text('🎁', style: TextStyle(fontSize: 22)),
                      ),
                    )
                  : ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ]),
                      child: const RepaintBoundary(
                        child: Opacity(
                          opacity: 0.55,
                          child: Text('🎁', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
