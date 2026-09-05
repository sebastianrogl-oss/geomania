import 'package:flutter/material.dart';

/// Läuft gerade eine Scroll-Bewegung?
///
/// ══ WOFÜR ══════════════════════════════════════════════════════════════
///
/// Die Streak-Flamme ist eine Lottie-Animation, und das Lottie-Widget baut
/// sich bei JEDEM Animationsframe komplett neu auf. Nachgewiesen im
/// Debug-Protokoll:
///
///   Rebuilding Lottie(dirty, state: _LottieState#… (tickers: tracking 1))
///
/// Rund 30-mal pro Sekunde, dauerhaft, auch wenn niemand den Screen anfasst.
/// Solange nichts in Bewegung ist, fällt das nicht auf. Beim Überziehen am
/// Listenende schon: Dort verschiebt iOS den gesamten Inhalt federnd, und
/// dieselbe Fläche muss zugleich neu gezeichnet werden. Fällt dabei ein Frame
/// aus, springt die Feder eine Position weiter — und genau das sieht man als
/// Zittern.
///
/// Belegt ist das mit einem Versuchs-Build: Mit einem stehenden Bild statt
/// der Animation war das Profil ruhig, sonst unverändert.
///
/// ══ WARUM EIN GLOBALES SIGNAL ══════════════════════════════════════════
///
/// Die Flamme steckt drei Ebenen tief (Screen → StatistikKacheln → _Flamme →
/// StreakFlamme). Den Scroll-Zustand durchzureichen hiesse, drei Widgets um
/// einen Parameter zu erweitern, den sie selbst nicht brauchen — und beim
/// nächsten Einsatzort wieder daran zu denken.
///
/// Dieselbe Bauart nutzt die App schon an mehreren Stellen
/// (FortschrittService.resetSignal, ProfilbildService.geaendert,
/// LocaleService.sprache).
///
/// ══ WARUM NICHT EIN EIGENER ANIMATIONCONTROLLER ════════════════════════
///
/// Naheliegend wäre, die Animation über `Lottie(controller: ...)` selbst zu
/// treiben, damit nur gezeichnet statt neu gebaut wird. Das hilft nicht — im
/// Paket (lottie 3.5.0, lib/src/lottie.dart) steht:
///
///   `get _progressAnimation => widget.controller ?? _autoAnimation;`
///
/// Beide Wege landen im selben Listener, und der ruft `setState`. Ein
/// eigener Controller ändert am Neubau nichts.
class ScrollSignal {
  /// True, solange irgendwo gescrollt wird — einschliesslich des Nachfederns
  /// am Ende, denn die Bewegung endet erst mit der ScrollEndNotification.
  static final laeuft = ValueNotifier<bool>(false);

  /// Legt sich um einen scrollbaren Bereich und pflegt [laeuft].
  ///
  /// Absichtlich an [ScrollStartNotification] und [ScrollEndNotification],
  /// nicht an [ScrollUpdateNotification]: Das Nachfedern erzeugt zwar laufend
  /// Updates, aber das Ende der Bewegung meldet erst die EndNotification.
  /// Würde man auf Updates hören, liefe die Animation mitten im Federn wieder
  /// an — also genau dann, wenn sie stört.
  static Widget beobachte({required Widget child}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollStartNotification) {
          laeuft.value = true;
        } else if (n is ScrollEndNotification) {
          laeuft.value = false;
        }
        // false: Die Meldung darf weiterlaufen. Andere Hörer — etwa eine
        // Ladeanzeige zum Nachladen — sollen sie ebenfalls sehen.
        return false;
      },
      child: child,
    );
  }
}
