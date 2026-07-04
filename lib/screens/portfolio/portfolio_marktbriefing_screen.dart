import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import '../../data/portfolio_daten.dart';
import '../../services/portfolio_markt_service.dart';
import '../../services/portfolio_service.dart';
import '../../utils/portfolio_format.dart';
import 'portfolio_investieren_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Screen 1: Marktbriefing (Phase 4)
// ══════════════════════════════════════════════════════════════════════════════

class PortfolioMarktbriefingScreen extends StatefulWidget {
  final PortfolioStatus status;
  const PortfolioMarktbriefingScreen({super.key, required this.status});

  @override
  State<PortfolioMarktbriefingScreen> createState() =>
      _PortfolioMarktbriefingScreenState();
}

class _PortfolioMarktbriefingScreenState
    extends State<PortfolioMarktbriefingScreen> {
  late final TagesMarkt _markt = ladeTagesMarkt();

  void _weiterZumInvestieren() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PortfolioInvestierenScreen(
          status: widget.status,
          markt: _markt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKlima(),
                    const SizedBox(height: 12),
                    _buildTrendBanner(),
                    const SizedBox(height: 20),
                    const Text('HEUTIGE MARKTNACHRICHTEN',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: Color(0xFF888888), letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    ..._markt.news.map(_buildNewsKarte),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GestureDetector(
                onTap: _weiterZumInvestieren,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Text('Investieren →',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAE5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Color(0xFF1A1A1A), size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💼 Marktbriefing',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A))),
                Text('Kapital: ${fmtKapital(widget.status.kapital)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Markt-Klima ───────────────────────────────────────────────────────────

  Widget _buildKlima() {
    final bull = _markt.bullish;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bull ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: bull ? const Color(0xFF4A9E4A) : const Color(0xFFE53935),
            width: 1.5),
      ),
      child: Row(
        children: [
          Text(bull ? '🐂' : '🐻', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text(
            bull ? 'Märkte optimistisch heute' : 'Märkte angespannt heute',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: bull ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
          ),
        ],
      ),
    );
  }

  // ── Makro-Trend-Banner ────────────────────────────────────────────────────

  Widget _buildTrendBanner() {
    final trend = widget.status.trend;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📈 Makro-Trend: ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                      color: Colors.white)),
              Expanded(
                child: Text(trend.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                        color: Color(0xFFF9A825))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tag ${widget.status.trendTag} von ${trend.dauerTage} — ${trend.beschreibung}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ── Nachrichten-Karte ─────────────────────────────────────────────────────

  Widget _buildNewsKarte(MarktNews n) {
    final sektor = portfolioSektoren.firstWhere((s) => s.id == n.sektor);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(sektor.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(n.titel,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAE5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(sektor.name,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(n.klartext,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF555555), height: 1.4)),
          if (n.gewinner.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildLaenderZeile('↑ Profitiert', n.gewinner, const Color(0xFF4A9E4A)),
          ],
          if (n.verlierer.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildLaenderZeile('↓ Verliert', n.verlierer, const Color(0xFFE53935)),
          ],
        ],
      ),
    );
  }

  Widget _buildLaenderZeile(String label, List<String> isos, Color farbe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: farbe)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 5, runSpacing: 4,
          children: isos.map((iso) => ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: CountryFlag.fromCountryCode(iso, width: 28, height: 19),
          )).toList(),
        ),
      ],
    );
  }
}
