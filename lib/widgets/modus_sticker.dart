import 'dart:math';
import 'package:flutter/material.dart';
import '../data/lernpfad_data.dart';

// ── Haupt-Dispatcher ──────────────────────────────────────────────────────────

class ModusSticker extends StatelessWidget {
  final LernModus modus;
  final bool istGesperrt;
  final double groesse;

  const ModusSticker({
    super.key,
    required this.modus,
    required this.istGesperrt,
    this.groesse = 32,
  });

  @override
  Widget build(BuildContext context) {
    switch (modus) {
      case LernModus.flaggenQuizBild:
      case LernModus.flaggenQuizMultiple:
      case LernModus.flaggenQuizEingabe:
        return _FlaggenSticker(istGesperrt: istGesperrt, groesse: groesse);
      case LernModus.hauptstaedteMultiple:
      case LernModus.hauptstaedteEingabe:
        return SizedBox(
          width: groesse * 1.15,
          height: groesse,
          child: CustomPaint(
            painter: TempelPainter(istGesperrt),
          ),
        );
      case LernModus.waehrungsQuiz:
      case LernModus.waehrungZuLand:
        return _MuenzSticker(istGesperrt: istGesperrt, groesse: groesse);
      case LernModus.sortierSpiel:
        return SizedBox(
          width: groesse,
          height: groesse,
          child: CustomPaint(painter: SortierPainter(istGesperrt)),
        );
      case LernModus.preisSchaetzen:
        return SizedBox(
          width: groesse * 1.15,
          height: groesse,
          child: CustomPaint(painter: PreisSchildPainter(istGesperrt)),
        );
      case LernModus.wirtschaftssektoren:
        return SizedBox(
          width: groesse * 1.15,
          height: groesse,
          child: CustomPaint(painter: FabrikPainter(istGesperrt)),
        );
      case LernModus.umrissBild:
      case LernModus.umrissMultiple:
      case LernModus.umrissEingabe:
      case LernModus.nachbarland:
      case LernModus.grenzkettenRaetsel:
        return SizedBox(
          width: groesse,
          height: groesse,
          child: CustomPaint(painter: UmrissPainter(istGesperrt)),
        );
      case LernModus.bipGesamt:
      case LernModus.flaeche:
        return SizedBox(
          width: groesse * 1.15,
          height: groesse,
          child: CustomPaint(painter: PreisSchildPainter(istGesperrt)),
        );
      case LernModus.extremFrage:
      case LernModus.extremFrageLeicht:
      case LernModus.zufallsFakt:
      case LernModus.bekanntesGebaeude:
        return SizedBox(
          width: groesse,
          height: groesse,
          child: CustomPaint(painter: SortierPainter(istGesperrt)),
        );
    }
  }
}

// ── STICKER 1 — Flagge ────────────────────────────────────────────────────────

class _FlaggenSticker extends StatelessWidget {
  final bool istGesperrt;
  final double groesse;

  const _FlaggenSticker({required this.istGesperrt, required this.groesse});

