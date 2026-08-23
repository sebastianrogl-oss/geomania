import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/lernpfad_data.dart';
import '../l10n/uebersetzungen.dart';
import '../services/ad_service.dart';
import '../services/challenge_panel_signal.dart';
import '../services/challenge_rekord_service.dart';
import '../services/daily_challenge.dart';
import '../services/fortschritt_service.dart';
import '../services/portfolio_service.dart';
import '../services/profilbild_service.dart';
import '../services/sound_service.dart';
import '../services/station_session_service.dart';
import '../utils/responsive.dart';
import '../widgets/kontinent_hintergrund.dart';
import '../widgets/level_skip_button.dart';
import '../widgets/pfad_deko_layer.dart';
import '../widgets/pfad_maskottchen.dart';
import '../widgets/kennzahl_erklaerung.dart';
import '../widgets/streak_flamme.dart';
import 'challenge_start_screen.dart';
import 'higher_lower_screen.dart';
import 'portfolio/portfolio_ergebnis_ansicht_screen.dart';
import 'portfolio_screen.dart';
import 'preis_schaetzen_screen.dart';
import 'ranking_game_screen.dart';
import 'station_quiz_screen.dart';
import '../widgets/lernpfad_station_button.dart';
import '../theme/app_theme.dart';


class _Anims {
  final Animation<double> ringScale;
  final Animation<double> ringOpacity;
  final Animation<double> ring2Scale;
  final Animation<double> ring2Opacity;
  const _Anims({
    required this.ringScale,
    required this.ringOpacity,
    required this.ring2Scale,
    required this.ring2Opacity,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final VoidCallback? onProfilTap;
  const HomeScreen({super.key, this.onProfilTap});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  LernpfadSnapshot? _snap;
  LernWelt _aktivWelt = lernwelten.first;
  // Verhindert, dass jeder _load()-Aufruf (z.B. nach Rückkehr aus einem
  // Quiz) die manuell gewählte/zuletzt aktive Welt überschreibt — sonst
  // springt die Ansicht bei 100%-Fortschritt immer zur letzten Welt zurück.
  bool _weltInitialisiert = false;
  Set<String> _doneChallenges = {};
  // Tatsächlich zu spielender Modus je Station (nach Pensionierungs-
  // Substitution bzw. einer bereits laufenden gespeicherten Session) — nur
  // für die aktive Welt befüllt, siehe _ladeTatsaechlicheModi(). Label/Icon
  // auf dem Stationsbutton sollen IMMER zum tatsächlich geöffneten Quiz
  // passen, nicht nur zum ursprünglich zugewiesenen station.modus (siehe
  // Kommentar bei FragenGenerator._pensionierterErsatz). Fallback auf
  // station.modus, solange diese Map noch nicht (neu) geladen ist.
  Map<String, LernModus> _tatsaechlicheModi = {};
  // Für welche Abschnitte der aktiven Welt gerade eine Wiederholungsrunde
  // aussteht (alle regulären Stationen fertig, aber die Wiederholung noch
  // nicht abgeschlossen) — steuert, ob die Geschenk-Kachel (_MeilensteinBtn)
  // antippbar ist. Siehe _ladeWiederholungStatus().
  Map<String, bool> _wiederholungAktivProAbschnitt = {};
  String _profilbild = ProfilbildService.standard;
  bool _panelOffen = false;
  final ScrollController _pfadScrollController = ScrollController();
  // Verhindert wiederholtes Auto-Scrollen bei jedem _load()-Rebuild (z.B.
  // nach Abschluss einer Station) — nur EINMAL pro Welt auslösen: beim
  // ersten Erscheinen dieser Welt (App-Start) oder beim Kontinent-Wechsel.
  String? _zuletztGescrollteWeltId;
  late final AnimationController _rippleCtrl;
  late final AnimationController _panelCtrl;
  late final Animation<Offset> _panelSlide;
  late final _Anims _anims;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOut));
    _anims = _Anims(
      ringScale: Tween<double>(
        begin: 1.0,
        end: 1.2,
      ).animate(CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut)),
      ringOpacity: Tween<double>(
        begin: 1.0,
        end: 0.0,
      ).animate(CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut)),
      ring2Scale: Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(
          parent: _rippleCtrl,
          curve: const Interval(0.33, 1.0, curve: Curves.easeOut),
        ),
      ),
      ring2Opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _rippleCtrl,
          curve: const Interval(0.33, 1.0, curve: Curves.easeOut),
        ),
      ),
    );
    _load();
    _ladeProfilbild();
    FortschrittService.resetSignal.addListener(_onResetSignal);
    ChallengePanelSignal.oeffnen.addListener(_onChallengePanelOeffnenSignal);
    ProfilbildService.geaendert.addListener(_ladeProfilbild);
  }

  // HomeScreen bleibt dank IndexedStack dauerhaft am Leben (kein initState()
  // beim Tab-Wechsel) -> ein geändertes Profilbild vom Profil-Tab würde ohne
  // dieses Signal hier nie nachgezogen.
  Future<void> _ladeProfilbild() async {
    final pfad = await ProfilbildService.getProfilbild();
    if (mounted) setState(() => _profilbild = pfad);
  }

  // Nach Abschluss einer Tages-Challenge (finaler "Weiter"-Button im
  // Ergebnis-Screen) soll man wieder direkt im Challenge-Panel landen statt
  // nur auf dem Lernpfad — dafür wird dieses Signal gebumpt.
  void _onChallengePanelOeffnenSignal() {
    if (!mounted || _panelOffen) return;
    setState(() => _panelOffen = true);
    _panelCtrl.forward(from: 0);
  }

  // Reset/"Alles freischalten" ändert den Fortschritt grundlegend — dort
  // soll die aktive Welt neu berechnet werden (anders als bei einem
  // normalen _load() nach dem Spielen einer Station).
  void _onResetSignal() {
    _weltInitialisiert = false;
    _load();
  }

  @override
  void dispose() {
    FortschrittService.resetSignal.removeListener(_onResetSignal);
    ChallengePanelSignal.oeffnen.removeListener(_onChallengePanelOeffnenSignal);
    ProfilbildService.geaendert.removeListener(_ladeProfilbild);
    _rippleCtrl.dispose();
    _panelCtrl.dispose();
    _pfadScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      FortschrittService.ladeSnapshot(),
      DailyChallenge.completedToday(),
    ]);
    if (!mounted) return;
    final snap = results[0] as LernpfadSnapshot;
    final done = results[1] as Set<String>;

    LernWelt aktiv = _aktivWelt;
    if (!_weltInitialisiert) {
      aktiv = lernwelten.first;
      for (final w in lernwelten) {
        if (snap.istWeltFrei(w.id)) {
          aktiv = w;
          if (snap.weltFortschritt(w.id) < 1.0) break;
        }
      }
      _weltInitialisiert = true;
    }
    setState(() {
      _snap = snap;
      _aktivWelt = aktiv;
      _doneChallenges = done;
    });
    _ladeTatsaechlicheModi(aktiv);
    _ladeWiederholungStatus(aktiv, snap);
  }

  // Prüft für jeden Abschnitt der übergebenen Welt, ob dessen reguläre
  // Stationen bereits vollständig abgeschlossen sind, die Wiederholung
  // dieses Abschnitts aber noch aussteht — nur dann wird die Geschenk-
  // Kachel (_MeilensteinBtn) antippbar (siehe FortschrittService.
  // wiederholungNoetig). Läuft separat/parallel zum Haupt-Snapshot, analog
  // zu _ladeTatsaechlicheModi().
  Future<void> _ladeWiederholungStatus(
    LernWelt welt,
    LernpfadSnapshot snap,
  ) async {
    final eintraege = <MapEntry<String, bool>>[];
    for (final a in welt.abschnitte) {
      final alleStationenFertig =
          a.stationen.isNotEmpty &&
          a.stationen.every((s) => snap.detailsFor(s.id).istAbgeschlossen);
      if (alleStationenFertig && !snap.istAbschnittAbgeschlossen(a.id)) {
        final noetig = await FortschrittService.wiederholungNoetig(a.id);
        eintraege.add(MapEntry(a.id, noetig));
      }
    }
    if (!mounted) return;
    setState(() => _wiederholungAktivProAbschnitt = Map.fromEntries(eintraege));
  }

  // Wird beim Antippen der Geschenk-Kachel ausgelöst (statt wie zuvor
  // automatisch nach Stations-Abschluss) — sammelt die falsch beantworteten
  // Fragen des Abschnitts und startet die Wiederholungsrunde.
  Future<void> _wiederholungTippen(LernAbschnitt abschnitt) async {
    final falscheFragen =
        await FortschrittService.sammelFalscheFragenFuerAbschnitt(abschnitt.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StationQuizScreen.wiederholung(
          wiederholungsAbschnittId: abschnitt.id,
          wiederholungsFragenJson: falscheFragen,
        ),
      ),
    );
    _load();
  }

  // Berechnet für jede Station der übergebenen Welt den Modus, der beim
  // Antippen TATSÄCHLICH gespielt würde (siehe _tatsaechlicheModi oben) —
  // parallel per Future.wait, da SharedPreferences nach dem ersten Zugriff
  // im Prozess bereits im Speicher gecacht ist (kein spürbarer I/O-Overhead
  // trotz vieler Stationen).
  Future<void> _ladeTatsaechlicheModi(LernWelt welt) async {
    final alleStationen = welt.abschnitte.expand((a) => a.stationen).toList();
    final eintraege = await Future.wait(
      alleStationen.map((s) async {
        final gespeichert = await StationSession.laden(s.id);
        final modus =
            gespeichert?.aktuelleFrage?.modus ??
            await FragenGenerator.ermittleTatsaechlichenModus(s);
        return MapEntry(s.id, modus);
      }),
    );
    if (!mounted) return;
    setState(() => _tatsaechlicheModi = Map.fromEntries(eintraege));
  }

  void _togglePanel() {
    if (_panelOffen) {
      _closePanel();
    } else {
      setState(() => _panelOffen = true);
      _panelCtrl.forward(from: 0);
    }
  }

  Future<void> _closePanel() async {
    await _panelCtrl.reverse();
    if (mounted) setState(() => _panelOffen = false);
  }

  Future<void> _challengeStarten(String id) async {
    await _closePanel();
    // markDone() feuert jetzt erst beim tatsächlichen Abschluss der
    // jeweiligen Challenge (siehe dortige _speichereErgebnis/_abschliessen),
    // nicht mehr schon beim Antippen — sonst zählte ein abgebrochenes
    // Spiel fälschlich als "heute erledigt".
    if (!mounted) return;
    final Widget screen;
    switch (id) {
      case 'preis':
        screen = ChallengeStartScreen(
          farbe: const Color(0xFFF9A825),
          logoAsset: 'assets/icons/challenge_preis.png',
          fallbackIcon: Icons.sell,
          titel: t('Das große Schätzen'),
          startDatum: kChallengesStartDatum,
          spielScreenBuilder: (_) => const PreisSchaetzenScreen(),
          ergebnisScreenBuilder: (_) =>
              const PreisSchaetzenScreen(nurAnsicht: true),
          istHeuteGespielt: () async =>
              (await ChallengeRekordService.getHeutigePunkte('preis')) != null,
        );
        break;
      case 'higher_lower':
        screen = ChallengeStartScreen(
          farbe: const Color(0xFF4A9E4A),
          logoAsset: 'assets/icons/challenge_higher_lower.png',
          fallbackIcon: Icons.swap_vert,
          titel: t('Higher or Lower'),
          startDatum: kChallengesStartDatum,
          spielScreenBuilder: (_) => const HigherLowerScreen(),
          ergebnisScreenBuilder: (_) =>
              const HigherLowerScreen(nurAnsicht: true),
          istHeuteGespielt: () async =>
              (await ChallengeRekordService.getHeutigePunkte('higher_lower')) !=
              null,
        );
        break;
      case 'ranking_game':
        screen = ChallengeStartScreen(
          farbe: const Color(0xFF7C3AED),
          logoAsset: 'assets/icons/challenge_ranking.png',
          fallbackIcon: Icons.military_tech,
          titel: t('Ranking Game'),
          startDatum: kChallengesStartDatum,
          spielScreenBuilder: (_) => const RankingGameScreen(),
          ergebnisScreenBuilder: (_) =>
              const RankingGameScreen(nurAnsicht: true),
          istHeuteGespielt: () async =>
              (await ChallengeRekordService.getHeutigePunkte('ranking_game')) !=
              null,
        );
        break;
      case 'portfolio':
        screen = ChallengeStartScreen(
          farbe: const Color(0xFF4A90D9),
          logoAsset: 'assets/icons/challenge_portfolio.png',
          fallbackIcon: Icons.business_center,
          titel: t('Portfolio'),
          startDatum: kChallengesStartDatum,
          spielScreenBuilder: (_) => const PortfolioScreen(),
          ergebnisScreenBuilder: (_) => const PortfolioErgebnisAnsichtScreen(),
          istHeuteGespielt: () async =>
              (await PortfolioService.ladeStatus()).heuteGespielt,
        );
        break;
      default:
        return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  LernStation? get _aktuelleStation {
    final snap = _snap;
    if (snap == null) return null;
    for (final a in _aktivWelt.abschnitte) {
      for (final s in a.stationen) {
        final d = snap.detailsFor(s.id);
        if (d.istFreigeschaltet && !d.istAbgeschlossen) return s;
      }
    }
    return null;
  }

  LernAbschnitt get _aktuellerAbschnitt {
    final snap = _snap;
    if (snap == null) return _aktivWelt.abschnitte.first;
    for (final a in _aktivWelt.abschnitte) {
      if (!snap.istAbschnittAbgeschlossen(a.id)) return a;
    }
    return _aktivWelt.abschnitte.last;
  }

  Future<void> _stationTippen(LernStation station) async {
    final details = _snap?.detailsFor(station.id);
    if (details == null || !details.istFreigeschaltet) return;

    // Label/Icon im Sheet müssen zum TATSÄCHLICH gespielten Modus passen,
    // nicht nur zum ursprünglich zugewiesenen station.modus: bei einer
    // bereits laufenden gespeicherten Session zählt deren tatsächliche
    // Frage, sonst greift dieselbe Pensionierungs-Prüfung wie beim
    // eigentlichen Start (FragenGenerator.generiereFragenFuerStation).
    final gespeichert = await StationSession.laden(station.id);
    final tatsaechlicherModus =
        gespeichert?.aktuelleFrage?.modus ??
        await FragenGenerator.ermittleTatsaechlichenModus(station);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StationSheet(
        station: station,
        modus: tatsaechlicherModus,
        abgeschlossen: details.istAbgeschlossen,
        onStart: () async {
          SoundService.spiele(Klang.knopf);
          Navigator.pop(context);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StationQuizScreen(station: station),
            ),
          );
          _load();
        },
        onSkipped: _load,
      ),
    );
  }

  void _weltUebersicht() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WeltUebersichtSheet(
        snap: _snap,
        aktivWelt: _aktivWelt,
        onWelt: (w) async {
          Navigator.pop(context);
          // Snapshot neu laden: eine Welt kann gerade erst per Werbung
          // freigeschaltet worden sein (siehe _KontinentFreischaltenDialog) —
          // ohne diesen Reload bleibt _snap auf dem Stand vor der
          // Freischaltung, wodurch die erste Station als gesperrt gilt und
          // ein erneutes Öffnen von "Alle Welten" den Freischalt-Dialog
          // erneut zeigt.
          await _load();
          if (!mounted) return;
          setState(() => _aktivWelt = w);
          _ladeTatsaechlicheModi(w);
        },
      ),
    );
  }

  // Wird von _Pfad nach jedem Build mit der Y-Position der aktuellen (bzw.
  // bei komplett abgeschlossener Welt: letzten) Station aufgerufen. Löst
  // NUR beim ersten Aufruf pro Welt-ID eine Scroll-Animation aus — App-Start
  // und Kontinent-Wechsel liefern eine neue Welt-ID, ein Rebuild nach dem
  // Abschluss einer Station innerhalb derselben Welt dagegen nicht, daher
  // kein ständiges Wegscrollen während des normalen Spielens.
  void _handleAktuelleStationY(double y) {
    final weltId = _aktivWelt.id;
    if (_zuletztGescrollteWeltId == weltId) return;
    _zuletztGescrollteWeltId = weltId;
    _scrolleZuStation(y);
  }

  Future<void> _scrolleZuStation(double zielY) async {
    // Kurze Verzögerung, damit das Layout der neuen Welt (andere Pfadlänge/
    // -form) vollständig aufgebaut ist, bevor der maxScrollExtent für den
    // Clamp feststeht — sonst könnte zu früh oder zu kurz gescrollt werden.
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted || !_pfadScrollController.hasClients) return;
    final viewportHoehe = _pfadScrollController.position.viewportDimension;
    final ziel = (zielY - viewportHoehe / 2).clamp(
      0.0,
      _pfadScrollController.position.maxScrollExtent,
    );
    await _pfadScrollController.animateTo(
      ziel,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _GreenHeader(
            weltEmoji: _aktivWelt.emoji,
            streak: snap?.streak ?? 0,
            punkte: snap?.gesamtRichtig ?? 0,
            profilbild: _profilbild,
            onProfilTap: widget.onProfilTap,
          ),
          _WeltBanner(
            welt: _aktivWelt,
            abschnitt: _aktuellerAbschnitt,
            onUebersicht: _weltUebersicht,
          ),
          Expanded(
            // LayoutBuilder statt MediaQuery.of(context).size.height für die
            // Panel-Höhe: MediaQuery liefert die GESAMTE Bildschirmhöhe, aber
            // dieser Stack selbst ist durch Header+Banner darüber bereits
            // verkleinert — "85% der Gesamthöhe" war dadurch auf dem Handy
            // (wo Header/Banner proportional mehr Platz einnehmen als im
            // breiten Desktop-Testfenster) HÖHER als der Stack selbst, sodass
            // der obere Rand des Panels (inkl. Drag-Handle zum Wegwischen)
            // vom Stack abgeschnitten wurde (Stack clippt standardmäßig).
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // 0. Unsichtbarer Emoji-Preloader — lädt 🔥⭐🎁 Font-Glyphen synchron
                    Positioned(
                      left: -9999,
                      top: -9999,
                      child: Wrap(
                        children: ['🔥', '⭐', '🎁']
                            .map(
                              (e) =>
                                  Text(e, style: const TextStyle(fontSize: 1)),
                            )
                            .toList(),
                      ),
                    ),
                    // 1. Scrollbarer Lernpfad
                    snap == null
                        ? const Center(child: CircularProgressIndicator())
                        : _Pfad(
                            welt: _aktivWelt,
                            snap: snap,
                            aktuelleStationId: _aktuelleStation?.id,
                            anims: _anims,
                            onStationTap: _stationTippen,
                            onWiederholungTap: _wiederholungTippen,
                            scrollController: _pfadScrollController,
                            onAktuelleStationY: _handleAktuelleStationY,
                            tatsaechlicheModi: _tatsaechlicheModi,
                            wiederholungAktivProAbschnitt:
                                _wiederholungAktivProAbschnitt,
                          ),
                    // 2. Dunkler Overlay (schließt Panel beim Antippen)
                    if (_panelOffen)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => _closePanel(),
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.54),
                          ),
                        ),
                      ),
                    // 3. Challenge Panel (Modal von unten, 85% Höhe)
                    if (_panelOffen)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SlideTransition(
                          position: _panelSlide,
                          child: SizedBox(
                            height: constraints.maxHeight * 0.85,
                            child: _ChallengePanel(
                              done: _doneChallenges,
                              onTap: _challengeStarten,
                              onClose: () => _closePanel(),
                            ),
                          ),
                        ),
                      ),
                    // 4. Challenge Button (immer ganz oben)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _ChallengeBtn(
                        doneCount: _doneChallenges.length,
                        onTap: _togglePanel,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grüner Header ─────────────────────────────────────────────────────────────

