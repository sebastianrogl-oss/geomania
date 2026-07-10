import 'package:flutter/material.dart';
import '../data/lernpfad_data.dart';
import '../services/abzeichen_service.dart';
import '../services/challenge_rekord_service.dart';
import '../services/daily_challenge.dart';
import '../services/fortschritt_service.dart';
import '../services/portfolio_service.dart';
import '../services/portfolio_spielstil_service.dart';
import '../services/profilbild_service.dart';
import '../services/rangliste_service.dart';
import '../utils/portfolio_format.dart';
import '../widgets/muenzalbum_seite.dart';
import '../widgets/station_emoji.dart';
import 'settings_screen.dart';

const _challengeIds = ['preis', 'higher_lower', 'ranking_game', 'portfolio'];

// ── Lern-Fortschritt-Kategorien ────────────────────────────────────────────────
//
// Jeder der 21 LernModus-Werte gehört zu genau einer der 7 Kategorien. bipGesamt,
// flaeche, waehrungZuLand und extremFrageLeicht sind thematisch bei
// "Länder-Daten & Rekorde" mit einsortiert (dieselbe Gruppe wie preisSchaetzen/
// extremFrage/waehrungsQuiz), da die alte eigenständige Kategorie
// "BIP & Wirtschaft" entfällt.
const _kategorieFlaggen = {
  LernModus.flaggenQuizBild,
  LernModus.flaggenQuizMultiple,
  LernModus.flaggenQuizEingabe,
};
const _kategorieHauptstaedte = {
  LernModus.hauptstaedteMultiple,
  LernModus.hauptstaedteEingabe,
};
const _kategorieUmrisse = {
  LernModus.umrissBild,
  LernModus.umrissMultiple,
  LernModus.umrissEingabe,
};
const _kategorieLaenderDaten = {
  LernModus.preisSchaetzen,
  LernModus.extremFrage,
  LernModus.wirtschaftssektoren,
  LernModus.waehrungsQuiz,
  LernModus.bipGesamt,
  LernModus.flaeche,
  LernModus.waehrungZuLand,
  LernModus.extremFrageLeicht,
};
const _kategorieNachbarn = {
  LernModus.nachbarland,
  LernModus.grenzkettenRaetsel,
};
const _kategorieWissen = {
  LernModus.zufallsFakt,
  LernModus.bekanntesGebaeude,
};
const _kategorieSortieren = {LernModus.sortierSpiel};