  @override
  Widget build(BuildContext context) {
    final stockFarbe =
        istGesperrt ? const Color(0xFF9E9C96) : const Color(0xFF5D4037);
    final streifen1 =
        istGesperrt ? const Color(0xFFB0AEA8) : const Color(0xFFE53935);
    final streifen2 =
        istGesperrt ? const Color(0xFFD0CEC8) : Colors.white;
    final streifen3 =
        istGesperrt ? const Color(0xFF9E9C96) : const Color(0xFF1565C0);

    return SizedBox(
      width: groesse * 1.25,
      height: groesse,
      child: Stack(
        children: [
          // Fahnenstock
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 3,
                height: groesse,
                decoration: BoxDecoration(
                  color: stockFarbe,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                      color: const Color(0xFF1a1a1a), width: 1),
                ),
              ),
            ),
          ),
          // Flagge
          Positioned(
            left: 3,
            top: groesse * 0.1,
            child: Container(
              width: groesse * 0.72,
              height: groesse * 0.5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                    color: const Color(0xFF1a1a1a), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(1),
                child: Column(
                  children: [
                    Expanded(child: Container(color: streifen1)),
                    Expanded(child: Container(color: streifen2)),
                    Expanded(child: Container(color: streifen3)),
                  ],
                ),
              ),
            ),
          ),
          // Glanzpunkt
          if (!istGesperrt)
            Positioned(
              left: 5,
              top: groesse * 0.12,
              child: Container(
                width: groesse * 0.18,
                height: groesse * 0.1,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── STICKER 2 — Tempel (Hauptstädte) ─────────────────────────────────────────

class TempelPainter extends CustomPainter {
  final bool istGesperrt;
  const TempelPainter(this.istGesperrt);

  @override
  void paint(Canvas canvas, Size size) {
    final hauptfarbe =
        istGesperrt ? const Color(0xFFB0AEA8) : const Color(0xFFEFEBE9);
    final akzent =
        istGesperrt ? const Color(0xFF9E9C96) : const Color(0xFF5D4037);
    final dach =
        istGesperrt ? const Color(0xFF9E9C96) : const Color(0xFFF9A825);

    final paint = Paint()..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Sockel
    paint.color = akzent;
    canvas.drawRect(
        Rect.fromLTWH(0, size.height - 6, size.width, 6), paint);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height - 6, size.width, 6), outline);

    // Hauptkörper
    paint.color = hauptfarbe;
    canvas.drawRect(
        Rect.fromLTWH(4, 14, size.width - 8, size.height - 20), paint);
    canvas.drawRect(
        Rect.fromLTWH(4, 14, size.width - 8, size.height - 20), outline);

    // Säulen (3 Stück)
    paint.color = akzent.withValues(alpha: 0.4);
    for (int i = 0; i < 3; i++) {
      final x = 7.0 + i * ((size.width - 14) / 3);
      canvas.drawRect(
          Rect.fromLTWH(x, 16, 4, size.height - 22), paint);
    }

    // Dreieckiges Dach
    final dachPfad = Path()
      ..moveTo(0, 14)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, 14)
      ..close();
    paint.color = dach;
    canvas.drawPath(dachPfad, paint);
    canvas.drawPath(dachPfad, outline);

    // Glanz
    if (!istGesperrt) {
      paint.color = Colors.white.withValues(alpha: 0.4);
      canvas.drawRect(Rect.fromLTWH(6, 15, 8, 4), paint);
    }
  }

  @override
  bool shouldRepaint(TempelPainter old) => old.istGesperrt != istGesperrt;
}

// ── STICKER 3 — Münze (Währung) ───────────────────────────────────────────────

class _MuenzSticker extends StatelessWidget {
  final bool istGesperrt;
  final double groesse;

  const _MuenzSticker({required this.istGesperrt, required this.groesse});

