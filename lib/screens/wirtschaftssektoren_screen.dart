import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/wirtschaftssektoren.dart';

// ── Phase ─────────────────────────────────────────────────────────────────────

enum _Phase { start, learn, quiz, result }

// ── Quiz question ─────────────────────────────────────────────────────────────

class _Question {
  final SektorData correct;
  final List<String> options; // 4 sector names
  _Question({required this.correct, required this.options});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WirtschaftssektorenScreen extends StatefulWidget {
  const WirtschaftssektorenScreen({super.key});

  @override
  State<WirtschaftssektorenScreen> createState() =>
      _WirtschaftssektorenScreenState();
}

class _WirtschaftssektorenScreenState
    extends State<WirtschaftssektorenScreen> {
  static const _kQuizCount = 10;
  static const _kLearnCount = 8;

  _Phase _phase = _Phase.start;

  // Learn
  late List<SektorData> _learnCards;
  late PageController _pageCtrl;
  int _cardIndex = 0;

  // Quiz
  late List<_Question> _questions;
  int _qIndex = 0;
  int _score = 0;
  String? _picked;
  bool _answered = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Learn setup ──────────────────────────────────────────────────────────────

  void _startLearn() {
    final rng = Random();
    _learnCards = List.of(wirtschaftssektoren)
      ..shuffle(rng);
    _learnCards = _learnCards.take(_kLearnCount).toList();
    _pageCtrl = PageController();
    setState(() {
      _phase = _Phase.learn;
      _cardIndex = 0;
    });
  }

  // ── Quiz setup ───────────────────────────────────────────────────────────────

  void _startQuiz() {
    final rng = Random();
    final pool = List.of(wirtschaftssektoren)..shuffle(rng);
    final picked = pool.take(_kQuizCount).toList();
    final allSectors = sektorEmojis.keys.toList();

    final qs = picked.map((c) {
      final wrong = allSectors
          .where((s) => s != c.mainSector)
          .toList()
        ..shuffle(rng);
      final opts = [c.mainSector, ...wrong.take(3)]..shuffle(rng);
      return _Question(correct: c, options: opts);
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

  // ── Answer ───────────────────────────────────────────────────────────────────

  void _pick(String option) {
    if (_answered) return;
    final isCorrect = option == _questions[_qIndex].correct.mainSector;
    setState(() {
      _picked = option;
      _answered = true;
      if (isCorrect) _score++;
    });
    _timer = Timer(const Duration(milliseconds: 1100), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_qIndex + 1 >= _kQuizCount) {
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
        _Phase.start  => _buildStart(),
        _Phase.learn  => _buildLearn(),
        _Phase.quiz   => _buildQuiz(),
        _Phase.result => _buildResult(),
      },
    );
  }

  // ── Start screen ─────────────────────────────────────────────────────────────

  Widget _buildStart() {
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
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF1A1A1A), size: 18),
              ),
            ),
            const SizedBox(height: 32),
            const Text('🏭', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('Wirtschaftssektoren',
                style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Lerne die wichtigsten Wirtschaftssektoren der Welt kennen.',
                style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4)),
            const SizedBox(height: 32),

