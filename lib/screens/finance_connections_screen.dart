import 'dart:math';
import 'package:flutter/material.dart';
import '../data/countries.dart';
import '../data/connections_puzzles.dart';

class FinanceConnectionsScreen extends StatefulWidget {
  const FinanceConnectionsScreen({super.key});

  @override
  State<FinanceConnectionsScreen> createState() => _FinanceConnectionsScreenState();
}

class _FinanceConnectionsScreenState extends State<FinanceConnectionsScreen> {
  static const _maxWrong = 3;

  // ── country lookup ──────────────────────────────────────────────────────────
  static final Map<String, Country> _cMap = {for (final c in countries) c.iso2: c};

  late ConnectionsPuzzle _puzzle;
  late List<String> _remaining; // iso2s still in the grid
  late List<String> _selected;
  late List<ConnectionsGroup> _solved;
  int _wrongLeft = _maxWrong;
  bool _gameOver = false;
  bool _victory = false;
  bool _shakeWrong = false;

  @override
  void initState() {
    super.initState();
    _initPuzzle();
  }

  void _initPuzzle() {
    final dayIndex = DateTime.now().difference(DateTime(2024)).inDays % connectionsPuzzles.length;
    _puzzle = connectionsPuzzles[dayIndex];
    final all = _puzzle.groups.expand((g) => g.iso2s).toList()..shuffle(Random());
    _remaining = all;
    _selected = [];
    _solved = [];
    _wrongLeft = _maxWrong;
    _gameOver = false;
    _victory = false;
    _shakeWrong = false;
  }

  void _toggle(String iso2) {
    if (_gameOver || _victory) return;
    if (_selected.contains(iso2)) {
      setState(() => _selected.remove(iso2));
    } else if (_selected.length < 4) {
      setState(() => _selected.add(iso2));
    }
  }

  void _check() {
    if (_selected.length != 4) return;
    final selectedSet = _selected.toSet();
    for (final group in _puzzle.groups) {
      if (_solved.contains(group)) continue;
      if (group.iso2s.toSet().difference(selectedSet).isEmpty) {
        // Correct!
        setState(() {
          _solved.add(group);
          for (final iso in group.iso2s) { _remaining.remove(iso); }
          _selected.clear();
          if (_solved.length == 4) _victory = true;
        });
        return;
      }
    }
    // Wrong
    setState(() => _wrongLeft--);
    if (_wrongLeft <= 0) {
      // Reveal all
      setState(() {
        for (final g in _puzzle.groups) {
          if (!_solved.contains(g)) _solved.add(g);
        }
        _remaining.clear();
        _selected.clear();
        _gameOver = true;
      });
      return;
    }
    // Flash wrong briefly
    setState(() => _shakeWrong = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() { _shakeWrong = false; _selected.clear(); });
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
        title: const Column(children: [
          Text('Connections', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800, fontSize: 18)),
          Text('Finanz-Edition', style: TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            // Lives
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Versuche übrig: ', style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
                ...List.generate(_maxWrong, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(Icons.circle, size: 14,
                      color: i < _wrongLeft ? const Color(0xFF4A9E4A) : const Color(0xFFD0D0CB)),
                )),
              ],
            ),
            const SizedBox(height: 12),

            // Solved groups
            ..._solved.map((g) => _SolvedBanner(group: g, cMap: _cMap)),

            // Active grid
            if (_remaining.isNotEmpty)
              _buildGrid(),

            const SizedBox(height: 16),

            // Status messages
            if (_victory)
              _StatusCard(emoji: '🎉', title: 'Glückwunsch!', sub: 'Alle Gruppen gefunden!',
                  color: const Color(0xFFE8F5E9), textColor: const Color(0xFF2E7D32))
            else if (_gameOver)
              _StatusCard(emoji: '💡', title: 'Game Over', sub: 'Nicht schlimm – du hast es gelernt!',
                  color: const Color(0xFFFFEBEE), textColor: const Color(0xFFC62828)),

            // Check button
            if (!_victory && !_gameOver) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selected.isEmpty ? null : () => setState(() => _selected.clear()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFD0D0CB)),
                    ),
                    child: const Text('Auswahl löschen', style: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selected.length == 4 ? _check : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Prüfen', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ]),
            ],

            if (_victory || _gameOver) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(_initPuzzle),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Nochmal spielen', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],

            const SizedBox(height: 8),
            const Text('Täglich neues Rätsel · Wähle 4 zusammengehörende Länder',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.82,
      ),
      itemCount: _remaining.length,
      itemBuilder: (context, i) {
        final iso2 = _remaining[i];
        final country = _cMap[iso2];
        final selected = _selected.contains(iso2);
        final isWrong = _shakeWrong && selected;
        return GestureDetector(
          onTap: () => _toggle(iso2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: selected
                  ? (isWrong ? const Color(0xFFFFEBEE) : const Color(0xFF8B5CF6))
                  : const Color(0xFFEAEAE5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? (isWrong ? const Color(0xFFE53935) : const Color(0xFF6D28D9)) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(country?.flagEmoji ?? iso2, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    country?.name ?? iso2,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SolvedBanner extends StatelessWidget {
  final ConnectionsGroup group;
  final Map<String, Country> cMap;
  const _SolvedBanner({required this.group, required this.cMap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: group.color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: group.color, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                  color: group.color == const Color(0xFFF9C74F) ? const Color(0xFF7B5800) : group.color)),
          const SizedBox(height: 6),
          Row(
            children: group.iso2s.map((iso) {
              final c = cMap[iso];
              return Expanded(
                child: Column(children: [
                  Text(c?.flagEmoji ?? iso, style: const TextStyle(fontSize: 22)),
                  Text(c?.name ?? iso,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String emoji, title, sub;
  final Color color, textColor;
  const _StatusCard({required this.emoji, required this.title, required this.sub, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: textColor)),
          Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
        ]),
      ]),
    );
  }
}
