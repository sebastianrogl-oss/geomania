import 'dart:math';
import 'package:flutter/material.dart';
import '../data/country_rankings.dart';
import '../l10n/uebersetzungen.dart';
import '../services/locale_service.dart';
import '../theme/app_theme.dart';

class RankingQuizScreen extends StatefulWidget {
  const RankingQuizScreen({super.key});

  @override
  State<RankingQuizScreen> createState() => _RankingQuizScreenState();
}

class _RankingQuizScreenState extends State<RankingQuizScreen> {
  static const _countryCount = 4;

  late RankingCategory _category;
  late List<CountryRanking> _correct;
  late List<CountryRanking> _shuffled;
  bool _submitted = false;
  int _score = 0;
  int _round = 0;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    final rng = Random();
    _category = rankingCategories[rng.nextInt(rankingCategories.length)];
    final pool = countryRankings
        .where((c) => _category.getValue(c) != null)
        .toList()
      ..shuffle(rng);
    final picked = pool.take(_countryCount).toList();
    _correct = List.of(picked)
      ..sort((a, b) {
        final av = _category.getValue(a)!;
        final bv = _category.getValue(b)!;
        return _category.higherIsBetter ? bv.compareTo(av) : av.compareTo(bv);
      });
    _shuffled = List.of(picked)..shuffle(rng);
    int tries = 0;
    while (_listsEqual(_shuffled, _correct) && tries < 20) {
      _shuffled.shuffle(rng);
      tries++;
    }
    setState(() {
      _submitted = false;
      _score = 0;
      _round++;
    });
  }

  bool _listsEqual(List<CountryRanking> a, List<CountryRanking> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i].iso2 != b[i].iso2) return false;
    }
    return true;
  }

  void _submit() {
    int s = 0;
    for (int i = 0; i < _shuffled.length; i++) {
      if (_shuffled[i].iso2 == _correct[i].iso2) s++;
    }
    setState(() {
      _submitted = true;
      _score = s;
    });
  }

  String _fmtValue(double v) {
    final cat = _category.id;
    final en = LocaleService.istEnglisch;
    String dec(double x, int decimals) {
      final s = x.toStringAsFixed(decimals);
      return en ? s : s.replaceAll('.', ',');
    }
    String thousands(int n) {
      final sep = en ? ',' : '.';
      final s = n.toString();
      final buf = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(sep);
        buf.write(s[i]);
      }
      return buf.toString();
    }
    if (cat == 'population') {
      if (v >= 1e9) return '${dec(v / 1e9, 2)} ${en ? 'B' : 'Mrd.'}';
      if (v >= 1e6) return '${dec(v / 1e6, 1)} ${en ? 'M' : 'Mio.'}';
      return '${v.toInt()}';
    }
    if (cat == 'area') {
      if (v >= 1e6) {
        return '${dec(v / 1e6, 2)} ${en ? 'M' : 'Mio.'} km²';
      }
      return '${thousands(v.toInt())} km²';
    }
    if (cat == 'gdpPerCapita') {
      return '\$${thousands(v.toInt())}';
    }
    if (cat == 'lifeExpectancy') return '${dec(v, 1)} ${en ? 'yrs' : 'J.'}';
    if (cat == 'co2') return '${dec(v, 1)} t';
    if (cat == 'coastline') {
      if (v >= 10000) return '${dec(v / 1000, 0)} Tkm';
      return '${thousands(v.toInt())} km';
    }
    if (cat == 'minimumWage') return '\$${v.toInt()}';
    if (cat == 'bigMac') return '\$${v.toStringAsFixed(2)}';
    return v.toString();
  }

  static const _catEmojis = {
    'population':     '👥',
    'area':           '🗺️',
    'gdpPerCapita':   '💰',
    'lifeExpectancy': '❤️',
    'co2':            '🏭',
    'coastline':      '🌊',
    'minimumWage':    '💵',
    'bigMac':         '🍔',
  };

  String get _catEmoji => _catEmojis[_category.id] ?? '📊';

  String get _directionLabel =>
      _category.higherIsBetter ? t('↑ Höchste zuerst') : t('↓ Niedrigste zuerst');

  int _worldRank(CountryRanking c) {
    final sorted = countryRankings
        .where((x) => _category.getValue(x) != null)
        .toList()
      ..sort((a, b) {
        final av = _category.getValue(a)!;
        final bv = _category.getValue(b)!;
        return _category.higherIsBetter ? bv.compareTo(av) : av.compareTo(bv);
      });
    final idx = sorted.indexWhere((x) => x.iso2 == c.iso2);
    return idx == -1 ? 9999 : idx + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHintergrund,
      appBar: AppBar(
        backgroundColor: kHintergrund,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t('Ranking-Quiz'),
            style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _submitted ? _buildResult() : _buildQuiz(),
    );
  }

  Widget _buildQuiz() {
    return SafeArea(
      child: Column(
        children: [
          // Category header
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  '$_catEmoji  ${_category.label}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_directionLabel,
                      style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Text(
                  t('Ziehe die Länder in die richtige Reihenfolge'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Position labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Text(t('Platz'),
                    style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  _category.higherIsBetter ? t('← größer') : t('← kleiner'),
                  style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Reorderable list
          Expanded(
            child: ReorderableListView(
              key: ValueKey(_round),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) => Material(
                color: Colors.transparent,
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                child: child,
              ),
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _shuffled.removeAt(oldIndex);
                  _shuffled.insert(newIndex, item);
                });
              },
              children: [
                for (int i = 0; i < _shuffled.length; i++)
                  ReorderableDragStartListener(
                    key: ValueKey(_shuffled[i].iso2),
                    index: i,
                    child: _RankCard(
                      key: ValueKey('card_${_shuffled[i].iso2}'),
                      rank: i + 1,
                      country: _shuffled[i],
                    ),
                  ),
              ],
            ),
          ),
          // Submit button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: GestureDetector(
              onTap: _submit,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(t('Auswerten'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final perfect = _score == _countryCount;
    final emoji = perfect ? '🏆' : _score >= 2 ? '👍' : '📚';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              perfect ? t('Perfekt!') : _score >= 2 ? t('Gut gemacht!') : t('Weiter üben!'),
              style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 24,
                  fontWeight: FontWeight.w800),
            ),
            Text(t('{n} von {total} Plätze korrekt', {'n': '$_score', 'total': '$_countryCount'}),
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            // Correct order with values
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_catEmoji  ${_category.label}',
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (int i = 0; i < _correct.length; i++) ...[
                    _ResultRow(
                      rank: i + 1,
                      country: _correct[i],
                      value: _fmtValue(_category.getValue(_correct[i])!),
                      worldRank: _worldRank(_correct[i]),
                      correct: _shuffled[i].iso2 == _correct[i].iso2,
                    ),
                    if (i < _correct.length - 1) const Divider(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _newRound,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(t('Nächste Runde'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
                child: Text(t('Zurück'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Drag card ────────────────────────────────────────────────────────────────

class _RankCard extends StatelessWidget {
  final int rank;
  final CountryRanking country;

  const _RankCard({super.key, required this.rank, required this.country});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAE5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('$rank',
                style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        title: Row(
          children: [
            Text(country.flagEmoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(country.name,
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        trailing: const Icon(Icons.drag_handle_rounded,
            color: Color(0xFFCCCCCC), size: 22),
      ),
    );
  }
}

// ─── Result row ───────────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  final int rank;
  final CountryRanking country;
  final String value;
  final int worldRank;
  final bool correct;

  const _ResultRow({
    required this.rank,
    required this.country,
    required this.value,
    required this.worldRank,
    required this.correct,
  });

  String get _fmtWorldRank => worldRank > 100 ? '#100+' : '#$worldRank';

  @override
  Widget build(BuildContext context) {
    final accent =
        correct ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final accentLight =
        correct ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: accentLight,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text('$rank',
                style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Text(country.flagEmoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(country.name,
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              Text(value,
                  style: TextStyle(
                      color: correct
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF888888),
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accentLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_fmtWorldRank,
              style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 6),
        Icon(
          correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: correct
              ? const Color(0xFF4A9E4A)
              : const Color(0xFFE57373),
          size: 18,
        ),
      ],
    );
  }
}