  @override
  Widget build(BuildContext context) {
    final muenzFarbe =
        istGesperrt ? const Color(0xFFB0AEA8) : const Color(0xFFF9A825);
    final textFarbe =
        istGesperrt ? const Color(0xFF9E9C96) : const Color(0xFF5D4037);

    return Container(
      width: groesse,
      height: groesse,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: muenzFarbe,
        border: Border.all(color: const Color(0xFF1a1a1a), width: 2.5),
        boxShadow: istGesperrt
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFFC17F00),
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '\$',
            style: TextStyle(
              fontSize: groesse * 0.56,
              fontWeight: FontWeight.w900,
              color: textFarbe,
              height: 1,
            ),
          ),
          if (!istGesperrt)
            Positioned(
              top: groesse * 0.12,
              left: groesse * 0.15,
              child: Container(
                width: groesse * 0.24,
                height: groesse * 0.15,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── STICKER 4 — Sortier-Balken ────────────────────────────────────────────────

class SortierPainter extends CustomPainter {
  final bool istGesperrt;
  const SortierPainter(this.istGesperrt);

  @override
  void paint(Canvas canvas, Size size) {
    final farben = istGesperrt
        ? [
            const Color(0xFFB0AEA8),
            const Color(0xFF9E9C96),
            const Color(0xFFD0CEC8)
          ]
        : [
            const Color(0xFF1565C0),
            const Color(0xFF42A5F5),
            const Color(0xFF90CAF9)
          ];

    final outline = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final hoehen = [size.height * 0.78, size.height * 0.52, size.height * 0.33];
    final balkenBreite = size.width / 3 - 2;

    for (int i = 0; i < 3; i++) {
      final x = i * (balkenBreite + 2) + 1;
      final y = size.height - hoehen[i];

      final paint = Paint()
        ..color = farben[i]
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, balkenBreite, hoehen[i]),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
      canvas.drawRRect(rect, outline);
    }

    // Sortier-Pfeil (oben rechts)
    if (!istGesperrt) {
      final pfeilPaint = Paint()
        ..color = const Color(0xFF1a1a1a)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final r = size.width - 1;
      canvas.drawLine(Offset(r - 7, 4), Offset(r, 11), pfeilPaint);
      canvas.drawLine(Offset(r, 11), Offset(r - 7, 11), pfeilPaint);
      canvas.drawLine(Offset(r, 11), Offset(r, 4), pfeilPaint);
    }
  }

  @override
  bool shouldRepaint(SortierPainter old) => old.istGesperrt != istGesperrt;
}

// ── STICKER 5 — Preisschild ───────────────────────────────────────────────────

class PreisSchildPainter extends CustomPainter {
  final bool istGesperrt;
  const PreisSchildPainter(this.istGesperrt);

  @override
  void paint(Canvas canvas, Size size) {
    final hauptfarbe =
        istGesperrt ? const Color(0xFFD0CEC8) : const Color(0xFFFFF9C4);
    final rand =
        istGesperrt ? const Color(0xFF9E9C96) : const Color(0xFFF57C00);

    final paint = Paint()..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Preisschild-Form (Rechteck mit Spitze rechts)
    final pfad = Path()
      ..moveTo(0, size.height * 0.15)
      ..lineTo(size.width * 0.65, size.height * 0.15)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.65, size.height * 0.85)
      ..lineTo(0, size.height * 0.85)
      ..close();

    paint.color = hauptfarbe;
    canvas.drawPath(pfad, paint);
    paint.color = rand.withValues(alpha: 0.25);
    canvas.drawPath(pfad, paint);
    canvas.drawPath(pfad, outline);

    // Loch links
    paint.color = Colors.white;
    canvas.drawCircle(
        Offset(size.width * 0.12, size.height * 0.5), 3.5, paint);
    final lochOutline = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
        Offset(size.width * 0.12, size.height * 0.5), 3.5, lochOutline);

    // "?" Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          fontSize: size.height * 0.45,
          fontWeight: FontWeight.w900,
          color: istGesperrt ? const Color(0xFF9E9C96) : rand,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(size.width * 0.3, size.height * 0.5 - textPainter.height / 2),
    );

    // Glanzpunkt
    if (!istGesperrt) {
      paint.color = Colors.white.withValues(alpha: 0.5);
      canvas.drawRect(
          Rect.fromLTWH(2, size.height * 0.18, size.width * 0.25, 4), paint);
    }
  }

  @override
  bool shouldRepaint(PreisSchildPainter old) =>
      old.istGesperrt != istGesperrt;
}

// ── STICKER 6 — Fabrik (Wirtschaftssektoren) ─────────────────────────────────

class FabrikPainter extends CustomPainter {
  final bool istGesperrt;
  const FabrikPainter(this.istGesperrt);

