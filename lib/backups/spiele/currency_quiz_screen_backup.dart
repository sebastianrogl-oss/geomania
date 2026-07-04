// BACKUP - currency_quiz_screen.dart - Stand: 2026-06-17
// Originalort: lib/screens/currency_quiz_screen.dart
// Beschreibung: Währungs-Quiz — 10 Fragen mit 10-Sekunden-Timer,
//               welche Währung hat dieses Land? Leicht/Schwer-Modus.
// Wiederherstellen: zurückkopieren nach lib/screens/currency_quiz_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/countries.dart';
import '../data/economic_blocks.dart';

enum _Difficulty { easy, hard }

class CurrencyQuizScreen extends StatefulWidget {
  const CurrencyQuizScreen({super.key});

  @override
  State<CurrencyQuizScreen> createState() => _CurrencyQuizScreenState();
}

class _CurrencyQuizScreenState extends State<CurrencyQuizScreen> {
  static const _questionsPerRound = 10;
  static const _secondsPerQ = 10;

  _Difficulty _difficulty = _Difficulty.easy;
  bool _started = false;

  late List<_Question> _questions;
  int _qIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedIdx;
  bool _done = false;

  int _timeLeft = _secondsPerQ;
  Timer? _timer;

  // ── unique currency list for distractors ───────────────────────────────────
  late List<String> _uniqueCurrencies;

  @override
  void initState() {
    super.initState();
    _uniqueCurrencies = countryCurrencies.values.toSet().toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    final rng = Random();
    final pool = countries.where((c) {
      if (!countryCurrencies.containsKey(c.iso2)) return false;
      if (_difficulty == _Difficulty.easy) return currencyEasyCountries.contains(c.iso2);
      return true;
    }).toList()..shuffle(rng);

    final picked = pool.take(_questionsPerRound).toList();
    _questions = picked.map((c) {
      final correct = countryCurrencies[c.iso2]!;
      final distractors = (_uniqueCurrencies.where((cu) => cu != correct).toList()..shuffle(rng)).take(3).toList();
      final opts = [correct, ...distractors]..shuffle(rng);
      return _Question(country: c, correct: correct, options: opts);
    }).toList();

    setState(() {
      _started = true;
      _qIndex = 0;
      _score = 0;
      _answered = false;
      _selectedIdx = null;
      _done = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = _secondsPerQ;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) _autoAdvance();
    });
  }

  void _autoAdvance() {
    if (_answered) return;
    _timer?.cancel();
    setState(() {
      _answered = true;
      _selectedIdx = null;
    });
    Future.delayed(const Duration(milliseconds: 1200), _next);
  }

  void _pick(int idx) {
    if (_answered) return;
    _timer?.cancel();
    final q = _questions[_qIndex];
    final correct = _questions[_qIndex].options[idx] == q.correct;
    setState(() {
      _answered = true;
      _selectedIdx = idx;
      if (correct) _score++;
    });
    Future.delayed(const Duration(milliseconds: 1100), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_qIndex + 1 >= _questionsPerRound) {
      setState(() => _done = true);
      return;
    }
    setState(() {
      _qIndex++;
      _answered = false;
      _selectedIdx = null;
    });
    _startTimer();
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
        title: const Text('Währungs-Quiz',
            style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: !_started
          ? _buildStart()
          : _done
              ? _buildResult()
              : _buildQuestion(),
    );
  }

  // ── Start screen ────────────────────────────────────────────────────────────
  Widget _buildStart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💱', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            const Text('Währungs-Quiz',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            const Text('Welche Währung gehört zu welchem Land?\n10 Fragen · 10 Sekunden pro Frage',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
            const SizedBox(height: 32),
            const Text('SCHWIERIGKEITSGRAD',
                style: TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _DiffBtn(label: 'Leicht', sub: 'Bekannte Länder', active: _difficulty == _Difficulty.easy,
                    onTap: () => setState(() => _difficulty = _Difficulty.easy))),
                const SizedBox(width: 10),
                Expanded(child: _DiffBtn(label: 'Schwer', sub: 'Alle 195 Länder', active: _difficulty == _Difficulty.hard,
                    onTap: () => setState(() => _difficulty = _Difficulty.hard))),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9A825),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Starten', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Question screen ─────────────────────────────────────────────────────────
  Widget _buildQuestion() {
    final q = _questions[_qIndex];
    final progress = (_qIndex + 1) / _questionsPerRound;
    final timerProgress = _timeLeft / _secondsPerQ;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress + score
          Row(
            children: [
              Text('${_qIndex + 1}/$_questionsPerRound',
                  style: const TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEAEAE5),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF9A825)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$_score Pkt', style: const TextStyle(color: Color(0xFFF9A825), fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),

          // Timer bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: timerProgress,
              minHeight: 5,
              backgroundColor: const Color(0xFFEAEAE5),
              valueColor: AlwaysStoppedAnimation<Color>(
                timerProgress > 0.4 ? const Color(0xFF4A9E4A) : const Color(0xFFE53935),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('${_timeLeft}s',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _timeLeft <= 3 ? const Color(0xFFE53935) : const Color(0xFF888888))),
            ),
          ),
          const SizedBox(height: 20),

          // Country card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              children: [
                Text(q.country.flagEmoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text(q.country.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 6),
                const Text('Welche Währung hat dieses Land?',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Options
          ...List.generate(q.options.length, (i) {
            Color bg = const Color(0xFFEAEAE5);
            Color textColor = const Color(0xFF1A1A1A);
            if (_answered) {
              if (q.options[i] == q.correct) {
                bg = const Color(0xFFE8F5E9);
                textColor = const Color(0xFF2E7D32);
              } else if (i == _selectedIdx) {
                bg = const Color(0xFFFFEBEE);
                textColor = const Color(0xFFC62828);
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _pick(i),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _answered && q.options[i] == q.correct
                          ? const Color(0xFF4A9E4A)
                          : _answered && i == _selectedIdx
                              ? const Color(0xFFE53935)
                              : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(q.options[i],
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                      ),
                      if (_answered && q.options[i] == q.correct)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF4A9E4A), size: 20),
                      if (_answered && i == _selectedIdx && q.options[i] != q.correct)
                        const Icon(Icons.cancel_rounded, color: Color(0xFFE53935), size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Result screen ────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final pct = (_score / _questionsPerRound * 100).round();
    final emoji = pct == 100 ? '🏆' : pct >= 70 ? '🎯' : pct >= 40 ? '📈' : '💡';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text('$_score / $_questionsPerRound',
                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            Text('$pct % richtig',
                style: const TextStyle(fontSize: 16, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF9A825),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Nochmal spielen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Zurück', style: TextStyle(color: Color(0xFF888888))),
            ),
          ],
        ),
      ),
    );
  }
}

class _Question {
  final Country country;
  final String correct;
  final List<String> options;
  const _Question({required this.country, required this.correct, required this.options});
}

class _DiffBtn extends StatelessWidget {
  final String label, sub;
  final bool active;
  final VoidCallback onTap;
  const _DiffBtn({required this.label, required this.sub, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF8E7) : const Color(0xFFEAEAE5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? const Color(0xFFF9A825) : Colors.transparent, width: 2),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: active ? const Color(0xFFF9A825) : const Color(0xFF1A1A1A))),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
          ],
        ),
      ),
    );
  }
}
