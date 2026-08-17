import 'package:flutter/material.dart';
import '../../data/portfolio_daten.dart';
import '../../l10n/uebersetzungen.dart';
import '../../services/abzeichen_service.dart';
import '../../services/challenge_ergebnis_service.dart';
import '../../services/challenge_panel_signal.dart';
import '../../services/challenge_rekord_service.dart';
import '../../services/daily_resume_service.dart';
import '../../services/portfolio_engine.dart';
import '../../services/portfolio_markt_service.dart';
import '../../services/portfolio_rendite_service.dart';
import '../../services/portfolio_service.dart';
import '../../services/tages_seed_service.dart';
import '../../services/auth_service.dart';
import '../../services/rangliste_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/abzeichen_popup.dart';
import '../../widgets/flaggen_widget.dart' show zeigeFlagge;
import '../../widgets/portfolio_flagge.dart';
import 'portfolio_aufloesung_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Screen 2: Investieren (Karten-Deck + Gewichtung) (Phase 5)
// ══════════════════════════════════════════════════════════════════════════════

Color _kontinentFarbe(String iso) => kontinentFarbeFuerId(landKontinent[iso]);

const _kPortfolioId = 'portfolio';

class PortfolioInvestierenScreen extends StatefulWidget {
  final PortfolioStatus status;
  final TagesMarkt markt;
  // Wiederherstellung eines Zwischenstands (siehe PortfolioScreen) — null
  // bei einem frisch gestarteten Investitionstag.
  final List<String>? resumeLaender;
  final Map<String, int>? resumeGewichtung;

  const PortfolioInvestierenScreen({
    super.key,
    required this.status,
    required this.markt,
    this.resumeLaender,
    this.resumeGewichtung,
  });

  @override
  State<PortfolioInvestierenScreen> createState() =>
      _PortfolioInvestierenScreenState();
}

