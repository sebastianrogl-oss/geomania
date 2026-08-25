import 'package:flutter/material.dart';

import '../l10n/uebersetzungen.dart';
import 'muenze_widget.dart';
import 'streak_flamme.dart';

// ── Maße ─────────────────────────────────────────────────────────────────────
//
// Leitgröße ist die KACHELSEITE. Die drei Kacheln teilen sich die Bildschirm-
// breite, ihre Breite steht damit fest — und weil sie quadratisch sind, ist
// damit auch alles andere festgelegt: Grafik, Zahl und Beschriftung sind
// Anteile dieser einen Größe.
//
// Vorher standen hier absolute Pixelwerte (Flamme 181, Münze 107, Button 82)
// in einer Kachel, die nur rund 88 px breit ist. Die FittedBox darin skalierte
// deshalb jedes Element unterschiedlich stark herunter — Flamme auf 49 %,
// Münze auf 82 %, Button gar nicht. Mit skaliert wurde die Zahl IM Element,
// und obwohl alle drei mit derselben Schriftgröße gesetzt waren, erschienen
// sie in drei verschiedenen Größen (rund 17, 30 und 36 px). Anteile statt
// Pixel schließen das aus: nichts wird mehr nachträglich skaliert.

/// Mindesthöhe der Kachel im Verhältnis zu ihrer Breite. 1.0 = quadratisch.
///
/// MINDEST-, nicht Festhöhe: Die Kachel darf höher werden, wenn die
/// Beschriftung bei grosser Systemschrift mehr Platz braucht — siehe die
/// Höhenrechnung in [_Kachel]. Bei Schriftskala 1.0 ist sie exakt quadratisch.
///
/// Der Hebel, wenn die Grafiken größer werden sollen: in einem Quadrat ist bei
/// rund 70 % der Kachelbreite Schluss, weil Grafik UND Beschriftung
/// hineinpassen müssen. Ein Wert von z. B. 1.6 macht die Kacheln hochkant und
/// die Grafiken entsprechend größer.
const double _kSeitenverhaeltnis = 1.0;

/// Innenabstand der Kachel, als Anteil ihrer Seite.
///
/// Deutlich knapper als zuvor (0.07): Münze und Flamme sind gewachsen, und im
/// Quadrat kann der Platz dafür nur aus Rand, Abstand und Beschriftung kommen.
const double _kInnenrand = 0.005;

/// Grundmaß der sichtbaren Grafikhöhe, als Anteil der Kachelseite.
///
/// Bezugswert der drei Faktoren darunter — alle drei Elemente waren einmal
/// exakt so groß. Die Faktoren machen sichtbar, wie weit jedes seither davon
/// abweicht, statt drei unabhängige Werte nebeneinanderzustellen.
const double _kGrafikGrundmass = 0.70;

/// Der Stationsbutton ist kleiner als die anderen beiden.
const double _kButtonFaktor = 0.80;

/// Die Münze ist größer.
///
/// Gewünscht war 1.5. Mehr als das Grundmaß × 1.16 passt aber nicht in eine
/// quadratische Kachel: die Münze ist ein voller Kreis, sie muss ganz
/// hineinpassen, und über ihr steht noch die Beschriftung. Bei Kachelseite
/// 116 wären 1.5 gleich 122 px — 27 px mehr, als das Grafikfeld hoch ist.
const double _kMuenzFaktor = 1.276; // 1.16 × 1.1

/// Die Flamme ist die größte der drei — sie darf das, weil ihre Leinwand zu
/// gut 40 % aus durchsichtigem Rand besteht.
const double _kFlammeFaktor = 1.008; // 0.84 × 1.2

/// Höhe des Grafikfelds: so hoch wie das größte der drei Elemente, damit die
/// Beschriftungen darunter auf einer Linie stehen.
const double _kGrafikAnteil = _kGrafikGrundmass * _kMuenzFaktor;

/// Anteil ihrer Box, den die Flamme sichtbar ausfüllt.
///
/// Die Lottie-Leinwand ist 300×250, die Grafik darin nimmt rund 71 % ein
/// (aus den Pfad-Koordinaten der Datei ausgemessen). BoxFit.contain in einem
/// Quadrat lässt zusätzlich oben und unten je 1/12 frei: 0.71 × 250/300.
///
/// Die Flammen-Box ist dadurch deutlich größer als ihr Platz in der Kachel —
/// das ist Absicht und stört nicht, weil der Überstand reiner Leerraum ist.
const double _kFlammeSichtbar = 0.59;

