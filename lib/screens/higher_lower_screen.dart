import 'dart:math';
import 'package:flutter/material.dart';
import '../data/abzeichen_data.dart';
import '../data/country_rankings.dart';
import '../l10n/uebersetzungen.dart';
import '../services/locale_service.dart';
import '../services/abzeichen_service.dart';
import '../services/challenge_ergebnis_service.dart';
import '../services/challenge_panel_signal.dart';
import '../services/challenge_rekord_service.dart';
import '../services/daily_challenge.dart';
import '../services/daily_resume_service.dart';
import '../services/tages_seed_service.dart';
import '../services/rangliste_service.dart';
import '../services/knopf_rueckmeldung.dart';
import '../services/sound_service.dart';
import '../widgets/abzeichen_popup.dart';
import '../widgets/challenge_ergebnis_header.dart';
import '../widgets/challenge_fertig_button.dart';
import '../widgets/ergebnis_karten.dart';
import '../widgets/flaggen_widget.dart' show zeigeFlagge;
import '../widgets/rangliste_ergebnis_karte.dart';
import '../widgets/spiel_erklaerung.dart';
import '../theme/app_theme.dart';

// ── Masse des Kopfbereichs ───────────────────────────────────────────────────
//
// Die drei Felder im Kopf — zurück, Punktestand, Erklärung — sind absichtlich
// gleich gross. Nur so ist der Platz rechts vom Titel im Voraus bekannt, und
// nur dann lässt sich der Titel über einen Stack in die ECHTE Mitte setzen,
// ohne dass er bei zweistelliger Punktzahl unter die Knöpfe läuft.

/// Tippfläche eines Kopffeldes. 44 ist das übliche Mindestmass.
const double _kKopfTippflaeche = 44;

/// Sichtbares Quadrat darin — wie beim Fragezeichen-Knopf im Quiz.
const double _kKopfFeld = 36;

/// Symbolgrösse in den Knopffeldern.
const double _kKopfSymbol = 20;

// ── Masse und Timing der Kartenfläche ────────────────────────────────────────

/// Höhe des VS-Bandes zwischen den beiden Kartenhälften.
///
/// Fest statt aus dem Inhalt: Die Hälften werden daraus berechnet
/// ([_buildGame]), und eine Höhe, die sich aus der Schriftgrösse ergäbe,
/// machte die Rechnung von der Systemschrift abhängig.
const double _kTrennerHoehe = 28;

/// Stärke der Trennlinie im VS-Band.
const double _kTrennerLinie = 1;

/// Wie weit eine Kartenhälfte über ihren Platz hinaus ins VS-Band reicht.
///
/// DAMIT DIE FARBFLÄCHE AN DER TRENNLINIE ENDET, nicht davor. Vorher waren
/// die Hälften genau [_kTrennerHoehe] auseinander: Zwischen der gefärbten
/// Fläche und der Linie blieben oben wie unten 13,5 dp blanker Untergrund
/// stehen — die Rückmeldung hörte sichtbar vor der Kante auf.
///
/// Jetzt wächst jede Hälfte um genau diesen Wert, sodass ihre Kante auf der
/// Linie liegt. In die Linie hinein läuft sie nicht: Abgezogen wird die halbe
/// Linienstärke, und das VS-Band wird ohnehin ZULETZT gezeichnet — Linie und
/// VS-Schild liegen also oben auf, nichts überdeckt sie.
const double _kHaelfteInsBand = (_kTrennerHoehe - _kTrennerLinie) / 2;

/// Dauer der Wisch-Bewegung nach einer richtigen Antwort.
const Duration _kWischDauer = Duration(milliseconds: 450);

/// Schlüssel der beiden Kartenhälften.
///
/// Öffentlich, weil die Tests darüber messen: Seit die Hälften in einem Stack
/// statt in zwei AnimatedSwitchern liegen, gibt es keinen Widget-Typ mehr, an
/// dem sie sich eindeutig festmachen liessen.
const Key kHlObenKey = ValueKey('hl_oben');
const Key kHlUntenKey = ValueKey('hl_unten');

/// Die Rückmeldungsfarben der angetippten Hälfte.
///
/// KRÄFTIGER ALS VORHER: Bis eben lagen hier #E8F5E9 und #FFEBEE — die
/// blassen Hinterlegungen der App. Als kleine Kachel funktionieren sie, über
/// eine halbe Bildschirmhöhe verlieren sie sich aber gegen den ohnehin hellen
/// Untergrund (#F5F4F0): Der Unterschied betrug im Grün gerade 13 Stufen im
/// Rotkanal. Zwei Abstufungen tiefer ist die Rückmeldung auf einen Blick da,
/// und der dunkle Text (#1A1A1A) sowie das weisse Wertfeld bleiben darauf gut
/// lesbar.
///
/// Öffentlich, damit der Test sie nicht abschreiben muss — sonst fällt er bei
/// der nächsten Farbänderung um, ohne dass etwas kaputt wäre.
const Color kHlRichtigFlaeche = Color(0xFFA5D6A7);
const Color kHlFalschFlaeche = Color(0xFFEF9A9A);

// Einen Freiraum-Wert für die Mitte braucht es nicht mehr: Dort steht jetzt
// nur noch das 36 px breite Zahlenfeld, und das ist von den beiden Knöpfen
// links und rechts so weit entfernt, dass es sie auch bei grosser
// Systemschrift nicht erreicht.

