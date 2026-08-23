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
import '../widgets/abzeichen_popup.dart';
import '../widgets/challenge_ergebnis_header.dart';
import '../widgets/challenge_fertig_button.dart';
import '../widgets/flaggen_widget.dart' show zeigeFlagge;
import '../widgets/rangliste_ergebnis_karte.dart';
import '../widgets/rekord_badge.dart';
import '../widgets/spiel_erklaerung.dart';
import '../theme/app_theme.dart';

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

class _HigherLowerScreenState extends State<HigherLowerScreen> {
  static const _kId = 'higher_lower';

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
  bool _rundungsGleichstand = false;
  bool _gameOver = false;

  int? _rekord;

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
    if (widget.nurAnsicht) {
      _ladeHeutigesErgebnis();
    } else {
      _ladeUndStarte();
    }
  }

  /// Zeigt das heute bereits erzielte Ergebnis erneut an, ohne eine neue
  /// Runde zu starten (siehe HigherLowerScreen.nurAnsicht).
  Future<void> _ladeHeutigesErgebnis() async {
    _rekord = await ChallengeRekordService.getRekord(_kId);
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
    _rekord = await ChallengeRekordService.getRekord(_kId);
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

  void _advanceRound() {
    final neuesLand = _naechstesLand();
    setState(() {
      _leftCountry = _rightCountry;
      _rightCountry = neuesLand;
    });
  }

  void _guess(bool guessHigher) {
    if (_answered || _gameOver) return;

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
      _rundungsGleichstand = rundungsGleichstand;
    });

    Future.delayed(const Duration(milliseconds: 1100), () async {
      if (!mounted) return;
      if (correct) {
        _advanceRound();
        setState(() {
          _score++;
          _answered = false;
          _lastCorrect = null;
        });
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
    _rekord = await ChallengeRekordService.getRekord(_kId);
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

  Widget _buildGame() {
    final leftVal = _fmt(_category.getValue(_leftCountry)!);
    final rightVal = _answered
        ? _fmt(_category.getValue(_rightCountry)!)
        : null;
    final rightBg = _answered
        ? (_lastCorrect == true
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFEBEE))
        : kHintergrund;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => ChallengePanelSignal.zurueckZumPanel(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEAE5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Color(0xFF1A1A1A),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Higher or Lower'),
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _category.label,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_rekord != null)
                      Text(
                        t('Rekord: {n}', {'n': '$_rekord'}),
                        style: const TextStyle(
                          color: Color(0xFFF9A825),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              // Score (aktuelle Serie)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9A825).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '$_score',
                      style: const TextStyle(
                        color: Color(0xFFF9A825),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                    'Bei richtiger Antwort geht es mit einem neuen Land weiter und deine Serie (🏆) wächst um 1. Bei einer falschen Antwort endet die Runde.',
                  ),
                  t(
                    'Ziel: eine möglichst lange Serie richtiger Antworten in Folge erreichen. Dein bester Wert wird als Rekord gespeichert.',
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Panels ──────────────────────────────────────────────────────────
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _answered ? null : () => _guess(false),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _RevealedPanel(
                      key: ValueKey(
                        'L_${_leftCountry.iso2}_${_category.id}_$_score',
                      ),
                      country: _leftCountry,
                      value: leftVal,
                      label: _category.label,
                      bgColor: kHintergrund,
                    ),
                  ),
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFD0D0CB),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
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
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _answered
                      ? _RevealedPanel(
                          key: ValueKey(
                            'R_rev_${_rightCountry.iso2}_${_category.id}_$_score',
                          ),
                          country: _rightCountry,
                          value: rightVal!,
                          label: _category.label,
                          bgColor: rightBg,
                          isCorrect: _lastCorrect,
                          hinweis: _rundungsGleichstand
                              ? t('Fast identisch! Beide Werte zählen als richtig.')
                              : null,
                        )
                      : _HiddenPanel(
                          key: ValueKey(
                            'R_hid_${_rightCountry.iso2}_${_category.id}_$_score',
                          ),
                          country: _rightCountry,
                          label: _category.label,
                          onTap: () => _guess(true),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Game Over ─────────────────────────────────────────────────────────────

  Widget _buildGameOver() {
    final neuerRekord = _score > 0 && _score >= (_rekord ?? 0);

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
              RekordBadge(
                neuerRekord: neuerRekord,
                rekordText: _rekord != null
                    ? t('{n} Richtige in Folge', {'n': '$_rekord'})
                    : null,
              ),
              const SizedBox(height: 16),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
            child: Column(
              children: [
                if (_historie.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t('Verlauf'),
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final r in _historie)
                    _HigherLowerRundenKarte(runde: r, format: _fmt),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
          child: ChallengeFertigButton(
              onTap: () => ChallengePanelSignal.zurueckZumPanel(context)),
        ),
      ],
    );
  }
}

// ── Revealed panel ────────────────────────────────────────────────────────────

class _RevealedPanel extends StatelessWidget {
  final CountryRanking country;
  final String value;
  final String label;
  final Color bgColor;
  final bool? isCorrect;
  final String? hinweis;

  const _RevealedPanel({
    super.key,
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
                if (isCorrect != null) ...[
                  const SizedBox(height: 10),
                  Icon(
                    isCorrect!
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: isCorrect!
                        ? const Color(0xFF4A9E4A)
                        : const Color(0xFFE57373),
                    size: 28,
                  ),
                ],
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

class _HigherLowerRundenKarte extends StatelessWidget {
  final _HigherLowerRunde runde;
  final String Function(double) format;

  const _HigherLowerRundenKarte({required this.runde, required this.format});

  @override
  Widget build(BuildContext context) {
    if (runde.warRichtig) {
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
            const Icon(Icons.check_circle, color: Color(0xFF4A9E4A), size: 18),
            const SizedBox(width: 10),
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

    // Der Fehler, der das Spiel beendet hat — deutlich hervorgehoben statt
    // gleich wie die richtigen Runden dargestellt, damit auf einen Blick
    // erkennbar ist, WO die Serie endete und WARUM.
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
              const Icon(Icons.cancel, color: Color(0xFFE53935), size: 20),
              const SizedBox(width: 10),
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
  final VoidCallback onTap;

  const _HiddenPanel({
    super.key,
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
