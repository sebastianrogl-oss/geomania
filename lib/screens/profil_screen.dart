import 'package:flutter/material.dart';
import '../services/daily_challenge.dart';
import '../services/fortschritt_service.dart';
import '../services/portfolio_service.dart';
import '../services/portfolio_spielstil_service.dart';
import '../services/stats_service.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Set<String> _done = {};
  Map<String, LernenProgress> _lernen = {};
  int _streak = 0;
  int _totalChallenges = 0;
  SpielstilErgebnis? _spielstil;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await DailyChallenge.completedToday();
    final lernen = await StatsService.allLernenProgress();
    final streak = await StatsService.getStreak();
    final daily = await StatsService.allDailyStats();
    final spielstilDaten = await PortfolioService.ladeSpielstilRohdaten();
    if (mounted) {
      setState(() {
        _done = done;
        _lernen = lernen;
        _streak = streak;
        _totalChallenges =
            daily.values.fold(0, (s, v) => s + v.completions);
        _spielstil = berechneSpielstil(spielstilDaten);
      });
    }
  }

  int get _totalSeen =>
      _lernen.values.fold(0, (s, v) => s + v.seenCount);

  void _openModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfilModal(streak: _streak),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Profil',
                    style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings_rounded,
                        color: Color(0xFF888888), size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Avatar + Name ────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _openModal,
                    child: Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAEAE5),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF4A9E4A), width: 3),
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: Color(0xFF4A9E4A), size: 32),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A9E4A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Sebastian',
                      style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  const Text('Geo-Anfänger 🌍',
                      style: TextStyle(
                          color: Color(0xFF4A9E4A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('$_streak Tage Streak',
                          style: const TextStyle(
                              color: Color(0xFFF9A825),
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Statistiken ──────────────────────────────────────────────────
            Row(
              children: [
                _StatCard(
                    value: '$_totalChallenges',
                    label: 'Challenges',
                    valueColor: const Color(0xFF4A9E4A)),
                const SizedBox(width: 8),
                _StatCard(
                    value: '$_totalSeen',
                    label: 'Stationen',
                    valueColor: const Color(0xFF1A1A1A)),
                const SizedBox(width: 8),
                const _StatCard(
                    value: '0',
                    label: 'Abzeichen',
                    valueColor: Color(0xFFF9A825)),
              ],
            ),
            const SizedBox(height: 24),

            // ── HEUTE ────────────────────────────────────────────────────────
            const Text('HEUTE',
                style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _ChallengeRow(
              emoji: '🏷️',
              title: 'Das große Schätzen',
              bg: const Color(0xFFFFF8E7),
              iconBg: const Color(0xFFFFEFC0),
              titleColor: const Color(0xFF5A3D00),
              done: _done.contains('preis'),
            ),
            const SizedBox(height: 8),
            _ChallengeRow(
              emoji: '⬆️',
              title: 'Higher or Lower',
              bg: const Color(0xFFEDF7ED),
              iconBg: const Color(0xFFD4EED4),
              titleColor: const Color(0xFF1A3D1A),
              done: _done.contains('higher_lower'),
            ),
            const SizedBox(height: 8),
            _ChallengeRow(
              emoji: '🏅',
              title: 'Ranking-Quiz',
              bg: const Color(0xFFF3EEFF),
              iconBg: const Color(0xFFE9DFFF),
              titleColor: const Color(0xFF3B1A6B),
              done: _done.contains('ranking'),
            ),
            const SizedBox(height: 8),
            _ChallengeRow(
              emoji: '💼',
              title: 'Portfolio des Tages',
              bg: const Color(0xFFEBF3FF),
              iconBg: const Color(0xFFD6E8FF),
              titleColor: const Color(0xFF1A3A6B),
              done: _done.contains('portfolio'),
            ),
            const SizedBox(height: 24),

            // ── SPIELSTIL (Weltportfolio) ────────────────────────────────────
            if (_spielstil != null) ...[
              const Text('DEIN INVESTOR-STIL',
                  style: TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
                  ],
                ),
                child: Row(
                  children: [
                    Text(_spielstil!.emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Dein Stil',
                              style: TextStyle(fontSize: 11, color: Color(0xFF888888),
                                  fontWeight: FontWeight.w600)),
                          Text(_spielstil!.titel,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A1A))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── LERN-FORTSCHRITT ─────────────────────────────────────────────
            const Text('LERN-FORTSCHRITT',
                style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            const SizedBox(height: 10),
            _ProgressRow(
              emoji: '🏳️',
              label: 'Flaggen',
              barColor: const Color(0xFF4A90D9),
              fraction: (_lernen['flags'] ?? LernenProgress.empty())
                  .seenFraction,
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              emoji: '🏛️',
              label: 'Hauptstädte',
              barColor: const Color(0xFF7C3AED),
              fraction: (_lernen['capitals'] ?? LernenProgress.empty())
                  .seenFraction,
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              emoji: '🔲',
              label: 'Umrisse',
              barColor: const Color(0xFF4A9E4A),
              fraction: 0.0,
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              emoji: '📈',
              label: 'BIP & Wirtschaft',
              barColor: const Color(0xFFF9A825),
              fraction: (_lernen['economy'] ?? LernenProgress.empty())
                  .seenFraction,
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              emoji: '💱',
              label: 'Währungen',
              barColor: const Color(0xFFC0185A),
              fraction: 0.0,
            ),
            const SizedBox(height: 8),
            _ProgressRow(
              emoji: '🏭',
              label: 'Wirtschaftssektoren',
              barColor: const Color(0xFF4A4AD9),
              fraction: 0.0,
            ),
            const SizedBox(height: 32),

            // ── Reset ────────────────────────────────────────────────────────
            GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Fortschritt zurücksetzen?'),
                    content: const Text(
                        'Alle Stationen, Punkte und Statistiken werden gelöscht. Das kann nicht rückgängig gemacht werden.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Abbrechen'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Zurücksetzen',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FortschrittService.allesDatenZuruecksetzen();
                  if (mounted) _load();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCCCC), width: 1.5),
                ),
                child: const Text(
                  'Fortschritt zurücksetzen',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFCC0000),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Test-Modus: alles freischalten ──────────────────────────────
            GestureDetector(
              onTap: () async {
                await FortschrittService.allesFreischalten();
                if (!mounted) return;
                _load();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('🔓 Alle Abschnitte & Stationen freigeschaltet'),
                  backgroundColor: Color(0xFF4A9E4A),
                ));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC5DDFF), width: 1.5),
                ),
                child: const Column(
                  children: [
                    Text(
                      '🔓 Alles freischalten (Test-Modus)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1565C0),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Alle Stationen sofort spiel- & wiederholbar, kein echter Fortschritt',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B93C4), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Profil Modal ──────────────────────────────────────────────────────────────

class _ProfilModal extends StatelessWidget {
  final int streak;
  const _ProfilModal({required this.streak});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: screenH * 0.62,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Griff
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0CEC8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Avatar + Name
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAE5),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF4A9E4A), width: 3),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Color(0xFF4A9E4A), size: 38),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Sebastian',
                  style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              const Icon(Icons.edit_rounded,
                  color: Color(0xFF4A9E4A), size: 16),
            ],
          ),
          const SizedBox(height: 3),
          const Text('Mitglied seit Juni 2025',
              style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),

          // Divider
          const Divider(
              color: Color(0xFFE0E0DB), thickness: 1, height: 1),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gesamtpunkte: 0',
                    style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                const Text('ABZEICHEN',
                    style: TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(
                    3,
                    (_) => Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAEAE5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Divider
          const Divider(
              color: Color(0xFFE0E0DB), thickness: 1, height: 1),

          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 14, 24, bottomPad + 12),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAEAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Einstellungen',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFFE53935), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Abmelden',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFFE53935),
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat-Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value, label;
  final Color valueColor;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEAEAE5),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Challenge-Row ─────────────────────────────────────────────────────────────

class _ChallengeRow extends StatelessWidget {
  final String emoji, title;
  final Color bg, iconBg, titleColor;
  final bool done;

  const _ChallengeRow({
    required this.emoji,
    required this.title,
    required this.bg,
    required this.iconBg,
    required this.titleColor,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
          if (done)
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4A9E4A), size: 20)
          else
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFCCCCCC),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Progress-Row ──────────────────────────────────────────────────────────────

class _ProgressRow extends StatelessWidget {
  final String emoji, label;
  final Color barColor;
  final double fraction;

  const _ProgressRow({
    required this.emoji,
    required this.label,
    required this.barColor,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (fraction * 100).round();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAE5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 4,
                backgroundColor: const Color(0xFFD8D6D0),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 30,
            child: Text('$pct%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
