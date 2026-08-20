import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class KontinentHintergrund extends StatefulWidget {
  final String kontinentId;
  final Widget child;

  const KontinentHintergrund({
    super.key,
    required this.kontinentId,
    required this.child,
  });

  @override
  State<KontinentHintergrund> createState() =>
      _KontinentHintergrundState();
}

class _KontinentHintergrundState
    extends State<KontinentHintergrund>
    with TickerProviderStateMixin {
  late AnimationController _bewegungsController;
  late AnimationController _veraenderungsController;
  late Animation<double> _bewegung;
  late Animation<double> _veraenderung;

  @override
  void initState() {
    super.initState();

    _bewegungsController = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();

    _bewegung = Tween<double>(begin: 0.0, end: 1.0)
        .animate(_bewegungsController);

    _veraenderungsController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    _veraenderung = CurvedAnimation(
      parent: _veraenderungsController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _bewegungsController.dispose();
    _veraenderungsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _getGradient(widget.kontinentId),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: Listenable.merge([_bewegung, _veraenderung]),
          builder: (context, child) {
            return RepaintBoundary(
              child: CustomPaint(
                painter: KontinentMusterPainter(
                  kontinentId: widget.kontinentId,
                  bewegungsOffset: _bewegung.value,
                  veraenderung: _veraenderung.value,
                ),
                size: Size.infinite,
              ),
            );
          },
        ),
        widget.child,
      ],
    );
  }

  List<Color> _getGradient(String id) {
    switch (id) {
      case 'europa':
        return [const Color(0xFFF0F4FF), kHintergrund];
      case 'suedamerika':
        return [const Color(0xFFF0FFF4), kHintergrund];
      case 'nordamerika':
        return [const Color(0xFFFFF8F0), kHintergrund];
      case 'afrika':
        return [const Color(0xFFFFF9F0), kHintergrund];
      case 'asien':
        return [const Color(0xFFF0F0FF), kHintergrund];
      case 'ozeanien':
        return [const Color(0xFFF0FFFE), kHintergrund];
      case 'welt':
        return [const Color(0xFFF0F2FF), kHintergrund];
      default:
        return [kHintergrund, kHintergrund];
    }
  }
}

class KontinentMusterPainter extends CustomPainter {
  final String kontinentId;
  final double bewegungsOffset;
  final double veraenderung;

