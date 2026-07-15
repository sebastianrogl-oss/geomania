import 'dart:math';
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import '../data/country_rankings.dart';
import '../l10n/uebersetzungen.dart';
import '../services/abzeichen_service.dart';
import '../services/locale_service.dart';
import '../services/challenge_ergebnis_service.dart';
import '../services/challenge_panel_signal.dart';
import '../services/challenge_rekord_service.dart';
import '../services/daily_challenge.dart';
import '../services/daily_resume_service.dart';
import '../services/tages_seed_service.dart';
import '../services/skala_service.dart';
import '../services/rangliste_service.dart';
import '../widgets/abzeichen_popup.dart';
import '../widgets/challenge_fertig_button.dart';
import '../widgets/rangliste_ergebnis_karte.dart';
import '../widgets/rekord_badge.dart';
import '../widgets/spiel_erklaerung.dart';

// ── Question ──────────────────────────────────────────────────────────────────
//
// Nutzt dieselben Kategorien (RankingCategory aus country_rankings.dart) wie
// Higher/Lower und Ranking-Quiz, statt einer eigenen, kleineren Kategorie-Liste.

class _Frage {
  final CountryRanking land;
  final RankingCategory kat;
  _Frage(this.land, this.kat);
}

// ── Ergebnis pro Frage (für die finale 8-Fragen-Liste) ───────────────────────

class _SchaetzErgebnis {
  final String landIso;
  final String landName;
  final String kategorieLabel;
  final bool istProzentKategorie;
  final double abweichung;
  final int punkte;

  const _SchaetzErgebnis({
    required this.landIso,
    required this.landName,
    required this.kategorieLabel,
    required this.istProzentKategorie,
    required this.abweichung,
    required this.punkte,
  });

  Map<String, dynamic> toJson() => {
        'landIso': landIso,
        'landName': landName,
        'kategorieLabel': kategorieLabel,
        'istProzentKategorie': istProzentKategorie,
        'abweichung': abweichung,
        'punkte': punkte,
      };

  static _SchaetzErgebnis fromJson(Map<String, dynamic> j) => _SchaetzErgebnis(
        landIso: j['landIso'] as String,
        landName: j['landName'] as String,
        kategorieLabel: j['kategorieLabel'] as String,
        istProzentKategorie: j['istProzentKategorie'] as bool,
        abweichung: (j['abweichung'] as num).toDouble(),
        punkte: j['punkte'] as int,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PreisSchaetzenScreen extends StatefulWidget {
  /// Wenn true: zeigt nur das heute bereits erzielte Ergebnis erneut an,
  /// startet KEINE neue Runde (für "Ergebnis ansehen" im Start-Screen).
  final bool nurAnsicht;
  const PreisSchaetzenScreen({super.key, this.nurAnsicht = false});
  @override
  State<PreisSchaetzenScreen> createState() => _PreisSchaetzenScreenState();
}

class _PreisSchaetzenScreenState extends State<PreisSchaetzenScreen>
    with SingleTickerProviderStateMixin {
  static const _kMaxPts = 800;
  static const _kId = 'preis';

  late final RankingCategory _heutigeKat;
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
  final List<_SchaetzErgebnis> _alleErgebnisse = [];

  late final AnimationController _ptsCtrl;
  late Animation<double> _ptsAnim;

  @override
  void initState() {
    super.initState();
    // Tägliche Kategorie seed-basiert bestimmen (gleich den ganzen Tag)
    final katIdx = Random(TagesSeedService.seedFuer(_kId) + 999)
        .nextInt(rankingCategories.length);
    _heutigeKat = rankingCategories[katIdx];
    _ptsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _ptsAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ptsCtrl, curve: Curves.elasticOut));
    if (widget.nurAnsicht) {
      _ladeHeutigesErgebnis();
    } else {
      _ladeUndStarte();
    }
  }

  @override
  void dispose() {
    _ptsCtrl.dispose();
    super.dispose();
  }

