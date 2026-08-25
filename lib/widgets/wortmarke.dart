import 'package:flutter/material.dart';

// ── Wortmarke ────────────────────────────────────────────────────────────────
//
// "GeoMania" mit Coiny daneben — der einzige Auftritt des Maskottchens im
// ganzen Einstieg, und zwar still statt animiert.
//
// WARUM HIER UND NUR HIER: Der Anmelde-Screen ist der einzige der drei, auf
// dem sich die App vorstellt; Namensauswahl und Willkommen sind Aufgaben.
// Neben dem Namen wird Coiny Teil der Marke statt Dekoration. Auf den beiden
// folgenden Screens fehlt er bewusst — im Spiel selbst ist er ohnehin
// ständig da.

/// Masse der Bilddatei und des tatsächlich sichtbaren Inhalts darin.
///
/// coin_normal.png ist 677x369 gross, die Münze darin aber nur 238x273 —
/// rundum liegt durchsichtiger Rand. Ohne diese Zahlen würde die Bildkante
/// ausgerichtet statt der Münze, und der Abstand zum Schriftzug sähe je nach
/// Grösse anders aus. Ausgemessen über die Alpha-Werte der Datei; wer das
/// Bild austauscht, muss sie neu bestimmen.
const double _kDateiBreite = 677;
const double _kDateiHoehe = 369;
const double _kInhaltX = 220;
const double _kInhaltY = 70;
const double _kInhaltBreite = 238;
const double _kInhaltHoehe = 273;

/// Höhe der sichtbaren Münze als Vielfaches der Versalhöhe des Schriftzugs.
///
/// Etwas grösser als die Versalien: Eine runde Form muss über die Ober- und
/// Unterkante flacher Buchstaben hinausragen, um gleich gross zu WIRKEN — der
/// klassische Ausgleich, den auch jedes "O" gegenüber einem "H" bekommt.
const double _kMuenzeZuVersal = 1.28;

/// Versalhöhe von Poppins als Anteil der Schriftgröße.
const double _kVersalAnteil = 0.70;

/// Abstand zwischen Münze und Schriftzug, als Anteil der Schriftgröße.
const double _kAbstandAnteil = 0.22;

class Wortmarke extends StatelessWidget {
  /// Schriftgröße des Schriftzugs. Alles andere leitet sich daraus ab.
  final double groesse;
  final Color farbe;

  const Wortmarke({
    super.key,
    this.groesse = 32,
    this.farbe = const Color(0xFF1A1A1A),
  });

  @override
  Widget build(BuildContext context) {
    final versal = groesse * _kVersalAnteil;
    final muenzHoehe = versal * _kMuenzeZuVersal;

    // Als GANZES verkleinern, wenn es nicht passt — nie nur die Schrift.
    // Bei grosser Systemschrift ist der Schriftzug auf einem 320-px-Gerät
    // rund 8 px zu breit. Würde allein der Text schrumpfen, veränderte sich
    // das Verhältnis von Münze zu Schriftzug und die Marke sähe auf schmalen
    // Geräten anders aus als auf breiten. Die FittedBox skaliert beides
    // gemeinsam, die Proportionen bleiben also überall gleich.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: _lockup(versal, muenzHoehe),
    );
  }

  Widget _lockup(double versal, double muenzHoehe) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      // An der SCHRIFTLINIE ausrichten, nicht an der Zeilenbox: Die Zeilenbox
      // enthält Platz für Unterlängen und Zeilenabstand, an ihr zentriert
      // säße die Münze sichtbar zu hoch.
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Baseline gibt der Münze eine Schriftlinie: So weit unter ihrer
        // Oberkante, dass ihre Mitte auf der Mitte der Versalhöhe liegt —
        // also optisch mittig zum Schriftzug statt mittig zur Zeile.
        Baseline(
          baseline: muenzHoehe / 2 + versal / 2,
          baselineType: TextBaseline.alphabetic,
          child: _CoinyZeichen(hoehe: muenzHoehe),
        ),
        SizedBox(width: groesse * _kAbstandAnteil),
        Text(
          'GeoMania',
          // Der Name wird NICHT übersetzt — er ist in jeder Sprache derselbe.
          style: TextStyle(
            fontSize: groesse,
            fontWeight: FontWeight.w900,
            color: farbe,
            height: 1.0,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

/// Coiny als stilles Bild, auf die sichtbare Münze zugeschnitten.
///
/// Das Layout-Feld ist genau so gross wie die Münze — der durchsichtige Rand
/// der Datei ragt darüber hinaus, ohne Platz zu belegen. Er muss nicht
/// geklippt werden, weil er nichts zeichnet.
class _CoinyZeichen extends StatelessWidget {
  final double hoehe;
  const _CoinyZeichen({required this.hoehe});

  @override
  Widget build(BuildContext context) {
    final massstab = hoehe / _kInhaltHoehe;
    final vollHoehe = _kDateiHoehe * massstab;
    final vollBreite = _kDateiBreite * massstab;

    return SizedBox(
      width: _kInhaltBreite * massstab,
      height: hoehe,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.translate(
          offset: Offset(-_kInhaltX * massstab, -_kInhaltY * massstab),
          child: SizedBox(
            width: vollBreite,
            height: vollHoehe,
            child: Image.asset(
              'assets/icons/deko/coin_normal.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
