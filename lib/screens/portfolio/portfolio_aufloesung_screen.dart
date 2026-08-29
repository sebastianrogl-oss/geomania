import 'package:flutter/material.dart';
import '../../data/portfolio_daten.dart';
import '../../l10n/uebersetzungen.dart';
import '../../services/challenge_panel_signal.dart';
import '../../services/portfolio_engine.dart';
import '../../services/portfolio_service.dart';
import '../../utils/portfolio_format.dart';
import '../../widgets/challenge_ergebnis_header.dart';
import '../../widgets/challenge_fertig_button.dart';
import '../../widgets/ergebnis_karten.dart';
import '../../widgets/portfolio_land_karte.dart';
import '../../widgets/rangliste_ergebnis_karte.dart';
import '../../theme/app_theme.dart';

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
  State<PortfolioAufloesungScreen> createState() =>
      _PortfolioAufloesungScreenState();
}

class _PortfolioAufloesungScreenState extends State<PortfolioAufloesungScreen> {
  PortfolioTagesErgebnis get ergebnis => widget.ergebnis;
  PortfolioStatus get status => widget.status;

  // HIER STAND DIE AUFSTIEGS-ANIMATION.
  //
  // Beim Überschreiten einer Kapitalschwelle sprang ein Dialog samt Konfetti
  // auf ("Neuer Rang erreicht! — Sparbuch-Anfänger"), noch bevor die
  // Auflösung des Tages zu sehen war. Sie ist ersatzlos entfernt: Der
  // Auflösungs-Screen ist der Moment für das Tagesergebnis, und ein zweiter
  // Feier-Moment davor nahm ihm die Aufmerksamkeit.
  //
  // DIE RÄNGE SELBST BLEIBEN. Sie stehen weiterhin in [rangTitel] und werden
  // im Depot als Karte "Dein Rang" mit Fortschrittsbalken angezeigt
  // (portfolio_screen.dart). Entfallen ist allein die Feier beim Aufstieg;
  // [neuerRangBeiAufstieg] wird dadurch nirgends mehr gebraucht.

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
      backgroundColor: kHintergrund,
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
                    // eigenerWert bestimmt NUR die Position auf der
                    // Verteilungskurve/den Vergleich mit den Top-100-Werten
                    // (RanglisteErgebnisKarte) — die sind jetzt nach
                    // Prozent-Rendite sortiert/gespeichert, daher muss hier
                    // ebenfalls Prozent übergeben werden, auch wenn die
                    // Anzeige unverändert den Dollar-Betrag zeigt.
                    eigenerWert: tagesRenditeProzent,
                    punkteLabel: t('Tagesgewinn'),
                    farbe: const Color(0xFF4A90D9),
                    // Achsen-Beschriftung der Kurve muss zum jetzt
                    // prozentualen eigenerWert/Top-100-Vergleich passen.
                    formatWert: (w) => fmtProzent(w.toDouble()),
                    punkteAnzeige: Text(
                      fmtKapital(gewinnAbsolut, mitVorzeichen: true),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
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
            // Die Aufschlüsselung als wischbarer Kartenstapel statt als
            // Scrollliste — dieselbe Bauform wie bei den anderen drei
            // Tages-Challenges und beim Willkommens-Screen (siehe
            // ergebnis_karten.dart). Kopf, Kapital-Anzeige und Fertig-Knopf
            // bleiben, wo sie waren.
            //
            // AUFTEILUNG: erst die Länder, dann die Abrechnung (Boni und
            // Gesamtzeile). Die Abrechnung hängt sich an die letzte
            // Länderkarte, wenn dort noch Platz ist — sonst bekommt sie eine
            // eigene. Dieselbe Regel wie beim Fehler in Higher or Lower.
            Expanded(
              child: Builder(builder: (context) {
                final laender = ergebnis.beitraege;
                // Eine Länderkarte ist rund 130 hoch: Innenrand, Flaggenzeile
                // und zwei bis vier Komponentenzeilen.
                // Über dem Stapel steht hier mehr als bei den anderen drei:
                // Kapital-Anzeige UND Ranglisten-Einordnung. Deshalb 360
                // Abzug, und mindestens 1 statt 2 — eine Länderkarte je
                // Wischkarte ist hier die richtige Portionierung, kein
                // Notbehelf.
                final proKarte = wischZeilenProKarte(context,
                    zeilenHoehe: 130,
                    abzugOben: 360,
                    mindestens: 1,
                    hoechstens: 3);
                final gruppen = <List<PortfolioLandBeitrag>>[];
                for (var i = 0; i < laender.length; i += proKarte) {
                  gruppen.add(laender.sublist(
                      i,
                      i + proKarte > laender.length
                          ? laender.length
                          : i + proKarte));
                }
                // Die Abrechnung ist rund zwei Länderkarten hoch.
                const abrechnungZeilen = 2;
                final abrechnungAufLetzter = gruppen.isNotEmpty &&
                    gruppen.last.length + abrechnungZeilen <= proKarte;
                return WischKartenStapel(
                  karten: [
                    for (var g = 0; g < gruppen.length; g++)
                      (context, hoehe) => WischKarte(
                            innenrand: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                            notfallScrollen: true,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final b in gruppen[g])
                                    PortfolioLandKarte(
                                        beitrag: b, ohneRahmen: true),
                                  if (abrechnungAufLetzter &&
                                      g == gruppen.length - 1)
                                    _buildAbrechnung(positiv),
                                ],
                              ),
                          ),
                    if (!abrechnungAufLetzter)
                      (context, hoehe) => WischKarte(
                            innenrand:
                                const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            notfallScrollen: true,
                            child: _buildAbrechnung(positiv),
                          ),
                  ],
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              // Genau EIN Button statt der bisherigen "Depot ansehen"/
              // "Rangliste"-Buttons — führt zurück zum Challenge-Panel,
              // identisch zum etablierten Navigationsverhalten der anderen
              // 3 Challenges.
              child: ChallengeFertigButton(
                onTap: () => _zurueckZumDepot(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Boni und Gesamtzeile — die Abrechnung unter den Länderbeiträgen.
  ///
  /// Die Überschrift steht in derselben Form wie „Runden 1–5" bei den anderen
  /// Challenges: klein, fett, linksbündig am oberen Kartenrand. Sie sagt, was
  /// auf dieser Karte steht — ohne sie beginnt die Karte mitten in einer
  /// Rechnung.
  Widget _buildAbrechnung(bool positiv) {
    return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        t('Bonus'),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (ergebnis.kontinentsBonus > 0) ...[
                      const SizedBox(height: 4),
                      _buildBonusZeile(
                        t('Kontinents-Synergie'),
                        ergebnis.kontinentsBonus.toDouble(),
                      ),
                      const SizedBox(height: 4),
                    ],
                    // Allianz-Bonus: eigener, vom Kontinents-Bonus oben
                    // unabhängiger Mechanismus — eine Zeile pro tatsächlich
                    // erfüllter Allianz-News (mehrere können sich addieren).
                    for (final allianz in ergebnis.erfuellteAllianzen) ...[
                      const SizedBox(height: 4),
                      _buildBonusZeile(
                        t('Allianz-Bonus ({k})', {
                          'k': allianz.allianzKontinente!
                              .map(kontinentNameFuerId)
                              .join("+"),
                        }),
                        allianz.allianzBonus!,
                      ),
                      const SizedBox(height: 4),
                    ],
                    // Sektor-Kombi-Bonus: ebenfalls eigenständig, wirkt wenn
                    // tatsächlich in beide genannten Sektoren investiert wurde.
                    for (final kombo in ergebnis.erfuellteSektorKombos) ...[
                      const SizedBox(height: 4),
                      _buildBonusZeile(
                        t('Sektor-Kombi-Bonus ({s})', {
                          's': kombo.sektorKombo!
                              .map(
                                (s) => t(
                                  portfolioSektoren
                                      .firstWhere((p) => p.id == s)
                                      .name,
                                ),
                              )
                              .join("+"),
                        }),
                        kombo.sektorKomboBonus!,
                      ),
                      const SizedBox(height: 4),
                    ],
                    const Divider(height: 24),
                    _buildGesamtZeile(positiv),
                  ],
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
            tween: Tween(
              begin: ergebnis.altesKapital,
              end: ergebnis.neuesKapital,
            ),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, wert, child) => Text(
              '${fmtKapital(ergebnis.altesKapital)} → ${fmtKapital(wert)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fmtProzent(ergebnis.depotRenditeGesamt),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: positiv
                  ? const Color(0xFF4A9E4A)
                  : const Color(0xFFE53935),
            ),
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
        border: Border.all(
          color: const Color(0xFF4A9E4A).withValues(alpha: 0.4),
        ),
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
            child: Row(
              children: [
                const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF4A9E4A),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fmtProzent(wert),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4A9E4A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGesamtZeile(bool positiv) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            t('Depot-Rendite gesamt'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          fmtProzent(ergebnis.depotRenditeGesamt),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: positiv ? const Color(0xFF4A9E4A) : const Color(0xFFE53935),
          ),
        ),
      ],
    );
  }
}
