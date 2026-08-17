import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/portfolio_daten.dart';
import '../../l10n/uebersetzungen.dart';
import '../../services/challenge_panel_signal.dart';
import '../../services/portfolio_engine.dart';
import '../../services/portfolio_service.dart';
import '../../utils/portfolio_format.dart';
import '../../widgets/challenge_ergebnis_header.dart';
import '../../widgets/challenge_fertig_button.dart';
import '../../widgets/portfolio_land_karte.dart';
import '../../widgets/rangliste_ergebnis_karte.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Screen 3: Auflösung (Phase 6/7)
// ══════════════════════════════════════════════════════════════════════════════

class PortfolioAufloesungScreen extends StatefulWidget {
  final PortfolioTagesErgebnis ergebnis;
  final PortfolioStatus status;
  /// Wenn true: wird direkt aus dem Start-Screen ("Ergebnisse ansehen")
  /// geöffnet, ohne den normalen Marktbriefing/Investieren-Stack darunter —
  /// "Depot ansehen" muss dann nur diesen einen Screen schließen.
  final bool nurAnsicht;

  const PortfolioAufloesungScreen({
    super.key,
    required this.ergebnis,
    required this.status,
    this.nurAnsicht = false,
  });

  @override
  State<PortfolioAufloesungScreen> createState() => _PortfolioAufloesungScreenState();
}

class _PortfolioAufloesungScreenState extends State<PortfolioAufloesungScreen> {
  PortfolioTagesErgebnis get ergebnis => widget.ergebnis;
  PortfolioStatus get status => widget.status;

  @override
  void initState() {
    super.initState();
    final neuerTitel =
        neuerRangBeiAufstieg(ergebnis.altesKapital, ergebnis.neuesKapital);
    if (neuerTitel != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _zeigeMeilenstein(neuerTitel);
      });
    }
  }

  void _zeigeMeilenstein(String titel) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: _Konfetti())),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1A1A1A), width: 2.5),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(t('Neuer Rang erreicht!'),
                      style: const TextStyle(fontSize: 13, color: Color(0xFF888888),
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(titel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(t('Weiter'),
                          style: const TextStyle(color: Colors.white,
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

  void _zurueckZumDepot(BuildContext context) {
    // Springt IMMER direkt zurück zum Challenge-Panel (statt einer festen
    // Pop-Anzahl, die je nach Aufruf-Pfad — frisch gespielt vs. nurAnsicht —
    // unterschiedlich tief wäre und sonst leicht am falschen Screen landet).
    ChallengePanelSignal.zurueckZumPanel(context);
  }

  @override
  Widget build(BuildContext context) {
    final positiv = ergebnis.depotRenditeGesamt >= 0;
    final gewinnAbsolut = ergebnis.neuesKapital - ergebnis.altesKapital;
    final tagesRenditeProzent = ergebnis.altesKapital > 0
        ? gewinnAbsolut / ergebnis.altesKapital * 100
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Column(
          children: [
            ChallengeErgebnisHeader(titel: t('Portfolio')),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKapitalHero(positiv),
                  const SizedBox(height: 16),
                  RanglisteErgebnisKarte(
                    challengeId: 'portfolio',
                    // Sortier-/Vergleichswert der Tages-Rangliste ist die
                    // PROZENTUALE Rendite, nicht der absolute Dollar-Betrag —
                    // fair unabhängig vom eigenen Startkapital.
                    eigenerWert: tagesRenditeProzent,
                    punkteLabel: t('Tagesrendite'),
                    farbe: const Color(0xFF4A90D9),
                    formatWert: (w) => fmtProzent(w.toDouble()),
                    punkteAnzeige: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmtProzent(tagesRenditeProzent),
                          style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A)),
                        ),
                        Text(
                          '(${fmtKapital(gewinnAbsolut, mitVorzeichen: true)})',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888888)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Color(0xFFD0CEC8)),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...ergebnis.beitraege
                        .map((b) => PortfolioLandKarte(beitrag: b)),
                    if (ergebnis.kontinentsBonus > 0) ...[
                      const SizedBox(height: 4),
                      _buildBonusZeile(
                          t('Kontinents-Synergie'), ergebnis.kontinentsBonus.toDouble()),
                      const SizedBox(height: 4),
                    ],
                    // Allianz-Bonus: eigener, vom Kontinents-Bonus oben
                    // unabhängiger Mechanismus — eine Zeile pro tatsächlich
                    // erfüllter Allianz-News (mehrere können sich addieren).
                    for (final allianz in ergebnis.erfuellteAllianzen) ...[
                      const SizedBox(height: 4),
                      _buildBonusZeile(
                          t('Allianz-Bonus ({k})', {
                            'k': allianz.allianzKontinente!.map(kontinentNameFuerId).join("+")
                          }),
                          allianz.allianzBonus!),
                      const SizedBox(height: 4),
                    ],
                    // Sektor-Kombi-Bonus: ebenfalls eigenständig, wirkt wenn
                    // tatsächlich in beide genannten Sektoren investiert wurde.
                    for (final kombo in ergebnis.erfuellteSektorKombos) ...[
                      const SizedBox(height: 4),
                      _buildBonusZeile(
                          t('Sektor-Kombi-Bonus ({s})', {
                            's': kombo.sektorKombo!
                                .map((s) => portfolioSektoren.firstWhere((p) => p.id == s).name)
                                .join("+")
                          }),
                          kombo.sektorKomboBonus!),
                      const SizedBox(height: 4),
                    ],
                    const Divider(height: 24),
                    _buildGesamtZeile(positiv),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              // Genau EIN Button statt der bisherigen "Depot ansehen"/
              // "Rangliste"-Buttons — führt zurück zum Challenge-Panel,
              // identisch zum etablierten Navigationsverhalten der anderen
              // 3 Challenges.
              child: ChallengeFertigButton(
                  onTap: () => _zurueckZumDepot(context)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Kapital-Hero ──────────────────────────────────────────────────────────

  Widget _buildKapitalHero(bool positiv) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: ergebnis.altesKapital, end: ergebnis.neuesKapital),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, wert, child) => Text(
              '${fmtKapital(ergebnis.altesKapital)} → ${fmtKapital(wert)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: Colors.white70),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fmtProzent(ergebnis.depotRenditeGesamt),
            style: TextStyle(
                fontSize: 40, fontWeight: FontWeight.w900,
                color: positiv ? const Color(0xFF4A9E4A) : const Color(0xFFE53935)),
          ),
        ],
      ),
    );
  }

  // ── Länder-Aufschlüsselung ────────────────────────────────────────────────

  Widget _buildBonusZeile(String label, double wert) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4A9E4A).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Expanded + ellipsis statt fixer Row-Breite: lange Labels wie
          // "Sektor-Kombi-Bonus (Technologie+Finanzen)" liefen im Hochformat
          // auf schmalen Handybreiten rechts über den Kartenrand hinaus
          // (RenderFlex-Overflow), da die äußere Row die Prozentzahl daneben
          // nicht mehr unterbringen konnte.
          Expanded(
            child: Row(children: [
              const Icon(Icons.add_circle_outline, color: Color(0xFF4A9E4A), size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32))),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Text(fmtProzent(wert),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  color: Color(0xFF4A9E4A))),
        ],
      ),
    );
  }

  Widget _buildGesamtZeile(bool positiv) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(t('Depot-Rendite gesamt'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        Text(fmtProzent(ergebnis.depotRenditeGesamt),
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900,
                color: positiv ? const Color(0xFF4A9E4A) : const Color(0xFFE53935))),
      ],
    );
  }
}

