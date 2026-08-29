import 'package:flutter/material.dart';


// ── Wischbare Karten ─────────────────────────────────────────────────────────
//
// Die gemeinsame Bauform für Kartenstapel, die man seitlich durchwischt.
// Herkunft ist der Willkommens-Screen; die Ergebnis-Ansichten der vier
// Tages-Challenges nutzen dieselben Teile, damit sich beides gleich anfühlt.
//
// Hier liegen nur die Hülle und die Punktreihe. Was IN einer Karte steht,
// bringt der Aufrufer mit — die Willkommens-Karten zeigen Bauteile der App,
// die Challenge-Karten Runden und Punkte.
//
// EINE BILDSCHIRMHÖHE JE KARTE, KEIN SCROLLEN. Der Stapel gibt jeder Seite
// denselben Kasten; wie viel Inhalt eine Karte trägt, kann die Höhe der
// Fläche also nicht beeinflussen. Passt der Inhalt nicht, ist die Aufteilung
// falsch — nicht die Karte zu klein.

/// Optik der Karte: abgerundetes Rechteck mit dezentem Rand.
///
/// Bewusst OHNE den harten 3D-Schatten der Knöpfe: Die Karte liegt auf dem
/// Hintergrund, und ein Schlagschatten machte daraus ein Objekt, das über der
/// Fläche schwebt, statt eines ruhigen Blattes darauf.
const double kWischKartenRadius = 20;
const double kWischKartenRand = 1.5;
const Color kWischKartenRandFarbe = Color(0xFFD0D0CB);
const double kWischKartenInnenrand = 18;

/// Seitenrand des Bildschirms — die Karte soll den Bildschirm ausfüllen und
/// nicht als kleines Kästchen in der Mitte schweben.
const double kWischSeitenrand = 12;

/// Punktreihe unter der Karte. Der aktive Punkt ist ein Strich statt eines
/// grösseren Punktes — er zeigt damit auch, wie weit man gekommen ist.
const double kWischPunkt = 8;
const double kWischPunktAktiv = 22;
const double kWischPunktLuecke = 6;
const double kWischPunktZeile = 28;

const Color _kAkzent = Color(0xFF4A9E4A);

/// Wie viele gleichartige Zeilen auf eine Karte passen.
///
/// Die Ergebnis-Ansichten der Challenges müssen ihre Runden auf Karten
/// verteilen, BEVOR die Karte gebaut wird — die Zahl der Karten steht ja
/// vorher fest. Gemessen werden kann da noch nichts, deshalb wird gerechnet:
/// aus der Bildschirmhöhe, dem Platz, den Kopfzeile, Punktreihe, Knopf und
/// Ränder davon abziehen, und der Höhe einer Zeile bei der eingestellten
/// Schrift.
///
/// [zeilenHoehe] ist die Höhe EINER Zeile bei Schriftskala 1 — der Aufrufer
/// kennt sein Zeilenformat, dieser Baustein nicht.
///
/// [abzugOben] ist der Platz, den der Aufrufer ÜBER dem Stapel belegt. In den
/// Ergebnis-Ansichten der Challenges steht dort die Punktzahl mit der
/// Ranglisten-Einordnung, und die ist der grösste Brocken der ganzen Seite.
///
/// [mindestens] ist voreingestellt 2: Eine Karte mit einer einzigen Zeile
/// wäre kein Kartenstapel mehr, sondern eine Diashow. Wo eine „Zeile" selbst
/// schon ein grosser Block ist — die Länderkarten im Portfolio etwa —, darf
/// der Aufrufer auf 1 heruntergehen; dort ist eine Karte je Block genau
/// richtig.
int wischZeilenProKarte(
  BuildContext context, {
  required double zeilenHoehe,
  double kopfHoehe = 46,
  double abzugOben = 0,
  int mindestens = 2,
  int hoechstens = 6,
}) {
  final schirm = MediaQuery.sizeOf(context).height;
  final skala = MediaQuery.textScalerOf(context).scale(1.0);
  // Abzug für alles ausserhalb der Karte: Ergebnis-Kopfzeile (~52),
  // Punktreihe, Knopfstreifen (~72) und die Ränder dazwischen. Grosszügig
  // gerundet — lieber eine Zeile weniger als eine abgeschnittene.
  const drumherum = 52 + kWischPunktZeile + 72 + 40;
  final innen = schirm -
      drumherum -
      abzugOben -
      2 * kWischKartenInnenrand -
      kopfHoehe * skala;
  final passt = (innen / (zeilenHoehe * skala)).floor();
  return passt.clamp(mindestens, hoechstens);
}

/// Die Punktreihe unter dem Stapel.
///
/// Die [FittedBox] ist für lange Stapel da: Die Ergebnis-Ansicht einer
/// Challenge kann je nach Spielverlauf ein Dutzend Karten haben, und auf
/// einem 320 px breiten Schirm liefe die Reihe sonst über. Sie wird dann als
/// Ganzes kleiner, statt umzubrechen oder abgeschnitten zu werden.
class WischPunktreihe extends StatelessWidget {
  final int anzahl;
  final int aktiv;

