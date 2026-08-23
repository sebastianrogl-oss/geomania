import 'package:flutter/material.dart';

import '../data/lernpfad_data.dart';
import '../l10n/uebersetzungen.dart';
import '../theme/app_theme.dart';
import '../widgets/flaggen_widget.dart';
import '../widgets/maskottchen_animation.dart';
import '../widgets/muenze_widget.dart';
import '../widgets/lernpfad_station_button.dart';
import '../widgets/streak_flamme.dart';

// ── Maße ─────────────────────────────────────────────────────────────────────
//
// Leitgröße ist die vom LayoutBuilder gemeldete Höhe — nicht die Bildschirm-
// höhe, damit System- und Navigationsleiste nicht mitzählen. Daraus entsteht
// EIN Skalenfaktor, aus dem sich jede Größe und jeder Abstand ableitet. Wer
// den Screen luftiger will, dreht an _kBezugsHoehe oder an den Werten unten;
// nachziehen muss man nichts.
//
// Ausnahme sind die Flaggen: die hängen an der BREITE (siehe _Flaggenband).
// Ein hoher, aber schmaler Bildschirm würde sie sonst aus der Zeile drücken.

/// Höhe, für die die Werte unten gesetzt sind — annähernd die Höhe, die der
/// Inhalt bei Skala 1.0 tatsächlich braucht. Auf einem höheren Bildschirm
/// wächst alles, auf einem flacheren schrumpft es, begrenzt durch die beiden
/// Schranken.
///
/// Der Wert stieg von 640 auf 770, als Coiny, Flamme und Münze größer wurden:
/// bliebe er bei 640, wäre die Skala auf jedem Gerät zu groß gerechnet und
/// der Screen liefe unten über.
const double _kBezugsHoehe = 770;

/// Untere Schranke der Skala. Mit 0.72 (dem Wert zur Bezugshöhe 640) blieb
/// auf einem 320×480-Schirm für Coiny nur noch ein 33-px-Rest übrig, weil
/// alles andere zu groß gerechnet war und das Maskottchen als einziges
/// nachgibt. 0.66 verteilt den Mangel: Coiny bekommt dort wieder 59 px.
const double _kSkalaMin = 0.66;
const double _kSkalaMax = 1.15;

/// Schrift schrumpft gedämpfter als das Layout: unter dieser Schranke wird
/// sie auf kleinen Geräten unangenehm zu lesen.
const double _kTextSkalaMin = 0.88;

// Größen bei Skala 1.0 — im Layout jeweils × skala.
//
// Die drei Grafiken sind hier bewusst anders groß als dort, wo sie sonst
// vorkommen: die Münze wirkt neben Flamme und Button sonst zu klein, der
// Stationsbutton zu wuchtig. Das gilt NUR für diesen Screen — Profil und
// Lernpfad bleiben unberührt.
/// Coiny bekommt den Platz, den die schlankeren Rahmen und der entfallene
/// Flaggen-Rahmen frei machen. Der Wert ist nur der WUNSCH — auf flachen
/// Bildschirmen gibt das Flexible darunter nur das her, was übrig bleibt.
const double _kCoiny = 260; // war 198
const double _kFlamme = 132; // 110 × 1.2
const double _kMuenze = 126; // 84 × 1.5

/// Symbol IN der Münze. Bleibt bei seiner bisherigen Größe (die Hälfte der
/// alten 84er Münze) — die Münze wächst, das Abzeichen darauf nicht.
const double _kMuenzSymbol = 42;

/// Durchmesser des Stationsbuttons: 0.9 des Lernpfad-Maßes
/// ([kStationsButtonGroesse]).
const double _kStationsButton = kStationsButtonGroesse * 0.9;

/// Breite der Grafikspalte der Zeilen: so breit wie die größte Grafik, damit
/// die Texte daneben bündig stehen.
const double _kGrafikSpalte = _kMuenze;

// ── Rahmen der Zeilen ────────────────────────────────────────────────────────
//
// Fläche und Radius sind die der Statistik-Kacheln im Profil
// (widgets/statistik_kacheln.dart). Einen Rand haben die dort NICHT — der
// kommt hier dazu, damit die vier Zeilen sauber voneinander getrennt wirken,
// bleibt aber eine dünne, stark aufgehellte Linie. Kein harter Schatten wie
// bei den Knöpfen: das würde die Zeilen zu Schaltflächen machen, die sie
// nicht sind.
const Color _kZeilenFlaeche = Color(0xFFEAEAE5);
const double _kZeilenRadius = 14;
const double _kZeilenRandStaerke = 1;
const double _kZeilenRandDeckkraft = 0.12;

