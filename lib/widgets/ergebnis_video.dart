import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

// ── Ergebnis-Videos ──────────────────────────────────────────────────────────
//
// Halbzeit-Moment und Schluss-Ansicht zeigen beide ein Video, das zum Ergebnis
// des Spielers passt. Damit Video und Text niemals auseinanderlaufen, liegt die
// Einstufung hier zentral: sowohl die Sprüche (halbzeit_sprueche.dart) als auch
// die Überschrift (station_abschluss_screen.dart) und die Videoauswahl leiten
// sich aus derselben Funktion [ergebnisStufe] ab.

/// Wie gut der Spieler abgeschnitten hat. Die Schwellen entsprechen exakt
/// denen, nach denen zuvor schon Überschrift und Spruch gewählt wurden.
enum ErgebnisStufe { perfekt, stark, solide, aufholen }

/// Einzige Stelle, an der über die Ergebnis-Schwellen entschieden wird.
///
/// Ohne beantwortete Fragen gibt es keine Quote — dann [ErgebnisStufe.solide]
/// als neutrale Mitte, wie es Überschrift und Spruch vorher auch taten.
ErgebnisStufe ergebnisStufe(int richtig, int gesamt) {
  if (gesamt == 0) return ErgebnisStufe.solide;
  if (richtig == gesamt) return ErgebnisStufe.perfekt;
  final anteil = richtig / gesamt;
  if (anteil >= 0.75) return ErgebnisStufe.stark;
  if (anteil >= 0.5) return ErgebnisStufe.solide;
  return ErgebnisStufe.aufholen;
}

/// Videos der Schluss-Ansicht, nach Ergebnis.
const _kAbschlussVideos = <ErgebnisStufe, String>{
  ErgebnisStufe.perfekt: 'assets/videos/video_1.mp4',
  ErgebnisStufe.stark: 'assets/videos/video_2.mp4',
  ErgebnisStufe.solide: 'assets/videos/video_3.mp4',
  ErgebnisStufe.aufholen: 'assets/videos/video_4.mp4',
};

/// Videos des Halbzeit-Moments, nach bisherigem Ergebnis.
const _kHalbzeitVideos = <ErgebnisStufe, String>{
  ErgebnisStufe.perfekt: 'assets/videos/video_5.mp4',
  ErgebnisStufe.stark: 'assets/videos/video_6.mp4',
  ErgebnisStufe.solide: 'assets/videos/video_7.mp4',
  ErgebnisStufe.aufholen: 'assets/videos/video_8.mp4',
};

String abschlussVideo(int richtig, int gesamt) =>
    _kAbschlussVideos[ergebnisStufe(richtig, gesamt)]!;

String halbzeitVideo(int richtig, int gesamt) =>
    _kHalbzeitVideos[ergebnisStufe(richtig, gesamt)]!;

// ── Kantenkaschierung ────────────────────────────────────────────────────────
//
// Der Videodecoder trifft den Hintergrundton minimal anders als eine
// Flutter-Farbfläche, wodurch sich die Videokante als dünne Linie abzeichnet.
// Zwei überlagerte Verläufe blenden die äußeren 8 % jeder Seite in den
// Screen-Hintergrund aus, sodass es keinen harten Übergang mehr gibt.
//
// Der transparente Zwischenwert ist bewusst kHintergrund mit Alpha 0 und nicht
// Colors.transparent: letzteres ist transparentes SCHWARZ, und der Verlauf
// liefe dann sichtbar über einen Grauschleier statt sauber auszublenden.
final _kTransparent = kHintergrund.withValues(alpha: 0);
const _kVerlaufStops = [0.0, 0.08, 0.92, 1.0];

final _kVerlaufSenkrecht = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: _kVerlaufStops,
  colors: [kHintergrund, _kTransparent, _kTransparent, kHintergrund],
);

final _kVerlaufWaagerecht = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  stops: _kVerlaufStops,
  colors: [kHintergrund, _kTransparent, _kTransparent, kHintergrund],
);