  /// Zeigt das heute bereits erzielte Ergebnis erneut an, ohne eine neue
  /// Runde zu starten (siehe PreisSchaetzenScreen.nurAnsicht). Die 8-Fragen-
  /// Liste wird aus dem beim Abschluss gespeicherten Detail-Ergebnis
  /// rekonstruiert (ChallengeErgebnisService), nicht neu berechnet.
  Future<void> _ladeHeutigesErgebnis() async {
    _rekord = await ChallengeRekordService.getRekord(_kId);
    final heute = await ChallengeRekordService.getHeutigePunkte(_kId) ?? 0;
    final detail = await ChallengeErgebnisService.laden(_kId);
    final ergebnisseRoh = (detail?['ergebnisse'] as List<dynamic>?) ?? [];
    final ergebnisse = ergebnisseRoh
        .map((e) => _SchaetzErgebnis.fromJson(e as Map<String, dynamic>))
        .toList();
    setState(() {
      _gesamt = heute;
      _neuerRekord = _rekord != null && heute >= _rekord!;
      _alleErgebnisse
        ..clear()
        ..addAll(ergebnisse);
      _fertig = true;
    });
  }

  Future<void> _ladeUndStarte() async {
    _rekord = await ChallengeRekordService.getRekord(_kId);
    _starteFragen();

    final zwischenstand = await DailyResumeService.laden(_kId);
    if (zwischenstand == null) return;
    final idx = zwischenstand['idx'] as int? ?? 0;
    final gesamt = zwischenstand['gesamt'] as int? ?? 0;
    if (idx <= 0 || idx >= _fragen.length) return;
    final ergebnisseRoh = (zwischenstand['ergebnisse'] as List<dynamic>?) ?? [];
    final ergebnisse = ergebnisseRoh
        .map((e) => _SchaetzErgebnis.fromJson(e as Map<String, dynamic>))
        .toList();
    // _skala wurde bereits oben in _starteFragen() EINMAL für die ganze
    // Runde berechnet — hier nur noch die Startposition des Sliders für
    // die fortgesetzte Frage neu bestimmen, NICHT die Skala selbst.
    final sk = _skala!;
    final start = sk.min + TagesSeedService.startBruch(idx) * (sk.max - sk.min);
    setState(() {
      _idx = idx;
      _gesamt = gesamt;
      _sliderVal = start.clamp(sk.min, sk.max);
      _beantwortet = false;
      _letztePts = 0;
      _abweichung = 0;
      _alleErgebnisse
        ..clear()
        ..addAll(ergebnisse);
    });
  }

  Future<void> _zwischenstandSpeichern() async {
    await DailyResumeService.speichern(_kId, {
      'idx': _idx,
      'gesamt': _gesamt,
      'ergebnisse': _alleErgebnisse.map((e) => e.toJson()).toList(),
    });
  }

