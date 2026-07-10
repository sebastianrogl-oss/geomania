import 'dart:math';
import 'package:flutter/material.dart';
import '../data/abzeichen_data.dart';

/// Einziges, gemeinsam genutztes Münz-Widget für Münzalbum UND Freischalt-
/// Popup — garantiert identisches Aussehen an beiden Stellen. Dicke,
/// 3D-wirkende Münze im Stil der coin_*.png-Maskottchen-Varianten
/// (assets/icons/deko/), immer goldfarben (kein Tier-Unterschied mehr).
class MuenzenWidget extends StatelessWidget {
  final Abzeichen abzeichen;
  final double groesse;
  final bool erreicht;

  const MuenzenWidget({
    super.key,
    required this.abzeichen,
    required this.groesse,
    required this.erreicht,
  });

  @override
  Widget build(BuildContext context) {
    if (!erreicht) {
      return CustomPaint(
        size: Size(groesse, groesse),
        painter: DashedCirclePainter(color: Colors.white.withValues(alpha: 0.25)),
      );
    }

    return SizedBox(
      width: groesse,
      height: groesse,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Echtes Maskottchen-Körper-Bild als Münz-Grundlage. Das Bild ist
          // Weitformat (1380x752, Kreis füllt nur einen mittleren Streifen
          // der Breite) -> ClipOval + BoxFit.cover statt contain, sonst
          // erscheint der Kreis winzig mit riesigem transparentem Rand
          // (dasselbe Muster wie ProfilbildService.istWeitformat).
          ClipOval(
            child: Image.asset(
              'assets/icons/deko/Körper.png',
              width: groesse,
              height: groesse,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => _fallbackGradientMuenze(groesse),
            ),
          ),
          Icon(
            iconFuerAbzeichen(abzeichen.id),
            size: groesse * 0.38,
            color: const Color(0xFF4E342E),
          ),
        ],
      ),
    );
  }

  /// Absicherung falls das Körper.png-Bild nicht lädt — die vorherige,
  /// rein aus BoxDecoration gebaute Münze (Sockel + Gold-Gradient) als
  /// Fallback, kein leerer Kreis/Crash.
  Widget _fallbackGradientMuenze(double groesse) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: groesse * 0.04,
          child: Container(
            width: groesse * 0.96,
            height: groesse * 0.96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFC17F00),
              border: Border.all(color: const Color(0xFF4E342E), width: groesse * 0.027),
            ),
          ),
        ),
        Container(
          width: groesse * 0.96,
          height: groesse * 0.96,
          margin: EdgeInsets.only(bottom: groesse * 0.04),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.3, -0.3),
              colors: [Color(0xFFFFD54F), Color(0xFFF9A825)],
            ),
            border: Border.all(color: const Color(0xFF4E342E), width: groesse * 0.027),
          ),
        ),
      ],
    );
  }
}

/// Einfarbiges Silhouetten-Icon je Abzeichen — deckt alle 30 echten IDs aus
/// abzeichen_data.dart ab.
IconData iconFuerAbzeichen(String id) {
  if (id == 'streak_app_30') return Icons.workspace_premium_rounded;
  if (id.startsWith('streak_')) return Icons.local_fire_department_rounded;
  if (id == 'perfekt') return Icons.gps_fixed_rounded;
  if (id == 'neuer_rekord') return Icons.trending_up_rounded;
  if (id == 'alle_challenges') return Icons.grid_view_rounded;
  if (id.startsWith('kontinent_')) return Icons.public_rounded;
  if (id.startsWith('stationen_')) return Icons.flag_rounded;
  if (id.startsWith('punkte_preis_')) return Icons.attach_money_rounded;
  if (id.startsWith('punkte_higher_lower_')) return Icons.swap_vert_rounded;
  if (id.startsWith('punkte_ranking_game_')) return Icons.leaderboard_rounded;
  if (id.startsWith('punkte_portfolio_')) return Icons.show_chart_rounded;
  return Icons.star_rounded;
}

/// Gestrichelter Kreis-Umriss für ein noch nicht freigeschaltetes Abzeichen —
/// dezent, kein Schloss-Icon, macht "besessen" vs. "noch offen" auch
/// optisch klar unterscheidbar von der metallischen Münze.
class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  const DashedCirclePainter({required this.color, this.strokeWidth = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final radius = min(size.width, size.height) / 2 - strokeWidth / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    const dashLength = 5.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final naechsteLaenge = min(dashLength, metric.length - distance);
        canvas.drawPath(
          metric.extractPath(distance, distance + naechsteLaenge),
          paint,
        );
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
