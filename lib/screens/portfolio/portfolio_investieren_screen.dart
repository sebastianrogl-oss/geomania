import 'dart:math';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import '../../data/portfolio_daten.dart';
import '../../services/portfolio_engine.dart';
import '../../services/portfolio_markt_service.dart';
import '../../services/portfolio_rendite_service.dart';
import '../../services/portfolio_service.dart';
import '../../services/tages_seed_service.dart';
import '../../services/auth_service.dart';
import '../../services/rangliste_service.dart';
import 'portfolio_aufloesung_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Screen 2: Investieren (Karten-Deck + Gewichtung) (Phase 5)
// ══════════════════════════════════════════════════════════════════════════════

const Map<String, Color> _kontinentFarben = {
  'europa': Color(0xFF1565C0),
  'asien': Color(0xFF7C3AED),
  'amerika': Color(0xFF2E7D32),
  'afrika': Color(0xFFE65100),
  'ozeanien': Color(0xFF00838F),
};

Color _kontinentFarbe(String iso) =>
    _kontinentFarben[landKontinent[iso]] ?? const Color(0xFF888888);

class PortfolioInvestierenScreen extends StatefulWidget {
  final PortfolioStatus status;
  final TagesMarkt markt;
  const PortfolioInvestierenScreen(
      {super.key, required this.status, required this.markt});

  @override
  State<PortfolioInvestierenScreen> createState() =>
      _PortfolioInvestierenScreenState();
}

