import 'package:flutter/material.dart';
import '../l10n/uebersetzungen.dart';
import '../services/locale_service.dart';
import '../services/profilbild_service.dart';
import '../services/rangliste_service.dart';
import '../utils/portfolio_format.dart';

const _kMonatsnamenDe = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];
const _kMonatsnamenEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

enum _Challenge { schaetzen, higherlower, ranking, portfolio }

extension _ChallengeX on _Challenge {
  String get id => switch (this) {
        _Challenge.schaetzen => 'schaetzen',
        _Challenge.higherlower => 'higherlower',
        _Challenge.ranking => 'ranking',
        _Challenge.portfolio => 'portfolio',
      };

  String get label => switch (this) {
        _Challenge.schaetzen => t('Schätzen'),
        _Challenge.higherlower => 'Higher/Lower',
        _Challenge.ranking => 'Ranking',
        _Challenge.portfolio => 'Portfolio',
      };
}

class RanglisteScreen extends StatefulWidget {
  const RanglisteScreen({super.key});

  @override
  State<RanglisteScreen> createState() => _RanglisteScreenState();
}

class _RanglisteScreenState extends State<RanglisteScreen> {
  _Challenge _challenge = _Challenge.schaetzen;
  int _portfolioSubTab = 0; // 0 = Heute, 1 = Gesamt (Alltime)
  late Future<List<RanglistenEintrag>> _future;
  String? _eigenesProfilbild;
  // Eigener Platz im Portfolio-Gesamt-Ranking, auch außerhalb der
  // angezeigten Top 100 (siehe RanglisteService.ladeEigenenPlatzPortfolio).
  // Nur für den "Gesamt"-Unterreiter relevant, sonst immer null.
  ({int platz, int gesamt})? _eigenerPlatzPortfolio;

  // 14-Tage-Historie der Tages-Ranglisten (nicht für Portfolio "Gesamt").
  // Auf Mitternacht normalisiert, damit die Tage-Differenz-Vergleiche unten
  // nicht von der Tageszeit des jeweiligen DateTime.now()-Aufrufs abhängen.
  late DateTime _angezeigterTag = _heuteDatum;

