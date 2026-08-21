import 'package:flutter/material.dart';

import '../l10n/uebersetzungen.dart';
import '../services/benachrichtigungs_service.dart';

// ── Maße ─────────────────────────────────────────────────────────────────────
//
// Leitgröße ist die Kartenbreite; Coiny und die Abstände leiten sich daraus
// ab, damit eine Änderung der Breite die Proportionen nicht zerreißt.
const double _kSeitenrand = 28;
const double _kCoinyAnteil = 0.32; // × verfügbare Kartenbreite

const _textDark = Color(0xFF1A1A1A);
const _textMid = Color(0xFF888888);
const _accent = Color(0xFF4A9E4A);
const _karte = Color(0xFFFFFDF7);

/// Der EIGENE Erlaubnis-Dialog, der dem Systemdialog vorgeschaltet ist.
///
/// Warum überhaupt zwei Dialoge: iOS zeigt sein Systemfenster genau EINMAL.
/// Wer dort ablehnt, kann Benachrichtigungen nur noch über die
/// Systemeinstellungen einschalten — das tut praktisch niemand. Also wird hier
/// zuerst erklärt, wofür, und der Systemdialog nur nach einem "Ja, gerne"
/// ausgelöst. Ein "Später" kostet nichts: der eine Versuch bleibt erhalten.
///
/// Gibt `true` zurück, wenn der Nutzer zugestimmt hat.
class ErinnerungDialog {
  static Future<bool> zeigen(BuildContext context) async {
    final zugestimmt = await showDialog<bool>(
      context: context,
      // Nicht durch Danebentippen wegwischbar: ein versehentliches Schließen
      // wäre stillschweigend ein "Später" und verbrauchte damit den ersten
      // der beiden Anläufe.
      barrierDismissible: false,
      builder: (_) => const _ErinnerungDialogInhalt(),
    );

    if (zugestimmt == true) {
      await BenachrichtigungsService.systemErlaubnisAnfragen();
      return true;
    }
    await BenachrichtigungsService.dialogVertagt();
    return false;
  }
}

class _ErinnerungDialogInhalt extends StatelessWidget {
  const _ErinnerungDialogInhalt();

  @override
  Widget build(BuildContext context) {
    final breite =
        MediaQuery.of(context).size.width - _kSeitenrand * 2 - 40;
    final coiny = (breite * _kCoinyAnteil).clamp(72.0, 130.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: _kSeitenrand),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        decoration: BoxDecoration(
          color: _karte,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _textDark, width: 2),
          boxShadow: const [
            BoxShadow(color: _textDark, offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/deko/coin_winken.png',
              width: coiny,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 14),
            Text(
              t('Sollen wir dich erinnern?'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('Dann bleibt deine Serie am Leben.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textMid,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            _JaButton(onTap: () => Navigator.of(context).pop(true)),
            const SizedBox(height: 4),
            // Bewusst ohne 3D-Muster und in Grau: die zurückgenommene Aktion
            // soll sichtbar die zweite Wahl sein, ohne versteckt zu wirken.
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                t('Später'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textMid,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hauptaktion im 3D-Muster der App (vgl. challenge_fertig_button.dart).
class _JaButton extends StatelessWidget {
  final VoidCallback onTap;
  const _JaButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _textDark, width: 2.5),
          boxShadow: const [
            BoxShadow(color: _textDark, offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Text(
          t('Ja, gerne'),
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
