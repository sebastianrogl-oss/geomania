import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Die animierte Streak-Flamme für kleine Anzeigen (Lernpfad-Header,
/// Profil-Kachel).
///
/// Nutzt dieselbe Lottie-Datei wie die große Streak-Feier
/// (widgets/streak_feier_overlay.dart), ist davon aber unabhängig — die Feier
/// steuert ihre Flamme selbst über einen eigenen Ticker, weil sie das Tempo
/// ändert. Hier genügt eine schlichte Endlosschleife in Normalgeschwindigkeit.
///
/// [groesse] gilt für Höhe UND Breite: die Komposition ist 300x250, wird per
/// BoxFit.contain eingepasst und bleibt damit unverzerrt. Der Aufrufer setzt
/// denselben Wert, den zuvor die Schriftgröße des Emojis hatte, sodass sich
/// am Layout nichts verschiebt.
/// Schriftgröße der Zahl als Anteil der Flammengröße.
/// Bei 139px Flamme ergibt das rund 27px Schrift.
const _kZahlAnteil = 0.1957;

/// Versatz der Zahl nach unten, als Anteil der Flammengröße.
///
/// Die Flamme läuft nach oben spitz zu; mittig zentriert säße die Zahl in
/// der schmalen Spitze. Dieser Versatz schiebt sie in den breiten unteren
/// Bereich, wo sie vollständig von Flamme umgeben ist.
/// Bei 139px Flamme ergibt das rund 60px Versatz.
const _kZahlVersatzAnteil = 0.429;

/// Versatz der Zahl nach rechts, als Anteil der Flammengröße.
/// Bei 139px Flamme rund 5px.
const _kZahlVersatzRechtsAnteil = 0.036;

/// Breite, die der Zahl an ihrer Position zur Verfügung steht — als Anteil
/// der Flammengröße.
///
/// Passt die Zahl nicht hinein (zwei-, dreistellige Streaks), verkleinert
/// die FittedBox sie automatisch so weit wie nötig. Einstellige Zahlen
/// bleiben unangetastet, weil scaleDown nur verkleinert.
const _kZahlMaxBreiteAnteil = 0.40;

/// Farbe der Zahl in der Flamme.
///
/// Dunkelorange statt Weiß: der Flammenkern ist hell, eine dunkle Schrift
/// hebt sich dort deutlicher ab. Von den drei erwogenen Tönen ist dies der
/// dunkelste (Alternativen: 0xFFCC5500, 0xFFE05A00) — er bleibt warm, setzt
/// sich aber auch gegen die hellsten Stellen des Kerns noch durch.
const _kZahlFarbe = Color(0xFFB34700);

/// Farbe der Zahl auf der grauen Flamme (Streak 0). Dunkelorange würde auf
/// dem grauen Grund fehl am Platz wirken; Schwarz passt zur Textfarbe der App.
const _kZahlFarbeErloschen = Color(0xFF1A1A1A);

class StreakFlamme extends StatelessWidget {
  final double groesse;

  /// Optionale Zahl, die IN der Flamme steht (Profil-Kachel). Ohne Angabe
  /// zeigt das Widget nur die Animation (Lernpfad-Kopfzeile).
  final int? zahl;

  /// Erzwingt die graue Flamme. Für Stellen, die ihre Zahl nicht selbst
  /// anzeigen und den Streak deshalb nicht aus [zahl] ableiten können —
  /// etwa die Kopfzeile im Lernpfad, wo die Zahl daneben steht.
  final bool erloschen;

  /// Feste Schriftgröße der Zahl. Ohne Angabe skaliert sie mit der Flamme.
  /// Die Profil-Kachel setzt hier denselben Wert wie Stationsbutton und
  /// Münze, damit die drei Zahlen nebeneinander gleich groß erscheinen.
  final double? zahlGroesse;

  const StreakFlamme({
    super.key,
    required this.groesse,
    this.zahl,
    this.erloschen = false,
    this.zahlGroesse,
  });

  @override
  Widget build(BuildContext context) {
    final g = groesse;
    // Bei Streak 0 brennt nichts: dann die graue Variante derselben
    // Animation, wie sie auch die Streak-Feier für den Ausgangszustand nutzt.
    final grau = erloschen || zahl == 0;
    final datei = grau
        ? 'assets/animations/flamme_grau.json'
        : 'assets/animations/flamme_rot.json';
    // Auf schmalen Geräten ist die Kachel enger als die gewünschte Größe.
    // FittedBox skaliert dann herunter, statt überzulaufen.
    //
    // Bewusst KEIN LayoutBuilder: der löst während des Layouts eine erneute
    // Layout-Berechnung aus, sobald Lottie sein Asset asynchron nachlädt —
    // das lässt den umgebenden IndexedStack in einer Endlosschleife hängen
    // ('!_debugDoingThisLayout'), und die Oberfläche reagiert nicht mehr.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: g,
        height: g,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Lottie.asset(
              datei,
              width: g,
              height: g,
              repeat: true,
              fit: BoxFit.contain,
              // Fällt die Datei aus, bleibt das Emoji als Rückfall — die
              // Anzeige verliert dadurch nichts an Aussage.
              errorBuilder: (context, fehler, stack) => Center(
                child: Text('🔥', style: TextStyle(fontSize: g * 0.8)),
              ),
            ),
            if (zahl != null)
              Padding(
                padding: EdgeInsets.only(
                  top: g * _kZahlVersatzAnteil,
                  left: g * _kZahlVersatzRechtsAnteil,
                ),
                // Feste Breite plus scaleDown: mehrstellige Streaks
                // schrumpfen automatisch so weit, dass sie in die Flamme
                // passen — einstellige bleiben unverändert groß.
                child: SizedBox(
                  width: g * _kZahlMaxBreiteAnteil,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$zahl',
                      // Kein Textschatten mehr: er diente dem Kontrast der
                      // weißen Schrift auf hellem Grund. Die dunkle Farbe
                      // trägt den Kontrast jetzt selbst, ein Schatten würde
                      // die Kanten nur schmutzig wirken lassen.
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: zahlGroesse ?? g * _kZahlAnteil,
                        fontWeight: FontWeight.w900,
                        color: grau ? _kZahlFarbeErloschen : _kZahlFarbe,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
