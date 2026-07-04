import 'dart:math';
import 'package:flutter/material.dart';
import '../data/country_rankings.dart';
import '../data/laender_daten.dart';
import '../services/challenge_rekord_service.dart';
import '../services/tages_seed_service.dart';
import '../services/skala_service.dart';
import '../services/rangliste_service.dart';

// ── Category ──────────────────────────────────────────────────────────────────

enum _Kat {
  bipProKopf, bevoelkerung, flaeche, lebenserwartung,
  internetGeschwindigkeit, korruptionsIndex, pressefreiheit,
  gluecksIndex, tourismusEinnahmen, militaerAusgaben,
  urbanisierung, geburtenrate, waldanteil, erneuerbareEnergie,
}

extension _KatX on _Kat {
  String get label => switch (this) {
    _Kat.bipProKopf             => 'BIP pro Kopf',
    _Kat.bevoelkerung           => 'Bevölkerung',
    _Kat.flaeche                => 'Fläche',
    _Kat.lebenserwartung        => 'Lebenserwartung',
    _Kat.internetGeschwindigkeit=> 'Internetgeschwindigkeit',
    _Kat.korruptionsIndex       => 'Korruptionsindex',
    _Kat.pressefreiheit         => 'Pressefreiheitsindex',
    _Kat.gluecksIndex           => 'Glücksindex',
    _Kat.tourismusEinnahmen     => 'Tourismuseinnahmen',
    _Kat.militaerAusgaben       => 'Militärausgaben',
    _Kat.urbanisierung          => 'Urbanisierungsrate',
    _Kat.geburtenrate           => 'Geburtenrate',
    _Kat.waldanteil             => 'Waldanteil',
    _Kat.erneuerbareEnergie     => 'Erneuerbare Energien',
  };
  double? wert(CountryRanking c) => switch (this) {
    _Kat.bipProKopf             => c.gdpPerCapita,
    _Kat.bevoelkerung           => c.population?.toDouble(),
    _Kat.flaeche                => c.area,
    _Kat.lebenserwartung        => c.lifeExpectancy,
    _Kat.internetGeschwindigkeit=> internetGeschwindigkeit[c.iso2],
    _Kat.korruptionsIndex       => korruptionsIndex[c.iso2],
    _Kat.pressefreiheit         => pressefreiheit[c.iso2],
    _Kat.gluecksIndex           => gluecksIndex[c.iso2],
    _Kat.tourismusEinnahmen     => tourismusEinnahmen[c.iso2],
    _Kat.militaerAusgaben       => militaerAusgaben[c.iso2],
    _Kat.urbanisierung          => urbanisierung[c.iso2],
    _Kat.geburtenrate           => geburtenrate[c.iso2],
    _Kat.waldanteil             => waldanteil[c.iso2],
    _Kat.erneuerbareEnergie     => erneuerbareEnergie[c.iso2],
  };
  SkalaErgebnis skala(double realVal) => switch (this) {
    _Kat.bipProKopf             => SkalaService.bipProKopf(realVal),
    _Kat.bevoelkerung           => SkalaService.bevoelkerung(realVal),
    _Kat.flaeche                => SkalaService.flaeche(realVal),
    _Kat.lebenserwartung        => SkalaService.lebenserwartung(realVal),
    _Kat.internetGeschwindigkeit=> SkalaService.internetGeschwindigkeit(realVal),
    _Kat.korruptionsIndex       => SkalaService.korruptionsIndex(realVal),
    _Kat.pressefreiheit         => SkalaService.pressefreiheit(realVal),
    _Kat.gluecksIndex           => SkalaService.gluecksIndex(realVal),
    _Kat.tourismusEinnahmen     => SkalaService.tourismusEinnahmen(realVal),
    _Kat.militaerAusgaben       => SkalaService.militaerAusgaben(realVal),
    _Kat.urbanisierung          => SkalaService.urbanisierung(realVal),
    _Kat.geburtenrate           => SkalaService.geburtenrate(realVal),
    _Kat.waldanteil             => SkalaService.waldanteil(realVal),
    _Kat.erneuerbareEnergie     => SkalaService.erneuerbareEnergie(realVal),
  };
}

// ── Question ──────────────────────────────────────────────────────────────────

