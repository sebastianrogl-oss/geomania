import 'dart:math';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import '../data/country_rankings.dart';
import '../services/challenge_rekord_service.dart';
import '../services/tages_seed_service.dart';
import '../services/rangliste_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatRang(int rang) {
  if (rang >= 100) return '#100+';
  return '#$rang';
}

int _berechnePunkte(int rang) {
  if (rang >= 100) return 0;
  return (101 - rang).clamp(0, 100);
}

// ── Zuordnung pro Kategorie ───────────────────────────────────────────────────

class _Zuordnung {
  final CountryRanking land;
  final int rang;
  final int punkte;
  const _Zuordnung(
      {required this.land, required this.rang, required this.punkte});
}

// ── Kategorie-Button ──────────────────────────────────────────────────────────

class _KatButton extends StatefulWidget {
  final String emoji;
  final String label;
  final bool zugeordnet;
  final String? flagIso2;
  final int? rang;
  final VoidCallback? onTap;

  const _KatButton({
    required this.emoji,
    required this.label,
    required this.zugeordnet,
    required this.onTap,
    this.flagIso2,
    this.rang,
  });

  @override
  State<_KatButton> createState() => _KatButtonState();
}

class _KatButtonState extends State<_KatButton> {
  bool _pressed = false;

  bool get _tappable => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final pressing = _pressed && _tappable;
    final topMargin = 5.0 + (pressing ? 4.0 : 0.0);
    final bottomMargin = 9.0 - (pressing ? 4.0 : 0.0);

