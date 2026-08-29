import 'package:flutter/material.dart';

// ── Der Schätz-Balken ────────────────────────────────────────────────────────
//
// Eine Spur mit einem Griff, einer Skala und — nach dem Bestätigen — der
// sichtbaren Strecke zwischen Tipp und Wahrheit.
//
// HERAUSGELÖST AUS station_quiz_screen.dart, wo er als Rang-Balken für den
// Modus "Länder-Ranking" entstand. Er wird jetzt auch beim grossen Schätzen
// gebraucht, und zwar mit derselben Auflösungs-Animation. Zwei Fassungen
// derselben Mechanik wären zwei Stellen, an denen Griff, Skala und Pflock
// auseinanderlaufen könnten.
//
// Der Unterschied zwischen beiden Verwendungen ist allein die ACHSE: Beim
// Ranking sind es Plätze 1 bis n, beim Schätzen ein stufenloser Wertebereich.
// Deshalb rechnet der Balken hier durchgehend in ANTEILEN von 0 bis 1 — wer
// ihn benutzt, rechnet seine eigene Einheit davor um. Beim Schätzen macht das
// die Skala (SkalaService), die auch schon den Regler bedient; beim Ranking
// ist es eine Division.
//
// Maße: Leitgröße ist die Höhe der Griffscheibe; Spurhöhe, Skalenstriche und
// Abstände sind Anteile davon.

/// Leitgröße: Durchmesser des Griffs. Zugleich die Mindest-Tippfläche in der
/// Höhe — gezogen wird ohnehin auf der ganzen Balkenbreite.
const double kGriffGroesse = 30.0;

/// Höhe der Spur, auf der der Griff läuft.
const double kSpurHoehe = kGriffGroesse * 0.33;

/// Gesamthöhe des Balkenbereichs: Griff plus Platz für die Skalenstriche
/// darunter.
const double kBalkenHoehe = kGriffGroesse * 1.6;

/// Länge der Skalenstriche, kurz und lang.
const double kStrichKurz = kGriffGroesse * 0.17;
const double kStrichLang = kGriffGroesse * 0.32;

const double kGriffRand = 2.5;

const Color kBalkenRahmen = Color(0xFF1A1A1A);
const Color kBalkenSpur = Color(0xFFDDDCD5);
const Color kBalkenStrich = Color(0xFFBFBEB6);
const Color kBalkenGewaehlt = Color(0xFF4A9E4A);
const Color kBalkenEcht = Color(0xFFF9A825);

const Color kBalkenAbstand = Color(0xFFD94040);

/// Dauer der Auflösungs-Fahrt. Gemeinsam für beide Verwendungen, damit sich
/// der Moment in der ganzen App gleich anfühlt.
const Duration kFahrtDauer = Duration(milliseconds: 900);

/// Kurve der Auflösungs-Fahrt: schwingt am Ziel kurz über und federt zurück.
const Curve kFahrtKurve = Curves.easeOutBack;

/// Eine Marke auf der Skala.
///
/// [anteil] von 0 bis 1, [lang] für die betonten Striche — dieselbe
/// Gliederung wie auf einem Lineal.
class BalkenMarke {
  final double anteil;
  final bool lang;

  const BalkenMarke(this.anteil, {this.lang = false});
}

/// Rasterschritt der Skalenstriche auf einer ganzzahligen Achse.
///
/// KEINE Dichte, sondern eine SKALA zur Orientierung: Bei 197 Rangplätzen auf
/// einem 320-px-Schirm läge ein Strich je Platz 1,4 px vom nächsten entfernt —
/// eine graue Fläche ohne Aussage. Der Schritt wächst deshalb mit der
/// Feldgrösse, damit nie mehr als rund 40 Striche entstehen.
int rasterSchritt(int gesamt) {
  for (final s in [1, 2, 5, 10, 20, 25]) {
    if (gesamt / s <= 40) return s;
  }
  return 50;
}

/// Marken für eine ganzzahlige Achse von 1 bis [gesamt] — die Skala des
/// Rang-Balkens.
List<BalkenMarke> markenFuerRaenge(int gesamt) {
  final schritt = rasterSchritt(gesamt);
  final marken = <BalkenMarke>[];
  for (var r = 1; r <= gesamt; r += schritt) {
    final anteil = gesamt <= 1 ? 0.0 : (r - 1) / (gesamt - 1);
    marken.add(BalkenMarke(anteil, lang: ((r - 1) ~/ schritt) % 5 == 0));
  }
  return marken;
}

/// Gleichmässig verteilte Marken für eine stufenlose Achse.
///
/// [abschnitte] Zwischenräume, also [abschnitte] + 1 Striche; jeder fünfte
/// wird lang. Für Skalen, hinter denen keine abzählbaren Stufen stehen — beim
/// Schätzen etwa Einwohnerzahlen oder Prozentwerte.
List<BalkenMarke> markenGleichmaessig(int abschnitte) => [
      for (var i = 0; i <= abschnitte; i++)
        BalkenMarke(i / abschnitte, lang: i % 5 == 0),
    ];

/// Die Spur mit Griff, Skala und Auflösung.
///
/// Der Griff wird über [anteil] von aussen gesetzt, nicht intern gehalten:
/// Nach dem Bestätigen fährt eine Animation ihn auf den echten Wert, und
/// dieselbe Eigenschaft muss dann die Position bestimmen wie vorher der
/// Finger.
class SchaetzBalken extends StatelessWidget {
  /// Aktuelle Position des Griffs, 0 bis 1. Als double, damit die Animation
  /// weich läuft statt in Stufen zu springen.
  final double anteil;

