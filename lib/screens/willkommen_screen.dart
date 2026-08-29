import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/lernpfad_data.dart';
import '../l10n/uebersetzungen.dart';
import '../theme/app_theme.dart';
import '../widgets/antwort_button.dart';
import '../widgets/challenge_kachel.dart';
import '../widgets/ergebnis_karten.dart';
import '../widgets/flaggen_widget.dart';
import '../widgets/kontinent_hintergrund.dart';
import '../widgets/gradnetz.dart';
import '../widgets/lernpfad_station_button.dart';
import '../widgets/streak_flamme.dart';

// ── Willkommen ───────────────────────────────────────────────────────────────
//
// Fünf wischbare Karten, gezeigt nach der Namensabfrage und vor dem ersten
// Blick auf den Lernpfad.
//
// JEDE KARTE ZEIGT EIN ECHTES BAUTEIL DER APP, keine eigens gezeichnete
// Illustration: das Flaggenband, den Stationsbutton des Lernpfads, dessen
// Modus-Symbole, Flamme und Münze, die Sinnbilder der Tages-Challenges. Wer
// die Karten gesehen hat, erkennt die Teile später wieder, statt sie zweimal
// lernen zu müssen.
//
// DER HINTERGRUND MUSS BEIM WISCHEN RUHIG BLEIBEN. Zwei Vorkehrungen dafür:
//
//  * Der PageView sitzt in einem Expanded und gibt jeder Seite denselben
//    Kasten. Wie viel Inhalt in einer Karte steht, kann die Höhe der Fläche
//    also nicht beeinflussen.
//  * Die Karte selbst hat width: double.infinity. Ohne das schrumpfte der
//    Stack in GradnetzHintergrund auf die Inhaltsbreite und der ganze Screen
//    spränge seitlich — derselbe Fehler, der beim Anmelde-Screen 41,75 px
//    Versatz erzeugte (siehe den Kommentar am Stack in gradnetz.dart).
//
// Das Gradnetz dreht sich je Karte einen Schritt weiter. Sonst passiert im
// Hintergrund nichts.

/// Anzahl der Karten. Die Texte stehen in [_kKarten].
const int _kAnzahlKarten = 5;

/// Ab welchem Gradnetz-Schritt die Folge beginnt. 0 ist der Anmelde-Screen,
/// 1 die Namensauswahl — der Globus dreht sich also über den ganzen Einstieg
/// hinweg in eine Richtung weiter.
const int _kErsterSchritt = 2;

// ── Maße ─────────────────────────────────────────────────────────────────────

/// Seitenrand des Bildschirms — Chrome, bleibt absolut.
///
/// Knapp gehalten: Die Karte soll den Bildschirm ausfüllen und nicht als
/// kleines Kästchen in der Mitte schweben. 12 lassen das Gradnetz ringsum
/// sichtbar, ohne Platz zu verschenken.
const double _kSeitenrand = kWischSeitenrand;

/// Innenrand der Karte.
const double _kKartenInnenrand = kWischKartenInnenrand;

/// Optik der Karte: abgerundetes Rechteck mit dezentem Rand, angelehnt an die
/// Modus-Anleitungen. Bewusst OHNE den harten 3D-Schatten der Knöpfe: Die
/// Karte liegt auf dem Gradnetz, und ein Schlagschatten machte daraus ein
/// Objekt, das über der Fläche schwebt, statt eines ruhigen Blattes darauf.
const double _kKartenRadius = kWischKartenRadius;
const double _kKartenRand = kWischKartenRand;
const Color _kKartenRandFarbe = kWischKartenRandFarbe;

/// Obergrenze für die Grafik auf den Karten ohne vollflächiges Motiv.
///
/// Die Grafik bekommt den ganzen Platz über der Textkante. Auf einem grossen
/// Bildschirm wäre das mehr, als einer Nachstellung guttut — sie wird dann
/// mittig in ihr Band gesetzt statt weiter aufgeblasen. Die Textkante bleibt
/// davon unberührt; genau deshalb darf hier gedeckelt werden, ohne dass der
/// Text auf dieser Karte woanders sässe als auf den übrigen.
const double _kGrafikMax = 420;

/// Höhe, unter der eine Nachstellung nicht mehr kleiner gebaut, sondern als
/// Ganzes herunterskaliert wird. Begründung an [_KartenFlaeche._motivband].
const double _kMotivNatur = 180;

const double _kAbstandGrafikTitel = 16;
const double _kAbstandTitelText = 8;
const double _kAbstandVorKnopf = 18;

const double _kTitelGroesse = 20;
const double _kTextGroesse = 14;

/// Zeilenhöhen als Vielfaches der Schriftgrösse.
///
/// Fest gesetzt statt der Voreinstellung überlassen, weil [_textKante] die
/// Höhe des Textblocks vorausrechnet: Die Messung muss mit demselben
/// Zeilenabstand arbeiten wie die Anzeige, sonst stimmt der reservierte Platz
/// nicht.
const double _kTitelZeile = 1.2;
const double _kTextZeile = 1.4;
const double _kKnopfGroesse = 16;
const double _kUeberspringenGroesse = 14;

/// Senkrechter Innenrand des "Los geht's"-Knopfs.
///
/// Als Konstante statt als Zahl im Knopf, weil [_textKante] die Knopfhöhe
/// vorausberechnen muss: Der Streifen wird auf ALLEN Karten freigehalten,
/// auch auf denen ohne Knopf.
const double _kKnopfInnen = 14;

/// Höhe der Punktreihe unter der Karte. Die Reihe selbst steht als
/// [WischPunktreihe] in ergebnis_karten.dart — dieselbe, die die
/// Ergebnis-Ansichten der Tages-Challenges nutzen.
const double _kPunktZeile = kWischPunktZeile;

const _textDark = Color(0xFF1A1A1A);
const _textMid = Color(0xFF888888);
const _accent = Color(0xFF4A9E4A);

// ── Die fünf Karten ──────────────────────────────────────────────────────────

/// Welches Bauteil eine Karte zeigt.
enum _Motiv { flaggen, lernpfad, spielarten, dranbleiben, challenges }

class _Karte {
  final _Motiv motiv;
  final String titel;
  final String text;

  /// Füllt das Motiv die GANZE Karte, von Rand zu Rand?
  ///
  /// Dann steht der Text auf einem grauen Feld darüber ([_Textfeld]) statt
  /// darunter — sonst wäre er auf den bunten Bildern nicht zu lesen.
  final bool vollflaechig;

