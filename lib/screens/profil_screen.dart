import 'package:flutter/material.dart';

import '../data/lernpfad_data.dart';
import '../data/modus_kategorien.dart';
import '../l10n/uebersetzungen.dart';
import '../services/ad_service.dart';
import '../services/abzeichen_service.dart';
import '../services/auth_service.dart';
import '../services/challenge_rekord_service.dart';
import '../services/fortschritt_service.dart';
import '../services/portfolio_service.dart';
import '../services/portfolio_spielstil_service.dart';
import '../services/haptik_service.dart';
import '../services/knopf_rueckmeldung.dart';
import '../services/profilbild_service.dart';
import '../services/rangliste_service.dart';
import '../utils/portfolio_format.dart';
import '../widgets/muenzalbum_seite.dart';
import '../widgets/statistik_kacheln.dart';
import '../widgets/station_emoji.dart';
import 'settings_screen.dart';
import '../theme/app_theme.dart';

const _challengeIds = ['preis', 'higher_lower', 'ranking_game', 'portfolio'];

// ── Lern-Fortschritt ──────────────────────────────────────────────────────────
//
// Welcher Modus in welchem Balken zählt, steht in lib/data/modus_kategorien.dart
// — dieser Screen rendert nur noch, was dort liegt. Ein neuer Modus wird
// ausschliesslich dort eingetragen.