/// Innenabstand der Rahmen. Waagerecht bleibt es bei 10; senkrecht ist es
/// deutlich knapper, weil dort die Höhe knapp ist und der Rahmen die Grafik
/// nicht zusätzlich einrahmen muss — sie bringt ihren eigenen Rand mit.
const double _kZeilenInnenrandWaagerecht = 10;
const double _kZeilenInnenrandSenkrecht = 3;

// Abstände bei Skala 1.0.
const double _kAbstandCoinyTitel = 16;
const double _kAbstandTitelBand = 18;
const double _kAbstandBandZeile = 10;
const double _kAbstandZwischenZeilen = 12;
const double _kAbstandVorButton = 24;
const double _kSpalteZuText = 14;

// Schriftgrößen bei Textskala 1.0.
const double _kTitelGroesse = 22;
const double _kZeilenGroesse = 15;
const double _kButtonGroesse = 16;

/// Seitenrand — Bildschirm-Chrome, bleibt absolut.
const double _kSeitenrand = 24;

const _textDark = Color(0xFF1A1A1A);
const _accent = Color(0xFF4A9E4A);

/// Der einzige Erklär-Screen der App, gezeigt nach der Namensabfrage und vor
/// dem ersten Blick auf den Lernpfad.
///
/// Bewusst EIN Screen und keine mehrseitige Tour: eine Tour wischt man weg,
/// ohne sie zu lesen. Die Einzelheiten stehen ohnehin dort, wo man sie
/// braucht — die Kurzanleitung im Start-Sheet jeder Station, die ausführliche
/// Anleitung beim ersten Vorkommen der Modi mit eigener Bedienung, und die
/// Kennzahlen hinter einem Tipp auf den Kopfbereich.
///
/// Deshalb steht hier kein Fließtext mehr, sondern vier Zeilen — jede mit dem
/// ECHTEN Bauteil daneben, dem man später in der App begegnet: die Flaggen aus
/// dem Flaggenquiz, der Stationsbutton aus dem Lernpfad, die Streak-Flamme aus
/// der Kopfzeile, die Münze aus dem Abzeichen-System. Wer den Screen gesehen
/// hat, erkennt die Teile wieder, statt sie zweimal lernen zu müssen.
class WillkommenScreen extends StatelessWidget {
  final VoidCallback onFertig;

