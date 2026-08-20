import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/countries.dart';
import '../l10n/uebersetzungen.dart';
import '../theme/app_theme.dart';

class OutlineQuizScreen extends StatefulWidget {
  final int questionCount;
  final bool isDaily;
  final String? continent;
  const OutlineQuizScreen({
    super.key,
    this.questionCount = 10,
    this.isDaily = false,
    this.continent,
  });

  @override
  State<OutlineQuizScreen> createState() => _OutlineQuizScreenState();
}

class _OutlineQuizScreenState extends State<OutlineQuizScreen> {
  static const _optCount = 4;
  static const _accent = Color(0xFF2E7D32);
  static const _accentLight = Color(0xFFDFF2E1);

  bool _loading = true;
  Map<String, List<List<Offset>>> _rings = {};
  List<Country> _all = [];

  List<Country> _questions = [];
  List<List<Country>> _options = [];
  int _totalQ = 0;
  int _current = 0;
  String? _selected;
  int _score = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/geo/ne_50m_countries.geojson');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final features = json['features'] as List;

    final rings = <String, List<List<Offset>>>{};
    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>;
      final iso2Raw = props['ISO_A2'] as String? ?? '';
      final iso2 = iso2Raw == '-99'
          ? (props['ISO_A2_EH'] as String? ?? '')
          : iso2Raw;
      final name = props['NAME'] as String? ?? '';
      if (iso2.isEmpty || iso2 == '-99' || name == 'Antarctica') continue;

      final geo = f['geometry'] as Map<String, dynamic>;
      final type = geo['type'] as String;
      final coords = geo['coordinates'] as List;
      final rs = <List<Offset>>[];
      if (type == 'Polygon') {
        rs.add(_ring(coords[0] as List));
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          rs.add(_ring((poly as List)[0] as List));
        }
      }
      if (rs.isNotEmpty) rings[iso2] = _filterRings(rs);
    }

    final all = countries.where((c) => rings.containsKey(c.iso2)).toList();

    if (!mounted) return;
    setState(() {
      _rings = rings;
      _all = all;
      _loading = false;
    });
    _buildQuestions();
  }

  // Keep only rings with bbox area >= 1% of the largest ring
  List<List<Offset>> _filterRings(List<List<Offset>> rs) {
    if (rs.length <= 1) return rs;
    double bboxArea(List<Offset> r) {
      double minX = r[0].dx, maxX = r[0].dx;
      double minY = r[0].dy, maxY = r[0].dy;
      for (final p in r) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      return (maxX - minX) * (maxY - minY);
    }
    final areas = rs.map(bboxArea).toList();
    final maxA = areas.reduce(max);
    return [
      for (var i = 0; i < rs.length; i++)
        if (areas[i] >= maxA * 0.10) rs[i],
    ];
  }

  List<Offset> _ring(List coords) => coords
      .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
      .toList();

  void _buildQuestions() {
    final rng = Random();
    final pool = (widget.continent == null
            ? List<Country>.from(_all)
            : _all.where((c) => c.region == widget.continent).toList())
        ..shuffle(rng);
    final qs = pool.take(widget.questionCount).toList();
    final opts = qs.map((q) {
      final wrongs = (List<Country>.from(_all)
            ..removeWhere((c) => c.iso2 == q.iso2)
            ..shuffle(rng))
          .take(_optCount - 1)
          .toList();
      return ([q, ...wrongs]..shuffle(rng));
    }).toList();
    setState(() {
      _questions = qs;
      _options = opts;
      _totalQ = qs.length;
      _current = 0;
      _selected = null;
      _score = 0;
      _finished = false;
    });
  }

  void _answer(String iso2) {
    if (_selected != null) return;
    final correct = iso2 == _questions[_current].iso2;
    setState(() {
      _selected = iso2;
      if (correct) _score++;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_current + 1 >= _totalQ) {
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
      backgroundColor: kHintergrund,
      appBar: AppBar(
        backgroundColor: kHintergrund,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t('Umriss-Quiz'),
            style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? _buildLoading()
          : _finished
              ? _buildResult()
              : _buildQuestion(),
    );
  }

  Widget _buildLoading() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Color(0xFF2E7D32)),
          const SizedBox(height: 16),
          Text(t('Länderumrisse werden geladen…'),
              style: const TextStyle(
                  color: Color(0xFF888888), fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _buildQuestion() {
    final country = _questions[_current];
    final countryRings = _rings[country.iso2] ?? [];
    final opts = _options[_current];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(children: [
          _totalQ <= 25
              ? Row(
                  children: List.generate(_totalQ, (i) {
                    final c = i < _current
                        ? _accent
                        : i == _current
                            ? _accent.withValues(alpha: 0.4)
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
                    value: _totalQ > 0 ? _current / _totalQ : 0,
                    backgroundColor: const Color(0xFFD0D0CB),
                    valueColor: const AlwaysStoppedAnimation(_accent),
                    minHeight: 5,
                  ),
                ),
          const SizedBox(height: 6),
          Text(t('Frage {n} von {total}', {'n': '${_current + 1}', 'total': '$_totalQ'}),
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),

          // Silhouette card
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: _accentLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: CustomPaint(
                painter: _SilhouettePainter(rings: countryRings),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(t('Welches Land hat diesen Umriss?'),
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),

          ...opts.map((c) => _OutlineOption(
                country: c,
                correct: _questions[_current].iso2,
                selected: _selected,
                onTap: () => _answer(c.iso2),
              )),
        ]),
      ),
    );
  }

  Widget _buildResult() {
    final pct = (_score / _totalQ * 100).round();
    final emoji = pct >= 80 ? '🏆' : pct >= 50 ? '👍' : '📚';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Spacer(),
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 20),
          Text(t('{score} / {total} richtig', {'score': '$_score', 'total': '$_totalQ'}),
              style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            pct >= 80
                ? t('Umriss-Experte!')
                : pct >= 50
                    ? t('Gut gemacht!')
                    : t('Weiter üben!'),
            style: const TextStyle(color: Color(0xFF888888), fontSize: 15),
          ),
          const SizedBox(height: 40),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentLight,
              border: Border.all(
                color: pct >= 80
                    ? _accent
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
              onTap: _buildQuestions,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: _accent, borderRadius: BorderRadius.circular(16)),
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
        ]),
      ),
    );
  }
}

