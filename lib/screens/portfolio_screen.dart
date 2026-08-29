import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/portfolio_daten.dart';
import '../l10n/uebersetzungen.dart';
import '../services/challenge_panel_signal.dart';
import '../services/daily_challenge.dart';
import '../services/daily_resume_service.dart';
import '../services/portfolio_markt_service.dart';
import '../services/portfolio_service.dart';
import '../utils/portfolio_format.dart';
import 'portfolio/portfolio_investieren_screen.dart';
import 'portfolio/portfolio_marktbriefing_screen.dart';
import 'portfolio_beispiel_screen.dart';
import '../theme/app_theme.dart';

const _kPortfolioId = 'portfolio';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Depot-Überblick (Startscreen des Spiels, Phase 3)
// ══════════════════════════════════════════════════════════════════════════════

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  PortfolioStatus? _status;
  Timer? _minutentakt;
  late final AnimationController _pulsCtrl;

  @override
  void initState() {
    super.initState();
    _pulsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _lade();
    _minutentakt = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minutentakt?.cancel();
    _pulsCtrl.dispose();
    super.dispose();
  }

  Future<void> _lade() async {
    final status = await PortfolioService.ladeStatus();
    if (!mounted) return;

    // Zwischenstand einer abgebrochenen Runde von HEUTE? -> direkt an der
    // gespeicherten Phase fortsetzen statt neu zu starten (siehe
    // DailyResumeService: der Schlüssel ist bereits tagesgebunden, ein
    // Zwischenstand vom Vortag wird dadurch automatisch nie gefunden).
    if (!status.heuteGespielt) {
      final zwischenstand = await DailyResumeService.laden(_kPortfolioId);
      final phase = zwischenstand?['phase'] as int?;
      if (phase != null && mounted) {
        if (phase >= 2) {
          final laender = ((zwischenstand?['laender'] as List<dynamic>?) ?? [])
              .map((e) => e as String)
              .toList();
          final gewichtungRoh =
              (zwischenstand?['gewichtung'] as Map<String, dynamic>?) ?? {};
          final gewichtung =
              gewichtungRoh.map((k, v) => MapEntry(k, (v as num).toInt()));
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PortfolioInvestierenScreen(
                status: status,
                markt: ladeTagesMarkt(),
                resumeLaender: laender,
                resumeGewichtung: gewichtung,
              ),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PortfolioMarktbriefingScreen(status: status),
            ),
          );
        }
        _lade();
        return;
      }
    }

    setState(() => _status = status);
  }

  Future<void> _starteInvestitionstag() async {
    final status = _status;
    if (status == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PortfolioMarktbriefingScreen(status: status),
      ),
    );
    _lade();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      backgroundColor: kHintergrund,
      body: status == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4A9E4A)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildKapitalHero(status),
                    const SizedBox(height: 16),
                    _buildRangKarte(status),
                    const SizedBox(height: 16),
                    _buildVerlaufsKarte(status),
                    const SizedBox(height: 24),
                    _buildCta(status),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          // ChallengePanelSignal statt einfachem Navigator.pop, damit man
          // konsistent zur Tages-Challenges-Übersicht zurückkehrt (mit
          // geöffnetem Panel), nicht nur zur "leeren" Hauptseite dahinter.
          onTap: () => ChallengePanelSignal.zurueckZumPanel(context),
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
          // Ohne Emoji: Die übrigen Challenge-Kopfzeilen tragen auch keins,
          // und der Aktenkoffer stand als einziges buntes Zeichen in einer
          // sonst ruhigen Leiste.
          child: Text(t('Weltportfolio'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A))),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PortfolioBeispielScreen(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Kapital-Hero ──────────────────────────────────────────────────────────

  Widget _buildKapitalHero(PortfolioStatus status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(t('DEIN KAPITAL'),
              style: const TextStyle(fontSize: 11, color: Colors.white54,
                  fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: status.kapital),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, wert, child) => Text(
              fmtKapital(wert),
              style: const TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
          ),
          // Die Rekord-Marke stand hier neben der Serie und ist raus: Wer bei
          // 1000 $ startet, las dort "Rekord: 1000 $" — den eigenen
          // Startbetrag als Bestleistung. Aussagekraft bekommt sie erst weit
          // später, und bis dahin verdoppelt sie nur die Zahl darüber.
          if (status.streak > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                  t('🔥 {n} Tage in Folge', {'n': '${status.streak}'}),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Rang-Titel ────────────────────────────────────────────────────────────

  Widget _buildRangKarte(PortfolioStatus status) {
    final rang = rangFuerKapital(status.kapital);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('Dein Rang'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888888),
                      fontWeight: FontWeight.w600)),
              if (rang.naechsteSchwelle != null)
                Text(
                    t('Noch {v}',
                        {'v': fmtKapital(rang.naechsteSchwelle! - status.kapital)}),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
            ],
          ),
          const SizedBox(height: 4),
          Text(t(rang.titel),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rang.fortschritt,
              minHeight: 10,
              backgroundColor: const Color(0xFFEAEAE5),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4A9E4A)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Verlaufskurve ─────────────────────────────────────────────────────────

  Widget _buildVerlaufsKarte(PortfolioStatus status) {
    final werte = status.verlauf.length > 14
        ? status.verlauf.sublist(status.verlauf.length - 14)
        : status.verlauf;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAE5)),
        boxShadow: const [
          BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('VERLAUF (14 TAGE)'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Color(0xFF888888), letterSpacing: 1.2)),
          const SizedBox(height: 10),
          if (werte.length < 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                t('Noch keine Historie — spiele deinen ersten Tag!'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
            )
          else
            SizedBox(
              height: 90,
              width: double.infinity,
              child: CustomPaint(painter: _VerlaufsPainter(werte)),
            ),
        ],
      ),
    );
  }

  // ── Call to Action ────────────────────────────────────────────────────────

  Widget _buildCta(PortfolioStatus status) {
    if (status.heuteGespielt) {
      final restzeit = DailyChallenge.untilMidnight();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4A9E4A), width: 1.5),
        ),
        child: Column(
          children: [
            Text(t('Heute erledigt ✓'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D32))),
            const SizedBox(height: 4),
            Text(
              t('Morgen geht\'s weiter — neue News in {h}h {m}m', {
                'h': '${restzeit.inHours}',
                'm': '${restzeit.inMinutes % 60}',
              }),
              style: const TextStyle(fontSize: 12, color: Color(0xFF4A9E4A)),
            ),
          ],
        ),
      );
    }

    return ScaleTransition(
      scale: Tween(begin: 0.97, end: 1.03).animate(
        CurvedAnimation(parent: _pulsCtrl, curve: Curves.easeInOut),
      ),
      child: GestureDetector(
        onTap: _starteInvestitionstag,
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
          child: Text(t('Heute investieren →'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

// ── Verlaufs-Chart (einfacher Linien-Chart) ─────────────────────────────────

class _VerlaufsPainter extends CustomPainter {
  final List<double> werte;
  _VerlaufsPainter(this.werte);

  @override
  void paint(Canvas canvas, Size size) {
    final minV = werte.reduce(min);
    final maxV = werte.reduce(max);
    final spanne = (maxV - minV).abs() < 0.01 ? 1.0 : maxV - minV;
    final steigend = werte.last >= werte.first;
    final farbe = steigend ? const Color(0xFF4A9E4A) : const Color(0xFFE53935);

    final linie = Path();
    for (int i = 0; i < werte.length; i++) {
      final x = size.width * i / (werte.length - 1);
      final y = size.height - ((werte[i] - minV) / spanne) * size.height;
      if (i == 0) {
        linie.moveTo(x, y);
      } else {
        linie.lineTo(x, y);
      }
    }

    final flaeche = Path.from(linie)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(flaeche, Paint()..color = farbe.withValues(alpha: 0.12));
    canvas.drawPath(
      linie,
      Paint()
        ..color = farbe
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _VerlaufsPainter oldDelegate) =>
      oldDelegate.werte != werte;
}
