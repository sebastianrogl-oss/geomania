import 'dart:math';

// ── Wackeln bei falscher Antwort ─────────────────────────────────────────────
//
// Stand bis zur Auslagerung in station_quiz_screen.dart. Es liegt jetzt hier,
// weil AntwortButton (widgets/antwort_button.dart) darauf aufbaut und der
// Knopf seinerseits ausserhalb des Quiz gebraucht wird — auf den
// Willkommens-Karten, die eine echte Frage nachstellen.

/// Dauer des Wackelns bei falscher Antwort.
///
/// Vorher 150 ms — das war der Grund, warum auf dem Gerät praktisch nichts zu
/// sehen war: bei 60 fps sind 150 ms nur 9 Frames, und da die Amplitude
/// zusätzlich mit exp(-5t) abklang, war schon ab Frame 3 alles vorbei (siehe
/// [wackelOffset]). Übrig blieb ein Ausschlag von rund 3 px über 2 Frames —
/// technisch lief die Animation, sichtbar war sie nicht.
const kWackelDauer = Duration(milliseconds: 400);

/// Gedämpftes Wackeln für eine falsch angetippte Antwort — 3 Ausschläge über
/// die volle Animationsdauer, Amplitude klingt exponentiell ab. [t] läuft von
/// 0.0 bis 1.0.
///
/// Amplitude (6→11 px) und Dämpfung (exp(-5t)→exp(-2.5t)) wurden zusammen mit
/// [kWackelDauer] angehoben, damit die Bewegung tatsächlich wahrnehmbar ist:
/// mit diesen Werten liegt der erste Ausschlag bei rund 9 px und auch der
/// dritte noch bei rund 4 px, statt wie zuvor nach zwei Frames unter die
/// Sichtbarkeitsschwelle zu fallen. Der abschließende Wert bei t=1.0 bleibt
/// praktisch 0, der Knopf kehrt also exakt an seine Position zurück.
double wackelOffset(double t) {
  final gedaempft = exp(-t * 2.5);
  return sin(t * pi * 6) * 11 * gedaempft;
}
