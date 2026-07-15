import 'package:flutter/material.dart';
import '../data/countries.dart';
import '../data/lernen_fakten.dart';
import '../l10n/uebersetzungen.dart';
import '../services/stats_service.dart';
import 'quiz_screen.dart';
import 'flag_quiz_screen.dart';
import 'gdp_quiz_screen.dart';
import 'outline_quiz_screen.dart';
import 'waehrungen_screen.dart';
import 'wirtschaftssektoren_screen.dart';
import 'sortier_spiel_screen.dart';
import 'category_match_screen.dart';

// ── Quiz-Settings ─────────────────────────────────────────────────────────────

class _QuizSettings {
  final String? continent;
  final int count;
  const _QuizSettings({this.continent, required this.count});
}

Future<_QuizSettings?> _pickSettings(
    BuildContext context, Map<String, int> rawMap) async {
  final continent = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContinentPicker(rawMap: rawMap),
  );
  if (continent == null) return null;
  if (!context.mounted) return null;
  final total = continent == 'Alle'
      ? countries.length
      : countries.where((c) => c.region == continent).length;
  final count = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _CountPicker(total: total),
  );
  if (count == null) return null;
  return _QuizSettings(
    continent: continent == 'Alle' ? null : continent,
    count: count,
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LernenScreen extends StatefulWidget {
  const LernenScreen({super.key});

  @override
  State<LernenScreen> createState() => _LernenScreenState();
}

class _LernenScreenState extends State<LernenScreen> {
  int _streak = 0;
  Map<String, LernenProgress> _progress = {};
  Map<String, Map<String, int>> _rawMaps = {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final p = await StatsService.allLernenProgress();
    final streak = await StatsService.getStreak();
    final rawFlags = await StatsService.getRawProgressMap('flags');
    final rawCapitals = await StatsService.getRawProgressMap('capitals');
    final rawEconomy = await StatsService.getRawProgressMap('economy');
    if (mounted) {
      setState(() {
        _progress = p;
        _streak = streak;
        _rawMaps = {
          'flags': rawFlags,
          'capitals': rawCapitals,
          'economy': rawEconomy,
        };
      });
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    _loadProgress();
  }

  String _getDailyFact() {
    final seed = DateTime.now().difference(DateTime(2024)).inDays;
    return lernenFakten[seed % lernenFakten.length];
  }

  @override
  Widget build(BuildContext context) {
    final flagsP = _progress['flags'] ?? LernenProgress.empty();
    final capsP = _progress['capitals'] ?? LernenProgress.empty();
    final econP = _progress['economy'] ?? LernenProgress.empty();
    final totalSeen = flagsP.seenCount + capsP.seenCount + econP.seenCount;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Text(t('Lernen'),
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(t('Was möchtest du heute lernen?'),
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),

            // ── Fakt des Tages ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B3A2D),
                borderRadius: BorderRadius.circular(18),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9E4A).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('💡', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('FAKT DES TAGES'),
                            style: const TextStyle(
                                color: Color(0xFF4A9E4A),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 5),
                        Text(t(_getDailyFact()),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.6)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── DEIN FORTSCHRITT ──────────────────────────────────────────────
            Text(t('DEIN FORTSCHRITT'),
                style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FortschrittPill(
                    value: '$_streak',
                    label: t('Streak'),
                    valueColor: const Color(0xFF4A9E4A),
                    barColor: const Color(0xFF4A9E4A),
                    progress: (_streak / 7).clamp(0.0, 1.0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FortschrittPill(
                    value: '$totalSeen',
                    label: t('Gelernt'),
                    valueColor: const Color(0xFF1A1A1A),
                    barColor: const Color(0xFF4A9E4A),
                    progress: (totalSeen / 195).clamp(0.0, 1.0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FortschrittPill(
                    value: '0',
                    label: t('Abzeichen'),
                    valueColor: const Color(0xFFF9A825),
                    barColor: const Color(0xFFF9A825),
                    progress: 0.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── KATEGORIEN ────────────────────────────────────────────────────
            Text(t('KATEGORIEN'),
                style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 105,
              ),
              itemCount: 6,
              itemBuilder: (context, i) {
                return [
                  _KategorieTile(
                    title: t('🏳️ Flaggen'),
                    sub: t('195 Länder'),
                    badge: '195 Flags',
                    bg: const Color(0xFFEBF3FF),
                    titleColor: const Color(0xFF1A3A6B),
                    subColor: const Color(0xFF4A90D9),
                    badgeBg: const Color(0xFFD6E8FF),
                    badgeColor: const Color(0xFF0C447C),
                    onTap: () async {
                      final s = await _pickSettings(
                          context, _rawMaps['flags'] ?? {});
                      if (s == null || !context.mounted) return;
                      _push(FlagQuizScreen(
                          questionCount: s.count,
                          continent: s.continent));
                    },
                  ),
                  _KategorieTile(
                    title: t('🏛️ Hauptstädte'),
                    sub: t('195 Städte'),
                    badge: t('Quiz'),
                    bg: const Color(0xFFF3EEFF),
                    titleColor: const Color(0xFF3B1A6B),
                    subColor: const Color(0xFF7C3AED),
                    badgeBg: const Color(0xFFE9DFFF),
                    badgeColor: const Color(0xFF3C3489),
                    onTap: () async {
                      final s = await _pickSettings(
                          context, _rawMaps['capitals'] ?? {});
                      if (s == null || !context.mounted) return;
                      _push(QuizScreen(
                          questionCount: s.count,
                          continent: s.continent));
                    },
                  ),
                  _KategorieTile(
                    title: t('🔲 Umrisse'),
                    sub: t('Erkenne Länder'),
                    badge: t('Quiz'),
                    bg: const Color(0xFFEDF7ED),
                    titleColor: const Color(0xFF1A3D1A),
                    subColor: const Color(0xFF4A9E4A),
                    badgeBg: const Color(0xFFD4EED4),
                    badgeColor: const Color(0xFF27500A),
                    onTap: () async {
                      final s = await _pickSettings(context, {});
                      if (s == null || !context.mounted) return;
                      _push(OutlineQuizScreen(
                          questionCount: s.count,
                          continent: s.continent));
                    },
                  ),
                  _KategorieTile(
                    title: t('📈 BIP & Wirtschaft'),
                    sub: t('Zahlen & Fakten'),
                    badge: t('6 Kapitel'),
                    bg: const Color(0xFFFFF8E7),
                    titleColor: const Color(0xFF5A3D00),
                    subColor: const Color(0xFFC68A00),
                    badgeBg: const Color(0xFFFFEFC0),
                    badgeColor: const Color(0xFF633806),
                    onTap: () async {
                      final s = await _pickSettings(
                          context, _rawMaps['economy'] ?? {});
                      if (s == null || !context.mounted) return;
                      _push(GdpQuizScreen(
                          questionCount: s.count,
                          continent: s.continent));
                    },
                  ),
                  _KategorieTile(
                    title: t('💱 Währungen'),
                    sub: t('Welche Währung wohin?'),
                    badge: t('Quiz'),
                    bg: const Color(0xFFFFF0F5),
                    titleColor: const Color(0xFF6B1A3A),
                    subColor: const Color(0xFFC0185A),
                    badgeBg: const Color(0xFFFFD6E8),
                    badgeColor: const Color(0xFF72243E),
                    onTap: () => _push(const WaehrungenScreen()),
                  ),
                  _KategorieTile(
                    title: t('🏭 Wirtschaftssektoren'),
                    sub: t('Welches Land lebt wovon?'),
                    badge: t('Neu'),
                    bg: const Color(0xFFF0F4FF),
                    titleColor: const Color(0xFF1A1A6B),
                    subColor: const Color(0xFF4A4AD9),
                    badgeBg: const Color(0xFFD6D6FF),
                    badgeColor: const Color(0xFF0C0C7C),
                    onTap: () => _push(const WirtschaftssektorenScreen()),
                  ),
                ][i];
              },
            ),
            const SizedBox(height: 24),

            // ── SPIELE ────────────────────────────────────────────────────────
            Text(t('SPIELE'),
                style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _SpielCard(
              emoji: '🔀',
              title: t('Sortier-Spiel'),
              sub: t('Bringe Länder in Reihenfolge'),
              bg: const Color(0xFFEDF7ED),
              iconBg: const Color(0xFFD4EED4),
              titleColor: const Color(0xFF1A3D1A),
              onTap: () => _push(const SortierSpielScreen()),
            ),
            const SizedBox(height: 8),
            _SpielCard(
              emoji: '🎯',
              title: t('Kategorie-Match'),
              sub: t('Welches Land gewinnt welche Kategorie?'),
              bg: const Color(0xFFFFF8E7),
              iconBg: const Color(0xFFFFEFC0),
              titleColor: const Color(0xFF5A3D00),
              onTap: () => _push(const CategoryMatchScreen()),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Fortschritt-Pill ──────────────────────────────────────────────────────────

class _FortschrittPill extends StatelessWidget {
  final String value, label;
  final Color valueColor, barColor;
  final double progress;

  const _FortschrittPill({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.barColor,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAE5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kategorie-Tile ────────────────────────────────────────────────────────────

class _KategorieTile extends StatelessWidget {
  final String title, sub, badge;
  final Color bg, titleColor, subColor, badgeBg, badgeColor;
  final VoidCallback? onTap;

  const _KategorieTile({
    required this.title,
    required this.sub,
    required this.badge,
    required this.bg,
    required this.titleColor,
    required this.subColor,
    required this.badgeBg,
    required this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2)),
            const SizedBox(height: 3),
            Text(sub,
                style: TextStyle(
                    color: subColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(badge,
                  style: TextStyle(
                      color: badgeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Spiel-Card ────────────────────────────────────────────────────────────────

class _SpielCard extends StatelessWidget {
  final String emoji, title, sub;
  final Color bg, iconBg, titleColor;
  final VoidCallback onTap;

  const _SpielCard({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.bg,
    required this.iconBg,
    required this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child:
                    Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFFBBBBBB), size: 14),
          ],
        ),
      ),
    );
  }
}

// ─── Kontinent-Picker ─────────────────────────────────────────────────────────

class _ContinentPicker extends StatelessWidget {
  final Map<String, int> rawMap;
  const _ContinentPicker({required this.rawMap});

  static const _opts = [
    ('🌐', 'Alle'),
    ('🇪🇺', 'Europa'),
    ('🌎', 'Nordamerika'),
    ('🏔️', 'Südamerika'),
    ('🌏', 'Asien'),
    ('🌍', 'Afrika'),
    ('🏝️', 'Ozeanien'),
  ];

  LernenProgress _progressFor(String continent) {
    final iso2s = continent == 'Alle'
        ? countries.map((c) => c.iso2).toList()
        : countries
            .where((c) => c.region == continent)
            .map((c) => c.iso2)
            .toList();
    return StatsService.progressForIso2s(rawMap, iso2s);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D0CB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(t('Welchen Kontinent?'),
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(t('Wähle einen Bereich zum Lernen'),
                    style:
                        const TextStyle(color: Color(0xFF888888), fontSize: 13)),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 16),
              child: Column(
                children: [
                  for (final (emoji, name) in _opts) ...[
                    _ContinentOption(
                      emoji: emoji,
                      name: name,
                      count: name == 'Alle'
                          ? countries.length
                          : countries
                              .where((c) => c.region == name)
                              .length,
                      progress: _progressFor(name),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinentOption extends StatelessWidget {
  final String emoji, name;
  final int count;
  final LernenProgress progress;
  const _ContinentOption({
    required this.emoji,
    required this.name,
    required this.count,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, name),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFEAEAE5),
          borderRadius: BorderRadius.circular(14),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(t(name),
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                if (progress.hasData)
                  Text('${progress.seenCount}/$count',
                      style: const TextStyle(
                          color: Color(0xFF4A9E4A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700))
                else
                  Text(t('{n} Länder', {'n': '$count'}),
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFBBBBBB), size: 18),
              ],
            ),
            if (progress.hasData) ...[
              const SizedBox(height: 6),
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress.seenFraction,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFD0D0CB),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF9EC89E)),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress.masteredFraction,
                    minHeight: 4,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4A9E4A)),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Anzahl-Picker ────────────────────────────────────────────────────────────

class _CountPicker extends StatelessWidget {
  final int total;
  const _CountPicker({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D0CB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(t('Wie viele Länder?'),
              style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(t('Wähle den Umfang deiner Lernrunde'),
              style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          const SizedBox(height: 16),
          if (total >= 10) ...[
            _CountOption(
                label: t('{n} Länder', {'n': '10'}), sub: t('Kurze Runde'), count: 10),
            const SizedBox(height: 8),
          ],
          if (total >= 25) ...[
            _CountOption(
                label: t('{n} Länder', {'n': '25'}), sub: t('Mittlere Runde'), count: 25),
            const SizedBox(height: 8),
          ],
          _CountOption(
              label: t('Alle Länder'),
              sub: t('{n} Fragen · Vollständige Runde', {'n': '$total'}),
              count: total),
        ],
      ),
    );
  }
}

class _CountOption extends StatelessWidget {
  final String label, sub;
  final int count;
  const _CountOption(
      {required this.label, required this.sub, required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, count),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFEAEAE5),
          borderRadius: BorderRadius.circular(14),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
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
                color: Color(0xFFBBBBBB)),
          ],
        ),
      ),
    );
  }
}
