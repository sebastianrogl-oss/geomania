import 'package:flutter/material.dart';
import '../services/rangliste_service.dart';
import '../utils/portfolio_format.dart';

enum _Challenge { schaetzen, higherlower, ranking, portfolio }

extension _ChallengeX on _Challenge {
  String get id => switch (this) {
        _Challenge.schaetzen => 'schaetzen',
        _Challenge.higherlower => 'higherlower',
        _Challenge.ranking => 'ranking',
        _Challenge.portfolio => 'portfolio',
      };

  String get label => switch (this) {
        _Challenge.schaetzen => 'Schätzen',
        _Challenge.higherlower => 'Higher/Lower',
        _Challenge.ranking => 'Ranking',
        _Challenge.portfolio => 'Portfolio',
      };
}

class RanglisteScreen extends StatefulWidget {
  const RanglisteScreen({super.key});

  @override
  State<RanglisteScreen> createState() => _RanglisteScreenState();
}

class _RanglisteScreenState extends State<RanglisteScreen> {
  _Challenge _challenge = _Challenge.schaetzen;
  int _portfolioSubTab = 0; // 0 = Heute, 1 = Gesamt (Alltime)
  late Future<List<RanglistenEintrag>> _future;

  @override
  void initState() {
    super.initState();
    _future = _ladeAktuelle();
  }

  Future<List<RanglistenEintrag>> _ladeAktuelle() {
    if (_challenge == _Challenge.portfolio && _portfolioSubTab == 1) {
      return RanglisteService.ladePortfolioAlltime();
    }
    return RanglisteService.ladeTagesRangliste(_challenge.id);
  }

  void _wechsleChallenge(_Challenge c) {
    if (_challenge == c) return;
    setState(() {
      _challenge = c;
      _future = _ladeAktuelle();
    });
  }

  void _wechslePortfolioSubTab(int i) {
    if (_portfolioSubTab == i) return;
    setState(() {
      _portfolioSubTab = i;
      _future = _ladeAktuelle();
    });
  }

  Future<void> _refresh() async {
    final neu = _ladeAktuelle();
    setState(() => _future = neu);
    await neu;
  }

  bool get _istGeld => _challenge == _Challenge.portfolio;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0E8),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rangliste',
                      style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Wer ist der beste Geo-Profi?',
                      style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final c in _Challenge.values) ...[
                          _ChallengePill(
                            label: c.label,
                            active: _challenge == c,
                            onTap: () => _wechsleChallenge(c),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  if (_challenge == _Challenge.portfolio) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _SubTabPill(
                          label: 'Heute',
                          active: _portfolioSubTab == 0,
                          onTap: () => _wechslePortfolioSubTab(0),
                        ),
                        const SizedBox(width: 8),
                        _SubTabPill(
                          label: 'Gesamt',
                          active: _portfolioSubTab == 1,
                          onTap: () => _wechslePortfolioSubTab(1),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF4A9E4A),
                onRefresh: _refresh,
                child: FutureBuilder<List<RanglistenEintrag>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 100),
                          Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF4A9E4A),
                            ),
                          ),
                        ],
                      );
                    }
                    final liste = snap.data ?? [];
                    if (liste.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        children: const [_LeererZustand()],
                      );
                    }
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: liste.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _RangZeile(eintrag: liste[i], istGeld: _istGeld),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Challenge-Umschalter ─────────────────────────────────────────────────────

class _ChallengePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ChallengePill(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4A9E4A) : const Color(0xFFEAEAE5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: active ? Colors.white : const Color(0xFF888888),
              fontSize: 13,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SubTabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SubTabPill(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1A1A1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFCCCCC5)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: active ? Colors.white : const Color(0xFF888888),
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── Ranglisten-Zeile ─────────────────────────────────────────────────────────

class _RangZeile extends StatelessWidget {
  final RanglistenEintrag eintrag;
  final bool istGeld;

  const _RangZeile({required this.eintrag, required this.istGeld});

  Color? get _rangFarbe => switch (eintrag.rang) {
        1 => const Color(0xFFF9A825),
        2 => const Color(0xFFB0BEC5),
        3 => const Color(0xFFA1887F),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final hervorgehoben = eintrag.istIch;
    final rangFarbe = _rangFarbe;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: hervorgehoben ? const Color(0xFFF0F8F0) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hervorgehoben
              ? const Color(0xFF4A9E4A)
              : const Color(0xFF1A1A1A),
          width: hervorgehoben ? 2.0 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF1a1a1a),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${eintrag.rang}',
              style: TextStyle(
                fontSize: eintrag.rang == 1 ? 17 : 14,
                fontWeight: FontWeight.w900,
                color: rangFarbe ?? const Color(0xFF1A1A1A),
              ),
            ),
          ),
          Expanded(
            child: Text(
              eintrag.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Text(
            istGeld ? fmtKapital(eintrag.wert.toDouble()) : '${eintrag.wert}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leerzustand ───────────────────────────────────────────────────────────────

class _LeererZustand extends StatelessWidget {
  const _LeererZustand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAE5),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: const Column(
        children: [
          Text('🏆', style: TextStyle(fontSize: 28)),
          SizedBox(height: 12),
          Text(
            'Noch keine Einträge heute — sei der Erste!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.4),
          ),
        ],
      ),
    );
  }
}
