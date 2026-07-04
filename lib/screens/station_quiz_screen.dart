import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/countries.dart';
import '../data/lernpfad_data.dart';
import '../data/wirtschaftssektoren.dart';
import '../services/fortschritt_service.dart';
import '../services/skala_service.dart';
import '../services/station_session_service.dart';
import '../widgets/flaggen_widget.dart';

// ── Geo-Cache (einmal laden, überall nutzen) ──────────────────────────────────

Map<String, List<List<Offset>>>? _geoCache;

/// Schritt 1: ne_50m als Basis laden (alle Länder, mittlere Qualität, ein Netzwerk-Call)
Future<Map<String, List<List<Offset>>>> _ladeGeoRings() async {
  if (_geoCache != null) return _geoCache!;
  final raw = await rootBundle.loadString('assets/geo/ne_50m_countries.geojson');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final features = json['features'] as List;
  final rings = <String, List<List<Offset>>>{};
  for (final f in features) {
    final props = f['properties'] as Map<String, dynamic>;
    final iso2Raw = props['ISO_A2'] as String? ?? '';
    final iso2 = iso2Raw == '-99'
        ? (props['ISO_A2_EH'] as String? ?? '')
        : iso2Raw;
    if (iso2 == 'AQ' || iso2.isEmpty || iso2 == '-99') continue;
    final geo = f['geometry'] as Map<String, dynamic>;
    final type = geo['type'] as String;
    final coords = geo['coordinates'] as List;
    final rs = <List<Offset>>[];
    if (type == 'Polygon') {
      rs.add(_ring(coords[0] as List));
    } else if (type == 'MultiPolygon') {
      for (final poly in coords) {
        rs.add(_ring((poly as List)[0] as List));
      }
    }
    if (rs.isNotEmpty) rings[iso2] = _filterRings(rs);
  }
  _geoCache = rings;
  return rings;
}

/// Schritt 2: Einzeldateien für konkrete Quiz-Länder nachladen (höhere Qualität)
/// Wird nach _ladeGeoRings() für nur die benötigten ISOs aufgerufen.
Future<void> _upgradeRingsMitEinzelDateien(
    Map<String, List<List<Offset>>> rings, Iterable<String> isos) async {
  await Future.wait(isos.map((iso2) async {
    try {
      final raw = await rootBundle.loadString('assets/geo/$iso2.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final features = json['features'] as List;
      if (features.isEmpty) return;
      final geo = features[0]['geometry'] as Map<String, dynamic>;
      final type = geo['type'] as String;
      final coords = geo['coordinates'] as List;
      final rs = <List<Offset>>[];
      if (type == 'Polygon') {
        rs.add(_ring(coords[0] as List));
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          rs.add(_ring((poly as List)[0] as List));
        }
      }
      if (rs.isNotEmpty) rings[iso2] = _filterRings(rs);
    } catch (_) {
      // Kein Einzelfile für $iso2 → ne_50m-Fallback bleibt
    }
  }));
}

List<Offset> _ring(List coords) =>
    coords.map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList();

List<List<Offset>> _filterRings(List<List<Offset>> rs) {
  if (rs.length <= 1) return rs;
  double bboxArea(List<Offset> r) {
    double minX = r[0].dx, maxX = r[0].dx, minY = r[0].dy, maxY = r[0].dy;
    for (final p in r) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return (maxX - minX) * (maxY - minY);
  }
  final areas = rs.map(bboxArea).toList();
  final maxA = areas.reduce(max);
  return [for (var i = 0; i < rs.length; i++) if (areas[i] >= maxA * 0.10) rs[i]];
}

class StationQuizScreen extends StatefulWidget {
  final LernStation? station;
  final String? wiederholungsAbschnittId;
  final String? wiederholungsFragenJson;

  const StationQuizScreen({
    super.key,
    required this.station,
  })  : wiederholungsAbschnittId = null,
        wiederholungsFragenJson = null;

  const StationQuizScreen.wiederholung({
    super.key,
    required this.wiederholungsAbschnittId,
    required this.wiederholungsFragenJson,
  }) : station = null;

  bool get istWiederholungsrunde => station == null;

  @override
  State<StationQuizScreen> createState() => _StationQuizScreenState();
}

class _StationQuizScreenState extends State<StationQuizScreen> {
  StationSession? _session;
  bool _loading = true;

  // Feedback-State
  bool _showFeedback = false;
  bool _feedbackRichtig = false;
  String? _gewahlteAntwort;
  Timer? _feedbackTimer;

  // Timer
  Timer? _countdownTimer;
  int _countdown = 15;

  // SortierSpiel
  List<String> _sortierReihenfolge = [];
  bool _sortierGeprueft = false;

  // PreisSchaetzen
  double _sliderWert = 0;
  bool _preisBestaetigt = false;

  // HauptstadtEingabe
  final _textCtrl = TextEditingController();
  bool _eingabeBestaetigt = false;

