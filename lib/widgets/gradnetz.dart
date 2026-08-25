import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ── Gradnetz ─────────────────────────────────────────────────────────────────
//
// Der gemeinsame Hintergrund der drei Einstiegs-Screens: Breiten- und
// Längenkreise einer Kugel, in echter orthografischer Projektion gerechnet.
// Die Kugel ist deutlich größer als der Bildschirm, man sieht also nur einen
// Ausschnitt — die Linien krümmen sich dadurch sanft, statt als Globus im Bild
// zu stehen.
//
// WARUM GERECHNET UND NICHT AUS DEN GEO-DATEN: Ein Muster aus echten
// Länderumrissen wäre naheliegend, aber ne_50m_countries.geojson ist 3,1 MB.
// Die Datei zu lesen, zu dekodieren und die Polygone zu vereinfachen dauert
// spürbar — die Schluss-Ansicht macht das bewusst erst NACH dem Bildaufbau.
// Auf dem allerersten Screen, beim Kaltstart, wäre das der falsche Ort. Das
// Gradnetz kostet dagegen nichts: rund 600 Punktberechnungen, keine Datei,
// kein Speicher, und es sitzt in einer RepaintBoundary, wird also nur einmal
// gezeichnet.

/// Farbe der Linien — die Tintenfarbe der App, nicht ein eigenes Grau.
const Color _kLinienFarbe = Color(0xFF1A1A1A);

/// Deckkraft der Linien auf dem Screen-Hintergrund.
///
/// 0.07 statt der zunächst angedachten 0.05: Nachgemessen an einem
/// gerenderten Bild ergeben 5 % auf kHintergrund einen Unterschied von nur
/// 11 Helligkeitsstufen — das verschwindet schon bei mäßigem Umgebungslicht.
/// 7 % ergeben 15 Stufen und bleiben drinnen als Textur wahrnehmbar, ohne
/// sich in den Vordergrund zu drängen.
///
/// In praller Sonne verschwindet auch das. Das ist bewusst hingenommen: Das
/// Netz trägt keine Information, es verliert also nichts, wenn es unsichtbar
/// wird. Deutlich kräftiger zu werden hiesse, aus der Textur ein Bild zu
/// machen — genau das soll sie nicht sein.
const double _kDeckkraft = 0.07;

/// Strichstärke. Mitentscheidend für die Sichtbarkeit: eine 1-px-Haarlinie bei
/// 7 % wirkt schwächer als eine 1,4-px-Linie bei 5 %.
const double _kStrichstaerke = 1.4;

/// Abstand zweier Linien in Grad.
const double _kGradAbstand = 15;

/// Kugelradius als Vielfaches der Bildschirmbreite.
///
/// Bestimmt die Krümmung: Je größer, desto flacher. 1.55 ergibt über die
/// Bildschirmbreite eine Auslenkung von rund 17 px auf einem 412-px-Gerät —
/// erkennbar gebogen, aber ruhig.
const double _kRadiusFaktor = 1.55;

/// Grundneigung des Blicks über den Äquator, in Grad. Ohne Neigung wären die
/// Breitenkreise gerade Linien.
const double _kGrundNeigung = 30;

/// Wie weit sich der Globus je Schritt weiterdreht, in Grad.
///
/// 12 und nicht 15: Bei genau einem Linienabstand (15°) sähe das Netz nach der
/// Drehung exakt gleich aus. 12° verschieben die Längenkreise sichtbar, ohne
/// dass die Textur eine andere wird.
const double _kDrehungProSchritt = 12;

/// Zusätzliche Neigung je Schritt, in Grad. Verschiebt die Breitenkreise —
/// ohne sie bliebe bei reiner Längsdrehung die waagerechte Gliederung starr.
const double _kNeigungProSchritt = 4;

/// Schrittweite beim Abtasten einer Linie, in Grad.
const double _kAbtastung = 2;

/// Der Hintergrund der Einstiegs-Screens: Fläche, Gradnetz, Inhalt.
///
/// [schritt] zählt von 0 an — Anmelden, Name, Willkommen. Er dreht den Globus
/// weiter und gibt dem Einstieg dadurch eine Bewegung, ohne dass etwas
/// animiert wird.
class GradnetzHintergrund extends StatelessWidget {
  final int schritt;
  final Widget child;