/// Abstand zwischen der Welt-Flagge und dem Block aus Flamme und Stern.
const double _kKopfFlaggeAbstand = 16;

/// Um wie viel dieser Block gemeinsam nach links rückt.
const double _kKopfBlockVersatz = 15;

class _GreenHeader extends StatefulWidget {
  final String weltEmoji;
  final int streak;
  final int punkte;
  final String profilbild;
  final VoidCallback? onProfilTap;
  const _GreenHeader({
    required this.weltEmoji,
    required this.streak,
    required this.punkte,
    required this.profilbild,
    this.onProfilTap,
  });

  @override
  State<_GreenHeader> createState() => _GreenHeaderState();
}

// Der ⭐-Zähler zeigt die insgesamt verdienten Sterne (gesamtRichtig). Kommt
// der Spieler von einem abgeschlossenen Quiz zurück, zählt er die dort neu
// verdienten Sterne hoch — also vom vorherigen Stand zum neuen, NICHT von 0.
// (Ein IntTween mit begin: 0 zählte bei jeder Wertänderung den kompletten
// Gesamtstand neu durch, was den eigentlichen Zugewinn unkenntlich machte.)
//
// Das frühere Pulsieren der Icons ist bewusst entfallen: 🔥 (Tages-Streak)
// bekommt beim Steigen jetzt einen eigenen Vollbild-Moment
// (widgets/streak_feier_overlay.dart), und für ⭐ genügt das Hochzählen.
class _GreenHeaderState extends State<_GreenHeader> {
  // Ausgangswert des laufenden Hochzählens. Wird in didUpdateWidget auf den
  // ALTEN Punktestand gesetzt, damit der TweenAnimationBuilder genau die
  // Differenz durchläuft.
  late int _punkteVon;

