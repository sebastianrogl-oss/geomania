import 'dart:math';
import 'package:flutter/material.dart';
import '../data/country_rankings.dart';
import '../l10n/uebersetzungen.dart';
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
import '../widgets/rangliste_ergebnis_karte.dart';
import '../widgets/flaggen_widget.dart' show zeigeFlagge;
import '../widgets/rekord_badge.dart';
import '../widgets/spiel_erklaerung.dart';
import '../theme/app_theme.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatRang(int rang) {
  if (rang >= 100) return '#100+';
  return '#$rang';
}

int _berechnePunkte(int rang) {
  if (rang >= 100) return 0;
  return (101 - rang).clamp(0, 100);
}

// ── Zuordnung pro Kategorie ───────────────────────────────────────────────────

class _Zuordnung {
  final CountryRanking land;
  final int rang;
  final int punkte;
  const _Zuordnung(
      {required this.land, required this.rang, required this.punkte});
}

// ── Kategorie-Button ──────────────────────────────────────────────────────────

class _KatButton extends StatefulWidget {
  final String emoji;
  final String label;
  final bool zugeordnet;
  final String? flagIso2;
  final int? rang;
  final VoidCallback? onTap;

  const _KatButton({
    required this.emoji,
    required this.label,
    required this.zugeordnet,
    required this.onTap,
    this.flagIso2,
    this.rang,
  });

  @override
  State<_KatButton> createState() => _KatButtonState();
}

class _KatButtonState extends State<_KatButton> {
  bool _pressed = false;

  bool get _tappable => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final pressing = _pressed && _tappable;
    final topMargin = 5.0 + (pressing ? 4.0 : 0.0);
    final bottomMargin = 9.0 - (pressing ? 4.0 : 0.0);