  const KontinentMusterPainter({
    required this.kontinentId,
    required this.bewegungsOffset,
    required this.veraenderung,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (kontinentId) {
      case 'europa':
        _zeichneKopfsteinpflaster(canvas, size);
      case 'suedamerika':
        _zeichneDschungel(canvas, size);
      case 'nordamerika':
        _zeichneCanyon(canvas, size);
      case 'afrika':
        _zeichneSavanne(canvas, size);
      case 'asien':
        _zeichneBerge(canvas, size);
      case 'ozeanien':
        _zeichneWellen(canvas, size);
      case 'welt':
        _zeichneSchwebendeWelt(canvas, size);
    }
  }

  @override
  bool shouldRepaint(KontinentMusterPainter old) {
    return old.bewegungsOffset != bewegungsOffset ||
        old.veraenderung != veraenderung ||
        old.kontinentId != kontinentId;
  }

  // ── EUROPA — Kopfsteinpflaster gleitet nach unten ───────────────────────────
  void _zeichneKopfsteinpflaster(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9B8EA0).withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double steinGroesse = 28;
    const double abstand = 3;
    final double aktuelleGroesse = steinGroesse * (0.9 + veraenderung * 0.2);
    final double verschiebeY = bewegungsOffset * (steinGroesse + abstand);

    int reihe = 0;
    for (double y = -steinGroesse + verschiebeY;
        y < size.height + steinGroesse;
        y += steinGroesse + abstand, reihe++) {
      final versatz = reihe.isEven ? 0.0 : aktuelleGroesse / 2;

      for (double x = -versatz;
          x < size.width + aktuelleGroesse;
          x += aktuelleGroesse + abstand) {
        final breite = aktuelleGroesse * 0.85;
        final hoehe = aktuelleGroesse * 0.75;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, breite, hoehe), const Radius.circular(3)),
          paint,
        );
      }
    }
  }

  // ── SÜDAMERIKA — Dschungel schwankt im Wind ─────────────────────────────────
  void _zeichneDschungel(Canvas canvas, Size size) {
    final bodenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1B5E20).withValues(alpha: 0.00),
          const Color(0xFF1B5E20).withValues(alpha: 0.08),
        ],
      ).createShader(
          Rect.fromLTWH(0, size.height * 0.75, size.width, size.height * 0.25));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.75, size.width, size.height * 0.25),
      bodenPaint,
    );

    final grasPaint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (double x = 0; x < size.width; x += 8) {
      final hoeheVarianz =
          15.0 + (sin(x * 0.7) * 5 + cos(x * 0.3) * 5).abs();
      final schwing = sin(bewegungsOffset * 2 * pi + x * 0.05) *
          (3.0 + veraenderung * 4.0);
      canvas.drawPath(
        Path()
          ..moveTo(x, size.height)
          ..quadraticBezierTo(
            x + schwing * 0.5,
            size.height - hoeheVarianz * 0.6,
            x + schwing,
            size.height - hoeheVarianz,
          ),
        grasPaint,
      );
    }

    final blattPaint = Paint()
      ..color = const Color(0xFF33691E).withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final leftYFactors = [0.10, 0.22, 0.34, 0.46, 0.58, 0.70, 0.82];
    for (int i = 0; i < leftYFactors.length; i++) {
      final y = size.height * leftYFactors[i];
      final schwing =
          sin(bewegungsOffset * 2 * pi + i * 0.8) * (2.0 + veraenderung * 3.0);
      canvas.drawPath(
        Path()
          ..moveTo(0, y)
          ..quadraticBezierTo(
              40 + schwing, y - 30 - schwing * 0.5, 55, y - 10),
        blattPaint,
      );
    }

    final rightYFactors = [0.15, 0.27, 0.40, 0.52, 0.64, 0.76];
    for (int i = 0; i < rightYFactors.length; i++) {
      final y = size.height * rightYFactors[i];
      final schwing = sin(bewegungsOffset * 2 * pi + i * 0.9 + pi) *
          (2.0 + veraenderung * 3.0);
      canvas.drawPath(
        Path()
          ..moveTo(size.width, y)
          ..quadraticBezierTo(size.width - 40 - schwing,
              y - 30 - schwing * 0.5, size.width - 55, y - 10),
        blattPaint,
      );
    }

    final tropfenPaint = Paint()
      ..color = const Color(0xFF0288D1).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const tropfenBasis = [
      [0.12, 0.06], [0.38, 0.04], [0.62, 0.11], [0.85, 0.07],
      [0.25, 0.18], [0.55, 0.14], [0.78, 0.22], [0.08, 0.30],
      [0.45, 0.26], [0.70, 0.33], [0.92, 0.19], [0.30, 0.38],
    ];
    for (final t in tropfenBasis) {
      final basisY = size.height * t[1];
      final tropfY = (basisY + bewegungsOffset * size.height) % size.height;
      canvas.drawCircle(
        Offset(size.width * t[0], tropfY),
        2.0,
        tropfenPaint,
      );
    }
  }

  // ── NORDAMERIKA — Canyon-Schichten verschieben sich horizontal ───────────────
  void _zeichneCanyon(Canvas canvas, Size size) {
    final schicht1Versatz = bewegungsOffset * size.width * 0.05;
    final schicht2Versatz = bewegungsOffset * size.width * 0.08;
    final schicht3Versatz = bewegungsOffset * size.width * 0.12;

    _zeichneSchicht(canvas, size, 0.35,
        const Color(0xFFFF7043).withValues(alpha: 0.04), schicht1Versatz);
    _zeichneSchicht(canvas, size, 0.25,
        const Color(0xFFE64A19).withValues(alpha: 0.05), schicht2Versatz);
    _zeichneSchicht(canvas, size, 0.15,
        const Color(0xFFBF360C).withValues(alpha: 0.07), schicht3Versatz);

    final kaktusPaint = Paint()
      ..color = const Color(0xFF33691E).withValues(alpha: 0.07)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final kakteeSchwing =
        sin(bewegungsOffset * 2 * pi) * (2.0 + veraenderung * 2.0);

    _zeichneKaktus(
        canvas,
        Offset(size.width * 0.82 + kakteeSchwing, size.height * 0.72),
        kaktusPaint,
        50.0);
    _zeichneKaktus(
        canvas,
        Offset(size.width * 0.93 + kakteeSchwing * 0.8, size.height * 0.80),
        kaktusPaint,
        38.0);
    _zeichneKaktus(
        canvas,
        Offset(size.width * 0.73 + kakteeSchwing * 1.2, size.height * 0.78),
        kaktusPaint,
        34.0);
  }

  void _zeichneSchicht(
      Canvas canvas, Size size, double yStart, Color farbe, double versatz) {
    canvas.save();
    canvas.translate(versatz, 0);

    final paint = Paint()
      ..color = farbe
      ..style = PaintingStyle.fill;

    final pfad = Path()..moveTo(-80, size.height);
    double x = -80;
    final double y = size.height * yStart;
    pfad.lineTo(-80, y);

    while (x < size.width + 30) {
      final zackeHoehe = 8.0 + sin(x * 0.1) * 6;
      pfad.quadraticBezierTo(
          x + 15, y - zackeHoehe, x + 30, y + sin(x * 0.05) * 4);
      x += 30;
    }

    pfad.lineTo(x, size.height);
    pfad.close();
    canvas.drawPath(pfad, paint);
    canvas.restore();
  }

  void _zeichneKaktus(Canvas canvas, Offset pos, Paint paint, double hoehe) {
    canvas.drawLine(pos, Offset(pos.dx, pos.dy - hoehe), paint);
    final armL = pos.dy - hoehe * 0.55;
    canvas.drawLine(
        Offset(pos.dx, armL), Offset(pos.dx - 15, armL - 18), paint);
    canvas.drawLine(
        Offset(pos.dx - 15, armL - 18), Offset(pos.dx - 15, armL - 6), paint);
    final armR = pos.dy - hoehe * 0.38;
    canvas.drawLine(
        Offset(pos.dx, armR), Offset(pos.dx + 13, armR - 15), paint);
    canvas.drawLine(
        Offset(pos.dx + 13, armR - 15), Offset(pos.dx + 13, armR - 5), paint);
  }

  // ── AFRIKA — Gras weht im Wind ───────────────────────────────────────────────
  void _zeichneSavanne(Canvas canvas, Size size) {
    final bodenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE65100).withValues(alpha: 0.00),
          const Color(0xFFBF360C).withValues(alpha: 0.06),
        ],
      ).createShader(
          Rect.fromLTWH(0, size.height * 0.80, size.width, size.height * 0.20));
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.80, size.width, size.height * 0.20),
      bodenPaint,
    );

    final horizPaint = Paint()
      ..color = const Color(0xFFE65100).withValues(alpha: 0.06)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final horizY = size.height * 0.75;
    final horizPfad = Path()..moveTo(0, horizY);
    for (double x = 0; x < size.width; x += 40) {
      horizPfad.quadraticBezierTo(x + 20, horizY + 2, x + 40, horizY);
    }
    canvas.drawPath(horizPfad, horizPaint);

    final kroneSchwang =
        sin(bewegungsOffset * 2 * pi) * (3.0 + veraenderung * 2.0);
    _zeichneAkazie(
        canvas,
        Offset(size.width * 0.15, size.height * 0.75),
        kroneSchwang);
    _zeichneAkazie(
        canvas,
        Offset(size.width * 0.70, size.height * 0.72),
        kroneSchwang * 0.8);
    _zeichneAkazie(
        canvas,
        Offset(size.width * 0.90, size.height * 0.78),
        kroneSchwang * 1.1);

    final grasPaint = Paint()
      ..color = const Color(0xFFF57F17).withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (double x = 3; x < size.width; x += 5) {
      final basis = size.height * 0.75 + (sin(x * 0.6) * 5).abs();
      final hoehe = 12.0 + (cos(x * 0.4) * 4).abs();
      final windStaerke = sin(bewegungsOffset * 2 * pi + x * 0.03) *
          (4.0 + veraenderung * 6.0);
      canvas.drawPath(
        Path()
          ..moveTo(x, basis)
          ..quadraticBezierTo(
            x + windStaerke * 0.5,
            basis - hoehe * 0.5,
            x + windStaerke,
            basis - hoehe,
          ),
        grasPaint,
      );
    }
  }

  void _zeichneAkazie(Canvas canvas, Offset position, double kroneSchwang) {
    final strichPaint = Paint()
      ..color = const Color(0xFF4E342E).withValues(alpha: 0.07)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
        position, Offset(position.dx, position.dy - 35), strichPaint);
    canvas.drawLine(
      Offset(position.dx, position.dy - 28),
      Offset(position.dx - 15, position.dy - 43),
      strichPaint,
    );
    canvas.drawLine(
      Offset(position.dx, position.dy - 28),
      Offset(position.dx + 15, position.dy - 43),
      strichPaint,
    );

    final kronePaint = Paint()
      ..color = const Color(0xFF4E342E).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(position.dx + kroneSchwang, position.dy - 50),
          width: 55,
          height: 18),
      kronePaint,
    );
  }

  // ── ASIEN — Wolken ziehen, Berge atmen, Bambus schwankt ─────────────────────
  void _zeichneBerge(Canvas canvas, Size size) {
    final bergAtmen = sin(veraenderung * pi) * 3.0;

    _zeichneBerg(
      canvas, size,
      spitzeX: size.width * 0.50,
      spitzeY: size.height * 0.15 - bergAtmen * 0.5,
      basisLinks: 0,
      basisRechts: size.width,
      basisY: size.height * 0.60,
      farbe: const Color(0xFF7986CB).withValues(alpha: 0.05),
      mitSchnee: false,
    );
    _zeichneBerg(
      canvas, size,
      spitzeX: size.width * 0.28,
      spitzeY: size.height * 0.25 - bergAtmen * 0.4,
      basisLinks: 0,
      basisRechts: size.width * 0.70,
      basisY: size.height * 0.65,
      farbe: const Color(0xFF5C6BC0).withValues(alpha: 0.06),
      mitSchnee: false,
    );
    _zeichneBerg(
      canvas, size,
      spitzeX: size.width * 0.72,
      spitzeY: size.height * 0.20 - bergAtmen,
      basisLinks: size.width * 0.40,
      basisRechts: size.width,
      basisY: size.height * 0.68,
      farbe: const Color(0xFF3949AB).withValues(alpha: 0.07),
      mitSchnee: true,
    );

    final wolke1X =
        (bewegungsOffset * size.width * 1.2) % (size.width + 100) - 50;
    final wolke2X =
        ((bewegungsOffset + 0.4) * size.width * 0.8) % (size.width + 80) - 40;
    final wolke3X =
        ((bewegungsOffset + 0.7) * size.width * 0.9) % (size.width + 60) - 30;

    _zeichneWolke(canvas, Offset(wolke1X, size.height * 0.10), 28);
    _zeichneWolke(canvas, Offset(wolke2X, size.height * 0.07), 36);
    _zeichneWolke(canvas, Offset(wolke3X, size.height * 0.16), 22);

    final bambusWind =
        sin(bewegungsOffset * 2 * pi) * (2.0 + veraenderung * 3.0);
    final bambusPaint = Paint()
      ..color = const Color(0xFF33691E).withValues(alpha: 0.05)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final x in [5.0, 11.0, 17.0, 23.0]) {
      final schwingX = bambusWind * (x / 23.0);
      canvas.drawLine(
          Offset(x, size.height), Offset(x + schwingX, 0), bambusPaint);
      for (double y = 30; y < size.height; y += 45) {
        canvas.drawLine(Offset(x - 2, y), Offset(x + 2, y), bambusPaint);
      }
    }
  }

  void _zeichneBerg(
    Canvas canvas,
    Size size, {
    required double spitzeX,
    required double spitzeY,
    required double basisLinks,
    required double basisRechts,
    required double basisY,
    required Color farbe,
    required bool mitSchnee,
  }) {
    final paint = Paint()
      ..color = farbe
      ..style = PaintingStyle.fill;
    final pfad = Path()
      ..moveTo(basisLinks, basisY)
      ..quadraticBezierTo(spitzeX - 30, spitzeY + 25, spitzeX, spitzeY)
      ..quadraticBezierTo(spitzeX + 30, spitzeY + 25, basisRechts, basisY)
      ..close();
    canvas.drawPath(pfad, paint);

    if (mitSchnee) {
      final bergHoehe = basisY - spitzeY;
      final schneePaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawPath(
        Path()
          ..moveTo(spitzeX, spitzeY)
          ..lineTo(spitzeX - 18, spitzeY + bergHoehe * 0.15)
          ..lineTo(spitzeX + 18, spitzeY + bergHoehe * 0.15)
          ..close(),
        schneePaint,
      );
    }
  }

  void _zeichneWolke(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.60, paint);
    canvas.drawCircle(
        Offset(center.dx + radius * 0.52, center.dy + 4), radius * 0.44, paint);
    canvas.drawCircle(
        Offset(center.dx - radius * 0.50, center.dy + 5), radius * 0.40, paint);
    canvas.drawCircle(
        Offset(center.dx + radius * 0.90, center.dy + 8), radius * 0.33, paint);
  }

  // ── OZEANIEN — Wellen rollen von rechts nach links ───────────────────────────
  void _zeichneWellen(Canvas canvas, Size size) {
    final wellenHoehe = 6.0 + veraenderung * 5.0;
    final schaumOpacity = 0.03 + veraenderung * 0.04;
    final welleVersatz = bewegungsOffset * 80;

    final paint = Paint()
      ..color = const Color(0xFF0288D1).withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final schaumPaint = Paint()
      ..color = const Color(0xFF0288D1).withValues(alpha: schaumOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (double y = 20; y < size.height; y += 35) {
      final pfad = Path()..moveTo(-welleVersatz, y);
      double x = -welleVersatz;
      bool oben = true;
      while (x < size.width + 80) {
        pfad.quadraticBezierTo(
          x + 20, oben ? y - wellenHoehe : y + wellenHoehe, x + 40, y);
        x += 40;
        oben = !oben;
      }
      canvas.drawPath(pfad, paint);

      for (double sx = 10 - welleVersatz; sx < size.width + 80; sx += 40) {
        canvas.drawPath(
          Path()
            ..moveTo(sx, y - 6)
            ..quadraticBezierTo(sx + 8, y - 10, sx + 16, y - 6),
          schaumPaint,
        );
      }
    }
  }

  // ── DIE WELT — Schwebende Kontinente ─────────────────────────────────────────
  void _zeichneSchwebendeWelt(Canvas canvas, Size size) {
    // [xFaktor, yFaktor, groesse, drehung, geschwindigkeit]
    final kontinente = [
      [0.15, 0.25, 0.20, 0.1,  1.0],  // Nordamerika
      [0.25, 0.60, 0.14, -0.1, 0.8],  // Südamerika
      [0.52, 0.22, 0.12, 0.05, 1.2],  // Europa
      [0.55, 0.55, 0.18, -0.05, 0.9], // Afrika
      [0.72, 0.28, 0.22, 0.08, 0.7],  // Asien
      [0.82, 0.65, 0.12, -0.08, 1.1], // Ozeanien
    ];

    for (int i = 0; i < kontinente.length; i++) {
      final k = kontinente[i];
      final basisX = size.width * k[0];
      final basisY = size.height * k[1];
      final groesse = size.width * k[2];
      final geschw = k[4];

      final schwebeX =
          sin(bewegungsOffset * 2 * pi * geschw + k[0] * 5) * 8.0;
      final schwebeY =
          cos(bewegungsOffset * 2 * pi * geschw + k[1] * 3) * 5.0;

      canvas.save();
      canvas.translate(basisX + schwebeX, basisY + schwebeY);
      canvas.rotate(k[3] + sin(veraenderung * pi) * 0.02);

      final paint = Paint()
        ..color = const Color(0xFF1565C0)
            .withValues(alpha: 0.05 + veraenderung * 0.03)
        ..style = PaintingStyle.fill;
      final randPaint = Paint()
        ..color = const Color(0xFF1565C0).withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final pfad = _getKontinentForm(i, groesse);
      canvas.drawPath(pfad, paint);
      canvas.drawPath(pfad, randPaint);
      canvas.restore();
    }

    // Sterne funkeln
    final sternPaint = Paint()..style = PaintingStyle.fill;
    final rng = Random(42);
    for (int i = 0; i < 50; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height * 0.6;
      final funkel = (sin(veraenderung * pi * 2 + i * 0.7) + 1) / 2;
      sternPaint.color =
          const Color(0xFF1565C0).withValues(alpha: 0.04 + funkel * 0.06);
      final radius = 0.8 + rng.nextDouble() * 1.5;
      canvas.drawCircle(Offset(sx, sy), radius, sternPaint);
    }

    // Verbindungslinien — Helligkeit pulsiert
    final liniePaint = Paint()
      ..color = const Color(0xFF1565C0)
          .withValues(alpha: 0.02 + veraenderung * 0.03)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // Europa → Nordamerika
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.52, size.height * 0.22)
        ..quadraticBezierTo(size.width * 0.35, size.height * 0.10,
            size.width * 0.15, size.height * 0.25),
      liniePaint,
    );
    // Europa → Asien
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.58, size.height * 0.25)
        ..quadraticBezierTo(size.width * 0.65, size.height * 0.18,
            size.width * 0.72, size.height * 0.28),
      liniePaint,
    );
    // Afrika → Südamerika
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.52, size.height * 0.60)
        ..quadraticBezierTo(size.width * 0.38, size.height * 0.65,
            size.width * 0.25, size.height * 0.60),
      liniePaint,
    );
  }

  Path _getKontinentForm(int index, double groesse) {
    switch (index) {
      case 0: // Nordamerika
        return Path()
          ..moveTo(0, -groesse * 0.3)
          ..quadraticBezierTo(
              groesse * 0.4, -groesse * 0.5, groesse * 0.5, 0)
          ..quadraticBezierTo(
              groesse * 0.3, groesse * 0.5, 0, groesse * 0.4)
          ..quadraticBezierTo(
              -groesse * 0.3, groesse * 0.2, -groesse * 0.2, -groesse * 0.1)
          ..quadraticBezierTo(
              -groesse * 0.1, -groesse * 0.3, 0, -groesse * 0.3)
          ..close();
      case 1: // Südamerika
        return Path()
          ..moveTo(-groesse * 0.2, -groesse * 0.4)
          ..quadraticBezierTo(
              groesse * 0.3, -groesse * 0.4, groesse * 0.3, 0)
          ..quadraticBezierTo(
              groesse * 0.2, groesse * 0.5, 0, groesse * 0.5)
          ..quadraticBezierTo(
              -groesse * 0.3, groesse * 0.3, -groesse * 0.2, -groesse * 0.2)
          ..quadraticBezierTo(
              -groesse * 0.3, -groesse * 0.4, -groesse * 0.2, -groesse * 0.4)
          ..close();
      case 2: // Europa
        return Path()
          ..moveTo(-groesse * 0.3, -groesse * 0.2)
          ..quadraticBezierTo(
              groesse * 0.1, -groesse * 0.4, groesse * 0.4, -groesse * 0.1)
          ..quadraticBezierTo(
              groesse * 0.3, groesse * 0.3, 0, groesse * 0.2)
          ..quadraticBezierTo(
              -groesse * 0.2, groesse * 0.3, -groesse * 0.3, 0)
          ..quadraticBezierTo(
              -groesse * 0.4, -groesse * 0.1, -groesse * 0.3, -groesse * 0.2)
          ..close();
      case 3: // Afrika
        return Path()
          ..moveTo(-groesse * 0.2, -groesse * 0.5)
          ..quadraticBezierTo(
              groesse * 0.3, -groesse * 0.5, groesse * 0.3, -groesse * 0.1)
          ..quadraticBezierTo(
              groesse * 0.3, groesse * 0.3, 0, groesse * 0.5)
          ..quadraticBezierTo(
              -groesse * 0.3, groesse * 0.3, -groesse * 0.3, -groesse * 0.1)
          ..quadraticBezierTo(
              -groesse * 0.3, -groesse * 0.3, -groesse * 0.2, -groesse * 0.5)
          ..close();
      case 4: // Asien
        return Path()
          ..moveTo(-groesse * 0.5, -groesse * 0.2)
          ..quadraticBezierTo(
              0, -groesse * 0.5, groesse * 0.5, -groesse * 0.3)
          ..quadraticBezierTo(
              groesse * 0.6, groesse * 0.1, groesse * 0.3, groesse * 0.4)
          ..quadraticBezierTo(
              0, groesse * 0.3, -groesse * 0.3, groesse * 0.3)
          ..quadraticBezierTo(
              -groesse * 0.6, 0, -groesse * 0.5, -groesse * 0.2)
          ..close();
      default: // Ozeanien
        return Path()
          ..addOval(Rect.fromCenter(
            center: Offset.zero,
            width: groesse,
            height: groesse * 0.7,
          ));
    }
  }
}
