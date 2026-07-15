import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/uebersetzungen.dart';
import '../services/daily_challenge.dart';
import '../services/fortschritt_service.dart';
import 'preis_schaetzen_screen.dart';
import 'higher_lower_screen.dart';
import 'ranking_game_screen.dart';
import 'portfolio_screen.dart';

// ── Challenge-Definitionen ────────────────────────────────────────────────────

class _ChallengeInfo {
  final String id, title, sub, emoji;
  final Color bg, iconBg, titleColor, subColor;
  const _ChallengeInfo({
    required this.id,
    required this.title,
    required this.sub,
    required this.emoji,
    required this.bg,
    required this.iconBg,
    required this.titleColor,
    required this.subColor,
  });
}

const _challenges = [
  _ChallengeInfo(
    id: 'preis',
    title: 'Das große Schätzen',
    sub: 'Schätze wirtschaftliche Kennzahlen',
    emoji: '🏷️',
    bg: Color(0xFFFFF8E7),
    iconBg: Color(0xFFFFEFC0),
    titleColor: Color(0xFF5A3D00),
    subColor: Color(0xFFC68A00),
  ),
  _ChallengeInfo(
    id: 'higher_lower',
    title: 'Higher or Lower',
    sub: 'Höher oder niedriger?',
    emoji: '⬆️',
    bg: Color(0xFFEDF7ED),
    iconBg: Color(0xFFD4EED4),
    titleColor: Color(0xFF1A3D1A),
    subColor: Color(0xFF4A9E4A),
  ),
  _ChallengeInfo(
    id: 'ranking_game',
    title: 'Ranking-Spiel',
    sub: 'Welches Land führt die Kategorie an?',
    emoji: '🏅',
    bg: Color(0xFFF3EEFF),
    iconBg: Color(0xFFE9DFFF),
    titleColor: Color(0xFF3B1A6B),
    subColor: Color(0xFF7C3AED),
  ),
  _ChallengeInfo(
    id: 'portfolio',
    title: 'Portfolio des Tages',
    sub: 'Verteile dein Budget klug auf Länder',
    emoji: '💼',
    bg: Color(0xFFEBF3FF),
    iconBg: Color(0xFFD6E8FF),
    titleColor: Color(0xFF1A3A6B),
    subColor: Color(0xFF4A90D9),
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  Set<String> _done = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    FortschrittService.resetSignal.addListener(_load);
  }

  @override
  void dispose() {
    _timer?.cancel();
    FortschrittService.resetSignal.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final done = await DailyChallenge.completedToday();
    if (mounted) setState(() => _done = done);
  }

  String _countdown() {
    final d = DailyChallenge.untilMidnight();
    return t('Reset in {h}h {m}m', {'h': '${d.inHours}', 'm': '${d.inMinutes % 60}'});
  }

  Future<void> _start(String id) async {
    await DailyChallenge.markDone(id);
    if (!mounted) return;
    setState(() => _done = {..._done, id});

    Widget screen;
    switch (id) {
      case 'preis':        screen = const PreisSchaetzenScreen(); break;
      case 'higher_lower': screen = const HigherLowerScreen(); break;
      case 'ranking_game': screen = const RankingGameScreen(); break;
      case 'portfolio':    screen = const PortfolioScreen(); break;
      default: return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _challenges.where((c) => _done.contains(c.id)).length;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1B3A2D),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(
                children: [
                  const Text('⚡',
                      style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t('Tägliche Challenges'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ),
                  Text(
                    _countdown(),
                    style: const TextStyle(
                        color: Color(0xFF8BC8A0),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          // ── Status-Bar ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1B3A2D),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  Text(
                    t('{n}/4 heute erledigt', {'n': '$doneCount'}),
                    style: const TextStyle(
                        color: Color(0xFFA8D5A2),
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: doneCount / 4.0,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4A9E4A)),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Challenge Karten (2×2 Schachbrett-Grid) ──────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ChallengeKarte(
                  info: _challenges[i],
                  isDone: _done.contains(_challenges[i].id),
                  onTap: () => _start(_challenges[i].id),
                ),
                childCount: _challenges.length,
              ),
            ),
          ),

          // ── Alle-spielen Button ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverToBoxAdapter(
              child: doneCount < 4
                  ? GestureDetector(
                      onTap: () {
                        final naechste = _challenges.firstWhere(
                          (c) => !_done.contains(c.id),
                          orElse: () => _challenges.first,
                        );
                        _start(naechste.id);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A9E4A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          t('Alle spielen →'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAEAE5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        t('🎉 Alle Challenges erledigt!'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFF4A9E4A),
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Challenge-Karte ───────────────────────────────────────────────────────────

class _ChallengeKarte extends StatelessWidget {
  final _ChallengeInfo info;
  final bool isDone;
  final VoidCallback onTap;

  const _ChallengeKarte({
    required this.info,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: info.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.06),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo – groß, kein Hintergrund
            Text(info.emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 10),

            // Titel
            Text(
              t(info.title),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDone ? const Color(0xFF888888) : info.titleColor,
              ),
            ),
            const SizedBox(height: 6),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF4A9E4A).withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isDone ? t('Erledigt ✅') : t('Spielen →'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDone ? const Color(0xFF4A9E4A) : info.titleColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