  /// Wie stark das Motiv über seinen Kasten hinaus gezeichnet wird.
  ///
  /// Nur die Flamme weicht von 1 ab. Der Faktor ändert NICHT den Platz im
  /// Layout — siehe [_KartenFlaeche._grossgezogen].
  final double grafikFaktor;

  const _Karte({
    required this.motiv,
    required this.titel,
    required this.text,
    this.vollflaechig = false,
    this.grafikFaktor = 1.0,
  });
}

/// Kurz halten: Wer fünf Karten wischt, liest keine Absätze. Eine Überschrift
/// und höchstens zwei Sätze je Karte.
const List<_Karte> _kKarten = [
  _Karte(
    motiv: _Motiv.flaggen,
    titel: '195 Länder entdecken',
    text: 'Flaggen, Hauptstädte, Umrisse, Zahlen — die ganze Welt in kleinen '
        'Portionen.',
    vollflaechig: true,
  ),
  _Karte(
    motiv: _Motiv.lernpfad,
    titel: 'Station für Station',
    text: 'Der Lernpfad führt dich durch jeden Kontinent. Eine Station nach '
        'der anderen.',
    vollflaechig: true,
  ),
  _Karte(
    motiv: _Motiv.spielarten,
    titel: 'Immer anders gefragt',
    text: 'Flaggen raten, Umrisse erkennen, Zahlen schätzen, Rätsel lösen.',
  ),
  _Karte(
    motiv: _Motiv.dranbleiben,
    titel: 'Dranbleiben lohnt sich',
    text: 'Jeder Tag zählt für deine Serie. Abzeichen gibt es obendrauf.',
    grafikFaktor: 1.5,
  ),
  _Karte(
    motiv: _Motiv.challenges,
    titel: 'Jeden Tag etwas Neues',
    text: 'Vier Tages-Challenges warten — für alle gleich, jeden Tag neu.',
  ),
];

class WillkommenScreen extends StatefulWidget {
  final VoidCallback onFertig;

  const WillkommenScreen({super.key, required this.onFertig});

  @override
  State<WillkommenScreen> createState() => _WillkommenScreenState();
}

class _WillkommenScreenState extends State<WillkommenScreen> {
  final _seiten = PageController();
  int _seite = 0;

  @override
  void dispose() {
    _seiten.dispose();
    super.dispose();
  }

  /// Erst beim Einrasten, nicht während des Wischens: Sonst spränge das
  /// Gradnetz auf halber Strecke um und wieder zurück, wenn jemand eine
  /// Wischbewegung abbricht.
  void _seiteGewechselt(int i) {
    if (i != _seite) setState(() => _seite = i);
  }

