import 'dart:math';
import 'package:flutter/material.dart';
import '../data/country_rankings.dart';
import '../l10n/uebersetzungen.dart';

enum _Phase { placing, result }

class CategoryMatchScreen extends StatefulWidget {
  const CategoryMatchScreen({super.key});

  @override
  State<CategoryMatchScreen> createState() => _CategoryMatchScreenState();
}

class _CategoryMatchScreenState extends State<CategoryMatchScreen> {
  static const _groupSize = 8;

  _Phase _phase = _Phase.placing;
  int _countryIndex = 0;
  int _totalPoints = 0;
  int _maxPoints = 0;

  late List<CountryRanking> _countries;
  late List<RankingCategory> _categories;
  late Map<String, String> _playerChoice;   // categoryId → iso2
  late Map<String, String> _optimal;        // categoryId → iso2 with best world rank
  late Map<String, int> _rankCache;         // '${catId}_${iso2}' → world rank
  late Map<String, int> _earnedPoints;      // categoryId → points earned

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    final rng = Random();
    final pool = countryRankings
        .where((c) => rankingCategories.every((cat) => cat.getValue(c) != null))
        .toList()
      ..shuffle(rng);
    _countries = pool.take(_groupSize).toList();
    _categories = List.of(rankingCategories)..shuffle(rng);

    // Pre-compute world rank for each (country, category) pair
    _rankCache = {};
    for (final cat in _categories) {
      final sorted = countryRankings
          .where((c) => cat.getValue(c) != null)
          .toList()
        ..sort((a, b) => cat.getValue(b)!.compareTo(cat.getValue(a)!));
      for (final c in _countries) {
        final idx = sorted.indexWhere((x) => x.iso2 == c.iso2);
        _rankCache['${cat.id}_${c.iso2}'] = idx == -1 ? 9999 : idx + 1;
      }
    }

    // Optimal: greedy unique assignment — each country can only be "ideal" once.
    // Sort categories by their best achievable rank (most clear-cut first),
    // then greedily lock in the best available country for each.
    _optimal = {};
    _maxPoints = 0;
    final usedAsOptimal = <String>{};

    final catsSorted = List.of(_categories)
      ..sort((a, b) {
        int bA = 9999, bB = 9999;
        for (final c in _countries) {
          final rA = _wr(a, c);
          final rB = _wr(b, c);
          if (rA < bA) bA = rA;
          if (rB < bB) bB = rB;
        }
        return bA.compareTo(bB);
      });

    for (final cat in catsSorted) {
      CountryRanking? winner;
      int bestRank = 9999;
      for (final c in _countries) {
        if (usedAsOptimal.contains(c.iso2)) continue;
        final r = _wr(cat, c);
        if (r < bestRank) {
          bestRank = r;
          winner = c;
        }
      }
      if (winner != null) {
        _optimal[cat.id] = winner.iso2;
        _maxPoints += _pts(bestRank);
        usedAsOptimal.add(winner.iso2);
      }
    }

