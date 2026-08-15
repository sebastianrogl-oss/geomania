import 'package:flutter/material.dart';
import '../data/portfolio_daten.dart';
import '../l10n/uebersetzungen.dart';
import '../services/portfolio_engine.dart';
import '../utils/portfolio_format.dart';
import '../widgets/flaggen_widget.dart' show zeigeFlagge;
import '../widgets/portfolio_land_karte.dart';

// ══════════════════════════════════════════════════════════════════════════════
// WELTPORTFOLIO — Onboarding-Beispiel ("So funktioniert's")
// Statischer Screen mit hartkodierten Beispieldaten — Begriffe/Formeln folgen
// exakt portfolio_engine.dart / portfolio_aufloesung_screen.dart.
// ══════════════════════════════════════════════════════════════════════════════

// ── Beispieldaten: Stil A — "Der Sichere" ───────────────────────────────────
const _stilASicher = [
  PortfolioLandBeitrag(
    iso: 'DE', anteilProzent: 40,
    basis: 1.2, news: -1.8, newsNamen: ['Lieferkette'],
    trend: 2.0, schwankung: -0.4,
    tagesRendite: 1.0, beitragProzent: 0.40,
  ),
  PortfolioLandBeitrag(
    iso: 'US', anteilProzent: 35,
    basis: 1.5, news: 2.0, newsNamen: ['Zinsen'],
    trend: 2.0, schwankung: 0.3,
    tagesRendite: 5.8, beitragProzent: 2.03,
  ),
  PortfolioLandBeitrag(
    iso: 'JP', anteilProzent: 25,
    basis: 0.9, news: 0.0, newsNamen: [],
    trend: 2.0, schwankung: -0.6,
    tagesRendite: 2.3, beitragProzent: 0.58,
  ),
];

// ── Beispieldaten: Stil B — "Der Jäger" ──────────────────────────────────────
const _stilBJaeger = [
  PortfolioLandBeitrag(
    iso: 'IN', anteilProzent: 50,
    basis: 2.2, news: 2.0, newsNamen: ['Zinsen'],
    trend: 2.0, schwankung: 3.1,
    tagesRendite: 9.3, beitragProzent: 4.65,
  ),
  PortfolioLandBeitrag(
    iso: 'BR', anteilProzent: 30,
    basis: 1.8, news: 1.6, newsNamen: ['Ernte'],
    trend: 0.0, schwankung: -4.2,
    tagesRendite: -0.8, beitragProzent: -0.24,
  ),
  PortfolioLandBeitrag(
    iso: 'VN', anteilProzent: 20,
    basis: 2.5, news: -1.8, newsNamen: ['Lieferkette'],
    trend: 0.0, schwankung: 2.7,
    tagesRendite: 3.4, beitragProzent: 0.68,
  ),
];

const _kSicherGesamt = 0.40 + 2.03 + 0.58; // 3.01
const _kJaegerGesamt = 4.65 - 0.24 + 0.68; // 5.09