            // Sector chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sektorEmojis.entries.map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAEAE5),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${e.value} ${e.key}',
                    style: const TextStyle(
                        color: Color(0xFF444444),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              )).toList(),
            ),
            const Spacer(),

            const Text('WAS MÖCHTEST DU TUN?',
                style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: _startLearn,
              child: _ModeCard(
                emoji: '📚',
                title: 'Lernen',
                sub: '8 Lernkarten — swipe durch Länder und Sektoren',
                color: const Color(0xFFE8F5E9),
                textColor: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _startQuiz,
              child: _ModeCard(
                emoji: '🧠',
                title: 'Quiz',
                sub: '10 Fragen — welcher Sektor dominiert dieses Land?',
                color: const Color(0xFFE3F2FD),
                textColor: const Color(0xFF1565C0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Learn mode ───────────────────────────────────────────────────────────────

  Widget _buildLearn() {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _phase = _Phase.start),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEAEAE5),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Color(0xFF1A1A1A), size: 18),
                  ),
                ),
                const Spacer(),
                Text('${_cardIndex + 1} / ${_learnCards.length}',
                    style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: _startQuiz,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF4A9E4A),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Quiz starten',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Dot progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(_learnCards.length, (i) {
                final active = i == _cardIndex;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _cardIndex
                          ? const Color(0xFF4A9E4A)
                          : const Color(0xFFD0D0CB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Cards
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: _learnCards.length,
              onPageChanged: (i) => setState(() => _cardIndex = i),
              itemBuilder: (_, i) => _LearnCard(data: _learnCards[i]),
            ),
          ),

          // Swipe hint / Next button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: _cardIndex < _learnCards.length - 1
                ? GestureDetector(
                    onTap: () => _pageCtrl.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF4A9E4A),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Text('Weiter →',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  )
                : GestureDetector(
                    onTap: _startQuiz,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF4A9E4A),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Text('Quiz starten 🧠',
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

  // ── Quiz mode ────────────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    final q = _questions[_qIndex];
    final correct = q.correct;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => setState(() => _phase = _Phase.start),
        ),
        title: const Text('Wirtschaftssektoren',
            style: TextStyle(
                color: Color(0xFF1A1A1A), fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$_score/$_kQuizCount',
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
              // Progress bar
              Row(
                children: List.generate(_kQuizCount, (i) {
                  final color = i < _qIndex
                      ? const Color(0xFF4A9E4A)
                      : i == _qIndex
                          ? const Color(0xFF4A9E4A).withValues(alpha: 0.35)
                          : const Color(0xFFD0D0CB);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 5,
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(3)),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text('Frage ${_qIndex + 1} von $_kQuizCount',
                  style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),

              // Country
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(correct.flagEmoji,
                        style: const TextStyle(fontSize: 68)),
                    const SizedBox(height: 12),
                    Text(correct.countryName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('Was ist der wichtigste Wirtschaftssektor?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    // Fun fact after answer
                    if (_answered && correct.funFact.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12)),
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
                    ],
                  ],
                ),
              ),

              // Options
              ...q.options.map((opt) {
                final emoji = sektorEmojis[opt] ?? '';
                Color bg = const Color(0xFFEAEAE5);
                Color textColor = const Color(0xFF1A1A1A);
                Widget? trailing;

                if (_answered) {
                  if (opt == correct.mainSector) {
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
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                        color: bg, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
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
    final pct = (_score / _kQuizCount * 100).round();
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
            Text('$_score / $_kQuizCount richtig',
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
              onTap: _startQuiz,
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
              onTap: _startLearn,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAEAE5),
                    borderRadius: BorderRadius.circular(16)),
                child: const Text('Nochmal lernen 📚',
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
}

// ── Learn card ────────────────────────────────────────────────────────────────

class _LearnCard extends StatelessWidget {
  final SektorData data;
  const _LearnCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        children: [
          // Header card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              children: [
                Text(data.flagEmoji, style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                Text(data.countryName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A9E4A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${data.sektorEmoji}  ${data.mainSector}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Description
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAE5),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(16),
            child: Text(data.sectorDescription,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.55)),
          ),
          const SizedBox(height: 10),

          // Top exports
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAE5),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOP EXPORTE',
                    style: TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: data.topExports.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(e,
                        style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
              ],
            ),
          ),

          // Fun fact
          if (data.funFact.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(data.funFact,
                        style: const TextStyle(
                            color: Color(0xFF5D4037),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.45)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Mode card ─────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final String emoji, title, sub;
  final Color color, textColor;
  const _ModeCard({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: textColor, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(sub,
                    style: TextStyle(
                        color: textColor.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              color: textColor.withValues(alpha: 0.5), size: 14),
        ],
      ),
    );
  }
}