  void _starteFragen() {
    final kat = _heutigeKat;
    final rng = Random(TagesSeedService.seedFuer(_kId));

    // 8 verschiedene Länder für die tägliche Kategorie
    final pool = countryRankings
        .where((c) => (kat.getValue(c) ?? -1) > 0)
        .where((c) => kat.id != 'area' || (c.area ?? 0) >= 0.1)
        .toList()
      ..shuffle(rng);

    final fragen = pool.take(8).map((land) => _Frage(land, kat)).toList();

    // EINMAL pro Tages-Runde aus den ECHTEN Werten der tatsächlich gezogenen
    // 8 Länder berechnet — bleibt danach für alle 8 Fragen dieser Runde
    // unverändert (siehe SkalaService.ausRundenWerten).
    final werteDieserRunde =
        fragen.map((f) => f.kat.getValue(f.land)!).toList();
    final sk = fragen.isNotEmpty
        ? SkalaService.ausRundenWerten(kat.id, werteDieserRunde)
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
      _alleErgebnisse.clear();
    });
  }

  void _bestaetigen() {
    final q = _fragen[_idx];
    final real = q.kat.getValue(q.land)!;
    // Abweichung relativ zur gezeigten Skalenbreite (nicht zum echten Wert)
    // -> macht die Schwierigkeit über alle Kategorien/Länder fair
    // vergleichbar, statt Länder mit großen absoluten Werten zu bevorzugen
    // und Zwergstaaten/kleine Werte unfair zu bestrafen. Nutzt exakt dieselbe
    // Skala, die auch für die Slider-Marker-Positionierung gilt.
    final skalaBreite = _skala!.max - _skala!.min;
    final dev = _istProzentKategorie(q.kat.id)
        ? (_sliderVal - real).abs()
        : skalaBreite <= 0
            ? 0.0
            : ((_sliderVal - real).abs() / skalaBreite * 100).clamp(0.0, 999.0);
    final pts = _istProzentKategorie(q.kat.id)
        ? _punkteProzentKategorie(dev)
        : _punkteFuer(dev);
    _ptsCtrl.forward(from: 0);
    setState(() {
      _beantwortet = true;
      _abweichung = dev;
      _letztePts = pts;
      _gesamt += pts;
      _alleErgebnisse.add(_SchaetzErgebnis(
        landIso: q.land.iso2,
        landName: q.land.name,
        kategorieLabel: q.kat.label,
        istProzentKategorie: _istProzentKategorie(q.kat.id),
        abweichung: dev,
        punkte: pts,
      ));
    });
  }

  // Kategorien mit fester 0-100-Skala (Prozent/Index-Punkte): eine relative
  // Abweichung ((schaetzung-real)/real*100) explodiert bei kleinen realen
  // Werten (z.B. 12 % Waldanteil -> 250 % "Abweichung" bei nur 30 echten
  // Prozentpunkten Differenz). Hier zählt stattdessen die ABSOLUTE Differenz
  // in Prozentpunkten, weil das die tatsächliche "Daneben-Distanz" auf der
  // Skala widerspiegelt. Zentral in SkalaService definiert (auch für die
  // Rundenskalen-Clamp-Logik dort genutzt) statt einer zweiten, hier
  // separat gepflegten Liste.
  bool _istProzentKategorie(String id) => SkalaService.istProzentKategorie(id);

  int _punkteProzentKategorie(double abweichungPunkte) {
    if (abweichungPunkte <= 1) return 100;
    if (abweichungPunkte <= 3) return 90;
    if (abweichungPunkte <= 5) return 80;
    if (abweichungPunkte <= 10) return 60;
    if (abweichungPunkte <= 15) return 45;
    if (abweichungPunkte <= 20) return 30;
    if (abweichungPunkte <= 30) return 15;
    if (abweichungPunkte <= 40) return 5;
    return 0;
  }

  Future<void> _weiter() async {
    if (_idx + 1 >= _fragen.length) {
      _neuerRekord = await ChallengeRekordService.setzeFallsBesser(_kId, _gesamt);
      await ChallengeRekordService.speichereHeutigePunkte(_kId, _gesamt);
      await ChallengeRekordService.summeErhoehen(_kId, _gesamt.toDouble());
      await RanglisteService.ergebnisSpeichernMitBereinigung(
          challengeId: 'schaetzen', wert: _gesamt);
      await DailyChallenge.markDone(_kId);
      await DailyResumeService.loeschen(_kId);
      await ChallengeErgebnisService.speichern(_kId,
          {'ergebnisse': _alleErgebnisse.map((e) => e.toJson()).toList()});
      final neueAbzeichen = await AbzeichenService.pruefeNachChallengeAbschluss(
        heutePerfekt: _gesamt >= _kMaxPts,
        neuerRekordHeute: _neuerRekord,
      );
      if (mounted && neueAbzeichen.isNotEmpty) {
        await AbzeichenPopup.zeigen(context, neueAbzeichen);
      }
      if (!mounted) return;
      setState(() {
        _fertig = true;
        _rekord = _gesamt > (_rekord ?? 0) ? _gesamt : _rekord;
      });
      return;
    }
    final nextIdx = _idx + 1;
    // _skala bleibt für die ganze Runde unverändert (siehe _starteFragen())
    // — hier wird NUR die Slider-Startposition innerhalb dieser festen
    // Skala neu bestimmt, nicht die Skala selbst.
    final sk = _skala!;
    final start =
        sk.min + TagesSeedService.startBruch(nextIdx) * (sk.max - sk.min);
    setState(() {
      _idx = nextIdx;
      _sliderVal = start.clamp(sk.min, sk.max);
      _beantwortet = false;
      _letztePts = 0;
      _abweichung = 0;
    });
    _zwischenstandSpeichern();
  }

  // dev = Abweichung in Prozent der gezeigten Skalenbreite (siehe
  // _bestaetigen). Schwellenwerte bewusst so gewählt, dass sie sich bei
  // einer Frage in der Mitte der Skala ähnlich "anfühlen" wie die frühere,
  // auf relative Abweichung vom echten Wert kalibrierte Kurve — gelten jetzt
  // aber gleichermaßen fair für jede Position auf der Skala.
  int _punkteFuer(double dev) {
    if (dev <= 0.5) return 100;
    if (dev <= 1.5) return 95;
    if (dev <= 3) return 88;
    if (dev <= 5) return 78;
    if (dev <= 8) return 65;
    if (dev <= 12) return 50;
    if (dev <= 18) return 35;
    if (dev <= 25) return 20;
    if (dev <= 35) return 8;
    return 0;
  }

  String _labelFuer(int p) {
    if (p == 100) return t('Perfekter Treffer!');
    if (p >= 99)  return t('Fast perfekt!');
    if (p >= 95)  return t('Unglaublich nah!');
    if (p >= 90)  return t('Sehr präzise!');
    if (p >= 83)  return t('Hervorragend!');
    if (p >= 75)  return t('Sehr gut!');
    if (p >= 65)  return t('Gut gemacht!');
    if (p >= 55)  return t('Nicht schlecht!');
    if (p >= 45)  return t('Nah dran!');
    if (p >= 35)  return t('Gute Richtung!');
    if (p >= 20)  return t('Weiter üben!');
    if (p >= 10)  return t('Noch weit weg');
    if (p >= 1)   return t('Sehr weit daneben');
    return t('Daneben!');
  }

  Color _farbe(int p) {
    if (p >= 90) return const Color(0xFF4A9E4A);
    if (p >= 70) return const Color(0xFF7CB342);
    if (p >= 50) return const Color(0xFFF9A825);
    if (p >= 30) return const Color(0xFFF57C00);
    return const Color(0xFFE53935);
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

  String _fakt(_Frage q, double realVal) {
    final pool = countryRankings
        .where((c) => (q.kat.getValue(c) ?? -1) > 0)
        .toList()
      ..sort((a, b) {
        final av = q.kat.getValue(a)!;
        final bv = q.kat.getValue(b)!;
        return bv.compareTo(av);
      });
    final rank = pool.indexWhere((c) => c.iso2 == q.land.iso2) + 1;
    final name = q.land.name;
    switch (q.kat.id) {
      case 'gdpPerCapita':
        return rank <= 3
            ? '$name gehört zu den reichsten Ländern der Welt (Platz $rank).'
            : '$name liegt auf Platz $rank beim BIP pro Kopf.';
      case 'population':
        return rank == 1
            ? '$name ist das bevölkerungsreichste Land der Welt.'
            : '$name ist das $rank.-bevölkerungsreichste Land der Welt.';
      case 'area':
        return rank == 1
            ? '$name ist das größte Land der Welt nach Fläche.'
            : '$name ist das $rank.-größte Land der Welt.';
      case 'lifeExpectancy':
        return rank <= 5
            ? 'Die Lebenserwartung in $name gehört zu den höchsten weltweit.'
            : 'In $name leben die Menschen im Schnitt ${realVal.toStringAsFixed(1)} Jahre.';
      case 'minimumWage':
        return rank <= 3
            ? '$name hat einen der höchsten Mindestlöhne der Welt (Platz $rank).'
            : 'In $name liegt der Mindestlohn bei ${realVal.round()} USD im Monat (Platz $rank).';
      case 'coastline':
        return rank == 1
            ? '$name hat die längste Küstenlinie der Welt.'
            : '$name hat eine Küstenlinie von ${realVal.round()} km (Platz $rank).';
      case 'gdpTotal':
        return rank <= 3
            ? '$name gehört zu den größten Volkswirtschaften der Welt (Platz $rank).'
            : '$name erwirtschaftet ein BIP von ${_fmtGerundetOderZweiDezimal(realVal / 1e9, 'Mrd. USD')} (Platz $rank).';
      case 'internet':
        return rank <= 5
            ? '$name gehört zu den schnellsten Ländern beim Internet (Platz $rank).'
            : '$name hat eine Download-Geschwindigkeit von ${realVal.round()} Mbps (Platz $rank).';
      case 'corruption':
        return rank <= 5
            ? '$name ist eines der am wenigsten korrupten Länder weltweit (Platz $rank).'
            : '$name erreicht ${realVal.round()} von 100 Punkten im Korruptionsindex (Platz $rank).';
      case 'press_freedom':
        return rank <= 5
            ? '$name gehört zu den pressefreiesten Ländern der Welt (Platz $rank).'
            : '$name erreicht ${realVal.round()} von 100 Punkten beim Pressefreiheitsindex (Platz $rank).';
      case 'happiness':
        return rank == 1
            ? '$name ist das glücklichste Land der Welt.'
            : '$name liegt auf Platz $rank im World Happiness Report (Score: ${realVal.toStringAsFixed(2)}).';
      case 'tourism':
        return rank <= 3
            ? '$name gehört zu den top Reisezielen weltweit (Platz $rank nach Einnahmen).'
            : '$name erwirtschaftet ${_fmtGerundetOderZweiDezimal(realVal, 'Mrd. USD')} durch Tourismus (Platz $rank).';
      case 'military':
        return rank == 1
            ? '$name hat das größte Militärbudget der Welt.'
            : '$name gibt ${_fmtGerundetOderZweiDezimal(realVal, 'Mrd. USD')} für das Militär aus (Platz $rank).';
      case 'birth_rate':
        return rank == 1
            ? '$name hat die höchste Geburtenrate weltweit.'
            : 'In $name kommen im Schnitt ${realVal.toStringAsFixed(1)} Kinder pro Frau zur Welt (Platz $rank).';
      case 'forest':
        return rank <= 5
            ? '$name gehört zu den waldreichsten Ländern der Welt (Platz $rank).'
            : '${_fmtGerundetOderZweiDezimal(realVal, '%')} der Fläche von $name sind von Wald bedeckt (Platz $rank).';
      case 'alcohol':
        return rank <= 3
            ? '$name gehört zu den Ländern mit dem höchsten Alkoholkonsum der Welt (Platz $rank).'
            : 'In $name werden im Schnitt ${realVal.toStringAsFixed(1)} Liter Alkohol pro Kopf getrunken (Platz $rank).';
      case 'olympics':
        return rank == 1
            ? '$name hat die meisten Olympia-Medaillen aller Zeiten.'
            : '$name hat ${realVal.round()} olympische Medaillen gewonnen (Platz $rank).';
      case 'highest_point':
        return rank == 1
            ? '$name hat den höchsten Punkt der Welt.'
            : 'Der höchste Punkt in $name liegt auf ${realVal.round()} m (Platz $rank).';
      case 'inflation':
        return rank == 1
            ? '$name hat die höchste Inflationsrate der Welt.'
            : 'Die Inflationsrate in $name liegt bei ${realVal.toStringAsFixed(1)} % (Platz $rank).';
      case 'debt':
        return rank == 1
            ? '$name hat die höchsten Staatsschulden relativ zur Wirtschaftsleistung.'
            : 'Die Staatsschulden in $name liegen bei ${realVal.round()} % des BIP (Platz $rank).';
      default:
        return '$name liegt auf Platz $rank bei ${q.kat.label}.';
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
          onPressed: () => ChallengePanelSignal.zurueckZumPanel(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('Das große Schätzen'),
                style: const TextStyle(
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
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(t('{n} Pkt.', {'n': '$_gesamt'}),
                    style: const TextStyle(
                        color: Color(0xFF4A9E4A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ErklaerungButton(
              titel: t('Das große Schätzen — Spielregeln'),
              farbe: const Color(0xFFF9A825),
              abschnitte: [
                t('Zu einem Land und einer Kategorie (z.B. Bevölkerung, BIP pro Kopf) siehst du eine Skala mit einem Schieberegler.'),
                t('Bewege den Regler auf die Position, an der du den echten Wert vermutest, und bestätige deine Schätzung.'),
                t('Je näher deine Schätzung am tatsächlichen Wert liegt, desto mehr Punkte bekommst du für diese Frage.'),
                t('Das Spiel besteht aus mehreren Fragen hintereinander — am Ende siehst du deine Gesamtpunktzahl und alle Antworten im Überblick.'),
              ],
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
    final realVal = q.kat.getValue(q.land)!;
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
                    Text(t('🏆 Rekord:'),
                        style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Text(t('{a} / {b} Punkte',
                        {'a': '$_rekord', 'b': '$_kMaxPts'}),
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
              child: Text(t('Frage {a} von {b}',
                      {'a': '${_idx + 1}', 'b': '${_fragen.length}'}),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CountryFlag.fromCountryCode(q.land.iso2,
                        width: 80, height: 54),
                  ),
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
              Center(
                child: Text(t('Deine Schätzung'),
                    style: const TextStyle(
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
                  child: Text(t('Bestätigen'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],

            // ── Auflösung (nach Antwort) ──────────────────────────────────
            if (_beantwortet) ...[
              // Karte im App-Design-System (weiß, schwarze Outline, harter
              // Schatten) — die Punkte-Anzeige ist jetzt als farblich zur
              // Bewertung passender Header DIREKT in die Karte integriert,
              // statt isoliert darüber zu schweben.
              Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0xFF1A1A1A),
                        offset: Offset(0, 4),
                        blurRadius: 0),
                  ],
                ),
                child: Column(
                  children: [
                    // Punkte-Header — Hintergrundton richtet sich nach der
                    // Bewertung (rot bei 0-20, orange/gold bei 21-50,
                    // hellgrün bei 51-80, kräftiges Grün bei 81-100).
                    Container(
                      width: double.infinity,
                      color: _farbe(_letztePts).withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: ScaleTransition(
                        scale: _ptsAnim,
                        child: Column(
                          children: [
                            Text(t('+{n} Punkte', {'n': '$_letztePts'}),
                                style: TextStyle(
                                    color: _farbe(_letztePts),
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(_labelFuer(_letztePts),
                                style: TextStyle(
                                    color: _farbe(_letztePts),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
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
                                    Text(t('Deine Schätzung'),
                                        style: const TextStyle(
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
                                    Text(t('Richtiger Wert'),
                                        style: const TextStyle(
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
                          const SizedBox(height: 18),

                          // Visual scale track
                          _SkalaVisuell(
                            min: sk.min,
                            max: sk.max,
                            userVal: _sliderVal,
                            correctVal: realVal,
                            format: sk.format,
                          ),
                          const SizedBox(height: 14),

                          // Deviation row
                          Center(
                            child: Text(
                              _istProzentKategorie(q.kat.id)
                                  ? t('Abweichung: {n} Prozentpunkte',
                                      {'n': '${_abweichung.round()}'})
                                  : t('Abweichung: {n} % der Skala', {
                                      'n': LocaleService.istEnglisch
                                          ? _abweichung.toStringAsFixed(1)
                                          : _abweichung
                                              .toStringAsFixed(1)
                                              .replaceAll('.', ','),
                                    }),
                              style: TextStyle(
                                  color: _farbe(_letztePts),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Fact — neutrales Info-Icon statt Glühbirne, da
                          // dies eine Ergebnis-Erklärung ist, kein Fun-Fact.
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F0),
                                borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 16, color: Color(0xFF888888)),
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                        ? t('Ergebnis anzeigen')
                        : t('Weiter →'),
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
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              children: [
                RekordBadge(
                  neuerRekord: _neuerRekord,
                  rekordText: _rekord != null
                      ? t('{a} / {b} Punkte', {'a': '$_rekord', 'b': '$_kMaxPts'})
                      : null,
                ),
                const SizedBox(height: 16),
                RanglisteErgebnisKarte(
                  challengeId: 'schaetzen',
                  eigenerWert: _gesamt,
                  punkteLabel: t('Gesamtpunktzahl'),
                  farbe: const Color(0xFFF9A825),
                  punkteAnzeige: RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: '$_gesamt',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A))),
                      TextSpan(
                          text: ' / $_kMaxPts',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB0AEA8))),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Color(0xFFD0CEC8)),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: Column(
                children: [
                  if (_alleErgebnisse.isNotEmpty)
                    _ErgebnisListeKarte(
                        ergebnisse: _alleErgebnisse, farbe: _farbe),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ChallengeFertigButton(
                onTap: () => ChallengePanelSignal.zurueckZumPanel(context)),
          ),
        ],
      ),
    );
  }
}

// ── Ergebnis-Liste (alle 8 Fragen) ────────────────────────────────────────────

class _ErgebnisListeKarte extends StatelessWidget {
  final List<_SchaetzErgebnis> ergebnisse;
  final Color Function(int) farbe;

  const _ErgebnisListeKarte({required this.ergebnisse, required this.farbe});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < ergebnisse.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEE8)),
            _ErgebnisZeile(ergebnis: ergebnisse[i], farbe: farbe(ergebnisse[i].punkte)),
          ],
        ],
      ),
    );
  }
}

class _ErgebnisZeile extends StatelessWidget {
  final _SchaetzErgebnis ergebnis;
  final Color farbe;

  const _ErgebnisZeile({required this.ergebnis, required this.farbe});

  @override
  Widget build(BuildContext context) {
    final abweichungText = ergebnis.istProzentKategorie
        ? t('{n} Prozentpunkte daneben', {'n': '${ergebnis.abweichung.round()}'})
        : t('{n} % der Skala daneben', {
            'n': LocaleService.istEnglisch
                ? ergebnis.abweichung.toStringAsFixed(1)
                : ergebnis.abweichung.toStringAsFixed(1).replaceAll('.', ','),
          });
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CountryFlag.fromCountryCode(ergebnis.landIso,
                width: 36, height: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ergebnis.landName,
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${ergebnis.kategorieLabel} · $abweichungText',
                    style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${ergebnis.punkte}',
              style: TextStyle(
                  color: farbe, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
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

  static const _markerGroesse = 18.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      final userPct = ((userVal - min) / (max - min)).clamp(0.0, 1.0);
      final correctPct = ((correctVal - min) / (max - min)).clamp(0.0, 1.0);
      final userX = userPct * w;
      final correctX = correctPct * w;
      const trackTop = 30.0;
      const trackHeight = 3.0;

      return SizedBox(
        height: 58,
        child: Stack(
          children: [
            // Track
            const Positioned(
              top: trackTop,
              left: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFEAEAE5),
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
                child: SizedBox(height: trackHeight),
              ),
            ),

            // Dezente gestrichelte Verbindungslinie zwischen Schätzung und
            // echtem Wert (ersetzt die vorherige rohe volle Balkenfüllung).
            Positioned(
              top: trackTop,
              left: userX < correctX ? userX : correctX,
              width: (correctX - userX).abs(),
              height: trackHeight,
              child: CustomPaint(
                painter: _GestrichelteLinie(color: const Color(0xFFD98C82)),
              ),
            ),

            // Nutzer-Marker (blau) — größer + weißer Rand für Kontrast.
            Positioned(
              top: trackTop + trackHeight / 2 - _markerGroesse / 2,
              left: (userX - _markerGroesse / 2).clamp(0, w - _markerGroesse),
              child: _Marker(color: const Color(0xFF2196F3)),
            ),

            // Richtiger-Wert-Marker (grün) — größer + weißer Rand.
            Positioned(
              top: trackTop + trackHeight / 2 - _markerGroesse / 2,
              left:
                  (correctX - _markerGroesse / 2).clamp(0, w - _markerGroesse),
              child: _Marker(color: const Color(0xFF4A9E4A)),
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
}

class _Marker extends StatelessWidget {
  final Color color;
  const _Marker({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _SkalaVisuell._markerGroesse,
      height: _SkalaVisuell._markerGroesse,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 3,
              offset: const Offset(0, 1)),
        ],
      ),
    );
  }
}

class _GestrichelteLinie extends CustomPainter {
  final Color color;
  const _GestrichelteLinie({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    const dashWidth = 4.0;
    const dashGap = 3.0;
    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      final xEnde = (x + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, y), Offset(xEnde, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _GestrichelteLinie oldDelegate) =>
      oldDelegate.color != color;
}
