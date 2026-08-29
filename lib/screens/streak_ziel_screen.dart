import 'package:flutter/material.dart';

import '../l10n/uebersetzungen.dart';
import '../services/knopf_rueckmeldung.dart';
import '../services/streak_ziel_service.dart';

// ── Streak-Ziel wählen ───────────────────────────────────────────────────────
//
// Erscheint einmal nach der zweiten abgeschlossenen Station (siehe
// [StreakZielService]). Ein winkender Coiny, vier Ziele zur Auswahl, ein
// Knopf — mehr nicht. Der Moment liegt direkt nach einem Erfolg, deshalb ist
// er bewusst kurz.
//
// ── Maße ────────────────────────────────────────────────────────────────────
//
// Leitgröße ist die Bildschirmhöhe: Coiny und die Abstände wachsen mit ihr,
// die Karten nicht (deren Höhe hängt am Text darin, nicht am Schirm). Auf dem
// kleinsten Ziel — 320x480 bei Schriftskala 1.5 — muss alles ohne Scrollen
// passen, deshalb sind alle drei Höhen-Anteile nach unten gedeckelt.

/// Coiny: Anteil der Bildschirmhöhe, mit Grenzen für sehr kleine und sehr
/// große Schirme.
///
/// Alle drei Werte sind um den Faktor 0.9 verkleinert (vorher 0.20 / 96 /
/// 176). Der Faktor steckt hier drin und nicht als eigene Konstante daneben:
/// Es gibt nur eine Grösse, und die soll man an einer Stelle ablesen können.
///
/// EINE LÜCKE ENTSTEHT DABEI NICHT, und es rückt auch nichts nach. Das
/// Ziel-Raster darunter sitzt in einem Expanded und nimmt, was übrig bleibt
/// (siehe build) — der frei gewordene Platz geht an die Karten.
///
/// Nachgemessen auf 320x480: Coiny 96,0 -> 86,4 px, die beiden Kartenreihen
/// wachsen um je 4,8 px, und der Knopf steht unverändert bei y=398. Auf
/// 384x750 dasselbe Bild: Coiny 150 -> 135, Reihen +7,5 px, Knopf unverändert.
const double _kCoinyAnteil = 0.18;
const double _kCoinyMin = 86.4;
const double _kCoinyMax = 158.4;

/// Abstände, ebenfalls als Anteil der Höhe.
const double _kAbstandCoinyTitel = 0.024;
const double _kAbstandTitelKarten = 0.030;
const double _kAbstandKartenKnopf = 0.030;

const double _kAbstandMin = 8.0;
const double _kAbstandMax = 24.0;

/// Abstand zwischen den Karten, waagrecht wie senkrecht.
const double _kKartenLuecke = 10.0;

const double _kSeitenrand = 20.0;

// ── Farben ───────────────────────────────────────────────────────────────────
const _cDunkel = Color(0xFF1A1A1A);
const _cGrau = Color(0xFF888888);
const _cGruen = Color(0xFF4A9E4A);
const _cHintergrund = Color(0xFFF5F4F0);

/// Die dezente Hervorhebung der Empfehlung — dieselben Werte, mit denen die
/// Rangliste den eigenen Eintrag heraushebt (siehe `_kEigeneZeile` und die
/// Randfarbe in rangliste_screen.dart). Bewusst kein eigener Ton: Der Spieler
/// soll das Muster wiedererkennen, nicht eine zweite Sprache lernen.
const _cEmpfohlenFlaeche = Color(0xFFE8F5E9);
const _cEmpfohlenRand = _cGruen;

/// Die Datei coin_winken.png ist 677x369 gross; die Figur darin sitzt bei
/// (220,70) und misst 238x273. Der Screen zeigt nur die Figur, nicht den
/// durchsichtigen Rand — dieselbe Rechnung wie im Willkommens-Screen.
const double _kCoinyDateiBreite = 677;
const double _kCoinyDateiHoehe = 369;
const double _kCoinyInhaltX = 220;
const double _kCoinyInhaltY = 70;
const double _kCoinyInhaltBreite = 238;

/// Beschriftung eines Ziels.
String _nameFuer(int tage) => switch (tage) {
      7 => 'Einsteiger',
      14 => 'Dranbleiber',
      30 => 'Monatsziel',
      _ => 'Durchhalter',
    };

class StreakZielScreen extends StatefulWidget {
  const StreakZielScreen({super.key});

  /// Zeigt den Screen und kehrt erst zurück, wenn er verlassen wurde — durch
  /// eine Wahl oder durch "Später entscheiden".
  ///
  /// Das Speichern passiert hier drin, nicht beim Aufrufer: Der Screen ist
  /// die einzige Stelle, die beide Ausgänge kennt.
  static Future<void> zeigen(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const StreakZielScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<StreakZielScreen> createState() => _StreakZielScreenState();
}

class _StreakZielScreenState extends State<StreakZielScreen> {
  /// Nichts ist vorausgewählt. Die 14 ist EMPFOHLEN, nicht GEWÄHLT — sonst
  /// könnte ein Tipp auf den Knopf eine Entscheidung speichern, die niemand
  /// getroffen hat.
  int? _gewaehlt;