// ── Konfetti (leichtgewichtig, ohne externe Abhängigkeit) ───────────────────

class _Konfetti extends StatefulWidget {
  const _Konfetti();

  @override
  State<_Konfetti> createState() => _KonfettiState();
}

class _KonfettiState extends State<_Konfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_KonfettiPartikel> _partikel;

  static const _farben = [
    Color(0xFF4A9E4A), Color(0xFFF9A825), Color(0xFFE53935),
    Color(0xFF4A90D9), Color(0xFF7C3AED),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward();
    final rng = Random();
    _partikel = List.generate(36, (_) => _KonfettiPartikel(
      x: rng.nextDouble(),
      startDelay: rng.nextDouble() * 0.3,
      farbe: _farben[rng.nextInt(_farben.length)],
      groesse: 6 + rng.nextDouble() * 6,
      drift: (rng.nextDouble() - 0.5) * 0.4,
      rotationSpeed: (rng.nextDouble() - 0.5) * 10,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => CustomPaint(
        size: Size.infinite,
        painter: _KonfettiPainter(_partikel, _ctrl.value),
      ),
    );
  }
}

class _KonfettiPartikel {
  final double x, startDelay, groesse, drift, rotationSpeed;
  final Color farbe;
  const _KonfettiPartikel({
    required this.x,
    required this.startDelay,
    required this.farbe,
    required this.groesse,
    required this.drift,
    required this.rotationSpeed,
  });
}

class _KonfettiPainter extends CustomPainter {
  final List<_KonfettiPartikel> partikel;
  final double t;
  _KonfettiPainter(this.partikel, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in partikel) {
      final localT = ((t - p.startDelay) / (1 - p.startDelay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final y = localT * (size.height + 40) - 20;
      final x = p.x * size.width + p.drift * size.width * localT;
      final rotation = p.rotationSpeed * localT * pi;
      final opacity = (1 - localT).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      final paint = Paint()..color = p.farbe.withValues(alpha: opacity);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.groesse, height: p.groesse * 0.6),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _KonfettiPainter oldDelegate) => true;
}