  static DateTime get _heuteDatum {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _kannZurueck => _heuteDatum.difference(_angezeigterTag).inDays < 13;
  bool get _kannVorwaerts => _angezeigterTag.isBefore(_heuteDatum);

  @override
  void initState() {
    super.initState();
    _future = _ladeAktuelle();
    ProfilbildService.getProfilbild()
        .then((pfad) => mounted ? setState(() => _eigenesProfilbild = pfad) : null);
  }

  Future<List<RanglistenEintrag>> _ladeAktuelle() {
    if (_challenge == _Challenge.portfolio && _portfolioSubTab == 1) {
      _ladeEigenenPlatzPortfolio();
      return RanglisteService.ladePortfolioAlltime();
    }
    _eigenerPlatzPortfolio = null;
    return RanglisteService.ladeTagesRangliste(_challenge.id, tag: _angezeigterTag);
  }

  // Läuft separat/parallel zur Top-100-Liste, damit ein langsamer/fehlender
  // eigener Platz (z.B. noch nie Portfolio gespielt) die Anzeige der Liste
  // selbst nicht verzögert oder blockiert.
  Future<void> _ladeEigenenPlatzPortfolio() async {
    final platz = await RanglisteService.ladeEigenenPlatzPortfolio();
    if (mounted && _challenge == _Challenge.portfolio && _portfolioSubTab == 1) {
      setState(() => _eigenerPlatzPortfolio = platz);
    }
  }

  void _wechsleChallenge(_Challenge c) {
    if (_challenge == c) return;
    setState(() {
      _challenge = c;
      _angezeigterTag = _heuteDatum;
      _future = _ladeAktuelle();
    });
  }

  void _wechslePortfolioSubTab(int i) {
    if (_portfolioSubTab == i) return;
    setState(() {
      _portfolioSubTab = i;
      _angezeigterTag = _heuteDatum;
      _future = _ladeAktuelle();
    });
  }

  void _wechsleTag(DateTime neuerTag) {
    setState(() {
      _angezeigterTag = neuerTag;
      _future = _ladeAktuelle();
    });
  }

  Future<void> _refresh() async {
    final neu = _ladeAktuelle();
    setState(() => _future = neu);
    await neu;
  }

  String get _angezeigterTagLabel {
    final diff = _heuteDatum.difference(_angezeigterTag).inDays;
    if (diff == 0) return t('Heute');
    if (diff == 1) return t('Gestern');
    final monate = LocaleService.istEnglisch ? _kMonatsnamenEn : _kMonatsnamenDe;
    final monat = monate[_angezeigterTag.month - 1];
    return LocaleService.istEnglisch
        ? '$monat ${_angezeigterTag.day}'
        : '${_angezeigterTag.day}. $monat';
  }

  bool get _istGeld => _challenge == _Challenge.portfolio;

  bool get _istPortfolioHeute =>
      _challenge == _Challenge.portfolio && _portfolioSubTab == 0;

  // Datums-Navigation gilt für alle Tages-Ranglisten (auch Portfolio
  // "Heute"), NICHT für Portfolio "Gesamt" (All-Time-Kapital, unverändert).
  bool get _zeigeDatumsNav =>
      _challenge != _Challenge.portfolio || _portfolioSubTab == 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0E8),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Rangliste'),
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(t('Wer ist der beste Geo-Profi?'),
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  // Row mit Expanded statt Wrap: 4 Kacheln MÜSSEN in eine
                  // Zeile passen (nicht umbrechen) — auf dem Handy war dafür
                  // v.a. "Higher/Lower" zu breit, Wrap ließ die Reihe dann in
                  // 2 Zeilen umbrechen. Jede Kachel bekommt jetzt exakt 1/4
                  // der verfügbaren Breite, der Text schrumpft bei Bedarf
                  // per FittedBox statt zu überlaufen.
                  Row(
                    children: [
                      for (final c in _Challenge.values) ...[
                        if (c != _Challenge.values.first)
                          const SizedBox(width: 6),
                        Expanded(
                          child: _ChallengePill(
                            label: c.label,
                            active: _challenge == c,
                            onTap: () => _wechsleChallenge(c),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_challenge == _Challenge.portfolio) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SubTabPill(
                          label: t('Heute'),
                          active: _portfolioSubTab == 0,
                          onTap: () => _wechslePortfolioSubTab(0),
                        ),
                        const SizedBox(width: 8),
                        _SubTabPill(
                          label: t('Gesamt'),
                          active: _portfolioSubTab == 1,
                          onTap: () => _wechslePortfolioSubTab(1),
                        ),
                      ],
                    ),
                  ],
                  if (_zeigeDatumsNav) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          color: const Color(0xFF1A1A1A),
                          onPressed: _kannZurueck
                              ? () => _wechsleTag(
                                  _angezeigterTag.subtract(const Duration(days: 1)))
                              : null,
                        ),
                        Text(
                          _angezeigterTagLabel,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          color: const Color(0xFF1A1A1A),
                          onPressed: _kannVorwaerts
                              ? () => _wechsleTag(
                                  _angezeigterTag.add(const Duration(days: 1)))
                              : null,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF4A9E4A),
                onRefresh: _refresh,
                child: FutureBuilder<List<RanglistenEintrag>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 100),
                          Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF4A9E4A),
                            ),
                          ),
                        ],
                      );
                    }
                    final liste = snap.data ?? [];
                    if (liste.isEmpty) {
                      // Bei Portfolio "Gesamt" (kein Tagesbezug) und bei
                      // "Heute" bleibt die ursprüngliche "sei der Erste"-
                      // Meldung sinnvoll — bei einem vergangenen Tag wäre
                      // sie irreführend (man kann rückwirkend nicht mehr
                      // "der Erste" sein), daher dort ein neutraler Hinweis.
                      final vergangenerTag =
                          _zeigeDatumsNav && _angezeigterTag != _heuteDatum;
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        children: [_LeererZustand(vergangenerTag: vergangenerTag)],
                      );
                    }
                    // Eigener Platz außerhalb der sichtbaren Top 100 — nur
                    // im Portfolio-"Gesamt"-Tab relevant, und nur wenn die
                    // eigene uid nicht bereits in der Liste selbst auftaucht.
                    final zeigeEigenenPlatz = _challenge == _Challenge.portfolio &&
                        _portfolioSubTab == 1 &&
                        _eigenerPlatzPortfolio != null &&
                        !liste.any((e) => e.istIch) &&
                        _eigenerPlatzPortfolio!.platz > liste.length;

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: liste.length + (zeigeEigenenPlatz ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i >= liste.length) {
                          return _EigenerPlatzZeile(
                            platz: _eigenerPlatzPortfolio!.platz,
                            gesamt: _eigenerPlatzPortfolio!.gesamt,
                          );
                        }
                        return _RangZeile(
                          eintrag: liste[i],
                          istGeld: _istGeld,
                          mitVorzeichen: _istPortfolioHeute,
                          eigenesProfilbild: _eigenesProfilbild,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Challenge-Umschalter ─────────────────────────────────────────────────────

class _ChallengePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ChallengePill(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4A9E4A) : const Color(0xFFEAEAE5),
          borderRadius: BorderRadius.circular(12),
        ),
        // FittedBox statt fixer Schriftgröße: bei 4 Kacheln in einer Reihe
        // (Row+Expanded) auf einem schmalen Handyscreen reicht der Platz
        // für "Higher/Lower" bei fixem fontSize nicht immer — FittedBox
        // schrumpft den Text stattdessen leicht statt ihn abzuschneiden.
        // Feste Höhe auf dem Container (statt intrinsisch aus dem Inhalt
        // abgeleitet): ohne sie wurde die "Higher/Lower"-Kachel sichtbar
        // kleiner als die anderen drei, weil FittedBox in der unbegrenzten
        // Höhen-Achse proportional zum (stärkeren) Skalierungsfaktor des
        // längeren Texts mitschrumpft.
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubTabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SubTabPill(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1A1A1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFCCCCC5)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: active ? Colors.white : const Color(0xFF888888),
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Eigener Platz außerhalb der Top 100 ─────────────────────────────────────

