import 'dart:math';
import 'package:flutter/material.dart';
import '../data/countries.dart';
import '../l10n/uebersetzungen.dart';
import '../services/locale_service.dart';
import '../services/stats_service.dart';

class GdpQuizScreen extends StatefulWidget {
  final int questionCount;
  final bool isDaily;
  final String? continent;
  const GdpQuizScreen({super.key, this.questionCount = 10, this.isDaily = false, this.continent});

  @override
  State<GdpQuizScreen> createState() => _GdpQuizScreenState();
}

class _GdpQuizScreenState extends State<GdpQuizScreen> {
  static const _optionsCount = 4;
  int _totalQuestions = 0;

  late List<Country> _questions;
  late List<List<int>> _options;
  int _current = 0;
  int? _selected;
  int _score = 0;
  bool _finished = false;
  Map<String, bool> _countryAnswers = {};

  @override
  void initState() {
    super.initState();
    _startQuiz();
  }

  void _startQuiz() {
    final rng = Random();
    final pool = countries
        .where((c) => c.gdp > 0 &&
            (widget.continent == null || c.region == widget.continent))
        .toList()
      ..shuffle(rng);
    _questions = pool.take(widget.questionCount).toList();
    _options = _questions.map((q) {
      final wrongs = (countries
              .where((c) => c.gdp > 0 && c.gdp != q.gdp)
              .toList()
            ..shuffle(rng))
          .take(_optionsCount - 1)
          .map((c) => c.gdp)
          .toList();
      return ([q.gdp, ...wrongs]..shuffle(rng));
    }).toList();
    setState(() {
      _totalQuestions = _questions.length;
      _current = 0;
      _selected = null;
      _score = 0;
      _finished = false;
      _countryAnswers = {};
    });
  }

  String _formatGdp(int gdp) {
    final en = LocaleService.istEnglisch;
    if (gdp >= 1000000000000) {
      final v = gdp / 1000000000000;
      final s = v.toStringAsFixed(2);
      return '${en ? s : s.replaceAll('.', ',')} ${en ? 'T' : 'Bio.'} \$';
    }
    final v = gdp / 1000000000;
    return '${v.toStringAsFixed(0)} ${en ? 'B' : 'Mrd.'} \$';
  }

  void _answer(int gdp) {
    if (_selected != null) return;
    final correct = gdp == _questions[_current].gdp;
    _countryAnswers[_questions[_current].iso2] = correct;
    setState(() {
      _selected = gdp;
      if (correct) _score++;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_current + 1 >= _totalQuestions) {
        StatsService.saveResult(category: 'economy', isDaily: widget.isDaily, score: _score, total: _totalQuestions);
        if (!widget.isDaily) {
          StatsService.saveCountryAnswers(category: 'economy', answers: Map.of(_countryAnswers));
          StatsService.saveLernenDoneToday('economy');
        }
        setState(() => _finished = true);
      } else {
        setState(() {
          _current++;
          _selected = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t('BIP-Quiz'),
            style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _finished ? _buildResult() : _buildQuestion(),
    );
  }

  Widget _buildQuestion() {
    final country = _questions[_current];
    final opts = _options[_current];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          children: [
            _totalQuestions <= 25
                ? Row(
                    children: List.generate(_totalQuestions, (i) {
                      final c = i < _current
                          ? const Color(0xFF2E7D32)
                          : i == _current
                              ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
                              : const Color(0xFFD0D0CB);
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 5,
                          decoration: BoxDecoration(
                              color: c, borderRadius: BorderRadius.circular(3)),
                        ),
                      );
                    }),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _totalQuestions > 0 ? _current / _totalQuestions : 0,
                      backgroundColor: const Color(0xFFD0D0CB),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
                      minHeight: 5,
                    ),
                  ),
            const SizedBox(height: 6),
            Text(t('Frage {n} von {total}', {'n': '${_current + 1}', 'total': '$_totalQuestions'}),
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(24)),
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                children: [
                  Text(country.flagEmoji,
                      style: const TextStyle(fontSize: 60)),
                  const SizedBox(height: 12),
                  Text(t('Wie hoch ist das BIP von'),
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(country.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('(${country.region})',
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...opts.map((gdp) => _GdpOptionButton(
                  label: _formatGdp(gdp),
                  correct: _questions[_current].gdp,
                  value: gdp,
                  selected: _selected,
                  onTap: () => _answer(gdp),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final pct = (_score / _totalQuestions * 100).round();
    final emoji = pct >= 80 ? '🏆' : pct >= 50 ? '👍' : '📚';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Text(emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            Text(t('{score} / {total} richtig', {'score': '$_score', 'total': '$_totalQuestions'}),
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              pct >= 80
                  ? t('Wirtschafts-Experte!')
                  : pct >= 50
                      ? t('Gut gemacht!')
                      : t('Weiter üben!'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF888888), fontSize: 15),
            ),
            const SizedBox(height: 40),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F5E9),
                border: Border.all(
                  color: pct >= 80
                      ? const Color(0xFF2E7D32)
                      : pct >= 50
                          ? const Color(0xFFF9A825)
                          : const Color(0xFFE57373),
                  width: 6,
                ),
              ),
              child: Center(
                child: Text('$pct%',
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 32,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const Spacer(),
            if (!widget.isDaily)
              GestureDetector(
                onTap: _startQuiz,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(t('Nochmal spielen'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            if (!widget.isDaily) const SizedBox(height: 12),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _GdpOptionButton extends StatelessWidget {
  final String label;
  final int correct, value;
  final int? selected;
  final VoidCallback onTap;

  const _GdpOptionButton({
    required this.label,
    required this.correct,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFEAEAE5);
    Color text = const Color(0xFF1A1A1A);
    Widget? trailing;

    if (selected != null) {
      if (value == correct) {
        bg = const Color(0xFFE8F5E9);
        text = const Color(0xFF2E7D32);
        trailing = const Icon(Icons.check_circle_rounded,
            color: Color(0xFF4A9E4A), size: 20);
      } else if (value == selected) {
        bg = const Color(0xFFFFEBEE);
        text = const Color(0xFFC62828);
        trailing = const Icon(Icons.cancel_rounded,
            color: Color(0xFFE57373), size: 20);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected != null && value == correct
                ? const Color(0xFF4A9E4A)
                : selected != null && value == selected
                    ? const Color(0xFFE57373)
                    : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