/// Das Ergebnis-Video als Ersatz für den bisherigen Bild-Platzhalter.
///
/// Ressourcen: Der [VideoPlayerController] gehört ausschließlich diesem Widget.
/// Er entsteht in `initState` — also erst, wenn der Screen gebaut wird und das
/// Ergebnis feststeht — und wird in `dispose` wieder freigegeben. Es liegt nie
/// mehr als ein Video im Speicher; die anderen sieben werden nicht angefasst.
///
/// [pfad] wird bewusst nur einmal beim Anlegen ausgewertet. Ändert er sich doch
/// (etwa durch einen Rebuild mit anderem Ergebnis), tauscht [didUpdateWidget]
/// den Controller aus und gibt den alten frei.
///
/// ── Warum hier kein Platzhalter-Bild mehr steht ───────────────────────────
///
/// Vorher stand an dieser Stelle ein Standbild von Coiny, solange das Video
/// lud. Weil der Controller erst in `initState` entsteht — also erst, wenn der
/// Screen schon sichtbar ist — sah man dieses Bild rund eine halbe Sekunde
/// lang und danach einen harten Schnitt auf das Video. Ein Standbild, das von
/// einem Video abgelöst wird, ist genau der sichtbare Wechsel, den man nicht
/// haben will.
///
/// Deshalb bleibt die Fläche jetzt leer (also im Screen-Hintergrund) und das
/// Video blendet sich ein, sobald es bereit ist. Der Platz ist über [hoehe]
/// die ganze Zeit reserviert, es springt also nichts. Laedt das Video gar
/// nicht, bleibt die Flaeche leer — das faellt weniger auf als ein Standbild,
/// das offensichtlich auf etwas wartet.
class ErgebnisVideo extends StatefulWidget {
  /// Pfad des Videos, das gezeigt wird.
  final String pfad;

  /// Höhe der Fläche — identisch mit der des vorherigen Platzhalters.
  final double hoehe;

  const ErgebnisVideo({
    super.key,
    required this.pfad,
    required this.hoehe,
  });

  @override
  State<ErgebnisVideo> createState() => _ErgebnisVideoState();
}

/// Dauer, über die sich das fertige Video einblendet.
const _kEinblendDauer = Duration(milliseconds: 300);

class _ErgebnisVideoState extends State<ErgebnisVideo> {
  VideoPlayerController? _ctrl;

  @override
  void initState() {
    super.initState();
    _starten(widget.pfad);
  }

  @override
  void didUpdateWidget(ErgebnisVideo alt) {
    super.didUpdateWidget(alt);
    if (alt.pfad != widget.pfad) {
      final vorher = _ctrl;
      _ctrl = null;
      vorher?.dispose();
      _starten(widget.pfad);
    }
  }

  Future<void> _starten(String pfad) async {
    // Misst, wie lange es vom Erscheinen des Screens bis zum ersten Bild
    // dauert — die Zahl beantwortet, ob das Video flüssig startet oder sichtbar
    // nachlädt. debugPrint ist im Release-Build ohnehin still.
    final uhr = Stopwatch()..start();
    final ctrl = VideoPlayerController.asset(pfad);
    try {
      await ctrl.initialize();
      debugPrint('[Ergebnis-Video] $pfad bereit nach '
          '${uhr.elapsedMilliseconds} ms');
    } catch (fehler) {
      // Nicht ladbar (fehlende Datei, Codec) — der Platzhalter bleibt stehen,
      // der Screen funktioniert unverändert weiter.
      debugPrint('[Ergebnis-Video] $pfad nicht ladbar: $fehler');
      await ctrl.dispose();
      return;
    }
    // Zwischen initialize() und hier kann das Widget längst weg sein (der
    // Spieler tippt auf Weiter). Dann den frisch erzeugten Controller sofort
    // freigeben, statt ihn in _ctrl abzulegen, wo dispose() ihn nicht mehr
    // erwischen würde — sonst bliebe genau hier eine Controller-Leiche.
    if (!mounted || pfad != widget.pfad) {
      await ctrl.dispose();
      return;
    }
    await ctrl.setLooping(true);
    await ctrl.setVolume(0);
    await ctrl.play();
    if (!mounted || pfad != widget.pfad) {
      await ctrl.dispose();
      return;
    }
    setState(() => _ctrl = ctrl);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _ctrl = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    final bereit = ctrl != null && ctrl.value.isInitialized;
    return SizedBox(
      height: widget.hoehe,
      child: AnimatedOpacity(
        opacity: bereit ? 1 : 0,
        duration: _kEinblendDauer,
        child: !bereit
          ? const SizedBox.expand()
          // Nur der VideoPlayer selbst: keine Abspielleiste, kein Play-Knopf,
          // nichts Anklickbares — es soll wie eine Animation wirken.
          : Center(
              child: AspectRatio(
                aspectRatio: ctrl.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(ctrl),
                    // Der Stack sitzt bewusst INNERHALB des AspectRatio, nicht
                    // um die ganze SizedBox: nur so deckt sich Positioned.fill
                    // exakt mit der Videofläche und die Farbstops liegen an
                    // deren Rändern statt irgendwo im freien Hintergrund.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration:
                              BoxDecoration(gradient: _kVerlaufSenkrecht),
                          child: DecoratedBox(
                            decoration:
                                BoxDecoration(gradient: _kVerlaufWaagerecht),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}
