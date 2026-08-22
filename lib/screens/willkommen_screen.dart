import 'package:flutter/material.dart';

import '../l10n/uebersetzungen.dart';
import '../theme/app_theme.dart';
import '../widgets/maskottchen_animation.dart';

// ── Maße ─────────────────────────────────────────────────────────────────────
//
// Leitgröße ist die Bildschirmhöhe: Coiny und die Abstände leiten sich daraus
// ab, damit der Screen auf einem kleinen Telefon nicht scrollen muss und auf
// einem Tablet nicht verloren wirkt.
const double _kCoinyAnteil = 0.17; // × Bildschirmhöhe
const double _kCoinyMin = 96;
const double _kCoinyMax = 170;
const double _kSeitenrand = 28;

const _textDark = Color(0xFF1A1A1A);
const _textMid = Color(0xFF888888);
const _accent = Color(0xFF4A9E4A);

/// Der einzige Erklär-Screen der App, gezeigt nach der Namensabfrage und vor
/// dem ersten Blick auf den Lernpfad.
///
/// Bewusst EIN Screen und keine mehrseitige Tour: eine Tour wischt man weg,
/// ohne sie zu lesen, und wer sie doch liest, hat drei Seiten später wieder
/// vergessen, was auf der ersten stand. Die Einzelheiten stehen ohnehin dort,
/// wo man sie braucht — die Kurzanleitung im Start-Sheet jeder Station, die
/// ausführliche Anleitung beim ersten Vorkommen der vier Modi mit eigener
/// Bedienung, und die Kennzahlen hinter einem Tipp auf den Kopfbereich.
///
/// Deshalb steht hier nur, was man vorher wissen muss, um überhaupt
/// anzufangen.
class WillkommenScreen extends StatelessWidget {
  final VoidCallback onFertig;

  const WillkommenScreen({super.key, required this.onFertig});

  @override
  Widget build(BuildContext context) {
    final hoehe = MediaQuery.of(context).size.height;
    final coiny = (hoehe * _kCoinyAnteil).clamp(_kCoinyMin, _kCoinyMax);

    return Scaffold(
      backgroundColor: kHintergrund,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  _kSeitenrand, 16, _kSeitenrand, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: MaskottchenAnimation(groesse: coiny)),
                    const SizedBox(height: 18),
                    Text(
                      t('Schön, dass du da bist!'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('Kurz, worum es geht:'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textMid,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Punkt(
                      symbol: '🌍',
                      titel: t('Die Welt kennenlernen'),
                      text: t('Flaggen, Hauptstädte, Umrisse, Währungen und '
                          'noch einiges mehr — immer spielerisch, nie als '
                          'Vokabelliste.'),
                    ),
                    _Punkt(
                      symbol: '🗺️',
                      titel: t('Station für Station'),
                      text: t('Der Lernpfad führt dich durch die Kontinente. '
                          'Jede Station ist eine kurze Runde in einer anderen '
                          'Spielart — die nächste wartet, sobald du fertig '
                          'bist.'),
                    ),
                    _Punkt(
                      symbol: '⭐',
                      titel: t('Sterne sammeln'),
                      text: t('Jede Frage, die du zum ersten Mal richtig hast, '
                          'gibt einen Stern. Damit schaltest du später neue '
                          'Profilbilder frei.'),
                    ),
                    _Punkt(
                      symbol: '🔥',
                      titel: t('Serie halten'),
                      text: t('Spiel jeden Tag eine Station, dann wächst deine '
                          'Serie. Tippe oben auf die Flamme oder den Stern, '
                          'wenn du mehr wissen willst.'),
                      letzter: true,
                    ),
                    const SizedBox(height: 26),
                    _LosGehtsButton(onTap: onFertig),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Ein Punkt der Aufzählung: Symbol links, Titel und Text rechts.
class _Punkt extends StatelessWidget {
  final String symbol;
  final String titel;
  final String text;
  final bool letzter;

  const _Punkt({
    required this.symbol,
    required this.titel,
    required this.text,
    this.letzter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: letzter ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(symbol,
                style: const TextStyle(fontSize: 22), textAlign: TextAlign.center),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textMid,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hauptaktion im 3D-Muster der App (vgl. challenge_fertig_button.dart und
/// erinnerung_dialog.dart).
class _LosGehtsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LosGehtsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _textDark, width: 2.5),
          boxShadow: const [
            BoxShadow(color: _textDark, offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Text(
          t('Los geht\'s'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
