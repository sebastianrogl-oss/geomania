import 'dart:math';
import 'package:flutter/material.dart';
import '../data/country_rankings.dart';

// ── Category definition ───────────────────────────────────────────────────────

class _SortCat {
  final String id, label, instruction;
  final bool higherFirst;
  final double? Function(CountryRanking) getValue;

  const _SortCat({
    required this.id,
    required this.label,
    required this.instruction,
    required this.higherFirst,
    required this.getValue,
  });
}

final _kCats = [
  _SortCat(
    id: 'gdp',
    label: 'BIP pro Kopf (USD)',
    instruction: 'Sortiere vom höchsten zum niedrigsten BIP pro Kopf',
    higherFirst: true,
    getValue: (c) => c.gdpPerCapita,
  ),
  _SortCat(
    id: 'pop',
    label: 'Bevölkerung',
    instruction: 'Sortiere vom bevölkerungsreichsten zum kleinsten Land',
    higherFirst: true,
    getValue: (c) => c.population?.toDouble(),
  ),
  _SortCat(
    id: 'area',
    label: 'Fläche (km²)',
    instruction: 'Sortiere vom größten zum kleinsten Land nach Fläche',
    higherFirst: true,
    getValue: (c) => c.area,
  ),
  _SortCat(
    id: 'life',
    label: 'Lebenserwartung (Jahre)',
    instruction: 'Sortiere von der höchsten zur niedrigsten Lebenserwartung',
    higherFirst: true,
    getValue: (c) => c.lifeExpectancy,
  ),
  _SortCat(
    id: 'growth',
    label: 'BIP-Wachstum 2023 (%)',
    instruction: 'Sortiere vom höchsten zum niedrigsten BIP-Wachstum 2023',
    higherFirst: true,
    getValue: (c) => gdpGrowthRates[c.iso2],
  ),
];

// ── Round data ────────────────────────────────────────────────────────────────

class _Round {
  final _SortCat cat;
  final List<CountryRanking> correct;
  _Round(this.cat, this.correct);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtValue(_SortCat cat, CountryRanking c) {
  final v = cat.getValue(c);
  if (v == null) return '–';
  switch (cat.id) {
    case 'gdp':
      return '\$ ${_fmtN(v.round())}';
    case 'pop':
      if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2).replaceAll('.', ',')} Mrd.';
      if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1).replaceAll('.', ',')} Mio.';
      return _fmtN(v.round());
    case 'area':
      return '${_fmtN(v.round())} km²';
    case 'life':
      return '${v.toStringAsFixed(1).replaceAll('.', ',')} J.';
    case 'growth':
      return '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1).replaceAll('.', ',')}%';
    default:
      return v.toStringAsFixed(1);
  }
}