  @override
  void paint(Canvas canvas, Size size) {
    final wand =
        istGesperrt ? const Color(0xFFB0AEA8) : const Color(0xFF90A4AE);
    final dach =
        istGesperrt ? const Color(0xFF9E9C96) : const Color(0xFF607D8B);
    final rauch =
        istGesperrt ? const Color(0xFFD0CEC8) : const Color(0xFFCFD8DC);
    final fenster =
        istGesperrt ? const Color(0xFFD0CEC8) : const Color(0xFFF57C00);

    final paint = Paint()..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final body = size.height * 0.45;

    // Fabrik-Körper
    paint.color = wand;
    canvas.drawRect(
        Rect.fromLTWH(2, body, size.width - 4, size.height - body), paint);
    canvas.drawRect(
        Rect.fromLTWH(2, body, size.width - 4, size.height - body), outline);

    // Zickzack-Dach
    final dachPfad = Path()
      ..moveTo(2, body)
      ..lineTo(2, body - 6)
      ..lineTo(10, body)
      ..lineTo(10, body - 6)
      ..lineTo(18, body)
      ..lineTo(18, body - 6)
      ..lineTo(26, body)
      ..lineTo(size.width - 2, body - 6)
      ..lineTo(size.width - 2, body);
    paint.color = dach;
    canvas.drawPath(dachPfad, paint);
    canvas.drawPath(dachPfad, outline);

    // Schornsteine
    for (int i = 0; i < 2; i++) {
      final x = 6.0 + i * 14;
      paint.color = dach;
      canvas.drawRect(Rect.fromLTWH(x, 2, 6, body - 2), paint);
      canvas.drawRect(Rect.fromLTWH(x, 2, 6, body - 2), outline);

      if (!istGesperrt) {
        paint.color = rauch;
        canvas.drawOval(Rect.fromLTWH(x - 1, 0, 6, 4), paint);
      }
    }

    // Fenster
    paint.color = fenster;
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(
          Rect.fromLTWH(4.0 + i * 10, body + 4, 6, 5), paint);
      canvas.drawRect(
          Rect.fromLTWH(4.0 + i * 10, body + 4, 6, 5), outline);
    }
  }

  @override
  bool shouldRepaint(FabrikPainter old) => old.istGesperrt != istGesperrt;
}

// ── STICKER 7 — Schatztruhe (Meilenstein) ────────────────────────────────────

class SchatztruhenPainter extends CustomPainter {
  final bool istGesperrt;
  const SchatztruhenPainter(this.istGesperrt);

  @override
  void paint(Canvas canvas, Size size) {
    final holz =
        istGesperrt ? const Color(0xFFB0AEA8) : const Color(0xFF795548);
    final gold =
        istGesperrt ? const Color(0xFF9E9C96) : const Color(0xFFF9A825);
    final hell =
        istGesperrt ? const Color(0xFFD0CEC8) : const Color(0xFFFFF176);

    final paint = Paint()..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Truhen-Unterteil
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.44, size.width, size.height * 0.56),
      const Radius.circular(3),
    );
    paint.color = holz;
    canvas.drawRRect(rect, paint);
    canvas.drawRRect(rect, outline);

    // Truhen-Deckel
    final deckel = Path()
      ..moveTo(0, size.height * 0.44)
      ..quadraticBezierTo(
          size.width / 2, 0, size.width, size.height * 0.44)
      ..lineTo(0, size.height * 0.44)
      ..close();
    paint.color = holz;
    canvas.drawPath(deckel, paint);

    // Goldstreifen
    paint.color = gold;
    canvas.drawRect(
        Rect.fromLTWH(2, size.height * 0.38, size.width - 4, 4), paint);

    canvas.drawPath(deckel, outline);

    // Goldschloss
    final schloss = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          size.width / 2 - 5, size.height * 0.50, 10, 8),
      const Radius.circular(2),
    );
    paint.color = gold;
    canvas.drawRRect(schloss, paint);
    canvas.drawRRect(schloss, outline);

    // Schloss-Öse
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.44), 3.5, paint);
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.44), 3.5, outline);

    // Glanz
    if (!istGesperrt) {
      paint.color = hell.withValues(alpha: 0.6);
      canvas.drawRect(
          Rect.fromLTWH(3, size.height * 0.47, 8, 3), paint);
    }

    // Holzstreifen
    final holzLinie = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(size.width * 0.22, size.height * 0.44),
        Offset(size.width * 0.22, size.height), holzLinie);
    canvas.drawLine(Offset(size.width * 0.78, size.height * 0.44),
        Offset(size.width * 0.78, size.height), holzLinie);
  }

  @override
  bool shouldRepaint(SchatztruhenPainter old) =>
      old.istGesperrt != istGesperrt;
}

