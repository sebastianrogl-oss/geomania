import 'package:flutter/material.dart';

import '../l10n/uebersetzungen.dart';
import '../services/streak_ziel_service.dart';

// ── Maße ─────────────────────────────────────────────────────────────────────
//
// Leitgröße ist der Seitenrand; alles andere ist bewusst absolut, weil dieses
// Overlay Bildschirm-Chrome ist und nicht an einer Figur hängt.
const double _kSeitenrand = 32;
const double _kSeitenrandSenkrecht = 40;

const _textDark = Color(0xFF1A1A1A);
const _karte = Color(0xFFFFFDF7);

/// Erklär-Overlay der App: Symbol, Überschrift, ein paar Absätze, unten ein
/// Knopf zum Schließen.
///
/// Genutzt für die Kennzahlen im grünen Kopfbereich (Sterne, Streak) UND für
/// die ausführlichen Modus-Anleitungen im Lernpfad. Die lagen vorher in einem
/// schlichten Bottom-Sheet mit X-Symbol; sie sehen jetzt aus wie alles andere
/// Erklärende in der App, mit dem Emoji ihrer Station davor.
///
/// Bewusst ein Dialog und kein Bottom-Sheet: ein Sheet über den halben
/// Bildschirm ist für ein paar Sätze zu viel Aufhebens.
Future<void> zeigeKennzahlErklaerung(
  BuildContext context, {
  required String symbol,
  required String titel,
  required List<String> absaetze,

  /// Optionaler Baustein unter den Absätzen — heute der Ziel-Fortschritt in
  /// der Serien-Erklärung. Als Widget statt als weiterer Textabsatz, weil ein
  /// Balken kein Satz ist.
  Widget? zusatz,
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
        // Auch senkrecht ein Rand: die längsten Modus-Anleitungen (Länder-
        // Ranking, Nachbarschafts-Kette) füllen den Dialog sonst bis an die
        // Bildschirmkante.
        insetPadding: const EdgeInsets.symmetric(
          horizontal: _kSeitenrand,
          vertical: _kSeitenrandSenkrecht,
        ),
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
              // Scrollbar, aber nur wenn nötig: bei drei Sätzen ändert sich
              // nichts, bei einer vierteiligen Modus-Anleitung auf einem
              // schmalen Schirm rollt der Text, während Überschrift und Knopf
              // stehen bleiben — sonst schöbe der Text den Knopf aus dem Bild.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      // Innerhalb des Rollbereichs, nicht darunter: Auf einem
                      // schmalen Schirm mit grosser Systemschrift schöbe der
                      // Zusatz sonst den Knopf aus dem Bild.
                      ?zusatz,
                    ],
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

/// Was die Serie ist und wie man sie hält — und wo das persönliche Ziel steht.
///
/// ══ WARUM DAS ZIEL HIER STEHT UND NICHT IN DER KACHEL ═════════════════════
///
/// Es stand kurzzeitig als Zeile mit Balken direkt in der Profil-Kachel. Eine
/// Kachel im Profil ist aber eine Kennzahl auf einen Blick; ein Balken mit
/// "3/14" darunter macht daraus eine kleine Tabelle. Hier, wo ohnehin erklärt
/// wird, was die Serie ist, gehört auch hin, was man sich vorgenommen hat.
///
/// Das Ziel wird HIER geladen, nicht von aussen hereingereicht.
///
/// Es gibt zwei Stellen, an denen die Serie steht: die Flamme in der
/// Lernpfad-Kopfleiste und die Kachel im Profil. Beide öffnen diese
/// Erklärung. Käme das Ziel als Parameter, müsste es durch beide Screens
/// durchgereicht werden — und die eine Stelle, an der man es vergisst, zeigt
/// dann stillschweigend kein Ziel an, obwohl eines gesetzt ist.
Future<void> zeigeStreakErklaerung(
  BuildContext context, {
  required int streak,
  VoidCallback? onZielSetzen,
}) async {
  final zielTage = await StreakZielService.ziel();
  final stand = await StreakZielService.stand();
  if (!context.mounted) return;
  // "Erledigt, aber kein Ziel" heisst: zweimal vertagt. Nur dieser Spieler
  // wird nie wieder von selbst gefragt.
  final zielAbgelehnt = stand == ZielStand.erledigt && zielTage == null;
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
    zusatz: _zielBereich(
      streak: streak,
      zielTage: zielTage,
      zielAbgelehnt: zielAbgelehnt,
      onZielSetzen: onZielSetzen,
    ),
  );
}

// ── Der Ziel-Bereich ────────────────────────────────────────────────────────

const double _kZielBalkenHoehe = 6;
const _kZielSpur = Color(0xFFE0DED4);

/// Die gelaufene Strecke, im Ton der Flamme.
const _kZielBalken = Color(0xFFB34700);

/// Drei Zustände, drei Antworten:
///
///  * Ziel gesetzt      → Balken und Fortschritt.
///  * Ziel noch offen   → NICHTS. Die App fragt von sich aus nach ein paar
///                        Stationen; ihr hier vorzugreifen hiesse, dieselbe
///                        Frage zweimal zu stellen.
///  * Ziel abgelehnt    → ein Weg zurück. Wer zweimal "Später" gewählt hat,
///                        wird nie wieder automatisch gefragt — ohne diesen
///                        Satz käme er an ein Ziel gar nicht mehr heran.
Widget? _zielBereich({
  required int? streak,
  required int? zielTage,
  required bool zielAbgelehnt,
  required VoidCallback? onZielSetzen,
}) {
  if (zielTage != null && streak != null) {
    return _ZielFortschritt(streak: streak, ziel: zielTage);
  }
  if (zielAbgelehnt && onZielSetzen != null) {
    return _ZielAngebot(onTap: onZielSetzen);
  }
  return null;
}

class _ZielFortschritt extends StatelessWidget {
  final int streak;
  final int ziel;

  const _ZielFortschritt({required this.streak, required this.ziel});

  @override
  Widget build(BuildContext context) {
    final anteil = ziel <= 0 ? 0.0 : (streak / ziel).clamp(0.0, 1.0);
    final geschafft = streak >= ziel;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('Dein Ziel'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
              ),
              // Der echte Wert, auch über dem Ziel: "20/14" liest sich als
              // "darüber". Ein bei 14 angehaltener Zähler sähe aus wie ein
              // Fehler.
              Text(
                '$streak/$ziel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: geschafft ? _kZielBalken : _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(_kZielBalkenHoehe / 2),
            child: LinearProgressIndicator(
              value: anteil,
              minHeight: _kZielBalkenHoehe,
              backgroundColor: _kZielSpur,
              valueColor: const AlwaysStoppedAnimation<Color>(_kZielBalken),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            geschafft
                ? t('Geschafft — {tage} Tage am Stück.', {'tage': '$ziel'})
                : t('Noch {n} Tage bis zu deinem Ziel von {tage} Tagen.',
                    {'n': '${ziel - streak}', 'tage': '$ziel'}),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textDark,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Für die, die die Zielfrage seinerzeit abgelehnt haben.
class _ZielAngebot extends StatelessWidget {
  final VoidCallback onTap;

  const _ZielAngebot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t('Du kannst dir vornehmen, wie viele Tage am Stück du spielen '
                'willst.'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textDark,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                t('Ziel setzen'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4A9E4A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