// ── Silhouette Painter ────────────────────────────────────────────────────────
// rings: Offset(longitude, latitude) in raw geographic degrees

class _SilhouettePainter extends CustomPainter {
  final List<List<Offset>> rings;
  const _SilhouettePainter({required this.rings});

  static const _fill = Color(0xFF2E7D32);
  static const _border = Color(0xFF1B5E20);
  static const _pad = 28.0;

  static double _mX(double lng) => (lng + 180) / 360;
  static double _mY(double lat) {
    final s = sin(lat * pi / 180);
    return 0.5 - log((1 + s) / (1 - s)) / (4 * pi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (rings.isEmpty) return;

    final proj = rings
        .map((r) => r.map((ll) => Offset(_mX(ll.dx), _mY(ll.dy))).toList())
        .toList();

    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final r in proj) {
      for (final p in r) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    final w = maxX - minX;
    final h = maxY - minY;
    if (w <= 0 || h <= 0) return;

    final avW = size.width - 2 * _pad;
    final avH = size.height - 2 * _pad;
    final sc = min(avW / w, avH / h);
    final dX = _pad + (avW - w * sc) / 2 - minX * sc;
    final dY = _pad + (avH - h * sc) / 2 - minY * sc;

    final fillPaint = Paint()
      ..color = _fill
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = _border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final r in proj) {
      if (r.length < 3) continue;
      final path = Path()
        ..moveTo(r[0].dx * sc + dX, r[0].dy * sc + dY);
      for (final p in r.skip(1)) {
        path.lineTo(p.dx * sc + dX, p.dy * sc + dY);
      }
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_SilhouettePainter o) => o.rings != rings;
}

// ── Option ────────────────────────────────────────────────────────────────────

class _OutlineOption extends StatelessWidget {
  final Country country;
  final String correct;
  final String? selected;
  final VoidCallback onTap;

  const _OutlineOption({
    required this.country,
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
      if (country.iso2 == correct) {
        bg = const Color(0xFFE8F5E9);
        text = const Color(0xFF2E7D32);
        trailing = const Icon(Icons.check_circle_rounded,
            color: Color(0xFF4A9E4A), size: 20);
      } else if (country.iso2 == selected) {
        bg = const Color(0xFFFFEBEE);
        text = const Color(0xFFC62828);
        trailing =
            const Icon(Icons.cancel_rounded, color: Color(0xFFE57373), size: 20);
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
            color: selected != null && country.iso2 == correct
                ? const Color(0xFF4A9E4A)
                : selected != null && country.iso2 == selected
                    ? const Color(0xFFE57373)
                    : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Text(country.flagEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(country.name,
                style: TextStyle(
                    color: text, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          ?trailing,
        ]),
      ),
    );
  }
}