  const WischPunktreihe({super.key, required this.anzahl, required this.aktiv});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kWischPunktZeile,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < anzahl; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin:
                    const EdgeInsets.symmetric(horizontal: kWischPunktLuecke / 2),
                width: i == aktiv ? kWischPunktAktiv : kWischPunkt,
                height: kWischPunkt,
                decoration: BoxDecoration(
                  color: i == aktiv ? _kAkzent : kWischKartenRandFarbe,
                  borderRadius: BorderRadius.circular(kWischPunkt / 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Die weisse Kartenfläche.
///
/// `width: double.infinity` ist Pflicht und keine Vorsicht: Ohne das schrumpft
/// die Karte auf ihre Inhaltsbreite, und ein Stapel aus verschieden breiten
/// Karten springt beim Wischen seitlich hin und her.
class WischKarte extends StatelessWidget {
  final Widget child;

  /// Innenrand. `null` nimmt [kWischKartenInnenrand] ringsum; wer sein Motiv
  /// bis an den Rand laufen lassen will, gibt `EdgeInsets.zero` an.
  final EdgeInsets? innenrand;

  /// Notbremse gegen Überlauf — KEIN Ersatz für eine richtige Aufteilung.
  ///
  /// Wie viele Zeilen auf eine Karte passen, muss der Aufrufer vorher
  /// ausrechnen ([wischZeilenProKarte]), und diese Rechnung arbeitet mit
  /// geschätzten Zeilenhöhen. Schätzungen gehen daneben: Beim grossen
  /// Schätzen bricht die Unterzeile auf schmalen Schirmen um, und die Karte
  /// lief um 12 px über — mit gelb-schwarzem Balken quer über die letzte
  /// Zeile.
  ///
  /// Mit dieser Bremse wird daraus ein Stück Scrollweg, das im Normalfall
  /// niemand braucht. Wer sie regelmässig zu sehen bekommt, hat die falsche
  /// Zeilenhöhe eingetragen.
  final bool notfallScrollen;

  const WischKarte({
    super.key,
    required this.child,
    this.innenrand,
    this.notfallScrollen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kWischKartenRadius),
        border:
            Border.all(color: kWischKartenRandFarbe, width: kWischKartenRand),
      ),
      // Innenradius: aussen minus Randbreite, sonst bliebe zwischen Inhalt und
      // Rahmen an den Ecken ein heller Zwickel stehen.
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(kWischKartenRadius - kWischKartenRand),
        child: Padding(
          padding: innenrand ?? const EdgeInsets.all(kWischKartenInnenrand),
          child: notfallScrollen
              ? SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: child,
                )
              : child,
        ),
      ),
    );
  }
}

/// Der Stapel: wischbare Karten mit Punktreihe darunter.
///
/// NUR DER STAPEL, kein Abschluss-Knopf. Er ersetzt eine gescrollte Liste
/// INNERHALB einer Ansicht — was darüber und darunter steht (Kopfzeile,
/// Punktzahl, Fertig-Knopf), bleibt an seinem Platz stehen und gehört dem
/// Aufrufer. Der Stapel füllt den Bereich, den er bekommt.
class WischKartenStapel extends StatefulWidget {
  /// Wird je Seite gebaut. [hoehe] ist der Kasten, den die Karte bekommt —
  /// wer seinen Inhalt daran ausrichten will, rechnet damit.
  final List<Widget Function(BuildContext context, double hoehe)> karten;

  const WischKartenStapel({super.key, required this.karten});

  @override
  State<WischKartenStapel> createState() => _WischKartenStapelState();
}

class _WischKartenStapelState extends State<WischKartenStapel> {
  final _seiten = PageController();
  int _seite = 0;

  @override
  void dispose() {
    _seiten.dispose();
    super.dispose();
  }

  /// Erst beim Einrasten, nicht während des Wischens — sonst spränge die
  /// Punktreihe auf halber Strecke um und wieder zurück, wenn jemand eine
  /// Wischbewegung abbricht.
  void _gewechselt(int i) {
    if (i != _seite) setState(() => _seite = i);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          // Der LayoutBuilder sitzt INNERHALB des Expanded, nicht darum
          // herum: So ist die gemeldete Höhe genau der Platz, der den Karten
          // bleibt — Punktreihe und Knopfstreifen sind schon abgezogen. Ein
          // LayoutBuilder aussen herum müsste beides selbst nachrechnen, und
          // die Rechnung ginge beim nächsten Umbau schief.
          child: LayoutBuilder(
            builder: (context, platz) => PageView.builder(
              controller: _seiten,
              onPageChanged: _gewechselt,
              itemCount: widget.karten.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.fromLTRB(
                    kWischSeitenrand, 0, kWischSeitenrand, 8),
                child: widget.karten[i](context, platz.maxHeight - 8),
              ),
            ),
          ),
        ),
        // Bei einer einzigen Karte entfällt die Punktreihe: Ein einzelner
        // Punkt zeigt nichts an, was man nicht ohnehin sähe, und der Platz
        // gehört besser der Karte. Das ist kein Sonderfall des Aufrufers —
        // ob ein Stapel nur eine Karte hat, hängt am Spielverlauf und
        // entscheidet sich erst hier.
        if (widget.karten.length > 1)
          WischPunktreihe(anzahl: widget.karten.length, aktiv: _seite),
      ],
    );
  }
}
