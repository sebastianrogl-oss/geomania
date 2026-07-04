import 'dart:math';
import 'package:flutter/material.dart';
import '../data/countries.dart';
import '../services/stats_service.dart';

class QuizScreen extends StatefulWidget {
  final int questionCount;
  final bool isDaily;
  final String? continent;
  const QuizScreen({super.key, this.questionCount = 10, this.isDaily = false, this.continent});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  static const _optionsCount = 4;

  late List<Country> _questions;
  late List<List<String>> _options;
  int _totalQ = 0;
  int _current = 0;
  String? _selected;
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
    final src = widget.continent == null
        ? countries
        : countries.where((c) => c.region == widget.continent).toList();
    final pool = List<Country>.from(src)..shuffle(rng);
    _questions = pool.take(widget.questionCount).toList();
    _options = _questions.map((q) {
      final wrongs = (List<Country>.from(countries)
            ..removeWhere((c) => c.capital == q.capital)
            ..shuffle(rng))
          .take(_optionsCount - 1)
          .map((c) => c.capital)
          .toList();
      return ([q.capital, ...wrongs]..shuffle(rng));
    }).toList();

    setState(() {
      _totalQ = _questions.length;
      _current = 0;
      _selected = null;
      _score = 0;
      _finished = false;
      _countryAnswers = {};
    });
  }

  void _answer(String choice) {
    if (_selected != null) return;
    final correct = choice == _questions[_current].capital;
    _countryAnswers[_questions[_current].iso2] = correct;
    setState(() {
      _selected = choice;
      if (correct) _score++;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_current + 1 >= _totalQ) {
        StatsService.saveResult(category: 'capitals', isDaily: widget.isDaily, score: _score, total: _totalQ);
        if (!widget.isDaily) {
          StatsService.saveCountryAnswers(category: 'capitals', answers: Map.of(_countryAnswers));
          StatsService.saveLernenDoneToday('capitals');
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
        title: const Text('Hauptstädte-Quiz',
            style: TextStyle(
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
            // Fortschrittsbalken
            _totalQ <= 25
                ? Row(
                    children: List.generate(_totalQ, (i) {
                      final color = i < _current
                          ? const Color(0xFF4A9E4A)
                          : i == _current
                              ? const Color(0xFF4A9E4A).withValues(alpha: 0.4)
                              : const Color(0xFFD0D0CB);
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 5,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3)),
                        ),
                      );
                    }),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _totalQ > 0 ? _current / _totalQ : 0,
                      backgroundColor: const Color(0xFFD0D0CB),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF4A9E4A)),
                      minHeight: 5,
                    ),
                  ),
            const SizedBox(height: 6),
            Text('Frage ${_current + 1} von $_totalQ',
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),

            // Länderkarte
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAE5),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Column(
                children: [
                  Text(country.flagEmoji,
                      style: const TextStyle(fontSize: 60)),
                  const SizedBox(height: 12),
                  const Text('Was ist die Hauptstadt von',
                      style: TextStyle(
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Antwort-Buttons
            ...opts.map((opt) => _OptionButton(
                  label: opt,
                  correct: _questions[_current].capital,
                  selected: _selected,
                  onTap: () => _answer(opt),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final percentage = (_score / _totalQ * 100).round();
    final emoji = percentage >= 80
        ? '🏆'
        : percentage >= 50
            ? '👍'
            : '📚';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Text(emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            Text('$_score / $_totalQ richtig',
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              percentage >= 80
                  ? 'Ausgezeichnet! Du bist ein Geo-Profi!'
                  : percentage >= 50
                      ? 'Gut gemacht! Weiter üben!'
                      : 'Nicht schlecht – nochmal versuchen!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 40),
            // Score-Ring
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEAEAE5),
                border: Border.all(
                  color: percentage >= 80
                      ? const Color(0xFF4A9E4A)
                      : percentage >= 50
                          ? const Color(0xFFF9A825)
                          : const Color(0xFFE57373),
                  width: 6,
                ),
              ),
              child: Center(
                child: Text('$percentage%',
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
                    color: const Color(0xFF4A9E4A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: const Text('Nochmal spielen',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Text('Zurück',
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

class _OptionButton extends StatelessWidget {
  final String label, correct;
  final String? selected;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.correct,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFEAEAE5);
    Color text = const Color(0xFF1A1A1A);
    Widget? trailing;

    if (selected != null) {
      if (label == correct) {
        bg = const Color(0xFFE8F5E9);
        text = const Color(0xFF2E7D32);
        trailing = const Icon(Icons.check_circle_rounded,
            color: Color(0xFF4A9E4A), size: 20);
      } else if (label == selected) {
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
            color: selected != null && label == correct
                ? const Color(0xFF4A9E4A)
                : selected != null && label == selected
                    ? const Color(0xFFE57373)
                    : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