  @override
  Widget build(BuildContext context) {
    final kopfHoehe =
        MediaQuery.textScalerOf(context).scale(_kUeberspringenGroesse) + 24;

    return Scaffold(
      backgroundColor: kHintergrund,
      body: GradnetzHintergrund(
        schritt: _kErsterSchritt + _seite,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, platz) {
              // Höhe, die einer Karte bleibt. Vorab gerechnet statt vom Inhalt
              // abgeleitet — sonst wanderte die Punktreihe beim Wischen
              // zwischen unterschiedlich hohen Karten hin und her.
              final kartenHoehe =
                  platz.maxHeight - kopfHoehe - _kPunktZeile - 8;

              // EINE Textkante für alle fünf Karten, hier einmal gerechnet und
              // durchgereicht. Würde jede Karte ihre eigene bestimmen, sässe
              // der Text je nach Motivhöhe woanders — gemessen lagen die fünf
              // vorher zwischen 20 % und 78 % der Kartenhöhe, und beim Wischen
              // sprang er entsprechend.
              final kartenBreite = platz.maxWidth - 2 * _kSeitenrand;
              final textOben = _textKante(context, kartenHoehe, kartenBreite);

              return Column(
                children: [
                  _Kopfzeile(
                    hoehe: kopfHoehe,
                    onUeberspringen: widget.onFertig,
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _seiten,
                      onPageChanged: _seiteGewechselt,
                      itemCount: _kAnzahlKarten,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(
                            _kSeitenrand, 0, _kSeitenrand, 8),
                        child: _KartenFlaeche(
                          karte: _kKarten[i],
                          hoehe: kartenHoehe,
                          textOben: textOben,
                          letzte: i == _kAnzahlKarten - 1,
                          onFertig: widget.onFertig,
                        ),
                      ),
                    ),
                  ),
                  WischPunktreihe(anzahl: _kAnzahlKarten, aktiv: _seite),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Kopfzeile ────────────────────────────────────────────────────────────────

/// Nur der Überspringen-Verweis, oben rechts.
///
/// Dezent in Grau statt als Knopf: Er soll erreichbar sein, ohne mit dem
/// Inhalt der Karte um Aufmerksamkeit zu ringen.
class _Kopfzeile extends StatelessWidget {
  final double hoehe;
  final VoidCallback onUeberspringen;

  const _Kopfzeile({required this.hoehe, required this.onUeberspringen});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: hoehe,
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onUeberspringen,
          // Sichtbar ist nur der Text; getroffen werden muss er mit einem
          // Finger, deshalb der grosszügige Innenrand statt einer knappen
          // Textbox.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(
              t('Überspringen'),
              style: const TextStyle(
                fontSize: _kUeberspringenGroesse,
                fontWeight: FontWeight.w600,
                color: _textMid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Eine Karte ───────────────────────────────────────────────────────────────
//
// Jede Karte besteht aus denselben drei Bändern, und zwar auf allen fünf an
// derselben Stelle:
//
//   1. Motiv          — von oben bis [textOben]
//   2. Textblock      — beginnt GENAU bei [textOben]
//   3. Knopfstreifen  — unten, freigehalten auch auf den Karten ohne Knopf
//
// Die Kante [textOben] rechnet der Screen einmal für alle fünf aus (siehe
// [_textKante]) und reicht sie durch. Dass sie NICHT je Karte entsteht, ist
// der ganze Punkt: Vorher ergab sie sich aus der Motivhöhe, und die ist je
// Karte anders — nachgemessen lag der Titel dadurch zwischen 20 % und 78 %
// der Kartenhöhe, und beim Wischen sprang er entsprechend.
//
// Die vollflächigen Karten (1 und 2) lassen ihr Motiv unter dem Textblock
// weiterlaufen und legen ihn auf ein graues Feld; die übrigen halten das Motiv
// über der Kante und setzen den Text darunter direkt auf das Weiss der Karte.

class _KartenFlaeche extends StatelessWidget {
  final _Karte karte;
  final double hoehe;

  /// Oberkante des Textblocks, gemeinsam für alle fünf Karten.
  final double textOben;

  final bool letzte;
  final VoidCallback onFertig;

  const _KartenFlaeche({
    required this.karte,
    required this.hoehe,
    required this.textOben,
    required this.letzte,
    required this.onFertig,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Volle Breite erzwingen: siehe der Hinweis am Dateikopf.
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kKartenRadius),
        border: Border.all(color: _kKartenRandFarbe, width: _kKartenRand),
      ),
      // Innenradius: aussen minus Randbreite, sonst bliebe zwischen Bild und
      // Rahmen an den Ecken ein heller Zwickel stehen.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kKartenRadius - _kKartenRand),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _motivband(),
            // Der Textblock hängt an der gemeinsamen Kante — nur oben
            // festgemacht, nicht unten: Er darf so hoch werden, wie er
            // braucht. [_textKante] hat den Platz dafür schon abgezogen.
            //
            // Das graue Feld rückt um seinen Innenrand nach oben, weil
            // [textOben] die Kante der SCHRIFT meint, nicht die des Kastens.
            Positioned(
              top: textOben - _Textfeld.innen,
              left: 0,
              right: 0,
              child: _textband(),
            ),
            if (letzte)
              Positioned(
                left: _kKartenInnenrand,
                right: _kKartenInnenrand,
                bottom: _kKartenInnenrand,
                child: _LosGehtsKnopf(onTap: onFertig),
              ),
          ],
        ),
      ),
    );
  }

  /// Band 1 — das Motiv.
  ///
  /// Vollflächig heisst wörtlich vollflächig: kein Innenrand, das Bild läuft
  /// bis an den Rand der Karte und wird nur vom abgerundeten Rahmen
  /// beschnitten — so, als schaue man in das Spiel hinein.
  Widget _motivband() {
    if (karte.vollflaechig) {
      return Positioned.fill(child: _Bauteil(motiv: karte.motiv, groesse: hoehe));
    }

    // Der Platz bis zur Textkante, abzüglich Innenrand und Abstand zum Titel.
    // Nach unten nicht begrenzt: Wird es sehr eng, schrumpft eben die Grafik —
    // sie darf nie in den Text hineinragen, denn die Textkante steht fest.
    final band =
        (textOben - _kKartenInnenrand - _kAbstandGrafikTitel).clamp(0.0, hoehe);
    final grafik = band < _kGrafikMax ? band : _kGrafikMax;

    // Unter [_kMotivNatur] wird die Nachstellung nicht mehr kleiner gebaut,
    // sondern als Ganzes herunterskaliert.
    //
    // Grund: Die Vorschauen sind aus den echten Widgets zusammengesetzt, und
    // deren Beschriftungen brauchen bei Schriftskala 1.5 eine Mindesthöhe —
    // auf 320x480 blieb der Challenge-Kachel sonst 18 px zu wenig. Ein Band,
    // das kleiner ist als die Nachstellung, darf die Textkante aber nicht
    // verschieben, denn die steht für alle fünf Karten fest. Also skalieren
    // statt quetschen.
    return Positioned(
      top: _kKartenInnenrand,
      left: _kKartenInnenrand,
      right: _kKartenInnenrand,
      height: band,
      // Mittig im Band: Deckelt [_kGrafikMax] die Grafik auf einem grossen
      // Bildschirm, verteilt sich der Rest gleichmässig über und unter ihr.
      child: Center(
        child: LayoutBuilder(
          builder: (context, platz) {
            final natur = grafik < _kMotivNatur ? _kMotivNatur : grafik;
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                // Feste Breite: In einer FittedBox wäre sie sonst unbegrenzt,
                // und die Nachstellungen zögen sich auf ihre Inhaltsbreite
                // zusammen.
                width: platz.maxWidth,
                height: natur,
                child: _grossgezogen(platz.maxWidth, natur),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Das Motiv, um [_Karte.grafikFaktor] vergrössert.
  ///
  /// Der Faktor wirkt NICHT auf den Platz, den das Motiv im Layout belegt —
  /// die Grafik wächst über ihren Kasten hinaus und bleibt dabei mittig. Genau
  /// so muss es sein: Der Kasten reicht bis zur gemeinsamen Textkante, und die
  /// darf sich nicht verschieben, nur weil auf einer Karte etwas grösser
  /// gezeichnet wird.
  ///
  /// Dass das gutgeht, liegt am Motiv selbst: Die Flamme ist eine Lottie-Datei
  /// mit reichlich Rand — von ihrem quadratischen Kasten füllt die sichtbare
  /// Flamme nur etwa ein Drittel. Ein Motiv, das seinen Kasten ausfüllt, würde
  /// bei einem Faktor über 1 in den Text ragen.
  Widget _grossgezogen(double breite, double hoehe) {
    final bauteil = _Bauteil(
      motiv: karte.motiv,
      groesse: hoehe * karte.grafikFaktor,
    );
    if (karte.grafikFaktor == 1.0) return bauteil;
    return OverflowBox(
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: SizedBox(
        width: breite * karte.grafikFaktor,
        height: hoehe * karte.grafikFaktor,
        child: bauteil,
      ),
    );
  }

  /// Band 2 — Titel und Text.
  ///
  /// Auf ALLEN fünf Karten dasselbe graue Feld, auch dort, wo der Text auf
  /// dem weissen Grund ohnehin zu lesen wäre. Es geht um ein geschlossenes
  /// Bild: fünf Karten, gleich aufgebaut. Ein Feld nur auf den beiden mit
  /// buntem Untergrund liesse die Folge beim Wischen zerfallen.
  Widget _textband() => _Textfeld(titel: karte.titel, text: karte.text);
}

// ── Die gemeinsame Textkante ─────────────────────────────────────────────────

/// Wo der Textblock auf JEDER Karte beginnt, gemessen von der Kartenoberkante.
///
/// Der Wunschwert ist [_kTextAnteil] — er stammt von Karte 3, wo der Text bei
/// normaler Schrift richtig sass (nachgemessen: 0,670 der Kartenhöhe). Auf
/// engen Geräten und bei grosser Systemschrift passt der Text dort aber nicht
/// mehr darunter; dann rückt die Kante so weit nach oben, wie nötig.
///
/// ENTSCHEIDEND: Gerechnet wird EINMAL für den ganzen Screen, aus Kartenmass,
/// Schriftskala und dem LÄNGSTEN der fünf Texte. Der Wert hängt also an nichts
/// Kartenspezifischem — alle fünf bekommen ihn identisch, und beim Wischen
/// bleibt der Text stehen.
const double _kTextAnteil = 0.66;

double _textKante(BuildContext context, double kartenHoehe, double breite) {
  final skalierer = MediaQuery.textScalerOf(context);

  // Gemessen wird auf der Textbreite IM grauen Feld — dort steht der Text auf
  // allen fünf Karten, und dort bricht er um.
  final messBreite = breite * _Textfeld.breite - 2 * _Textfeld.innen;

  double hoeheVon(String s, double groesse, FontWeight gewicht, double zeile) {
    final maler = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: groesse,
            fontWeight: gewicht,
            height: zeile),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: skalierer,
    )..layout(maxWidth: messBreite);
    return maler.height;
  }

  var noetig = 0.0;
  for (final k in _kKarten) {
    final h = hoeheVon(t(k.titel), _kTitelGroesse, FontWeight.w900,
            _kTitelZeile) +
        _kAbstandTitelText +
        hoeheVon(t(k.text), _kTextGroesse, FontWeight.w500, _kTextZeile);
    if (h > noetig) noetig = h;
  }

  // Der Knopfstreifen wird auf ALLEN Karten freigehalten, nicht nur auf der
  // letzten — sonst sässe der Text dort tiefer als auf den übrigen.
  final knopf = skalierer.scale(_kKnopfGroesse) * 1.2 +
      2 * _kKnopfInnen +
      _kAbstandVorKnopf;

  final platzKante =
      kartenHoehe - noetig - 2 * _Textfeld.innen - knopf - _kKartenInnenrand;
  final wunschKante = kartenHoehe * _kTextAnteil;
  return platzKante < wunschKante ? platzKante : wunschKante;
}

// ── Das graue Textfeld ───────────────────────────────────────────────────────

/// Titel und Text auf grauem Grund — für die vollflächigen Karten.
///
/// EIN Bauteil für alle davon, nicht zweimal ähnlich gebaut: Farbe, Radius,
/// Innenrand, Breite und Lage kommen aus dieser Klasse, damit die Felder auf
/// Karte 1 und 2 nicht auseinanderdriften.
///
/// Grau statt weiss und mit Radius 12: dieselbe Fläche wie die Antwortknöpfe
/// im Quiz und die Statistik-Kacheln im Profil ([AppTheme.card]).
class _Textfeld extends StatelessWidget {
  final String titel;
  final String text;

  const _Textfeld({required this.titel, required this.text});

  /// Breite als Anteil der Karte.
  static const double breite = 0.86;

  /// Innenrand des Feldes, rundum gleich.
  ///
  /// Nicht privat, weil [_textKante] damit rechnet: Von der Kartenhöhe muss
  /// abgezogen werden, was Rand und Text zusammen brauchen.
  static const double innen = 14;

  /// Eckradius. Derselbe wie an den Antwortknöpfen im Quiz und den
  /// Statistik-Kacheln im Profil.
  static const double radius = 12;

  /// Farbe des Textes im Feld.
  ///
  /// Dunkler als das [_textMid] der übrigen Nebentexte: Auf dem grauen Feld
  /// hätte das helle Grau zu wenig Kontrast.
  static const Color textFarbe = Color(0xFF5A5A5A);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: breite,
        child: Container(
          padding: const EdgeInsets.all(innen),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t(titel),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: _kTitelGroesse,
                  fontWeight: FontWeight.w900,
                  height: _kTitelZeile,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: _kAbstandTitelText),
              Text(
                t(text),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: _kTextGroesse,
                  height: _kTextZeile,
                  fontWeight: FontWeight.w500,
                  color: textFarbe,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Die Bauteile auf den Karten ──────────────────────────────────────────────


class _Bauteil extends StatelessWidget {
  final _Motiv motiv;
  final double groesse;

  const _Bauteil({required this.motiv, required this.groesse});

  @override
  Widget build(BuildContext context) {
    switch (motiv) {
      case _Motiv.flaggen:
        return const _Streufeld();
      case _Motiv.lernpfad:
        return _Pfadvorschau(groesse: groesse);
      case _Motiv.spielarten:
        return _Fragevorschau(groesse: groesse);
      case _Motiv.dranbleiben:
        // Nur die Flamme, gross, mit der Eins darin — genau so sieht sie im
        // Spiel am ersten Tag aus. Dasselbe Widget, das die Kopfzeile des
        // Lernpfads und die Profil-Kachel zeigen.
        //
        // Die Münzsammlung stand hier zwischenzeitlich darunter und ist
        // wieder raus: Zwei Blickfänge auf einer Karte teilen die
        // Aufmerksamkeit, und die Flamme allein sagt dasselbe.
        return Center(child: StreakFlamme(groesse: groesse, zahl: 1));
      case _Motiv.challenges:
        return _Challengevorschau(groesse: groesse);
    }
  }
}

/// Karte 2: ein Ausschnitt des echten Lernpfads.
///
/// Beide Teile stammen aus dem Spiel: [KontinentHintergrund] zeichnet dieselbe
/// gekachelte Fläche, auf der der Pfad steht, und [LernpfadStationButton] ist
/// buchstäblich derselbe Button — dasselbe Widget, nicht eine zweite Fassung
/// davon. Ohne onTap, also ohne Druck-Animation.
///
/// KEINE VERBINDUNGSLINIE: Der Lernpfad hat keine. Die Stationen stehen im
/// Zickzack auf der Kachelfläche, verbunden wird nichts — eine Linie hier
/// hinzuzumalen hiesse, etwas zu zeigen, das es im Spiel nicht gibt.
class _Pfadvorschau extends StatelessWidget {
  final double groesse;

  const _Pfadvorschau({required this.groesse});

  /// Waagerechte Lage der Stationen als Anteil der Breite — dasselbe
  /// Zickzack-Muster, das home_screen für den Pfad benutzt (Mitte, rechts
  /// aussen, Mitte, links aussen).
  static const List<double> _x = [0.50, 0.70, 0.50, 0.30, 0.50, 0.70];
  static const List<LernModus> _modi = [
    LernModus.flaggenQuizBild,
    LernModus.hauptstaedteMultiple,
    LernModus.umrissBild,
    LernModus.zweiWahrheiten,
    LernModus.waehrungsQuiz,
    LernModus.nachbarland,
  ];

  @override
  Widget build(BuildContext context) {
    return KontinentHintergrund(
      kontinentId: 'europa',
      child: LayoutBuilder(
        builder: (context, platz) {
          // Stationsgrösse: mal 1,5 gegenüber der ersten Fassung (Teiler 4,53
          // statt 6,8, Grenzen 36/99 statt 24/66). Der Ausschnitt zeigt damit
          // weniger, aber grössere Stationen — die Modus-Symbole darin sind
          // erkennbar, statt als Punkte zu erscheinen.
          final d = (platz.maxHeight / 4.53).clamp(36.0, 99.0).toDouble();

          // Der Abstand hängt an der STATIONSGRÖSSE, nicht an der Kartenhöhe.
          //
          // Das ist der Unterschied zur ersten Fassung: Dort war er ein
          // Anteil der Höhe, und weil die Grösse bei 99 gedeckelt ist, riss
          // der Weg auf einem hohen Bildschirm auseinander — drei Stationen
          // mit je einer Stationsbreite Leere dazwischen. So bleibt der
          // Zwischenraum immer gut die halbe Station.
          final schritt = d * 1.55;

          // Der Weg läuft über beide Kartenkanten hinaus: Die erste Station
          // sitzt über dem oberen Rand, und es werden so viele gesetzt, bis
          // eine unter dem unteren liegt. Der Ausschnitt wirkt damit wie ein
          // Blick in den laufenden Lernpfad und nicht wie eine sauber
          // abgezählte Auswahl. Reichen die sechs Modi nicht, fangen sie von
          // vorn an.
          final anzahl = (platz.maxHeight / schritt).ceil() + 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < anzahl; i++)
                Positioned(
                  left: platz.maxWidth * _x[i % _x.length] - d / 2,
                  top: schritt * (i - 0.4),
                  child: LernpfadStationButton(
                    modus: _modi[i % _modi.length],
                    groesse: d,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Karte 3: eine echte Frage, verkleinert nachgestellt.
///
/// Eine Flagge und darunter vier Antwortknöpfe — genau der Aufbau, den das
/// Flaggenquiz zeigt. Die Knöpfe sind [AntwortButton] aus dem Stationsquiz,
/// dasselbe Widget, nicht eine zweite Fassung davon; sie standen bis zu dieser
/// Karte als private Klasse in station_quiz_screen.dart.
///
/// Der dritte Knopf steht auf "richtig" und ist deshalb grün — so zeigt die
/// Karte nicht nur die Frage, sondern auch die Rückmeldung, die darauf folgt.
/// Nichts davon ist antippbar: [AntwortButton] ohne onTap bleibt stumm stehen.
class _Fragevorschau extends StatelessWidget {
  final double groesse;

  const _Fragevorschau({required this.groesse});

  /// Vier Länder, deren Flaggen niemand verwechselt — die richtige Antwort
  /// soll auf einen Blick zur gezeigten Flagge passen.
  static const List<String> _antworten = ['Brasilien', 'Argentinien', 'Japan',
      'Thailand'];
  static const int _richtig = 2;
  static const String _flagge = 'JP';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, platz) {
        final flaggenBreite = (platz.maxHeight * 0.34).clamp(36.0, 88.0);
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            // Feste Breite, damit die Knöpfe eine Zeile bilden statt sich auf
            // die Textbreite zusammenzuziehen — dieselbe Falle wie beim
            // Anmelde-Screen.
            width: platz.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Flagge(iso: _flagge, breite: flaggenBreite.toDouble()),
                SizedBox(height: flaggenBreite * 0.18),
                for (var i = 0; i < _antworten.length; i++)
                  AntwortButton(
                    text: t(_antworten[i]),
                    showFeedback: true,
                    istRichtig: i == _richtig,
                    istGewaehlt: i == _richtig,
                    feedbackRichtig: true,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// Karte 5: ein Ausschnitt des Tages-Challenge-Panels.
///
/// [ChallengeKachel] ist dieselbe Kachel, die das Panel im Lernpfad zeigt —
/// dasselbe Widget, nicht eine zweite Fassung davon; sie stand bis zu dieser
/// Karte als private Klasse in home_screen.dart. Titel, Farben und Bilder
/// stammen aus derselben Liste wie dort.
///
/// Die erste Kachel steht auf "erledigt" und trägt deshalb das weisse
/// Häkchen — so zeigt die Karte gleich mit, wie ein gespielter Tag aussieht.
/// Ohne onTap bleiben alle vier stumm stehen.
class _Challengevorschau extends StatelessWidget {
  final double groesse;

  const _Challengevorschau({required this.groesse});

  /// Dieselben vier Challenges wie im Panel, in derselben Reihenfolge.
  static const _kacheln = [
    (
      asset: 'assets/icons/challenge_preis.png',
      emoji: '🏷️',
      titel: 'Das große Schätzen',
      bg: Color(0xFFF9A825),
    ),
    (
      asset: 'assets/icons/challenge_higher_lower.png',
      emoji: '📊',
      titel: 'Higher or Lower',
      bg: Color(0xFF4A9E4A),
    ),
    (
      asset: 'assets/icons/challenge_ranking.png',
      emoji: '🔢',
      titel: 'Ranking Quiz',
      bg: Color(0xFF7C3AED),
    ),
    (
      asset: 'assets/icons/challenge_portfolio.png',
      emoji: '💹',
      titel: 'Portfolio des Tages',
      bg: Color(0xFF4A90D9),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, platz) {
        const luecke = 8.0;
        // Zwei mal zwei wie im Panel. Die Kacheln bekommen dasselbe
        // Seitenverhältnis, das der GridView dort ausrechnet.
        final zellBreite = (platz.maxWidth - luecke) / 2;
        final zellHoehe = (platz.maxHeight - luecke) / 2;
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: luecke,
          mainAxisSpacing: luecke,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: (zellBreite / zellHoehe).clamp(0.4, 2.5),
          children: [
            for (var i = 0; i < _kacheln.length; i++)
              ChallengeKachel(
                id: 'vorschau$i',
                asset: _kacheln[i].asset,
                emoji: _kacheln[i].emoji,
                title: t(_kacheln[i].titel),
                bg: _kacheln[i].bg,
                isDone: i == 0,
              ),
          ],
        );
      },
    );
  }
}

// ── Hauptaktion ──────────────────────────────────────────────────────────────

/// Hauptaktion im 3D-Muster der App (vgl. challenge_fertig_button.dart).
class _LosGehtsKnopf extends StatelessWidget {
  final VoidCallback onTap;

  const _LosGehtsKnopf({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _textDark, width: 2.5),
          boxShadow: const [
            BoxShadow(color: _textDark, offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Text(
          t('Los geht\'s'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: _kKnopfGroesse,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}


// ── Eine Flagge ──────────────────────────────────────────────────────────────

/// Höhe einer Flagge als Anteil ihrer Breite.
///
/// 4:3, weil das country_flags-Paket seine Grafiken mit BoxFit.contain in
/// diesem Verhältnis zeichnet (siehe widgets/flaggen_widget.dart).
const double _kFlaggenVerhaeltnis = 0.75;

/// Haarlinie an der Flaggenkante — feste Breite, nicht mitskaliert: eine
/// Linie soll auf jedem Gerät eine Linie bleiben und kein Balken.
const double _kFlaggenRand = 1;
const double _kFlaggenRadius = 4;

class _Flagge extends StatelessWidget {
  final String iso;
  final double breite;

  const _Flagge({required this.iso, required this.breite});

  @override
  Widget build(BuildContext context) {
    final hoehe = breite * _kFlaggenVerhaeltnis;

    // Nur eine Haarlinie auf der Kante, kein 3D-Rahmen: sechs Flaggen
    // nebeneinander mit dickem Rand und hartem Schatten wirkten wie sechs
    // Knöpfe. Die Linie soll die Flagge begrenzen, nicht einrahmen.
    //
    // Sie liegt ÜBER der Flagge (Stack) statt als Border des Containers:
    // ein Border verkleinert den Innenraum, die Flagge würde also um die
    // Randbreite schrumpfen und die Linie säße einen Hauch neben der Kante.
    return SizedBox(
      width: breite,
      height: hoehe,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_kFlaggenRadius),
            child: zeigeFlagge(iso, width: breite, height: hoehe),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_kFlaggenRadius),
              border: Border.all(color: _textDark, width: _kFlaggenRand),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Karte 1: das Streufeld ───────────────────────────────────────────────────
//
// Flaggen, Wahrzeichen und vereinzelt Coiny über die ganze Kartenfläche, teils
// über die Ränder hinaus.
//
// LOCKERES RASTER STATT REINEM ZUFALL. Die erste Fassung setzte 14 Stücke auf
// von Hand gewürfelte Anteile, und das sah aus wie gewürfelt: An zwei Stellen
// klebten drei Motive aneinander, dazwischen blieben Löcher. Das ist kein
// Ausrutscher, sondern die Regel — gleichverteilte Punkte klumpen, weil nichts
// sie auseinanderhält.
//
// Deshalb steht jetzt ein Raster aus [_kSpalten] x [_kZeilen] Zellen dahinter,
// und jedes Stück sitzt in genau einer Zelle. Das Raster allein wirkte
// gestellt; deshalb bekommt jedes Stück einen festen Versatz aus [_kVersatz]
// (Anteil der Zellengrösse) und eine eigene Neigung. Ergebnis: gleichmässige
// Dichte ohne Klumpen, aber keine erkennbaren Reihen und Spalten.
//
// WENIGER, DAFÜR GRÖSSER: 12 Stücke statt 14, jedes davon aber
// [_kZellFuellung] der Zellengrösse gross — deutlich mehr als die 0,18 bis
// 0,23 der Kartenbreite vorher.
//
// VOLL SICHTBAR, nicht blass wie die Hintergrund-Deko der Einstiegs-Screens
// (einstiegs_deko.dart, 6 bis 22 % Deckkraft). Dort sind die Motive Textur,
// hier sind sie der Inhalt.
//
// DIE WAHRZEICHEN stammen NICHT aus dem Gebäude-Quiz: Der Modus
// bekanntesGebaeude ist reine Textarbeit ("In welchem Land steht [Bauwerk]?",
// siehe laender_gebaeude.dart) und hatte nie eigene Bilder. Die
// Illustrationen gehören zur Pfad-Deko des Lernpfads (pfad_deko_layer.dart)
// und liegen in assets/icons/deko/.
//
// Versatz und Neigung stehen als feste Listen statt als Zufall: Die Karte soll
// auf jedem Gerät gleich aussehen und sich beim Neuzeichnen nicht neu würfeln.

enum _StreuArt { flagge, wahrzeichen, coiny }

const int _kSpalten = 4;
const int _kZeilen = 6;

/// Grösse eines Stücks, je Zellenkante getrennt gedeckelt.
///
/// Die Zellen sind hochkant — die Karte ist höher als breit. Ein Stück nur an
/// der schmalen Kante zu bemessen liesse zwischen den Zeilen zu viel Weiss;
/// nur an der hohen bemessen liesse es in die Nachbarspalte wachsen. Deshalb
/// zwei Anteile, und es gilt der kleinere der beiden Werte.
///
/// BEIDE WERTE MÜSSEN UNTER 1 BLEIBEN, und zwar mit Luft für die Neigung:
/// Nur dann passt jedes Stück gekippt in seine Zelle, und nur dann findet die
/// Überschneidungsprüfung in [_Streufeld] immer eine Lösung — die letzte Stufe
/// setzt das Stück in die Zellenmitte, und die muss frei sein können.
///
/// Werdegang der Zahlen: erst 0,95/0,88 bei 3x4 Zellen, dann 0,89/0,95 bei
/// 4x6 (Faktor 0,7), jetzt 0,71/0,76 (nochmals Faktor 0,8). Auf einer 360 px
/// breiten Karte ist ein Stück damit 76,7 px gross statt der 136,8 px vom
/// Anfang. Der Höhenanteil greift nur auf flachen Karten (320x480, Tablet),
/// wo die Zeilen sonst zu eng stünden.
const double _kZellFuellungB = 0.71;
const double _kZellFuellungH = 0.76;

/// Wie weit das Raster über die Kartenfläche hinausgeht.
///
/// Ohne das sässen die äusseren Zellen vollständig im Bild, und die Karte
/// hätte ringsum einen leeren Saum. Gedehnt ragen die Randstücke über die
/// Kanten und der Haufen wirkt, als ginge er weiter.
///
/// Senkrecht schwächer als vorher (1,05 statt 1,12): Bei sechs Zeilen statt
/// vier genügt weniger Dehnung für denselben Überstand, und die Zeilen rücken
/// dadurch enger zusammen.
const double _kRasterDehnungX = 1.20;
const double _kRasterDehnungY = 1.05;

/// Versatz je Zelle, als Anteil der Zellengrösse — das, was aus dem Raster
/// eine Streuung macht. Reihenfolge zeilenweise von links oben.
///
/// Die Werte sind nicht frei gewürfelt, sondern nach zwei Regeln gewählt, die
/// beide aus dem Probebild stammen:
///
///  * WAAGERECHT höchstens 0,20 Unterschied zwischen zwei Nachbarn einer
///    Zeile. Laufen sie stärker aufeinander zu, überdecken sie sich; laufen
///    sie stärker auseinander, entsteht eine senkrechte Gasse.
///  * SENKRECHT rücken die Zeilen zusammen; nur zwischen Zeile 4 und 5 gehen
///    sie auseinander. Der einzige grössere Zwischenraum liegt damit genau
///    dort, wo ohnehin das graue Textfeld darüberliegt — sichtbar wird er
///    nicht. Nebenbei rückt Zeile 4 damit über das Feld und bleibt sichtbar,
///    statt dahinter zu verschwinden.
const List<Offset> _kVersatz = [
  // Zeile 1 — leicht nach unten
  Offset(-0.12, 0.10),
  Offset(0.04, 0.12),
  Offset(-0.06, 0.08),
  Offset(0.10, 0.10),
  // Zeile 2
  Offset(0.08, 0.02),
  Offset(-0.10, 0.00),
  Offset(0.06, 0.04),
  Offset(-0.04, 0.02),
  // Zeile 3
  Offset(-0.10, -0.04),
  Offset(0.06, -0.06),
  Offset(-0.08, -0.02),
  Offset(0.12, -0.04),
  // Zeile 4 — nach oben, über das Textfeld
  Offset(0.12, -0.12),
  Offset(-0.06, -0.14),
  Offset(0.10, -0.10),
  Offset(-0.08, -0.12),
  // Zeile 5 — nach unten; der Zwischenraum darüber liegt hinter dem Textfeld
  Offset(-0.08, 0.12),
  Offset(0.10, 0.14),
  Offset(-0.04, 0.10),
  Offset(0.08, 0.12),
  // Zeile 6 — über den unteren Kartenrand hinaus
  Offset(0.10, 0.16),
  Offset(-0.08, 0.14),
  Offset(0.12, 0.18),
  Offset(-0.06, 0.14),
];

/// Neigung je Zelle im Bogenmaß. Klein gehalten — die Stücke sollen
/// hingelegt wirken, nicht umgekippt.
const List<double> _kNeigung = [
  -0.20, 0.13, 0.22, -0.11, //
  0.24, -0.09, 0.16, -0.15, //
  0.11, 0.19, -0.13, 0.21, //
  -0.17, 0.10, -0.22, 0.14, //
  0.18, -0.12, 0.20, -0.16, //
  -0.10, 0.23, -0.19, 0.12, //
];

/// Was in welcher Zelle liegt. Zeilenweise von links oben, 24 Einträge für
/// [_kSpalten] x [_kZeilen] Zellen.
///
/// Gemischt statt sortiert: Flaggen, Wahrzeichen und Coiny wechseln sich ab,
/// damit nirgends eine Ecke nur aus Flaggen besteht. Die beiden Coiny stehen
/// weit auseinander — er ist der Blickfang, und zwei nebeneinander sähen aus
/// wie ein Fehler.
///
/// Die Wahrzeichen decken alle sechs Kontinente ab, dazu die drei Motive aus
/// der Reihe welt_* — dieselben Bilder, die der Lernpfad neben seinen
/// Stationen zeigt.
const List<_Stueck> _kStuecke = [
  // Zeile 1
  _Stueck(_StreuArt.flagge, 'BR'),
  _Stueck(_StreuArt.wahrzeichen, 'europa_bigben'),
  _Stueck(_StreuArt.flagge, 'JP'),
  _Stueck(_StreuArt.wahrzeichen, 'welt_flugzeug'),
  // Zeile 2
  _Stueck(_StreuArt.coiny, 'coin_winken'),
  _Stueck(_StreuArt.wahrzeichen, 'asien_fuji'),
  _Stueck(_StreuArt.flagge, 'CA'),
  _Stueck(_StreuArt.wahrzeichen, 'suedamerika_palme'),
  // Zeile 3
  _Stueck(_StreuArt.flagge, 'ZA'),
  _Stueck(_StreuArt.wahrzeichen, 'afrika_pyramide'),
  _Stueck(_StreuArt.flagge, 'AU'),
  _Stueck(_StreuArt.wahrzeichen, 'ozeanien_opernhaus'),
  // Zeile 4
  _Stueck(_StreuArt.wahrzeichen, 'europa_eiffelturm'),
  _Stueck(_StreuArt.flagge, 'MX'),
  _Stueck(_StreuArt.wahrzeichen, 'welt_kompass'),
  _Stueck(_StreuArt.flagge, 'NO'),
  // Zeile 5
  _Stueck(_StreuArt.flagge, 'IN'),
  _Stueck(_StreuArt.wahrzeichen, 'nordamerika_wolkenkratzer'),
  _Stueck(_StreuArt.coiny, 'coin_normal'),
  _Stueck(_StreuArt.wahrzeichen, 'asien_temple'),
  // Zeile 6
  _Stueck(_StreuArt.wahrzeichen, 'suedamerika_lama'),
  _Stueck(_StreuArt.flagge, 'EG'),
  _Stueck(_StreuArt.wahrzeichen, 'europa_akropolis'),
  _Stueck(_StreuArt.flagge, 'KR'),
];

class _Stueck {
  final _StreuArt art;

  /// ISO-Code (Flagge) oder Dateiname ohne Endung (Wahrzeichen, Coiny).
  final String wert;

  const _Stueck(this.art, this.wert);
}

/// Wie weit der Versatz zurückgenommen wird, wenn ein Stück auf ein schon
/// gesetztes stösst.
///
/// Der erste Wert ist der volle Versatz aus [_kVersatz], der letzte ist gar
/// kein Versatz — dann sitzt das Stück in der Mitte seiner Zelle. Der letzte
/// Schritt kann nie scheitern, weil ein Stück samt Neigung immer kleiner ist
/// als seine Zelle (siehe [_kZellFuellungB]); die Suche endet also garantiert.
const List<double> _kVersatzStufen = [1.0, 0.75, 0.5, 0.25, 0.0];

class _Streufeld extends StatelessWidget {
  const _Streufeld();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, platz) {
        final b = platz.maxWidth;
        final h = platz.maxHeight;
        final zelleB = b * _kRasterDehnungX / _kSpalten;
        final zelleH = h * _kRasterDehnungY / _kZeilen;
        final ausB = zelleB * _kZellFuellungB;
        final ausH = zelleH * _kZellFuellungH;
        final gross = ausB < ausH ? ausB : ausH;

        // ÜBERSCHNEIDUNGSPRÜFUNG. Die Stücke werden der Reihe nach gesetzt;
        // jedes bekommt zuerst seinen vollen Versatz, und wenn es damit ein
        // schon gesetztes berührt, wird der Versatz stufenweise
        // zurückgenommen, bis es frei steht.
        //
        // Gerechnet wird mit dem GEDREHTEN Kasten: Eine um 0,2 rad gekippte
        // Flagge braucht rund ein Fünftel mehr Platz als die ungekippte, und
        // genau diese Ecken waren es, die sich berührten.
        //
        // Die Prüfung läuft hier und nicht in der Konstantenliste, weil die
        // tatsächlichen Masse erst beim Layout feststehen: Auf einer flachen
        // Karte sind die Zellen anders geschnitten als auf einer hohen, und
        // was dort frei steht, kann sich hier überlagern.
        final gesetzt = <Rect>[];
        final stuecke = <Widget>[];
        for (var i = 0; i < _kStuecke.length; i++) {
          final kasten = _kasten(i, gross);
          for (final stufe in _kVersatzStufen) {
            final mitte = _mitte(i, b, h, zelleB, zelleH, stufe);
            final r = Rect.fromCenter(
              center: Offset(mitte.dx, mitte.dy - gross / 2 + kasten.height / 2),
              width: kasten.width,
              height: kasten.height,
            );
            final frei = !gesetzt.any((a) => a.overlaps(r));
            if (frei || stufe == _kVersatzStufen.last) {
              gesetzt.add(r);
              stuecke.add(Positioned(
                left: mitte.dx - gross / 2,
                top: mitte.dy - gross / 2,
                child: Transform.rotate(
                  angle: _kNeigung[i],
                  child: _StreuStueck(stueck: _kStuecke[i], breite: gross),
                ),
              ));
              break;
            }
          }
        }

        return Stack(clipBehavior: Clip.none, children: stuecke);
      },
    );
  }

  /// Mittelpunkt der Zelle von Stück [i], um [stufe] mal seinen Versatz
  /// verschoben.
  ///
  /// Das Raster wird vom Kartenmittelpunkt aus gedehnt: So wächst es nach
  /// allen Seiten über die Kanten hinaus, statt sich als Ganzes nach links
  /// oben zu verschieben.
  Offset _mitte(int i, double b, double h, double zelleB, double zelleH,
      double stufe) {
    final spalte = i % _kSpalten;
    final zeile = i ~/ _kSpalten;
    return Offset(
      b * 0.5 +
          ((spalte + 0.5) / _kSpalten - 0.5) * b * _kRasterDehnungX +
          _kVersatz[i].dx * zelleB * stufe,
      h * 0.5 +
          ((zeile + 0.5) / _kZeilen - 0.5) * h * _kRasterDehnungY +
          _kVersatz[i].dy * zelleH * stufe,
    );
  }

  /// Der Platz, den Stück [i] gekippt einnimmt.
  ///
  /// Flaggen sind flacher als breit ([_kFlaggenVerhaeltnis]), Wahrzeichen und
  /// Coiny quadratisch. Gekippt wächst beides: Ein Rechteck w x hh belegt
  /// gedreht |cos|·w + |sin|·hh in der Breite und |sin|·w + |cos|·hh in der
  /// Höhe.
  Size _kasten(int i, double gross) {
    final w = gross;
    final hh = _kStuecke[i].art == _StreuArt.flagge
        ? gross * _kFlaggenVerhaeltnis
        : gross;
    final c = math.cos(_kNeigung[i]).abs();
    final s = math.sin(_kNeigung[i]).abs();
    return Size(c * w + s * hh, s * w + c * hh);
  }
}

class _StreuStueck extends StatelessWidget {
  final _Stueck stueck;
  final double breite;

  const _StreuStueck({required this.stueck, required this.breite});

  @override
  Widget build(BuildContext context) {
    switch (stueck.art) {
      case _StreuArt.flagge:
        return _Flagge(iso: stueck.wert, breite: breite);
      case _StreuArt.wahrzeichen:
        return SizedBox(
          width: breite,
          height: breite,
          child: Image.asset(
            'assets/icons/deko/${stueck.wert}.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        );
      case _StreuArt.coiny:
        return _Coiny(datei: stueck.wert, durchmesser: breite);
    }
  }
}

// ── Coiny ────────────────────────────────────────────────────────────────────

/// Masse der Coiny-Dateien und des tatsächlich sichtbaren Inhalts darin.
///
/// Alle vier Posen sind 677x369 gross, die Münze darin aber nur 238x273 an
/// Position (220,70) — rundum liegt durchsichtiger Rand. Ohne diese Zahlen
/// würde die Bildkante ausgerichtet statt der Münze, und Coiny erschiene im
/// Streufeld gut ein Drittel so gross wie gewollt. Ausgemessen über die
/// Alpha-Werte der Datei; wer die Bilder austauscht, muss sie neu bestimmen.
const double _kCoinyDateiBreite = 677;
const double _kCoinyDateiHoehe = 369;
const double _kCoinyInhaltX = 220;
const double _kCoinyInhaltY = 70;
const double _kCoinyInhaltBreite = 238;

/// Coiny, auf die sichtbare Münze zugeschnitten.
///
/// Das Layout-Feld ist genau so breit wie die Münze — der durchsichtige Rand
/// der Datei ragt darüber hinaus, ohne Platz zu belegen. Geklippt werden muss
/// er nicht, weil er nichts zeichnet.
class _Coiny extends StatelessWidget {
  final String datei;
  final double durchmesser;

  const _Coiny({required this.datei, required this.durchmesser});

  @override
  Widget build(BuildContext context) {
    final massstab = durchmesser / _kCoinyInhaltBreite;
    return SizedBox(
      width: durchmesser,
      height: durchmesser,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.translate(
          offset:
              Offset(-_kCoinyInhaltX * massstab, -_kCoinyInhaltY * massstab),
          child: SizedBox(
            width: _kCoinyDateiBreite * massstab,
            height: _kCoinyDateiHoehe * massstab,
            child: Image.asset(
              'assets/icons/deko/$datei.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