    return GestureDetector(
      onTapDown: _tappable ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _tappable
          ? (_) {
              if (!_pressed) return;
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: _tappable ? () => setState(() => _pressed = false) : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: pressing ? 50 : 200),
        margin: EdgeInsets.fromLTRB(16, topMargin, 16, bottomMargin),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF1A1A1A),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1A1A),
              offset: Offset(0, pressing ? 0 : 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A)),
                ),
              ),
              if (widget.zugeordnet && widget.rang != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 1,
                  height: 16,
                  color: const Color(0xFFD0CEC8),
                ),
                if (widget.flagIso2 != null) ...[
                  zeigeFlagge(
                    widget.flagIso2!,
                    width: 24,
                    height: 16,
                    borderRadius: 2,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  _formatRang(widget.rang!),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status ────────────────────────────────────────────────────────────────────

enum _Status { laden, spielen, aufloesung }

// ── Screen ────────────────────────────────────────────────────────────────────

class RankingGameScreen extends StatefulWidget {
  /// Wenn true: zeigt nur das heute bereits erzielte Ergebnis erneut an,
  /// startet KEINE neue Runde (für "Ergebnisse" im Start-Screen).
  final bool nurAnsicht;
  const RankingGameScreen({super.key, this.nurAnsicht = false});
  @override
  State<RankingGameScreen> createState() => _RankingGameScreenState();
}

class _RankingGameScreenState extends State<RankingGameScreen> {
  static const _kId = 'ranking_game';
  static const _kAnzahl = 8;

  List<CountryRanking> _laender = [];
  List<RankingCategory> _tagesKats = [];
  Map<String, _Zuordnung> _zuordnungen = {};
  Set<String> _verwendeteKategorien = {};
  int _aktuellerIndex = 0;
  int? _rekord;
  bool _neuerRekord = false;
  _Status _status = _Status.laden;

  @override
  void initState() {
    super.initState();
    if (widget.nurAnsicht) {
      _ladeHeutigesErgebnis();
    } else {
      _init();
    }
  }

  /// Zeigt das heute bereits erzielte Ergebnis erneut an, ohne eine neue
  /// Runde zu starten (siehe RankingGameScreen.nurAnsicht). _baue() liefert
  /// dank des tages-basierten Seeds dieselben Länder/Kategorien wie beim
  /// tatsächlichen Spiel — nur die getroffene Zuordnung muss rekonstruiert
  /// werden.
  Future<void> _ladeHeutigesErgebnis() async {
    _rekord = await ChallengeRekordService.getRekord(_kId);
    final heute = await ChallengeRekordService.getHeutigePunkte(_kId) ?? 0;
    _baue();
    final detail = await ChallengeErgebnisService.laden(_kId);
    final zuordnungenRoh =
        (detail?['zuordnungen'] as Map<String, dynamic>?) ?? {};

    final neueZuordnungen = <String, _Zuordnung>{};
    for (final entry in zuordnungenRoh.entries) {
      final kat = _tagesKats.cast<RankingCategory?>().firstWhere(
          (k) => k?.id == entry.key, orElse: () => null);
      final land = _laender.cast<CountryRanking?>().firstWhere(
          (l) => l?.iso2 == entry.value, orElse: () => null);
      if (kat == null || land == null) continue;
      final rang = _weltrang(land, kat);
      neueZuordnungen[entry.key] =
          _Zuordnung(land: land, rang: rang, punkte: _berechnePunkte(rang));
    }

    setState(() {
      _zuordnungen = neueZuordnungen;
      _verwendeteKategorien = neueZuordnungen.keys.toSet();
      _aktuellerIndex = _laender.length;
      _neuerRekord = _rekord != null && heute >= _rekord!;
      _status = _Status.aufloesung;
    });
  }

  Future<void> _init() async {
    _rekord = await ChallengeRekordService.getRekord(_kId);
    _baue();

    final zwischenstand = await DailyResumeService.laden(_kId);
    if (zwischenstand == null) return;
    final zuordnungenRoh =
        (zwischenstand['zuordnungen'] as Map<String, dynamic>?) ?? {};
    if (zuordnungenRoh.isEmpty) return;

    final neueZuordnungen = <String, _Zuordnung>{};
    for (final entry in zuordnungenRoh.entries) {
      final kat = _tagesKats.firstWhere((k) => k.id == entry.key);
      final land = _laender.cast<CountryRanking?>().firstWhere(
          (l) => l?.iso2 == entry.value, orElse: () => null);
      if (land == null) continue;
      final rang = _weltrang(land, kat);
      neueZuordnungen[entry.key] =
          _Zuordnung(land: land, rang: rang, punkte: _berechnePunkte(rang));
    }
    if (neueZuordnungen.isEmpty) return;

    setState(() {
      _zuordnungen = neueZuordnungen;
      _verwendeteKategorien = neueZuordnungen.keys.toSet();
      _aktuellerIndex = neueZuordnungen.length;
    });
  }

  Future<void> _zwischenstandSpeichern() async {
    await DailyResumeService.speichern(_kId, {
      'zuordnungen': {
        for (final e in _zuordnungen.entries) e.key: e.value.land.iso2,
      },
    });
  }

  static const _kMaxZiehVersuche = 20;

  // Zieht Länder+Kategorien für einen gegebenen Versuchs-Seed (dieselbe
  // Logik wie bisher, nur als eigene Methode damit _baue() sie in einer
  // Schleife mit unterschiedlichen Seeds aufrufen kann).
  (List<CountryRanking>, List<RankingCategory>) _zieheKombination(int seed) {
    final katRng = Random(seed + 77);
    final tagesKats =
        (List.of(rankingCategories)..shuffle(katRng)).take(_kAnzahl).toList();

    final rng = Random(seed);
    final pool = countryRankings
        .where((c) =>
            c.gdpPerCapita != null &&
            c.population != null &&
            c.area != null &&
            c.lifeExpectancy != null)
        .toList()
      ..shuffle(rng);
    final laender = pool.take(_kAnzahl).toList();

    return (laender, tagesKats);
  }

  void _baue() {
    final baseSeed = TagesSeedService.seedFuer(_kId);

    var laender = <CountryRanking>[];
    var tagesKats = <RankingCategory>[];
    var versuch = 0;
    do {
      (laender, tagesKats) = _zieheKombination(baseSeed + versuch * 1000);
      versuch++;
    } while (!_istGueltigeKombination(laender, tagesKats) &&
        versuch < _kMaxZiehVersuche);

    if (!_istGueltigeKombination(laender, tagesKats)) {
      laender = _ersetzeProblematischesLand(laender, tagesKats);
    }

    setState(() {
      _tagesKats = tagesKats;
      _laender = laender;
      _zuordnungen = {};
      _verwendeteKategorien = {};
      _aktuellerIndex = 0;
      _status = _Status.spielen;
    });
  }

  // ── Faire Tageskombination: bipartites Matching (Kuhn's Algorithm) ────────
  //
  // Stellt sicher, dass für die gezogenen 8 Länder/Kategorien eine
  // VOLLSTÄNDIGE Zuordnung existiert, bei der jedes Land eine Kategorie mit
  // Weltrang < 100 bekommt — geprüft schon bei der Ziehung (_baue), nicht
  // erst nachträglich bei der Auflösung repariert.

  Map<String, List<int>> _guteKategorienGraph(
      List<CountryRanking> laender, List<RankingCategory> kategorien) {
    final graph = <String, List<int>>{};
    for (final land in laender) {
      graph[land.iso2] = [
        for (var k = 0; k < kategorien.length; k++)
          if (_weltrang(land, kategorien[k]) < 100) k,
      ];
    }
    return graph;
  }

  Map<String, String> _bipartitesMatching(List<CountryRanking> laender,
      List<RankingCategory> kategorien, Map<String, List<int>> graph) {
    final matchKatIndex = <int, String>{}; // katIndex -> iso2

    bool tryKuppeln(String iso, Set<int> besucht) {
      for (final katIdx in graph[iso]!) {
        if (besucht.contains(katIdx)) continue;
        besucht.add(katIdx);
        if (!matchKatIndex.containsKey(katIdx) ||
            tryKuppeln(matchKatIndex[katIdx]!, besucht)) {
          matchKatIndex[katIdx] = iso;
          return true;
        }
      }
      return false;
    }

    for (final land in laender) {
      tryKuppeln(land.iso2, <int>{});
    }

    final ergebnis = <String, String>{};
    matchKatIndex.forEach((katIdx, iso) {
      ergebnis[iso] = kategorien[katIdx].id;
    });
    return ergebnis;
  }

  bool _istGueltigeKombination(
      List<CountryRanking> laender, List<RankingCategory> kategorien) {
    final graph = _guteKategorienGraph(laender, kategorien);
    if (graph.values.any((liste) => liste.isEmpty)) return false;
    final matching = _bipartitesMatching(laender, kategorien, graph);
    return matching.length == laender.length;
  }

  // Äußerst unwahrscheinlicher Fallback (siehe _kMaxZiehVersuche): tauscht
  // das Land mit den wenigsten Rang<100-Optionen deterministisch gegen das
  // Land aus dem restlichen Länder-Pool mit den meisten Rang<100-Optionen.
  List<CountryRanking> _ersetzeProblematischesLand(
      List<CountryRanking> laender, List<RankingCategory> kategorien) {
    final graph = _guteKategorienGraph(laender, kategorien);
    var schlechtestesIso = laender.first.iso2;
    var minGute = graph[schlechtestesIso]!.length;
    for (final land in laender) {
      final anzahl = graph[land.iso2]!.length;
      if (anzahl < minGute) {
        minGute = anzahl;
        schlechtestesIso = land.iso2;
      }
    }

    final restPool = countryRankings.where((c) =>
        c.gdpPerCapita != null &&
        c.population != null &&
        c.area != null &&
        c.lifeExpectancy != null &&
        !laender.any((l) => l.iso2 == c.iso2));

    CountryRanking? bestesErsatz;
    var besteAnzahl = -1;
    for (final kandidat in restPool) {
      final anzahl =
          kategorien.where((k) => _weltrang(kandidat, k) < 100).length;
      if (anzahl > besteAnzahl) {
        besteAnzahl = anzahl;
        bestesErsatz = kandidat;
      }
    }
    if (bestesErsatz == null) return laender;

    return [
      for (final land in laender)
        if (land.iso2 == schlechtestesIso) bestesErsatz else land,
    ];
  }

  int _weltrang(CountryRanking land, RankingCategory kat) {
    final wert = kat.getValue(land);
    if (wert == null || wert <= 0) return 999;
    return countryRankings
            .where((c) => (kat.getValue(c) ?? 0) > wert)
            .length +
        1;
  }

  void _tippKategorie(String katId) {
    if (_verwendeteKategorien.contains(katId)) return;
    if (_aktuellerIndex >= _laender.length) return;

    final land = _laender[_aktuellerIndex];
    final kat = _tagesKats.firstWhere((k) => k.id == katId);
    final rang = _weltrang(land, kat);
    final punkte = _berechnePunkte(rang);

    setState(() {
      _zuordnungen[katId] =
          _Zuordnung(land: land, rang: rang, punkte: punkte);
      _verwendeteKategorien.add(katId);
      _aktuellerIndex++;
    });

    if (_aktuellerIndex >= _laender.length) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _abschliessen();
      });
    } else {
      _zwischenstandSpeichern();
    }
  }

  Future<void> _abschliessen() async {
    final pts = _gesamtPunkte();
    _neuerRekord = await ChallengeRekordService.setzeFallsBesser(_kId, pts);
    await ChallengeRekordService.speichereHeutigePunkte(_kId, pts);
    await ChallengeRekordService.summeErhoehen(_kId, pts.toDouble());
    await ChallengeErgebnisService.speichern(_kId, {
      'zuordnungen': {
        for (final e in _zuordnungen.entries) e.key: e.value.land.iso2,
      },
    });
    if (_neuerRekord) _rekord = pts;
    await RanglisteService.ergebnisSpeichernMitBereinigung(
        challengeId: 'ranking', wert: pts);
    await DailyChallenge.markDone(_kId);
    await DailyResumeService.loeschen(_kId);
    final neueAbzeichen = await AbzeichenService.pruefeNachChallengeAbschluss(
      heutePerfekt: pts >= _kAnzahl * 100,
      neuerRekordHeute: _neuerRekord,
    );
    if (mounted && neueAbzeichen.isNotEmpty) {
      await AbzeichenPopup.zeigen(context, neueAbzeichen);
    }
    if (!mounted) return;
    setState(() => _status = _Status.aufloesung);
  }

  int _gesamtPunkte() =>
      _zuordnungen.values.fold(0, (sum, z) => sum + z.punkte);

  // iso2 → katId: Kuhn's Algorithmus oben liefert nur IRGENDEIN gültiges
  // Matching (jedes Land bekommt eine Kategorie mit Rang < 100), aber nicht
  // zwingend das mit der höchsten Gesamtpunktzahl — ein Land könnte einer
  // Kategorie mit Rang 87 zugeordnet werden, obwohl es in einer anderen,
  // noch freien Kategorie Rang 3 hätte. Bei 8 Ländern × 8 Kategorien (nur
  // 8! = 40.320 Permutationen) ist vollständiges Backtracking mit Pruning
  // im Millisekundenbereich und liefert garantiert das Maximum.
  Map<String, String> _berechneIdealeKonstellation() {
    return _berechneOptimaleIdealeKonstellation(_laender, _tagesKats);
  }

  Map<String, String> _berechneOptimaleIdealeKonstellation(
      List<CountryRanking> laender, List<RankingCategory> kategorien) {
    Map<String, String>? besteLoesung;
    var besteGesamtpunkte = -1;

    void backtracking(
        List<CountryRanking> uebrigeLaender,
        Set<String> verwendeteKategorien,
        Map<String, String> aktuelleZuordnung,
        int aktuellePunkte) {
      if (uebrigeLaender.isEmpty) {
        if (aktuellePunkte > besteGesamtpunkte) {
          besteGesamtpunkte = aktuellePunkte;
          besteLoesung = Map.from(aktuelleZuordnung);
        }
        return;
      }

      // Pruning: selbst wenn jedes verbleibende Land die vollen 100 Punkte
      // (Rang 1) bekäme, kann dieser Zweig die aktuell beste Lösung nicht
      // mehr schlagen -> abbrechen.
      final maxNochErreichbar = aktuellePunkte + uebrigeLaender.length * 100;
      if (maxNochErreichbar <= besteGesamtpunkte) return;

      final land = uebrigeLaender.first;
      final restLaender = uebrigeLaender.skip(1).toList();

      // _baue() garantiert bereits bei der Ziehung (_istGueltigeKombination),
      // dass für JEDES Land mindestens eine Rang<100-Kategorie frei bleibt,
      // egal in welcher Reihenfolge zugeordnet wird — kein Fallback auf
      // Rang>=100 nötig, das würde die #100+-Garantie aus dem letzten Fix
      // brechen.
      for (final kat in kategorien) {
        if (verwendeteKategorien.contains(kat.id)) continue;
        final weltrang = _weltrang(land, kat);
        if (weltrang >= 100) continue;

        aktuelleZuordnung[land.iso2] = kat.id;
        verwendeteKategorien.add(kat.id);

        backtracking(restLaender, verwendeteKategorien, aktuelleZuordnung,
            aktuellePunkte + _berechnePunkte(weltrang));

        aktuelleZuordnung.remove(land.iso2);
        verwendeteKategorien.remove(kat.id);
      }
    }

    backtracking(laender, <String>{}, {}, 0);
    return besteLoesung ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHintergrund,
      body: switch (_status) {
        _Status.laden => const Center(
            child: CircularProgressIndicator(color: Color(0xFF4A9E4A))),
        _Status.spielen => _buildSpiel(),
        _Status.aufloesung => _buildAufloesung(),
      },
    );
  }

  // ── Spielphase ────────────────────────────────────────────────────────────────

  Widget _buildSpiel() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Color(0xFF1A1A1A), size: 20),
                  ),
                ),
                const Spacer(),
                ErklaerungButton(
                  titel: t('Ranking-Quiz — Spielregeln'),
                  farbe: const Color(0xFF7C3AED),
                  abschnitte: [
                    t('Für jedes angezeigte Land musst du eine passende Kategorie wählen (z.B. "Größte Fläche", "Meiste Einwohner").'),
                    t('Tippe auf die Kategorie, in der du glaubst, dass dieses Land weltweit am besten platziert ist — je näher an Platz 1, desto mehr Punkte.'),
                    t('Jede Kategorie kann nur einmal vergeben werden. Ist sie schon belegt, musst du beim nächsten Land eine andere wählen.'),
                    t('Nach allen Ländern siehst du die Auflösung mit deiner tatsächlichen Punktzahl im Vergleich zur bestmöglichen Zuordnung.'),
                  ],
                ),
              ],
            ),
          ),
          _buildHeader(),
          const Divider(color: Color(0xFFD0CEC8), height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: _buildKategorieButtons(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final fertig = _aktuellerIndex >= _laender.length;

    if (fertig) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: Text(
            t('Alle Länder zugeordnet!'),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final land = _laender[_aktuellerIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAE5),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_aktuellerIndex + 1} / ${_laender.length}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A)),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 1,
                  height: 16,
                  color: const Color(0xFFD0CEC8),
                ),
                Text(
                  '${_gesamtPunkte()} pts',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAE5),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: zeigeFlagge(
                    land.iso2,
                    width: 64,
                    height: 42,
                    borderRadius: 4,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                land.name,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            t('Wähle die beste Kategorie:'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }

  Widget _buildKategorieButtons() {
    return Column(
      children: [
        ..._tagesKats.map((kat) {
          final zuordnung = _zuordnungen[kat.id];
          final zugeordnet = zuordnung != null;
          return _KatButton(
            emoji: kat.emoji,
            label: kat.label,
            zugeordnet: zugeordnet,
            flagIso2: zugeordnet ? zuordnung.land.iso2 : null,
            rang: zugeordnet ? zuordnung.rang : null,
            onTap: zugeordnet ? null : () => _tippKategorie(kat.id),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Auflösung ─────────────────────────────────────────────────────────────────

  Widget _buildFlaggeUndRang(_Zuordnung? z, {bool versteckeHundertPlus = false}) {
    if (z == null) {
      return const Text('—',
          style: TextStyle(fontSize: 13, color: Color(0xFF888888)));
    }
    final zeigeRang = !(versteckeHundertPlus && z.rang >= 100);
    return Row(
      children: [
        zeigeFlagge(
          z.land.iso2,
          width: 32,
          height: 22,
          borderRadius: 3,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                z.land.name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  if (zeigeRang) ...[
                    Text(_formatRang(z.rang),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF888888))),
                    const Text(' · ',
                        style: TextStyle(color: Color(0xFFD0CEC8))),
                  ],
                  Text(
                    '+${z.punkte}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: z.punkte > 50
                          ? const Color(0xFF4A9E4A)
                          : const Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAufloesung() {
    final gesamtPunkte = _gesamtPunkte();

    final idealRaw = _berechneIdealeKonstellation(); // iso2 → katId
    final idealProKat = <String, _Zuordnung>{}; // katId → Zuordnung
    for (final e in idealRaw.entries) {
      final land = _laender.firstWhere((l) => l.iso2 == e.key);
      final kat = _tagesKats.firstWhere((k) => k.id == e.value);
      final rang = _weltrang(land, kat);
      idealProKat[e.value] =
          _Zuordnung(land: land, rang: rang, punkte: _berechnePunkte(rang));
    }
    final maxPunkte =
        idealProKat.values.fold(0, (sum, z) => sum + z.punkte);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChallengeErgebnisHeader(titel: t('Ranking-Quiz')),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RekordBadge(
                  neuerRekord: _neuerRekord,
                  rekordText:
                      _rekord != null ? t('{n} Pkt.', {'n': '$_rekord'}) : null,
                ),
                const SizedBox(height: 16),
                RanglisteErgebnisKarte(
                  challengeId: 'ranking',
                  eigenerWert: gesamtPunkte,
                  punkteLabel: t('Gesamtpunktzahl'),
                  farbe: const Color(0xFF7C3AED),
                  punkteAnzeige: RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: '$gesamtPunkte',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A))),
                      TextSpan(
                          text: ' / $maxPunkte',
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
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: Color(0xFFD0CEC8)),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Column(
                children: [
                  ..._tagesKats.map((kat) {
                    final spieler = _zuordnungen[kat.id];
                    final ideal = idealProKat[kat.id];
                    final korrekt = spieler != null &&
                        ideal != null &&
                        spieler.land.iso2 == ideal.land.iso2;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: korrekt
                                ? const Color(0xFF4A9E4A)
                                : const Color(0xFFEAEAE5),
                            width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF1A1A1A),
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(kat.emoji,
                                  style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(kat.label,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A1A))),
                              ),
                              if (korrekt)
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF4A9E4A), size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(color: Color(0xFFEAEAE5), height: 1),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(t('Deine Wahl'),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF888888),
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    _buildFlaggeUndRang(spieler),
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                width: 1,
                                height: 50,
                                color: const Color(0xFFEAEAE5),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(t('Ideal'),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF888888),
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    if (korrekt)
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded,
                                              color: Color(0xFF4A9E4A),
                                              size: 16),
                                          const SizedBox(width: 6),
                                          Text(t('Korrekt!'),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF4A9E4A))),
                                        ],
                                      )
                                    else
                                      _buildFlaggeUndRang(ideal,
                                          versteckeHundertPlus: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                ChallengeFertigButton(
                    onTap: () => ChallengePanelSignal.zurueckZumPanel(context)),
                const SizedBox(height: 12),
                Text(t('Morgen wieder verfügbar'),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