  const WillkommenScreen({super.key, required this.onFertig});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHintergrund,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final skala = (constraints.maxHeight / _kBezugsHoehe).clamp(
              _kSkalaMin,
              _kSkalaMax,
            );
            final textSkala = skala.clamp(_kTextSkalaMin, 1.0);
            final spalte = _kGrafikSpalte * skala;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                _kSeitenrand,
                8 * skala,
                _kSeitenrand,
                12 * skala,
              ),
              child: Column(
                // Oben ausgerichtet statt mittig: übrige Höhe sammelt sich
                // dadurch unten unter dem Knopf, statt sich je zur Hälfte
                // über und unter den Inhalt zu legen.
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Coiny gibt als erstes nach. Auf sehr flachen Bildschirmen
                  // (320×480) reicht der Platz sonst nicht — und dann soll
                  // lieber das Maskottchen kleiner werden als dass Text oder
                  // Knopf gestaucht werden oder ein Überlauf entsteht.
                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, platz) {
                        final gewuenscht = _kCoiny * skala;
                        return Center(
                          child: MaskottchenAnimation(
                            groesse: gewuenscht > platz.maxHeight
                                ? platz.maxHeight
                                : gewuenscht,
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: _kAbstandCoinyTitel * skala),

                  Text(
                    t('Schön, dass du da bist!'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _kTitelGroesse * textSkala,
                      fontWeight: FontWeight.w900,
                      color: _textDark,
                    ),
                  ),
                  SizedBox(height: _kAbstandTitelBand * skala),

                  // Blickfang: echte Flaggen, nacheinander eingeblendet. Sie
                  // sagen ohne ein Wort, worum die App geht.
                  //
                  // OHNE Rahmen: die Flaggen tragen ihre eigenen Kanten, eine
                  // graue Fläche darum macht daraus einen Kasten im Kasten.
                  Column(
                    children: [
                      _Flaggenband(
                        breite: constraints.maxWidth - 2 * _kSeitenrand,
                      ),
                      SizedBox(height: _kAbstandBandZeile * skala),
                      Text(
                        t('195 Länder entdecken'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _kZeilenGroesse * textSkala,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _kAbstandZwischenZeilen * skala),

                  // Die drei übrigen Zeilen, jede mit dem echten Bauteil aus
                  // der App links daneben.
                  _Zeile(
                    spalte: spalte,
                    skala: skala,
                    textSkala: textSkala,
                    text: t('Station für Station'),
                    // Buchstäblich derselbe Button wie im Lernpfad — dasselbe
                    // Widget, nicht eine zweite Fassung davon (siehe
                    // widgets/lernpfad_station_button.dart). Ohne onTap, also
                    // ohne Druck-Animation. Gezeigt wird die Flaggen-Station,
                    // passend zum Flaggenband darüber.
                    grafik: LernpfadStationButton(
                      modus: LernModus.flaggenQuizBild,
                      groesse: _kStationsButton * skala,
                    ),
                  ),
                  SizedBox(height: _kAbstandZwischenZeilen * skala),
                  _Zeile(
                    spalte: spalte,
                    skala: skala,
                    textSkala: textSkala,
                    text: t('Jeden Tag dranbleiben'),
                    grafik: StreakFlamme(groesse: _kFlamme * skala),
                  ),
                  SizedBox(height: _kAbstandZwischenZeilen * skala),
                  _Zeile(
                    spalte: spalte,
                    skala: skala,
                    textSkala: textSkala,
                    text: t('Abzeichen verdienen'),
                    grafik: MuenzGrundlage(
                      groesse: _kMuenze * skala,
                      // Das Symbol des höchsten Abzeichens statt eines
                      // Sterns: die Zeile spricht jetzt von Abzeichen, ein
                      // Stern stünde für die andere Währung der App.
                      inhalt: Icon(
                        Icons.workspace_premium_rounded,
                        // Feste Größe statt Anteil der Münze: die Münze ist
                        // gewachsen, das Abzeichen darauf soll bleiben.
                        size: _kMuenzSymbol * skala,
                        color: kMuenzInhaltFarbe,
                      ),
                    ),
                  ),

                  SizedBox(height: _kAbstandVorButton * skala),
                  _LosGehtsButton(
                    onTap: onFertig,
                    skala: skala,
                    textSkala: textSkala,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Flaggenband ──────────────────────────────────────────────────────────────

/// Sechs Flaggen, eine je Kontinent, in bewusst unterschiedlichen Mustern:
/// Streifen (DE), Rautenfeld (BR), Kreis (JP), Vielfarbig (ZA), Wappenblatt
/// (CA), Sternbild (AU). Sie sollen auf den ersten Blick verschieden
/// aussehen, nicht als sechs Streifenflaggen verschwimmen.
const List<String> _kFlaggen = ['DE', 'BR', 'JP', 'ZA', 'CA', 'AU'];

/// Höhe einer Flagge als Anteil ihrer Breite.
///
/// 4:3, weil das country_flags-Paket seine Grafiken mit BoxFit.contain in
/// diesem Verhältnis zeichnet (siehe widgets/flaggen_widget.dart). Bei jedem
/// anderen Wert bliebe innerhalb der Box ein durchsichtiger Rand — und der
/// dünne Rahmen läge dann eben NICHT an der Flaggenkante, sondern ein Stück
/// daneben.
const double _kFlaggenVerhaeltnis = 0.75;

/// Lücke zwischen zwei Flaggen, als Anteil einer Flaggenbreite.
const double _kFlaggenLuecke = 0.13;

const double _kFlaggeMin = 26;
const double _kFlaggeMax = 64;

/// Haarlinie an der Flaggenkante — feste Breite, nicht mitskaliert: eine
/// Linie soll auf jedem Gerät eine Linie bleiben und kein Balken.
const double _kFlaggenRand = 1;
const double _kFlaggenRadius = 4;

// Einblenden: jede Flagge kommt einzeln, von leicht unten. Ruhig genug, dass
// es nicht vom Text ablenkt — nach gut einer Sekunde steht das Band still.
const Duration _kBandDauer = Duration(milliseconds: 1100);
const double _kBandVersatz = 0.62; // Anteil der Dauer, über den gestaffelt wird
const double _kBandHub = 10; // px, um die eine Flagge von unten hochkommt

class _Flaggenband extends StatefulWidget {
  /// Verfügbare Breite. Die Flaggengröße hängt AN IHR, nicht am Höhen-
  /// Skalenfaktor: sonst passt das Band auf schmalen, hohen Geräten nicht
  /// mehr in die Zeile.
  final double breite;

  const _Flaggenband({required this.breite});

  @override
  State<_Flaggenband> createState() => _FlaggenbandState();
}

class _FlaggenbandState extends State<_Flaggenband>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _kBandDauer,
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anzahl = _kFlaggen.length;
    // Breite + Lücken füllen die Zeile genau aus — dadurch kann das Band
    // nicht überlaufen, egal wie schmal der Bildschirm ist.
    final breite = (widget.breite / (anzahl + (anzahl - 1) * _kFlaggenLuecke))
        .clamp(_kFlaggeMin, _kFlaggeMax);
    final luecke = breite * _kFlaggenLuecke;

    // Zeitfenster je Flagge: alle starten versetzt, die letzte endet mit dem
    // Controller.
    final schritt = _kBandVersatz / (anzahl - 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < anzahl; i++) ...[
          if (i > 0) SizedBox(width: luecke),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, kind) {
              final t = CurvedAnimation(
                parent: _ctrl,
                curve: Interval(
                  i * schritt,
                  i * schritt + (1 - _kBandVersatz),
                  curve: Curves.easeOutCubic,
                ),
              ).value;
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * _kBandHub),
                  child: kind,
                ),
              );
            },
            child: _Flagge(iso: _kFlaggen[i], breite: breite),
          ),
        ],
      ],
    );
  }
}