class _PortfolioInvestierenScreenState
    extends State<PortfolioInvestierenScreen> {
  static const _kAuswahlAnzahl = 3;

  late final PageController _pageCtrl = PageController(viewportFraction: 0.72);
  double _seite = 0;

  final List<String> _gewaehlt = [];
  bool _gewichtungPhase = false;
  bool _wirdAbgeschlossen = false;
  Map<String, int> _gewichte = {};
  String? _aktivesPreset;

  late final Map<String, double> _erwartungen = {
    for (final iso in widget.markt.laenderPool)
      iso: erwarteteRendite(iso, widget.markt.news, widget.status.trend),
  };
  late final double _minErwartung = _erwartungen.values.reduce(min);
  late final double _maxErwartung = _erwartungen.values.reduce(max);

  @override
  void initState() {
    super.initState();
    _pageCtrl.addListener(() {
      setState(() => _seite = _pageCtrl.page ?? 0);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Auswahl-Logik ─────────────────────────────────────────────────────────

  double _chanceFraktion(String iso) {
    final spanne = (_maxErwartung - _minErwartung).abs() < 0.01
        ? 1.0
        : _maxErwartung - _minErwartung;
    return ((_erwartungen[iso]! - _minErwartung) / spanne).clamp(0.0, 1.0);
  }

  void _tippLand(String iso) {
    setState(() {
      if (_gewaehlt.contains(iso)) {
        _gewaehlt.remove(iso);
        _gewichtungPhase = false;
      } else if (_gewaehlt.length < _kAuswahlAnzahl) {
        _gewaehlt.add(iso);
        if (_gewaehlt.length == _kAuswahlAnzahl) {
          _wendePresetAn('gleich');
          _gewichtungPhase = true;
        }
      }
    });
  }

  Map<String, int> _presetGewichte(String preset) {
    final a = _gewaehlt[0], b = _gewaehlt[1], c = _gewaehlt[2];
    switch (preset) {
      case 'favorit':
        return {a: 50, b: 25, c: 25};
      case 'konzentriert':
        return {a: 70, b: 15, c: 15};
      case 'gleich':
      default:
        return {a: 34, b: 33, c: 33};
    }
  }

  void _wendePresetAn(String preset) {
    setState(() {
      _gewichte = _presetGewichte(preset);
      _aktivesPreset = preset;
    });
  }

  void _nudge(String iso, int delta) {
    final andere = _gewaehlt.where((i) => i != iso).toList();
    setState(() {
      if (delta > 0) {
        andere.sort((a, b) => _gewichte[b]!.compareTo(_gewichte[a]!));
        for (final donor in andere) {
          if (_gewichte[donor]! - delta >= 0 && _gewichte[iso]! + delta <= 100) {
            _gewichte[donor] = _gewichte[donor]! - delta;
            _gewichte[iso] = _gewichte[iso]! + delta;
            break;
          }
        }
      } else {
        final d = -delta;
        andere.sort((a, b) => _gewichte[a]!.compareTo(_gewichte[b]!));
        for (final empfaenger in andere) {
          if (_gewichte[iso]! - d >= 0 && _gewichte[empfaenger]! + d <= 100) {
            _gewichte[empfaenger] = _gewichte[empfaenger]! + d;
            _gewichte[iso] = _gewichte[iso]! - d;
            break;
          }
        }
      }
      _aktivesPreset = null;
    });
  }

  double _gewichtetesRisiko() {
    var summe = 0.0;
    for (final iso in _gewaehlt) {
      summe += (_gewichte[iso]! / 100) * landProfile[iso]!.risiko;
    }
    return summe;
  }

  (String, Color, String) _risikoAmpel(double risiko) {
    if (risiko < 0.35) return ('niedrig', const Color(0xFF4A9E4A), '🟢');
    if (risiko < 0.65) return ('mittel', const Color(0xFFF9A825), '🟡');
    return ('hoch', const Color(0xFFE53935), '🔴');
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

    if (AuthService.uid != null) {
      await RanglisteService.portfolioKapitalSpeichern(neuerStatus.kapital);
      final altesKapital = widget.status.kapital;
      if (altesKapital > 0) {
        final tagesRenditeInProzent =
            (neuerStatus.kapital - altesKapital) / altesKapital;
        await RanglisteService.ergebnisSpeichern(
          challengeId: 'portfolio',
          wert: (tagesRenditeInProzent * 100).round(),
        );
      }
    }

    if (!mounted) return;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _gewichtungPhase ? _buildGewichtung() : _buildDeck(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
              _gewichtungPhase ? 'Kapital verteilen' : 'Wähle $_kAuswahlAnzahl Länder',
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

  // ── Karten-Deck ───────────────────────────────────────────────────────────

  Widget _buildDeck() {
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.markt.laenderPool.length,
            itemBuilder: (_, i) => _buildKarte(widget.markt.laenderPool[i], i),
          ),
        ),
        const SizedBox(height: 12),
        if (_gewaehlt.isNotEmpty) _buildAusgewaehlteLeiste(),
      ],
    );
  }

  Widget _buildKarte(String iso, int index) {
    final profil = landProfile[iso]!;
    final diff = _seite - index;
    final scale = (1 - diff.abs() * 0.18).clamp(0.80, 1.0);
    final opacity = (1 - diff.abs() * 0.55).clamp(0.35, 1.0);
    final ausgewaehlt = _gewaehlt.contains(iso);
    final inNews = widget.markt.news
        .any((n) => n.gewinner.contains(iso) || n.verlierer.contains(iso));
    final trendProfitiert = profil.sektoren.contains(widget.status.trend.sektor);

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: () => _tippLand(iso),
          child: Container(
            margin: EdgeInsets.symmetric(
                horizontal: 6, vertical: ausgewaehlt ? 0 : 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: ausgewaehlt
                    ? const Color(0xFF1A1A1A)
                    : inNews
                        ? const Color(0xFFF9A825)
                        : const Color(0xFFEAEAE5),
                width: ausgewaehlt ? 3.5 : (inNews ? 2.5 : 1.5),
              ),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF1A1A1A),
                    offset: Offset(0, ausgewaehlt ? 3 : 6),
                    blurRadius: 0),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20)),
                      child: SizedBox(
                        width: double.infinity,
                        height: 100,
                        child: CountryFlag.fromCountryCode(iso,
                            width: double.infinity, height: 100),
                      ),
                    ),
                    if (ausgewaehlt)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 16),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(landName(iso),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _kontinentFarbe(iso),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(kontinentName(iso),
                            style: const TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                      const SizedBox(height: 10),
                      _buildBalken('Chance', _chanceFraktion(iso),
                          const Color(0xFF4A9E4A)),
                      const SizedBox(height: 5),
                      _buildBalken('Stabilität', (1 - profil.risiko).clamp(0.0, 1.0),
                          const Color(0xFF4A90D9)),
                      if (inNews) ...[
                        const SizedBox(height: 8),
                        _buildTag('🔥 heute in den News', const Color(0xFFF9A825)),
                      ],
                      if (trendProfitiert) ...[
                        const SizedBox(height: 6),
                        _buildTag('📈 Trend-Sektor', const Color(0xFF1A1A1A)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalken(String label, double fraktion, Color farbe) {
    final gefuellt = (fraktion * 5).round().clamp(0, 5);
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF888888),
                  fontWeight: FontWeight.w600)),
        ),
        ...List.generate(5, (i) => Container(
          width: 13, height: 8,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: i < gefuellt ? farbe : const Color(0xFFEAEAE5),
            borderRadius: BorderRadius.circular(2),
          ),
        )),
      ],
    );
  }

  Widget _buildTag(String text, Color farbe) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: farbe.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: farbe)),
    );
  }

  Widget _buildAusgewaehlteLeiste() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _gewaehlt.map((iso) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CountryFlag.fromCountryCode(iso, width: 42, height: 28),
              ),
              const SizedBox(height: 2),
              Text(
                landName(iso).length > 9
                    ? '${landName(iso).substring(0, 8)}…'
                    : landName(iso),
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        )).toList(),
      ),
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
          GestureDetector(
            onTap: () => setState(() => _gewichtungPhase = false),
            child: const Text('← Auswahl ändern',
                style: TextStyle(fontSize: 12, color: Color(0xFF888888),
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          const Text('PRESETS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Color(0xFF888888), letterSpacing: 1.2)),
          const SizedBox(height: 8),
          _buildPresetButton('gleich', 'Gleich verteilt', '34 / 33 / 33'),
          const SizedBox(height: 8),
          _buildPresetButton('favorit', 'Ein Favorit', '50 / 25 / 25'),
          const SizedBox(height: 8),
          _buildPresetButton('konzentriert', 'Alles auf einen', '70 / 15 / 15'),
          const SizedBox(height: 20),
          const Text('DEINE GEWICHTUNG',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Color(0xFF888888), letterSpacing: 1.2)),
          const SizedBox(height: 8),
          ..._gewaehlt.map(_buildGewichtZeile),
          const SizedBox(height: 16),
          if (bonus > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4A9E4A), width: 1.5),
              ),
              child: Row(children: [
                const Icon(Icons.add_circle_outline,
                    color: Color(0xFF4A9E4A), size: 16),
                const SizedBox(width: 8),
                Text('Kontinents-Synergie: +$bonus%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: Color(0xFF4A9E4A))),
              ]),
            ),
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
              Text('Depot-Risiko: $risikoLabel',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: risikoFarbe)),
            ]),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _wirdAbgeschlossen ? null : _investierenUndAbschliessen,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: _wirdAbgeschlossen
                    ? const Color(0xFFD0CEC8)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                boxShadow: _wirdAbgeschlossen
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
                  : const Text('Investieren & Tag abschließen',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String preset, String label, String verteilung) {
    final aktiv = _aktivesPreset == preset;
    return GestureDetector(
      onTap: () => _wendePresetAn(preset),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: aktiv ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: aktiv ? const Color(0xFF1A1A1A) : const Color(0xFFEAEAE5),
              width: 1.5),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF1A1A1A),
                offset: Offset(0, aktiv ? 2 : 4),
                blurRadius: 0),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: aktiv ? Colors.white : const Color(0xFF1A1A1A))),
            Text(verteilung,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: aktiv ? Colors.white70 : const Color(0xFF888888))),
          ],
        ),
      ),
    );
  }

  Widget _buildGewichtZeile(String iso) {
    final gewicht = _gewichte[iso] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAE5)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: CountryFlag.fromCountryCode(iso, width: 28, height: 19),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(landName(iso),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          _nudgeButton(Icons.remove, () => _nudge(iso, -10)),
          SizedBox(
            width: 44,
            child: Text('$gewicht%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          _nudgeButton(Icons.add, () => _nudge(iso, 10)),
        ],
      ),
    );
  }

  Widget _nudgeButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFEAEAE5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF1A1A1A)),
      ),
    );
  }
}