class PortfolioBeispielScreen extends StatelessWidget {
  const PortfolioBeispielScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A9E4A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(t("So funktioniert's"),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _abschnitt1DasPrinzip(),
                    const SizedBox(height: 28),
                    _sectionTitle(t('EIN TAG IM BEISPIEL')),
                    const SizedBox(height: 10),
                    _trendBanner(),
                    const SizedBox(height: 12),
                    _newsKarte(
                      titel: t('Notenbank senkt Zinsen'),
                      klartext: t('Billiges Geld beflügelt Wachstumsmärkte.'),
                      flaggen: const ['IN', 'BR', 'ID'],
                      positiv: true,
                    ),
                    _newsKarte(
                      titel: t('Lieferketten-Störung in Asien'),
                      klartext: t('Produktion stockt kurzfristig.'),
                      flaggen: const ['CN', 'VN', 'DE'],
                      positiv: false,
                    ),
                    _newsKarte(
                      titel: t('Rekord-Ernte in Südamerika'),
                      klartext: t('Agrar-Exporteure verdienen mit.'),
                      flaggen: const ['BR', 'AR'],
                      positiv: true,
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle(t('ZWEI WEGE — BEIDE GÜLTIG')),
                    const SizedBox(height: 4),
                    Text(
                      t('Es gibt kein Richtig oder Falsch — nur unterschiedlichen '
                      'Umgang mit Risiko.'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                    ),
                    const SizedBox(height: 12),
                    _stilKarte(
                      emoji: '🛡️',
                      titel: t('Der Sichere'),
                      borderColor: const Color(0xFF1565C0),
                      beitraege: _stilASicher,
                      risikoLabel: t('niedrig'), risikoEmoji: '🟢',
                      risikoFarbe: const Color(0xFF4A9E4A),
                      tagGesamt: _kSicherGesamt,
                      kapitalAlt: 1000, kapitalNeu: 1030,
                      fazit: t('Ruhig und stetig — kleine Schwankungen, kaum '
                          'Verlusttage.'),
                    ),
                    _stilKarte(
                      emoji: '🦅',
                      titel: t('Der Jäger'),
                      borderColor: const Color(0xFFF9A825),
                      beitraege: _stilBJaeger,
                      risikoLabel: t('hoch'), risikoEmoji: '🔴',
                      risikoFarbe: const Color(0xFFE53935),
                      tagGesamt: _kJaegerGesamt,
                      kapitalAlt: 1000, kapitalNeu: 1051,
                      fazit: t('Große Sprünge — heute top, morgen vielleicht '
                          'Verlust. Der Jäger lebt mit der Schwankung.'),
                    ),
                    const SizedBox(height: 16),
                    _abschnitt4Lehre(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A9E4A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1A1A1A), width: 2.5),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4)),
                    ],
                  ),
                  child: Text(t("Los geht's →"),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Abschnitt 1 — Das Prinzip ────────────────────────────────────────────

  Widget _abschnitt1DasPrinzip() {
    return _karte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Dein Depot'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          Text(
            t('Du startest mit 1.000 \$ und vermehrst dein Kapital Tag für Tag. '
            'Jeden Tag EIN Investment-Zug — dein Kapital bleibt gespeichert und '
            'wächst weiter. Je klüger du investierst, desto schneller steigt '
            'dein Vermögen.'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.5),
          ),
          const SizedBox(height: 14),
          const Text('1.000 \$ → 1.087 \$ → 1.152 \$ → …',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: Color(0xFF4A9E4A))),
        ],
      ),
    );
  }

  // ── Abschnitt 2 — Trend-Banner + News ────────────────────────────────────

  Widget _trendBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF9A825), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t('📈 Makro-Trend: '),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A))),
              Expanded(
                child: Text(t('KI-Revolution'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                        color: Color(0xFFC68A00))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(t('Tag 3 von 7 — Technologie profitiert mehrere Tage lang'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A5C00))),
          const SizedBox(height: 8),
          Text(
            t('Trends laufen über mehrere Tage. Wer früh dabei ist und dranbleibt '
            'sammelt Vorteil.'),
            style: const TextStyle(fontSize: 11, color: Color(0xFF8A7000),
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _newsKarte({
    required String titel,
    required String klartext,
    required List<String> flaggen,
    required bool positiv,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titel,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(klartext,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                const SizedBox(height: 8),
                Row(
                  children: flaggen.map((iso) => Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: zeigeFlagge(iso, width: 24, height: 16, borderRadius: 3),
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(positiv ? '↑' : '↓',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                  color: positiv ? const Color(0xFF4A9E4A) : const Color(0xFFE53935))),
        ],
      ),
    );
  }

  // ── Abschnitt 3 — Zwei Spielweisen ───────────────────────────────────────

  Widget _stilKarte({
    required String emoji,
    required String titel,
    required Color borderColor,
    required List<PortfolioLandBeitrag> beitraege,
    required String risikoLabel,
    required String risikoEmoji,
    required Color risikoFarbe,
    required double tagGesamt,
    required double kapitalAlt,
    required double kapitalNeu,
    required String fazit,
  }) {
    final positiv = tagGesamt >= 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(titel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A))),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12, runSpacing: 6,
            children: beitraege.map((b) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                zeigeFlagge(b.iso, width: 22, height: 15, borderRadius: 3),
                const SizedBox(width: 5),
                Text('${landName(b.iso)} ${b.anteilProzent}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            )).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(risikoEmoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(t('Depot-Risiko: {label}', {'label': risikoLabel}),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: risikoFarbe)),
            ],
          ),
          const SizedBox(height: 14),
          ...beitraege.map((b) => PortfolioLandKarte(beitrag: b)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(t('Kontinents-Bonus: keiner (verschiedene Kontinente)'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t('Tag gesamt'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              Text(fmtProzent(tagGesamt),
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900,
                      color: positiv
                          ? const Color(0xFF4A9E4A)
                          : const Color(0xFFE53935))),
            ],
          ),
          Text('${fmtKapital(kapitalAlt)} → ${fmtKapital(kapitalNeu)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(fazit,
                style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A),
                    fontStyle: FontStyle.italic, height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ── Abschnitt 4 — Die wichtige Lehre ─────────────────────────────────────

  Widget _abschnitt4Lehre() {
    return _karte(
      bg: const Color(0xFFE8F5E9),
      border: const Color(0xFF4A9E4A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Es gibt keine perfekte Wahl'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 10),
          Text(
            t('Jedes Land hat eine erwartete Rendite — aber auch eine zufällige '
            'Tagesschwankung 🎲, die du VORHER nicht siehst. Länder mit hohem '
            'Risiko schlagen stärker aus: mal nach oben, mal nach unten.\n\n'
            'Im Beispiel hat Brasilien trotz guter News einen schlechten '
            'Zufallstag erwischt (🎲 −4,2%) und Verlust gemacht. Das konnte '
            'niemand vorhersehen.\n\n'
            'Dein Skill ist NICHT die eine richtige Antwort zu finden — sondern:\n'
            '• die Nachrichten & den Trend clever zu nutzen (Erwartungswert erhöhen)\n'
            '• dein Risiko bewusst zu steuern (breit streuen = ruhiger, '
            'konzentrieren = riskanter)\n\n'
            'Finde deinen eigenen Stil. Nach ein paar Tagen zeigt dir das Spiel '
            'welcher Investor-Typ du bist.'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A), height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14, runSpacing: 8,
            children: [
              Text(t('🛡️ Der Sichere'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(t('🦅 Der Jäger'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(t('🎯 Der Spezialist'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(t('🎰 Der Zocker'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Widget _sectionTitle(String t) {
    return Text(t,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: Color(0xFF888888), letterSpacing: 1.2));
  }

  Widget _karte({
    required Widget child,
    Color bg = Colors.white,
    Color border = const Color(0xFF1A1A1A),
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: child,
    );
  }
}