  // Umriss-Quiz
  Map<String, List<List<Offset>>> _geoRings = {};

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _countdownTimer?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Session-Init ───────────────────────────────────────────────────────────

  Future<void> _initSession() async {
    StationSession session;

    if (widget.istWiederholungsrunde) {
      session = StationSession.fuerWiederholungsrunde(
        widget.wiederholungsAbschnittId!,
        widget.wiederholungsFragenJson!,
      );
    } else {
      final gespeichert = await StationSession.laden(widget.station!.id);
      if (gespeichert != null) {
        session = gespeichert;
      } else {
        await FortschrittService.stationZuruecksetzen(widget.station!.id);
        final fragen =
            await FragenGenerator.generiereFragenFuerStation(widget.station!);
        session = StationSession(
          stationId: widget.station!.id,
          aktiveFragen: fragen,
          hatTimer: widget.station!.schwierigkeitsgrad == 4,
        );
      }
    }

    // GeoJSON laden falls Umriss-Modi vorhanden
    final brauchtGeo = session.aktiveFragen.any((f) =>
        f.modus == LernModus.umrissBild || f.modus == LernModus.umrissMultiple);
    if (brauchtGeo) {
      try {
        final rings = await _ladeGeoRings();
        // Hochauflösende Einzeldateien für Quiz-Länder nachladen
        final quizIsos = session.aktiveFragen
            .where((f) => f.modus == LernModus.umrissBild || f.modus == LernModus.umrissMultiple)
            .expand((f) => [f.laenderCode, ...f.antwortOptionen])
            .where((s) => s.isNotEmpty && s.length == 2)
            .toSet();
        await _upgradeRingsMitEinzelDateien(rings, quizIsos);
        if (mounted) setState(() => _geoRings = rings);
      } catch (e) {
        debugPrint('GeoJSON konnte nicht geladen werden: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _session = session;
      _loading = false;
    });
    if (session.hatTimer) _startCountdown();
    _initFrageState(session.aktuelleFrage);
  }

  void _initFrageState(Frage? frage) {
    if (frage == null) return;
    if (frage.modus == LernModus.sortierSpiel) {
      setState(() {
        _sortierReihenfolge = List.of(frage.antwortOptionen);
        _sortierGeprueft = false;
      });
    } else if (frage.modus == LernModus.preisSchaetzen) {
      final mn = (frage.meta['min'] as num?)?.toDouble() ?? 0;
      final mx = (frage.meta['max'] as num?)?.toDouble() ?? 100;
      // Startwert absichtlich NICHT mittig (siehe TagesSeedService.startBruch
      // in der Fragen-Generierung) — sonst wäre "Slider einfach stehen
      // lassen" zufällig oft schon eine gute Schätzung.
      final start = (frage.meta['start'] as num?)?.toDouble() ?? (mn + mx) / 2;
      setState(() {
        _sliderWert = start.clamp(mn, mx);
        _preisBestaetigt = false;
      });
    } else if (frage.modus == LernModus.hauptstaedteEingabe) {
      _textCtrl.clear();
      setState(() => _eingabeBestaetigt = false);
    }
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _countdown = 15);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        _timerAbgelaufen();
      }
    });
  }

  void _stopCountdown() => _countdownTimer?.cancel();

  void _timerAbgelaufen() {
    if (_showFeedback || _session == null) return;
    setState(() {
      _showFeedback = true;
      _feedbackRichtig = false;
      _gewahlteAntwort = null;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _session!.timerAbgelaufen();
      _vorruecken();
    });
  }

  // ── Antwort-Handler ────────────────────────────────────────────────────────

  void _antwortGewaehlt(String antwort) {
    if (_showFeedback || _session == null) return;
    _stopCountdown();
    final frage = _session!.aktuelleFrage;
    if (frage == null) return;
    final richtig = antwort == frage.richtigeAntwort;
    setState(() {
      _gewahlteAntwort = antwort;
      _showFeedback = true;
      _feedbackRichtig = richtig;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (richtig) {
        _session!.richtigeAntwortVerarbeiten();
      } else {
        _session!.falscheAntwortVerarbeiten();
      }
      _vorruecken();
    });
  }

  void _eingabeBestaetigen() {
    if (_eingabeBestaetigt || _session == null) return;
    final frage = _session!.aktuelleFrage;
    if (frage == null) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _stopCountdown();
    final richtig =
        text.toLowerCase() == frage.richtigeAntwort.toLowerCase();
    setState(() {
      _eingabeBestaetigt = true;
      _showFeedback = true;
      _feedbackRichtig = richtig;
      _gewahlteAntwort = text;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (richtig) {
        _session!.richtigeAntwortVerarbeiten();
      } else {
        _session!.falscheAntwortVerarbeiten();
      }
      _textCtrl.clear();
      setState(() => _eingabeBestaetigt = false);
      _vorruecken();
    });
  }

  void _sortierPruefen() {
    if (_sortierGeprueft || _session == null) return;
    final frage = _session!.aktuelleFrage;
    if (frage == null) return;
    _stopCountdown();
    final richtig = _sortierReihenfolge.join(',') == frage.richtigeAntwort;
    setState(() {
      _sortierGeprueft = true;
      _showFeedback = true;
      _feedbackRichtig = richtig;
    });
    // Kein Auto-Timer: die Lösung mit Werten braucht Zeit zum Lesen —
    // der Nutzer bestätigt manuell mit "Weiter" (siehe _sortierWeiter).
  }

  void _sortierWeiter() {
    if (_session == null) return;
    if (_feedbackRichtig) {
      _session!.richtigeAntwortVerarbeiten();
    } else {
      _session!.falscheAntwortVerarbeiten();
    }
    setState(() => _sortierGeprueft = false);
    _vorruecken();
  }

  void _preisBestaetigen() {
    if (_preisBestaetigt || _session == null) return;
    final frage = _session!.aktuelleFrage;
    if (frage == null) return;
    _stopCountdown();
    final zielwert = double.tryParse(frage.richtigeAntwort) ?? 0;
    final richtig = zielwert == 0
        ? _sliderWert.abs() < 1
        : (_sliderWert - zielwert).abs() / zielwert <= 0.2;
    setState(() {
      _preisBestaetigt = true;
      _showFeedback = true;
      _feedbackRichtig = richtig;
    });
    // Kein Auto-Timer: der tatsächliche Wert + Abweichung braucht Zeit zum
    // Lesen — der Nutzer bestätigt manuell mit "Weiter" (siehe _preisWeiter).
  }

  void _preisWeiter() {
    if (_session == null) return;
    if (_feedbackRichtig) {
      _session!.richtigeAntwortVerarbeiten();
    } else {
      _session!.falscheAntwortVerarbeiten();
    }
    setState(() => _preisBestaetigt = false);
    _vorruecken();
  }

  // ── Vorrücken / Station fertig ─────────────────────────────────────────────

  void _vorruecken() {
    if (!mounted) return;
    if (_session!.istFertig) {
      _stationFertig();
    } else {
      setState(() {
        _showFeedback = false;
        _gewahlteAntwort = null;
      });
      _session!.speichernFortschritt();
      if (_session!.hatTimer) _startCountdown();
      _initFrageState(_session!.aktuelleFrage);
    }
  }

  Future<void> _stationFertig() async {
    _stopCountdown();
    setState(() => _showFeedback = false);

    if (widget.istWiederholungsrunde) {
      await FortschrittService.wiederholungAbschliessen(
          widget.wiederholungsAbschnittId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🎉 Abschnitt vollständig abgeschlossen!'),
        backgroundColor: Color(0xFF4A9E4A),
      ));
      Navigator.pop(context);
      return;
    }

    // Normale Station speichern
    await FortschrittService.stationAbschliessen(
      widget.station!.id,
      _session!.richtigeAntworten,
      _session!.falscheAntworten,
      falscheFragenJson: _session!.falscheFragenAlsJson(),
    );

    if (!FortschrittService.istLetzteStationImAbschnitt(widget.station!.id)) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // Letzte Station: Wiederholung prüfen
    final abschnittId = _abschnittId();
    final wdhNoetig =
        await FortschrittService.wiederholungNoetig(abschnittId);

    if (!wdhNoetig) {
      await FortschrittService.wiederholungAbschliessen(abschnittId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🎉 Perfekt! Abschnitt abgeschlossen!'),
        backgroundColor: Color(0xFF4A9E4A),
      ));
      Navigator.pop(context);
      return;
    }

    // Wiederholungsrunde starten
    final falscheJson =
        await FortschrittService.sammelFalscheFragenFuerAbschnitt(abschnittId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🔄 Weiter zur Wiederholungsrunde!'),
      backgroundColor: Color(0xFFD98C30),
      duration: Duration(milliseconds: 1500),
    ));
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StationQuizScreen.wiederholung(
          wiederholungsAbschnittId: abschnittId,
          wiederholungsFragenJson: falscheJson,
        ),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  String _abschnittId() {
    final k = stationKontext(widget.station!.id);
    return k != null ? k.$2.id : '';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading || _session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session!;
    final frage = session.aktuelleFrage;

    final titel = widget.istWiederholungsrunde
        ? '🔄 Wiederholungsrunde'
        : lernModusLabel(widget.station!.modus);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(titel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: session.fortschritt,
            minHeight: 6,
            backgroundColor: const Color(0xFF2A4A3A),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF4A9E4A)),
          ),
        ),
      ),
      body: frage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (session.hatTimer) _TimerBar(countdown: _countdown),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _frageWidget(frage),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _frageWidget(Frage f) {
    return switch (f.modus) {
      LernModus.flaggenQuizBild => _FlagBildUI(
          frage: f,
          gewaehlt: _gewahlteAntwort,
          showFeedback: _showFeedback,
          feedbackRichtig: _feedbackRichtig,
          onAntwort: _antwortGewaehlt,
        ),
      LernModus.flaggenQuizMultiple => _FlagMultipleUI(
          frage: f,
          gewaehlt: _gewahlteAntwort,
          showFeedback: _showFeedback,
          feedbackRichtig: _feedbackRichtig,
          onAntwort: _antwortGewaehlt,
        ),
      LernModus.sortierSpiel => _SortierUI(
          frage: f,
          reihenfolge: _sortierReihenfolge,
          geprueft: _sortierGeprueft,
          feedbackRichtig: _feedbackRichtig,
          onReorder: (o, n) => setState(() {
            final it = _sortierReihenfolge.removeAt(o);
            _sortierReihenfolge.insert(n, it);
          }),
          onPruefen: _sortierPruefen,
          onWeiter: _sortierWeiter,
        ),
      LernModus.preisSchaetzen => _PreisUI(
          frage: f,
          sliderWert: _sliderWert,
          bestaetigt: _preisBestaetigt,
          feedbackRichtig: _feedbackRichtig,
          onChanged: (v) => setState(() => _sliderWert = v),
          onBestaetigen: _preisBestaetigen,
          onWeiter: _preisWeiter,
        ),
      LernModus.hauptstaedteEingabe => _EingabeUI(
          frage: f,
          controller: _textCtrl,
          bestaetigt: _eingabeBestaetigt,
          showFeedback: _showFeedback,
          feedbackRichtig: _feedbackRichtig,
          onBestaetigen: _eingabeBestaetigen,
        ),
      LernModus.umrissBild => _UmrissBildUI(
          frage: f,
          geoRings: _geoRings,
          gewaehlt: _gewahlteAntwort,
          showFeedback: _showFeedback,
          feedbackRichtig: _feedbackRichtig,
          onAntwort: _antwortGewaehlt,
        ),
      LernModus.umrissMultiple => _UmrissMultipleUI(
          frage: f,
          geoRings: _geoRings,
          gewaehlt: _gewahlteAntwort,
          showFeedback: _showFeedback,
          feedbackRichtig: _feedbackRichtig,
          onAntwort: _antwortGewaehlt,
        ),
      _ => _GenericMCUI(
          frage: f,
          gewaehlt: _gewahlteAntwort,
          showFeedback: _showFeedback,
          feedbackRichtig: _feedbackRichtig,
          onAntwort: _antwortGewaehlt,
        ),
    };
  }
}

