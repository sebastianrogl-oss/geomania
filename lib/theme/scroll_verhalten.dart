import 'package:flutter/material.dart';

/// Einheitliches Nachfedern auf allen Screens und beiden Plattformen.
///
/// ══ WAS VORHER PASSIERTE ════════════════════════════════════════════════
///
/// Die App setzte gar kein Scroll-Verhalten, jeder Screen bekam also die
/// Voreinstellung der Plattform. Auf Android heisst das: [ClampingScrollPhysics]
/// — der Inhalt bleibt am Ende hart stehen — plus der Dehn-Effekt von
/// Android 12 aufwärts, der den gezeichneten Inhalt beim Überziehen streckt.
///
/// Auf einer grossen, ruhigen Fläche wie dem Lernpfad sieht dieses Strecken
/// aus wie ein weiches Nachfedern. Im Profil, wo Karten mit Rändern,
/// Schatten und einer laufenden Lottie-Flamme untereinanderstehen, verzerrt
/// dieselbe Bewegung lauter Kanten gleichzeitig — und das wirkt als Zittern.
/// Derselbe Effekt, zwei völlig verschiedene Eindrücke.
///
/// ══ DIE LÖSUNG STEHT AN EINER STELLE ════════════════════════════════════
///
/// Statt in jedem Screen `physics:` zu setzen — und beim nächsten neuen
/// Screen wieder zu vergessen — hängt das Verhalten an der MaterialApp.
/// Damit federn Lernpfad, Profil, Einstellungen, Münzmappe und Rangliste
/// gleich, auf Android wie auf iOS.
///
/// ── Warum kein Überzieh-Anzeiger mehr ───────────────────────────────────
///
/// [buildOverscrollIndicator] gibt das Kind unverändert zurück, unterdrückt
/// also Leuchten und Dehnen. Beides ist die Android-Antwort auf hart
/// stehenden Inhalt: Es zeigt "hier ist Schluss", weil sich sonst nichts
/// bewegt. Mit federnder Physik bewegt sich der Inhalt selbst — ein Anzeiger
/// obendrauf wäre die zweite Antwort auf dieselbe Frage. iOS hat aus dem
/// gleichen Grund nie einen gehabt.
///
/// ── Was NICHT betroffen ist ─────────────────────────────────────────────
///
/// Eine im Screen ausdrücklich gesetzte Physik gewinnt weiterhin, denn
/// Flutter legt sie über die hier gelieferte (`physics.applyTo(...)`):
///
///   * [NeverScrollableScrollPhysics] bleibt unbeweglich — die inneren
///     Seiten der Münzmappe und des Willkommens-Screens.
///   * Die Notbremse in `widgets/ergebnis_karten.dart` bleibt klemmend. Dort
///     geht es um wenige Pixel Überlauf INNERHALB einer Wischkarte; ein
///     federnder Inhalt in einer festen Karte sähe nach Fehler aus.
///   * [AlwaysScrollableScrollPhysics] in der Rangliste federt jetzt mit,
///     weil es die hier gelieferte Physik als Grundlage bekommt.
class AppScrollVerhalten extends MaterialScrollBehavior {
  const AppScrollVerhalten();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
