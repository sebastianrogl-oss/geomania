import 'package:flutter/material.dart';

import '../l10n/uebersetzungen.dart';

// ── Maße ─────────────────────────────────────────────────────────────────────
//
// Leitgröße ist der Seitenrand; alles andere ist bewusst absolut, weil dieses
// Overlay Bildschirm-Chrome ist und nicht an einer Figur hängt.
const double _kSeitenrand = 32;

const _textDark = Color(0xFF1A1A1A);
const _karte = Color(0xFFFFFDF7);

/// Kurzerklärung für eine Kennzahl aus dem grünen Kopfbereich.
///
/// Sterne und Streak stehen dort dauerhaft, wurden aber nirgends erklärt: dass
/// ein Stern für die erste richtige Antwort auf eine Frage steht und dass man
/// damit Profilbilder freischaltet, war nur zu erraten.
///
/// Bewusst ein Dialog und kein Bottom-Sheet: es sind drei Sätze, und ein Sheet
/// über den halben Bildschirm wäre dafür zu viel Aufhebens. Für die
/// ausführlichen Modus-Anleitungen ist zeigeSpielErklaerung() zuständig.
Future<void> zeigeKennzahlErklaerung(
  BuildContext context, {
  required String symbol,
  required String titel,
  required List<String> absaetze,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => GestureDetector(
      // Antippen irgendwo schliesst — dasselbe Verhalten wie beim
      // Kategorien-Overlay im Quiz, damit sich Overlays der App gleich
      // anfühlen.
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(ctx).pop(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: _kSeitenrand),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(symbol, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titel,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final absatz in absaetze)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    absatz,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                      height: 1.45,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: Text(
                      t('Alles klar'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A9E4A),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Was ein Stern ist, woher er kommt und wofür er gut ist.
///
/// [gesamtSterne] ist die im ganzen Lernpfad erreichbare Zahl. Sie wird
/// hereingereicht statt hier berechnet, damit diese Datei nichts über den
/// Aufbau des Lernpfads wissen muss.
Future<void> zeigeSterneErklaerung(BuildContext context, int gesamtSterne) {
  return zeigeKennzahlErklaerung(
    context,
    symbol: '⭐',
    titel: t('Deine Sterne'),
    absaetze: [
      t('Jede Frage, die du zum ersten Mal richtig beantwortest, gibt einen '
          'Stern. Dieselbe Frage noch einmal richtig zu beantworten gibt '
          'keinen weiteren — Sterne zeigen also, wie viel du schon kannst.'),
      t('Mit Sternen schaltest du im Profil neue Profilbilder frei. Sie '
          'werden dabei abgezogen, dein Gesamtstand oben bleibt aber stehen.'),
      t('Im ganzen Lernpfad sind {n} Sterne zu holen.', {'n': '$gesamtSterne'}),
    ],
  );
}

/// Was die Serie ist und wie man sie hält.
Future<void> zeigeStreakErklaerung(BuildContext context) {
  return zeigeKennzahlErklaerung(
    context,
    symbol: '🔥',
    titel: t('Deine Serie'),
    absaetze: [
      t('Die Flamme zählt die Tage, an denen du hintereinander gespielt '
          'hast. Eine einzige abgeschlossene Station am Tag genügt, um sie '
          'am Leben zu halten.'),
      t('Setzt du einen Tag aus, fängt die Serie wieder bei 1 an. Verloren '
          'ist dabei nichts: Sterne, Abzeichen und dein Fortschritt im '
          'Lernpfad bleiben unberührt.'),
      t('Für lange Serien gibt es ausserdem Abzeichen.'),
    ],
  );
}