  // Der Header wird einmal mit dem 0-Platzhalter gebaut, bevor der Snapshot
  // geladen ist (siehe build(): `snap?.gesamtRichtig ?? 0`). Dieser Sprung
  // 0 -> Gesamtstand ist kein Zugewinn und darf nicht hochgezählt werden.
  bool _erstStandGesetzt = false;

  @override
  void initState() {
    super.initState();
    _punkteVon = widget.punkte;
    // Steht beim Aufbau schon ein Wert, ist das bereits der geladene Stand.
    _erstStandGesetzt = widget.punkte > 0;
  }

  @override
  void didUpdateWidget(covariant _GreenHeader old) {
    super.didUpdateWidget(old);
    if (widget.punkte != old.punkte) {
      if (kDebugMode) {
        debugPrint('[Header] Sterne ${old.punkte} -> ${widget.punkte}'
            '${_erstStandGesetzt ? '' : ' (Erstbefüllung, ohne Animation)'}');
      }
      _punkteVon = _erstStandGesetzt ? old.punkte : widget.punkte;
      _erstStandGesetzt = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Die Schrift wächst hier ungebremst mit der Systemeinstellung mit.
    //
    // Zwischenzeitlich stand hier eine Deckelung auf Skala 1.2, weil die
    // Zeile bei 1.5 um 11 px seitlich überlief. Der Überlauf kam aber nicht
    // von der Zeile, sondern von einer starren 44-px-Box, die die Tippfläche
    // um Stern und Zahl vergrößern sollte: deren Inhalt braucht bei 1.5 rund
    // 55 px. Seit dort eine MINDESTgröße statt einer festen Größe steht
    // (ConstrainedBox weiter unten), passt alles ohne Deckelung — nachgemessen
    // auf 320, 360 und 412 px bei Skala 1.0, 1.3 und 1.5.
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF4A9E4A),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(widget.weltEmoji, style: const TextStyle(fontSize: 22)),
          // Flamme+Zahl und Stern+Zahl rücken als Block näher an die Flagge.
          // Der Versatz steckt bewusst in DIESEM Abstand und nicht in einem
          // Transform an den beiden Blöcken: so wandern beide zwangsläufig
          // gleich weit, ihr Abstand zueinander bleibt unberührt, die
          // Tippflächen wandern mit — und das Profilbild rechts bleibt durch
          // den Spacer, wo es ist.
          const SizedBox(width: _kKopfFlaggeAbstand - _kKopfBlockVersatz),
          // Deutlich größer als das frühere Emoji (18): die Flamme trägt die
          // Streak-Anzeige optisch. Die Kopfzeile ist 56px hoch, 45px passen
          // dort hinein, und die Row zentriert ihre Kinder vertikal — der
          // Zahlentext daneben bleibt dadurch auf Höhe.
          //
          // Der Versatz korrigiert die optische Lage: Transform.translate
          // wirkt rein visuell, der Platzbedarf in der Row bleibt unverändert
          // und der Zahlentext daneben rutscht dadurch nicht mit.
          // Flamme UND Zahl liegen in einem gemeinsamen GestureDetector: eine
          // einzelne Ziffer ist ein zu kleines Ziel für einen Finger, und
          // beide gehören ohnehin zusammen. HitTestBehavior.opaque nimmt auch
          // die Lücke dazwischen mit.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => zeigeStreakErklaerung(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: const Offset(5, -5),
                  // Die Zahl steht hier daneben statt in der Flamme, deshalb
                  // muss der erloschene Zustand ausdrücklich mitgegeben
                  // werden.
                  child: StreakFlamme(
                    groesse: 45,
                    erloschen: widget.streak == 0,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.streak}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                zeigeSterneErklaerung(context, kErreichbareSterne),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                // Zählt die im letzten Quiz verdienten Sterne hoch (vom alten
                // auf den neuen Gesamtstand, siehe _punkteVon).
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: _punkteVon, end: widget.punkte),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (context, wert, child) => Text(
                    '$wert',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onProfilTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: ProfilbildService.istWeitformat(widget.profilbild)
                    // Siehe profil_screen.dart: BoxFit.cover schnitt bei
                    // "winken" die Hand ab, contain+Skalierung zeigt sie
                    // vollständig.
                    ? Transform.scale(
                        scale: 1.25,
                        child:
                            Image.asset(widget.profilbild, fit: BoxFit.contain),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.asset(widget.profilbild,
                            fit: BoxFit.contain),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Welt-Banner ───────────────────────────────────────────────────────────────

class _WeltBanner extends StatelessWidget {
  final LernWelt welt;
  final LernAbschnitt abschnitt;
  final VoidCallback onUebersicht;
  const _WeltBanner({
    required this.welt,
    required this.abschnitt,
    required this.onUebersicht,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF3D8B3D),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Nur noch der Name. Die Nummer der Welt stand vorher davor
                  // ("Welt 1 — Europa"), sagt aber nichts, was der Name nicht
                  // schon sagt — und der Kopf ist schmal.
                  t(welt.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  // Ohne den Titel dahinter ("Abschnitt 1 — Einsteiger"):
                  // die Stufe ordnet bereits ein, der Titel wiederholt sie
                  // nur mit anderen Worten.
                  t('Abschnitt {n}', {'n': '${abschnitt.stufe}'}),
                  style: const TextStyle(
                    color: Color(0xFFA8D5A2),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onUebersicht,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, color: Colors.white, size: 15),
                  const SizedBox(width: 4),
                  Text(
                    t('Welten'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pfad ──────────────────────────────────────────────────────────────────────

class _Pfad extends StatelessWidget {
  final LernWelt welt;
  final LernpfadSnapshot snap;
  final String? aktuelleStationId;
  final _Anims anims;
  final void Function(LernStation) onStationTap;
  final void Function(LernAbschnitt) onWiederholungTap;
  final ScrollController scrollController;
  final void Function(double y) onAktuelleStationY;
  // Tatsächlich zu spielender Modus je Station-ID (siehe
  // _HomeScreenState._ladeTatsaechlicheModi) — fällt auf station.modus
  // zurück, solange die Map für diese Station noch nicht befüllt ist.
  final Map<String, LernModus> tatsaechlicheModi;
  // Siehe _HomeScreenState._ladeWiederholungStatus() — steuert, ob die
  // Geschenk-Kachel für den jeweiligen Abschnitt antippbar ist.
  final Map<String, bool> wiederholungAktivProAbschnitt;

  const _Pfad({
    required this.welt,
    required this.snap,
    required this.aktuelleStationId,
    required this.anims,
    required this.onStationTap,
    required this.onWiederholungTap,
    required this.scrollController,
    required this.onAktuelleStationY,
    required this.tatsaechlicheModi,
    required this.wiederholungAktivProAbschnitt,
  });

  @override
  Widget build(BuildContext context) {
    // Die Systemschriftgröße geht in die Höhe des Abschnitts-Bands ein, und
    // die wiederum in die Wegpunkte des Pfades — deshalb hier einmal lesen
    // und durchreichen, statt im Stack an mehreren Stellen erneut.
    final textSkala = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (_, constraints) => _buildStack(constraints.maxWidth, textSkala),
    );
  }

  Widget _buildStack(double w, double textSkala) {
    // Mitte → HalbR(60%) → Rechts(65%) → HalbR → Mitte → HalbL(40%) → Links(35%) → HalbL
    const xPat = [0.50, 0.60, 0.65, 0.60, 0.50, 0.40, 0.35, 0.40];
    const vGap = 130.0;
    const topPad = 120.0;
    const bannerBeforeGap = 50.0;
    // Das Band trägt zwei Textzeilen, und der Untertitel bricht um. Bei einer
    // eingestellten Systemschrift von 1.5 lief es deshalb um bis zu 39 px
    // über. Die Höhe wächst jetzt mit der Schrift mit — das darf sie, weil
    // sie hier berechnet wird und damit in die Wegpunkte des Pfades eingeht.
    // Bei Skala 1.0 bleibt es bei den bisherigen 56.
    final bannerH = 56.0 * textSkala.clamp(1.0, 1.7);
    const bannerAfterGap = 55.0; // > 41px Radius → keine Station auf dem Banner

    final overlays = <Widget>[];
    double y = topPad;
    // Y-Position der aktuellen Station fürs Auto-Scrollen (siehe
    // _HomeScreenState._handleAktuelleStationY). Fallback auf die letzte
    // Station, falls die Welt komplett abgeschlossen ist (dann matcht keine
    // Station aktuelleStationId).
    double? aktuelleStationY;
    double letzteStationY = topPad;

    final List<Offset> alleStationPos = [];
    final List<List<Offset>> stationenProAbschnitt = [];
    final List<({Offset pos, int stufe})> checkpointPunkte = [];
    int globalStationIdx = 0; // zählt alle Stationen quer über alle Abschnitte

    for (int ai = 0; ai < welt.abschnitte.length; ai++) {
      final a = welt.abschnitte[ai];
      stationenProAbschnitt.add([]);
      final aFrei = snap.istAbschnittFrei(a.id);
      final aDone = snap.istAbschnittAbgeschlossen(a.id);

      final doneInSection = a.stationen
          .where((s) => snap.detailsFor(s.id).istAbgeschlossen)
          .length;
      final sectionProgress = a.stationen.isNotEmpty
          ? doneInSection / a.stationen.length
          : 0.0;

      if (ai > 0) {
        final bY = y + bannerBeforeGap;
        overlays.add(
          Positioned(
            left: 16,
            right: 16,
            top: bY,
            height: bannerH,
            child: _AbschnittTrenner(
              abschnitt: a,
              istFrei: aFrei,
              istDone: aDone,
            ),
          ),
        );
        y = bY + bannerH + bannerAfterGap;
      }

      // Gerade Abschnitte starten rechts, ungerade links — immer von Mitte aus
      final localStart = (ai % 2 == 0) ? 0 : 4;

      int localIdx = localStart;

      for (final s in a.stationen) {
        final details = snap.detailsFor(s.id);
        final istDone = details.istAbgeschlossen;
        final istAktuell = s.id == aktuelleStationId;
        final angezeigterModus = tatsaechlicheModi[s.id] ?? s.modus;

        final xFrac = xPat[localIdx % xPat.length];
        final cx = xFrac * w;

        alleStationPos.add(Offset(cx, y));
        stationenProAbschnitt.last.add(Offset(cx, y));
        letzteStationY = y;
        if (istAktuell) aktuelleStationY = y;
        if (istAktuell) {
          // START-Blase nur auf der allerersten Station, solange sie nicht abgeschlossen
          if (globalStationIdx == 0) {
            overlays.add(
              Positioned(
                left: cx - 55,
                top: y - 106,
                width: 110,
                child: _StartSprechblase(istGestartet: details.istGestartet),
              ),
            );
          }
          overlays.add(
            Positioned(
              left: cx - 45,
              top: y - 45,
              child: _ActiveBtn(
                modus: angezeigterModus,
                anims: anims,
                onTap: () => onStationTap(s),
                sectionProgress: sectionProgress,
              ),
            ),
          );
        } else if (istDone) {
          overlays.add(
            Positioned(
              left: cx - 41,
              top: y - 41,
              child: _DoneBtn(onTap: () => onStationTap(s)),
            ),
          );
        } else if (details.istFreigeschaltet) {
          overlays.add(
            Positioned(
              left: cx - 41,
              top: y - 41,
              child: LernpfadStationButton(
                modus: angezeigterModus,
                onTap: () => onStationTap(s),
              ),
            ),
          );
        } else {
          overlays.add(
            Positioned(
              left: cx - 41,
              top: y - 41,
              child: _LockedBtn(modus: s.modus),
            ),
          );
        }

        y += vGap;
        localIdx++;
        globalStationIdx++;
      }

      // Checkpoint immer in der Mitte
      final mcx = 0.50 * w;
      overlays.add(
        Positioned(
          left: mcx - 41,
          top: y - 41,
          child: _MeilensteinBtn(
            abschnitt: a,
            istDone: aDone,
            istLetzter: ai == welt.abschnitte.length - 1,
            wiederholungAktiv: wiederholungAktivProAbschnitt[a.id] ?? false,
            onTap: () => onWiederholungTap(a),
          ),
        ),
      );
      checkpointPunkte.add((pos: Offset(mcx, y), stufe: a.stufe));
      y += vGap;
    }

    final s = stationenProAbschnitt;
    final all = alleStationPos;

    overlays.insertAll(
      0,
      pfadDekoOverlays(
        kontinentId: welt.id,
        allePositionen: all,
        stationenProAbschnitt: s,
        screenWidth: w,
      ),
    );

    // Münzen: stufe 1 → Station 7, andere an spezifischen Positionen
    final muenzPunkte = checkpointPunkte.map((cp) {
      return switch (cp.stufe) {
        1 => (pos: all.length >= 7 ? all[6] : cp.pos, stufe: cp.stufe),
        2 => (
          pos: s.length > 1 && s[1].length > 2 ? s[1][2] : cp.pos,
          stufe: cp.stufe,
        ),
        3 => (
          pos: s.length > 2 && s[2].length > 10 ? s[2][10] : cp.pos,
          stufe: cp.stufe,
        ),
        4 => (
          pos: s.length > 3 && s[3].length > 22 ? s[3][22] : cp.pos,
          stufe: cp.stufe,
        ),
        _ => cp,
      };
    }).toList();
    overlays.addAll(
      pfadMaskottchenOverlays(abschnitte: muenzPunkte, screenWidth: w),
    );

    // Globus: freie Positionen (kein Clash mit Coin/Deko). Nicht jede Welt
    // hat 4 Abschnitte (Südamerika/Ozeanien haben nur 3, siehe Teil 2 des
    // Block-Umbaus) -> jeder Eintrag nur, wenn der Abschnitt tatsächlich
    // existiert, sonst würde checkpointPunkte[3] einen RangeError werfen.
    final globusPunkte = [
      if (welt.id != 'suedamerika' && checkpointPunkte.isNotEmpty)
        (
          pos: s.isNotEmpty && s[0].length > 10 ? s[0][10] : all.first,
          stufe: 1,
        ),
      if (checkpointPunkte.length > 1)
        (
          pos: s.length > 1 && s[1].length > 10
              ? s[1][10]
              : checkpointPunkte[1].pos,
          stufe: 2,
        ),
      if (checkpointPunkte.length > 2)
        (
          pos: s.length > 2 && s[2].length > 2
              ? s[2][2]
              : checkpointPunkte[2].pos,
          stufe: 3,
        ),
      if (checkpointPunkte.length > 3)
        (
          pos: s.length > 3 && s[3].length > 14
              ? s[3][14]
              : checkpointPunkte[3].pos,
          stufe: 4,
        ),
    ];
    overlays.addAll(
      pfadGlobusOverlays(abschnitte: globusPunkte, screenWidth: w),
    );

    final totalH = y + 80;

    // Erst NACH diesem Build (Layout steht, maxScrollExtent ist bekannt) an
    // den Aufrufer melden, wo die aktuelle Station liegt — der Aufrufer
    // entscheidet dann (siehe _handleAktuelleStationY), ob dorthin animiert
    // gescrollt wird.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onAktuelleStationY(aktuelleStationY ?? letzteStationY);
    });

    return KontinentHintergrund(
      kontinentId: welt.id,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: 40),
        child: SizedBox(
          width: double.infinity,
          height: totalH,
          child: Stack(clipBehavior: Clip.none, children: overlays),
        ),
      ),
    );
  }
}

// ── Meilenstein Button ────────────────────────────────────────────────────────

class _MeilensteinBtn extends StatelessWidget {
  final LernAbschnitt abschnitt;
  final bool istDone;
  final bool istLetzter;
  // Alle Stationen des Abschnitts fertig, Wiederholung aber noch nicht
  // abgeschlossen -> Kachel ist antippbar und startet die Wiederholung
  // (siehe _HomeScreenState._wiederholungTippen). Vorher (Stationen noch
  // nicht fertig) oder danach (bereits abgeschlossen, istDone) bleibt sie
  // inert wie zuvor.
  final bool wiederholungAktiv;
  final VoidCallback onTap;
  const _MeilensteinBtn({
    required this.abschnitt,
    required this.istDone,
    required this.istLetzter,
    required this.wiederholungAktiv,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Drei Zustände statt nur zwei: nicht erreicht (grau, inert) — bereit
    // zum Antippen (grün, wie der übrige "aktiv"-Farbcode im Lernpfad) —
    // abgeschlossen (orange, inert, wie zuvor).
    final hauptFarbe = istDone
        ? const Color(0xFFF9A825)
        : wiederholungAktiv
        ? const Color(0xFF4A9E4A)
        : const Color(0xFFCECCCA);
    final sockelFarbe = istDone
        ? const Color(0xFFC17F00)
        : wiederholungAktiv
        ? const Color(0xFF3D8B3D)
        : const Color(0xFFADABA8);
    const radius = BorderRadius.all(Radius.circular(16));

    final String icon;
    final String label;
    if (istLetzter) {
      icon = istDone ? '🏆' : '⭐';
      label = istDone
          ? t('Abschluss ✅')
          : wiederholungAktiv
          ? t('Wiederholung starten')
          : t('Abschluss');
    } else {
      icon = istDone ? '🎁' : '📖';
      label = istDone
          ? t('Abschnitt ✅')
          : wiederholungAktiv
          ? t('Wiederholung starten')
          : t('Checkpoint');
    }

    return GestureDetector(
      onTap: wiederholungAktiv ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 82,
            height: 87,
            child: Stack(
              children: [
                // Sockel
                Positioned(
                  top: 5,
                  left: 0,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: sockelFarbe,
                      borderRadius: radius,
                    ),
                  ),
                ),
                // Haupt-Kachel
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: hauptFarbe,
                      borderRadius: radius,
                    ),
                    child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 34)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: istDone || wiederholungAktiv
                  ? const Color(0xFF4A9E4A)
                  : const Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }
}

// ── START Sprech-Blase ────────────────────────────────────────────────────────

class _StartSprechblase extends StatelessWidget {
  final bool istGestartet;
  const _StartSprechblase({required this.istGestartet});

  static const _top = Color(0xFF4CAF50);
  static const _sockel = Color(0xFF388E3C);
  static const _sockelH = 4.0;
  static const _br = BorderRadius.all(Radius.circular(10));
  static const _style = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 11,
    letterSpacing: 0.8,
  );

  @override
  Widget build(BuildContext context) {
    final label = istGestartet ? 'WEITER' : 'START';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Sockel (dunkleres Grün, 4px nach unten versetzt)
            Transform.translate(
              offset: const Offset(0, _sockelH),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: _sockel,
                  borderRadius: _br,
                ),
                child: Text(label, style: _style.copyWith(color: _sockel)),
              ),
            ),
            // Deckfläche (helles Grün)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(color: _top, borderRadius: _br),
              child: Text(label, style: _style),
            ),
          ],
        ),
        const SizedBox(height: _sockelH),
        CustomPaint(
          size: const Size(12, 6),
          painter: _PfeilUntenMaler(color: _top),
        ),
      ],
    );
  }
}