// ── Timer-Bar ──────────────────────────────────────────────────────────────────

class _TimerBar extends StatelessWidget {
  final int countdown;
  const _TimerBar({required this.countdown});

  @override
  Widget build(BuildContext context) {
    final fraction = (countdown / 15.0).clamp(0.0, 1.0);
    final color = countdown > 5
        ? const Color(0xFFD98C30)
        : const Color(0xFFD94040);
    return Column(
      children: [
        LinearProgressIndicator(
          value: fraction,
          minHeight: 6,
          backgroundColor: const Color(0xFFD0CEC8),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 4, bottom: 2),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${countdown}s',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Hilfsfunktionen ────────────────────────────────────────────────────────────

Country? _countryByIso2(String iso2) {
  if (iso2.isEmpty) return null;
  return countries.cast<Country?>().firstWhere(
    (c) => c?.iso2 == iso2,
    orElse: () => null,
  );
}

Color _optionFarbe(String option, String richtige, String? gewaehlt,
    bool showFeedback, bool feedbackRichtig) {
  if (!showFeedback) return const Color(0xFFEAEAE5);
  if (option == richtige) return const Color(0xFF4A9E4A);
  if (option == gewaehlt && !feedbackRichtig) return const Color(0xFFD94040);
  return const Color(0xFFEAEAE5);
}

Color _textFarbe(String option, String richtige, String? gewaehlt,
    bool showFeedback, bool feedbackRichtig) {
  if (!showFeedback) return const Color(0xFF1a1a1a);
  if (option == richtige) return Colors.white;
  if (option == gewaehlt && !feedbackRichtig) return Colors.white;
  return const Color(0xFF888888);
}

// ── Gemeinsame Widgets ─────────────────────────────────────────────────────────

class _LandHeader extends StatelessWidget {
  final String iso2;
  const _LandHeader({required this.iso2});

  @override
  Widget build(BuildContext context) {
    final co = _countryByIso2(iso2);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FlaggenWidget(
            countryCode: iso2, width: 64, height: 42, borderRadius: 6),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            co?.name ?? iso2,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _AntwortButton extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;
  final VoidCallback? onTap;

  const _AntwortButton({
    required this.text,
    required this.bgColor,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Flaggen Bild → Land wählen ─────────────────────────────────────────────────

class _FlagBildUI extends StatelessWidget {
  final Frage frage;
  final String? gewaehlt;
  final bool showFeedback, feedbackRichtig;
  final void Function(String) onAntwort;

  const _FlagBildUI({
    required this.frage,
    required this.gewaehlt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onAntwort,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Welchem Land gehört diese Flagge?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FlaggenWidget(
              countryCode: frage.laenderCode,
              width: 260,
              height: 170,
              borderRadius: 12),
        ),
        const SizedBox(height: 28),
        ...frage.antwortOptionen.map((opt) => _AntwortButton(
              text: opt,
              bgColor: _optionFarbe(opt, frage.richtigeAntwort, gewaehlt,
                  showFeedback, feedbackRichtig),
              textColor: _textFarbe(opt, frage.richtigeAntwort, gewaehlt,
                  showFeedback, feedbackRichtig),
              onTap: showFeedback ? null : () => onAntwort(opt),
            )),
      ],
    );
  }
}

// ── Flaggen Multiple: Land → Flagge wählen ─────────────────────────────────────

class _FlagMultipleUI extends StatelessWidget {
  final Frage frage;
  final String? gewaehlt;
  final bool showFeedback, feedbackRichtig;
  final void Function(String) onAntwort;

  const _FlagMultipleUI({
    required this.frage,
    required this.gewaehlt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onAntwort,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          frage.frage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: frage.antwortOptionen.map((iso2) {
            Color border = Colors.transparent;
            if (showFeedback) {
              if (iso2 == frage.richtigeAntwort) {
                border = const Color(0xFF4A9E4A);
              } else if (iso2 == gewaehlt && !feedbackRichtig) {
                border = const Color(0xFFD94040);
              }
            }
            return GestureDetector(
              onTap: showFeedback ? null : () => onAntwort(iso2),
              child: LayoutBuilder(
                builder: (ctx, constraints) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: border,
                      width: border == Colors.transparent ? 0 : 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FlaggenWidget(
                      countryCode: iso2,
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      borderRadius: 0,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Generic Multiple Choice (Hauptstädte, Währungen, Wirtschaft) ───────────────

class _GenericMCUI extends StatelessWidget {
  final Frage frage;
  final String? gewaehlt;
  final bool showFeedback, feedbackRichtig;
  final void Function(String) onAntwort;

  const _GenericMCUI({
    required this.frage,
    required this.gewaehlt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onAntwort,
  });

  String _labelFor(String opt) {
    if (frage.modus == LernModus.wirtschaftssektoren) {
      final emoji = sektorEmojis[opt] ?? '';
      return emoji.isEmpty ? opt : '$emoji  $opt';
    }
    return opt;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (frage.laenderCode.isNotEmpty) ...[
          _LandHeader(iso2: frage.laenderCode),
          const SizedBox(height: 16),
        ],
        Text(
          frage.frage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        ...frage.antwortOptionen.map((opt) => _AntwortButton(
              text: _labelFor(opt),
              bgColor: _optionFarbe(opt, frage.richtigeAntwort, gewaehlt,
                  showFeedback, feedbackRichtig),
              textColor: _textFarbe(opt, frage.richtigeAntwort, gewaehlt,
                  showFeedback, feedbackRichtig),
              onTap: showFeedback ? null : () => onAntwort(opt),
            )),
      ],
    );
  }
}

// ── Hauptstadt Texteingabe ─────────────────────────────────────────────────────

class _EingabeUI extends StatelessWidget {
  final Frage frage;
  final TextEditingController controller;
  final bool bestaetigt, showFeedback, feedbackRichtig;
  final VoidCallback onBestaetigen;

  const _EingabeUI({
    required this.frage,
    required this.controller,
    required this.bestaetigt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onBestaetigen,
  });

  @override
  Widget build(BuildContext context) {
    Color feedbackFarbe = const Color(0xFFEAEAE5);
    if (showFeedback) {
      feedbackFarbe = feedbackRichtig
          ? const Color(0xFFD4EDD4)
          : const Color(0xFFEDD4D4);
    }

    return Column(
      children: [
        _LandHeader(iso2: frage.laenderCode),
        const SizedBox(height: 20),
        Text(
          frage.frage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: feedbackFarbe,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            enabled: !bestaetigt,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Hauptstadt eingeben…',
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => onBestaetigen(),
          ),
        ),
        if (showFeedback) ...[
          const SizedBox(height: 12),
          Text(
            feedbackRichtig
                ? '✅ Richtig!'
                : '❌ Richtig war: ${frage.richtigeAntwort}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: feedbackRichtig
                  ? const Color(0xFF4A9E4A)
                  : const Color(0xFFD94040),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: bestaetigt ? null : onBestaetigen,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A9E4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: const Color(0xFFCCCCCC),
            ),
            child: const Text('Bestätigen',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ── Sortier-Spiel ──────────────────────────────────────────────────────────────

class _SortierUI extends StatelessWidget {
  final Frage frage;
  final List<String> reihenfolge;
  final bool geprueft, feedbackRichtig;
  final void Function(int, int) onReorder;
  final VoidCallback onPruefen;
  final VoidCallback onWeiter;

  const _SortierUI({
    required this.frage,
    required this.reihenfolge,
    required this.geprueft,
    required this.feedbackRichtig,
    required this.onReorder,
    required this.onPruefen,
    required this.onWeiter,
  });

  @override
  Widget build(BuildContext context) {
    return geprueft ? _ErgebnisAnsicht(frage: frage, nutzerReihenfolge: reihenfolge, onWeiter: onWeiter)
        : _SortierListe(frage: frage, reihenfolge: reihenfolge, onReorder: onReorder, onPruefen: onPruefen);
  }
}

// ── Sortier-Spiel: Drag&Drop-Liste (vor dem Prüfen) ──────────────────────────

class _SortierListe extends StatelessWidget {
  final Frage frage;
  final List<String> reihenfolge;
  final void Function(int, int) onReorder;
  final VoidCallback onPruefen;

  const _SortierListe({
    required this.frage,
    required this.reihenfolge,
    required this.onReorder,
    required this.onPruefen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          frage.frage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          '↑ Größtes oben  |  Kleinstes unten ↓',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: reihenfolge.length * 64.0,
          child: ReorderableListView.builder(
            shrinkWrap: true,
            proxyDecorator: (child, _, _) => Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: child,
            ),
            onReorderItem: onReorder,
            itemCount: reihenfolge.length,
            itemBuilder: (ctx, i) {
              final iso2 = reihenfolge[i];
              final co = _countryByIso2(iso2);
              return Container(
                key: ValueKey(iso2),
                height: 56,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Text('${i + 1}.', style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xFF666666))),
                    const SizedBox(width: 10),
                    FlaggenWidget(
                        countryCode: iso2,
                        width: 36,
                        height: 24,
                        borderRadius: 4),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        co?.name ?? iso2,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.drag_handle,
                        color: Color(0xFFBBBBBB), size: 20),
                    const SizedBox(width: 12),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onPruefen,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A9E4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reihenfolge prüfen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ── Sortier-Spiel: Ergebnis mit korrekter Reihenfolge + Werten ──────────────

class _ErgebnisAnsicht extends StatelessWidget {
  final Frage frage;
  final List<String> nutzerReihenfolge;
  final VoidCallback onWeiter;

  const _ErgebnisAnsicht({
    required this.frage,
    required this.nutzerReihenfolge,
    required this.onWeiter,
  });

  @override
  Widget build(BuildContext context) {
    final richtigeReihenfolge = frage.richtigeAntwort.split(',');
    final werteRoh = frage.meta['werte'];
    final werte = werteRoh is Map
        ? werteRoh.map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble()))
        : <String, double?>{};
    final einheit = frage.meta['einheit'] as String? ?? '';
    final kategorieLabel = frage.meta['kategorieLabel'] as String?;
    final anzahlRichtig = List.generate(richtigeReihenfolge.length,
        (i) => nutzerReihenfolge.indexOf(richtigeReihenfolge[i]) == i)
        .where((r) => r)
        .length;

    return Column(
      children: [
        Text(
          kategorieLabel != null
              ? 'Richtig (nach $kategorieLabel, größte zuerst):'
              : 'Richtige Reihenfolge:',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < richtigeReihenfolge.length; i++)
          _ErgebnisZeile(
            rang: i + 1,
            iso2: richtigeReihenfolge[i],
            wert: werte[richtigeReihenfolge[i]],
            einheit: einheit,
            warRichtig: nutzerReihenfolge.indexOf(richtigeReihenfolge[i]) == i,
            nutzerPlatz: nutzerReihenfolge.indexOf(richtigeReihenfolge[i]) + 1,
          ),
        const SizedBox(height: 8),
        Text(
          anzahlRichtig == richtigeReihenfolge.length
              ? '✅ Perfekte Reihenfolge!'
              : '$anzahlRichtig von ${richtigeReihenfolge.length} richtig sortiert',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: anzahlRichtig == richtigeReihenfolge.length
                ? const Color(0xFF4A9E4A)
                : const Color(0xFFD94040),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onWeiter,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A9E4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Weiter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _ErgebnisZeile extends StatelessWidget {
  final int rang;
  final String iso2;
  final double? wert;
  final String einheit;
  final bool warRichtig;
  final int nutzerPlatz;

  const _ErgebnisZeile({
    required this.rang,
    required this.iso2,
    required this.wert,
    required this.einheit,
    required this.warRichtig,
    required this.nutzerPlatz,
  });

  @override
  Widget build(BuildContext context) {
    final co = _countryByIso2(iso2);
    return Container(
      height: 56,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: warRichtig ? const Color(0xFFD4EDD4) : const Color(0xFFEDD4D4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('$rang.', style: const TextStyle(
              fontWeight: FontWeight.w700, color: Color(0xFF666666))),
          const SizedBox(width: 10),
          FlaggenWidget(countryCode: iso2, width: 36, height: 24, borderRadius: 4),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              co?.name ?? iso2,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          if (wert != null)
            Text(
              _formatGrosswert(wert!, einheit),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555)),
            ),
          const SizedBox(width: 8),
          Icon(
            warRichtig ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: warRichtig ? const Color(0xFF4A9E4A) : const Color(0xFFD94040),
            size: 20,
          ),
          if (!warRichtig) ...[
            const SizedBox(width: 4),
            Text('(Platz $nutzerPlatz)',
                style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
          ],
        ],
      ),
    );
  }
}

// Rekonstruiert dieselbe adaptive Skala, die beim Erzeugen der Frage
// verwendet wurde (Referenzwert = die korrekte Antwort) — ohne eine
// nicht-serialisierbare Formatierfunktion im Frage-meta ablegen zu müssen.
SkalaErgebnis? _skalaFuerFrage(Frage frage) {
  final kategorie = frage.meta['kategorie'] as String?;
  final zielwert = double.tryParse(frage.richtigeAntwort);
  if (kategorie == null || zielwert == null) return null;
  return SkalaService.fuerKategorie(kategorie, zielwert);
}

// ── Gemeinsamer Zahlenformatierer (Mio./Mrd./Tsd.), Fallback falls keine
// Kategorie-Skala verfügbar ist (z.B. Sortierspiel-Werte) ───────────────────

String _formatGrosswert(double v, String einheit) {
  if (einheit == 'Jahre') return '${v.toStringAsFixed(1)} $einheit';
  final n = v.round();
  final abs = n.abs();
  if (abs >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)} Mrd. $einheit';
  if (abs >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} Mio. $einheit';
  if (abs >= 1000) return '${(n / 1000).toStringAsFixed(1)} Tsd. $einheit';
  return '$n $einheit';
}

// ── Preis schätzen ─────────────────────────────────────────────────────────────

class _PreisUI extends StatelessWidget {
  final Frage frage;
  final double sliderWert;
  final bool bestaetigt, feedbackRichtig;
  final void Function(double) onChanged;
  final VoidCallback onBestaetigen;
  final VoidCallback onWeiter;

  const _PreisUI({
    required this.frage,
    required this.sliderWert,
    required this.bestaetigt,
    required this.feedbackRichtig,
    required this.onChanged,
    required this.onBestaetigen,
    required this.onWeiter,
  });

  @override
  Widget build(BuildContext context) {
    return bestaetigt ? _buildErgebnis() : _buildEingabe();
  }

  Widget _buildEingabe() {
    final min = (frage.meta['min'] as num?)?.toDouble() ?? 0;
    final max = (frage.meta['max'] as num?)?.toDouble() ?? 100;
    final schritt = (frage.meta['schritt'] as num?)?.toDouble() ?? 1;
    final skala = _skalaFuerFrage(frage);
    String fmt(double v) => skala?.format(v) ?? _formatGrosswert(v, '');
    final divisionen = ((max - min) / schritt).round().clamp(50, 500);

    return Column(
      children: [
        _LandHeader(iso2: frage.laenderCode),
        const SizedBox(height: 20),
        Text(
          frage.frage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 28),
        Text(
          fmt(sliderWert),
          style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1B3A2D)),
        ),
        const SizedBox(height: 8),
        Slider(
          value: sliderWert.clamp(min, max),
          min: min,
          max: max,
          divisions: divisionen,
          onChanged: onChanged,
          activeColor: const Color(0xFF4A9E4A),
          inactiveColor: const Color(0xFFCCCCC6),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fmt(min),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888))),
              Text(fmt(max),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onBestaetigen,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A9E4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Schätzung bestätigen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildErgebnis() {
    final zielwert = double.tryParse(frage.richtigeAntwort) ?? 0;
    final skala = _skalaFuerFrage(frage);
    String fmt(double v) => skala?.format(v) ?? _formatGrosswert(v, '');
    final abweichungProzent =
        zielwert == 0 ? null : ((sliderWert - zielwert) / zielwert * 100);

    return Column(
      children: [
        _LandHeader(iso2: frage.laenderCode),
        const SizedBox(height: 20),
        Text(
          frage.frage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Text('Deine Schätzung: ${fmt(sliderWert)}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: feedbackRichtig
                ? const Color(0xFFD4EDD4)
                : const Color(0xFFEDD4D4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                feedbackRichtig ? '✅ Richtig! (±20%)' : '❌ Daneben',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: feedbackRichtig
                      ? const Color(0xFF2A6A2A)
                      : const Color(0xFFD94040),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tatsächlicher Wert: ${fmt(zielwert)}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1a1a1a)),
              ),
              if (abweichungProzent != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Du lagst ${abweichungProzent.abs().toStringAsFixed(0)}% zu ${abweichungProzent > 0 ? "hoch" : "niedrig"}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onWeiter,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A9E4A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Weiter',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ── Umriss Bild: Silhouette anzeigen → Land wählen ────────────────────────────

class _UmrissBildUI extends StatelessWidget {
  final Frage frage;
  final Map<String, List<List<Offset>>> geoRings;
  final String? gewaehlt;
  final bool showFeedback, feedbackRichtig;
  final void Function(String) onAntwort;

  const _UmrissBildUI({
    required this.frage,
    required this.geoRings,
    required this.gewaehlt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onAntwort,
  });

  @override
  Widget build(BuildContext context) {
    final rings = geoRings[frage.laenderCode] ?? [];
    final geoLoaded = geoRings.isNotEmpty;
    return Column(
      children: [
        const Text(
          'Welchem Land gehört dieser Umriss?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFFDFF2E1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: !geoLoaded
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
              : rings.isEmpty
                  ? const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('🗺️', style: TextStyle(fontSize: 52)),
                        SizedBox(height: 8),
                        Text('Kein Umriss verfügbar',
                            style: TextStyle(
                                color: Color(0xFF9E9C96),
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ]),
                    )
                  : ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(painter: _UmrissPainter(rings: rings)),
                ),
        ),
        const SizedBox(height: 20),
        ...frage.antwortOptionen.map((opt) => _AntwortButton(
              text: opt,
              bgColor: _optionFarbe(opt, frage.richtigeAntwort, gewaehlt,
                  showFeedback, feedbackRichtig),
              textColor: _textFarbe(opt, frage.richtigeAntwort, gewaehlt,
                  showFeedback, feedbackRichtig),
              onTap: showFeedback ? null : () => onAntwort(opt),
            )),
      ],
    );
  }
}

// ── Umriss Multiple: Land anzeigen → Silhouette wählen ───────────────────────

class _UmrissMultipleUI extends StatelessWidget {
  final Frage frage;
  final Map<String, List<List<Offset>>> geoRings;
  final String? gewaehlt;
  final bool showFeedback, feedbackRichtig;
  final void Function(String) onAntwort;

  const _UmrissMultipleUI({
    required this.frage,
    required this.geoRings,
    required this.gewaehlt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onAntwort,
  });

  @override
  Widget build(BuildContext context) {
    final co = _countryByIso2(frage.richtigeAntwort);
    return Column(
      children: [
        Text(
          'Welcher Umriss gehört zu ${co?.flagEmoji ?? ''} ${co?.name ?? frage.richtigeAntwort}?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.2,
          children: frage.antwortOptionen.map((iso2) {
            Color borderColor = Colors.transparent;
            double borderWidth = 0;
            if (showFeedback) {
              if (iso2 == frage.richtigeAntwort) {
                borderColor = const Color(0xFF4A9E4A);
                borderWidth = 3;
              } else if (iso2 == gewaehlt && !feedbackRichtig) {
                borderColor = const Color(0xFFD94040);
                borderWidth = 3;
              }
            }
            final rings = geoRings[iso2] ?? [];
            final geoLoaded = geoRings.isNotEmpty;
            Color bgColor = const Color(0xFFDFF2E1);
            if (showFeedback) {
              if (iso2 == frage.richtigeAntwort) bgColor = const Color(0xFFE8F5E9);
              if (iso2 == gewaehlt && !feedbackRichtig) bgColor = const Color(0xFFFFEBEE);
            }
            final silColor = (showFeedback && iso2 == gewaehlt && !feedbackRichtig)
                ? const Color(0xFFD94040)
                : const Color(0xFF2E7D32);
            return GestureDetector(
              onTap: showFeedback ? null : () => onAntwort(iso2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                child: !geoLoaded
                    ? const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF2E7D32)),
                        ),
                      )
                    : rings.isEmpty
                        ? const Center(
                            child: Text('🗺️', style: TextStyle(fontSize: 32)),
                          )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CustomPaint(
                            painter: _UmrissPainter(rings: rings, color: silColor)),
                      ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Umriss-Silhouette Painter ─────────────────────────────────────────────────

class _UmrissPainter extends CustomPainter {
  final List<List<Offset>> rings;
  final Color color;
  const _UmrissPainter({required this.rings, this.color = const Color(0xFF2E7D32)});

  static double _mX(double lng) => (lng + 180) / 360;
  static double _mY(double lat) {
    final s = sin(lat * pi / 180);
    return 0.5 - log((1 + s) / (1 - s)) / (4 * pi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (rings.isEmpty) return;
    const pad = 20.0;
    final proj = rings
        .map((r) => r.map((ll) => Offset(_mX(ll.dx), _mY(ll.dy))).toList())
        .toList();
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final r in proj) {
      for (final p in r) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    final w = maxX - minX, h = maxY - minY;
    if (w <= 0 || h <= 0) return;
    final avW = size.width - 2 * pad, avH = size.height - 2 * pad;
    final sc = min(avW / w, avH / h);
    final dX = pad + (avW - w * sc) / 2 - minX * sc;
    final dY = pad + (avH - h * sc) / 2 - minY * sc;
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color.withAlpha(178)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (final r in proj) {
      if (r.length < 3) continue;
      final path = Path()..moveTo(r[0].dx * sc + dX, r[0].dy * sc + dY);
      for (final p in r.skip(1)) path.lineTo(p.dx * sc + dX, p.dy * sc + dY);
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_UmrissPainter o) => o.rings != rings || o.color != color;
}