String _fmtN(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SortierSpielScreen extends StatefulWidget {
  const SortierSpielScreen({super.key});

  @override
  State<SortierSpielScreen> createState() => _SortierSpielScreenState();
}

class _SortierSpielScreenState extends State<SortierSpielScreen>
    with TickerProviderStateMixin {
  static const _kRounds = 3;
  static const _kPerRound = 5;
  static const _kPtsPerCorrect = 20;

  late List<_Round> _rounds;
  int _roundIdx = 0;
  late List<CountryRanking> _current;
  bool _answered = false;
  bool _finished = false;
  bool _allRichtig = false;
  int _totalScore = 0;
  int _roundPts = 0;

  late final AnimationController _erfolgCtrl;
  late final AnimationController _slideCtrl;

  @override
  void initState() {
    super.initState();
    _erfolgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _buildRounds();
  }

  @override
  void dispose() {
    _erfolgCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _buildRounds() {
    final rng = Random();
    final cats = List.of(_kCats)..shuffle(rng);
    final rounds = <_Round>[];
    final usedIso2s = <String>{};

    for (final cat in cats.take(_kRounds)) {
      final pool = countryRankings
          .where((c) => !usedIso2s.contains(c.iso2))
          .where((c) => cat.getValue(c) != null)
          .toList()
        ..shuffle(rng);
      final picked = pool.take(_kPerRound).toList();
      final correct = List.of(picked)
        ..sort((a, b) {
          final va = cat.getValue(a)!;
          final vb = cat.getValue(b)!;
          return cat.higherFirst ? vb.compareTo(va) : va.compareTo(vb);
        });
      for (final c in picked) {
        usedIso2s.add(c.iso2);
      }
      rounds.add(_Round(cat, correct));
    }

    _rounds = rounds;
    _current = List.of(_rounds[0].correct)..shuffle(rng);
    _answered = false;
    _finished = false;
    _allRichtig = false;
    _totalScore = 0;
    _roundIdx = 0;
    _roundPts = 0;
    _erfolgCtrl.reset();
    _slideCtrl.reset();
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final item = _current.removeAt(oldIndex);
      _current.insert(newIndex, item);
    });
  }

  void _confirm() {
    final correct = _rounds[_roundIdx].correct;
    int pts = 0;
    for (int i = 0; i < _kPerRound; i++) {
      if (_current[i].iso2 == correct[i].iso2) pts += _kPtsPerCorrect;
    }
    final allRichtig = pts == _kPerRound * _kPtsPerCorrect;
    setState(() {
      _answered = true;
      _roundPts = pts;
      _totalScore += pts;
      _allRichtig = allRichtig;
    });
    if (allRichtig) {
      _erfolgCtrl.forward();
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _next();
      });
    } else {
      _slideCtrl.forward();
    }
  }

  void _next() {
    if (_roundIdx + 1 >= _kRounds) {
      setState(() => _finished = true);
      return;
    }
    final rng = Random();
    _erfolgCtrl.reset();
    _slideCtrl.reset();
    setState(() {
      _roundIdx++;
      _answered = false;
      _roundPts = 0;
      _allRichtig = false;
      _current = List.of(_rounds[_roundIdx].correct)..shuffle(rng);
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
        title: Text(
          'Runde ${_roundIdx + 1} / $_kRounds',
          style: const TextStyle(
              color: Color(0xFF1A1A1A), fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$_totalScore Pkt.',
                  style: const TextStyle(
                      color: Color(0xFF4A9E4A),
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: _finished ? _buildResult() : _buildRound(),
    );
  }

  // ── Round view ─────────────────────────────────────────────────────────────

  Widget _buildRound() {
    final round = _rounds[_roundIdx];

    return Stack(
      children: [
        // Haupt-Inhalt
        SafeArea(
          child: Column(
            children: [
              // Kategorie-Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(round.cat.instruction,
                          style: const TextStyle(
                              color: Color(0xFF1B5E20),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.4)),
                      const SizedBox(height: 4),
                      Text(
                        _answered
                            ? 'Ergebnis: $_roundPts / ${_kPerRound * _kPtsPerCorrect} Punkte'
                            : 'Ziehe die Karten in die richtige Reihenfolge',
                        style: const TextStyle(
                            color: Color(0xFF4A9E4A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Pos.-Label
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('Pos.',
                        style: TextStyle(
                            color: Color(0xFFBBBBBB),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Drag-Liste (eingefroren wenn beantwortet)
              Expanded(
                child: ReorderableListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  onReorderItem: _answered ? (a, b) {} : _onReorderItem,
                  children: [
                    for (int i = 0; i < _current.length; i++)
                      _DragCard(
                        key: ValueKey(_current[i].iso2),
                        position: i + 1,
                        country: _current[i],
                        cat: round.cat,
                      ),
                  ],
                ),
              ),

              // Bestätigen-Button (nur solange nicht beantwortet)
              if (!_answered)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: GestureDetector(
                    onTap: _confirm,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A9E4A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Reihenfolge bestätigen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Overlays ────────────────────────────────────────────────────────
        if (_answered && _allRichtig) _buildErfolgOverlay(),
        if (_answered && !_allRichtig) _buildLoesungsOverlay(),
      ],
    );
  }

  // ── Erfolgs-Overlay (alles richtig) ────────────────────────────────────────

  Widget _buildErfolgOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _erfolgCtrl, curve: Curves.elasticOut),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A9E4A),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A9E4A).withValues(alpha: 0.5),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 54),
              ),
              const SizedBox(height: 20),
              const Text(
                'Perfekt! 🎉',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Lösungs-Overlay (teilweise oder ganz falsch) ───────────────────────────

  Widget _buildLoesungsOverlay() {
    final round = _rounds[_roundIdx];
    final correct = round.correct;
    final richtigAnzahl = List.generate(
      _kPerRound,
      (i) => _current[i].iso2 == correct[i].iso2,
    ).where((b) => b).length;
    final istFinal = _roundIdx + 1 >= _kRounds;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic)),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            children: [
              // Griff
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),

              // Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'So wäre es richtig gewesen:',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF888888),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Richtige Reihenfolge
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _kPerRound,
                  itemBuilder: (_, i) {
                    final c = correct[i];
                    final userRichtig = _current[i].iso2 == c.iso2;
                    return _LoesungsKarte(
                      position: i + 1,
                      country: c,
                      cat: round.cat,
                      isCorrect: userRichtig,
                    );
                  },
                ),
              ),

              // Zusammenfassung
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Row(
                  children: [
                    Icon(
                      richtigAnzahl >= 3
                          ? Icons.emoji_events_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: richtigAnzahl >= 3
                          ? const Color(0xFF4A9E4A)
                          : const Color(0xFFE53935),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Du hast $richtigAnzahl/$_kPerRound richtig sortiert',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: richtigAnzahl >= 3
                            ? const Color(0xFF4A9E4A)
                            : const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              ),

              // WEITER-Button
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 0, 16, MediaQuery.paddingOf(context).bottom + 14),
                child: GestureDetector(
                  onTap: _next,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9E4A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      istFinal ? 'Ergebnis anzeigen →' : 'WEITER →',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ergebnis-Screen ────────────────────────────────────────────────────────

  Widget _buildResult() {
    final maxScore = _kRounds * _kPerRound * _kPtsPerCorrect;
    final pct = (_totalScore / maxScore * 100).round();
    final emoji = pct >= 70 ? '🏆' : pct >= 40 ? '👍' : '📚';
    final grade =
        pct >= 70 ? 'Ausgezeichnet!' : pct >= 40 ? 'Gut gemacht!' : 'Weiter üben!';
    final ringColor = pct >= 70
        ? const Color(0xFF4A9E4A)
        : pct >= 40
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
            Text('$_totalScore / $maxScore Punkte',
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
              onTap: () => setState(_buildRounds),
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

// ── Drag Card ─────────────────────────────────────────────────────────────────

class _DragCard extends StatelessWidget {
  final int position;
  final CountryRanking country;
  final _SortCat cat;

  const _DragCard({
    required super.key,
    required this.position,
    required this.country,
    required this.cat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAE5),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFFD0D0CB)),
            child: Center(
              child: Text('$position',
                  style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Text(country.flagEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(country.name,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ),
          const Icon(Icons.drag_handle_rounded, color: Color(0xFFBBBBBB), size: 22),
        ],
      ),
    );
  }
}

// ── Lösungs-Karte (richtige Reihenfolge im Overlay) ──────────────────────────

class _LoesungsKarte extends StatelessWidget {
  final int position;
  final CountryRanking country;
  final _SortCat cat;
  final bool isCorrect;

  const _LoesungsKarte({
    required this.position,
    required this.country,
    required this.cat,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isCorrect ? const Color(0xFF4A9E4A) : const Color(0xFFE53935);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Position-Nummer in farbigem Kreis
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: borderColor),
            child: Center(
              child: Text('$position',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Text(country.flagEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(country.name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isCorrect
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFFB71C1C))),
          ),
          // Kategorie-Wert rechts
          Text(_fmtValue(cat, country),
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