  Future<void> _bestaetigen() async {
    final tage = _gewaehlt;
    if (tage == null) return;
    knopfRueckmeldung();
    await StreakZielService.setzeZiel(tage);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _spaeter() async {
    await StreakZielService.vertagt();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hoehe = MediaQuery.of(context).size.height;
    double abstand(double anteil) =>
        (hoehe * anteil).clamp(_kAbstandMin, _kAbstandMax);

    return Scaffold(
      backgroundColor: _cHintergrund,
      // Kein Zurück-Pfeil und keine Wischgeste: Der Screen wird über einen
      // der beiden Wege verlassen, damit der Zustand im Dienst dazu passt.
      body: PopScope(
        canPop: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kSeitenrand),
            child: Column(
              children: [
                SizedBox(height: abstand(_kAbstandCoinyTitel)),
                _Coiny(
                  durchmesser:
                      (hoehe * _kCoinyAnteil).clamp(_kCoinyMin, _kCoinyMax),
                ),
                SizedBox(height: abstand(_kAbstandCoinyTitel)),
                Text(
                  t('Wie weit willst du?'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _cDunkel,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('Setz dir ein Streak-Ziel.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _cGrau,
                  ),
                ),
                SizedBox(height: abstand(_kAbstandTitelKarten)),
                // Das Raster nimmt den Platz, der übrig bleibt, statt ihn zu
                // fordern: Auf 320x480 bei Schriftskala 1.5 ist er knapp, und
                // dann sollen die Karten flacher werden, nicht der Screen
                // scrollbar. Innen sorgt je ein FittedBox dafür, dass der
                // Inhalt mitschrumpft (siehe [_ZielKarte]).
                Expanded(
                  child: _Zielraster(
                    gewaehlt: _gewaehlt,
                    onWahl: (tage) => setState(() => _gewaehlt = tage),
                  ),
                ),
                SizedBox(height: abstand(_kAbstandKartenKnopf)),
                _ZielKnopf(
                  aktiv: _gewaehlt != null,
                  onTap: _bestaetigen,
                ),
                const SizedBox(height: 6),
                // Der leise Ausgang: ein Textlink, kein zweiter Knopf. Wer
                // hier landet, hat gerade zwei Stationen geschafft und weiss
                // vielleicht noch gar nicht, was ein Streak ist — ein
                // erzwungener Haken wäre an dieser Stelle Reibung ohne
                // Gewinn. Gefragt wird trotzdem nur noch ein zweites Mal,
                // siehe [StreakZielService.vertagt].
                TextButton(
                  onPressed: _spaeter,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(88, 44),
                    foregroundColor: _cGrau,
                  ),
                  child: Text(
                    t('Später entscheiden'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _cGrau,
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
}

/// Die vier Ziele als 2x2-Raster.
///
/// Bewusst ein Raster aus Rows und keine GridView: Es sind genau vier feste
/// Karten, die ihre Höhe aus ihrem Inhalt nehmen sollen. Eine GridView
/// bräuchte ein childAspectRatio — also eine feste Proportion, die bei
/// Schriftskala 1.5 überliefe.
class _Zielraster extends StatelessWidget {
  final int? gewaehlt;
  final ValueChanged<int> onWahl;

  const _Zielraster({required this.gewaehlt, required this.onWahl});

  @override
  Widget build(BuildContext context) {
    final tage = StreakZielService.zielTage;
    return Column(
      children: [
        for (var reihe = 0; reihe < 2; reihe++) ...[
          if (reihe > 0) const SizedBox(height: _kKartenLuecke),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var spalte = 0; spalte < 2; spalte++) ...[
                  if (spalte > 0) const SizedBox(width: _kKartenLuecke),
                  Expanded(
                    child: _ZielKarte(
                      tage: tage[reihe * 2 + spalte],
                      gewaehlt: gewaehlt == tage[reihe * 2 + spalte],
                      onTap: () => onWahl(tage[reihe * 2 + spalte]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Eine Ziel-Karte in drei Zuständen.
///
/// RUHE: weisse Fläche, dunkler Rand, harter Schatten — die Kartenoptik der
/// App.
///
/// EMPFOHLEN (nur die 14): grüne Fläche und grüner Rand nach dem Muster der
/// Rangliste. Dezent genug, dass die anderen drei nicht wie Fehlgriffe
/// wirken.
///
/// GEWÄHLT: Der Rand wird kräftiger und die Karte sinkt auf ihren Schatten —
/// dieselbe Geste wie beim Stationsbutton. Wichtig, weil sich Empfehlung und
/// Wahl sonst nicht unterscheiden liessen: Die Empfehlung ist eine Aussage
/// über die Karte, die Wahl eine über den Spieler.
class _ZielKarte extends StatelessWidget {
  final int tage;
  final bool gewaehlt;
  final VoidCallback onTap;

  const _ZielKarte({
    required this.tage,
    required this.gewaehlt,
    required this.onTap,
  });

  bool get _empfohlen => tage == StreakZielService.empfohlen;

  @override
  Widget build(BuildContext context) {
    final rand = gewaehlt
        ? _cGruen
        : (_empfohlen ? _cEmpfohlenRand : _cDunkel);
    final flaeche = (gewaehlt || _empfohlen) ? _cEmpfohlenFlaeche : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        // Der gewählte Zustand sitzt auf seinem Schatten: 3 px tiefer, dafür
        // ohne Versatz. Die Gesamthöhe bleibt dadurch gleich, es springt
        // nichts.
        margin: EdgeInsets.only(top: gewaehlt ? 3 : 0, bottom: gewaehlt ? 0 : 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: flaeche,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: rand, width: gewaehlt ? 2.5 : 2.0),
          boxShadow: gewaehlt
              ? null
              : const [
                  BoxShadow(
                    color: _cDunkel,
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
        ),
        // Der Haken macht die WAHL sichtbar. Ohne ihn sähen die empfohlene
        // und die gewählte Karte fast gleich aus — beide grün hinterlegt, der
        // Unterschied wäre allein der fehlende Schatten. Am Gerät nachgesehen:
        // Das reicht nicht. Dasselbe Zeichen benutzt die Sprachwahl in den
        // Einstellungen.
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: gewaehlt ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: _cGruen,
                ),
              ),
            ),
            _KartenInhalt(tage: tage, empfohlen: _empfohlen),
          ],
        ),
      ),
    );
  }
}

/// Zahl, Einheit, Name und der Platz für das Empfohlen-Schild.
class _KartenInhalt extends StatelessWidget {
  final int tage;
  final bool empfohlen;

  const _KartenInhalt({required this.tage, required this.empfohlen});

  @override
  Widget build(BuildContext context) {
    return Center(
      // EIN FittedBox um den ganzen Inhalt, nicht je Zeile einer: So
      // schrumpft die Karte bei grosser Systemschrift als Ganzes und behält
      // ihre Proportionen, statt dass jede Zeile für sich einen anderen
      // Faktor bekommt. Nach oben wird nichts vergrössert (scaleDown).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zahl und Einheit in EINER Zeile: Auf 320x480 ist jede
              // eingesparte Zeile spürbar, und "7 Tage" liest sich ohnehin
              // zusammen.
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$tage',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _cDunkel,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    t('Tage'),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _cGrau,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                t(_nameFuer(tage)),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _cDunkel,
                ),
              ),
              // Der Platz für das Empfohlen-Schild wird auf ALLEN Karten
              // freigehalten, sonst wäre die 14er höher als ihre Nachbarn und
              // das Raster liefe auseinander.
              const SizedBox(height: 4),
              Visibility(
                visible: empfohlen,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: _EmpfohlenSchild(),
              ),
            ],
          ),
      ),
    );
  }
}

class _EmpfohlenSchild extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _cGruen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          t('Empfohlen'),
          maxLines: 1,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Der Hauptknopf im Stil von [ChallengeFertigButton] — grau und stumpf,
/// solange nichts gewählt ist.
class _ZielKnopf extends StatelessWidget {
  final bool aktiv;
  final VoidCallback onTap;

  const _ZielKnopf({required this.aktiv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: aktiv ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: aktiv ? _cGruen : const Color(0xFFD0CEC8),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: aktiv ? _cDunkel : const Color(0xFFB0AEA8),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: aktiv ? _cDunkel : const Color(0xFFB0AEA8),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          t('Ziel setzen'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: aktiv ? Colors.white : const Color(0xFF8A8880),
          ),
        ),
      ),
    );
  }
}

/// Zeigt allein die Figur aus coin_winken.png, ohne den durchsichtigen Rand
/// der Datei.
class _Coiny extends StatelessWidget {
  final double durchmesser;

  const _Coiny({required this.durchmesser});

  @override
  Widget build(BuildContext context) {
    final massstab = durchmesser / _kCoinyInhaltBreite;
    return SizedBox(
      width: durchmesser,
      height: durchmesser,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.translate(
          offset: Offset(-_kCoinyInhaltX * massstab, -_kCoinyInhaltY * massstab),
          child: SizedBox(
            width: _kCoinyDateiBreite * massstab,
            height: _kCoinyDateiHoehe * massstab,
            child: Image.asset(
              'assets/icons/deko/coin_winken.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