// ── Screen ────────────────────────────────────────────────────────────────────

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Map<String, Set<String>> _spieltage = {};
  Map<String, int> _challengeAnzahlGespielt = {};
  Map<String, double> _challengeSumme = {};
  Map<String, int?> _challengeRekord = {};
  double? _portfolioRekordProzent;
  Set<String> _freigeschalteteAbzeichen = {};
  LernpfadSnapshot? _lpSnap;
  SpielstilErgebnis? _spielstil;
  String _profilbild = ProfilbildService.standard;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final spieltage = <String, Set<String>>{
      for (final id in _challengeIds)
        id: await ChallengeRekordService.getSpieltage(id),
    };
    final anzahlGespielt = <String, int>{
      for (final id in _challengeIds)
        id: await ChallengeRekordService.getAnzahlGespielt(id),
    };
    final summe = <String, double>{
      for (final id in _challengeIds) id: await ChallengeRekordService.getSumme(id),
    };
    final rekord = <String, int?>{
      for (final id in _challengeIds) id: await ChallengeRekordService.getRekord(id),
    };
    final portfolioRekordProzent =
        await ChallengeRekordService.getRekordProzent('portfolio');
    final freigeschaltet = await AbzeichenService.getFreigeschaltete();
    final lpSnap = await FortschrittService.ladeSnapshot();
    final spielstilDaten = await PortfolioService.ladeSpielstilRohdaten();
    final profilbild = await ProfilbildService.getProfilbild();
    if (mounted) {
      setState(() {
        _spieltage = spieltage;
        _challengeAnzahlGespielt = anzahlGespielt;
        _challengeSumme = summe;
        _challengeRekord = rekord;
        _portfolioRekordProzent = portfolioRekordProzent;
        _freigeschalteteAbzeichen = freigeschaltet;
        _lpSnap = lpSnap;
        _spielstil = berechneSpielstil(spielstilDaten);
        _profilbild = profilbild;
      });
    }
  }

  int get _streak => _lpSnap?.streak ?? 0;
  int get _totalSeen => _lpSnap?.abgeschlosseneStationenAnzahl ?? 0;
  // Die erste Statistik-Kachel zeigt seit dem Umbau den Lernpfad-Streak. Die
  // frühere Zahl der heute abgeschlossenen Challenges (aus
  // DailyChallenge.completedToday) wird dadurch nirgends mehr angezeigt und
  // ist samt ihrem Ladevorgang entfallen.
  double _kategorieFortschritt(Set<LernModus> modi) =>
      _lpSnap?.modiFortschritt(modi) ?? 0.0;

  // ── Tages-Challenge-Statistikfelder: Schnitt · Rekord · Gespielt ──────────
  //
  // Die Rohwerte kommen weiterhin aus summePunkte_* (siehe
  // ChallengeRekordService.summeErhoehen) — angezeigt wird davon aber der
  // Durchschnitt je Runde, nicht die Summe.

  /// Durchschnitt JE RUNDE, nicht die Summe über alle Tage.
  ///
  /// Eine Summe wächst mit jedem Spieltag und sagt deshalb vor allem, wie
  /// lange jemand dabei ist — neben "Rekord" und "Gespielt" steht sie damit
  /// dreimal für dasselbe. Der Schnitt beantwortet dagegen die Frage, die
  /// zwischen Bestwert und Anzahl fehlt: wie gut man üblicherweise ist.
  String _schnittPunkteText(String id) {
    final anzahl = _challengeAnzahlGespielt[id] ?? 0;
    if (anzahl == 0) return '—';
    return ((_challengeSumme[id] ?? 0) / anzahl).round().toString();
  }

  String _schnittRenditeText(String id) {
    final anzahl = _challengeAnzahlGespielt[id] ?? 0;
    if (anzahl == 0) return '—';
    return fmtProzent((_challengeSumme[id] ?? 0) / anzahl);
  }

  String _rekordText(String id) {
    // Portfolio zeigt nur die Prozent-Rendite (kein Dollar-Betrag mehr) —
    // konsistent mit _schnittRenditeText, das ebenfalls rein prozentual ist.
    if (id == 'portfolio') {
      final prozent = _portfolioRekordProzent;
      return prozent == null ? '—' : fmtProzent(prozent);
    }
    final v = _challengeRekord[id];
    return v == null ? '—' : '$v';
  }

  void _openProfilbildDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfilbildDialog(
        aktuellesProfilbild: _profilbild,
        freigeschalteteAbzeichen: _freigeschalteteAbzeichen,
        onGewaehlt: (pfad) => setState(() => _profilbild = pfad),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t('Profil'),
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                GestureDetector(
                  // Nach der Rückkehr NEU LADEN, nicht nur neu bauen.
                  //
                  // Vorher stand hier ein blosses setState: Das zeichnet die
                  // Oberfläche neu, lässt aber jedes Feld auf dem Stand, den
                  // es beim Öffnen des Profils hatte. In den Einstellungen
                  // lässt sich der Spielstand aber verändern — die Ehrenmünze
                  // "Urgestein" verleihen, Sterne gutschreiben, den
                  // Fortschritt zurücksetzen. Nichts davon kam an: Die
                  // frisch verliehene Münze blieb im Album als leeres Fach
                  // stehen, bis die App neu gestartet wurde.
                  onTap: () {
                    knopfRueckmeldung();
                    Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()))
                        .then((_) {
                      if (mounted) _load();
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings_rounded,
                        color: Color(0xFF888888), size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Avatar + Name ────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      knopfRueckmeldung();
                      _openProfilbildDialog();
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAEAE5),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF4A9E4A), width: 3),
                          ),
                          child: ClipOval(
                            child: ProfilbildService.istWeitformat(_profilbild)
                                // BoxFit.cover cropte bei den breiten Globus-/Coin-
                                // Illustrationen (677x369) zu viel vom Rand weg -
                                // bei "winken" fiel dadurch die ausgestreckte Hand
                                // teilweise weg. Fix: wie im Auswahl-Screen
                                // (weiter unten) BoxFit.contain + Skalierung, das
                                // zeigt den kompletten Bildinhalt unbeschnitten.
                                ? Transform.scale(
                                    scale: ProfilbildService.kWeitformatFaktor,
                                    child: Image.asset(_profilbild, fit: BoxFit.contain),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Image.asset(_profilbild, fit: BoxFit.contain),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A9E4A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(AuthService.anzeigename ?? t('Spieler'),
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(t('Geo-Anfänger 🌍'),
                      style: const TextStyle(
                          color: Color(0xFF4A9E4A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  // Die Streak-Zeile stand früher hier; sie ist in die
                  // Statistik-Kachel unten gewandert.
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Statistiken ──────────────────────────────────────────────────
            // Quadratische Kacheln, deren Inhalt sich aus ihrer Seitenlänge
            // ergibt — Maße und Begründung in widgets/statistik_kacheln.dart.
            StatistikKacheln(
              streak: _streak,
              stationen: _totalSeen,
              abzeichen: _freigeschalteteAbzeichen.length,
            ),
            const SizedBox(height: 24),

            // ── HEUTE ────────────────────────────────────────────────────────
            Text(t('HEUTE'),
                style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _ChallengeRow(
              logoAsset: 'assets/icons/challenge_preis.png',
              fallbackIcon: Icons.sell,
              title: t('Das große Schätzen'),
              bg: const Color(0xFFFFF8E7),
              titleColor: const Color(0xFF5A3D00),
              anzahlGespielt: _challengeAnzahlGespielt['preis'] ?? 0,
              statWert1: _schnittPunkteText('preis'),
              statLabel1: t('Schnitt'),
              statWert2: _rekordText('preis'),
              spieltage: _spieltage['preis'] ?? const {},
              titelVersatz: -3,
            ),
            const SizedBox(height: 8),
            _ChallengeRow(
              logoAsset: 'assets/icons/challenge_higher_lower.png',
              fallbackIcon: Icons.swap_vert,
              title: 'Higher or Lower',
              bg: const Color(0xFFEDF7ED),
              titleColor: const Color(0xFF1A3D1A),
              anzahlGespielt: _challengeAnzahlGespielt['higher_lower'] ?? 0,
              statWert1: _schnittPunkteText('higher_lower'),
              statLabel1: t('Schnitt'),
              statWert2: _rekordText('higher_lower'),
              spieltage: _spieltage['higher_lower'] ?? const {},
            ),
            const SizedBox(height: 8),
            _ChallengeRow(
              logoAsset: 'assets/icons/challenge_ranking.png',
              fallbackIcon: Icons.military_tech,
              title: t('Ranking-Quiz'),
              bg: const Color(0xFFF3EEFF),
              titleColor: const Color(0xFF3B1A6B),
              anzahlGespielt: _challengeAnzahlGespielt['ranking_game'] ?? 0,
              statWert1: _schnittPunkteText('ranking_game'),
              statLabel1: t('Schnitt'),
              statWert2: _rekordText('ranking_game'),
              spieltage: _spieltage['ranking_game'] ?? const {},
            ),
            const SizedBox(height: 8),
            _ChallengeRow(
              logoAsset: 'assets/icons/challenge_portfolio.png',
              fallbackIcon: Icons.business_center,
              title: t('Portfolio des Tages'),
              bg: const Color(0xFFEBF3FF),
              titleColor: const Color(0xFF1A3A6B),
              anzahlGespielt: _challengeAnzahlGespielt['portfolio'] ?? 0,
              statWert1: _schnittRenditeText('portfolio'),
              statLabel1: t('Schnitt'),
              statWert2: _rekordText('portfolio'),
              spieltage: _spieltage['portfolio'] ?? const {},
              titelVersatz: -3,
            ),
            const SizedBox(height: 24),

            // ── SPIELSTIL (Weltportfolio) ────────────────────────────────────
            if (_spielstil != null) ...[
              Text(t('DEIN INVESTOR-STIL'),
                  style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
                  ],
                ),
                child: Row(
                  children: [
                    Text(_spielstil!.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('Dein Stil'),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF888888),
                                  fontWeight: FontWeight.w600)),
                          Text(t(_spielstil!.titel),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A1A))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── LERN-FORTSCHRITT ─────────────────────────────────────────────
            Text(t('LERN-FORTSCHRITT'),
                style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            for (final kategorie in kModusKategorien) ...[
              _ProgressRow(
                modus: kategorie.symbolModus,
                label: t(kategorie.label),
                barColor: kategorie.farbe,
                fraction: _kategorieFortschritt(kategorie.modi),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Profilbild-/Abzeichen-Dialog ───────────────────────────────────────────────
//
// Antippen des Profilbilds öffnet diesen Dialog mit zwei Reitern: die
// Avatar-Auswahl (Teil 2) und die komplette Abzeichen-Galerie, die vorher
// fest im Fortschritts-Bereich stand (Teil 3) — Inhalte unverändert, nur der
// Zugangsweg hat sich geändert.
class _ProfilbildDialog extends StatefulWidget {
  final String aktuellesProfilbild;
  final Set<String> freigeschalteteAbzeichen;
  final ValueChanged<String> onGewaehlt;

  const _ProfilbildDialog({
    required this.aktuellesProfilbild,
    required this.freigeschalteteAbzeichen,
    required this.onGewaehlt,
  });

  @override
  State<_ProfilbildDialog> createState() => _ProfilbildDialogState();
}

class _ProfilbildDialogState extends State<_ProfilbildDialog> {
  late final PageController _pageController;
  late String _gewaehlt;
  int _seite = 0;
  bool _hinweisSichtbar = false;
  // Pfade der per Werbung bereits freigeschalteten Bilder (Coin/Globus sind
  // separat immer frei, siehe ProfilbildService.istImmerKostenlos, und
  // stehen NICHT in diesem Set).
  Set<String> _freigeschaltet = {};
  /// Verfügbarer Sternestand (verdient minus ausgegeben).
  int _sterne = 0;
  /// Stand vor dem letzten Kauf — Ausgangswert des Herunterzählens.
  int _sterneVorher = 0;
  /// Zuletzt gekauftes Bild — bekommt einmalig den Scale-Puls.
  String? _geradeFreigeschaltet;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _gewaehlt = widget.aktuellesProfilbild;
    _pruefeSwipeHinweis();
    _ladeFreigeschaltet();
    _ladeSterne();
  }

  Future<void> _ladeFreigeschaltet() async {
    final freigeschaltet = <String>{};
    for (final pfad in ProfilbildService.verfuegbareBilder) {
      if (await ProfilbildService.istFreigeschaltet(pfad)) {
        freigeschaltet.add(pfad);
      }
    }
    if (mounted) setState(() => _freigeschaltet = freigeschaltet);
  }

  Future<void> _ladeSterne() async {
    final snap = await FortschrittService.ladeSnapshot();
    final verfuegbar =
        await ProfilbildService.verfuegbareSterne(snap.gesamtRichtig);
    if (mounted) setState(() => _sterne = verfuegbar);
  }

  /// Kauf eines Profilbilds: bestätigen, buchen, direkt aktivieren.
  Future<void> _kaufe(String pfad, int preis) async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Text(
          t('Dieses Profilbild für {n} Sterne freischalten?',
              {'n': '$preis'}),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('Abbrechen'),
                style: const TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t('Freischalten'),
                style: const TextStyle(
                    color: Color(0xFF4A9E4A), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (bestaetigt != true || !mounted) return;

    final erfolg = await ProfilbildService.kaufeMitSternen(pfad, _sterne);
    if (!erfolg || !mounted) return;

    setState(() {
      _freigeschaltet.add(pfad);
      _sterneVorher = _sterne;
      _sterne -= preis;
      // Löst den Scale-Puls auf genau diesem Bild aus.
      _geradeFreigeschaltet = pfad;
    });
    _vibriere();
    _waehle(pfad);
  }

  // Ein mittlerer Stoss zur Bestätigung der Auswahl. Schalter und
  // Plattformweg liegen im Dienst — hier steht nur noch das Wofür.
  void _vibriere() => HaptikService.spiele(HaptikArt.mittel);

  /// Kurzer Hinweis, wenn die Sterne nicht reichen.
  void _zeigeFehlendeSterne(int fehlend) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t('Noch {n} Sterne nötig', {'n': '$fehlend'})),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _pruefeSwipeHinweis() async {
    final gezeigt = await AbzeichenService.wurdeSwipeHinweisGezeigt();
    if (gezeigt || !mounted) return;
    setState(() => _hinweisSichtbar = true);
    await AbzeichenService.setzeSwipeHinweisGezeigt();
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) setState(() => _hinweisSichtbar = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _waehle(String pfad) async {
    setState(() => _gewaehlt = pfad);
    await ProfilbildService.setProfilbild(pfad);
    await RanglisteService.profilbildAktualisieren(pfad);
    widget.onGewaehlt(pfad);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: screenH * 0.75,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: kHintergrund,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Griff
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0CEC8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Verfügbarer Sternestand — macht sichtbar, womit bezahlt wird.
          // Zählt nach einem Kauf animiert herunter.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⭐', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 5),
              TweenAnimationBuilder<int>(
                // Von-Wert ist der Stand vor dem letzten Kauf, damit sichtbar
                // heruntergezählt wird statt einfach umzuspringen.
                tween: IntTween(begin: _sterneVorher, end: _sterne),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, wert, child) => Text(
                  '$wert',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                t('Verfügbare Sterne'),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.center,
            // Stack clippt standardmäßig (Clip.hardEdge) alles was über
            // seine eigenen Grenzen hinausragt -> selbst ein Positioned mit
            // großzügigem left/right half nichts, solange der Stack selbst
            // noch schneidet. Hier explizit deaktiviert, der Hinweistext
            // bekommt seine Begrenzung ausschließlich über Positioned.
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < 2; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _seite ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _seite
                            ? const Color(0xFF4A9E4A)
                            : const Color(0xFFD0CEC8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
              if (_hinweisSichtbar)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _hinweisSichtbar ? 1 : 0,
                      duration: const Duration(milliseconds: 400),
                      child: Center(
                        child: Text(
                          t('← Wische für dein Münzalbum'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() {
                _seite = i;
                _hinweisSichtbar = false;
              }),
              children: [
                GridView.builder(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    // Zelle bewusst höher als breit: der Kreis bleibt
                    // quadratisch, darunter bleibt Platz für den
                    // Sterne-Preis. Als Verhältnis statt fester Pixel, damit
                    // der Platz auf jeder Bildschirmbreite mitwächst.
                    childAspectRatio: 0.78,
                  ),
                  itemCount: ProfilbildService.verfuegbareBilder.length,
                  itemBuilder: (_, i) {
                    final pfad = ProfilbildService.verfuegbareBilder[i];
                    final ausgewaehlt = pfad == _gewaehlt;
                    final frei = ProfilbildService.istImmerKostenlos(pfad) ||
                        _freigeschaltet.contains(pfad);
                    // Vier Bilder kosten Sterne statt einer Werbung.
                    final preis = ProfilbildService.sternePreise[pfad];
                    final kostetSterne = !frei && preis != null;
                    final bezahlbar = kostetSterne && _sterne >= preis;

                    return GestureDetector(
                      onTap: frei
                          ? () => _waehle(pfad)
                          : kostetSterne
                              ? (bezahlbar
                                  ? () => _kaufe(pfad, preis)
                                  : () => _zeigeFehlendeSterne(preis - _sterne))
                              : () => showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => _ProfilbildFreischaltenDialog(
                                  onFreigeschaltet: () async {
                                    await ProfilbildService.schalteFrei(pfad);
                                    if (mounted) {
                                      setState(
                                          () => _freigeschaltet.add(pfad));
                                    }
                                    _waehle(pfad);
                                  },
                                ),
                              ),
                      // Nach dem Kauf pulsiert genau dieses Bild einmal.
                      child: _KaufPuls(
                        aktiv: _geradeFreigeschaltet == pfad,
                        child: Column(
                          children: [
                            // Der Kreis nimmt den quadratischen Teil der
                            // Zelle ein, der Preis sitzt darunter — dadurch
                            // kann er nicht mehr abgeschnitten werden.
                            Expanded(
                              child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ausgewaehlt
                                    ? const Color(0xFF4A9E4A)
                                    : const Color(0xFFD0CEC8),
                                width: ausgewaehlt ? 3 : 1.5,
                              ),
                            ),
                            child: ClipOval(
                              child: Opacity(
                                opacity: frei ? 1.0 : 0.4,
                                child: ProfilbildService.istWeitformat(pfad)
                                    // Alle Globus-/Coin-Illustrationen (677x369,
                                    // Bildinhalt füllt nur einen mittleren
                                    // Streifen) einheitlich mit Faktor 1.25
                                    // vergrößern -> geprüft dass bei allen 7
                                    // übrigen Varianten der Bildinhalt erst ab
                                    // Skalierung ~1.95-2.15 anschneiden würde,
                                    // 1.25 bleibt also überall unbeschnitten
                                    // (bei "winken" liegt die Schwelle wegen der
                                    // asymmetrisch ausgestreckten Hand niedriger,
                                    // bei ~1.59 — 1.25 bleibt auch dort deutlich
                                    // darunter).
                                    ? Transform.scale(
                                        scale: ProfilbildService.kWeitformatFaktor,
                                        child: Image.asset(pfad, fit: BoxFit.contain),
                                      )
                                    : Padding(
                                        // Deutlich mehr Innenabstand als die
                                        // Globus-/Coin-Icons, damit die restlichen
                                        // (bereits randfüllenden) Tier-/Deko-Icons
                                        // nicht mehr unverhältnismäßig größer
                                        // wirken als die neu vereinheitlichten
                                        // Globus-/Coin-Optionen.
                                        padding: const EdgeInsets.all(14),
                                        child: Transform.scale(
                                          scale: 0.8,
                                          child: Image.asset(pfad, fit: BoxFit.contain),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          // Bilder mit Werbe-Freischaltung behalten das
                          // Schloss; Sterne-Bilder zeigen stattdessen unten
                          // ihren Preis.
                          if (!frei && !kostetSterne)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1A1A1A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.lock_rounded,
                                    color: Colors.white, size: 12),
                              ),
                            ),
                        ],
                      ),
                            ),
                            // Preis unter dem Kreis: grün wenn bezahlbar,
                            // sonst grau.
                            if (kostetSterne)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: bezahlbar
                                          ? const Color(0xFF4A9E4A)
                                          : const Color(0xFFD0CEC8),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    '⭐ $preis',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: bezahlbar
                                          ? const Color(0xFF4A9E4A)
                                          : const Color(0xFF888888),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                MuenzalbumSeite(
                  freigeschaltete: widget.freigeschalteteAbzeichen,
                  onSwipeZurueckZuProfilbild: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Einmaliger Scale-Puls nach dem Freischalten — das Bild wechselt sichtbar
/// von ausgegraut zu farbig.
class _KaufPuls extends StatefulWidget {
  final bool aktiv;
  final Widget child;
  const _KaufPuls({required this.aktiv, required this.child});

  @override
  State<_KaufPuls> createState() => _KaufPulsState();
}

class _KaufPulsState extends State<_KaufPuls>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        weight: 50,
        tween: Tween(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
      ),
      TweenSequenceItem(
        weight: 50,
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
      ),
    ]).animate(_ctrl);
    if (widget.aktiv) _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _KaufPuls old) {
    super.didUpdateWidget(old);
    if (!old.aktiv && widget.aktiv) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

// ── Profilbild per Werbung freischalten ─────────────────────────────────────

class _ProfilbildFreischaltenDialog extends StatefulWidget {
  final Future<void> Function() onFreigeschaltet;
  const _ProfilbildFreischaltenDialog({required this.onFreigeschaltet});

  @override
  State<_ProfilbildFreischaltenDialog> createState() =>
      _ProfilbildFreischaltenDialogState();
}

class _ProfilbildFreischaltenDialogState
    extends State<_ProfilbildFreischaltenDialog> {
  bool _ladeAd = false;
  bool _nichtVerfuegbar = false;

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

    Navigator.pop(context);
    await widget.onFreigeschaltet();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.paddingOf(context).bottom + 24),
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
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text(t('Dieses Profilbild freischalten'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            t('Schau eine kurze Werbung an, um dieses Bild dauerhaft freizuschalten'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _ladeAd
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(t('Werbung ansehen'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Stat-Card ─────────────────────────────────────────────────────────────────

// ── Challenge-Row ─────────────────────────────────────────────────────────────

/// Kantenlänge des Challenge-Logos.
///
/// Von 70 auf 84 gewachsen: Seit das Logo in EINER Reihe neben allem anderen
/// steht statt über den Kennzahlen, hat es die volle Kartenhöhe zur Verfügung
/// und wirkte in der alten Größe verloren.
const double _kChallengeLogo = 84;

class _ChallengeRow extends StatelessWidget {
  final String logoAsset;
  final IconData fallbackIcon;
  final String title;
  final Color bg, titleColor;
  final int anzahlGespielt;
  final Set<String> spieltage;
  final String statWert1;
  final String statLabel1;
  final String statWert2;
  // Feinjustierung der Titel-Position (negativ = nach oben) — bei "Das
  // große Schätzen"/"Portfolio des Tages" sitzt der Titel sonst spürbar
  // tiefer als bei den kürzeren Titeln der anderen beiden Challenges.
  final double titelVersatz;

  const _ChallengeRow({
    required this.logoAsset,
    required this.fallbackIcon,
    required this.title,
    required this.bg,
    required this.titleColor,
    required this.anzahlGespielt,
    required this.spieltage,
    required this.statWert1,
    required this.statLabel1,
    required this.statWert2,
    this.titelVersatz = 0,
  });

  Widget _statFeld(String zahl, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // FittedBox statt fixer Schriftgröße: schrumpft den Wert bei Bedarf
        // statt überzulaufen (z.B. bei sehr langen Prozentwerten).
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(zahl,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
        ),
        const SizedBox(height: 2),
        // Einzeilig um jeden Preis: Bei grosser Systemschrift passt selbst
        // "Rekord" nicht mehr in die rund 47 px breite Spalte eines 320-px-
        // Geräts (es bräuchte 56) und bräche auf zwei, "Gespielt" sogar auf
        // mehr Zeilen um. Ein Umbruch mitten in der Kennzahlenreihe zerreisst
        // die Optik, deshalb schrumpft die Beschriftung stattdessen — wie die
        // Zahl darüber auch. Sie bleibt dabei immer noch grösser als bei
        // normaler Schriftgrösse, die Vergrösserung wirkt also weiter.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label,
              maxLines: 1,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888)),
              textAlign: TextAlign.center),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Zwei Zeilen (Logo+Titel oben, Statistik-Werte darunter) statt EINER
    // breiten Zeile mit allem nebeneinander: bei langen Titeln (z.B. "Das
    // große Schätzen") plus dem 126px breiten 7-Tage-Streifen plus den
    // beiden Statistik-Feldern passte das auf einem Hochformat-Handyscreen
    // nicht mehr nebeneinander (RenderFlex-Overflow rechts) — untereinander
    // hat jede Zeile die volle Kartenbreite zur Verfügung.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
      ),
      // EINE Reihe statt zwei übereinander: Das Logo steht links über die
      // ganze Kartenhöhe, alles andere rechts daneben. Dadurch rücken die
      // Kennzahlen nach rechts, das Logo bekommt die volle Höhe und sitzt
      // mittig dazu, und die Kugelreihe wandert nach oben an die Stelle, an
      // der vorher die Streak-Zeile stand.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo — liegt direkt auf der Kartenfarbe, kein weißer
          // Hintergrund/Kreis.
          SizedBox(
            width: _kChallengeLogo,
            height: _kChallengeLogo,
            child: Image.asset(
              logoAsset,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) =>
                  Icon(fallbackIcon, size: _kChallengeLogo * 0.63, color: titleColor),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.translate(
                  offset: Offset(0, titelVersatz),
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: titleColor)),
                ),
                const SizedBox(height: 8),
                _StreakStreifen(spieltage: spieltage),
                const SizedBox(height: 12),
                anzahlGespielt > 0
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _statFeld(statWert1, statLabel1)),
                          Expanded(child: _statFeld(statWert2, t('Rekord'))),
                          Expanded(
                              child: _statFeld('$anzahlGespielt', t('Gespielt'))),
                        ],
                      )
                    : Text(t('Noch nicht gespielt'),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF888888))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 7-Tage-Verlaufsstreifen ────────────────────────────────────────────────────

class _StreakStreifen extends StatelessWidget {
  final Set<String> spieltage; // yyyy-mm-dd Strings
  const _StreakStreifen({required this.spieltage});

  @override
  Widget build(BuildContext context) {
    final heute = DateTime.now();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final tag = heute.subtract(Duration(days: 6 - i));
        final tagStr = '${tag.year}-${tag.month.toString().padLeft(2, '0')}-'
            '${tag.day.toString().padLeft(2, '0')}';
        final gespielt = spieltage.contains(tagStr);
        final istHeute = i == 6;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gespielt ? const Color(0xFF4A9E4A) : const Color(0xFFDDDBD5),
              border: istHeute
                  ? Border.all(color: const Color(0xFF1A1A1A), width: 1.2)
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

// ── Progress-Row ──────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  final LernModus modus;
  final String label;
  final Color barColor;
  final double fraction;

  const _ProgressRow({
    required this.modus,
    required this.label,
    required this.barColor,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (fraction * 100).round();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAE5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StationEmoji(modus: modus, status: StationStatus.aktuell, fontSize: 28),
              const SizedBox(width: 10),
              // Zwei Zeilen statt einer: "Ordnen & Vergleichen" braucht auf
              // 320 px bei Schriftskala 1.5 rund 226 px und hätte in den 216 px
              // der Zeile nicht mehr Platz — es wäre als "Ordnen & Vergleiche…"
              // erschienen. Ein FittedBox oder eine Deckelung der Schriftskala
              // träfe genau die Nutzer mit grosser Systemschrift; ein Umbruch
              // kostet dagegen nur Höhe, und die Karte steht in einer
              // Scroll-Ansicht. Unterhalb von Skala 1.5 bleibt jeder Name
              // weiterhin einzeilig, die Optik ändert sich also für die
              // meisten gar nicht.
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.15)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFD8D6D0),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 30,
                child: Text('$pct%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
