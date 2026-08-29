import 'package:flutter/material.dart';

import '../utils/responsive.dart';

// ── Challenge-Kachel ─────────────────────────────────────────────────────────
//
// Eine der vier Kacheln im Tages-Challenge-Panel. Stand als private
// _GrossKarte in home_screen.dart und ist hierher gewandert, damit sie auch
// ausserhalb des Panels gezeigt werden kann, ohne sie nachzubauen — die
// Willkommens-Karte "Jeden Tag etwas Neues" stellt damit einen Ausschnitt der
// echten Challenge-Ansicht nach. Ändert sich die Kachel im Panel, ändert sie
// sich dort mit.
//
// Ohne [onTap] bleibt sie stumm stehen: genau das braucht die Nachstellung.
class ChallengeKachel extends StatefulWidget {
  final String id, asset, emoji, title;
  final Color bg;
  final bool isDone;
  final VoidCallback? onTap;
  const ChallengeKachel({
    super.key,
    required this.id,
    required this.asset,
    required this.emoji,
    required this.title,
    required this.bg,
    required this.isDone,
    this.onTap,
  });

  @override
  State<ChallengeKachel> createState() => _ChallengeKachelState();
}

class _ChallengeKachelState extends State<ChallengeKachel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Öffnet immer den ChallengeStartScreen — der entscheidet selbst anhand
    // des Tagesstatus, ob "Spielen" oder "Ergebnis ansehen" angezeigt wird.
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0),
        child: child,
      ),
      child: GestureDetector(
        onTap: _handleTap,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: widget.bg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(14.rpx(context)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo groß, kein weißlicher Hintergrund
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        widget.asset,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => Center(
                          child: Text(
                            widget.emoji,
                            style: TextStyle(fontSize: 52.rsp(context)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.rpx(context)),
                  // Titel unten — feste Höhe für exakt 2 Zeilen reserviert,
                  // damit der Icon-Bereich (Expanded oben) bei 1-zeiligen
                  // Titeln (z.B. "Ranking Quiz") nicht mehr Höhe bekommt als
                  // bei 2-zeiligen (z.B. "Portfolio des Tages") — sonst
                  // wirken die Icons trotz gleich großer Kacheln
                  // unterschiedlich groß. Skaliert mit rpx() (nicht rsp()),
                  // da sie zur Schriftgröße passen muss, die selbst mit
                  // rsp() wächst — beide zusammen halten das Verhältnis.
                  SizedBox(
                    height: 42.rpx(context),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.rsp(context),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isDone)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 22.rpx(context),
                  height: 22.rpx(context),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: const Color(0xFF4A9E4A),
                    size: 16.rpx(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
