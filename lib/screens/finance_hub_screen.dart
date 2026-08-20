import 'package:flutter/material.dart';
import '../data/finance_facts.dart';
import '../data/connections_puzzles.dart';
import '../l10n/uebersetzungen.dart';
import 'higher_lower_screen.dart';
import 'category_match_screen.dart';
import 'ranking_quiz_screen.dart';
import 'currency_quiz_screen.dart';
import 'economic_blocks_screen.dart';
import 'finance_connections_screen.dart';
import '../theme/app_theme.dart';

class FinanceHubScreen extends StatelessWidget {
  const FinanceHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todayFact = financeFacts[DateTime.now().difference(DateTime(2024)).inDays % financeFacts.length];
    final puzzleIdx = DateTime.now().difference(DateTime(2024)).inDays % connectionsPuzzles.length;
    final puzzle = connectionsPuzzles[puzzleIdx];

    return Scaffold(
      backgroundColor: kHintergrund,
      appBar: AppBar(
        backgroundColor: kHintergrund,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t('Finanzen & Wirtschaft'),
            style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800, fontSize: 17)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header banner ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF9A825), Color(0xFFFFCA28)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('Wirtschaftswissen'), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                    const SizedBox(height: 6),
                    Text(t('Teste dein Wissen\nüber Finanzen & Wirtschaft'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.35)),
                  ]),
                ),
                const Text('📈', style: TextStyle(fontSize: 48)),
              ]),
            ),
            const SizedBox(height: 28),

            // ── Schnellspiele ───────────────────────────────────────────────
            Text(t('SCHNELLSPIELE'),
                style: const TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            _GameCard(
              emoji: '⬆️⬇️',
              title: 'Higher or Lower',
              sub: t('Ist der Wert höher oder niedriger?'),
              bgColor: const Color(0xFFE3F2FD),
              titleColor: const Color(0xFF1565C0),
              subColor: const Color(0xFF1976D2),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HigherLowerScreen())),
            ),
            const SizedBox(height: 10),
            _GameCard(
              emoji: '🎯',
              title: t('Kategorie-Match'),
              sub: t('Welches Land gewinnt welche Kategorie?'),
              bgColor: const Color(0xFFE0F7FA),
              titleColor: const Color(0xFF006064),
              subColor: const Color(0xFF00838F),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryMatchScreen())),
            ),
            const SizedBox(height: 10),
            _GameCard(
              emoji: '🏅',
              title: t('Ranking-Quiz'),
              sub: t('Länder nach BIP, Fläche & mehr sortieren'),
              bgColor: const Color(0xFFFCE4EC),
              titleColor: const Color(0xFF880E4F),
              subColor: const Color(0xFFAD1457),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RankingQuizScreen())),
            ),
            const SizedBox(height: 28),

            // ── Neue Spiele ─────────────────────────────────────────────────
            Row(children: [
              Text(t('NEUE SPIELE'),
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9A825),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                child: Text(t('NEU'), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 10),

            // Currency Quiz
            _GameCard(
              emoji: '💱',
              title: t('Währungs-Quiz'),
              sub: t('Welche Währung hat dieses Land?'),
              bgColor: const Color(0xFFFFF8E7),
              titleColor: const Color(0xFFF57F17),
              subColor: const Color(0xFFFFA726),
              badge: t('10 Sek. Timer'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CurrencyQuizScreen())),
            ),
            const SizedBox(height: 10),

            // Economic Blocks
            _GameCard(
              emoji: '🤝',
              title: t('Wirtschaftsblöcke'),
              sub: 'EU · G7 · G20 · OPEC · BRICS · ASEAN',
              bgColor: const Color(0xFFE8F4FF),
              titleColor: const Color(0xFF1565C0),
              subColor: const Color(0xFF1976D2),
              badge: t('10 Fragen'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EconomicBlocksScreen())),
            ),
            const SizedBox(height: 10),

            // Connections
            _ConnectionsCard(puzzle: puzzle,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceConnectionsScreen()))),
            const SizedBox(height: 28),

            // ── Wusstest du? ────────────────────────────────────────────────
            Text(t('WUSSTEST DU?'),
                style: const TextStyle(color: Color(0xFF999999), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF4A9E4A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                const Text('💡', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(t(todayFact),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.45)),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(t('Täglich neuer Fakt'),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable game card ────────────────────────────────────────────────────────
class _GameCard extends StatelessWidget {
  final String emoji, title, sub;
  final Color bgColor, titleColor, subColor;
  final String? badge;
  final VoidCallback onTap;

  const _GameCard({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.bgColor,
    required this.titleColor,
    required this.subColor,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w800)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: titleColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5)),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    child: Text(badge!, style: TextStyle(color: titleColor, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: subColor, size: 14),
        ]),
      ),
    );
  }
}

// ── Connections preview card ──────────────────────────────────────────────────
class _ConnectionsCard extends StatelessWidget {
  final ConnectionsPuzzle puzzle;
  final VoidCallback onTap;
  const _ConnectionsCard({required this.puzzle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🔗', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('Connections – Finanz Edition'),
                    style: const TextStyle(color: Color(0xFF7B5800), fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(t('Finde die 4 Gruppen à 4 Länder'),
                    style: const TextStyle(color: Color(0xFFF9A825), fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFF9A825), size: 14),
          ]),
          const SizedBox(height: 12),
          // Color preview stripes
          Row(children: puzzle.groups.map((g) => Expanded(
            child: Container(
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: g.color, borderRadius: BorderRadius.circular(4)),
            ),
          )).toList()),
          const SizedBox(height: 8),
          Text(t('Heutiges Rätsel: "{title}"', {'title': t(puzzle.title)}),
              style: const TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