/// Wie weit die Flamme nach OBEN gerückt wird, als Anteil ihrer Boxhöhe.
///
/// Die Grafik sitzt in ihrer Leinwand nicht mittig: ausgemessen liegt sie
/// zwischen y=50 und y=227 von 250, ihr Mittelpunkt also 4,5 % der Boxhöhe
/// UNTER der Mitte. Ohne Ausgleich sinkt sie beim Vergrößern weiter ab —
/// dieser Versatz nimmt genau das zurück und hebt sie damit auf die optische
/// Mitte ihres Felds.
const double _kFlammeHoeher = 0.045;

/// Zusätzlicher fester Versatz der Flamme, in Pixeln, positiv = nach oben.
/// Kommt zu dem Ausgleich oben dazu — nicht als Anteil, weil er eine bewusste
/// optische Setzung ist und nicht aus der Grafik folgt.
///
/// Stand kurzzeitig auf 20; damit sass die Flamme zu hoch. Die 10 hier sind
/// die Rücknahme um 10 Pixel nach unten.
///
/// Der Versatz liegt am Transform um die GANZE Flamme — die Zahl steckt in
/// ihr drin und wandert deshalb zwangsläufig mit, bleibt also mittig.
const double _kFlammeVersatz = 7; // 10 minus 3 px nach unten

/// Versatz der Beschriftungen nach oben, in Pixeln. Rein optisch: die Zeile
/// bleibt an ihrem Platz im Layout, sie wird nur höher gezeichnet.
const double _kLabelVersatz = 5;

/// Sockelhöhe des Stationsbuttons, als Anteil seines Durchmessers.
/// Entspricht den 5 px bei 82 px Durchmesser aus dem Lernpfad.
const double _kSockelAnteil = 0.061;

/// Schriftgröße der Zahl, als Anteil des GRUNDMASSES (nicht der jeweiligen
/// Elementgröße): Flamme und Münze zeigen ihre Zahl dadurch weiterhin gleich
/// groß, obwohl die Elemente verschieden groß sind.
///
/// So gewählt, dass auch dreistellige Zahlen (Stationen!) noch ohne
/// Verkleinerung hineinpassen — sonst wären die Zahlen wieder unterschiedlich
/// groß, sobald ein Zähler dreistellig wird.
const double _kZahlAnteil = 0.32; // 0.40 × 0.8

/// Der Stationsbutton macht seine Zahl im selben Maß kleiner wie sich selbst,
/// damit sie nicht plötzlich seinen ganzen Kreis füllt. Seine Zahl ist damit
/// als einzige kleiner als die beiden anderen.
const double _kZahlFaktorButton = 1.0;

/// Breite, die der Zahl im Kreis zur Verfügung steht, als Anteil des
/// Durchmessers.
const double _kZahlBereich = 0.82;

/// Beschriftung unter der Grafik. Knapper als zuvor (0.095 / 0.03 / 1.2) —
/// der Platz geht an Münze und Flamme.
const double _kLabelAnteil = 0.085;
/// Kein eigener Abstand mehr: die Beschriftung wird ohnehin 5 px nach oben
/// gezeichnet, und das Grafikfeld braucht jeden Rest — mit 0.005 lief die
/// Kachel um 0,35 px ueber.
const double _kAbstandGrafikLabel = 0;

/// Zeilenhöhe der Beschriftung, als Vielfaches ihrer Schriftgröße.
/// 1.12 statt 1.15: die gewachsene Muenze braucht das letzte halbe Pixel —
/// ohne das lief die Kachel um 0,35 px ueber. Der Unterlaenge im "g" von
/// "Abzeichen" bleibt genug Raum.
const double _kLabelZeilenhoehe = 1.12;

/// Abstand zwischen zwei Kacheln.
const double _kKachelAbstand = 8;

const _kKachelFarbe = Color(0xFFEAEAE5);
const _kLabelFarbe = Color(0xFF888888);

/// Die drei Statistik-Kacheln im Profil: Streak, Stationen, Abzeichen.
///
/// Jede trägt ihre Zahl in einem eigenen Element — Streak in der Flamme,
/// Stationen im grünen Lernpfad-Button, Abzeichen in der Münze. Es sind
/// dieselben Bauteile, denen man auch sonst in der App begegnet.
class StatistikKacheln extends StatelessWidget {
  final int streak;
  final int stationen;
  final int abzeichen;