// ── STICKER 8 — Schloss (gesperrte Station) ───────────────────────────────────

class SchlossPainter extends CustomPainter {
  const SchlossPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB0AEA8);
    final outline = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Schloss-Bügel
    final bugelRect =
        Rect.fromLTWH(4, 0, size.width - 8, size.height * 0.55);
    final bugelPaint = Paint()
      ..color = const Color(0xFF9E9C96)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final bugelOutline = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(bugelRect, pi, pi, false, bugelOutline);
    canvas.drawArc(bugelRect, pi, pi, false, bugelPaint);

    // Schloss-Körper
    final koerper = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.38, size.width, size.height * 0.62),
      const Radius.circular(4),
    );
    canvas.drawRRect(koerper, paint);
    canvas.drawRRect(koerper, outline);

    // Schlüsselloch
    paint.color = const Color(0xFF787672);
    canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.63), 4, paint);
    canvas.drawRect(
        Rect.fromLTWH(size.width / 2 - 2.5, size.height * 0.63, 5, 6), paint);
  }

  @override
  bool shouldRepaint(SchlossPainter old) => false;
}

// ── STICKER 9 — Umriss (Ländersilhouette) ────────────────────────────────────

class UmrissPainter extends CustomPainter {
  final bool istGesperrt;
  const UmrissPainter(this.istGesperrt);

  @override
  void paint(Canvas canvas, Size size) {
    final fuell =
        istGesperrt ? const Color(0xFFB0AEA8) : const Color(0xFF42A5F5);
    final rand =
        istGesperrt ? const Color(0xFF9E9C96) : const Color(0xFF1565C0);

    final paint = Paint()
      ..color = fuell
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Stilisierte Ländersilhouette
    final w = size.width;
    final h = size.height;
    final pfad = Path()
      ..moveTo(w * 0.20, h * 0.15)
      ..quadraticBezierTo(w * 0.55, h * 0.05, w * 0.80, h * 0.20)
      ..quadraticBezierTo(w * 1.0, h * 0.35, w * 0.90, h * 0.55)
      ..quadraticBezierTo(w * 0.85, h * 0.80, w * 0.65, h * 0.90)
      ..quadraticBezierTo(w * 0.40, h * 1.0, w * 0.20, h * 0.85)
      ..quadraticBezierTo(w * 0.0, h * 0.70, w * 0.05, h * 0.45)
      ..quadraticBezierTo(w * 0.05, h * 0.25, w * 0.20, h * 0.15)
      ..close();

    canvas.drawPath(pfad, paint);

    // Innere Kontur-Andeutung
    final innerPaint = Paint()
      ..color = rand.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(pfad, innerPaint);
    canvas.drawPath(pfad, outline);

    // Kleiner Punkt (Hauptstadt-Marker)
    if (!istGesperrt) {
      final dotPaint = Paint()
        ..color = const Color(0xFF1565C0)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(w * 0.52, h * 0.48), 2.5, dotPaint);
      canvas.drawCircle(
          Offset(w * 0.52, h * 0.48),
          2.5,
          Paint()
            ..color = const Color(0xFF1a1a1a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);

      // Glanzpunkt
      final glanzPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5);
      canvas.drawRect(
          Rect.fromLTWH(w * 0.22, h * 0.18, w * 0.22, h * 0.1), glanzPaint);
    }
  }

  @override
  bool shouldRepaint(UmrissPainter old) => old.istGesperrt != istGesperrt;
}