    _playerChoice = {};
    _earnedPoints = {};
    _countryIndex = 0;
    _totalPoints = 0;
  }

  int _wr(RankingCategory cat, CountryRanking c) =>
      _rankCache['${cat.id}_${c.iso2}'] ?? 9999;

  // Rank 1 → 100 pts, Rank 51 → 50 pts, Rank 101+ → 0 pts
  int _pts(int rank) => (101 - rank).clamp(0, 100);

  String _rankLabel(int rank) => rank > 100 ? '#100+' : '#$rank';

  CountryRanking get _current => _countries[_countryIndex];
  CountryRanking _byIso(String iso2) =>
      _countries.firstWhere((c) => c.iso2 == iso2);

  void _assign(String categoryId) {
    if (_playerChoice.containsKey(categoryId)) return;
    final cat = _categories.firstWhere((c) => c.id == categoryId);
    final pts = _pts(_wr(cat, _current));
    setState(() {
      _playerChoice[categoryId] = _current.iso2;
      _earnedPoints[categoryId] = pts;
      _totalPoints += pts;
      if (_countryIndex < _groupSize - 1) {
        _countryIndex++;
      } else {
        _phase = _Phase.result;
      }
    });
  }

  void _restart() {
    setState(() {
      _init();
      _phase = _Phase.placing;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: SafeArea(
        child: _phase == _Phase.placing ? _buildPlacing() : _buildResult(),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
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
        Text(t('Kategorie-Match'),
            style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 16,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }

  // ── Placing ──────────────────────────────────────────────────────────────────

  Widget _buildPlacing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),

        // Progress dots
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(children: [
            Text(t('Land {n} von {total}', {'n': '${_countryIndex + 1}', 'total': '$_groupSize'}),
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            for (int i = 0; i < _groupSize; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == _countryIndex ? 18 : 8,
                height: 8,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i < _countryIndex
                      ? const Color(0xFF4A9E4A)
                      : i == _countryIndex
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFFD0D0CB),
                ),
              ),
          ]),
        ),

        // Country card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween(
                      begin: const Offset(0.2, 0), end: Offset.zero)
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOut)),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _CountryCard(
                key: ValueKey('c$_countryIndex'), country: _current),
          ),
        ),

        // Category slots
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: _categories.length,
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final assignedIso = _playerChoice[cat.id];
              final filled = assignedIso != null;
              final assigned = filled ? _byIso(assignedIso) : null;

              return GestureDetector(
                onTap: filled ? null : () => _assign(cat.id),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: filled
                        ? const Color(0xFFE8F5E9)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: filled
                            ? const Color(0xFF4A9E4A)
                                .withValues(alpha: 0.45)
                            : const Color(0xFFE0E0E0)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.label,
                              style: TextStyle(
                                  color: filled
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFF1A1A1A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          Text(cat.unit,
                              style: TextStyle(
                                  color: filled
                                      ? const Color(0xFF66BB6A)
                                      : const Color(0xFFAAAAAA),
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                    if (filled && assigned != null)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(assigned.flagEmoji,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: Text(assigned.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _rankLabel(_wr(cat, assigned)),
                          style: const TextStyle(
                              color: Color(0xFF66BB6A),
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ]),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Result ───────────────────────────────────────────────────────────────────

  Widget _buildResult() {
    final pct = _maxPoints > 0 ? _totalPoints / _maxPoints : 0.0;
    final emoji = pct >= 0.8 ? '🏆' : pct >= 0.5 ? '👍' : '📚';

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(children: [
              // Score summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$_totalPoints',
                          style: const TextStyle(
                              color: Color(0xFFF9A825),
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              height: 1.0)),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 6),
                        child: Text(t('/ {n} Pkt möglich', {'n': '$_maxPoints'}),
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Result rows
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  children: [
                    for (int i = 0; i < _categories.length; i++) ...[
                      _buildResultRow(_categories[i]),
                      if (i < _categories.length - 1)
                        const Divider(height: 12, thickness: 0.5),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: _restart,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: const Color(0xFF4A9E4A),
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Text(t('Nochmal spielen'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAEAE5),
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Text(t('Zurück'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(RankingCategory cat) {
    final playerIso = _playerChoice[cat.id]!;
    final optIso = _optimal[cat.id]!;
    final correct = playerIso == optIso;
    final playerC = _byIso(playerIso);
    final optC = _byIso(optIso);
    final playerRank = _wr(cat, playerC);
    final optRank = _wr(cat, optC);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: correct
                  ? const Color(0xFF4A9E4A)
                  : const Color(0xFFE57373),
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.label,
                    style: const TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                if (correct)
                  _rankLine(playerC, playerRank, const Color(0xFF1A1A1A))
                else ...[
                  _rankLine(playerC, playerRank, const Color(0xFFC62828)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(t('Ideale Wahl: '),
                        style: const TextStyle(
                            color: Color(0xFFAAAAAA),
                            fontSize: 10,
                            fontWeight: FontWeight.w500)),
                    Flexible(
                        child: _rankLine(
                            optC, optRank, const Color(0xFF2E7D32))),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankLine(CountryRanking c, int rank, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(c.flagEmoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 3),
        Flexible(
          child: Text(c.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 5),
        Text(_rankLabel(rank),
            style: TextStyle(
                color: color.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Country card ──────────────────────────────────────────────────────────────

class _CountryCard extends StatelessWidget {
  final CountryRanking country;
  const _CountryCard({super.key, required this.country});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Text(country.flagEmoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 14),
        Text(country.name,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