  const StatistikKacheln({
    super.key,
    required this.streak,
    required this.stationen,
    required this.abzeichen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Kachel(
            label: t('Streak'),
            grafik: (grundmass, zahl) => _Flamme(
              zahl: streak,
              hoehe: grundmass * _kFlammeFaktor,
              zahlGroesse: zahl,
            ),
          ),
        ),
        const SizedBox(width: _kKachelAbstand),
        Expanded(
          child: _Kachel(
            label: t('Stationen'),
            grafik: (grundmass, zahl) => StatistikStationsButton(
              zahl: stationen,
              durchmesser: grundmass * _kButtonFaktor,
              zahlGroesse: zahl * _kZahlFaktorButton,
            ),
          ),
        ),
        const SizedBox(width: _kKachelAbstand),
        Expanded(
          child: _Kachel(
            label: t('Abzeichen'),
            grafik: (grundmass, zahl) {
              final muenze = grundmass * _kMuenzFaktor;
              return MuenzGrundlage(
                groesse: muenze,
                inhalt: _Zahl(
                  zahl: abzeichen,
                  farbe: kMuenzInhaltFarbe,
                  groesse: zahl,
                  bereich: muenze * _kZahlBereich,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Eine Kachel. Quadratisch (siehe [_kSeitenverhaeltnis]), alles darin ein
/// Anteil ihrer Seite.
class _Kachel extends StatelessWidget {
  final String label;

  /// Bekommt das Grundmaß und die Schriftgröße der Zahl — beide aus der
  /// Kachelseite berechnet und für alle drei Kacheln gleich. Wie weit ein
  /// Element davon abweicht, entscheidet sein Faktor am Dateikopf.
  final Widget Function(double grundmass, double zahlGroesse) grafik;

  const _Kachel({required this.label, required this.grafik});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          final seite = constraints.maxWidth;
          final grundmass = seite * _kGrafikGrundmass;
          // Das Feld ist so hoch wie das größte Element (die Flamme) — nicht
          // so hoch wie das jeweilige. Nur so stehen die Beschriftungen
          // darunter auf einer Linie.
          final feldHoehe = seite * _kGrafikAnteil;
          final zahlGroesse = grundmass * _kZahlAnteil;

          // ── Höhe der Kachel ─────────────────────────────────────────────
          //
          // Quadratisch ist nur der NORMALFALL, nicht das Gesetz. Die Grafik
          // hängt an der Kachelseite und ist damit unabhängig von der
          // Systemschrift; die Beschriftung darunter wächst dagegen mit ihr.
          // Bei Schriftskala 1 blieben nach der letzten Größenanpassung
          // rechnerisch 0,2 px übrig — jede Vergrößerung der Schrift lief
          // deshalb unten aus der Kachel heraus.
          //
          // Statt Grafik oder Beschriftung zu stauchen (beides würde die
          // gewollten Größenverhältnisse zerstören) wächst die Kachel jetzt
          // mit: Sie ist so hoch wie ihre Seite ODER so hoch, wie ihr Inhalt
          // es braucht — je nachdem, was mehr ist. Bei Skala 1.0 bleiben die
          // Kacheln damit exakt quadratisch, darüber werden sie so viel höher
          // wie die Beschriftung an Höhe gewinnt.
          final innen = seite * _kInnenrand;
          final labelStil = TextStyle(
            color: _kLabelFarbe,
            fontSize: seite * _kLabelAnteil,
            fontWeight: FontWeight.w700,
            // Feste Zeilenhöhe, sonst stimmt die Rechnung nicht: die
            // voreingestellte Zeilenhöhe von Poppins ist rund das 1,7-fache
            // der Schriftgröße. 1.12 lässt der Unterlänge im "g" von
            // "Abzeichen" genug Raum.
            height: _kLabelZeilenhoehe,
          );
          // GEMESSEN statt gerechnet. Schriftgröße mal Zeilenhöhe mal
          // Skalierung ist nur eine Näherung — sie lag um rund einen halben
          // Pixel daneben, und genau so viel lief die Kachel dann noch über.
          // Der TextPainter liefert die Höhe, die der Text tatsächlich
          // einnimmt, samt Schriftmetrik und Skalierung.
          final labelHoehe = (TextPainter(
            text: TextSpan(text: label, style: labelStil),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout())
              .height;
          final noetigeHoehe = 2 * innen +
              feldHoehe +
              seite * _kAbstandGrafikLabel +
              labelHoehe;
          final mindestHoehe = seite * _kSeitenverhaeltnis;
          final hoehe =
              noetigeHoehe > mindestHoehe ? noetigeHoehe : mindestHoehe;

          return Container(
            height: hoehe,
            padding: EdgeInsets.all(innen),
            decoration: BoxDecoration(
              color: _kKachelFarbe,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: feldHoehe,
                  child: Center(child: grafik(grundmass, zahlGroesse)),
                ),
                SizedBox(height: seite * _kAbstandGrafikLabel),
                Transform.translate(
                  offset: const Offset(0, -_kLabelVersatz),
                  // DERSELBE Stil, mit dem oben die Höhe gemessen wurde —
                  // sonst rechnet die Kachel mit anderen Werten, als sie
                  // zeichnet.
                  child: Text(label, maxLines: 1, style: labelStil),
                ),
              ],
            ),
          );
        },
    );
  }
}

/// Die Flamme, auf sichtbare Höhe gebracht.
///
/// Ihre Box ist rund 1,7-mal so hoch wie die Flamme darin (siehe
/// [_kFlammeSichtbar]) und ragt damit über den Platz in der Kachel hinaus.
/// Die [OverflowBox] erlaubt genau das: überzustehen kommt nur der
/// durchsichtige Rand der Leinwand, die Flamme selbst bleibt im Feld.
class _Flamme extends StatelessWidget {
  final int zahl;
  final double hoehe;
  final double zahlGroesse;

  const _Flamme({
    required this.zahl,
    required this.hoehe,
    required this.zahlGroesse,
  });

  @override
  Widget build(BuildContext context) {
    final box = hoehe / _kFlammeSichtbar;
    return OverflowBox(
      minWidth: 0,
      minHeight: 0,
      maxWidth: box,
      maxHeight: box,
      // Nach oben, nie nach unten: der Versatz ist negativ und gleicht aus,
      // dass die Grafik in ihrer Leinwand tiefer sitzt als die Mitte. Die
      // Zahl in der Flamme wandert mit, sie gehört zum selben Bild.
      child: Transform.translate(
        offset: Offset(0, -box * _kFlammeHoeher - _kFlammeVersatz),
        child: StreakFlamme(groesse: box, zahl: zahl, zahlGroesse: zahlGroesse),
      ),
    );
  }
}

/// Der grüne Stationsbutton des Lernpfads, hier ohne Druck-Interaktion.
///
/// Optik 1:1 aus home_screen.dart (_FreiBtn / _Druckbar3DBtn): Sockel in
/// #3D8B3D, RadialGradient #5DBB63 → #4A9E4A mit Zentrum (-0.3, -0.3) und
/// Radius 0.8. Der 3D-Eindruck entsteht über den dunkleren Sockel, NICHT über
/// eine Outline oder einen harten Schatten.
class StatistikStationsButton extends StatelessWidget {
  final int zahl;
  final double durchmesser;
  final double zahlGroesse;

  const StatistikStationsButton({
    super.key,
    required this.zahl,
    required this.durchmesser,
    required this.zahlGroesse,
  });

  @override
  Widget build(BuildContext context) {
    final sockel = durchmesser * _kSockelAnteil;
    return SizedBox(
      width: durchmesser,
      height: durchmesser + sockel,
      child: Stack(
        children: [
          Positioned(
            top: sockel,
            left: 0,
            right: 0,
            child: Container(
              width: durchmesser,
              height: durchmesser,
              decoration: const BoxDecoration(
                color: Color(0xFF3D8B3D),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              width: durchmesser,
              height: durchmesser,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF5DBB63), Color(0xFF4A9E4A)],
                  center: Alignment(-0.3, -0.3),
                  radius: 0.8,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _Zahl(
                  zahl: zahl,
                  farbe: Colors.white,
                  groesse: zahlGroesse,
                  bereich: durchmesser * _kZahlBereich,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zahl in einem runden Element (Button, Münze).
///
/// Die scaleDown-FittedBox ist nur noch Notnagel für den Fall, dass ein
/// Zähler vierstellig wird — bei den erwarteten Werten greift sie nicht, und
/// genau darauf beruht, dass alle drei Zahlen gleich groß erscheinen.
class _Zahl extends StatelessWidget {
  final int zahl;
  final Color farbe;
  final double groesse;
  final double bereich;

  const _Zahl({
    required this.zahl,
    required this.farbe,
    required this.groesse,
    required this.bereich,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: bereich,
      height: bereich,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$zahl',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: groesse,
            fontWeight: FontWeight.w900,
            color: farbe,
          ),
        ),
      ),
    );
  }
}