// ── Screen ────────────────────────────────────────────────────────────────────

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Set<String> _done = {};
  Map<String, Set<String>> _spieltage = {};
  Map<String, int> _challengeStreaks = {};
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
    final done = await DailyChallenge.completedToday();
    final spieltage = <String, Set<String>>{
      for (final id in _challengeIds)
        id: await ChallengeRekordService.getSpieltage(id),
    };
    final streaks = <String, int>{
      for (final id in _challengeIds) id: await ChallengeRekordService.getStreak(id),
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
        _done = done;
        _spieltage = spieltage;
        _challengeStreaks = streaks;
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
  // Reale, aktuell verfügbare Kennzahl: heute abgeschlossene Challenges
  // (0-4) — dieselbe Datenquelle wie die HEUTE-Häkchen unten.
  int get _totalChallenges => _done.length;
  double _kategorieFortschritt(Set<LernModus> modi) =>
      _lpSnap?.modiFortschritt(modi) ?? 0.0;

  // ── Tages-Challenge-Statistikfelder ("Ø Punkte"/"Ø Rendite" + "Rekord") ──────

  double _avg(String id) {
    final anzahl = _challengeAnzahlGespielt[id] ?? 0;
    if (anzahl == 0) return 0;
    return (_challengeSumme[id] ?? 0) / anzahl;
  }

  String _avgPunkteText(String id) =>
      (_challengeAnzahlGespielt[id] ?? 0) == 0 ? '—' : _avg(id).round().toString();

  String _avgRenditeText(String id) =>
      (_challengeAnzahlGespielt[id] ?? 0) == 0 ? '—' : fmtProzent(_avg(id));

  String _rekordText(String id) {
    // Portfolio zeigt nur die Prozent-Rendite (kein Dollar-Betrag mehr) —
    // konsistent mit _avgRenditeText, das ebenfalls rein prozentual ist.
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
                const Text('Profil',
                    style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
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
                    onTap: _openProfilbildDialog,
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
                                ? FractionallySizedBox(
                                    widthFactor: 0.9,
                                    heightFactor: 0.9,
                                    child: Image.asset(_profilbild, fit: BoxFit.cover),
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
                  const Text('Sebastian',
                      style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  const Text('Geo-Anfänger 🌍',
                      style: TextStyle(
                          color: Color(0xFF4A9E4A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('$_streak Tage Streak',
                          style: const TextStyle(
                              color: Color(0xFFF9A825),
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Statistiken ──────────────────────────────────────────────────
            Row(
              children: [
                _StatCard(
                    value: '$_totalChallenges',
                    label: 'Challenges',
                    valueColor: const Color(0xFF4A9E4A)),
                const SizedBox(width: 8),
                _StatCard(
                    value: '$_totalSeen',
                    label: 'Stationen',
                    valueColor: const Color(0xFF1A1A1A)),
                const SizedBox(width: 8),
                const _StatCard(
                    value: '0',
                    label: 'Abzeichen',
                    valueColor: Color(0xFFF9A825)),
              ],
            ),
            const SizedBox(height: 24),

            // ── HEUTE ────────────────────────────────────────────────────────
            const Text('HEUTE',
                style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _ChallengeRow(
              logoAsset: 'assets/icons/challenge_preis.png',
              fallbackIcon: Icons.sell,
              title: 'Das große Schätzen',
              bg: const Color(0xFFFFF8E7),
              titleColor: const Color(0xFF5A3D00),
              streak: _challengeStreaks['preis'] ?? 0,
              anzahlGespielt: _challengeAnzahlGespielt['preis'] ?? 0,
              statWert1: _avgPunkteText('preis'),
              statLabel1: 'Ø Punkte',
              statWert2: _rekordText('preis'),
              spieltage: _spieltage['preis'] ?? const {},
            ),
            const SizedBox(height: 8),
            _ChallengeRow(
              logoAsset: 'assets/icons/challenge_higher_lower.png',
              fallbackIcon: Icons.swap_vert,
              title: 'Higher or Lower',
              bg: const Color(0xFFEDF7ED),
              titleColor: const Color(0xFF1A3D1A),
              streak: _challengeStreaks['higher_lower'] ?? 0,
              anzahlGespielt: _challengeAnzahlGespielt['higher_lower'] ?? 0,
              statWert1: _avgPunkteText('higher_lower'),
              statLabel1: 'Ø geschafft',
              statWert2: _rekordText('higher_lower'),
              spieltage: _spieltage['higher_lower'] ?? const {},
            ),
            const SizedBox(height: 8),
            _ChallengeRow(
              logoAsset: 'assets/icons/challenge_ranking.png',
              fallbackIcon: Icons.military_tech,
              title: 'Ranking-Quiz',
              bg: const Color(0xFFF3EEFF),
              titleColor: const Color(0xFF3B1A6B),
              streak: _challengeStreaks['ranking_game'] ?? 0,
              anzahlGespielt: _challengeAnzahlGespielt['ranking_game'] ?? 0,
              statWert1: _avgPunkteText('ranking_game'),
              statLabel1: 'Ø Punkte',
              statWert2: _rekordText('ranking_game'),
              spieltage: _spieltage['ranking_game'] ?? const {},
            ),
            const SizedBox(height: 8),
            _ChallengeRow(
              logoAsset: 'assets/icons/challenge_portfolio.png',
              fallbackIcon: Icons.business_center,
              title: 'Portfolio des Tages',
              bg: const Color(0xFFEBF3FF),
              titleColor: const Color(0xFF1A3A6B),
              streak: _challengeStreaks['portfolio'] ?? 0,
              anzahlGespielt: _challengeAnzahlGespielt['portfolio'] ?? 0,
              statWert1: _avgRenditeText('portfolio'),
              statLabel1: 'Ø Rendite',
              statWert2: _rekordText('portfolio'),
              spieltage: _spieltage['portfolio'] ?? const {},
            ),
            const SizedBox(height: 24),

            // ── SPIELSTIL (Weltportfolio) ────────────────────────────────────
            if (_spielstil != null) ...[
              const Text('DEIN INVESTOR-STIL',
                  style: TextStyle(
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
                          const Text('Dein Stil',
                              style: TextStyle(fontSize: 11, color: Color(0xFF888888),
                                  fontWeight: FontWeight.w600)),
                          Text(_spielstil!.titel,
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
            const Text('LERN-FORTSCHRITT',
                style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _ProgressRow(
              modus: LernModus.flaggenQuizBild,
              label: 'Flaggen',
              barColor: const Color(0xFF4A90D9),
              fraction: _kategorieFortschritt(_kategorieFlaggen),
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              modus: LernModus.hauptstaedteMultiple,
              label: 'Hauptstädte',
              barColor: const Color(0xFF7C3AED),
              fraction: _kategorieFortschritt(_kategorieHauptstaedte),
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              modus: LernModus.umrissBild,
              label: 'Umrisse',
              barColor: const Color(0xFF4A9E4A),
              fraction: _kategorieFortschritt(_kategorieUmrisse),
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              modus: LernModus.preisSchaetzen,
              label: 'Länder-Daten & Rekorde',
              barColor: const Color(0xFFF9A825),
              fraction: _kategorieFortschritt(_kategorieLaenderDaten),
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              modus: LernModus.nachbarland,
              label: 'Nachbarn & Grenzen',
              barColor: const Color(0xFF00897B),
              fraction: _kategorieFortschritt(_kategorieNachbarn),
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              modus: LernModus.zufallsFakt,
              label: 'Wissen & Wahrzeichen',
              barColor: const Color(0xFFC0185A),
              fraction: _kategorieFortschritt(_kategorieWissen),
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              modus: LernModus.sortierSpiel,
              label: 'Sortierspiel',
              barColor: const Color(0xFF1565C0),
              fraction: _kategorieFortschritt(_kategorieSortieren),
            ),
            const SizedBox(height: 8),
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _gewaehlt = widget.aktuellesProfilbild;
    _pruefeSwipeHinweis();
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
        color: Color(0xFFF5F5F0),
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
                      child: const Center(
                        child: Text(
                          '← Wische für dein Münzalbum',
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
                  ),
                  itemCount: ProfilbildService.verfuegbareBilder.length,
                  itemBuilder: (_, i) {
                    final pfad = ProfilbildService.verfuegbareBilder[i];
                    final ausgewaehlt = pfad == _gewaehlt;
                    return GestureDetector(
                      onTap: () => _waehle(pfad),
                      child: Container(
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
                          child: ProfilbildService.istWeitformat(pfad)
                              // Alle Globus-/Coin-Illustrationen (677x369,
                              // Bildinhalt füllt nur einen mittleren
                              // Streifen) einheitlich mit Faktor 1.5
                              // vergrößern -> geprüft dass bei allen 7
                              // übrigen Varianten der Bildinhalt erst ab
                              // Skalierung ~1.95-2.15 anschneiden würde,
                              // 1.5 bleibt also überall unbeschnitten
                              // (bei "winken" liegt die Schwelle wegen der
                              // asymmetrisch ausgestreckten Hand niedriger,
                              // bei ~1.59 — 1.5 bleibt auch dort knapp
                              // darunter).
                              ? Transform.scale(
                                  scale: 1.5,
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

// ── Stat-Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color valueColor;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEAEAE5),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Challenge-Row ─────────────────────────────────────────────────────────────

class _ChallengeRow extends StatelessWidget {
  final String logoAsset;
  final IconData fallbackIcon;
  final String title;
  final Color bg, titleColor;
  final int streak;
  final int anzahlGespielt;
  final Set<String> spieltage;
  final String statWert1;
  final String statLabel1;
  final String statWert2;

  const _ChallengeRow({
    required this.logoAsset,
    required this.fallbackIcon,
    required this.title,
    required this.bg,
    required this.titleColor,
    required this.streak,
    required this.anzahlGespielt,
    required this.spieltage,
    required this.statWert1,
    required this.statLabel1,
    required this.statWert2,
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
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF888888)),
            textAlign: TextAlign.center),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo — liegt direkt auf der Kartenfarbe, kein weißer
              // Hintergrund/Kreis mehr, deutlich kleiner als die Karte selbst.
              SizedBox(
                width: 70,
                height: 70,
                child: Image.asset(
                  logoAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Icon(fallbackIcon, size: 44, color: titleColor),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: titleColor)),
                    const SizedBox(height: 4),
                    Text(
                      streak > 0 ? '🔥 $streak Tage in Folge' : 'Noch keine Serie',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888)),
                    ),
                    const SizedBox(height: 6),
                    _StreakStreifen(spieltage: spieltage),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          anzahlGespielt > 0
              ? Row(
                  children: [
                    Expanded(child: _statFeld(statWert1, statLabel1)),
                    Expanded(child: _statFeld(statWert2, 'Rekord')),
                  ],
                )
              : const Text('Noch nicht gespielt',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
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
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
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
              const SizedBox(width: 12),
              SizedBox(
                width: 30,
                child: Text('$pct%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