  /// Der abgegebene Tipp. Null, solange nicht bestätigt wurde.
  final double? geraten;

  /// Der echte Wert. Null, solange nicht bestätigt wurde.
  final double? echt;

  /// Die Skalenstriche.
  final List<BalkenMarke> marken;

  /// Null sperrt die Bedienung (nach dem Bestätigen).
  final ValueChanged<double>? onZiehen;

  const SchaetzBalken({
    super.key,
    required this.anteil,
    required this.marken,
    required this.onZiehen,
    this.geraten,
    this.echt,
  });

  /// Anteil an einer Berührungsstelle.
  ///
  /// Die Breite kommt aus dem eigenen RenderBox statt aus einem LayoutBuilder:
  /// Beim Ranking steckt der ganze Fragen-Inhalt in einem IntrinsicHeight, und
  /// ein LayoutBuilder kann dort keine intrinsische Höhe melden — er wirft
  /// "LayoutBuilder does not support returning intrinsic dimensions". Zum
  /// Zeitpunkt einer Berührung ist das Layout ohnehin fertig, die Grösse steht
  /// also fest.
  double _ausX(BuildContext context, double x) {
    final breite = (context.findRenderObject() as RenderBox?)?.size.width ?? 0;
    final rand = kGriffGroesse / 2;
    final nutz = (breite - 2 * rand).clamp(1.0, double.infinity);
    return ((x - rand) / nutz).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Antippen springt hin, Ziehen folgt dem Finger. Beides über dieselbe
      // Umrechnung, damit ein Tipp und ein Zug an derselben Stelle denselben
      // Wert ergeben.
      onTapDown: onZiehen == null
          ? null
          : (d) => onZiehen!(_ausX(context, d.localPosition.dx)),
      onHorizontalDragUpdate: onZiehen == null
          ? null
          : (d) => onZiehen!(_ausX(context, d.localPosition.dx)),
      child: SizedBox(
        height: kBalkenHoehe,
        width: double.infinity,
        child: CustomPaint(
          painter: _BalkenMaler(
            anteil: anteil,
            geraten: geraten,
            echt: echt,
            marken: marken,
          ),
        ),
      ),
    );
  }
}

class _BalkenMaler extends CustomPainter {
  final double anteil;
  final double? geraten;
  final double? echt;
  final List<BalkenMarke> marken;

  _BalkenMaler({
    required this.anteil,
    required this.geraten,
    required this.echt,
    required this.marken,
  });

  /// Bildpunkt eines Anteils. Die Spur lässt links und rechts je einen halben
  /// Griff Rand, damit der Griff an den Enden nicht abgeschnitten wird.
  double _zuX(double a, double breite) {
    final rand = kGriffGroesse / 2;
    return rand + a.clamp(0.0, 1.0) * (breite - 2 * rand);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final mitteY = kGriffGroesse / 2;
    double zuX(double a) => _zuX(a, size.width);
    final links = zuX(0);
    final rechts = zuX(1);

    // ── Spur ────────────────────────────────────────────────────────────
    final spur = Rect.fromLTRB(
        links, mitteY - kSpurHoehe / 2, rechts, mitteY + kSpurHoehe / 2);
    final radius = Radius.circular(kSpurHoehe / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(spur, radius),
      Paint()..color = kBalkenSpur,
    );

    // ── Skala ───────────────────────────────────────────────────────────
    final strich = Paint()
      ..color = kBalkenStrich
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (final m in marken) {
      final x = zuX(m.anteil);
      final laenge = m.lang ? kStrichLang : kStrichKurz;
      canvas.drawLine(
        Offset(x, mitteY + kSpurHoehe / 2 + 3),
        Offset(x, mitteY + kSpurHoehe / 2 + 3 + laenge),
        strich,
      );
    }

    // ── Strecke zwischen Tipp und Wahrheit ──────────────────────────────
    if (geraten != null && echt != null) {
      final a = zuX(geraten!);
      final b = zuX(echt!);
      final von = a < b ? a : b;
      final bis = a < b ? b : a;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
              von, mitteY - kSpurHoehe / 2, bis, mitteY + kSpurHoehe / 2),
          radius,
        ),
        Paint()..color = kBalkenAbstand.withValues(alpha: 0.85),
      );
      // Der abgegebene Tipp bleibt als flacher Pflock stehen, während der
      // Griff weiterwandert — sonst wäre nach der Animation nicht mehr zu
      // sehen, worauf man getippt hatte.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(a, mitteY),
              width: kGriffRand * 2,
              height: kGriffGroesse * 0.7),
          const Radius.circular(2),
        ),
        Paint()..color = kBalkenGewaehlt,
      );
    }

    // ── Griff ───────────────────────────────────────────────────────────
    final gx = zuX(anteil);
    final gefuellt = echt == null ? kBalkenGewaehlt : kBalkenEcht;
    // Harter Schatten ohne Weichzeichnung, wie bei allen Knöpfen der App.
    canvas.drawCircle(
      Offset(gx, mitteY + 3),
      kGriffGroesse / 2,
      Paint()..color = kBalkenRahmen,
    );
    canvas.drawCircle(
      Offset(gx, mitteY),
      kGriffGroesse / 2,
      Paint()..color = kBalkenRahmen,
    );
    canvas.drawCircle(
      Offset(gx, mitteY),
      kGriffGroesse / 2 - kGriffRand,
      Paint()..color = gefuellt,
    );
  }

  @override
  bool shouldRepaint(_BalkenMaler alt) =>
      alt.anteil != anteil ||
      alt.geraten != geraten ||
      alt.echt != echt ||
      alt.marken != marken;
}
