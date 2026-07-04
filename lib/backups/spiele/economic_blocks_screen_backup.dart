// BACKUP - economic_blocks_screen.dart - Stand: 2026-06-17
// Originalort: lib/screens/economic_blocks_screen.dart
// Beschreibung: Wirtschaftsblöcke-Quiz — 10 Multiple-Choice-Fragen,
//               welchem Block (EU, G7, G20, OPEC, BRICS, ASEAN) gehört das Land?
// Wiederherstellen: zurückkopieren nach lib/screens/economic_blocks_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../data/countries.dart';
import '../data/economic_blocks.dart';

class EconomicBlocksScreen extends StatefulWidget {
  const EconomicBlocksScreen({super.key});

  @override
  State<EconomicBlocksScreen> createState() => _EconomicBlocksScreenState();
}

class _EconomicBlocksScreenState extends State<EconomicBlocksScreen> {
  static const _questionsPerRound = 10;

  bool _started = false;
  late List<_Question> _questions;
  int _qIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedIdx;
  bool _done = false;

  void _startGame() {
    final rng = Random();
    final pool = countries.where((c) => economicBlockPrimary.containsKey(c.iso2)).toList()..shuffle(rng);
    // Mix 70% block countries + 30% "Keiner davon" countries
    final nonBlock = countries.where((c) => !economicBlockPrimary.containsKey(c.iso2)).toList()..shuffle(rng);
    final mixed = [
      ...pool.take(7),
      ...nonBlock.take(3),
    ]..shuffle(rng);

    _questions = mixed.take(_questionsPerRound).map((c) {
      final correct = primaryBlockFor(c.iso2);
      // Build 4 options: correct + 3 different blocks
      final others = allBlocks.where((b) => b != correct).toList()..shuffle(rng);
      final opts = [correct, ...others.take(3)]..shuffle(rng);
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
  }

  void _pick(int idx) {
    if (_answered) return;
    final correct = _questions[_qIndex].options[idx] == _questions[_qIndex].correct;
    setState(() {
      _answered = true;
      _selectedIdx = idx;
      if (correct) _score++;
    });
    Future.delayed(const Duration(milliseconds: 1200), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_qIndex + 1 >= _questionsPerRound) { setState(() => _done = true); return; }
    setState(() { _qIndex++; _answered = false; _selectedIdx = null; });
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
        title: const Text('Wirtschaftsblöcke',
            style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: !_started ? _buildStart() : _done ? _buildResult() : _buildQuestion(),
    );
  }

  Widget _buildStart() {
    final blockInfo = [
      ('🇪🇺', 'EU', '27 Länder'),
      ('🤝', 'G7', 'Führende Industriestaaten'),
      ('🌐', 'G20', '19 Länder + EU'),
      ('🛢️', 'OPEC', '12 Ölförderländer'),
      ('🌍', 'BRICS', '5 Schwellenländer'),
      ('🌏', 'ASEAN', '10 Südostasien-Länder'),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Text('🤝', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('Wirtschaftsblöcke',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          const Text('Welchem Wirtschaftsblock gehört das Land?\n10 Fragen · Multiple Choice',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
          const SizedBox(height: 28),
          const Align(alignment: Alignment.centerLeft,
            child: Text('DIE BLÖCKE',
                style: TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
          const SizedBox(height: 10),
          ...blockInfo.map((b) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: const Color(0xFFEAEAE5), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Text(b.$1, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Text(b.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1A1A))),
              const SizedBox(width: 8),
              Text('· ${b.$3}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
            ]),
          )),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90D9),
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
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_qIndex];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress bar
          Row(children: [
            Text('${_qIndex + 1}/$_questionsPerRound',
                style: const TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_qIndex + 1) / _questionsPerRound,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEAEAE5),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A90D9)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$_score Pkt', style: const TextStyle(color: Color(0xFF4A90D9), fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 24),

          // Country display
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFB3D9FF), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(children: [
              Text(q.country.flagEmoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(q.country.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 6),
              const Text('Zu welchem Wirtschaftsblock gehört dieses Land?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 20),

          // Correct block info if answered
          if (_answered)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _questions[_qIndex].options[_selectedIdx ?? -1] == q.correct
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Icon(
                  _questions[_qIndex].options[_selectedIdx ?? -1] == q.correct
                      ? Icons.check_circle_rounded
                      : Icons.info_rounded,
                  color: _questions[_qIndex].options[_selectedIdx ?? -1] == q.correct
                      ? const Color(0xFF4A9E4A)
                      : const Color(0xFF1565C0),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${q.country.name} gehört zu: ${q.correct}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _questions[_qIndex].options[_selectedIdx ?? -1] == q.correct
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1565C0),
                    ),
                  ),
                ),
              ]),
            ),

          // Options
          ...List.generate(q.options.length, (i) {
            Color bg = const Color(0xFFEAEAE5);
            Color textColor = const Color(0xFF1A1A1A);
            if (_answered) {
              if (q.options[i] == q.correct) { bg = const Color(0xFFE8F5E9); textColor = const Color(0xFF2E7D32); }
              else if (i == _selectedIdx) { bg = const Color(0xFFFFEBEE); textColor = const Color(0xFFC62828); }
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
                  child: Row(children: [
                    Expanded(child: Text(q.options[i],
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor))),
                    if (_answered && q.options[i] == q.correct)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF4A9E4A), size: 20),
                    if (_answered && i == _selectedIdx && q.options[i] != q.correct)
                      const Icon(Icons.cancel_rounded, color: Color(0xFFE53935), size: 20),
                  ]),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final pct = (_score / _questionsPerRound * 100).round();
    final emoji = pct == 100 ? '🏆' : pct >= 70 ? '🤝' : pct >= 40 ? '📊' : '📚';
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
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90D9), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                ),
                child: const Text('Nochmal spielen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Zurück', style: TextStyle(color: Color(0xFF888888)))),
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
