import 'dart:math';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import '../data/abzeichen_data.dart';
import '../data/country_rankings.dart';
import '../services/abzeichen_service.dart';
import '../services/challenge_ergebnis_service.dart';
import '../services/challenge_panel_signal.dart';
import '../services/challenge_rekord_service.dart';
import '../services/daily_challenge.dart';
import '../services/daily_resume_service.dart';
import '../services/tages_seed_service.dart';
import '../services/rangliste_service.dart';
import '../widgets/abzeichen_popup.dart';
import '../widgets/rangliste_ergebnis_karte.dart';

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

  static _HigherLowerRunde fromJson(Map<String, dynamic> j) => _HigherLowerRunde(
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
      final links = countryRankings
          .cast<CountryRanking?>()
          .firstWhere((c) => c?.iso2 == zwischenstand['leftIso2'], orElse: () => null);
      final rechts = countryRankings
          .cast<CountryRanking?>()
          .firstWhere((c) => c?.iso2 == zwischenstand['rightIso2'], orElse: () => null);
      if (links != null && rechts != null) {
        final historieRoh =
            (zwischenstand['historie'] as List<dynamic>?) ?? [];
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
    _seedLaender = countryRankings
        .where((c) => _category.getValue(c) != null)
        .toList()
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
    final pool = countryRankings
        .where((c) =>
            _category.getValue(c) != null && c.iso2 != _rightCountry.iso2)
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
    final bool correct = leftVal == rightVal ||
        (guessHigher ? rightVal > leftVal : rightVal < leftVal);

    _historie.add(_HigherLowerRunde(
      land1Iso: _leftCountry.iso2,
      land1Name: _leftCountry.name,
      land2Iso: _rightCountry.iso2,
      land2Name: _rightCountry.name,
      wert1: leftVal,
      wert2: rightVal,
      wahlHoeher: guessHigher,
      warRichtig: correct,
    ));

    setState(() {
      _answered = true;
      _lastCorrect = correct;
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
    final neuerRekord = await ChallengeRekordService.setzeFallsBesser(_kId, _score);
    await ChallengeRekordService.speichereHeutigePunkte(_kId, _score);
    await ChallengeRekordService.summeErhoehen(_kId, _score.toDouble());
    await ChallengeErgebnisService.speichern(_kId, {
      'categoryId': _category.id,
      'wrongIso2': _rightCountry.iso2,
      'historie': _historie.map((e) => e.toJson()).toList(),
    });
    _rekord = await ChallengeRekordService.getRekord(_kId);
    await RanglisteService.ergebnisSpeichern(
        challengeId: 'higherlower', wert: _score);
    await DailyChallenge.markDone(_kId);
    await DailyResumeService.loeschen(_kId);
    // "Perfekt" hat für Higher-or-Lower kein natürliches Maximum (Serie ohne
    // Deckel) -> hier bewusst nie ausgelöst, nur über Preis/Ranking möglich.
    return AbzeichenService.pruefeNachChallengeAbschluss(
      neuerRekordHeute: neuerRekord,
    );
  }

  String _fmt(double v) {
    switch (_category.id) {
      case 'population':
        if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2).replaceAll('.', ',')} Mrd.';
        if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1).replaceAll('.', ',')} Mio.';
        return _fmtInt(v.toInt());
      case 'area':
        if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2).replaceAll('.', ',')} Mio. km²';
        return '${_fmtInt(v.toInt())} km²';
      case 'gdpPerCapita':    return '\$ ${_fmtInt(v.toInt())}';
      case 'gdpTotal':
        if (v >= 1e12) return '\$ ${(v / 1e12).toStringAsFixed(1).replaceAll('.', ',')} Bio.';
        if (v >= 1e9) return '\$ ${(v / 1e9).toStringAsFixed(0)} Mrd.';
        return '\$ ${(v / 1e6).toStringAsFixed(0)} Mio.';
      case 'lifeExpectancy':  return '${v.toStringAsFixed(1)} Jahre';
      case 'coastline':       return '${_fmtInt(v.toInt())} km';
      case 'minimumWage':     return '\$ ${_fmtInt(v.toInt())}/Mo.';
      case 'internet':        return '${v.round()} Mbps';
      case 'corruption':      return '${v.round()} / 100';
      case 'press_freedom':   return '${v.round()} / 100';
      case 'happiness':       return v.toStringAsFixed(2).replaceAll('.', ',');
      case 'tourism':         return '${v.round()} Mrd. \$';
      case 'military':        return '${v.round()} Mrd. \$';
      case 'birth_rate':      return '${v.toStringAsFixed(1).replaceAll('.', ',')} K/Frau';
      case 'forest':          return '${v.round()} %';
      case 'alcohol':         return '${v.toStringAsFixed(1).replaceAll('.', ',')} L/Kopf';
      case 'olympics':        return '${v.toInt()} Medaillen';
      case 'highest_point':   return '${_fmtInt(v.toInt())} m';
      case 'inflation':       return '${v.toStringAsFixed(1).replaceAll('.', ',')} %';
      case 'debt':            return '${v.toStringAsFixed(1).replaceAll('.', ',')} % BIP';
      default:                return '${v.toStringAsFixed(1)} ${_category.unit}';
    }
  }

  String _fmtInt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
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
    final rightVal = _answered ? _fmt(_category.getValue(_rightCountry)!) : null;
    final rightBg = _answered
        ? (_lastCorrect == true
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFEBEE))
        : const Color(0xFFF5F5F0);

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
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Color(0xFF1A1A1A), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Higher or Lower',
                        style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    Text(_category.label,
                        style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    if (_rekord != null)
                      Text('Rekord: $_rekord',
                          style: const TextStyle(
                              color: Color(0xFFF9A825),
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              // Score (aktuelle Serie)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                    color:
                        const Color(0xFFF9A825).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Text('🏆', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text('$_score',
                      style: const TextStyle(
                          color: Color(0xFFF9A825),
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ]),
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
                          'L_${_leftCountry.iso2}_${_category.id}_$_score'),
                      country: _leftCountry,
                      value: leftVal,
                      label: _category.label,
                      bgColor: const Color(0xFFF5F5F0),
                    ),
                  ),
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  const Divider(height: 1, thickness: 1, color: Color(0xFFD0D0CB)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('VS',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2)),
                  ),
                ],
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _answered
                      ? _RevealedPanel(
                          key: ValueKey(
                              'R_rev_${_rightCountry.iso2}_${_category.id}_$_score'),
                          country: _rightCountry,
                          value: rightVal!,
                          label: _category.label,
                          bgColor: rightBg,
                          isCorrect: _lastCorrect,
                        )
                      : _HiddenPanel(
                          key: ValueKey(
                              'R_hid_${_rightCountry.iso2}_${_category.id}_$_score'),
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
    final emoji = _score >= 15 ? '🏆' : _score >= 8 ? '👍' : '📚';
    final neuerRekord = _score > 0 && _score >= (_rekord ?? 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          const Text('Spiel vorbei!',
              style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Kategorie: ${_category.label}',
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),

          if (_rekord != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFEAEAE5),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏆 Rekord:',
                      style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text('$_rekord Richtige in Folge',
                      style: const TextStyle(
                          color: Color(0xFFF9A825),
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          RanglisteErgebnisKarte(
            challengeId: 'higherlower',
            eigenerWert: _score,
            punkteLabel: 'Richtige Antworten',
            farbe: const Color(0xFF4A9E4A),
            punkteAnzeige: Text('$_score',
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A))),
          ),

          if (neuerRekord) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('🏆 Neuer Rekord!',
                  style: TextStyle(
                      color: Color(0xFF856404),
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
          ],

          if (_historie.isNotEmpty) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Verlauf',
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            for (final r in _historie)
              _HigherLowerRundenKarte(runde: r, format: _fmt),
          ],
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => ChallengePanelSignal.zurueckZumPanel(context),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: const Color(0xFF4A9E4A),
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Text('Weiter',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
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

  const _RevealedPanel({
    super.key,
    required this.country,
    required this.value,
    required this.label,
    required this.bgColor,
    this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      color: bgColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CountryFlag.fromCountryCode(country.iso2,
                width: 72, height: 48),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(country.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14)),
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 21,
                    fontWeight: FontWeight.w800)),
          ),
          if (isCorrect != null) ...[
            const SizedBox(height: 10),
            Icon(
              isCorrect! ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isCorrect!
                  ? const Color(0xFF4A9E4A)
                  : const Color(0xFFE57373),
              size: 28,
            ),
          ],
        ],
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
            const Icon(Icons.check_circle,
                color: Color(0xFF4A9E4A), size: 18),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: CountryFlag.fromCountryCode(runde.land1Iso,
                  width: 22, height: 15),
            ),
            const SizedBox(width: 4),
            const Text('vs',
                style: TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: CountryFlag.fromCountryCode(runde.land2Iso,
                  width: 22, height: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${runde.land1Name} vs ${runde.land2Name}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    // Der Fehler, der das Spiel beendet hat — deutlich hervorgehoben statt
    // gleich wie die richtigen Runden dargestellt, damit auf einen Blick
    // erkennbar ist, WO die Serie endete und WARUM.
    final deineWahl = runde.wahlHoeher ? 'höher' : 'niedriger';
    final tatsaechlich = runde.wahlHoeher ? 'niedriger' : 'höher';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('Hier war der Fehler',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE53935),
                  letterSpacing: 0.5)),
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
                  blurRadius: 8),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: CountryFlag.fromCountryCode(runde.land1Iso,
                              width: 28, height: 19),
                        ),
                        const SizedBox(width: 6),
                        const Text('vs',
                            style: TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: CountryFlag.fromCountryCode(runde.land2Iso,
                              width: 28, height: 19),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                        'Deine Wahl: $deineWahl — Richtig wäre: $tatsaechlich',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE53935))),
                    const SizedBox(height: 2),
                    Text(
                        '${runde.land1Name}: ${format(runde.wert1)} · '
                        '${runde.land2Name}: ${format(runde.wert2)}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF888888))),
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
        color: const Color(0xFFF5F5F0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CountryFlag.fromCountryCode(country.iso2,
                width: 72, height: 48),
          ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(country.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xFFD0D0CB), width: 1)),
              child: const Text('?  ?  ?',
                  style: TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6)),
            ),
          ],
        ),
      ),
    );
  }
}