class _PfeilUntenMaler extends CustomPainter {
  final Color color;
  const _PfeilUntenMaler({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_PfeilUntenMaler o) => o.color != color;
}

// ── Abgeschlossen (grünes 3D) ─────────────────────────────────────────────────

class _DoneBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _DoneBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Druckbar3DButton(
      kreisGroesse: 82,
      sockelHoehe: 5,
      sockelFarbe: const Color(0xFF3D8B3D),
      inhalt: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF5DBB63), Color(0xFF4A9E4A)],
            center: Alignment(-0.3, -0.3),
            radius: 0.8,
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
      ),
      onTap: onTap,
    );
  }
}

// ── Freigeschaltet (grünes 3D mit Modus-Emoji) ───────────────────────────────

// ── Pulsier-Ring Painter (einheitlich grün) ───────────────────────────────────

class _PulsierRing3DPainter extends CustomPainter {
  final double animValue; // 0.0 → 1.0
  const _PulsierRing3DPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 3.0);
    final startR = size.width / 2 + 8.0; // 53px Startradius
    final r = startR + animValue * 8.0; // 51→59 (102px→118px diameter)
    final sw = (3.0 - animValue * 2.0).clamp(0.3, 3.0);
    final opacity = (1.0 - animValue * 0.9).clamp(0.0, 1.0);

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..color = const Color(0xFFF9A825).withValues(alpha: opacity * 0.7),
    );
  }

  @override
  bool shouldRepaint(_PulsierRing3DPainter o) => o.animValue != animValue;
}

