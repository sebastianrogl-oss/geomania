import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/uebersetzungen.dart';
import '../services/rangliste_service.dart';

// Zeigt im Ergebnis-Screen einer Tages-Challenge: eigene Punktzahl, Weltrang/
// Teilnehmerzahl, "X% der Spieler geschlagen" und eine Verteilungskurve mit
// Positions-Marker. Lädt einmalig beim Erscheinen — nutzt AUSSCHLIESSLICH
// RanglisteService.ladeTagesRangliste (Top 100, wird ohnehin für die
// Rangliste geladen) + ladeEigenenPlatzHeute (2 günstige Aggregations-
// Abfragen), keine zusätzlichen Firestore-Abfragen nur für die Kurve.
class RanglisteErgebnisKarte extends StatefulWidget {
  final String challengeId;
  final num eigenerWert;
  final String punkteLabel;
  final Widget punkteAnzeige;
  final Color farbe;
  final String Function(num) formatWert;

  const RanglisteErgebnisKarte({
    super.key,
    required this.challengeId,
    required this.eigenerWert,
    required this.punkteLabel,
    required this.punkteAnzeige,
    this.farbe = const Color(0xFFF9A825),
    this.formatWert = _defaultFormatWert,
  });

  static String _defaultFormatWert(num w) => w.round().toString();

  @override
  State<RanglisteErgebnisKarte> createState() => _RanglisteErgebnisKarteState();
}

class _RanglisteErgebnisKarteState extends State<RanglisteErgebnisKarte> {
  static const _minTeilnehmerFuerKurve = 10;

  List<RanglistenEintrag>? _top100;
  ({int platz, int gesamt})? _platzInfo;
  bool _geladen = false;

  @override
  void initState() {
    super.initState();
    final top100Future = RanglisteService.ladeTagesRangliste(widget.challengeId)
        .timeout(const Duration(seconds: 8), onTimeout: () {
      return <RanglistenEintrag>[];
    });
    final platzFuture = RanglisteService.ladeEigenenPlatzHeute(
            widget.challengeId, widget.eigenerWert)
        .timeout(const Duration(seconds: 8), onTimeout: () {
      return null;
    });
    Future(() async {
      final top100 = await top100Future;
      final platzInfo = await platzFuture;
      if (!mounted) {
        return;
      }
      setState(() {
        _top100 = top100;
        _platzInfo = platzInfo;
        _geladen = true;
      });
    });
  }

  double _prozentGeschlagen(({int platz, int gesamt}) info) =>
      ((info.gesamt - info.platz) / info.gesamt * 100).clamp(0, 100);