/// Ein graues, abgerundetes Feld im Kopfbereich.
///
/// [tippbar] entscheidet nur über die Breite der Hülle: Knöpfe bekommen die
/// 44-px-Tippfläche, die reine Punktanzeige nicht — sie muss nicht getroffen
/// werden und würde sonst 8 px Freiraum vom Titel wegnehmen.
class _KopfFeld extends StatelessWidget {
  final Widget child;
  final bool tippbar;
  const _KopfFeld({required this.child, this.tippbar = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tippbar ? _kKopfTippflaeche : _kKopfFeld,
      height: _kKopfTippflaeche,
      child: Center(
        child: Container(
          width: _kKopfFeld,
          height: _kKopfFeld,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAE5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Runden-Historie (für die Game-Over-Liste) ──────────────────────────────

class _HigherLowerRunde {
  final String land1Iso;
  final String land1Name;
  final String land2Iso;
  final String land2Name;
  final double wert1;
  final double wert2;
  final bool wahlHoeher;
  final bool warRichtig;

  const _HigherLowerRunde({
    required this.land1Iso,
    required this.land1Name,
    required this.land2Iso,
    required this.land2Name,
    required this.wert1,
    required this.wert2,
    required this.wahlHoeher,
    required this.warRichtig,
  });

  Map<String, dynamic> toJson() => {
    'land1Iso': land1Iso,
    'land1Name': land1Name,
    'land2Iso': land2Iso,
    'land2Name': land2Name,
    'wert1': wert1,
    'wert2': wert2,
    'wahlHoeher': wahlHoeher,
    'warRichtig': warRichtig,
  };

  static _HigherLowerRunde fromJson(Map<String, dynamic> j) =>
      _HigherLowerRunde(
        land1Iso: j['land1Iso'] as String,
        land1Name: j['land1Name'] as String,
        land2Iso: j['land2Iso'] as String,
        land2Name: j['land2Name'] as String,
        wert1: (j['wert1'] as num).toDouble(),
        wert2: (j['wert2'] as num).toDouble(),
        wahlHoeher: j['wahlHoeher'] as bool,
        warRichtig: j['warRichtig'] as bool,
      );
}

class HigherLowerScreen extends StatefulWidget {
  /// Wenn true: zeigt nur das heute bereits erzielte Ergebnis erneut an,
  /// startet KEINE neue Runde (für "Ergebnisse" im Start-Screen).
  final bool nurAnsicht;
  const HigherLowerScreen({super.key, this.nurAnsicht = false});

  @override
  State<HigherLowerScreen> createState() => _HigherLowerScreenState();
}

class _HigherLowerScreenState extends State<HigherLowerScreen>
    with SingleTickerProviderStateMixin {
  static const _kId = 'higher_lower';

  /// Treibt die Wisch-Bewegung nach einer richtigen Antwort.
  late final AnimationController _wisch;

  /// Die alte obere Karte, solange sie nach rechts hinausfährt.
  ///
  /// Ein fertig gebautes Widget statt der Rohdaten: Es entsteht im Moment vor
  /// dem Weiterschalten und trägt damit noch die Rückmeldungsfarbe, die es
  /// beim Antworten bekommen hat. Aus dem dann schon weitergedrehten Zustand
  /// liesse es sich nicht mehr rekonstruieren.
  Widget? _ausKarte;

  bool get _wischt => _ausKarte != null;

  /// Während der Bewegung ist die Fläche stumm — sonst tippt man in die
  /// rutschende Karte hinein und rät auf ein Land, das gerade erst
  /// hereinkommt.
  bool get _tippenGesperrt => _answered || _gameOver || _wischt;

  late RankingCategory _category;
  late CountryRanking _leftCountry;
  late CountryRanking _rightCountry;

  // Deterministische Länderkette für die heutige Challenge: gleiche
  // Kategorie und gleiche Reihenfolge für alle Spieler an diesem Tag.
  List<CountryRanking> _seedLaender = [];
  int _naechsterSeedIdx = 0;

  int _score = 0;
  bool _answered = false;
  bool? _lastCorrect;

  /// Welche Hälfte der Spieler angetippt hat: true = untere ("höher"),
  /// false = obere ("niedriger"). Die Rückmeldung färbt GENAU diese Seite.
  bool? _wahlUnten;
  bool _rundungsGleichstand = false;
  bool _gameOver = false;


  final List<_HigherLowerRunde> _historie = [];

  // _category/_leftCountry/_rightCountry werden nur innerhalb der
  // (nicht awaiteten) async Lade-Methoden gesetzt, die build() aber sofort
  // nach initState() bereits ohne diese Daten aufruft — ohne dieses Flag
  // greift der allererste Frame auf die noch uninitialisierten late-Felder
  // zu (LateInitializationError).
  bool _bereit = false;

  @override
  void initState() {
    super.initState();
    _wisch = AnimationController(vsync: this, duration: _kWischDauer);
    if (widget.nurAnsicht) {
      _ladeHeutigesErgebnis();
    } else {
      _ladeUndStarte();
    }
  }

  @override
  void dispose() {
    _wisch.dispose();
    super.dispose();
  }

  /// Zeigt das heute bereits erzielte Ergebnis erneut an, ohne eine neue
  /// Runde zu starten (siehe HigherLowerScreen.nurAnsicht).
  Future<void> _ladeHeutigesErgebnis() async {
    final heute = await ChallengeRekordService.getHeutigePunkte(_kId) ?? 0;
    final detail = await ChallengeErgebnisService.laden(_kId);
    final katId = detail?['categoryId'] as String?;
    final wrongIso2 = detail?['wrongIso2'] as String?;
    final historieRoh = (detail?['historie'] as List<dynamic>?) ?? [];
    final historie = historieRoh
        .map((e) => _HigherLowerRunde.fromJson(e as Map<String, dynamic>))
        .toList();
    setState(() {
      _score = heute;
      _category = rankingCategories.firstWhere(
        (k) => k.id == katId,
        orElse: () => rankingCategories.first,
      );
      _rightCountry = countryRankings.firstWhere(
        (c) => c.iso2 == wrongIso2,
        orElse: () => countryRankings.first,
      );
      _leftCountry = _rightCountry;
      _historie
        ..clear()
        ..addAll(historie);
      _gameOver = true;
      _bereit = true;
    });
  }

  Future<void> _ladeUndStarte() async {
    // Tägliche Kategorie: einmal pro Tag fest, anderen Seed als Preis-Schätzen
    final katRng = Random(TagesSeedService.seedFuer(_kId) + 555);
    _category = rankingCategories[katRng.nextInt(rankingCategories.length)];
    _generiereSeedLaender();

    final zwischenstand = await DailyResumeService.laden(_kId);
    if (zwischenstand != null) {
      final links = countryRankings.cast<CountryRanking?>().firstWhere(
        (c) => c?.iso2 == zwischenstand['leftIso2'],
        orElse: () => null,
      );
      final rechts = countryRankings.cast<CountryRanking?>().firstWhere(
        (c) => c?.iso2 == zwischenstand['rightIso2'],
        orElse: () => null,
      );
      if (links != null && rechts != null) {
        final historieRoh = (zwischenstand['historie'] as List<dynamic>?) ?? [];
        final historie = historieRoh
            .map((e) => _HigherLowerRunde.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _score = zwischenstand['score'] as int? ?? 0;
          _naechsterSeedIdx = zwischenstand['seedIdx'] as int? ?? 2;
          _leftCountry = links;
          _rightCountry = rechts;
          _answered = false;
          _lastCorrect = null;
          _wahlUnten = null;
          _gameOver = false;
          _historie
            ..clear()
            ..addAll(historie);
          _bereit = true;
        });
        return;
      }
    }
    _startGame();
  }

  Future<void> _zwischenstandSpeichern() async {
    await DailyResumeService.speichern(_kId, {
      'score': _score,
      'seedIdx': _naechsterSeedIdx,
      'leftIso2': _leftCountry.iso2,
      'rightIso2': _rightCountry.iso2,
      'historie': _historie.map((e) => e.toJson()).toList(),
    });
  }

  void _generiereSeedLaender() {
    final rng = Random(TagesSeedService.seedFuer(_kId));
    _seedLaender =
        countryRankings.where((c) => _category.getValue(c) != null).toList()
          ..shuffle(rng);
  }

  void _startGame() {
    _naechsterSeedIdx = 2;
    setState(() {
      _score = 0;
      _answered = false;
      _lastCorrect = null;
      _wahlUnten = null;
      _gameOver = false;
      _leftCountry = _seedLaender[0];
      _rightCountry = _seedLaender[1];
      _historie.clear();
      _bereit = true;
    });
  }

  // Nächstes Land der Tageskette; fällt erst zurück auf Zufall, wenn die
  // Kette erschöpft ist (Kategorie bleibt dabei immer gleich).
  CountryRanking _naechstesLand() {
    if (_naechsterSeedIdx < _seedLaender.length) {
      return _seedLaender[_naechsterSeedIdx++];
    }
    final rng = Random();
    final pool =
        countryRankings
            .where(
              (c) =>
                  _category.getValue(c) != null && c.iso2 != _rightCountry.iso2,
            )
            .toList()
          ..shuffle(rng);
    return pool.first;
  }

  /// Weiter zur nächsten Frage — mit der Wisch-Bewegung.
  ///
  /// Die Daten werden SOFORT umgestellt, die Bewegung läuft rückwärts dazu:
  /// Bei p = 0 sitzen die Karten noch dort, wo sie vor dem Umstellen waren,
  /// bei p = 1 auf ihren neuen Plätzen. Das erspart einen zweiten Satz
  /// Zustandsfelder für "was war vorher" — bis auf die eine Karte, die
  /// hinausfährt und im neuen Zustand nicht mehr vorkommt.
  void _advanceRound() {
    final neuesLand = _naechstesLand();
    // Schnappschuss VOR dem Umstellen: Danach ist _answered false, und die
    // Karte hätte ihre Rückmeldungsfarbe verloren.
    final ausKarte = _obenPanel();
    setState(() {
      _ausKarte = ausKarte;
      _leftCountry = _rightCountry;
      _rightCountry = neuesLand;
      _score++;
      _answered = false;
      _lastCorrect = null;
      _wahlUnten = null;
      _rundungsGleichstand = false;
    });
    // Zum Start der Bewegung, nicht danach. Fehlt die Klangdatei noch, kehrt
    // spiele() still zurück (siehe [Klang.wisch]).
    SoundService.spiele(Klang.wisch);
    _wisch.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() => _ausKarte = null);
    });
  }

  void _guess(bool guessHigher) {
    if (_tippenGesperrt) return;
    // AUSDRÜCKLICH nur der Knopfklang: kein richtig/falsch, auch nicht bei
    // Higher or Lower. Ob der Tipp stimmte, zeigt der Screen ohnehin sofort.
    knopfRueckmeldung();

    final leftVal = _category.getValue(_leftCountry)!;
    final rightVal = _category.getValue(_rightCountry)!;
    // Rundungs-Gleichstand: der Spieler sieht nur die GERUNDETE Zahl (_fmt) —
    // weichen die Rohwerte nur minimal ab, sodass beide auf denselben
    // angezeigten Wert runden, wirkt jede Entscheidung für ihn willkürlich.
    // Dann zählt JEDE Antwort als richtig, statt nur die Richtung des
    // unsichtbaren Rohwert-Unterschieds.
    final rundungsGleichstand =
        leftVal != rightVal && _fmt(leftVal) == _fmt(rightVal);
    final bool correct =
        leftVal == rightVal ||
        rundungsGleichstand ||
        (guessHigher ? rightVal > leftVal : rightVal < leftVal);

    _historie.add(
      _HigherLowerRunde(
        land1Iso: _leftCountry.iso2,
        land1Name: _leftCountry.name,
        land2Iso: _rightCountry.iso2,
        land2Name: _rightCountry.name,
        wert1: leftVal,
        wert2: rightVal,
        wahlHoeher: guessHigher,
        warRichtig: correct,
      ),
    );

    setState(() {
      _answered = true;
      _lastCorrect = correct;
      _wahlUnten = guessHigher;
      _rundungsGleichstand = rundungsGleichstand;
    });

    Future.delayed(const Duration(milliseconds: 1100), () async {
      if (!mounted) return;
      if (correct) {
        // Setzt den Zustand um UND startet die Wisch-Bewegung.
        _advanceRound();
        _zwischenstandSpeichern();
      } else {
        final neueAbzeichen = await _speichereErgebnis();
        if (mounted && neueAbzeichen.isNotEmpty) {
          await AbzeichenPopup.zeigen(context, neueAbzeichen);
        }
        if (!mounted) return;
        setState(() => _gameOver = true);
      }
    });
  }

  Future<List<Abzeichen>> _speichereErgebnis() async {
    // Die Serie ist zu Ende, die Challenge damit abgeschlossen.
    //
    // Der Sieg-Klang steht beim AUFRUFER, hinter dem Abzeichen-Popup: Sonst
    // liefe er hinter der Abzeichen-Animation ab, und beim Ergebnis selbst
    // waere es still.
    final neuerRekord = await ChallengeRekordService.setzeFallsBesser(
      _kId,
      _score,
    );
    await ChallengeRekordService.speichereHeutigePunkte(_kId, _score);
    await ChallengeRekordService.summeErhoehen(_kId, _score.toDouble());
    await ChallengeErgebnisService.speichern(_kId, {
      'categoryId': _category.id,
      'wrongIso2': _rightCountry.iso2,
      'historie': _historie.map((e) => e.toJson()).toList(),
    });
    await RanglisteService.ergebnisSpeichernMitBereinigung(
      challengeId: 'higherlower',
      wert: _score,
    );
    await DailyChallenge.markDone(_kId);
    await DailyResumeService.loeschen(_kId);
    // "Perfekt" hat für Higher-or-Lower kein natürliches Maximum (Serie ohne
    // Deckel) -> hier bewusst nie ausgelöst, nur über Preis/Ranking möglich.
    return AbzeichenService.pruefeNachChallengeAbschluss(
      neuerRekordHeute: neuerRekord,
    );
  }

  String _fmt(double v) {
    final en = LocaleService.istEnglisch;
    String dec(int decimals) {
      final s = v.toStringAsFixed(decimals);
      return en ? s : s.replaceAll('.', ',');
    }

    String decOf(double x, int decimals) {
      final s = x.toStringAsFixed(decimals);
      return en ? s : s.replaceAll('.', ',');
    }

    switch (_category.id) {
      case 'population':
        if (v >= 1e9) return '${decOf(v / 1e9, 2)} ${en ? 'B' : 'Mrd.'}';
        if (v >= 1e6) return '${decOf(v / 1e6, 1)} ${en ? 'M' : 'Mio.'}';
        return _fmtInt(v.toInt());
      case 'area':
        if (v >= 1e6) return '${decOf(v / 1e6, 2)} ${en ? 'M' : 'Mio.'} km²';
        return '${_fmtInt(v.toInt())} km²';
      case 'gdpPerCapita':
        return '\$ ${_fmtInt(v.toInt())}';
      case 'gdpTotal':
        if (v >= 1e12) return '\$ ${decOf(v / 1e12, 1)} ${en ? 'T' : 'Bio.'}';
        if (v >= 1e9) {
          return '\$ ${(v / 1e9).toStringAsFixed(0)} ${en ? 'B' : 'Mrd.'}';
        }
        return '\$ ${(v / 1e6).toStringAsFixed(0)} ${en ? 'M' : 'Mio.'}';
      case 'lifeExpectancy':
        return '${dec(1)} ${en ? 'years' : 'Jahre'}';
      case 'coastline':
        return '${_fmtInt(v.toInt())} km';
      case 'minimumWage':
        return '\$ ${_fmtInt(v.toInt())}/${en ? 'mo' : 'Mo.'}';
      case 'internet':
        return '${v.round()} Mbps';
      case 'corruption':
        return '${v.round()} / 100';
      case 'press_freedom':
        return '${v.round()} / 100';
      case 'happiness':
        return dec(2);
      case 'tourism':
        return _fmtGerundetOderZweiDezimal(v, '${en ? 'B' : 'Mrd.'} \$');
      case 'military':
        return _fmtGerundetOderZweiDezimal(v, '${en ? 'B' : 'Mrd.'} \$');
      case 'birth_rate':
        return '${dec(1)} ${en ? 'children/woman' : 'K/Frau'}';
      case 'forest':
        return '${v.round()} %';
      case 'alcohol':
        return '${dec(1)} ${en ? 'L/capita' : 'L/Kopf'}';
      case 'olympics':
        return '${v.toInt()} ${en ? 'medals' : 'Medaillen'}';
      case 'highest_point':
        return '${_fmtInt(v.toInt())} m';
      case 'inflation':
        return '${dec(1)} %';
      case 'debt':
        return '${dec(1)} % ${en ? 'GDP' : 'BIP'}';
      default:
        return '${dec(1)} ${_category.unit}';
    }
  }

  // Ganzzahlige Rundung würde bei sehr kleinen Werten (z.B. Tourismus-
  // einnahmen/Militärausgaben winziger Länder) fälschlich "0" anzeigen,
  // obwohl der Wert ungleich null ist — dann fest auf 2 Nachkommastellen
  // ausweichen, sonst ganzzahlig runden wie gewohnt.
  String _fmtGerundetOderZweiDezimal(double v, String einheit) {
    final en = LocaleService.istEnglisch;
    if (v == 0) return '0 $einheit';
    if (v.round() == 0) {
      final s = v.toStringAsFixed(2);
      return '${en ? s : s.replaceAll('.', ',')} $einheit';
    }
    return '${v.round()} $einheit';
  }

  String _fmtInt(int n) {
    final sep = LocaleService.istEnglisch ? ',' : '.';
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(sep);
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHintergrund,
      body: SafeArea(
        child: !_bereit
            ? const Center(child: CircularProgressIndicator())
            : (_gameOver ? _buildGameOver() : _buildGame()),
      ),
    );
  }

