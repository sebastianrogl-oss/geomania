import 'dart:math';
import 'package:flutter/material.dart';
import '../data/country_rankings.dart';
import '../services/challenge_rekord_service.dart';
import '../services/tages_seed_service.dart';
import '../services/rangliste_service.dart';

class HigherLowerScreen extends StatefulWidget {
  const HigherLowerScreen({super.key});

  @override
  State<HigherLowerScreen> createState() => _HigherLowerScreenState();
}

class _HigherLowerScreenState extends State<HigherLowerScreen> {
  static const _kId = 'higher_lower';

  late RankingCategory _category;
  late CountryRanking _leftCountry;
  late CountryRanking _rightCountry;

  // Deterministische Länderkette für die heutige Challenge: gleiche
  // Kategorie und gleiche Reihenfolge für alle Spieler an diesem Tag.
  List<CountryRanking> _seedLaender = [];
  int _naechsterSeedIdx = 0;

  int _score = 0;
  int _totalPunkte = 0;
  bool _answered = false;
  bool? _lastCorrect;
  bool _gameOver = false;

  int? _rekord;

  @override
  void initState() {
    super.initState();
    _ladeUndStarte();
  }

  Future<void> _ladeUndStarte() async {
    _rekord = await ChallengeRekordService.getRekord(_kId);
    // Tägliche Kategorie: einmal pro Tag fest, anderen Seed als Preis-Schätzen
    final katRng = Random(TagesSeedService.seedFuer(_kId) + 555);
    _category = rankingCategories[katRng.nextInt(rankingCategories.length)];
    _generiereSeedLaender();
    _startGame();
  }

  void _generiereSeedLaender() {
    final rng = Random(TagesSeedService.seedFuer(_kId));
    _seedLaender = countryRankings
        .where((c) => _category.getValue(c) != null)
        .toList()
      ..shuffle(rng);
  }

  void _startGame() {
    _naechsterSeedIdx = 2;
    setState(() {
      _score = 0;
      _totalPunkte = 0;
      _answered = false;
      _lastCorrect = null;
      _gameOver = false;
      _leftCountry = _seedLaender[0];
      _rightCountry = _seedLaender[1];
    });
  }

  // Nächstes Land der Tageskette; fällt erst zurück auf Zufall, wenn die
  // Kette erschöpft ist (Kategorie bleibt dabei immer gleich).
  CountryRanking _naechstesLand() {
    if (_naechsterSeedIdx < _seedLaender.length) {
      return _seedLaender[_naechsterSeedIdx++];
    }
    final rng = Random();
    final pool = countryRankings
        .where((c) =>
            _category.getValue(c) != null && c.iso2 != _rightCountry.iso2)
        .toList()
      ..shuffle(rng);
    return pool.first;
  }

  double get _multiplikator {
    if (_score >= 20) return 3.0;
    if (_score >= 10) return 2.0;
    if (_score >= 5) return 1.5;
    return 1.0;
  }

  int get _punkteProRichtig => (100 * _multiplikator).round();

  String get _multiplikatorLabel {
    final m = _multiplikator;
    if (m > 1) return '×${m.toStringAsFixed(1).replaceAll('.', ',')} Bonus!';
    return '';
  }

  void _advanceRound() {
    final neuesLand = _naechstesLand();
    setState(() {
      _leftCountry = _rightCountry;
      _rightCountry = neuesLand;
    });
  }

