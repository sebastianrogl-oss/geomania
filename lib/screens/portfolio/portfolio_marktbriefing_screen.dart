import 'package:flutter/material.dart';
import '../../data/portfolio_daten.dart';
import '../../l10n/uebersetzungen.dart';
import '../../services/challenge_panel_signal.dart';
import '../../services/daily_resume_service.dart';
import '../../services/portfolio_markt_service.dart';
import '../../services/portfolio_service.dart';
import '../../utils/portfolio_format.dart';
import '../../widgets/portfolio_flagge.dart';
import '../../widgets/spiel_erklaerung.dart';
import 'portfolio_investieren_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Screen 1: Marktbriefing (Phase 4)
// ══════════════════════════════════════════════════════════════════════════════

const _kPortfolioId = 'portfolio';

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

  @override
  void initState() {
    super.initState();
    // Phase 1 sofort merken — deckt auch den Fall ab, dass die App
    // geschlossen wird, während die News hier noch gelesen werden.
    DailyResumeService.speichern(_kPortfolioId, {'phase': 1});
  }

  void _weiterZumInvestieren() {
    DailyResumeService.speichern(_kPortfolioId, {'phase': 2});
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
    // Phasen 1-3 (Marktbriefing, Länderauswahl, Gewichtung) sind ein
    // durchgehender Spiel-Flow ohne Rückwärts-Navigation — weder Wisch-
    // zurück noch Android-/Browser-Zurück-Button dürfen eine Phase
    // zurückspringen. Einziger Ausstieg ist der Auflösungs-Screen am Ende.
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                      _buildSektorDesTages(),
                      const SizedBox(height: 20),
                      Text(t('HEUTIGE MARKTNACHRICHTEN'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: Color(0xFF888888), letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      ..._markt.news.asMap().entries.map((e) =>
                          _GestaffelteKarte(
                              index: e.key, child: _buildNewsKarte(e.value))),
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
                    child: Text(t('Investieren →'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    // Zurück-Pfeil führt IMMER direkt zum Challenge-Panel/Menü (nicht zur
    // vorherigen Phase) — die PopScope-Sperre gegen Wisch-/Hardware-Zurück
    // zwischen den Phasen bleibt davon unberührt bestehen.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Marktbriefing'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A))),
                Text(t('Kapital: {v}', {'v': fmtKapital(widget.status.kapital)}),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
              ],
            ),
          ),
          ErklaerungButton(
            titel: t('Portfolio des Tages — Spielregeln'),
            farbe: const Color(0xFF4A90D9),
            abschnitte: [
              t('Lies zuerst das Marktbriefing: hier stehen die heutigen Markt-Nachrichten und der Sektor-Trend des Tages — sie beeinflussen, welche Länder und Sektoren heute gut abschneiden.'),
              t('Wähle danach 3 Länder aus 16 zur Auswahl für dein Depot.'),
              t('Verteile dein Kapital prozentual auf die 3 gewählten Länder (Gewichtung) — mehr Gewicht auf ein Land bedeutet mehr Einfluss auf dein Ergebnis, aber auch mehr Risiko.'),
              t('In der Auflösung siehst du die tatsächliche Tagesrendite jedes Landes sowie mögliche Bonus-Erträge (z.B. Kontinents-Synergie, Allianz-Bonus, Sektor-Kombi-Bonus), wenn deine Auswahl dazu passt.'),
              t('Ziel: dein Kapital von Tag zu Tag durch geschickte Länderauswahl vermehren.'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sektor-Trend heute ────────────────────────────────────────────────────
  // Zeigt den tatsächlich im Rendite-Modell wirksamen Makro-Trend (siehe
  // trendEffekt() in portfolio_rendite_service.dart) statt einer davon
  // unabhängigen, rein aus den 3 News abgeleiteten Anzeige — Banner und
  // Spielmechanik stimmen so überein. Trend wird täglich neu gezogen, daher
  // kein "Tag X von Y"-Zähler mehr.

  Widget _buildSektorDesTages() {
    final trend = widget.status.trend;
    final sektor = portfolioSektoren.firstWhere((s) => s.id == trend.sektor);
    final farbe = portfolioSektorFarben[trend.sektor] ?? const Color(0xFF888888);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: farbe.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: farbe, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sektor.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            // Flexible statt fixer Größe: "mainAxisSize: min" allein
            // verhindert keinen Overflow, wenn der Text auf einem schmalen
            // Handyscreen breiter wäre als der verfügbare Platz — Flexible
            // lässt den Text notfalls auf die verbleibende Breite schrumpfen
            // (mit Ellipsis) statt über den Rand der Pille hinauszulaufen.
            Flexible(
              child: Text(
                t('Tagessektor: {s} (+{n}%)', {
                  's': t(sektor.name),
                  'n': trend.staerke.toStringAsFixed(1),
                }),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: sektorFarbeDunkel(trend.sektor)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nachrichten-Karte ─────────────────────────────────────────────────────

  // Gemeinsame Karten-Hülle (Optik) für alle Typen — der Inhalt selbst
  // verzweigt: einzelLand bekommt eine eigene, prominentere Anordnung
  // (großes Flaggen+Name/Bonus-Layout), alle anderen Typen teilen sich den
  // generischen Aufbau (Kopfzeile + Titel + Klartext + Typ-Info + Flaggen).
  Widget _buildNewsKarte(MarktNews n) {
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
      child: n.typ == NewsTyp.einzelLand
          ? _buildEinzelLandInhalt(n)
          : _buildGenerischerInhalt(n),
    );
  }

  Widget _buildGenerischerInhalt(MarktNews n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNewsKopfzeile(n),
        const SizedBox(height: 8),
        Text(t(n.titel),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A))),
        const SizedBox(height: 4),
        Text(t(n.klartext),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF888888), height: 1.4)),
        const SizedBox(height: 6),
        if (n.typ == NewsTyp.kontinentsAllianz)
          _buildAllianzInfo(n)
        else if (n.typ == NewsTyp.sektorKombination)
          _buildSektorKomboInfo(n)
        else if (n.typ == NewsTyp.extremEreignis)
          _buildBandbreiteInfo(n)
        else
          _buildSektorInfo(n),
        if (n.gewinner.isNotEmpty || n.verlierer.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            runSpacing: 6,
            children: [
              ...n.gewinner.map((iso) => _flaggeMitPfeil(iso, hoch: true)),
              ...n.verlierer.map((iso) => _flaggeMitPfeil(iso, hoch: false)),
            ],
          ),
        ],
      ],
    );
  }

  // einzelLand: große Flagge + Titel/Landname oben, Klartext darunter, Bonus-
  // Prozent unten deutlich sichtbar mit Trend-Icon — klarere Hierarchie als
  // die generische Karte, da hier immer nur EIN Land im Fokus steht.
  Widget _buildEinzelLandInhalt(MarktNews n) {
    final iso = n.gewinner.isNotEmpty ? n.gewinner.first : n.verlierer.first;
    final positiv = (n.staerke ?? 0) > 0;
    final impactFarbe =
        positiv ? const Color(0xFF4A9E4A) : const Color(0xFFE53935);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNewsKopfzeile(n),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PortfolioFlagge(iso: iso, width: 56, height: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t(n.titel),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 2),
                  Text(landName(iso),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: Color(0xFF888888))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(t(n.klartext),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(positiv ? Icons.trending_up : Icons.trending_down,
                color: impactFarbe, size: 18),
            const SizedBox(width: 4),
            Text(
              '${positiv ? "+" : ""}${n.staerke!.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 15, color: impactFarbe),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewsKopfzeile(MarktNews n) {
    // einzelLand zeigt seinen Bonus jetzt prominent unten (siehe
    // _buildEinzelLandInhalt) statt zusätzlich hier oben.
    final zeigtStaerke = n.typ == NewsTyp.standard;
    final positiv = (n.staerke ?? 0) > 0;
    final impactFarbe =
        positiv ? const Color(0xFF4A9E4A) : const Color(0xFFE53935);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAE5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(t('MARKT-NEWS'),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                  color: Color(0xFF888888), letterSpacing: 0.8)),
        ),
        if (istGrossereignisNews(n)) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF9A825).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(t('⚡ Großereignis'),
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                    color: Color(0xFFB4750E), letterSpacing: 0.3)),
          ),
        ],
        const Spacer(),
        if (zeigtStaerke) ...[
          Icon(positiv ? Icons.trending_up : Icons.trending_down,
              color: impactFarbe, size: 18),
          const SizedBox(width: 3),
          Text(
            '${positiv ? "+" : "-"}${(n.staerke ?? 0).abs().toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                color: impactFarbe),
          ),
        ],
      ],
    );
  }

  // standard: immer gesetzt. einzelLand: bewusst OHNE Sektor-Zuordnung (genau
  // EIN Land statt eines Sektor-Clusters) -> zeigt nichts, die Flagge unten
  // reicht als Info.
  Widget _buildSektorInfo(MarktNews n) {
    if (n.sektor == null) return const SizedBox.shrink();
    final positiv = (n.staerke ?? 0) > 0;
    final sektor = portfolioSektoren.firstWhere((s) => s.id == n.sektor);
    final impactFarbe =
        positiv ? const Color(0xFF4A9E4A) : const Color(0xFFE53935);
    return Text(
      t('{status}: {emoji} {sektor}', {
        'status': positiv ? t('Profitiert') : t('Betroffen'),
        'emoji': sektor.emoji,
        'sektor': t(sektor.name),
      }),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: impactFarbe),
    );
  }

  // kontinentsAllianz: kein Gewinn/Verlust für einzelne Länder — wirkt nur
  // als Portfolio-Bonus, wenn mind. 1 Land aus JEDEM genannten Kontinent
  // gewählt ist (siehe berechneAllianzBonus). Badges nutzen exakt dieselbe
  // Kontinent-Farbzuordnung (kontinentFarbeFuerId, portfolio_daten.dart) wie
  // die Kontinent-Badges auf den Länderkarten — eine gemeinsame Quelle.
  Widget _buildAllianzInfo(MarktNews n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: n.allianzKontinente!.map((k) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kontinentFarbeFuerId(k),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(kontinentNameFuerId(k),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              )).toList(),
        ),
        const SizedBox(height: 6),
        Text(t('+{n}% Bonus', {'n': n.allianzBonus!.toStringAsFixed(1)}),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                color: Color(0xFF4A9E4A))),
      ],
    );
  }

  // sektorKombination: kein Gewinn/Verlust für einzelne Länder — wirkt nur
  // als Portfolio-Bonus, wenn tatsächlich in BEIDE genannten Sektoren
  // investiert wurde (siehe berechneSektorKomboBonus). Badges nutzen exakt
  // dieselbe Sektor-Farbe/-Emoji-Quelle (portfolioSektoren/portfolioSektorFarben,
  // portfolio_daten.dart) wie die Sektor-Chips auf den Länderkarten.
  Widget _buildSektorKomboInfo(MarktNews n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: n.sektorKombo!.map((s) {
            final sektor = portfolioSektoren.firstWhere((p) => p.id == s);
            final farbe = portfolioSektorFarben[s] ?? const Color(0xFF888888);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: farbe.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: farbe, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sektor.emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(t(sektor.name),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: farbe)),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(t('+{n}% Bonus', {'n': n.sektorKomboBonus!.toStringAsFixed(1)}),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900,
                color: Color(0xFF4A9E4A))),
      ],
    );
  }

  // extremEreignis: lila statt grün/rot, da die Richtung ungewiss ist — zeigt
  // die vorab bekannte Bandbreite, NICHT den tatsächlichen (verborgenen,
  // seed-basierten) Wert, der erst im Auflösungs-Screen sichtbar wird.
  Widget _buildBandbreiteInfo(MarktNews n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 14, color: Color(0xFF7C3AED)),
              const SizedBox(width: 4),
              Text(
                t('{min}% bis {max}%', {
                  'min': n.bandbreiteMin!.toStringAsFixed(0),
                  'max': n.bandbreiteMax!.toStringAsFixed(0),
                }),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: Color(0xFF7C3AED)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(t('Ungewisse Auswirkung'),
            style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic,
                color: Color(0xFF888888))),
      ],
    );
  }

  Widget _flaggeMitPfeil(String iso, {required bool hoch}) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PortfolioFlagge(iso: iso, width: 32, height: 22, radius: 4),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: hoch ? const Color(0xFF4A9E4A) : const Color(0xFFE53935),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Icon(hoch ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 8, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// Lässt jede Nachrichtenkarte gestaffelt (150ms Verzögerung pro Index) mit
// Slide-in von unten + Fade-in erscheinen, statt alle gleichzeitig statisch.
class _GestaffelteKarte extends StatefulWidget {
  final int index;
  final Widget child;
  const _GestaffelteKarte({required this.index, required this.child});

  @override
  State<_GestaffelteKarte> createState() => _GestaffelteKarteState();
}

class _GestaffelteKarteState extends State<_GestaffelteKarte> {
  bool _sichtbar = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 150), () {
      if (mounted) setState(() => _sichtbar = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _sichtbar ? Offset.zero : const Offset(0, 0.15),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _sichtbar ? 1 : 0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
