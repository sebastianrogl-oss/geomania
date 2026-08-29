import 'package:flutter/material.dart';

import 'muenze_widget.dart' show kMuenzInhaltFarbe;

/// Der Grabstein für die Ehrenmünze "Urgestein".
///
/// KEINE MÜNZE: Alles Erspielbare ist eine Münze und liegt in der Mappe.
/// Die Ehrung ist etwas anderes — sie wird verliehen, nicht gesammelt — und
/// bekommt deshalb eine eigene Form. Ein Grabstein zu "Urgestein" (englisch
/// "Day One") sagt in einem Bild, worum es geht: Wer ihn hat, war von Anfang
/// an dabei.
///
/// Gezeichnet statt als Bild abgelegt, weil die Form aus zwei Rechtecken und
/// einem Halbkreis besteht — dafür lohnt kein Asset, und gezeichnet skaliert
/// sie ohne Kantenunschärfe von der 66-px-Kachel im Album bis zur grossen
/// Darstellung im Freischalt-Popup.
///
/// Optik nach dem Muster der App: flache Farben, dunkle Outline, kein
/// Verlauf und kein weicher Schatten (siehe die 3D-Knöpfe). Alle Masse sind
/// Anteile von [groesse] — eine Änderung der Grösse zieht Outline, Sockel und
/// Gravur automatisch mit.
class GrabsteinWidget extends StatelessWidget {
  final double groesse;

  /// Schon verliehen? Sonst nur der Umriss, wie bei den gesperrten Münzen.
  final bool erreicht;

  /// Farbe des Umrisses im gesperrten Zustand.
  ///
  /// Voreinstellung ist das Weiss des Albums, das auf dunklem Leder liegt —
  /// dieselbe Regel wie bei [MuenzenWidget.umrissFarbe].
  final Color? umrissFarbe;

  const GrabsteinWidget({
    super.key,
    required this.groesse,
    required this.erreicht,
    this.umrissFarbe,
  });

  /// Wie gross der Stein im Verhältnis zu seinem Layout-Kasten gezeichnet
  /// wird.
  ///
  /// KLEINER ALS SEIN PLATZ, mit Absicht: Neben den runden Münzen der
  /// Sammlung soll die Ehrung etwas zurücktreten statt sich vorzudrängen.
  ///
  /// Der KASTEN bleibt dabei unverändert [groesse] gross — nur der Inhalt
  /// schrumpft. Sonst wanderten im Album Name und Beschreibung unter der
  /// Ehrung nach oben, und die Zelle sässe anders als ihre Nachbarn.
  static const double anteil = 0.64; // 0,8 × 0,8

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: groesse,
      height: groesse,
      child: Center(
        child: SizedBox(
          width: groesse * anteil,
          height: groesse * anteil,
          child: CustomPaint(
            painter: _GrabsteinMaler(
              erreicht: erreicht,
              umrissFarbe: umrissFarbe ?? Colors.white.withValues(alpha: 0.25),
            ),
            child: erreicht
                ? Align(
                    // Die Gravur sitzt in der oberen Hälfte des Steins, nicht
                    // in dessen Mitte: Darunter liegt der Sockel, und ein
                    // mittig gesetztes Zeichen rutschte optisch nach unten.
                    alignment: const Alignment(0, -0.28),
                    child: Icon(
                      Icons.star_rounded,
                      size: groesse * anteil * 0.3,
                      color: kMuenzInhaltFarbe,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Stein, Sockel und Boden — alles aus Anteilen der Kantenlänge.
///
/// Der Stein steht nicht mittig im Quadrat, sondern etwas höher: Unten
/// brauchen Sockel und Boden Platz, sonst stünde der Stein auf der Kante des
/// Kastens.
class _GrabsteinMaler extends CustomPainter {
  final bool erreicht;
  final Color umrissFarbe;

  const _GrabsteinMaler({required this.erreicht, required this.umrissFarbe});

  /// Helles und dunkles Steingrau — zwei flache Töne, kein Verlauf.
  static const _stein = Color(0xFFC6C3BA);
  static const _sockel = Color(0xFF97948B);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final strich = s * 0.055;

    // Masse des Steins, alle als Anteil der Kantenlänge.
    final steinBreite = s * 0.56;
    final steinLinks = (s - steinBreite) / 2;
    final steinOben = s * 0.08;
    final bodenOben = s * 0.90;
    final sockelOben = s * 0.72;
    final sockelBreite = s * 0.80;
    final sockelLinks = (s - sockelBreite) / 2;

    final umriss = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strich
      ..strokeJoin = StrokeJoin.round
      ..color = erreicht ? kMuenzInhaltFarbe : umrissFarbe;

    // Der Stein: unten eckig, oben ein Halbkreis.
    final stein = Path()
      ..moveTo(steinLinks, bodenOben)
      ..lineTo(steinLinks, steinOben + steinBreite / 2)
      ..arcToPoint(
        Offset(steinLinks + steinBreite, steinOben + steinBreite / 2),
        radius: Radius.circular(steinBreite / 2),
      )
      ..lineTo(steinLinks + steinBreite, bodenOben)
      ..close();

    // Der Sockel: die breitere Platte, auf der der Stein steht.
    final sockel = Path()
      ..addRRect(RRect.fromLTRBR(
        sockelLinks,
        sockelOben,
        sockelLinks + sockelBreite,
        bodenOben,
        Radius.circular(s * 0.04),
      ));

    // KEIN Boden unter der Figur. Ein grüner Grasstreifen stand hier
    // zwischenzeitlich und ist wieder raus: Auf dem dunklen Leder der
    // Münzmappe war er ein greller Balken, und im Freischalt-Popup schwebte
    // er ohne Zusammenhang unter dem Stein.
    if (erreicht) {
      canvas.drawPath(stein, Paint()..color = _stein);
      canvas.drawPath(sockel, Paint()..color = _sockel);
    }

    // Umriss zuletzt, damit er über den Flächen liegt. Im gesperrten Zustand
    // ist er das Einzige, was gezeichnet wird — dasselbe Prinzip wie beim
    // gestrichelten Kreis der noch offenen Münzen.
    canvas.drawPath(sockel, umriss);
    canvas.drawPath(stein, umriss);
  }

  @override
  bool shouldRepaint(_GrabsteinMaler o) =>
      o.erreicht != erreicht || o.umrissFarbe != umrissFarbe;
}
