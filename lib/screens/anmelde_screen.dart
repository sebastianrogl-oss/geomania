import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../l10n/uebersetzungen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/maskottchen_animation.dart';
import '../widgets/sprach_umschalter.dart';

// ── Anmeldung ────────────────────────────────────────────────────────────────
//
// Der allererste Bildschirm. Es gibt bewusst KEINEN Gast-Modus: Fortschritt,
// Rangliste und der reservierte Anzeigename hängen alle an einer Konto-ID, und
// ein Gast hätte davon nichts, was einen Gerätewechsel überlebt.
//
// Der Sprachumschalter steht hier wie auf der Namensauswahl: Beide Schritte
// gehören zum ersten Start, und wer die Sprache erst nach dem Anmelden ändern
// will, soll dafür nicht in die Einstellungen müssen.

/// Höhe, die oben für den Sprachumschalter freigehalten wird.
const double _kUmschalterPlatz = 56;

class AnmeldeScreen extends StatefulWidget {
  final VoidCallback onAngemeldet;
  const AnmeldeScreen({super.key, required this.onAngemeldet});

  @override
  State<AnmeldeScreen> createState() => _AnmeldeScreenState();
}

class _AnmeldeScreenState extends State<AnmeldeScreen> {
  bool _laeuft = false;
  String? _fehler;

  Future<void> _versuche(Future<AnmeldeErgebnis> Function() anmeldung) async {
    if (_laeuft) return;
    setState(() {
      _laeuft = true;
      _fehler = null;
    });
    final ergebnis = await anmeldung();
    if (!mounted) return;
    switch (ergebnis) {
      case AnmeldeErgebnis.erfolgreich:
        // Das spieler-Dokument sofort anlegen, damit ein Abbruch VOR der
        // Namensauswahl kein Konto ohne Gegenstück in der Datenbank
        // hinterlässt.
        await AuthService.spielerAnlegen();
        if (mounted) widget.onAngemeldet();
        return;
      case AnmeldeErgebnis.abgebrochen:
        // Kein Fehler — wer den Dialog wegwischt, steht einfach wieder hier.
        setState(() => _laeuft = false);
        return;
      case AnmeldeErgebnis.nichtEingerichtet:
        setState(() {
          _laeuft = false;
          _fehler = t('Die Anmeldung ist noch nicht eingerichtet. '
              'Bitte versuch es später noch einmal.');
        });
        return;
      case AnmeldeErgebnis.fehler:
        setState(() {
          _laeuft = false;
          _fehler = t('Die Anmeldung hat nicht geklappt — '
              'bitte versuch es erneut.');
        });
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHintergrund,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: _kUmschalterPlatz),
                        const MaskottchenAnimation(groesse: 180),
                        const SizedBox(height: 20),
                        Text(
                          t('Willkommen bei GeoMania!'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1a1a1a),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t('Melde dich an, damit dein Fortschritt und dein '
                              'Platz in der Rangliste erhalten bleiben.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF888888),
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_laeuft)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(
                                color: Color(0xFF4A9E4A)),
                          )
                        else ...[
                          _AnmeldeKnopf(
                            symbol: 'G',
                            symbolFarbe: const Color(0xFF4285F4),
                            text: t('Mit Google anmelden'),
                            onTap: () =>
                                _versuche(AuthService.mitGoogleAnmelden),
                          ),
                          if (AuthService.appleVerfuegbar) ...[
                            const SizedBox(height: 12),
                            _AnmeldeKnopf(
                              symbol: '',
                              symbolFarbe: const Color(0xFF1A1A1A),
                              text: t('Mit Apple anmelden'),
                              onTap: () =>
                                  _versuche(AuthService.mitAppleAnmelden),
                            ),
                          ],
                          // Nur im Debug-Build: eine echte, anonyme
                          // Firebase-Anmeldung. Sie liefert eine vollwertige
                          // uid, danach läuft alles ganz normal weiter.
                          if (kDebugMode) ...[
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () => _versuche(AuthService.testAnmeldung),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 8),
                                child: Text(
                                  t('Test-Anmeldung (Debug)'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB8570A),
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0xFFB8570A),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                        if (_fehler != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _fehler!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFFCC0000)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  top: 0,
                  right: 24,
                  child: SprachUmschalter(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Anmelde-Knopf im 3D-Muster der App, aber weiss statt farbig: die Marke des
/// Anbieters soll die Zeile tragen, nicht die Knopffarbe.
class _AnmeldeKnopf extends StatelessWidget {
  final String symbol;
  final Color symbolFarbe;
  final String text;
  final VoidCallback onTap;

  const _AnmeldeKnopf({
    required this.symbol,
    required this.symbolFarbe,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: const Color(0xFF1A1A1A), width: 2.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              child: Text(
                symbol,
                textAlign: TextAlign.center,
                // Ohne Skalierung: das Markenzeichen soll neben dem Text
                // stehen, nicht ihn verdrängen.
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: symbolFarbe,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
