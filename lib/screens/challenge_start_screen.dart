import 'package:flutter/material.dart';
import '../l10n/uebersetzungen.dart';
import '../services/challenge_panel_signal.dart';
import '../services/locale_service.dart';

/// Tag, an dem die Tages-Challenges eingeführt wurden — Ausgabe #1 für alle 4.
/// Vor Release auf das tatsächliche Launch-/Testdatum zurückgesetzt, damit
/// die erste ab jetzt gespielte Runde wieder korrekt als "Ausgabe #1" zählt,
/// statt einer aus der Testphase bereits hochgezählten Nummer.
final kChallengesStartDatum = DateTime(2026, 7, 17);

const _kMonatsnamenDe = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
];
const _kMonatsnamenEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String formatiertesDatum(DateTime d) {
  final monate = LocaleService.istEnglisch ? _kMonatsnamenEn : _kMonatsnamenDe;
  return LocaleService.istEnglisch
      ? '${monate[d.month - 1]} ${d.day}, ${d.year}'
      : '${d.day}. ${monate[d.month - 1]} ${d.year}';
}

int ausgabeNummer(DateTime startDatum) {
  final heute = DateTime.now();
  final tageDiff = DateTime(heute.year, heute.month, heute.day)
      .difference(DateTime(startDatum.year, startDatum.month, startDatum.day))
      .inDays;
  return tageDiff + 1;
}

/// Wiederverwendbarer Start-/Ergebnis-Screen für alle Tages-Challenges:
/// erscheint statt des direkten Sprungs ins Spiel bzw. statt einer reinen
/// Text-Meldung. Zeigt je nach Tagesstatus entweder einen "Spielen"- oder
/// einen "Ergebnisse"-Button.
class ChallengeStartScreen extends StatefulWidget {
  final Color farbe;
  final String logoAsset;
  final IconData fallbackIcon;
  final String titel;
  final DateTime startDatum;
  final WidgetBuilder spielScreenBuilder;
  final WidgetBuilder ergebnisScreenBuilder;
  final Future<bool> Function() istHeuteGespielt;

  const ChallengeStartScreen({
    super.key,
    required this.farbe,
    required this.logoAsset,
    required this.fallbackIcon,
    required this.titel,
    required this.startDatum,
    required this.spielScreenBuilder,
    required this.ergebnisScreenBuilder,
    required this.istHeuteGespielt,
  });

  @override
  State<ChallengeStartScreen> createState() => _ChallengeStartScreenState();
}

class _ChallengeStartScreenState extends State<ChallengeStartScreen> {
  bool? _gespielt;

  @override
  void initState() {
    super.initState();
    _pruefen();
  }

  Future<void> _pruefen() async {
    final done = await widget.istHeuteGespielt();
    if (mounted) setState(() => _gespielt = done);
  }

  Future<void> _spielen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: widget.spielScreenBuilder),
    );
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nummer = ausgabeNummer(widget.startDatum);
    return Scaffold(
      backgroundColor: widget.farbe,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                // Zurück zum Challenge-Panel (die 4 Karten), nicht nur ein
                // einfacher Pop -> das würde je nach Stack-Tiefe an der
                // Startseite/dem Lernpfad statt am Panel landen. Dieselbe
                // Navigation wie der bereits bewährte finale "Weiter"-Button.
                onPressed: () => ChallengePanelSignal.zurueckZumPanel(context),
              ),
            ),
            const Spacer(),
            Image.asset(
              widget.logoAsset,
              width: 252,
              height: 252,
              errorBuilder: (c, e, s) =>
                  Icon(widget.fallbackIcon, size: 198, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(widget.titel,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 6),
            Text(t('Ausgabe #{n}', {'n': '$nummer'}),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(formatiertesDatum(DateTime.now()),
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const Spacer(),
            if (_gespielt == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: CircularProgressIndicator(color: Colors.white),
              )
            else if (_gespielt == false)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _WeisserButton(
                  text: t('Spielen'),
                  farbe: widget.farbe,
                  onTap: _spielen,
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Text(t('Heute bereits gespielt'),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _WeisserButton(
                  text: t('Ergebnisse'),
                  farbe: widget.farbe,
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: widget.ergebnisScreenBuilder)),
                ),
              ),
              const SizedBox(height: 12),
              Text(t('Komm morgen für Ausgabe #{n} wieder', {'n': '${nummer + 1}'}),
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _WeisserButton extends StatelessWidget {
  final String text;
  final Color farbe;
  final VoidCallback onTap;
  const _WeisserButton({required this.text, required this.farbe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: farbe)),
      ),
    );
  }
}
