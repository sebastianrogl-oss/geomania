import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/uebersetzungen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradnetz.dart';
import '../widgets/wortmarke.dart';
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

  /// Der Rohtext des letzten Fehlschlags — 'apple/notHandled',
  /// 'firebase/invalid-credential' und dergleichen.
  ///
  /// Er steht klein und grau unter der freundlichen Meldung. Der Spieler
  /// braucht ihn nicht; wer einen Fehlerbericht schreibt, braucht ausser ihm
  /// nichts. Ohne diesen Text bedeutet "noch nicht eingerichtet" gleichzeitig
  /// "Entitlement fehlt", "Profil ist zu alt", "Anbieter nicht freigeschaltet"
  /// und "Client-ID passt nicht" — vier Ursachen, ein Satz, kein Anhaltspunkt.
  String? _befund;

  Future<void> _versuche(Future<AnmeldeAusgang> Function() anmeldung) async {
    if (_laeuft) return;
    setState(() {
      _laeuft = true;
      _fehler = null;
      _befund = null;
    });
    final ausgang = await anmeldung();
    final ergebnis = ausgang.ergebnis;
    // Der Erfolgsfall steht bewusst VOR der mounted-Prüfung: Sobald die
    // Anmeldung durch ist, meldet authStateChanges das dem StartWrapper, der
    // tauscht diesen Screen sofort aus — und dieses State-Objekt ist bereits
    // abgeräumt, wenn wir hier ankommen. Hinter einem `if (!mounted) return;`
    // wurde spielerAnlegen() deshalb nie erreicht, und das Konto blieb ohne
    // Gegenstück in der Datenbank zurück.
    if (ergebnis == AnmeldeErgebnis.erfolgreich) {
      // Das spieler-Dokument sofort anlegen, damit ein Abbruch VOR der
      // Namensauswahl kein Konto ohne Gegenstück in der Datenbank
      // hinterlässt.
      await AuthService.spielerAnlegen();
      if (mounted) widget.onAngemeldet();
      return;
    }
    if (!mounted) return;
    switch (ergebnis) {
      case AnmeldeErgebnis.erfolgreich:
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
          _befund = ausgang.befund;
        });
        return;
      case AnmeldeErgebnis.fehler:
        setState(() {
          _laeuft = false;
          _fehler = t('Die Anmeldung hat nicht geklappt — '
              'bitte versuch es erneut.');
          _befund = ausgang.befund;
        });
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHintergrund,
      body: GradnetzHintergrund(
        schritt: 0,
        child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              // Wie beim Stack in GradnetzHintergrund: ohne fit bemisst sich
              // der Stack an seinem einzigen nicht positionierten Kind, dem
              // Scrollbereich — und der schrumpft auf seine Inhaltsbreite.
              // Der Sprachumschalter daneben ist Positioned und zählt nicht
              // mit. Beide Stacks brauchen das fit; das äussere allein reicht
              // nicht, dann bleibt zwar die Hintergrundfläche breit, der
              // Inhalt sitzt aber trotzdem in einem schmalen, linksbündigen
              // Kasten.
              fit: StackFit.expand,
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
                        const Wortmarke(),
                        const SizedBox(height: 14),
                        Text(
                          t('Erkunde die Welt, Land für Land.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF888888),
                          ),
                        ),
                        const SizedBox(height: 36),
                        if (_laeuft)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(
                                color: Color(0xFF4A9E4A)),
                          )
                        else ...[
                          _GoogleKnopf(
                            onTap: () =>
                                _versuche(AuthService.mitGoogleAnmelden),
                          ),
                          // Nur auf Apple-Plattformen — und dann samt seinem
                          // Abstand. Beides steht bewusst INNERHALB derselben
                          // Bedingung: Läge der SizedBox davor, bliebe auf
                          // Android eine 12 px hohe Lücke unter dem
                          // Google-Knopf stehen, wo nichts ist.
                          //
                          // Ein ausgegrauter Apple-Knopf auf Android wäre die
                          // Alternative gewesen. Er verwirrt aber mehr, als er
                          // hilft: Anmelden kann man sich damit dort ohnehin
                          // nie.
                          if (AuthService.appleVerfuegbar) ...[
                            const SizedBox(height: 12),
                            _AppleKnopf(
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
                        // Auswählbar, damit sich der Text auf dem Gerät
                        // markieren und weiterschicken lässt. Ein Fehlercode,
                        // den man abtippen muss, kommt falsch an oder gar
                        // nicht.
                        if (_befund != null) ...[
                          const SizedBox(height: 6),
                          SelectableText(
                            _befund!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: Color(0xFF888888),
                            ),
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
      ),
    );
  }
}

// ── Anbieter-Knöpfe ──────────────────────────────────────────────────────────
//
// Getrennte Klassen statt eines gemeinsamen Knopfes mit Parametern: Google und
// Apple geben für ihre Anmeldeknöpfe je eigene, verbindliche Gestaltungsregeln
// vor. Ein Bauteil, das beide bedient, endet zwangsläufig bei einem Kompromiss,
// der keine der beiden Vorgaben erfüllt.

/// Maße nach Googles Vorgaben für "Sign in with Google".
///
/// Weisser Grund, graue Umrandung, Logo links, ein Textabstand von 12 zum Logo
/// und 12 zum Rand. Das Logo misst 18 dp im Quadrat.
const _kGoogleHoehe = 48.0;
const _kGoogleLogo = 18.0;
const _kGoogleRand = Color(0xFF747775);
const _kGoogleText = Color(0xFF1F1F1F);
const _kGoogleRadius = 12.0;

/// "Mit Google anmelden" nach den offiziellen Vorgaben.
///
/// Bewusst NICHT im 3D-Muster der übrigen App: Google verlangt für diesen Knopf
/// den eigenen Aufbau — weisse Fläche, graue 1-px-Umrandung, das unveränderte
/// vierfarbige Logo links. Der harte schwarze Schatten und der 2,5-px-Rand der
/// App-Knöpfe würden davon abweichen, und eine Abweichung kann bei der
/// Store-Prüfung beanstandet werden. Die App-Handschrift trägt hier die
/// Schriftart und der Radius, nicht Rand und Schatten.
class _GoogleKnopf extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleKnopf({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: _kGoogleHoehe,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kGoogleRadius),
          border: Border.all(color: _kGoogleRand),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/icons/google_g.svg',
              width: _kGoogleLogo,
              height: _kGoogleLogo,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                t('Mit Google anmelden'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kGoogleText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Mit Apple anmelden" — schwarze Fläche, weisses Apfelzeichen, wie es Apples
/// Vorgaben für den dunklen Knopf verlangen.
///
/// Wird nur auf iOS und macOS überhaupt gebaut, siehe die Bedingung an der
/// Aufrufstelle. Das Zeichen kommt aus der Systemschrift; auf Apple-Geräten
/// ist  das Apfelsymbol, weshalb hier keine Bilddatei nötig ist.
class _AppleKnopf extends StatelessWidget {
  final VoidCallback onTap;
  const _AppleKnopf({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: _kGoogleHoehe,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(_kGoogleRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                t('Mit Apple anmelden'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