/// Eine Flagge in der 3D-Sprache der App: dunkler Rand, harter Schatten.
class _Flagge extends StatelessWidget {
  final String iso;
  final double breite;

  const _Flagge({required this.iso, required this.breite});

  @override
  Widget build(BuildContext context) {
    final hoehe = breite * _kFlaggenVerhaeltnis;

    // Nur eine Haarlinie auf der Kante, kein 3D-Rahmen mehr: sechs Flaggen
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

// ── Rahmen ───────────────────────────────────────────────────────────────────

/// Das abgerundete Rechteck um eine Zeile.
///
/// Fläche und Radius sind von den Statistik-Kacheln im Profil übernommen
/// (widgets/statistik_kacheln.dart): #EAEAE5 und Radius 14. Der dünne Rand
/// kommt hier dazu — die Profil-Kacheln haben keinen, hier trennt er die vier
/// Zeilen sichtbar voneinander, ohne dass sie wie Knöpfe aussehen.
class _Rahmen extends StatelessWidget {
  final Widget child;
  const _Rahmen({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: _kZeilenInnenrandWaagerecht,
        vertical: _kZeilenInnenrandSenkrecht,
      ),
      decoration: BoxDecoration(
        color: _kZeilenFlaeche,
        borderRadius: BorderRadius.circular(_kZeilenRadius),
        border: Border.all(
          color: _textDark.withValues(alpha: _kZeilenRandDeckkraft),
          width: _kZeilenRandStaerke,
        ),
      ),
      child: child,
    );
  }
}

// ── Zeile ────────────────────────────────────────────────────────────────────

/// Grafik links in fester Spaltenbreite, EINE Zeile Text rechts.
///
/// Alle drei Grafiken sind unterschiedlich groß und stammen aus verschiedenen
/// Widgets; die gemeinsame Spaltenbreite ist es, die die Zeilen trotzdem
/// bündig ausrichtet.
class _Zeile extends StatelessWidget {
  final Widget grafik;
  final String text;
  final double spalte;
  final double skala;
  final double textSkala;

  const _Zeile({
    required this.grafik,
    required this.text,
    required this.spalte,
    required this.skala,
    required this.textSkala,
  });

  @override
  Widget build(BuildContext context) {
    return _Rahmen(
      child: Row(
        children: [
          SizedBox(
            width: spalte,
            height: spalte,
            child: Center(child: grafik),
          ),
          SizedBox(width: _kSpalteZuText * skala),
          Expanded(
            // Die englischen Fassungen sind mal kürzer, mal länger als die
            // deutschen. Statt zu raten, ob beide passen: was nicht passt,
            // wird kleiner gesetzt statt umgebrochen oder abgeschnitten.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                maxLines: 1,
                style: TextStyle(
                  fontSize: _kZeilenGroesse * textSkala,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hauptaktion ──────────────────────────────────────────────────────────────

/// Hauptaktion im 3D-Muster der App (vgl. challenge_fertig_button.dart und
/// erinnerung_dialog.dart).
class _LosGehtsButton extends StatelessWidget {
  final VoidCallback onTap;
  final double skala;
  final double textSkala;

  const _LosGehtsButton({
    required this.onTap,
    required this.skala,
    required this.textSkala,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 15 * skala),
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
          style: TextStyle(
            fontSize: _kButtonGroesse * textSkala,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