class _EigenerPlatzZeile extends StatelessWidget {
  final int platz;
  final int gesamt;

  const _EigenerPlatzZeile({required this.platz, required this.gesamt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4A9E4A), width: 2.0),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle_rounded,
              color: Color(0xFF4A9E4A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t('Dein Platz: #{p} von {g}', {'p': '$platz', 'g': '$gesamt'}),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ranglisten-Zeile ─────────────────────────────────────────────────────────

class _RangZeile extends StatelessWidget {
  final RanglistenEintrag eintrag;
  final bool istGeld;
  final bool mitVorzeichen;
  final String? eigenesProfilbild;

  const _RangZeile({
    required this.eintrag,
    required this.istGeld,
    this.mitVorzeichen = false,
    this.eigenesProfilbild,
  });

  Color? get _rangFarbe => switch (eintrag.rang) {
        1 => const Color(0xFFF9A825),
        2 => const Color(0xFFB0BEC5),
        3 => const Color(0xFFA1887F),
        _ => null,
      };

  String? get _profilbildPfad =>
      eintrag.istIch ? (eigenesProfilbild ?? eintrag.profilbildPfad) : eintrag.profilbildPfad;

  @override
  Widget build(BuildContext context) {
    final hervorgehoben = eintrag.istIch;
    final rangFarbe = _rangFarbe;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: hervorgehoben ? const Color(0xFFF0F8F0) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hervorgehoben
              ? const Color(0xFF4A9E4A)
              : const Color(0xFF1A1A1A),
          width: hervorgehoben ? 2.0 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF1a1a1a),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${eintrag.rang}',
              style: TextStyle(
                fontSize: eintrag.rang == 1 ? 17 : 14,
                fontWeight: FontWeight.w900,
                color: rangFarbe ?? const Color(0xFF1A1A1A),
              ),
            ),
          ),
          _ProfilbildIcon(pfad: _profilbildPfad),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              eintrag.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          if (mitVorzeichen && eintrag.zusatzWert != null)
            // Tägliche Portfolio-Rangliste: sortiert nach eintrag.wert
            // (Prozent-Rendite) — die Prozentzahl ist daher prominent,
            // der Dollar-Betrag (zusatzWert) nur informativ darunter.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmtProzent(eintrag.wert.toDouble()),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  fmtKapital(eintrag.zusatzWert!.toDouble(),
                      mitVorzeichen: true),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            )
          else
            Text(
              istGeld
                  ? fmtKapital(eintrag.wert.toDouble(),
                      mitVorzeichen: mitVorzeichen)
                  : '${eintrag.wert}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Profilbild-Icon ────────────────────────────────────────────────────────────

class _ProfilbildIcon extends StatelessWidget {
  final String? pfad;
  const _ProfilbildIcon({required this.pfad});

  static const _platzhalter =
      Icon(Icons.person, size: 18, color: Color(0xFF888888));

  @override
  Widget build(BuildContext context) {
    final pfad = this.pfad;
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: pfad == null
          ? _platzhalter
          : ClipOval(
              child: ProfilbildService.istWeitformat(pfad)
                  // Siehe profil_screen.dart: BoxFit.cover schnitt bei
                  // "winken" die Hand ab, contain+Skalierung zeigt sie
                  // vollständig.
                  ? Transform.scale(
                      scale: 1.25,
                      child: Image.asset(pfad,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => _platzhalter),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(3),
                      child: Image.asset(pfad,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => _platzhalter),
                    ),
            ),
    );
  }
}

// ── Leerzustand ───────────────────────────────────────────────────────────────

class _LeererZustand extends StatelessWidget {
  final bool vergangenerTag;
  const _LeererZustand({this.vergangenerTag = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAE5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 12),
          Text(
            vergangenerTag
                ? t('Keine Daten für diesen Tag')
                : t('Noch keine Einträge heute — sei der Erste!'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.4),
          ),
        ],
      ),
    );
  }
}
