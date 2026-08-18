import 'package:flutter/material.dart';

/// Eigenständig gezeichnetes Filmklappen-Icon (statt gestapelter
/// Material-Icons) — kein einzelnes Material-Icon zeigt Klappen-Balken mit
/// schrägen Streifen UND Play-Dreieck zusammenhängend, deshalb per
/// CustomPainter direkt gezeichnet.
class FilmklappeIcon extends StatelessWidget {
  final double size;
  final Color color;

  const FilmklappeIcon({
    super.key,
    this.size = 16,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _FilmklappePainter(color),
    );
  }
}

class _FilmklappePainter extends CustomPainter {
  final Color color;
  _FilmklappePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final strich = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    final ecke = Radius.circular(w * 0.12);
    const keineEcke = Radius.zero;

    // Oberer Klappen-Balken (geschlossenes Rechteck, leicht schräg wirkend)
    // — nur die äußeren (oberen) Ecken abgerundet, die untere Kante bleibt
    // eckig, da dort der Körper anschließt.
    final klappe = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, h * 0.05, w, h * 0.28),
      topLeft: ecke,
      topRight: ecke,
      bottomLeft: keineEcke,
      bottomRight: keineEcke,
    );
    canvas.drawRRect(klappe, strich);

    // Die schrägen Streifen INNERHALB des Klappen-Balkens (verbunden, da sie
    // im geschlossenen Rechteck liegen)
    final fuell = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07;

    for (int i = 1; i <= 3; i++) {
      final x = w * (i * 0.25);
      canvas.drawLine(
        Offset(x, h * 0.05),
        Offset(x - w * 0.12, h * 0.33),
        fuell,
      );
    }

    // Unterer Körper der Klappe — nur die äußeren (unteren) Ecken
    // abgerundet, die obere Kante bleibt eckig (Anschluss an die Klappe).
    final koerper = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, h * 0.35, w, h * 0.60),
      topLeft: keineEcke,
      topRight: keineEcke,
      bottomLeft: ecke,
      bottomRight: ecke,
    );
    canvas.drawRRect(koerper, strich);

    // Play-Dreieck im unteren Körper
    final play = Path()
      ..moveTo(w * 0.40, h * 0.50)
      ..lineTo(w * 0.40, h * 0.80)
      ..lineTo(w * 0.66, h * 0.65)
      ..close();
    canvas.drawPath(
      play,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _FilmklappePainter old) =>
      old.color != color;
}