class _PortfolioInvestierenScreenState
    extends State<PortfolioInvestierenScreen> {
  static const _kAuswahlAnzahl = 3;

  // Die 3 Ziel-Slots (null = leer). _gewaehlt bleibt als abgeleitete Liste
  // erhalten, damit der restliche Code (Gewichtung, Risiko, Kontinents-Bonus)
  // unverändert mit einer flachen Länderliste weiterarbeiten kann.
  final List<String?> _slots = List.filled(_kAuswahlAnzahl, null);
  List<String> get _gewaehlt => _slots.whereType<String>().toList();

  bool _gewichtungPhase = false;
  bool _wirdAbgeschlossen = false;
  Map<String, int> _gewichte = {};

  // Steuert PopScope.canPop (siehe build()): während der aktiven Phasen 1-3
  // bewusst false, damit Wisch-/Hardware-Zurück nicht mitten in der Runde
  // Fortschritt verwirft. Nach erfolgreichem Abschluss (Navigation zum
  // Auflösungs-Screen) auf true — sonst blockiert PopScope auch den
  // PROGRAMMATISCHEN Navigator.popUntil() aus dem "Fertig"-Button dort oben
  // im Stack: der Nutzer landete wieder auf der (bereits abgeschlossenen,
  // also nicht mehr reagierenden) Gewichtungsseite statt beim Challenge-Panel.
  bool _rundeAbgeschlossen = false;

  @override
  void initState() {
    super.initState();
    final resumeLaender = widget.resumeLaender;
    if (resumeLaender != null && resumeLaender.isNotEmpty) {
      for (var i = 0; i < resumeLaender.length && i < _slots.length; i++) {
        _slots[i] = resumeLaender[i];
      }
    }
    if (_slots.every((s) => s != null)) {
      final resumeGewichtung = widget.resumeGewichtung;
      _gewichte = (resumeGewichtung != null && resumeGewichtung.isNotEmpty)
          ? Map.of(resumeGewichtung)
          : {for (final iso in _gewaehlt) iso: 0};
      _gewichtungPhase = true;
    }
  }

  // ── Flug-Animation (Tippen auf eine Grid-Karte fliegt in den nächsten
  // freien Slot) ──────────────────────────────────────────────────────────
  final GlobalKey _stackKey = GlobalKey();
  final Map<String, GlobalKey> _gridKeys = {};
  final List<GlobalKey> _slotKeys =
      List.generate(_kAuswahlAnzahl, (_) => GlobalKey());
  String? _flugIso;
  Rect? _flugStart;
  Rect? _flugZiel;
  int? _flugZielIndex;

  // ── Auswahl-Logik ─────────────────────────────────────────────────────────

  GlobalKey _keyFuerLand(String iso) =>
      _gridKeys.putIfAbsent(iso, () => GlobalKey());

  int? _ersterFreierSlot() {
    for (var i = 0; i < _slots.length; i++) {
      if (_slots[i] == null) return i;
    }
    return null;
  }

  // Zwischenstand bei jedem Phasenübergang bzw. jeder Auswahl-/Gewichtungs-
  // Änderung sichern, damit ein Schließen der App mitten in der Runde nicht
  // zum Neustart führt (siehe PortfolioScreen._fortsetzenFallsVorhanden).
  Future<void> _zwischenstandSpeichern() async {
    await DailyResumeService.speichern(_kPortfolioId, {
      'phase': _gewichtungPhase ? 3 : 2,
      'laender': _gewaehlt,
      'gewichtung': _gewichte,
    });
  }

  void _platziereInSlot(String iso, int slotIndex) {
    if (_slots[slotIndex] != null || _slots.contains(iso)) return;
    setState(() {
      _slots[slotIndex] = iso;
      if (_slots.every((s) => s != null)) {
        // Alle Slider starten bei 0% — der Spieler verteilt das Kapital
        // selbst in 5%-Schritten (siehe _setzeGewicht), statt einer
        // vorgegebenen Zufallsverteilung. KEIN automatischer Phasenwechsel
        // mehr — der Spieler muss explizit auf "Weiter" tippen (siehe
        // _weiterZurGewichtung), damit ein Antippen des 3. Landes nicht
        // sofort ungewollt zur nächsten Phase springt.
        _gewichte = {for (final land in _gewaehlt) land: 0};
      }
    });
    _zwischenstandSpeichern();
  }

  void _weiterZurGewichtung() {
    if (_gewaehlt.length != _kAuswahlAnzahl) return;
    setState(() => _gewichtungPhase = true);
    _zwischenstandSpeichern();
  }

  void _entferneAusSlot(int index) {
    setState(() {
      _slots[index] = null;
    });
    _zwischenstandSpeichern();
  }

  // Tippen auf eine Grid-Karte: misst Start- (Karte) und Zielposition
  // (nächster freier Slot) im Koordinatensystem des umschließenden Stacks
  // und lässt eine Miniatur-Karte animiert dorthin fliegen. Die eigentliche
  // Auswahl (_platziereInSlot) passiert erst wenn die Animation fertig ist.
  void _startFlug(String iso) {
    if (_flugIso != null) return;
    final frei = _ersterFreierSlot();
    if (frei == null) return;

    final gridBox =
        _keyFuerLand(iso).currentContext?.findRenderObject() as RenderBox?;
    final slotBox =
        _slotKeys[frei].currentContext?.findRenderObject() as RenderBox?;
    final stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;

    if (gridBox == null || slotBox == null || stackBox == null) {
      _platziereInSlot(iso, frei);
      return;
    }

    final startGlobal = gridBox.localToGlobal(Offset.zero, ancestor: stackBox);
    final zielGlobal = slotBox.localToGlobal(Offset.zero, ancestor: stackBox);

    setState(() {
      _flugIso = iso;
      _flugStart = startGlobal & gridBox.size;
      _flugZiel = zielGlobal & slotBox.size;
      _flugZielIndex = frei;
    });
  }

  void _flugAbgeschlossen() {
    final iso = _flugIso;
    final ziel = _flugZielIndex;
    setState(() {
      _flugIso = null;
      _flugStart = null;
      _flugZiel = null;
      _flugZielIndex = null;
    });
    if (iso != null && ziel != null) _platziereInSlot(iso, ziel);
  }

  // Setzt das Gewicht von [iso] unabhängig von den anderen beiden Slidern
  // (keine automatische Umverteilung mehr) — hart auf ein Vielfaches von 5
  // gerundet, auch wenn der Slider selbst dank divisions:20 schon auf
  // 5%-Schritte einrastet (siehe Slider in _buildGewichtZeile). Ob die Summe
  // aller drei Gewichte 100% ergibt, prüft _gewichtungGueltig separat und
  // steuert darüber den "Investieren"-Button.
  void _setzeGewicht(String iso, int neuerWert) {
    final ziel = ((neuerWert / 5).round() * 5).clamp(0, 100);
    if (ziel == (_gewichte[iso] ?? 0)) return;
    setState(() => _gewichte[iso] = ziel);
    _zwischenstandSpeichern();
  }

  int get _gewichtungSumme => _gewichte.values.fold(0, (a, b) => a + b);
  bool get _gewichtungGueltig => _gewichtungSumme == 100;

  double _gewichtetesRisiko() {
    var summe = 0.0;
    for (final iso in _gewaehlt) {
      summe += (_gewichte[iso]! / 100) * landProfile[iso]!.risiko;
    }
    return summe;
  }

  (String, Color, String) _risikoAmpel(double risiko) {
    if (risiko < 0.35) return (t('niedrig'), const Color(0xFF4A9E4A), '🟢');
    if (risiko < 0.65) return (t('mittel'), const Color(0xFFF9A825), '🟡');
    return (t('hoch'), const Color(0xFFE53935), '🔴');
  }

  Future<void> _investierenUndAbschliessen() async {
    if (_wirdAbgeschlossen) return;
    setState(() => _wirdAbgeschlossen = true);

    final tagesSeed = TagesSeedService.seedFuer('portfolio');
    final ergebnis = berechneTagesErgebnis(
      gewichte: _gewichte,
      heutigeNews: widget.markt.news,
      trend: widget.status.trend,
      altesKapital: widget.status.kapital,
      tagesSeed: tagesSeed,
    );

    final neuerStatus = await PortfolioService.schliesseTagAb(
      neuesKapital: ergebnis.neuesKapital,
      gewichtetesRisiko: ergebnis.gewichtetesRisiko,
      effektiveLaenderzahl: ergebnis.effektiveLaenderzahl,
      newsTrefferAnzahl: ergebnis.newsTrefferAnzahl,
      trendTrefferAnzahl: ergebnis.trendTrefferAnzahl,
      anzahlLaender: _gewaehlt.length,
    );
    // Runde erfolgreich abgeschlossen -> Zwischenstand nicht mehr nötig.
    await DailyResumeService.loeschen(_kPortfolioId);

    await ChallengeErgebnisService.speichern('portfolio', {
      'ergebnis': {
        'kontinentsBonus': ergebnis.kontinentsBonus,
        'allianzBonus': ergebnis.allianzBonus,
        'erfuellteAllianzen': ergebnis.erfuellteAllianzen
            .map((n) => {
                  'titel': n.titel,
                  'allianzKontinente': n.allianzKontinente,
                  'allianzBonus': n.allianzBonus,
                })
            .toList(),
        'sektorKomboBonus': ergebnis.sektorKomboBonus,
        'erfuellteSektorKombos': ergebnis.erfuellteSektorKombos
            .map((n) => {
                  'titel': n.titel,
                  'sektorKombo': n.sektorKombo,
                  'sektorKomboBonus': n.sektorKomboBonus,
                })
            .toList(),
        'depotRenditeGesamt': ergebnis.depotRenditeGesamt,
        'altesKapital': ergebnis.altesKapital,
        'neuesKapital': ergebnis.neuesKapital,
        'gewichtetesRisiko': ergebnis.gewichtetesRisiko,
        'effektiveLaenderzahl': ergebnis.effektiveLaenderzahl,
        'newsTrefferAnzahl': ergebnis.newsTrefferAnzahl,
        'trendTrefferAnzahl': ergebnis.trendTrefferAnzahl,
        'beitraege': ergebnis.beitraege
            .map((b) => {
                  'iso': b.iso,
                  'anteilProzent': b.anteilProzent,
                  'basis': b.basis,
                  'news': b.news,
                  'newsNamen': b.newsNamen,
                  'trend': b.trend,
                  'schwankung': b.schwankung,
                  'tagesRendite': b.tagesRendite,
                  'beitragProzent': b.beitragProzent,
                })
            .toList(),
      },
    });

    final altesKapital = widget.status.kapital;
    final gewinnHeuteAbsolut = neuerStatus.kapital - altesKapital;
    final tagesRenditeProzent =
        altesKapital > 0 ? gewinnHeuteAbsolut / altesKapital * 100 : 0.0;

    final istRekord = await ChallengeRekordService.setzeFallsBesser(
        'portfolio', gewinnHeuteAbsolut.round());
    if (istRekord) {
      await ChallengeRekordService.setzeRekordProzent(
          'portfolio', tagesRenditeProzent);
    }

    if (AuthService.uid != null) {
      await RanglisteService.portfolioKapitalSpeichern(neuerStatus.kapital);
      // Tages-Rangliste sortiert nach PROZENTUALER Rendite (fair unabhängig
      // vom Startkapital) — der absolute Dollar-Betrag wird nur informativ
      // als zusatzWert mitgespeichert, siehe RanglisteErgebnisKarte-Anzeige.
      await RanglisteService.ergebnisSpeichernMitBereinigung(
        challengeId: 'portfolio',
        wert: tagesRenditeProzent,
        zusatzWert: gewinnHeuteAbsolut.round(),
      );
    }

    // Portfolio hat keine "Punktzahl" mit festem Maximum -> "perfekt" bleibt
    // hier bewusst aus, nur über Preis/Ranking erreichbar. Ein neuer Rekord
    // zeigt sich daran, dass der Rekordwert sich gegenüber vorher erhöht hat.
    final istNeuerRekord = neuerStatus.rekordKapital > widget.status.rekordKapital;
    final neueAbzeichen = await AbzeichenService.pruefeNachChallengeAbschluss(
      neuerRekordHeute: istNeuerRekord,
    );
    if (mounted && neueAbzeichen.isNotEmpty) {
      await AbzeichenPopup.zeigen(context, neueAbzeichen);
    }

    if (!mounted) return;
    setState(() => _rundeAbgeschlossen = true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PortfolioAufloesungScreen(
          ergebnis: ergebnis,
          status: neuerStatus,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Phasen 1-3 sind ein durchgehender Flow ohne Rückwärts-Navigation
    // (siehe auch _buildHeader ohne Zurück-Pfeil und _buildGewichtung ohne
    // "Auswahl ändern"-Link) — einziger Ausstieg ist der Auflösungs-Screen.
    // canPop erst nach erfolgreichem Abschluss true (siehe
    // _rundeAbgeschlossen): sonst blockiert PopScope auch das
    // programmatische Navigator.popUntil() aus dem "Fertig"-Button auf dem
    // darüberliegenden Auflösungs-Screen.
    return PopScope(
      canPop: _rundeAbgeschlossen,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _gewichtungPhase ? _buildGewichtung() : _buildAuswahl(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Zurück-Pfeil führt IMMER direkt zum Challenge-Panel/Menü (nicht zur
    // vorherigen Phase) — die PopScope-Sperre gegen Wisch-/Hardware-Zurück
    // zwischen den Phasen bleibt davon unberührt bestehen.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ChallengePanelSignal.zurueckZumPanel(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAE5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF1A1A1A), size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _gewichtungPhase
                  ? t('Kapital verteilen')
                  : t('Wähle {n} Länder', {'n': '$_kAuswahlAnzahl'}),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A)),
            ),
          ),
          if (!_gewichtungPhase)
            Text('${_gewaehlt.length} / $_kAuswahlAnzahl',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: _gewaehlt.length == _kAuswahlAnzahl
                        ? const Color(0xFF4A9E4A)
                        : const Color(0xFF888888))),
        ],
      ),
    );
  }

  // ── Länderauswahl: Grid + Ziel-Slots ────────────────────────────────────────

  Widget _buildAuswahl() {
    return Stack(
      key: _stackKey,
      children: [
        Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              // LayoutBuilder statt fixem childAspectRatio: die Karte hat
              // einen breitenunabhängigen Fixteil (Name, Sektor-/Status-Chips
              // — feste Schriftgrößen) plus einen zur Kartenbreite
              // proportionalen Flaggenanteil. Ein reines Seitenverhältnis
              // geht fälschlich davon aus, dass die GESAMTE Höhe proportional
              // zur Breite mitschrumpft — bei echter Handy-Kartenbreite
              // (~85-90px statt der ~186px im breiten Test-Fenster, in dem
              // das Verhältnis ursprünglich kalibriert wurde) reichte die so
              // berechnete Zellhöhe für den Fixteil nicht mehr aus (RenderFlex-
              // Overflow ~77-87px, per Widget-Test bei 390px/360px Breite
              // gemessen). Die Formel unten berechnet die tatsächlich nötige
              // Höhe für JEDE Breite direkt (statt eines für eine Breite
              // passenden Verhältnisses), inkl. 20px Sicherheitsmarge.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const kPadding = 12.0;
                  const kSpacing = 10.0;
                  const kCols = 2;
                  final kartenBreite = (constraints.maxWidth -
                          kPadding * 2 -
                          kSpacing * (kCols - 1)) /
                      kCols;
                  // Annähernd quadratisch statt der früheren schmalen
                  // 4-Spalten-Karten: bei 2 Spalten sind die Karten fast
                  // doppelt so breit, wodurch auch Kategorie-/Sektor-Chips
                  // ohne Abschneiden lesbar sind (siehe kleinerer
                  // Flaggen-Breitenanteil unten, damit die Flagge bei der
                  // größeren Kartenbreite nicht unproportional dominiert).
                  // Faktor 1.25 statt 1.05: der volle Karteninhalt (Flagge +
                  // Name + Kontinent-Chip + 2 volle Sektor-Chips) brauchte
                  // bei reinem 1.05-Verhältnis 31px mehr Höhe als vorhanden
                  // (per Geräte-Test gemessener RenderFlex-Overflow).
                  final kartenHoehe = kartenBreite * 1.25;
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: kPadding),
                    // Feste 2 Spalten statt MaxCrossAxisExtent: bei genau 16
                    // Ländern ergeben sich damit immer exakt 8 volle Reihen zu
                    // je 2 Karten (scrollbar), unabhängig von der
                    // Fensterbreite.
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: kCols,
                      crossAxisSpacing: kSpacing,
                      mainAxisSpacing: kSpacing,
                      mainAxisExtent: kartenHoehe,
                    ),
                    itemCount: widget.markt.laenderPool.length,
                    itemBuilder: (_, i) =>
                        _buildGridKarte(widget.markt.laenderPool[i]),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildSlotLeiste(),
            if (_gewaehlt.length >= 2) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildBonusBox(kontinentsBonusProzent(_gewaehlt)),
              ),
            ],
            // Erst hier, per explizitem Tap, geht es zur Gewichtung —
            // kein automatischer Sprung mehr sobald der 3. Slot gefüllt ist.
            if (_gewaehlt.length == _kAuswahlAnzahl) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: _weiterZurGewichtung,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4)),
                      ],
                    ),
                    child: Text(t('Weiter →'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
        if (_flugIso != null && _flugStart != null && _flugZiel != null)
          TweenAnimationBuilder<Rect?>(
            key: ValueKey('flug_$_flugIso'),
            tween: RectTween(begin: _flugStart, end: _flugZiel),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            onEnd: _flugAbgeschlossen,
            builder: (context, rect, child) {
              if (rect == null) return const SizedBox.shrink();
              // Positioned.fromRect zwingt die Karte auf die exakte,
              // interpolierte Box-Größe — vom Grid-Zellen-Maß bis zum ZIEL-
              // Rect des noch LEEREN Slots (nur 96px hoch, siehe _buildSlot),
              // was kleiner ist als die Mini-Karte braucht -> ohne Gegenmaß-
              // nahme ein RenderFlex-Overflow (gelb-schwarzer Streifen)
              // während des 400ms-Tweens. FittedBox skaliert den natürlich
              // bemessenen Karteninhalt (SizedBox unten, bewusst mit etwas
              // Marge dimensioniert) stattdessen verzerrungsfrei auf jede
              // Zielgröße, ohne dass die Column je zu wenig Platz bekommt.
              return Positioned.fromRect(
                rect: rect,
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 105,
                      height: 225,
                      child: _buildMiniKarte(_flugIso!, istAusgewaehlt: true),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Kompakte Karte für das Auswahl-Grid — NUR per Tippen auswählbar (Tap =
  // Flug-Animation in den nächsten freien Slot). Kein Drag & Drop mehr, um
  // versehentliche Auswahl durch Wischen zu vermeiden.
  Widget _buildGridKarte(String iso) {
    final ausgewaehlt = _gewaehlt.contains(iso);
    final voll = _ersterFreierSlot() == null;
    final versteckt = iso == _flugIso;
    final inaktiv = ausgewaehlt || (voll && !ausgewaehlt);

    final karte = Opacity(
      key: _keyFuerLand(iso),
      opacity: versteckt ? 0 : (inaktiv ? 0.35 : 1.0),
      child: _buildMiniKarte(iso),
    );

    if (versteckt || inaktiv) return karte;

    return GestureDetector(
      onTap: () => _startFlug(iso),
      child: karte,
    );
  }

  // Gemeinsame Kartenoptik für Grid-Zelle, Flug-Miniatur UND befüllten Slot.
  // [gross] = befüllter Slot: mehr Platz, größere Flagge/Schrift, Sektor-Chips
  // nebeneinander statt gestapelt. [istAusgewaehlt] = goldener Rahmen — nur
  // für den befüllten Slot bzw. die gerade fliegende Karte, sonst dezentes Grau.
  Widget _buildMiniKarte(String iso, {bool gross = false, bool istAusgewaehlt = false}) {
    final sektoren = landProfile[iso]!.sektoren;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(gross ? 18 : 14),
        border: Border.all(
          color: istAusgewaehlt ? const Color(0xFFF9A825) : const Color(0xFFEAEAE5),
          width: istAusgewaehlt ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.08),
              offset: const Offset(0, 3),
              blurRadius: 6),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gross)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              child: SizedBox(
                width: double.infinity,
                height: 60.rpx(context),
                child: zeigeFlagge(iso,
                    width: double.infinity, height: 60.rpx(context)),
              ),
            )
          else
            // Doppelt so groß wie zuvor (bezogen auf den früheren ~52px-
            // Breitenanteil der Karte) und horizontal mittig statt
            // linksbündig — der restliche Inhalt (Name, Badges, Chips)
            // rutscht dadurch entsprechend weiter nach unten (siehe erhöhte
            // childAspectRatio im GridView unten). LayoutBuilder statt
            // fixer Pixelwerte, damit die Flagge nie breiter als die
            // tatsächliche Kartenbreite wird (die je nach Bildschirmbreite
            // variiert, siehe SliverGridDelegateWithFixedCrossAxisCount).
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Kleinerer Breitenanteil als zuvor (0.88): bei den jetzt
                    // ~doppelt so breiten 2-Spalten-Karten würde die Flagge
                    // sonst unproportional dominieren und dem restlichen
                    // Karteninhalt (Name, Kategorie-/Sektor-Chips) den Platz
                    // nehmen, den es gerade für dessen volle Lesbarkeit braucht.
                    final breite = constraints.maxWidth * 0.55;
                    return PortfolioFlagge(
                        iso: iso, width: breite, height: breite * 36 / 52);
                  },
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: (gross ? 10 : 8).rpx(context),
                vertical: (gross ? 8 : 6).rpx(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(landName(iso),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: (gross ? 14 : 12).rsp(context),
                        fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A))),
                SizedBox(height: (gross ? 5 : 3).rpx(context)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: (gross ? 7 : 5).rpx(context),
                      vertical: (gross ? 2 : 1).rpx(context)),
                  decoration: BoxDecoration(
                    color: _kontinentFarbe(iso),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(kontinentName(iso),
                      style: TextStyle(fontSize: (gross ? 9 : 7).rsp(context),
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                SizedBox(height: (gross ? 8 : 5).rpx(context)),
                if (gross) ...[
                  // Gestapelt statt nebeneinander: die "gross"-Karte steckt in
                  // der 3-Slots-Leiste beim Auswählen (nur ~1/3 Bildschirm-
                  // breite auf dem Handy) — nebeneinander hatten die festen
                  // Chip-Mindestbreiten (Emoji+5-Punkte-Ranking) dort keinen
                  // Platz mehr und liefen über (RenderFlex-Overflow).
                  if (sektoren.isNotEmpty) _buildSektorChip(iso, 0, gross: true),
                  if (sektoren.length > 1) ...[
                    const SizedBox(height: 4),
                    _buildSektorChip(iso, 1, gross: true),
                  ],
                ] else ...[
                  if (sektoren.isNotEmpty) _buildSektorChip(iso, 0, gross: false),
                  if (sektoren.length > 1) ...[
                    const SizedBox(height: 3),
                    _buildSektorChip(iso, 1, gross: false),
                  ],
                  // Chance/Stabilität wieder auf der Grid-Karte (nur hier,
                  // nicht auf der "gross"-Slot-Karte) — abgeleitet aus den
                  // bestehenden LandProfil-Feldern (kein separates Datenfeld
                  // vorhanden): Chance = normalisiertes basisWachstum,
                  // Stabilität = 1 - risiko.
                  const SizedBox(height: 6),
                  _statusChip(t('Chance'), Icons.trending_up, _chanceWert(iso),
                      const Color(0xFF4A9E4A)),
                  const SizedBox(height: 4),
                  _statusChip(t('Stabilität'), Icons.shield, _stabilitaetWert(iso),
                      const Color(0xFF4A90D9)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // "Chance" = normalisiertes basisWachstum (~-1.0 bis 2.3 -> 0.0-1.0),
  // "Stabilität" = 1 - risiko (risiko ist bereits 0.0-1.0 skaliert).
  double _chanceWert(String iso) =>
      ((landProfile[iso]!.basisWachstum + 1.0) / 3.3).clamp(0.0, 1.0);

  double _stabilitaetWert(String iso) =>
      (1.0 - landProfile[iso]!.risiko).clamp(0.0, 1.0);

  // Identisches Design UND identische Maße wie _buildSektorChip(gross:false)
  // — bewusst exakt dieselben Zahlenwerte übernommen (nicht die größere
  // "gross"-Slot-Variante), da genau diese kompakte Chip-Größe direkt
  // darüber auf derselben Grid-Karte für die Sektoren verwendet wird. Icon
  // statt Sektor-Emoji, sonst 1:1 dieselbe Struktur (Label + 5-Punkte-Ranking).
  Widget _statusChip(String label, IconData icon, double staerke0bis1, Color farbe) {
    final ranking = (staerke0bis1 * 5).round().clamp(1, 5);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: 5.rpx(context), vertical: 2.rpx(context)),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: farbe.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 9.rpx(context), color: farbe),
          SizedBox(width: 2.rpx(context)),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 7.5.rsp(context), fontWeight: FontWeight.w700, color: farbe)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) => Container(
              margin: EdgeInsets.only(left: 0.75.rpx(context)),
              width: 3.5.rpx(context),
              height: 3.5.rpx(context),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < ranking ? farbe : farbe.withValues(alpha: 0.2),
              ),
            )),
          ),
        ],
      ),
    );
  }

  // Farbiger Chip für einen der 2 stärksten Sektoren eines Landes: Emoji +
  // Name + 1-5-Ranking (5 Segmente, N gefüllt) statt eines unauffälligen
  // Mini-Balkens. width: double.infinity statt MainAxisSize.min, damit lange
  // Sektor-Namen im schmalen Grid ellipsieren statt die Karte zu sprengen.
  Widget _buildSektorChip(String iso, int index, {required bool gross}) {
    final sektorId = landProfile[iso]!.sektoren[index];
    final sektor = portfolioSektoren.firstWhere((s) => s.id == sektorId);
    final farbe = portfolioSektorFarben[sektorId] ?? const Color(0xFF888888);
    final ranking = (getLandSektorStaerke(iso, sektorId) * 5).round().clamp(1, 5);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: (gross ? 8 : 5).rpx(context),
          vertical: (gross ? 4 : 2).rpx(context)),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: farbe.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Text(sektor.emoji, style: TextStyle(fontSize: (gross ? 11 : 9).rsp(context))),
          SizedBox(width: (gross ? 3 : 2).rpx(context)),
          Expanded(
            child: Text(t(sektor.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: (gross ? 11 : 7.5).rsp(context),
                    fontWeight: FontWeight.w700, color: farbe)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) => Container(
              margin: EdgeInsets.only(left: (gross ? 1.2 : 0.75).rpx(context)),
              width: (gross ? 4 : 3.5).rpx(context),
              height: (gross ? 4 : 3.5).rpx(context),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < ranking ? farbe : farbe.withValues(alpha: 0.2),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusBox(int bonus) {
    if (bonus <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4A9E4A), width: 1.5),
      ),
      child: Row(children: [
        const Icon(Icons.add_circle_outline, color: Color(0xFF4A9E4A), size: 16),
        const SizedBox(width: 8),
        Text(t('Kontinents-Synergie: +{n}%', {'n': '$bonus'}),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: Color(0xFF4A9E4A))),
      ]),
    );
  }

  // ── 3 Ziel-Slots ─────────────────────────────────────────────────────────

  Widget _buildSlotLeiste() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < _kAuswahlAnzahl; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _buildSlot(i)),
          ],
        ],
      ),
    );
  }

  // Kein DragTarget mehr — Slots werden ausschließlich durch Antippen einer
  // Grid-Karte befüllt (siehe _startFlug/_platziereInSlot).
  Widget _buildSlot(int index) {
    final iso = _slots[index];
    final box = Container(
      key: _slotKeys[index],
      height: iso != null ? null : 96,
      decoration: BoxDecoration(
        color: iso != null ? Colors.transparent : const Color(0xFFF5F0E8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: iso == null
          ? Center(
              child: Text(t('Slot {n}', {'n': '${index + 1}'}),
                  style: const TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: Color(0xFF999999))),
            )
          : GestureDetector(
              onTap: () => _entferneAusSlot(index),
              child: _buildMiniKarte(iso, gross: true, istAusgewaehlt: true),
            ),
    );
    if (iso != null) return box;
    return CustomPaint(
      foregroundPainter: const _GestrichelterRahmen(
        color: Color(0xFFBBBBBB),
        strokeWidth: 1.5,
        radius: 14,
      ),
      child: box,
    );
  }

  // ── Gewichtung ────────────────────────────────────────────────────────────

  Widget _buildGewichtung() {
    final bonus = kontinentsBonusProzent(_gewaehlt);
    final risiko = _gewichtetesRisiko();
    final (risikoLabel, risikoFarbe, risikoEmoji) = _risikoAmpel(risiko);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kein "Auswahl ändern"-Link mehr: Phasen 1-3 sind ein
          // durchgehender Flow ohne Rückwärts-Navigation.
          Text(t('DEINE GEWICHTUNG'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Color(0xFF888888), letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ..._gewaehlt.map(_buildGewichtZeile),
          const SizedBox(height: 16),
          if (bonus > 0) ...[
            _buildBonusBox(bonus),
            const SizedBox(height: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEAEAE5)),
            ),
            child: Row(children: [
              Text(risikoEmoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(t('Depot-Risiko: {r}', {'r': risikoLabel}),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: risikoFarbe)),
            ]),
          ),
          const SizedBox(height: 12),
          // Summen-Anzeige: rot solange die 3 Gewichte (in 5%-Schritten,
          // Start bei 0%) noch nicht exakt 100% ergeben — steuert zugleich,
          // ob der Investieren-Button aktiv ist.
          Center(
            child: Text(
              t('Summe: {n}% {status}', {
                'n': '$_gewichtungSumme',
                'status': _gewichtungGueltig ? '✓' : t('(muss 100% sein)'),
              }),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _gewichtungGueltig
                      ? const Color(0xFF4A9E4A)
                      : const Color(0xFFE53935)),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: (_wirdAbgeschlossen || !_gewichtungGueltig)
                ? null
                : _investierenUndAbschliessen,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: (_wirdAbgeschlossen || !_gewichtungGueltig)
                    ? const Color(0xFFD0CEC8)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: (_wirdAbgeschlossen || !_gewichtungGueltig)
                    ? null
                    : const [
                        BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4)),
                      ],
              ),
              child: _wirdAbgeschlossen
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: Center(
                        child: SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    )
                  : Text(t('Investieren & Tag abschließen'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGewichtZeile(String iso) {
    final gewicht = _gewichte[iso] ?? 0;
    final sektoren = landProfile[iso]!.sektoren;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAE5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PortfolioFlagge(iso: iso, width: 28, height: 19, radius: 3),
              const SizedBox(width: 8),
              Expanded(
                child: Text(landName(iso),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              SizedBox(
                width: 44,
                child: Text('$gewicht%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Sektor-Chips (2 stärkste, 1-5-Ranking) — dieselbe kompakte
          // Darstellung wie im Auswahl-Grid, damit sichtbar bleibt worauf
          // man sich beim Verteilen des Kapitals einlässt.
          Row(
            children: [
              if (sektoren.isNotEmpty)
                Expanded(child: _buildSektorChip(iso, 0, gross: false)),
              if (sektoren.length > 1) ...[
                const SizedBox(width: 6),
                Expanded(child: _buildSektorChip(iso, 1, gross: false)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF1A1A1A),
              inactiveTrackColor: const Color(0xFFEAEAE5),
              thumbColor: const Color(0xFF1A1A1A),
              overlayColor: const Color(0x1A1A1A1A),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              // Unterdrückt die grüne Wert-Blase beim Ziehen komplett,
              // unabhängig davon ob ein label gesetzt ist — der Prozentwert
              // steht bereits fest neben dem Slider (siehe oben).
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: gewicht.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (v) => _setzeGewicht(iso, v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

// Flutter hat keinen eingebauten gestrichelten Rand — statt einer neuen
// Paket-Abhängigkeit (z.B. dotted_border) reicht ein kleiner CustomPainter
// für die leeren Ziel-Slots.
class _GestrichelterRahmen extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  static const _dashWidth = 6.0;
  static const _dashGap = 5.0;

  const _GestrichelterRahmen({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final rand = Path()..addRRect(rrect);
    final gestrichelt = Path();
    for (final metric in rand.computeMetrics()) {
      var distanz = 0.0;
      var zeichnen = true;
      while (distanz < metric.length) {
        final laenge = zeichnen ? _dashWidth : _dashGap;
        if (zeichnen) {
          gestrichelt.addPath(
              metric.extractPath(
                  distanz, (distanz + laenge).clamp(0, metric.length)),
              Offset.zero);
        }
        distanz += laenge;
        zeichnen = !zeichnen;
      }
    }
    canvas.drawPath(gestrichelt, paint);
  }

  @override
  bool shouldRepaint(covariant _GestrichelterRahmen oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      radius != oldDelegate.radius;
}