class _Frage {
  final CountryRanking land;
  final _Kat kat;
  _Frage(this.land, this.kat);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PreisSchaetzenScreen extends StatefulWidget {
  const PreisSchaetzenScreen({super.key});
  @override
  State<PreisSchaetzenScreen> createState() => _PreisSchaetzenScreenState();
}

class _PreisSchaetzenScreenState extends State<PreisSchaetzenScreen>
    with SingleTickerProviderStateMixin {
  static const _kMaxPts = 800;
  static const _kId = 'preis';

  late final _Kat _heutigeKat;
  List<_Frage> _fragen = [];
  int _idx = 0;
  SkalaErgebnis? _skala;
  double _sliderVal = 50;
  bool _beantwortet = false;
  bool _fertig = false;
  int _gesamt = 0;
  int _letztePts = 0;
  double _abweichung = 0;
  int? _rekord;
  bool _neuerRekord = false;

  late final AnimationController _ptsCtrl;
  late Animation<double> _ptsAnim;

  @override
  void initState() {
    super.initState();
    // Tägliche Kategorie seed-basiert bestimmen (gleich den ganzen Tag)
    final katIdx = Random(TagesSeedService.seedFuer(_kId) + 999)
        .nextInt(_Kat.values.length);
    _heutigeKat = _Kat.values[katIdx];
    _ptsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _ptsAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ptsCtrl, curve: Curves.elasticOut));
    _ladeUndStarte();
  }

  @override
  void dispose() {
    _ptsCtrl.dispose();
    super.dispose();
  }

  Future<void> _ladeUndStarte() async {
    _rekord = await ChallengeRekordService.getRekord(_kId);
    _starteFragen();
  }

  void _starteFragen() {
    final kat = _heutigeKat;
    final rng = Random(TagesSeedService.seedFuer(_kId));

    // 8 verschiedene Länder für die tägliche Kategorie
    final pool = countryRankings
        .where((c) => (kat.wert(c) ?? -1) > 0)
        .where((c) => kat != _Kat.flaeche || (c.area ?? 0) >= 0.1)
        .toList()
      ..shuffle(rng);

    final fragen = pool.take(8).map((land) => _Frage(land, kat)).toList();

    final sk = fragen.isNotEmpty
        ? fragen.first.kat.skala(fragen.first.kat.wert(fragen.first.land)!)
        : null;
    final start = sk != null
        ? sk.min + TagesSeedService.startBruch(0) * (sk.max - sk.min)
        : 50.0;

    setState(() {
      _fragen = fragen;
      _idx = 0;
      _skala = sk;
      _sliderVal = start.clamp(sk?.min ?? 0, sk?.max ?? 100);
      _gesamt = 0;
      _fertig = false;
      _beantwortet = false;
      _letztePts = 0;
      _abweichung = 0;
      _neuerRekord = false;
    });
  }

  void _bestaetigen() {
    final q = _fragen[_idx];
    final real = q.kat.wert(q.land)!;
    final dev = ((_sliderVal - real).abs() / real * 100).clamp(0.0, 999.0);
    final pts = _punkteFuer(dev);
    _ptsCtrl.forward(from: 0);
    setState(() {
      _beantwortet = true;
      _abweichung = dev;
      _letztePts = pts;
      _gesamt += pts;
    });
  }

  Future<void> _weiter() async {
    if (_idx + 1 >= _fragen.length) {
      _neuerRekord = await ChallengeRekordService.setzeFallsBesser(_kId, _gesamt);
      await ChallengeRekordService.speichereHeutigePunkte(_kId, _gesamt);
      await RanglisteService.ergebnisSpeichern(
          challengeId: 'schaetzen', wert: _gesamt);
      setState(() {
        _fertig = true;
        _rekord = _gesamt > (_rekord ?? 0) ? _gesamt : _rekord;
      });
      return;
    }
    final nextIdx = _idx + 1;
    final q = _fragen[nextIdx];
    final realVal = q.kat.wert(q.land)!;
    final sk = q.kat.skala(realVal);
    final start =
        sk.min + TagesSeedService.startBruch(nextIdx) * (sk.max - sk.min);
    setState(() {
      _idx = nextIdx;
      _skala = sk;
      _sliderVal = start.clamp(sk.min, sk.max);
      _beantwortet = false;
      _letztePts = 0;
      _abweichung = 0;
    });
  }

  int _punkteFuer(double dev) {
    double p;
    if (dev == 0) {
      p = 100;
    } else if (dev <= 1) {
      p = 100 - dev;
    } else if (dev <= 2) {
      p = 99 - (dev - 1) * 4;
    } else if (dev <= 5) {
      p = 95 - (dev - 2) * 4;
    } else if (dev <= 10) {
      p = 83 - (dev - 5) * 3.6;
    } else if (dev <= 15) {
      p = 65 - (dev - 10) * 3;
    } else if (dev <= 20) {
      p = 50 - (dev - 15) * 2.4;
    } else if (dev <= 30) {
      p = 38 - (dev - 20) * 1.8;
    } else if (dev <= 50) {
      p = 20 - (dev - 30) * 0.75;
    } else if (dev <= 75) {
      p = 5 - (dev - 50) * 0.16;
    } else {
      p = 1 - (dev - 75) * 0.02;
    }
    return p.round().clamp(0, 100);
  }

  String _labelFuer(int p) {
    if (p == 100) return 'Perfekter Treffer!';
    if (p >= 99)  return 'Fast perfekt!';
    if (p >= 95)  return 'Unglaublich nah!';
    if (p >= 90)  return 'Sehr präzise!';
    if (p >= 83)  return 'Hervorragend!';
    if (p >= 75)  return 'Sehr gut!';
    if (p >= 65)  return 'Gut gemacht!';
    if (p >= 55)  return 'Nicht schlecht!';
    if (p >= 45)  return 'Nah dran!';
    if (p >= 35)  return 'Gute Richtung!';
    if (p >= 20)  return 'Weiter üben!';
    if (p >= 10)  return 'Noch weit weg';
    if (p >= 1)   return 'Sehr weit daneben';
    return 'Daneben!';
  }

  Color _farbe(int p) {
    if (p >= 90) return const Color(0xFF4A9E4A);
    if (p >= 70) return const Color(0xFF7CB342);
    if (p >= 50) return const Color(0xFFF9A825);
    if (p >= 30) return const Color(0xFFF57C00);
    return const Color(0xFFE53935);
  }

  String _fakt(_Frage q, double realVal) {
    final pool = countryRankings
        .where((c) => (q.kat.wert(c) ?? -1) > 0)
        .toList()
      ..sort((a, b) {
        final av = q.kat.wert(a)!;
        final bv = q.kat.wert(b)!;
        return bv.compareTo(av);
      });
    final rank = pool.indexWhere((c) => c.iso2 == q.land.iso2) + 1;
    final name = q.land.name;
    switch (q.kat) {
      case _Kat.bipProKopf:
        return rank <= 3
            ? '$name gehört zu den reichsten Ländern der Welt (Platz $rank).'
            : '$name liegt auf Platz $rank beim BIP pro Kopf.';
      case _Kat.bevoelkerung:
        return rank == 1
            ? '$name ist das bevölkerungsreichste Land der Welt.'
            : '$name ist das $rank.-bevölkerungsreichste Land der Welt.';
      case _Kat.flaeche:
        return rank == 1
            ? '$name ist das größte Land der Welt nach Fläche.'
            : '$name ist das $rank.-größte Land der Welt.';
      case _Kat.lebenserwartung:
        return rank <= 5
            ? 'Die Lebenserwartung in $name gehört zu den höchsten weltweit.'
            : 'In $name leben die Menschen im Schnitt ${realVal.toStringAsFixed(1)} Jahre.';
      case _Kat.internetGeschwindigkeit:
        return rank <= 5
            ? '$name gehört zu den schnellsten Ländern beim Internet (Platz $rank).'
            : '$name hat eine Download-Geschwindigkeit von ${realVal.round()} Mbps (Platz $rank).';
      case _Kat.korruptionsIndex:
        return rank <= 5
            ? '$name ist eines der am wenigsten korrupten Länder weltweit (Platz $rank).'
            : '$name erreicht ${realVal.round()} von 100 Punkten im Korruptionsindex (Platz $rank).';
      case _Kat.pressefreiheit:
        return rank <= 5
            ? '$name gehört zu den pressefreiesten Ländern der Welt (Platz $rank).'
            : '$name erreicht ${realVal.round()} von 100 Punkten beim Pressefreiheitsindex (Platz $rank).';
      case _Kat.gluecksIndex:
        return rank == 1
            ? '$name ist das glücklichste Land der Welt.'
            : '$name liegt auf Platz $rank im World Happiness Report (Score: ${realVal.toStringAsFixed(2)}).';
      case _Kat.tourismusEinnahmen:
        return rank <= 3
            ? '$name gehört zu den top Reisezielen weltweit (Platz $rank nach Einnahmen).'
            : '$name erwirtschaftet ${realVal.round()} Mrd. USD durch Tourismus (Platz $rank).';
      case _Kat.militaerAusgaben:
        return rank == 1
            ? '$name hat das größte Militärbudget der Welt.'
            : '$name gibt ${realVal.round()} Mrd. USD für das Militär aus (Platz $rank).';
      case _Kat.urbanisierung:
        return rank <= 3
            ? '$name ist eines der am stärksten urbanisierten Länder der Welt (Platz $rank).'
            : '${realVal.round()} % der Bevölkerung in $name leben in Städten (Platz $rank).';
      case _Kat.geburtenrate:
        return rank == 1
            ? '$name hat die höchste Geburtenrate weltweit.'
            : 'In $name kommen im Schnitt ${realVal.toStringAsFixed(1)} Kinder pro Frau zur Welt (Platz $rank).';
      case _Kat.waldanteil:
        return rank <= 5
            ? '$name gehört zu den waldreichsten Ländern der Welt (Platz $rank).'
            : '${realVal.round()} % der Fläche von $name sind von Wald bedeckt (Platz $rank).';
      case _Kat.erneuerbareEnergie:
        return rank <= 5
            ? '$name erzeugt fast seinen gesamten Strom aus erneuerbaren Quellen (Platz $rank).'
            : '${realVal.round()} % des Stroms in $name kommen aus erneuerbaren Quellen (Platz $rank).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Das große Schätzen',
                style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            Text(_heutigeKat.label,
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        centerTitle: true,
        actions: [
          if (!_fertig && _gesamt > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('$_gesamt Pkt.',
                    style: const TextStyle(
                        color: Color(0xFF4A9E4A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
      body: _fertig ? _buildErgebnis() : _buildQuiz(),
    );
  }

  // ── Quiz ──────────────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    if (_fragen.isEmpty || _skala == null) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF4A9E4A)));
    }
    final q = _fragen[_idx];
    final realVal = q.kat.wert(q.land)!;
    final sk = _skala!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Rekord-Banner ────────────────────────────────────────────
            if (_rekord != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFFEAEAE5),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Text('🏆 Rekord:',
                        style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text('$_rekord / $_kMaxPts Punkte',
                        style: const TextStyle(
                            color: Color(0xFFF9A825),
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // ── Fortschritt ──────────────────────────────────────────────
            Row(
              children: List.generate(_fragen.length, (i) {
                final col = i < _idx
                    ? const Color(0xFF4A9E4A)
                    : i == _idx
                        ? const Color(0xFF4A9E4A).withValues(alpha: 0.4)
                        : const Color(0xFFD0D0CB);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 5,
                    decoration: BoxDecoration(
                        color: col, borderRadius: BorderRadius.circular(3)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text('Frage ${_idx + 1} von ${_fragen.length}',
                  style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 18),

            // ── Länder-Karte ─────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(24),
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
              child: Column(
                children: [
                  Text(q.land.flagEmoji,
                      style: const TextStyle(fontSize: 58)),
                  const SizedBox(height: 10),
                  Text(q.land.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9E4A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(q.kat.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Slider (vor Antwort) ──────────────────────────────────────
            if (!_beantwortet) ...[
              Center(
                child: Text(sk.format(_sliderVal),
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 32,
                        fontWeight: FontWeight.w800)),
              ),
              const Center(
                child: Text('Deine Schätzung',
                    style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              Slider(
                value: _sliderVal.clamp(sk.min, sk.max),
                min: sk.min,
                max: sk.max,
                divisions: sk.divisionen,
                activeColor: const Color(0xFF4A9E4A),
                inactiveColor: const Color(0xFFD0D0CB),
                onChanged: (v) => setState(() => _sliderVal = v),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sk.format(sk.min),
                        style: const TextStyle(
                            color: Color(0xFFBBBBBB), fontSize: 10)),
                    Text(sk.format(sk.max),
                        style: const TextStyle(
                            color: Color(0xFFBBBBBB), fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _bestaetigen,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A9E4A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: const Text('Bestätigen',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],

            // ── Auflösung (nach Antwort) ──────────────────────────────────
            if (_beantwortet) ...[
              // Points badge
              ScaleTransition(
                scale: _ptsAnim,
                child: Center(
                  child: Column(
                    children: [
                      Text('+$_letztePts Punkte',
                          style: TextStyle(
                              color: _farbe(_letztePts),
                              fontSize: 36,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(_labelFuer(_letztePts),
                          style: TextStyle(
                              color: _farbe(_letztePts),
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Scale visual
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3))
                    ]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Values row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Deine Schätzung',
                                  style: TextStyle(
                                      color: Color(0xFF2196F3),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                              Text(sk.format(_sliderVal),
                                  style: const TextStyle(
                                      color: Color(0xFF2196F3),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Richtiger Wert',
                                  style: TextStyle(
                                      color: Color(0xFF4A9E4A),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                              Text(sk.format(realVal),
                                  style: const TextStyle(
                                      color: Color(0xFF4A9E4A),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Visual scale track
                    _SkalaVisuell(
                      min: sk.min,
                      max: sk.max,
                      userVal: _sliderVal,
                      correctVal: realVal,
                      format: sk.format,
                    ),
                    const SizedBox(height: 12),

                    // Deviation row
                    Center(
                      child: Text(
                        'Abweichung: ${_abweichung.toStringAsFixed(1).replaceAll('.', ',')} %',
                        style: TextStyle(
                            color: _farbe(_letztePts),
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Fact
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F0),
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Text('💡',
                              style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_fakt(q, realVal),
                                style: const TextStyle(
                                    color: Color(0xFF555555),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: _weiter,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: const Color(0xFF4A9E4A),
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _idx + 1 >= _fragen.length
                        ? 'Ergebnis anzeigen'
                        : 'Weiter →',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Ergebnis ──────────────────────────────────────────────────────────────

  Widget _buildErgebnis() {
    final pct = (_gesamt / _kMaxPts * 100).round();
    final emoji = pct >= 80 ? '🎯' : pct >= 50 ? '👍' : '📚';
    final grade = pct >= 80
        ? 'Ausgezeichnet!'
        : pct >= 50
            ? 'Gut gemacht!'
            : 'Weiter üben!';
    final ringColor = pct >= 80
        ? const Color(0xFF4A9E4A)
        : pct >= 50
            ? const Color(0xFFF9A825)
            : const Color(0xFFE53935);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Text(emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 14),
            Text(grade,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('$_gesamt / $_kMaxPts Punkte',
                style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            if (_neuerRekord) ...[
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
            const SizedBox(height: 28),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEAEAE5),
                border: Border.all(color: ringColor, width: 6),
              ),
              child: Center(
                child: Text('$pct %',
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 30,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: const Color(0xFFEAEAE5),
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: const Text('Zurück',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Skala-Visualisierung ──────────────────────────────────────────────────────

class _SkalaVisuell extends StatelessWidget {
  final double min, max, userVal, correctVal;
  final String Function(double) format;

  const _SkalaVisuell({
    required this.min,
    required this.max,
    required this.userVal,
    required this.correctVal,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final userPct = ((userVal - min) / (max - min)).clamp(0.0, 1.0);
      final correctPct = ((correctVal - min) / (max - min)).clamp(0.0, 1.0);
      final userX = userPct * w;
      final correctX = correctPct * w;

      return SizedBox(
        height: 52,
        child: Stack(
          children: [
            // Track
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEAE5),
                    borderRadius: BorderRadius.circular(2),
                  )),
            ),

            // Filled area between user and correct (tinted)
            Positioned(
              top: 24,
              left: userX < correctX ? userX : correctX,
              width: (correctX - userX).abs(),
              child: Container(
                height: 4,
                color: _farbe(userX, correctX),
              ),
            ),

            // User line (blue)
            Positioned(
              top: 16,
              left: (userX - 1.5).clamp(0, w - 3),
              child: Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(2))),
            ),
            // User dot
            Positioned(
              top: 19,
              left: (userX - 5).clamp(0, w - 10),
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: Color(0xFF2196F3), shape: BoxShape.circle),
              ),
            ),

            // Correct line (green)
            Positioned(
              top: 16,
              left: (correctX - 1.5).clamp(0, w - 3),
              child: Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                      color: const Color(0xFF4A9E4A),
                      borderRadius: BorderRadius.circular(2))),
            ),
            Positioned(
              top: 19,
              left: (correctX - 5).clamp(0, w - 10),
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: Color(0xFF4A9E4A), shape: BoxShape.circle),
              ),
            ),

            // Min label bottom-left
            Positioned(
              bottom: 0,
              left: 0,
              child: Text(format(min),
                  style: const TextStyle(
                      color: Color(0xFFBBBBBB),
                      fontSize: 8,
                      fontWeight: FontWeight.w600)),
            ),
            // Max label bottom-right
            Positioned(
              bottom: 0,
              right: 0,
              child: Text(format(max),
                  style: const TextStyle(
                      color: Color(0xFFBBBBBB),
                      fontSize: 8,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    });
  }

  Color _farbe(double userX, double correctX) {
    final diff = (userX - correctX).abs();
    if (diff < 20) return const Color(0xFF4A9E4A).withValues(alpha: 0.2);
    if (diff < 60) return const Color(0xFFF9A825).withValues(alpha: 0.2);
    return const Color(0xFFE53935).withValues(alpha: 0.15);
  }
}