// ── Aktuell (grün 3D + Fortschrittsring + Sonar) ─────────────────────────────

class _ActiveBtn extends StatelessWidget {
  final LernModus modus;
  final _Anims anims;
  final VoidCallback onTap;
  final double sectionProgress;

  const _ActiveBtn({
    required this.modus,
    required this.anims,
    required this.onTap,
    required this.sectionProgress,
  });

  Widget _pulsierRing3D(Animation<double> scale, Animation<double> opacity) {
    return AnimatedBuilder(
      animation: scale,
      builder: (_, _) => CustomPaint(
        size: const Size(90, 90),
        painter: _PulsierRing3DPainter(
          animValue: ((scale.value - 1.0) / 0.2).clamp(0.0, 1.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 95, // 90 + 5 Sockel
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sonar-Ring 1
          _pulsierRing3D(anims.ringScale, anims.ringOpacity),
          // Sonar-Ring 2 (versetzt)
          _pulsierRing3D(anims.ring2Scale, anims.ring2Opacity),
          // 3D Grün-Button (8px Offset → zentriert in 106px)
          Positioned(
            top: 0,
            left: 0,
            child: Druckbar3DButton(
              kreisGroesse: 90,
              sockelHoehe: 5,
              sockelFarbe: const Color(0xFF3D8B3D),
              inhalt: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFF5DBB63), Color(0xFF4A9E4A)],
                    center: Alignment(-0.3, -0.3),
                    radius: 0.8,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(lernpfadModusIcon(modus), color: Colors.white, size: 36),
                ),
              ),
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gesperrt (grau 3D mit grauem Modus-Emoji) ───────────────────────────────

class _LockedBtn extends StatelessWidget {
  final LernModus modus;
  const _LockedBtn({required this.modus});

  @override
  Widget build(BuildContext context) {
    return Druckbar3DButton(
      kreisGroesse: 82,
      sockelHoehe: 5,
      sockelFarbe: const Color(0xFFB0AEA8),
      inhalt: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFD0CEC8),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            lernpfadModusIcon(modus),
            color: const Color(0xFF9E9C96),
            size: 28,
          ),
        ),
      ),
      onTap: null,
    );
  }
}