  // ── Game ──────────────────────────────────────────────────────────────────

  // Die Rückmeldung gehört auf die Seite, die der Spieler ANGETIPPT hat —
  // nicht auf die untere.
  //
  // Vorher hing die Farbe an der unteren Karte, weil das die Karte ist, die
  // aufgedeckt wird. Wer aber oben tippte ("der verdeckte Wert ist
  // niedriger") und recht hatte, sah die Bestätigung trotzdem unten: grün an
  // einer Karte, die er gar nicht gewählt hatte. Aufgedeckt wird weiterhin
  // die untere — das ist die Antwort —, gefärbt wird die Wahl. Beide
  // Kartenbauer unten lesen diese Farbe.
  Color get _rueckmeldung =>
      _lastCorrect == true ? kHlRichtigFlaeche : kHlFalschFlaeche;

  Widget _buildGame() {
    return Column(
      children: [
        // ── Kopfbereich ─────────────────────────────────────────────────────
        //
        // Titel und Kategorie stehen MITTIG im Kopf, nicht links neben dem
        // Zurück-Knopf. Damit das die echte Mitte ist und nicht nur die Mitte
        // des Restplatzes, liegen die Knöpfe in einem Stack ÜBER dem Titel und
        // der Titel bekommt links wie rechts denselben Freiraum.
        //
        // Alle drei Felder — zurück, Punkte, Erklärung — sind gleich breit.
        // Dadurch ist der rechte Freiraum berechenbar (_kKopfFreiraum) und der
        // Titel kann mit den Knöpfen nicht kollidieren, egal wie viele Stellen
        // die Punktzahl hat.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // IN DER MITTE STEHT NUR DIE SERIE.
              //
              // Der Spielname ist raus wie in den drei anderen Challenges,
              // und die Kategorie ebenfalls: Sie steht auf beiden Kartenhälften
              // ohnehin unter dem Ländernamen, in der Kopfzeile war sie das
              // dritte Mal dasselbe Wort.
              //
              // Die Zahl sitzt im grauen Feld — demselben [_KopfFeld], das
              // schon den Pokal ersetzt hat und das auch die beiden Knöpfe
              // daneben tragen.
              _KopfFeld(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$_score',
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => ChallengePanelSignal.zurueckZumPanel(context),
                  child: const _KopfFeld(
                    tippbar: true,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF1A1A1A),
                      size: _kKopfSymbol,
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Das graue Feld mit der Serie stand hier und ist in die
                    // Mitte gewandert (siehe oben). Rechts bleibt nur noch
                    // der Erklärungs-Knopf.
                    ErklaerungButton(
                      titel: t('Higher or Lower — Spielregeln'),
                      farbe: const Color(0xFF4A9E4A),
                      abschnitte: [
                        t(
                          'Du siehst zwei Länder mit derselben Kategorie (z.B. Bevölkerung, Fläche, BIP pro Kopf). Bei einem Land ist der Wert bereits sichtbar.',
                        ),
                        t(
                          'Tippe auf das untere, verdeckte Land, wenn du glaubst, dass sein Wert HÖHER ist als der des oberen Landes — oder tippe auf das obere Land, wenn du glaubst, dass es NIEDRIGER ist.',
                        ),
                        t(
                          'Bei richtiger Antwort geht es mit einem neuen Land weiter und deine Serie waechst um 1. Bei einer falschen Antwort endet die Runde.',
                        ),
                        t(
                          'Ziel: eine möglichst lange Serie richtiger Antworten in Folge erreichen. Dein bester Wert wird als Rekord gespeichert.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Panels ──────────────────────────────────────────────────────────
        //
        // EIN Stack statt zweier fester Hälften in einer Column.
        //
        // Nötig für die Wisch-Bewegung: Nach einer richtigen Antwort wandert
        // die untere Karte auf den oberen Platz. In einer Column mit zwei
        // Expanded ist das unmöglich — jede Hälfte kann nur ihren eigenen
        // Kasten füllen, und der AnimatedSwitcher darin tauscht Inhalte aus,
        // statt sie zu bewegen. Im Stack liegen beide Karten dagegen im
        // selben Koordinatensystem und lassen sich frei verschieben.
        //
        // Die Karten selbst ([_RevealedPanel], [_HiddenPanel]) sind
        // unverändert; nur ihre Anordnung ist neu.
        Expanded(
          child: LayoutBuilder(
            builder: (context, platz) {
              final b = platz.maxWidth;
              final h = platz.maxHeight;
              final haelfte = (h - _kTrennerHoehe) / 2;
              final untenOben = haelfte + _kTrennerHoehe;
              // Bis an die Trennlinie statt bis an den Bandrand — siehe
              // [_kHaelfteInsBand].
              final flaecheHoehe = haelfte + _kHaelfteInsBand;
              final untenFlaeche = untenOben - _kHaelfteInsBand;

              return AnimatedBuilder(
                animation: _wisch,
                builder: (context, _) {
                  // DIE KARTE WANDERT AUSSEN HERUM.
                  //
                  // Sie verlässt die untere Hälfte nach rechts und taucht
                  // links oben wieder auf — als führe der Weg um den Bildrand
                  // herum. Dass es dieselbe Karte ist, macht die ÜBERLAPPUNG
                  // klar: Das Auftauchen oben beginnt, während unten noch ein
                  // Rest hinauswischt. Gezeichnet wird sie in dieser Zeit
                  // zweimal — einmal auf jedem Weg-Abschnitt.
                  //
                  // Drei Abschnitte auf einer Zeitachse von 0 bis 1:
                  final roh = _wischt ? _wisch.value : 1.0;
                  final raus = _abschnitt(roh, 0.00, 0.50);
                  final reinOben = _abschnitt(roh, 0.30, 1.00);
                  final reinUnten = _abschnitt(roh, 0.05, 0.95);

                  return Stack(
                    children: [
                      // Die alte obere Karte. Sie bewegt sich NICHT — sie wird
                      // von der ankommenden überdeckt. Ein Schnappschuss aus
                      // dem Moment vor dem Weiterschalten (siehe
                      // [_advanceRound]), damit sie bis zuletzt ihre
                      // Rückmeldungsfarbe trägt.
                      if (_ausKarte != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          width: b,
                          height: flaecheHoehe,
                          child: IgnorePointer(child: _ausKarte!),
                        ),

                      // Das neue Land, das unten hereinkommt.
                      Positioned(
                        top: untenFlaeche,
                        width: b,
                        height: flaecheHoehe,
                        left: -(1 - reinUnten) * b,
                        child: KeyedSubtree(
                          key: kHlUntenKey,
                          child: _untenPanel(),
                        ),
                      ),

                      // Die wandernde Karte, Abschnitt 1: unten nach rechts
                      // hinaus. Liegt über dem neuen Land, damit sie es beim
                      // Hinauswischen verdeckt statt darunter zu verschwinden.
                      if (_wischt && raus < 1)
                        Positioned(
                          top: untenFlaeche,
                          width: b,
                          height: flaecheHoehe,
                          left: raus * b,
                          child: IgnorePointer(child: _obenPanel()),
                        ),

                      // Die wandernde Karte, Abschnitt 2: oben von links
                      // herein. Im Ruhezustand steht sie bei 0 und IST die
                      // obere Karte — deshalb hängt hier auch die Tippfläche.
                      //
                      // Die Schlüssel sind der Griff für die Tests: Sie messen
                      // darüber, ob eine Hälfte ihren Platz von Kante zu Kante
                      // füllt.
                      Positioned(
                        top: 0,
                        width: b,
                        height: flaecheHoehe,
                        left: -(1 - reinOben) * b,
                        child: GestureDetector(
                          key: kHlObenKey,
                          onTap: _tippenGesperrt ? null : () => _guess(false),
                          child: _obenPanel(),
                        ),
                      ),

                      // Das VS-Band zuletzt, damit die Karten darunter
                      // durchlaufen statt darüber.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: haelfte,
                        height: _kTrennerHoehe,
                        child: const _VsBand(),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Fortschritt eines Abschnitts der Wisch-Bewegung, weich abgerundet.
  ///
  /// [roh] ist die Gesamtzeit von 0 bis 1, [von] und [bis] schneiden daraus
  /// den Abschnitt heraus. Vor [von] liefert die Funktion 0, nach [bis] eine
  /// 1 — dadurch stehen die Karten ausserhalb ihres Abschnitts still, und die
  /// Abschnitte dürfen sich überlappen.
  double _abschnitt(double roh, double von, double bis) =>
      Curves.easeInOut.transform(((roh - von) / (bis - von)).clamp(0.0, 1.0));

  /// Die obere Karte — immer aufgedeckt.
  Widget _obenPanel() {
    return _RevealedPanel(
      country: _leftCountry,
      value: _fmt(_category.getValue(_leftCountry)!),
      label: _category.label,
      bgColor: _answered && _wahlUnten == false ? _rueckmeldung : kHintergrund,
      isCorrect: _answered && _wahlUnten == false ? _lastCorrect : null,
      hinweis: _answered && _wahlUnten == false && _rundungsGleichstand
          ? t('Fast identisch! Beide Werte zählen als richtig.')
          : null,
    );
  }

  /// Die untere Karte — verdeckt, bis geraten wurde.
  Widget _untenPanel() {
    if (!_answered) {
      return _HiddenPanel(
        country: _rightCountry,
        label: _category.label,
        onTap: _tippenGesperrt ? null : () => _guess(true),
      );
    }
    return _RevealedPanel(
      country: _rightCountry,
      value: _fmt(_category.getValue(_rightCountry)!),
      label: _category.label,
      bgColor: _wahlUnten == true ? _rueckmeldung : kHintergrund,
      isCorrect: _wahlUnten == true ? _lastCorrect : null,
      hinweis: _wahlUnten == true && _rundungsGleichstand
          ? t('Fast identisch! Beide Werte zählen als richtig.')
          : null,
    );
  }

  // ── Game Over ─────────────────────────────────────────────────────────────
  //
  // Kopf, Punktzahl und Fertig-Knopf stehen wie bisher fest an ihrem Platz.
  // GEÄNDERT HAT SICH NUR DER VERLAUF darunter: Wo vorher alle Runden
  // untereinander in einem Scrollbereich standen, liegt jetzt ein wischbarer
  // Kartenstapel mit Punktreihe (siehe ergebnis_karten.dart, dieselbe Bauform
  // wie beim Willkommens-Screen).
  //
  // AUFTEILUNG DER KARTEN
  //
  //   Karte 1 … n  Die richtigen Runden, [_rundenProKarte] je Karte.
  //
  // DER FEHLER HÄNGT SICH AN DIE LETZTE KARTE, wenn er dort noch Platz hat —
  // sonst bekommt er eine eigene. Er ist rund [_kFehlerZeilen] Zeilen hoch;
  // bleiben auf der letzten Karte so viele frei, gehört er dorthin. Eine
  // fast leere Karte nur für den Fehler wäre eine Karte zu viel, und man
  // sieht Serie und Abbruch lieber zusammen.
  //
  // Bei einer Serie ohne Fehler (Fragen ausgegangen) fällt er weg, bei einer
  // Serie ohne richtige Runde steht er allein.

  /// Wie viele Runden-Zeilen der Fehler-Block belegt.
  ///
  /// Ausgemessen: Überschrift (19) plus Kasten mit Flaggenzeile, Wahl und
  /// Werten (83) plus Abstand — rund 110 gegen 46 einer Zeile, aufgerundet
  /// also drei.
  static const int _kFehlerZeilen = 3;

  /// Wie viele richtige Runden auf eine Verlaufskarte passen.
  ///
  /// Eine Zeile ist 20 Innenrand + 12er Schrift + 8 Abstand hoch; gerechnet
  /// wird mit 46, damit auch bei zwei Zeilen Ländername nichts überläuft.
  ///
  /// [abzugOben] deckt Punktzahl-Block und Trennstrich ab — der grösste
  /// Brocken der Seite und der Grund, warum hier weniger Zeilen passen als
  /// auf einer Karte, die den ganzen Bildschirm hätte.
  int _rundenProKarte(BuildContext context) =>
      wischZeilenProKarte(context, zeilenHoehe: 46, abzugOben: 230);

  Widget _buildGameOver() {
    final richtige = _historie.where((r) => r.warRichtig).toList();
    final fehler = _historie.where((r) => !r.warRichtig).toList();
    final proKarte = _rundenProKarte(context);

    final gruppen = <List<_HigherLowerRunde>>[];
    for (var i = 0; i < richtige.length; i += proKarte) {
      gruppen.add(richtige.sublist(
          i, i + proKarte > richtige.length ? richtige.length : i + proKarte));
    }

    // Geht sich der Fehler auf der letzten Karte noch aus?
    final fehlerAufLetzter = fehler.isNotEmpty &&
        gruppen.isNotEmpty &&
        gruppen.last.length + _kFehlerZeilen <= proKarte;
    final fehlerEigeneKarte = fehler.isNotEmpty && !fehlerAufLetzter;

    return Column(
      children: [
        ChallengeErgebnisHeader(
          titel: t('Higher or Lower'),
          kategorie: _category.label,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
          child: Column(
            children: [
              // Der eigene Bestwert stand hier und ist raus — in allen vier
              // Challenges (siehe ranking_game_screen.dart).
              const SizedBox(height: 8),
              RanglisteErgebnisKarte(
                challengeId: 'higherlower',
                eigenerWert: _score,
                punkteLabel: t('Richtige Antworten'),
                farbe: const Color(0xFF4A9E4A),
                punkteAnzeige: Text(
                  '$_score',
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
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Divider(color: Color(0xFFD0CEC8)),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _historie.isEmpty
              ? const SizedBox.shrink()
              : WischKartenStapel(
                  karten: [
                    for (var g = 0; g < gruppen.length; g++)
                      (context, hoehe) => _VerlaufKarte(
                            runden: gruppen[g],
                            vonRunde: g * proKarte + 1,
                            fehler: fehlerAufLetzter && g == gruppen.length - 1
                                ? fehler.first
                                : null,
                            format: _fmt,
                          ),
                    if (fehlerEigeneKarte)
                      (context, hoehe) =>
                          _FehlerKarte(runde: fehler.first, format: _fmt),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
          child: ChallengeFertigButton(
              onTap: () => ChallengePanelSignal.zurueckZumPanel(context)),
        ),
      ],
    );
  }
}

// ── Die Karten des Verlaufs ──────────────────────────────────────────────────

/// Ein Ausschnitt des Verlaufs: die richtigen Runden dieser Karte.
class _VerlaufKarte extends StatelessWidget {
  final List<_HigherLowerRunde> runden;

  /// Nummer der ersten Runde auf dieser Karte, für die Überschrift.
  final int vonRunde;

  /// Der Fehler, wenn er auf DIESER Karte noch Platz hat — sonst null.
  final _HigherLowerRunde? fehler;
  final String Function(double) format;

  const _VerlaufKarte({
    required this.runden,
    required this.vonRunde,
    required this.format,
    this.fehler,
  });

  @override
  Widget build(BuildContext context) {
    final bis = vonRunde + runden.length - 1;
    return WischKarte(
      innenrand: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      notfallScrollen: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vonRunde == bis
                ? t('Runde {n}', {'n': '$vonRunde'})
                : t('Runden {a}–{b}', {'a': '$vonRunde', 'b': '$bis'}),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final r in runden) _HigherLowerRundenZeile(runde: r),
          if (fehler != null) ...[
            const SizedBox(height: 4),
            _HigherLowerFehlerBlock(runde: fehler!, format: format),
          ],
        ],
      ),
    );
  }
}

/// Letzte Karte: der Fehler, der die Serie beendet hat.
class _FehlerKarte extends StatelessWidget {
  final _HigherLowerRunde runde;
  final String Function(double) format;

  const _FehlerKarte({required this.runde, required this.format});

  @override
  Widget build(BuildContext context) {
    return WischKarte(
      innenrand: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      notfallScrollen: true,
      child: _HigherLowerFehlerBlock(runde: runde, format: format),
    );
  }
}

// ── Kartenhälften ─────────────────────────────────────────────────────────────

/// Das VS-Band zwischen den beiden Hälften.
///
/// Feste Höhe [_kTrennerHoehe], damit die Hälften darüber und darunter
/// berechenbar sind — die Wisch-Bewegung braucht die Zahl.
class _VsBand extends StatelessWidget {
  const _VsBand();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Divider(height: 1, thickness: 1, color: Color(0xFFD0D0CB)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'VS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _RevealedPanel extends StatelessWidget {
  final CountryRanking country;
  final String value;
  final String label;
  final Color bgColor;
  final bool? isCorrect;
  final String? hinweis;

  const _RevealedPanel({
    required this.country,
    required this.value,
    required this.label,
    required this.bgColor,
    this.isCorrect,
    this.hinweis,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: bgColor,
      // Die Karte bekommt eine feste halbe Bildschirmhöhe, ihr Inhalt haengt
      // aber an der Systemschrift UND an der Länge des Ländernamens: bei
      // Skala 1.5 lief sie mit langen Namen (zwei Zeilen) um rund 10 px
      // ueber. Die FittedBox verkleinert dann die ganze Karte gleichmaessig,
      // statt Text abzuschneiden — passt der Inhalt, tut sie nichts, denn
      // scaleDown vergroessert nie.
      child: LayoutBuilder(
        builder: (context, platz) => FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            // Feste Breite: sonst bekaeme die Spalte in der FittedBox
            // unbegrenzte Breite und der Ländername wuerde nie umbrechen.
            width: platz.maxWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                zeigeFlagge(
                  country.iso2,
                  width: 72,
                  height: 48,
                  borderRadius: 6,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    country.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // KEIN Zeichen mehr, weder Haken noch Kreuz: Die Fläche
                // trägt die Rückmeldung allein, ein Symbol darüber sagt
                // dasselbe ein zweites Mal. Der Haken bei der richtigen
                // Antwort war schon vorher raus, jetzt folgt ihm das Kreuz
                // bei der falschen.
                //
                // Es bleibt keine Lücke zurück: Die Spalte wird schlicht
                // kürzer, und die FittedBox setzt sie weiterhin mittig in
                // die Hälfte.
                if (hinweis != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      hinweis!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4A9E4A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Runden-Karte (Game-Over-Verlauf) ────────────────────────────────────────

/// Eine richtige Runde als Zeile auf einer Verlaufskarte.
///
/// Vorher entschied EIN Widget anhand von `runde.warRichtig`, ob es eine
/// schmale Zeile oder den grossen Fehler-Block zeichnet. Getrennt, seit die
/// beiden auf verschiedenen Karten stehen: Die Karte weiss vorher, was sie
/// zeigt, und muss es nicht dem Widget überlassen.
class _HigherLowerRundenZeile extends StatelessWidget {
  final _HigherLowerRunde runde;

  const _HigherLowerRundenZeile({required this.runde});

  @override
  Widget build(BuildContext context) {
    {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8F0),
          border: Border.all(color: const Color(0xFF4A9E4A), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            zeigeFlagge(
              runde.land1Iso,
              width: 22,
              height: 15,
              borderRadius: 3,
            ),
            const SizedBox(width: 4),
            const Text(
              'vs',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            zeigeFlagge(
              runde.land2Iso,
              width: 22,
              height: 15,
              borderRadius: 3,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${runde.land1Name} vs ${runde.land2Name}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

/// Der Fehler, der das Spiel beendet hat — deutlich hervorgehoben statt gleich
/// wie die richtigen Runden dargestellt, damit auf einen Blick erkennbar ist,
/// WO die Serie endete und WARUM.
class _HigherLowerFehlerBlock extends StatelessWidget {
  final _HigherLowerRunde runde;
  final String Function(double) format;

  const _HigherLowerFehlerBlock({required this.runde, required this.format});

  @override
  Widget build(BuildContext context) {
    final deineWahl = runde.wahlHoeher ? t('höher') : t('niedriger');
    final tatsaechlich = runde.wahlHoeher ? t('niedriger') : t('höher');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            t('Hier war der Fehler'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE53935),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            border: Border.all(color: const Color(0xFFE53935), width: 2.5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        zeigeFlagge(
                          runde.land1Iso,
                          width: 28,
                          height: 19,
                          borderRadius: 3,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'vs',
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        zeigeFlagge(
                          runde.land2Iso,
                          width: 28,
                          height: 19,
                          borderRadius: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('Deine Wahl: {a} — Richtig wäre: {b}', {
                        'a': deineWahl,
                        'b': tatsaechlich,
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE53935),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${runde.land1Name}: ${format(runde.wert1)} · '
                      '${runde.land2Name}: ${format(runde.wert2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Hidden panel ──────────────────────────────────────────────────────────────

class _HiddenPanel extends StatelessWidget {
  final CountryRanking country;
  final String label;

  /// Null sperrt die Fläche — während der Wisch-Bewegung.
  final VoidCallback? onTap;

  const _HiddenPanel({
    required this.country,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: kHintergrund,
        // Wie bei der aufgedeckten Karte: passt der Inhalt bei grosser
        // Systemschrift nicht mehr in die halbe Bildschirmhoehe, wird die
        // ganze Karte gleichmaessig kleiner statt der Text abgeschnitten.
        child: LayoutBuilder(
          builder: (context, platz) => FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: platz.maxWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  zeigeFlagge(
                    country.iso2,
                    width: 72,
                    height: 48,
                    borderRadius: 6,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      country.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFD0D0CB),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      '?  ?  ?',
                      style: TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