  const GradnetzHintergrund({
    super.key,
    required this.child,
    this.schritt = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kHintergrund,
      child: Stack(
        children: [
          // RepaintBoundary: Das Netz ändert sich nie, es soll nicht bei jedem
          // Tastendruck im Namensfeld neu gezeichnet werden.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GradnetzMaler(
                  laengsDrehung: schritt * _kDrehungProSchritt,
                  neigung: _kGrundNeigung + schritt * _kNeigungProSchritt,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GradnetzMaler extends CustomPainter {
  final double laengsDrehung;
  final double neigung;

  const _GradnetzMaler({required this.laengsDrehung, required this.neigung});

  static double _bogen(double grad) => grad * pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = size.width * _kRadiusFaktor;
    final mitteX = size.width / 2;
    final mitteY = size.height / 2;
    final lat0 = _bogen(neigung);
    final lon0 = _bogen(laengsDrehung);

    final stift = Paint()
      ..color = _kLinienFarbe.withValues(alpha: _kDeckkraft)
      ..strokeWidth = _kStrichstaerke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    /// Orthografische Projektion: Punkt der Kugeloberfläche auf die Fläche.
    /// null = liegt auf der abgewandten Seite.
    Offset? aufFlaeche(double lonGrad, double latGrad) {
      final lon = _bogen(lonGrad) - lon0;
      final lat = _bogen(latGrad);
      final sichtbar =
          sin(lat0) * sin(lat) + cos(lat0) * cos(lat) * cos(lon);
      if (sichtbar <= 0) return null;
      final x = radius * cos(lat) * sin(lon);
      final y = radius * (cos(lat0) * sin(lat) - sin(lat0) * cos(lat) * cos(lon));
      return Offset(mitteX + x, mitteY - y);
    }

    // Nur den Bereich abtasten, der überhaupt auf den Schirm fallen kann.
    // Ohne diese Eingrenzung würde für jede Linie die ganze Kugel gerechnet,
    // und das meiste davon läge weit ausserhalb.
    final halbeBreiteGrad =
        asin((size.width / 2 / radius).clamp(0.0, 1.0)) * 180 / pi;
    final halbeHoeheGrad =
        asin((size.height / 2 / radius).clamp(0.0, 1.0)) * 180 / pi;
    final lonSpanne = halbeBreiteGrad * 2.5 + _kGradAbstand;
    final latSpanne = halbeHoeheGrad * 1.6 + _kGradAbstand;

    void linie(Offset? Function(double) punktAn, double von, double bis) {
      final pfad = Path();
      var offen = false;
      for (var t = von; t <= bis; t += _kAbtastung) {
        final p = punktAn(t);
        if (p == null) {
          offen = false;
          continue;
        }
        if (!offen) {
          pfad.moveTo(p.dx, p.dy);
          offen = true;
        } else {
          pfad.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(pfad, stift);
    }

    // Breitenkreise — die waagerechten, zur Mitte hin gekrümmten Linien.
    final latVon = ((neigung - latSpanne) / _kGradAbstand).floor() * _kGradAbstand;
    final latBis = ((neigung + latSpanne) / _kGradAbstand).ceil() * _kGradAbstand;
    for (var lat = latVon; lat <= latBis; lat += _kGradAbstand) {
      if (lat <= -90 || lat >= 90) continue;
      linie((lon) => aufFlaeche(lon, lat), laengsDrehung - lonSpanne,
          laengsDrehung + lonSpanne);
    }

    // Längenkreise — die senkrechten, zu den Polen hin zusammenlaufenden.
    final lonVon =
        ((laengsDrehung - lonSpanne) / _kGradAbstand).floor() * _kGradAbstand;
    final lonBis =
        ((laengsDrehung + lonSpanne) / _kGradAbstand).ceil() * _kGradAbstand;
    for (var lon = lonVon; lon <= lonBis; lon += _kGradAbstand) {
      linie((lat) => aufFlaeche(lon, lat), neigung - latSpanne,
          neigung + latSpanne);
    }
  }

  @override
  bool shouldRepaint(_GradnetzMaler alt) =>
      alt.laengsDrehung != laengsDrehung || alt.neigung != neigung;
}