// ── Abschnitt-Trenner ─────────────────────────────────────────────────────────

class _AbschnittTrenner extends StatelessWidget {
  final LernAbschnitt abschnitt;
  final bool istFrei;
  final bool istDone;
  const _AbschnittTrenner({
    required this.abschnitt,
    required this.istFrei,
    required this.istDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAE5),
        borderRadius: BorderRadius.circular(16),
        border: istDone
            ? Border.all(color: const Color(0xFF4A9E4A), width: 1.5)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            offset: Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  // Ohne den Titel dahinter ("Abschnitt 1 — Einsteiger"):
                  // die Stufe ordnet bereits ein, der Titel wiederholt sie
                  // nur mit anderen Worten.
                  t('Abschnitt {n}', {'n': '${abschnitt.stufe}'}),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: istFrei
                        ? const Color(0xFF1a1a1a)
                        : const Color(0xFF999999),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t(abschnitt.untertitel),
                  // Höchstens zwei Zeilen: das Band hat eine berechnete Höhe
                  // (siehe bannerH), und ein dritter Umbruch — möglich bei
                  // großer Systemschrift und langen Untertiteln — würde sie
                  // sprengen.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: istFrei
                        ? const Color(0xFF666666)
                        : const Color(0xFFBBBBBB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              istDone
                  ? '✅'
                  : istFrei
                  ? '▼'
                  : '🔒',
              style: TextStyle(
                fontSize: 16,
                color: istFrei && !istDone ? const Color(0xFF4A9E4A) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Station Sheet ─────────────────────────────────────────────────────────────

class _StationSheet extends StatefulWidget {
  final LernStation station;
  // Tatsächlich zu spielender Modus (nach Pensionierungs-Substitution) —
  // NICHT einfach station.modus, siehe _stationTippen().
  final LernModus modus;
  final bool abgeschlossen;
  final VoidCallback onStart;
  final VoidCallback onSkipped;
  const _StationSheet({
    required this.station,
    required this.modus,
    required this.abgeschlossen,
    required this.onStart,
    required this.onSkipped,
  });

  @override
  State<_StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<_StationSheet> {
  bool _skipLoading = false;

  // Identische Logik zum Level-Skip in station_quiz_screen.dart
  // (_StationQuizScreenState._levelSkippen) — hier zusätzlich VOR dem
  // eigentlichen Start der Station aufrufbar, damit der Spieler ein Level
  // überspringen kann, ohne es erst öffnen zu müssen.
  Future<void> _skipLevel() async {
    if (_skipLoading) return;
    setState(() => _skipLoading = true);
    final belohnt = await AdService.zeigeRewardedAd(onBelohnt: () {});
    if (!mounted) return;
    setState(() => _skipLoading = false);
    if (!belohnt) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t(
            'Werbung aktuell nicht verfügbar, versuch es später erneut')),
        backgroundColor: const Color(0xFF888888),
      ));
      return;
    }
    await FortschrittService.stationUeberspringenUndAbschnittPruefen(
        widget.station.id);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onSkipped();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: LevelSkipButton(
              loading: _skipLoading,
              onTap: _skipLevel,
              color: const Color(0xFF888888),
            ),
          ),
          Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          Icon(lernpfadModusIcon(widget.modus), size: 56, color: const Color(0xFF4A9E4A)),
          const SizedBox(height: 12),
          Text(
            lernModusLabel(widget.modus),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            lernModusFragenLabel(widget.station),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          // Hier stand ein Einzeiler zur Bedienung. Er ist wieder raus: die
          // ausführliche Anleitung erscheint beim ersten Vorkommen des Modus
          // und bleibt über den Hilfe-Knopf in der Spielfläche erreichbar —
          // das Sheet davor braucht sie nicht zu wiederholen.
          // (lernModusKurzanleitung() in lernpfad_data.dart bleibt bestehen.)
          if (widget.abgeschlossen) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4A9E4A).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                t('Bereits abgeschlossen ✅'),
                style: const TextStyle(
                  color: Color(0xFF4A9E4A),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A9E4A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                widget.abgeschlossen ? t('Nochmal spielen') : t('START'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                t('Abbrechen'),
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Challenge Panel (Modal von unten) ────────────────────────────────────────

class _ChallengePanel extends StatefulWidget {
  final Set<String> done;
  final void Function(String id) onTap;
  final VoidCallback onClose;
  const _ChallengePanel({
    required this.done,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_ChallengePanel> createState() => _ChallengePanelState();
}

class _ChallengePanelState extends State<_ChallengePanel> {
  double _dragTotal = 0;

  static const _karten = [
    (
      id: 'preis',
      asset: 'assets/icons/challenge_preis.png',
      emoji: '🏷️',
      title: 'Das große Schätzen',
      bg: Color(0xFFF9A825),
    ),
    (
      id: 'higher_lower',
      asset: 'assets/icons/challenge_higher_lower.png',
      emoji: '⬆️',
      title: 'Higher or Lower',
      bg: Color(0xFF4A9E4A),
    ),
    (
      id: 'ranking_game',
      asset: 'assets/icons/challenge_ranking.png',
      emoji: '🏅',
      title: 'Ranking Quiz',
      bg: Color(0xFF7C3AED),
    ),
    (
      id: 'portfolio',
      asset: 'assets/icons/challenge_portfolio.png',
      emoji: '💼',
      title: 'Portfolio des Tages',
      bg: Color(0xFF4A90D9),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final doneCount = widget.done.length;
    final d = DailyChallenge.untilMidnight();
    final countdown = t('Heute • Reset in {h}h {m}m', {
      'h': '${d.inHours}',
      'm': '${d.inMinutes % 60}',
    });

    return Container(
      decoration: const BoxDecoration(
        color: kHintergrund,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (d) {
              if (d.delta.dy > 0) {
                _dragTotal += d.delta.dy;
                if (_dragTotal > 100) {
                  _dragTotal = 0;
                  widget.onClose();
                }
              }
            },
            onVerticalDragEnd: (_) => _dragTotal = 0,
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0CEC8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('⚡ TÄGLICHE CHALLENGES'),
                      style: const TextStyle(
                        color: Color(0xFF4A9E4A),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      countdown,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEAE5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF888888),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Fortschritts-Punkte
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (int i = 0; i < 4; i++) ...[
                      if (i > 0)
                        Expanded(
                          child: Container(
                            height: 1.5,
                            color: const Color(0xFFD0CEC8),
                          ),
                        ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: i < doneCount
                              ? const Color(0xFF4A9E4A)
                              : const Color(0xFFEAEAE5),
                          shape: BoxShape.circle,
                          border: i < doneCount
                              ? null
                              : Border.all(
                                  color: const Color(0xFFD0CEC8),
                                  width: 1.5,
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  t('{n} von 4 Challenges erledigt', {'n': '$doneCount'}),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Karten (2×2 Schachbrett-Grid) — Seitenverhältnis wird aus dem
          // TATSÄCHLICH verfügbaren Platz berechnet (LayoutBuilder) statt
          // eines fixen "1.0" (perfekt quadratisch): auf dem Handy ist die
          // Panel-Höhe knapper als im breiten Desktop-Testfenster, ein
          // starres Quadrat-Verhältnis ließ die 2 Reihen dort entweder nicht
          // mehr vollständig hineinpassen (Scrollen nötig) oder unten
          // ungenutzten Leerraum übrig — so füllen die 4 Kacheln den Bereich
          // auf JEDER Bildschirmgröße gleichmäßig und exakt aus.
          //
          // Alle 4 Karten bewusst exakt gleich groß UND die Spaltentrennlinie
          // exakt mittig (siehe Testrunde: sowohl einzelne Kacheln als auch
          // ganze Spalten unterschiedlich breit zu machen, wurde mit dem
          // Nutzer wieder verworfen — zurück zur einfachen, symmetrischen
          // Lösung).
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const padding = EdgeInsets.fromLTRB(16, 0, 16, 20);
                const spacing = 10.0;
                final zellBreite =
                    (constraints.maxWidth - padding.horizontal - spacing) / 2;
                final zellHoehe =
                    (constraints.maxHeight - padding.vertical - spacing) / 2;
                return GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  padding: padding,
                  // Clamp als Absicherung gegen extrem knappe/negative
                  // Constraints (z.B. während eines Zwischenschritts beim
                  // Öffnen/Schließen des Panels) — sonst wäre childAspectRatio
                  // <= 0 und GridView würde abstürzen.
                  childAspectRatio: (zellBreite / zellHoehe).clamp(0.4, 2.5),
                  children: [
                    for (final k in _karten)
                      _GrossKarte(
                        id: k.id,
                        asset: k.asset,
                        emoji: k.emoji,
                        title: t(k.title),
                        bg: k.bg,
                        isDone: widget.done.contains(k.id),
                        onTap: () => widget.onTap(k.id),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Große Challenge-Karte ─────────────────────────────────────────────────────

class _GrossKarte extends StatefulWidget {
  final String id, asset, emoji, title;
  final Color bg;
  final bool isDone;
  final VoidCallback onTap;
  const _GrossKarte({
    required this.id,
    required this.asset,
    required this.emoji,
    required this.title,
    required this.bg,
    required this.isDone,
    required this.onTap,
  });

  @override
  State<_GrossKarte> createState() => _GrossKarteState();
}

class _GrossKarteState extends State<_GrossKarte>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Öffnet immer den ChallengeStartScreen — der entscheidet selbst anhand
    // des Tagesstatus, ob "Spielen" oder "Ergebnis ansehen" angezeigt wird.
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0),
        child: child,
      ),
      child: GestureDetector(
        onTap: _handleTap,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: widget.bg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.all(14.rpx(context)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo groß, kein weißlicher Hintergrund
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        widget.asset,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => Center(
                          child: Text(
                            widget.emoji,
                            style: TextStyle(fontSize: 52.rsp(context)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10.rpx(context)),
                  // Titel unten — feste Höhe für exakt 2 Zeilen reserviert,
                  // damit der Icon-Bereich (Expanded oben) bei 1-zeiligen
                  // Titeln (z.B. "Ranking Quiz") nicht mehr Höhe bekommt als
                  // bei 2-zeiligen (z.B. "Portfolio des Tages") — sonst
                  // wirken die Icons trotz gleich großer Kacheln
                  // unterschiedlich groß. Skaliert mit rpx() (nicht rsp()),
                  // da sie zur Schriftgröße passen muss, die selbst mit
                  // rsp() wächst — beide zusammen halten das Verhältnis.
                  SizedBox(
                    height: 42.rpx(context),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.rsp(context),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isDone)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 22.rpx(context),
                  height: 22.rpx(context),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: const Color(0xFF4A9E4A),
                    size: 16.rpx(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Challenge-Button (oben rechts, fixed) ────────────────────────────────────

class _ChallengeBtn extends StatefulWidget {
  final int doneCount;
  final VoidCallback onTap;
  const _ChallengeBtn({required this.doneCount, required this.onTap});

  @override
  State<_ChallengeBtn> createState() => _ChallengeBtnState();
}

class _ChallengeBtnState extends State<_ChallengeBtn>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut));
    _syncAnim();
  }

  @override
  void didUpdateWidget(_ChallengeBtn old) {
    super.didUpdateWidget(old);
    _syncAnim();
  }

  void _syncAnim() {
    if (widget.doneCount < 4) {
      if (!_glowCtrl.isAnimating) _glowCtrl.repeat();
    } else {
      _glowCtrl.stop();
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const sockelH = 4.0;
    const outer = 58.0;
    const inner = 50.0;
    const pad = (outer - inner) / 2; // 4px
    const outerBr = BorderRadius.all(Radius.circular(16));
    const innerBr = BorderRadius.all(Radius.circular(14));
    final allDone = widget.doneCount >= 4;
    final badgeColor = allDone
        ? const Color(0xFF4A9E4A)
        : const Color(0xFFE53935);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: SizedBox(
        width: outer,
        height: outer + sockelH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Viereckiger Glow (pulsiert, nur wenn nicht alle erledigt)
            if (!allDone)
              AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, _) {
                  final v = _glowAnim.value;
                  final extra = v * 16;
                  final glowSize = outer + extra;
                  final offset = -(extra / 2);
                  return Positioned(
                    top: offset + 3,
                    left: offset,
                    width: glowSize,
                    height: glowSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18 + v * 4),
                        border: Border.all(
                          color: const Color(
                            0xFF4A9E4A,
                          ).withValues(alpha: (0.6 - v * 0.6).clamp(0, 1)),
                          width: (2.5 - v * 2.0).clamp(0.1, 2.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4A9E4A).withValues(
                              alpha: (0.15 - v * 0.15).clamp(0, 0.15),
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            // Äußerer 3D-Rahmen (LinearGradient + BoxShadow)
            Positioned(
              top: 2,
              left: 0,
              child: Container(
                width: outer,
                height: outer,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFE0DDD6)],
                  ),
                  borderRadius: outerBr,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(2, 5),
                    ),
                    BoxShadow(
                      color: Color(0xCCFFFFFF),
                      blurRadius: 3,
                      offset: Offset(-1, -2),
                    ),
                  ],
                ),
              ),
            ),
            // Innerer Sockel (dunkelgrün, fix)
            Positioned(
              top: pad + sockelH,
              left: pad,
              width: inner,
              height: inner,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF3D8B3D),
                  borderRadius: innerBr,
                ),
              ),
            ),
            // Innere Deckfläche (animiert, sinkt beim Drücken)
            AnimatedPositioned(
              duration: Duration(milliseconds: _pressed ? 50 : 100),
              curve: Curves.easeOut,
              top: _pressed ? pad + sockelH : pad,
              left: pad,
              width: inner,
              height: inner,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xFF5DBB63), Color(0xFF4A9E4A)],
                    center: Alignment(-0.3, -0.3),
                    radius: 0.8,
                  ),
                  borderRadius: innerBr,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      offset: Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                    SizedBox(height: 1),
                    Text(
                      'Daily',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Badge (erledigte Challenges)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${widget.doneCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
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

// ── Welt-Übersicht Sheet ──────────────────────────────────────────────────────

class _WeltUebersichtSheet extends StatefulWidget {
  final LernpfadSnapshot? snap;
  final LernWelt aktivWelt;
  final void Function(LernWelt) onWelt;
  const _WeltUebersichtSheet({
    required this.snap,
    required this.aktivWelt,
    required this.onWelt,
  });

  @override
  State<_WeltUebersichtSheet> createState() => _WeltUebersichtSheetState();
}

class _WeltUebersichtSheetState extends State<_WeltUebersichtSheet> {
  @override
  Widget build(BuildContext context) {
    final snap = widget.snap;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: kHintergrund,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            t('Alle Welten'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: lernwelten.map((w) {
                  final frei =
                      snap?.istWeltFrei(w.id) ?? (w.reihenfolge == 1);
                  final fortschritt = snap?.weltFortschritt(w.id) ?? 0.0;
                  final istAktiv = w.id == widget.aktivWelt.id;
                  return GestureDetector(
                    onTap: frei
                        ? () => widget.onWelt(w)
                        : () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => _KontinentFreischaltenDialog(
                              weltId: w.id,
                              weltName: w.name,
                              onFreigeschaltet: () => widget.onWelt(w),
                            ),
                          ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: istAktiv
                            ? const Color(0xFF4A9E4A).withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: istAktiv
                            ? Border.all(
                                color: const Color(0xFF4A9E4A),
                                width: 2,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            w.emoji,
                            style: TextStyle(
                              fontSize: 22,
                              color: frei ? null : const Color(0xFFCCCCCC),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(w.name),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: frei
                                        ? const Color(0xFF1a1a1a)
                                        : const Color(0xFF999999),
                                  ),
                                ),
                                if (frei) ...[
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: fortschritt,
                                    backgroundColor: const Color(0xFFD4D4CC),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF4A9E4A),
                                        ),
                                    minHeight: 4,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            frei ? '${(fortschritt * 100).round()}%' : '🔒',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: frei
                                  ? const Color(0xFF4A9E4A)
                                  : const Color(0xFFBBBBBB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kontinent per Werbung freischalten ──────────────────────────────────────

class _KontinentFreischaltenDialog extends StatefulWidget {
  final String weltId;
  final String weltName;
  final VoidCallback onFreigeschaltet;
  const _KontinentFreischaltenDialog({
    required this.weltId,
    required this.weltName,
    required this.onFreigeschaltet,
  });

  @override
  State<_KontinentFreischaltenDialog> createState() =>
      _KontinentFreischaltenDialogState();
}

class _KontinentFreischaltenDialogState
    extends State<_KontinentFreischaltenDialog> {
  int _angesehen = 0;
  bool _ladeAd = false;
  bool _nichtVerfuegbar = false;

  @override
  void initState() {
    super.initState();
    FortschrittService.kontinentWerbungenAngesehen(widget.weltId).then((n) {
      if (mounted) setState(() => _angesehen = n);
    });
  }

  Future<void> _werbungAnsehen() async {
    setState(() {
      _ladeAd = true;
      _nichtVerfuegbar = false;
    });

    final belohnt = await AdService.zeigeRewardedAd(onBelohnt: () {});
    if (!mounted) return;

    if (!belohnt) {
      setState(() {
        _ladeAd = false;
        _nichtVerfuegbar = true;
      });
      return;
    }

    final neuerStand = await FortschrittService.kontinentWerbungErhoehen(
      widget.weltId,
    );
    if (!mounted) return;

    if (neuerStand >= FortschrittService.kontinentWerbungenNoetig) {
      Navigator.pop(context);
      widget.onFreigeschaltet();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('🎉 {welt} ist jetzt freigeschaltet!', {
              'welt': t(widget.weltName),
            }),
          ),
          backgroundColor: const Color(0xFF4A9E4A),
        ),
      );
      return;
    }

    setState(() {
      _angesehen = neuerStand;
      _ladeAd = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final noetig = FortschrittService.kontinentWerbungenNoetig;
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: kHintergrund,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            t('Diesen Kontinent freischalten'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            t('Schau dir {n} kurze Werbungen an, um {welt} freizuschalten', {
              'n': '$noetig',
              'welt': t(widget.weltName),
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(noetig, (i) {
              final gesehen = i < _angesehen;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gesehen
                      ? const Color(0xFF4A9E4A)
                      : const Color(0xFFD4D4CC),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            t('{n} von {gesamt} angesehen', {
              'n': '$_angesehen',
              'gesamt': '$noetig',
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
          if (_nichtVerfuegbar) ...[
            const SizedBox(height: 12),
            Text(
              t('Werbung aktuell nicht verfügbar, versuch es später erneut'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _ladeAd ? null : _werbungAnsehen,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A9E4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _ladeAd
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    t('Werbung ansehen'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