    return GestureDetector(
      onTapDown: _tappable ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _tappable
          ? (_) {
              if (!_pressed) return;
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: _tappable ? () => setState(() => _pressed = false) : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: pressing ? 50 : 200),
        margin: EdgeInsets.fromLTRB(16, topMargin, 16, bottomMargin),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF1A1A1A),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1A1A),
              offset: Offset(0, pressing ? 0 : 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A)),
                ),
              ),
              if (widget.zugeordnet && widget.rang != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 1,
                  height: 16,
                  color: const Color(0xFFD0CEC8),
                ),
                if (widget.flagIso2 != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: CountryFlag.fromCountryCode(
                      widget.flagIso2!,
                      width: 24,
                      height: 16,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  _formatRang(widget.rang!),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status ────────────────────────────────────────────────────────────────────

enum _Status { laden, spielen, aufloesung }

// ── Screen ────────────────────────────────────────────────────────────────────

class RankingGameScreen extends StatefulWidget {
  const RankingGameScreen({super.key});
  @override
  State<RankingGameScreen> createState() => _RankingGameScreenState();
}

class _RankingGameScreenState extends State<RankingGameScreen> {
  static const _kId = 'ranking_game';
  static const _kAnzahl = 8;

  List<CountryRanking> _laender = [];
  List<RankingCategory> _tagesKats = [];
  Map<String, _Zuordnung> _zuordnungen = {};
  Set<String> _verwendeteKategorien = {};
  int _aktuellerIndex = 0;
  int? _rekord;
  bool _neuerRekord = false;
  _Status _status = _Status.laden;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _rekord = await ChallengeRekordService.getRekord(_kId);
    _baue();
  }

  void _baue() {
    final seed = TagesSeedService.seedFuer(_kId);
    final katRng = Random(seed + 77);
    final tagesKats =
        (List.of(rankingCategories)..shuffle(katRng)).take(_kAnzahl).toList();

    final rng = Random(seed);
    final pool = countryRankings
        .where((c) =>
            c.gdpPerCapita != null &&
            c.population != null &&
            c.area != null &&
            c.lifeExpectancy != null)
        .toList()
      ..shuffle(rng);
    final laender = pool.take(_kAnzahl).toList();

    setState(() {
      _tagesKats = tagesKats;
      _laender = laender;
      _zuordnungen = {};
      _verwendeteKategorien = {};
      _aktuellerIndex = 0;
      _status = _Status.spielen;
    });
  }

  int _weltrang(CountryRanking land, RankingCategory kat) {
    final wert = kat.getValue(land);
    if (wert == null || wert <= 0) return 999;
    return countryRankings
            .where((c) => (kat.getValue(c) ?? 0) > wert)
            .length +
        1;
  }

  void _tippKategorie(String katId) {
    if (_verwendeteKategorien.contains(katId)) return;
    if (_aktuellerIndex >= _laender.length) return;

    final land = _laender[_aktuellerIndex];
    final kat = _tagesKats.firstWhere((k) => k.id == katId);
    final rang = _weltrang(land, kat);
    final punkte = _berechnePunkte(rang);

    setState(() {
      _zuordnungen[katId] =
          _Zuordnung(land: land, rang: rang, punkte: punkte);
      _verwendeteKategorien.add(katId);
      _aktuellerIndex++;
    });

    if (_aktuellerIndex >= _laender.length) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _abschliessen();
      });
    }
  }

  Future<void> _abschliessen() async {
    final pts = _gesamtPunkte();
    _neuerRekord = await ChallengeRekordService.setzeFallsBesser(_kId, pts);
    await ChallengeRekordService.speichereHeutigePunkte(_kId, pts);
    if (_neuerRekord) _rekord = pts;
    await RanglisteService.ergebnisSpeichern(challengeId: 'ranking', wert: pts);
    setState(() => _status = _Status.aufloesung);
  }

  int _gesamtPunkte() =>
      _zuordnungen.values.fold(0, (sum, z) => sum + z.punkte);

  // iso2 → katId: greedy bijection (bestes Land je Kategorie)
  // Optimale Zuordnung (maximale Gesamtpunktzahl) per Bitmask-DP.
  // Ein gieriger Ansatz (höchste Einzelpunktzahl zuerst) kann ein Land
  // fälschlich auf 0 Punkte zwingen, obwohl eine bessere Gesamtlösung
  // existiert – siehe Assignment-Problem.
  Map<String, String> _berechneIdealeKonstellation() {
    final n = _laender.length;
    final punkte = List.generate(
      n,
      (i) => List.generate(
          n, (j) => _berechnePunkte(_weltrang(_laender[i], _tagesKats[j]))),
    );

    final voll = (1 << n) - 1;
    final dp = List<int>.filled(1 << n, -1);
    final wahl = List<int>.filled(1 << n, -1);
    dp[0] = 0;

    for (int mask = 0; mask <= voll; mask++) {
      if (dp[mask] < 0) continue;
      final land = _bitCount(mask); // Index des als Nächstes zuzuordnenden Landes
      if (land >= n) continue;
      for (int kat = 0; kat < n; kat++) {
        if (mask & (1 << kat) != 0) continue;
        final neueMask = mask | (1 << kat);
        final neuerWert = dp[mask] + punkte[land][kat];
        if (neuerWert > dp[neueMask]) {
          dp[neueMask] = neuerWert;
          wahl[neueMask] = kat;
        }
      }
    }

    final ergebnis = <String, String>{}; // iso2 → katId
    var mask = voll;
    for (int land = n - 1; land >= 0; land--) {
      final kat = wahl[mask];
      ergebnis[_laender[land].iso2] = _tagesKats[kat].id;
      mask &= ~(1 << kat);
    }
    return ergebnis;
  }

  int _bitCount(int mask) {
    var count = 0;
    while (mask != 0) {
      count += mask & 1;
      mask >>= 1;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: switch (_status) {
        _Status.laden => const Center(
            child: CircularProgressIndicator(color: Color(0xFF4A9E4A))),
        _Status.spielen => _buildSpiel(),
        _Status.aufloesung => _buildAufloesung(),
      },
    );
  }

  // ── Spielphase ────────────────────────────────────────────────────────────────

  Widget _buildSpiel() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          const Divider(color: Color(0xFFD0CEC8), height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: _buildKategorieButtons(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final fertig = _aktuellerIndex >= _laender.length;

    if (fertig) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: Text(
            'Alle Länder zugeordnet!',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final land = _laender[_aktuellerIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAE5),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_aktuellerIndex + 1} / ${_laender.length}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A)),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 1,
                  height: 16,
                  color: const Color(0xFFD0CEC8),
                ),
                Text(
                  '${_gesamtPunkte()} pts',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAE5),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CountryFlag.fromCountryCode(
                      land.iso2,
                      width: 64,
                      height: 42,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                land.name,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Wähle die beste Kategorie:',
            style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }

  Widget _buildKategorieButtons() {
    return Column(
      children: [
        ..._tagesKats.map((kat) {
          final zuordnung = _zuordnungen[kat.id];
          final zugeordnet = zuordnung != null;
          return _KatButton(
            emoji: kat.emoji,
            label: kat.label,
            zugeordnet: zugeordnet,
            flagIso2: zugeordnet ? zuordnung.land.iso2 : null,
            rang: zugeordnet ? zuordnung.rang : null,
            onTap: zugeordnet ? null : () => _tippKategorie(kat.id),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Auflösung ─────────────────────────────────────────────────────────────────

  Widget _buildFlaggeUndRang(_Zuordnung? z, {bool versteckeHundertPlus = false}) {
    if (z == null) {
      return const Text('—',
          style: TextStyle(fontSize: 13, color: Color(0xFF888888)));
    }
    final zeigeRang = !(versteckeHundertPlus && z.rang >= 100);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: CountryFlag.fromCountryCode(
            z.land.iso2,
            width: 32,
            height: 22,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                z.land.name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  if (zeigeRang) ...[
                    Text(_formatRang(z.rang),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF888888))),
                    const Text(' · ',
                        style: TextStyle(color: Color(0xFFD0CEC8))),
                  ],
                  Text(
                    '+${z.punkte}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: z.punkte > 50
                          ? const Color(0xFF4A9E4A)
                          : const Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAufloesung() {
    final gesamtPunkte = _gesamtPunkte();

    final idealRaw = _berechneIdealeKonstellation(); // iso2 → katId
    final idealProKat = <String, _Zuordnung>{}; // katId → Zuordnung
    for (final e in idealRaw.entries) {
      final land = _laender.firstWhere((l) => l.iso2 == e.key);
      final kat = _tagesKats.firstWhere((k) => k.id == e.value);
      final rang = _weltrang(land, kat);
      idealProKat[e.value] =
          _Zuordnung(land: land, rang: rang, punkte: _berechnePunkte(rang));
    }
    final maxPunkte =
        idealProKat.values.fold(0, (sum, z) => sum + z.punkte);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ergebnis',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Text('$gesamtPunkte / $maxPunkte',
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4A9E4A))),
                const Text('Punkte',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF888888))),
                const SizedBox(height: 4),
                if (_neuerRekord)
                  const Text('Neuer Rekord!',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF9A825)))
                else if (_rekord != null)
                  Text('Rekord: $_rekord Pkt.',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF888888))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Color(0xFFD0CEC8)),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                children: [
                  ..._tagesKats.map((kat) {
                    final spieler = _zuordnungen[kat.id];
                    final ideal = idealProKat[kat.id];
                    final korrekt = spieler != null &&
                        ideal != null &&
                        spieler.land.iso2 == ideal.land.iso2;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: korrekt
                                ? const Color(0xFF4A9E4A)
                                : const Color(0xFFEAEAE5),
                            width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF1A1A1A),
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(kat.emoji,
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(kat.label,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A1A))),
                              ),
                              if (korrekt)
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF4A9E4A), size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: Color(0xFFEAEAE5), height: 1),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Deine Wahl',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF888888),
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    _buildFlaggeUndRang(spieler),
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                width: 1,
                                height: 50,
                                color: const Color(0xFFEAEAE5),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Ideal',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF888888),
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    if (korrekt)
                                      const Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded,
                                              color: Color(0xFF4A9E4A),
                                              size: 16),
                                          SizedBox(width: 6),
                                          Text('Korrekt!',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF4A9E4A))),
                                        ],
                                      )
                                    else
                                      _buildFlaggeUndRang(ideal,
                                          versteckeHundertPlus: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Center(
              child: Text('Morgen wieder verfügbar',
                  style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
            ),
          ),
        ],
      ),
    );
  }
}