  void _guess(bool guessHigher) {
    if (_answered || _gameOver) return;

    final leftVal = _category.getValue(_leftCountry)!;
    final rightVal = _category.getValue(_rightCountry)!;
    final bool correct = leftVal == rightVal ||
        (guessHigher ? rightVal > leftVal : rightVal < leftVal);

    setState(() {
      _answered = true;
      _lastCorrect = correct;
    });

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      if (correct) {
        _advanceRound();
        setState(() {
          _score++;
          _totalPunkte += _punkteProRichtig;
          _answered = false;
          _lastCorrect = null;
        });
      } else {
        _speichereErgebnis();
        setState(() => _gameOver = true);
      }
    });
  }

  Future<void> _speichereErgebnis() async {
    await ChallengeRekordService.setzeFallsBesser(_kId, _totalPunkte);
    await ChallengeRekordService.speichereHeutigePunkte(_kId, _totalPunkte);
    _rekord = await ChallengeRekordService.getRekord(_kId);
    await RanglisteService.ergebnisSpeichern(
        challengeId: 'higherlower', wert: _totalPunkte);
  }

  String _fmt(double v) {
    switch (_category.id) {
      case 'population':
        if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2).replaceAll('.', ',')} Mrd.';
        if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1).replaceAll('.', ',')} Mio.';
        return _fmtInt(v.toInt());
      case 'area':
        if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2).replaceAll('.', ',')} Mio. km²';
        return '${_fmtInt(v.toInt())} km²';
      case 'gdpPerCapita':    return '\$ ${_fmtInt(v.toInt())}';
      case 'gdpTotal':
        if (v >= 1e12) return '\$ ${(v / 1e12).toStringAsFixed(1).replaceAll('.', ',')} Bio.';
        if (v >= 1e9) return '\$ ${(v / 1e9).toStringAsFixed(0)} Mrd.';
        return '\$ ${(v / 1e6).toStringAsFixed(0)} Mio.';
      case 'lifeExpectancy':  return '${v.toStringAsFixed(1)} Jahre';
      case 'coastline':       return '${_fmtInt(v.toInt())} km';
      case 'minimumWage':     return '\$ ${_fmtInt(v.toInt())}/Mo.';
      case 'internet':        return '${v.round()} Mbps';
      case 'corruption':      return '${v.round()} / 100';
      case 'press_freedom':   return '${v.round()} / 100';
      case 'happiness':       return v.toStringAsFixed(2).replaceAll('.', ',');
      case 'tourism':         return '${v.round()} Mrd. \$';
      case 'military':        return '${v.round()} Mrd. \$';
      case 'birth_rate':      return '${v.toStringAsFixed(1).replaceAll('.', ',')} K/Frau';
      case 'forest':          return '${v.round()} %';
      case 'alcohol':         return '${v.toStringAsFixed(1).replaceAll('.', ',')} L/Kopf';
      case 'olympics':        return '${v.toInt()} Medaillen';
      case 'highest_point':   return '${_fmtInt(v.toInt())} m';
      case 'inflation':       return '${v.toStringAsFixed(1).replaceAll('.', ',')} %';
      case 'debt':            return '${v.toStringAsFixed(1).replaceAll('.', ',')} % BIP';
      default:                return '${v.toStringAsFixed(1)} ${_category.unit}';
    }
  }

  String _fmtInt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: _gameOver ? _buildGameOver() : _buildGame(),
      ),
    );
  }

  // ── Game ──────────────────────────────────────────────────────────────────

  Widget _buildGame() {
    final leftVal = _fmt(_category.getValue(_leftCountry)!);
    final rightVal = _answered ? _fmt(_category.getValue(_rightCountry)!) : null;
    final rightBg = _answered
        ? (_lastCorrect == true
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE))
        : const Color(0xFFF5F5F0);

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAEAE5),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Color(0xFF1A1A1A), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Higher or Lower',
                        style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        Text(_category.label,
                            style: const TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                        if (_multiplikatorLabel.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(_multiplikatorLabel,
                                style: const TextStyle(
                                    color: Color(0xFFE53935),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                    if (_rekord != null)
                      Text('Rekord: $_rekord Pkt.',
                          style: const TextStyle(
                              color: Color(0xFFF9A825),
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              // Score + current points
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color:
                        const Color(0xFFF9A825).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Row(children: [
                      const Text('🏆', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text('$_score',
                          style: const TextStyle(
                              color: Color(0xFFF9A825),
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ]),
                    Text('$_totalPunkte Pkt.',
                        style: const TextStyle(
                            color: Color(0xFFF9A825),
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Panels ──────────────────────────────────────────────────────────
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _answered ? null : () => _guess(false),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _RevealedPanel(
                      key: ValueKey(
                          'L_${_leftCountry.iso2}_${_category.id}_$_score'),
                      country: _leftCountry,
                      value: leftVal,
                      label: _category.label,
                      bgColor: const Color(0xFFEAEAE5),
                    ),
                  ),
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  const Divider(height: 1, thickness: 1, color: Color(0xFFD0D0CB)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('VS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2)),
                  ),
                ],
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _answered
                      ? _RevealedPanel(
                          key: ValueKey(
                              'R_rev_${_rightCountry.iso2}_${_category.id}_$_score'),
                          country: _rightCountry,
                          value: rightVal!,
                          label: _category.label,
                          bgColor: rightBg,
                          isCorrect: _lastCorrect,
                        )
                      : _HiddenPanel(
                          key: ValueKey(
                              'R_hid_${_rightCountry.iso2}_${_category.id}_$_score'),
                          country: _rightCountry,
                          label: _category.label,
                          onTap: () => _guess(true),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Game Over ─────────────────────────────────────────────────────────────

  Widget _buildGameOver() {
    final emoji = _score >= 15 ? '🏆' : _score >= 8 ? '👍' : '📚';
    final neuerRekord = _totalPunkte > 0 &&
        _totalPunkte >= (_rekord ?? 0) &&
        _totalPunkte > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          const Text('Spiel vorbei!',
              style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Kategorie: ${_category.label}',
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),

          if (_rekord != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFEAEAE5),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆 Rekord:',
                      style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text('$_rekord Punkte',
                      style: const TextStyle(
                          color: Color(0xFFF9A825),
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Score bubble
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
                color: const Color(0xFFF9A825).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFFF9A825).withValues(alpha: 0.3),
                    width: 1.5)),
            child: Column(children: [
              const Text('Richtige Antworten',
                  style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text('$_score',
                  style: const TextStyle(
                      color: Color(0xFFF9A825),
                      fontSize: 68,
                      fontWeight: FontWeight.w900,
                      height: 1.0)),
              Text('$_totalPunkte Punkte total',
                  style: const TextStyle(
                      color: Color(0xFFF9A825),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ]),
          ),

          if (neuerRekord) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('🏆 Neuer Rekord!',
                  style: TextStyle(
                      color: Color(0xFF856404),
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
          ],

          const SizedBox(height: 16),
          // Wrong answer card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.cancel_rounded,
                  color: Color(0xFFE57373), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_rightCountry.flagEmoji} ${_rightCountry.name}:  '
                  '${_fmt(_category.getValue(_rightCountry)!)}',
                  style: const TextStyle(
                      color: Color(0xFFC62828),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _startGame,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: const Color(0xFF4A9E4A),
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Text('Nochmal spielen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: const Color(0xFFEAEAE5),
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Text('Zurück',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Revealed panel ────────────────────────────────────────────────────────────

class _RevealedPanel extends StatelessWidget {
  final CountryRanking country;
  final String value;
  final String label;
  final Color bgColor;
  final bool? isCorrect;

  const _RevealedPanel({
    super.key,
    required this.country,
    required this.value,
    required this.label,
    required this.bgColor,
    this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: bgColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(country.flagEmoji, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(country.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14)),
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 21,
                    fontWeight: FontWeight.w800)),
          ),
          if (isCorrect != null) ...[
            const SizedBox(height: 10),
            Icon(
              isCorrect! ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isCorrect!
                  ? const Color(0xFF4A9E4A)
                  : const Color(0xFFE57373),
              size: 28,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Hidden panel ──────────────────────────────────────────────────────────────

class _HiddenPanel extends StatelessWidget {
  final CountryRanking country;
  final String label;
  final VoidCallback onTap;

  const _HiddenPanel({
    super.key,
    required this.country,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFF5F5F0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(country.flagEmoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(country.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xFFD0D0CB), width: 1)),
              child: const Text('?  ?  ?',
                  style: TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6)),
            ),
          ],
        ),
      ),
    );
  }
}