  static const _labelStyle = TextStyle(
      fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF888888));
  static const _minMaxStyle = TextStyle(fontSize: 11, color: Color(0xFF888888));

  @override
  Widget build(BuildContext context) {
    if (!_geladen) return const SizedBox.shrink();

    final platzInfo = _platzInfo;
    final top100 = _top100 ?? [];
    final werte = top100.map((e) => e.wert.toDouble()).toList();
    final eigenerWertD = widget.eigenerWert.toDouble();

    var minWert = werte.isEmpty ? eigenerWertD : werte.reduce(min);
    var maxWert = werte.isEmpty ? eigenerWertD : werte.reduce(max);
    minWert = min(minWert, eigenerWertD);
    maxWert = max(maxWert, eigenerWertD);

    final zeigeKurve = platzInfo != null &&
        platzInfo.gesamt >= _minTeilnehmerFuerKurve &&
        werte.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.punkteLabel, style: _labelStyle),
                    const SizedBox(height: 4),
                    widget.punkteAnzeige,
                  ],
                ),
              ),
              if (platzInfo != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(t('Weltweiter Rang'), style: _labelStyle),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '#${platzInfo.platz}',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A)),
                        ),
                        TextSpan(
                          text: ' / ${platzInfo.gesamt}',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB0AEA8)),
                        ),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEAEAE5)),
          const SizedBox(height: 14),
          if (platzInfo == null)
            Text(t('Noch keine Vergleichsdaten heute'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888)))
          else if (!zeigeKurve)
            Text(t('Noch zu wenige Mitspieler für eine Verteilung heute'),
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                    fontStyle: FontStyle.italic))
          else ...[
            Text(
              t('Du hast heute {p}% der Spieler geschlagen!',
                  {'p': _prozentGeschlagen(platzInfo).toStringAsFixed(0)}),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              width: double.infinity,
              child: CustomPaint(
                size: Size.infinite,
                painter: _VerteilungsKurvePainter(
                  werte: werte,
                  eigenerWert: eigenerWertD,
                  minWert: minWert,
                  maxWert: maxWert,
                  farbe: widget.farbe,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.formatWert(minWert), style: _minMaxStyle),
                Text(widget.formatWert(maxWert), style: _minMaxStyle),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Geglättetes Histogramm (12-15 Buckets, gleitender Durchschnitt über 3
// Nachbar-Buckets) der heutigen Ergebniswerte, gefüllte Fläche + gestrichelter
// Positions-Marker für den eigenen Wert.
class _VerteilungsKurvePainter extends CustomPainter {
  final List<double> werte;
  final double eigenerWert;
  final double minWert;
  final double maxWert;
  final Color farbe;

  static const _bucketAnzahl = 14;

  const _VerteilungsKurvePainter({
    required this.werte,
    required this.eigenerWert,
    required this.minWert,
    required this.maxWert,
    required this.farbe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final spanne = (maxWert - minWert).abs() < 0.0001 ? 1.0 : maxWert - minWert;
    final bucketBreite = spanne / _bucketAnzahl;

    final counts = List<double>.filled(_bucketAnzahl, 0);
    for (final w in werte) {
      final idx = (((w - minWert) / bucketBreite).floor()).clamp(0, _bucketAnzahl - 1);
      counts[idx]++;
    }

    final geglaettet = List<double>.generate(_bucketAnzahl, (i) {
      final a = counts[max(0, i - 1)];
      final b = counts[i];
      final c = counts[min(_bucketAnzahl - 1, i + 1)];
      return (a + b + c) / 3;
    });

    final maxHoehe = geglaettet.reduce(max) <= 0 ? 1.0 : geglaettet.reduce(max);
    final baseline = size.height;
    final kurvenPunkte = List<Offset>.generate(_bucketAnzahl, (i) {
      // Volle Breite ausnutzen (erster Punkt bei x=0, letzter bei
      // x=size.width) statt Bucket-Mitten, sonst bleibt an beiden Rändern
      // sichtbarer Leerraum zur Achsen-Beschriftung.
      final x = _bucketAnzahl <= 1 ? 0.0 : (i / (_bucketAnzahl - 1)) * size.width;
      final y = baseline - (geglaettet[i] / maxHoehe) * (size.height - 8);
      return Offset(x, y);
    });

    final kurve = Path()..moveTo(kurvenPunkte.first.dx, kurvenPunkte.first.dy);
    for (var i = 0; i < kurvenPunkte.length - 1; i++) {
      final p0 = kurvenPunkte[i];
      final p1 = kurvenPunkte[i + 1];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      kurve.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    kurve.lineTo(kurvenPunkte.last.dx, kurvenPunkte.last.dy);

    final flaeche = Path.from(kurve)
      ..lineTo(size.width, baseline)
      ..lineTo(0, baseline)
      ..close();

    canvas.drawPath(flaeche, Paint()..color = farbe.withValues(alpha: 0.15));
    canvas.drawPath(
      kurve,
      Paint()
        ..color = farbe
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final markerX = ((eigenerWert - minWert) / spanne).clamp(0.0, 1.0) * size.width;
    final markerY = _kurvenHoeheBei(markerX, kurvenPunkte);

    const dashHoehe = 4.0, dashLuecke = 3.0;
    var y = 0.0;
    final dashPaint = Paint()
      ..color = farbe
      ..strokeWidth = 1.5;
    while (y < markerY) {
      canvas.drawLine(
          Offset(markerX, y), Offset(markerX, min(y + dashHoehe, markerY)), dashPaint);
      y += dashHoehe + dashLuecke;
    }

    canvas.drawCircle(Offset(markerX, markerY), 5, Paint()..color = farbe);
    canvas.drawCircle(
      Offset(markerX, markerY),
      5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  double _kurvenHoeheBei(double x, List<Offset> punkte) {
    if (punkte.length < 2) return punkte.isEmpty ? 0 : punkte.first.dy;
    if (x <= punkte.first.dx) return punkte.first.dy;
    if (x >= punkte.last.dx) return punkte.last.dy;
    for (var i = 0; i < punkte.length - 1; i++) {
      final p0 = punkte[i];
      final p1 = punkte[i + 1];
      if (x >= p0.dx && x <= p1.dx) {
        final t = p1.dx == p0.dx ? 0.0 : (x - p0.dx) / (p1.dx - p0.dx);
        return p0.dy + (p1.dy - p0.dy) * t;
      }
    }
    return punkte.last.dy;
  }

  @override
  bool shouldRepaint(covariant _VerteilungsKurvePainter oldDelegate) =>
      werte != oldDelegate.werte ||
      eigenerWert != oldDelegate.eigenerWert ||
      minWert != oldDelegate.minWert ||
      maxWert != oldDelegate.maxWert ||
      farbe != oldDelegate.farbe;
}
