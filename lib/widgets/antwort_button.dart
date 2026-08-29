import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'wackeln.dart';

// ── Antwortknopf ─────────────────────────────────────────────────────────────
//
// Der Knopf, mit dem im Stationsquiz jede Multiple-Choice-Frage beantwortet
// wird. Stand als privates _AntwortButton in station_quiz_screen.dart und ist
// hierher gewandert, damit er auch ausserhalb des Quiz gezeigt werden kann,
// ohne ihn nachzubauen — die Willkommens-Karte "Immer anders gefragt" stellt
// damit eine echte Frage nach. Ändert sich der Knopf im Spiel, ändert er sich
// dort mit.
//
// Ohne [onTap] bleibt er stumm stehen: genau das braucht die Nachstellung.

class AntwortButton extends StatefulWidget {
  final String text;
  final Widget? leading;
  final bool showFeedback;
  final bool istRichtig;
  final bool istGewaehlt;
  final bool feedbackRichtig;
  final VoidCallback? onTap;

  const AntwortButton({
    super.key,
    required this.text,
    this.leading,
    required this.showFeedback,
    required this.istRichtig,
    required this.istGewaehlt,
    required this.feedbackRichtig,
    this.onTap,
  });

  @override
  State<AntwortButton> createState() => _AntwortButtonState();
}

class _AntwortButtonState extends State<AntwortButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wackelCtrl;

  bool get _istFalschGewaehlt =>
      widget.showFeedback && widget.istGewaehlt && !widget.feedbackRichtig;

  @override
  void initState() {
    super.initState();
    _wackelCtrl = AnimationController(vsync: this, duration: kWackelDauer);
  }

  bool _warFalschGewaehlt(AntwortButton w) =>
      w.showFeedback && w.istGewaehlt && !w.feedbackRichtig;

  @override
  void didUpdateWidget(covariant AntwortButton old) {
    super.didUpdateWidget(old);
    // Der Übergang wird über den vorherigen Wert von _istFalschGewaehlt
    // selbst geprüft, nicht mehr über old.showFeedback: Letzteres traf nur zu,
    // wenn showFeedback im SELBEN Rebuild von false auf true kippte, und ging
    // damit leer aus, sobald der Screen zwischendurch noch einmal baute (z.B.
    // durch den Countdown-Tick) oder das Feedback bereits stand, als die Wahl
    // gesetzt wurde.
    if (!_warFalschGewaehlt(old) && _istFalschGewaehlt) {
      if (kDebugMode) {
        debugPrint('[Wackel/Button] Start "${widget.text}" — forward(from: 0)');
      }
      _wackelCtrl.forward(from: 0);
    } else if (!widget.showFeedback && old.showFeedback) {
      _wackelCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _wackelCtrl.dispose();
    super.dispose();
  }

  Color get _bgColor {
    if (!widget.showFeedback) return const Color(0xFFEAEAE5);
    if (widget.istRichtig) return const Color(0xFF4A9E4A);
    if (_istFalschGewaehlt) return const Color(0xFFE53935);
    return const Color(0xFFEAEAE5);
  }

  Color get _textColor {
    if (!widget.showFeedback) return const Color(0xFF1a1a1a);
    if (widget.istRichtig) return Colors.white;
    if (_istFalschGewaehlt) return Colors.white;
    return const Color(0xFF888888);
  }

  @override
  Widget build(BuildContext context) {
    // Die richtige Antwort blendet sanft grün ein (300ms, kein Wackeln) —
    // der falsch gewählte Button reagiert schneller (150ms) UND wackelt.
    final faerbDauer = widget.istRichtig && !widget.istGewaehlt
        ? const Duration(milliseconds: 300)
        : const Duration(milliseconds: 150);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _wackelCtrl,
          builder: (context, child) {
            final dx =
                _istFalschGewaehlt ? wackelOffset(_wackelCtrl.value) : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: AnimatedContainer(
            duration: faerbDauer,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
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
}
