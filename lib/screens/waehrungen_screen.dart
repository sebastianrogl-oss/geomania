import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/currencies.dart';

// ── Phase ─────────────────────────────────────────────────────────────────────

enum _Phase { difficulty, quiz, result }

// ── Question model ────────────────────────────────────────────────────────────

class _Question {
  final CurrencyData correct;
  final List<String> options; // 4 currency names (shuffled)
  _Question({required this.correct, required this.options});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WaehrungenScreen extends StatefulWidget {
  const WaehrungenScreen({super.key});

  @override
  State<WaehrungenScreen> createState() => _WaehrungenScreenState();
}

class _WaehrungenScreenState extends State<WaehrungenScreen> {
  static const _kCount = 10;

  _Phase _phase = _Phase.difficulty;
  int _difficulty = 1;

  late List<_Question> _questions;
  int _qIndex = 0;
  int _score = 0;
  String? _picked;      // the option the user tapped
  bool _answered = false;
  Timer? _advanceTimer;

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  // ── Quiz generation ──────────────────────────────────────────────────────────

  void _startQuiz(int difficulty) {
    _difficulty = difficulty;
    final rng = Random();

    // Pool: for difficulty 1 → only d1; 2 → d1+d2; 3 → all
    final pool = currencies
        .where((c) => c.difficulty <= difficulty)
        .toList()
      ..shuffle(rng);
    final picked = pool.take(_kCount).toList();

    // All currency names (for distractors)
    final allNames = currencies.map((c) => c.currencyName).toSet().toList();

    final qs = picked.map((c) {
      final wrong = allNames
          .where((n) => n != c.currencyName)
          .toList()
        ..shuffle(rng);
      final options = [c.currencyName, ...wrong.take(3)]..shuffle(rng);
      return _Question(correct: c, options: options);
    }).toList();

    setState(() {
      _questions = qs;
      _qIndex = 0;
      _score = 0;
      _picked = null;
      _answered = false;
      _phase = _Phase.quiz;
    });
  }

  // ── Answer handling ──────────────────────────────────────────────────────────

  void _pick(String option) {
    if (_answered) return;
    final isCorrect = option == _questions[_qIndex].correct.currencyName;
    setState(() {
      _picked = option;
      _answered = true;
      if (isCorrect) _score++;
    });
    _advanceTimer = Timer(const Duration(milliseconds: 1100), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_qIndex + 1 >= _kCount) {
      setState(() => _phase = _Phase.result);
    } else {
      setState(() {
        _qIndex++;
        _picked = null;
        _answered = false;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: switch (_phase) {
        _Phase.difficulty => _buildDifficulty(),
        _Phase.quiz       => _buildQuiz(),
        _Phase.result     => _buildResult(),
      },
    );
  }

  // ── Difficulty picker ────────────────────────────────────────────────────────

  Widget _buildDifficulty() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAE5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF1A1A1A), size: 18),
              ),
            ),
            const SizedBox(height: 32),
            const Text('💱', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('Währungen-Quiz',
                style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 28,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Welche Währung hat dieses Land?',
                style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 40),
            const Text('SCHWIERIGKEITSGRAD',
                style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _DiffOption(
              emoji: '🟢',
              label: 'Leicht',
              sub: 'EUR, USD, GBP, JPY & Co.',
              onTap: () => _startQuiz(1),
            ),
            const SizedBox(height: 10),
            _DiffOption(
              emoji: '🟡',
              label: 'Mittel',
              sub: 'Krone, Forint, Won & mehr',
              onTap: () => _startQuiz(2),
            ),
            const SizedBox(height: 10),
            _DiffOption(
              emoji: '🔴',
              label: 'Schwer',
              sub: 'Kyat, Kip, Tögrög & exotische Währungen',
              onTap: () => _startQuiz(3),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quiz ─────────────────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    final q = _questions[_qIndex];
    final correct = q.correct;
    final hasFact = correct.funFact.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => setState(() => _phase = _Phase.difficulty),
        ),
        title: Text(
          _diffLabel(_difficulty),
          style: const TextStyle(
              color: Color(0xFF1A1A1A), fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$_score/$_kCount',
                  style: const TextStyle(
                      color: Color(0xFF4A9E4A),
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            children: [
              // Progress dots
              Row(
                children: List.generate(_kCount, (i) {
                  Color c;
                  if (i < _qIndex) {
                    c = const Color(0xFF4A9E4A);
                  } else if (i == _qIndex) {
                    c = const Color(0xFF4A9E4A).withValues(alpha: 0.35);
                  } else {
                    c = const Color(0xFFD0D0CB);
                  }
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 5,
                      decoration: BoxDecoration(
                          color: c, borderRadius: BorderRadius.circular(3)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text('Frage ${_qIndex + 1} von $_kCount',
                  style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),

              // Country display
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(correct.flagEmoji,
                        style: const TextStyle(fontSize: 72)),
                    const SizedBox(height: 12),
                    Text(correct.countryName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('Welche Währung hat dieses Land?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

              // Fun fact (after answer)
              AnimatedOpacity(
                opacity: (_answered && hasFact) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡 ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(correct.funFact,
                            style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ),

              // Options
              ...q.options.map((opt) {
                Color bg = const Color(0xFFEAEAE5);
                Color textColor = const Color(0xFF1A1A1A);
                Widget? trailing;

                if (_answered) {
                  if (opt == correct.currencyName) {
                    bg = const Color(0xFFE8F5E9);
                    textColor = const Color(0xFF2E7D32);
                    trailing = const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF4A9E4A), size: 20);
                  } else if (opt == _picked) {
                    bg = const Color(0xFFFFEBEE);
                    textColor = const Color(0xFFB71C1C);
                    trailing = const Icon(Icons.cancel_rounded,
                        color: Color(0xFFE53935), size: 20);
                  }
                }

                return GestureDetector(
                  onTap: () => _pick(opt),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                        color: bg, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(opt,
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (trailing != null) trailing,
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Result ───────────────────────────────────────────────────────────────────

  Widget _buildResult() {
    final pct = (_score / _kCount * 100).round();
    final emoji = pct >= 80 ? '🏆' : pct >= 50 ? '👍' : '📚';
    final grade = pct >= 80 ? 'Ausgezeichnet!' : pct >= 50 ? 'Gut gemacht!' : 'Weiter üben!';
    final ringColor = pct >= 80
        ? const Color(0xFF4A9E4A)
        : pct >= 50
            ? const Color(0xFFF9A825)
            : const Color(0xFFE53935);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Text(emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text(grade,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('$_score / $_kCount richtig',
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEAEAE5),
                border: Border.all(color: ringColor, width: 6),
              ),
              child: Center(
                child: Text('$pct %',
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 30,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _startQuiz(_difficulty),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFF4A9E4A),
                    borderRadius: BorderRadius.circular(16)),
                child: const Text('Nochmal spielen',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _phase = _Phase.difficulty),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAEAE5),
                    borderRadius: BorderRadius.circular(16)),
                child: const Text('Schwierigkeit ändern',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAEAE5),
                    borderRadius: BorderRadius.circular(16)),
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

  String _diffLabel(int d) {
    switch (d) {
      case 1: return '🟢 Leicht';
      case 2: return '🟡 Mittel';
      default: return '🔴 Schwer';
    }
  }
}

// ── Difficulty option ─────────────────────────────────────────────────────────

class _DiffOption extends StatelessWidget {
  final String emoji, label, sub;
  final VoidCallback onTap;

  const _DiffOption({
    required this.emoji,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEAE5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFBBBBBB), size: 20),
          ],
        ),
      ),
    );
  }
}
