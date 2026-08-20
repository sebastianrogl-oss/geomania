import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../data/countries.dart';
import '../data/laender_aliase.dart';
import '../data/lernpfad_data.dart';
import '../data/wirtschaftssektoren.dart';
import '../l10n/uebersetzungen.dart';
import '../l10n/wirtschaftssektoren_en.dart';
import '../services/locale_service.dart';
import '../services/ad_service.dart';
import '../services/abzeichen_service.dart';
import '../services/einstellungen_service.dart';
import '../services/fortschritt_service.dart';
import '../services/skala_service.dart';
import '../services/station_session_service.dart';
import '../widgets/abzeichen_popup.dart';
import '../widgets/flaggen_widget.dart';
import '../widgets/level_skip_button.dart';
import '../widgets/streak_feier_overlay.dart';
import '../theme/app_theme.dart';

// ── Geo-Cache (einmal laden, überall nutzen) ──────────────────────────────────

Map<String, List<List<Offset>>>? _geoCache;

/// Schritt 1: ne_10m als Basis laden (alle Länder, hohe Qualität, ein Netzwerk-Call)
Future<Map<String, List<List<Offset>>>> _ladeGeoRings() async {
  if (_geoCache != null) return _geoCache!;
  final raw = await rootBundle.loadString('assets/geo/ne_10m_countries.geojson');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final features = json['features'] as List;
  // Rohe Ringe zuerst je ISO-Code SAMMELN statt sofort überschreiben: manche
  // Länder haben mehrere Features mit demselben ISO_A2 (z.B. Frankreich +
  // das winzige Clipperton-Atoll, Kasachstan + die Enklave Baikonur,
  // Brasilien + Inselterritorien, Australien + Außengebiete) — ein simples
  // rings[iso2] = ... hätte die Hauptlandmasse durch das zufällig zuletzt
  // gelesene Fragment ersetzt (führte z.B. dazu, dass für FR nur noch
  // Clipperton Island statt Frankreich gerendert wurde).
  final rohRinge = <String, List<List<Offset>>>{};
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
    if (rs.isNotEmpty) (rohRinge[iso2] ??= []).addAll(rs);
  }
  final rings = <String, List<List<Offset>>>{
    for (final e in rohRinge.entries) e.key: _nachbearbeiteRinge(e.key, e.value),
  };
  _geoCache = rings;
  return rings;
}

/// Inselstaaten/-reiche Länder, bei denen Küsten- bzw. Hauptinseln fester
/// Bestandteil des erkennbaren Umrisses sind — hier greift NUR der (auf 0,5%
/// gelockerte) Flächenfilter, aber NICHT der Exklaven-Distanzfilter, sonst
/// würden z.B. Japans Hokkaido/Kyushu/Shikoku oder Neuseelands Südinsel als
/// "zu weit entfernt" verworfen. Portugal bewusst NICHT hier: Azoren/Madeira
/// sollen für den Umriss-Quiz gerade weggefiltert werden (siehe
/// kLandspezifischeMaxDistanz).
const Set<String> kInselLaenderBehalten = {
  'DK', 'NO', 'FI', 'EE', 'HR', 'GR', 'ID', 'PH', 'JP', 'NZ', 'IS',
  'GB', 'IE', 'CU', 'SB', 'VU', 'PG', 'FJ',
};

/// Länderspezifisch verschärfte Exklaven-Distanzschwelle (siehe
/// _entferneWeitEntfernteExklaven) für Länder mit einer bekannten, weit
/// entfernten Übersee-Region, die für den Umriss-Quiz nicht mit ins Bild
/// soll. FR bewusst 10° statt der ursprünglich angefragten 5°: bei 5° würde
/// auch Korsika (~8,6° vom Festlands-Schwerpunkt) mit rausgefiltert werden,
/// das anders als Französisch-Guayana (~70°) zum allgemein erkannten
/// Frankreich-Umriss dazugehört (vergleichbar mit Sizilien/Sardinien bei
/// Italien, die bei ~5° Abstand liegen und bewusst erhalten bleiben).
const Map<String, double> kLandspezifischeMaxDistanz = {
  'PT': 5, // nur iberische Halbinsel, ohne Azoren/Madeira
  'ES': 8, // ohne Kanarische Inseln, Balearen (~6°) bleiben
  'FR': 10, // ohne Französisch-Guayana, Korsika (~8,6°) bleibt
  'CL': 10, // ohne Osterinsel
};

/// Länderspezifische Nachbearbeitung nach dem allgemeinen Flächen-Filter.
/// Norwegen: Svalbard liegt als eigener Ring weit nördlich vom Festland
/// getrennt (ca. 74-81°N, Festland bis Nordkapp nur ~71°N) und wird im
/// Umriss-Quiz bewusst weggelassen — sonst wirkt die Silhouette wie zwei
/// unzusammenhängende Flecken statt einem erkennbaren Festlands-Umriss.
List<List<Offset>> _nachbearbeiteRinge(String iso2, List<List<Offset>> rs) {
  final minFlaechenAnteil = kInselLaenderBehalten.contains(iso2) ? 0.005 : 0.01;
  final nachFlaeche =
      _filterRings(_entzerreAntimeridian(rs), minFlaechenAnteil: minFlaechenAnteil);
  final gefiltert = kInselLaenderBehalten.contains(iso2)
      ? nachFlaeche
      : _entferneWeitEntfernteExklaven(nachFlaeche,
          schwelleGrad: kLandspezifischeMaxDistanz[iso2] ?? 45.0);
  if (iso2 != 'NO' || gefiltert.length <= 1) return gefiltert;
  double avgLat(List<Offset> r) =>
      r.map((p) => p.dy).reduce((a, b) => a + b) / r.length;
  final ohneSvalbard = gefiltert.where((r) => avgLat(r) < 73.0).toList();
  return ohneSvalbard.isEmpty ? gefiltert : ohneSvalbard;
}

/// Manche Länder-Geometrien in ne_10m enthalten neben dem Kernland auch weit
/// entfernte Übersee-Gebiete mit demselben ISO-Code — z.B. Französisch-
/// Guayana (Südamerika, ~70° von Frankreich entfernt) oder Alaska (~59° von
/// den kontinentalen USA entfernt). Diese Gebiete sind flächenmäßig nicht
/// winzig und überleben daher den reinen Prozent-Filter oben, würden aber als
/// gemeinsame BoundingBox mit dem Kernland dessen Silhouette auf einen
/// unkenntlichen Fleck in der Ecke schrumpfen lassen. Default-Schwelle 45°:
/// empirisch an den ne_10m-Daten kalibriert — liegt bequem zwischen den
/// größten legitimen Archipel-Abständen (Tasmanien ~22°, Kiribati-Inseln bis
/// ~30°, Azoren ~20°) und den beiden bekannten Exklaven-Fällen (Guayana
/// ~70°, Alaska ~59°), sodass echte Archipel-Staaten unangetastet bleiben.
/// Für Länder mit bekannter Übersee-Exklave wird stattdessen die engere
/// Schwelle aus kLandspezifischeMaxDistanz übergeben.
List<List<Offset>> _entferneWeitEntfernteExklaven(List<List<Offset>> rs,
    {double schwelleGrad = 45.0}) {
  if (rs.length <= 1) return rs;
  Offset centroid(List<Offset> r) {
    double sx = 0, sy = 0;
    for (final p in r) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / r.length, sy / r.length);
  }

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
  final kernIdx = areas.indexOf(areas.reduce(max));
  final kernMitte = centroid(rs[kernIdx]);
  final ergebnis = [
    for (var i = 0; i < rs.length; i++)
      if ((centroid(rs[i]) - kernMitte).distance <= schwelleGrad) rs[i],
  ];
  return ergebnis.isEmpty ? rs : ergebnis;
}

/// Länder, die den Antimeridian (±180°) durchqueren (Russland via Tschukotka,
/// Fidschi, USA via die Aleuten, grenzwertig auch Kiribati/Neuseeland) ergeben
/// mit rohen Längengrad-Werten eine Bounding-Box, die fast den gesamten
/// Globus umfasst — die eigentliche Landmasse wird dadurch auf einen
/// winzigen Streifen zusammengequetscht (sichtbar z.B. bei Russland: ein
/// Fragment bei -179° und eines bei +179° liegen in rohen Lng-Werten fast
/// 360° auseinander statt ~2°). Erkennung: ein naiver Lng-Sprung > 180°
/// zwischen dem west- und östlichsten Punkt ist bei echten Ländern (anders
/// als beim Antimeridian-Sprung) praktisch ausgeschlossen. Fix: negative
/// Längengrade um 360° verschieben, damit z.B. Tschukotka (-179°) und
/// Kaliningrad (+19°) einen zusammenhängenden Wertebereich statt eines
/// Sprungs bei ±180° ergeben.
List<List<Offset>> _entzerreAntimeridian(List<List<Offset>> rs) {
  double minLng = double.infinity, maxLng = double.negativeInfinity;
  for (final r in rs) {
    for (final p in r) {
      if (p.dx < minLng) minLng = p.dx;
      if (p.dx > maxLng) maxLng = p.dx;
    }
  }
  if (maxLng - minLng <= 180) return rs;
  return rs
      .map((r) => r.map((p) => Offset(p.dx < 0 ? p.dx + 360 : p.dx, p.dy)).toList())
      .toList();
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
      if (rs.isNotEmpty) rings[iso2] = _nachbearbeiteRinge(iso2, rs);
    } catch (_) {
      // Kein Einzelfile für $iso2 → ne_50m-Fallback bleibt
    }
  }));
}

List<Offset> _ring(List coords) =>
    coords.map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList();

// Standard-Schwelle 1% des größten Rings: entfernt Kartografie-Rauschen
// (Einzelpunkt-Artefakte, Mini-Riffe, winzige Nebeninseln) und — in
// Kombination mit dem Umriss-Ausschluss kleiner/unmarkanter Länder
// (kUmrissAusschluss in alle_laender.dart) — auch die vielen kleinen
// Nebeninseln "normaler" Länder (z.B. Italiens winzige Mittelmeerinseln
// abseits von Sizilien/Sardinien). Für Archipel-/Inselstaaten wie Malediven,
// Kiribati, Griechenland, Japan etc. wird stattdessen die gelockerte 0,5%-
// Schwelle übergeben (siehe kInselLaenderBehalten in _nachbearbeiteRinge),
// da dort jede Insel zur erkennbaren Form dazugehört und es kein einzelnes
// "Festland" gibt.
List<List<Offset>> _filterRings(List<List<Offset>> rs, {double minFlaechenAnteil = 0.01}) {
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
  return [
    for (var i = 0; i < rs.length; i++)
      if (areas[i] >= maxA * minFlaechenAnteil) rs[i],
  ];
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

  // Level-Skip-Button (Rewarded Ad, sitzt in der AppBar)
  bool _levelSkipLoading = false;

  // Timer — Dauer hängt vom Modus der jeweils aktuellen Frage ab (siehe
  // timerSekundenFuerModus), nicht mehr fix 15s. _timerGesamt == 0 bedeutet
  // kein Timer für die aktuelle Frage (weder Countdown noch UI-Anzeige).
  Timer? _countdownTimer;
  int _countdown = 0;
  int _timerGesamt = 0;

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
          // Nutzt dasselbe abschnitt.hatTimer-Flag, das lernpfad_screen.dart
          // bereits für den Timer-Hinweis in der Abschnitts-Übersicht liest
          // (korrekt gesetzt für den jeweils LETZTEN Abschnitt eines
          // Kontinents) — NICHT schwierigkeitsgrad == 4, das bei Südamerika/
          // Ozeanien (nur 3 statt 4 Abschnitte) nie zutrifft.
          hatTimer: stationKontext(widget.station!.id)?.$2.hatTimer ?? false,
        );
      }
    }

    // GeoJSON laden falls Umriss-Modi vorhanden
    bool istUmrissModus(LernModus m) =>
        m == LernModus.umrissBild ||
        m == LernModus.umrissMultiple ||
        m == LernModus.umrissEingabe;
    final brauchtGeo = session.aktiveFragen.any((f) => istUmrissModus(f.modus));
    if (brauchtGeo) {
      try {
        final rings = await _ladeGeoRings();
        // Hochauflösende Einzeldateien für Quiz-Länder nachladen
        final quizIsos = session.aktiveFragen
            .where((f) => istUmrissModus(f.modus))
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
    } else if (frage.modus == LernModus.hauptstaedteEingabe ||
        frage.modus == LernModus.flaggenQuizEingabe ||
        frage.modus == LernModus.umrissEingabe) {
      _textCtrl.clear();
      setState(() => _eingabeBestaetigt = false);
    }
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    final sekunden = timerSekundenFuerModus(
        _session?.aktuelleFrage?.modus ?? LernModus.zufallsFakt);
    if (sekunden <= 0) {
      // Kein Timer für diesen Modus (z.B. preisSchaetzen, zufallsFakt,
      // bekanntesGebaeude) — auch in Abschnitt 4 keine Zeitanzeige, freies
      // Nachdenken/Schätzen.
      setState(() {
        _timerGesamt = 0;
        _countdown = 0;
      });
      return;
    }
    setState(() {
      _timerGesamt = sekunden;
      _countdown = sekunden;
    });
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

  // Kurzes Vibrations-Feedback bei Antwort-Auswertung — kurzer Puls bei
  // richtig, spürbar längerer bei falsch (inkl. Timer-Ablauf), respektiert
  // den Vibration-Schalter in den Einstellungen. Nutzt das vibration-Paket
  // (direkter Vibrator-Zugriff) statt HapticFeedback.*: Flutters
  // HapticFeedback-API ruft auf Android IMMER View.performHapticFeedback()
  // auf, was von einer separaten System-Einstellung ("Tipp-/Berührungs-
  // Feedback") abhängt und bei vielen Geräten (u.a. Samsung One UI) trotz
  // erteilter VIBRATE-Berechtigung stumm bleibt, wenn diese Einstellung aus
  // ist — das vibration-Paket spricht den Vibrationsmotor direkt an und
  // umgeht dieses Problem. Bewusst fire-and-forget (kein await): die Haptik
  // soll den UI-Fluss nicht verzögern.
  void _vibriereAntwort(bool richtig) {
    EinstellungenService.vibrationAktiv.then((aktiv) async {
      if (!aktiv) return;
      if (!await Vibration.hasVibrator()) return;
      if (richtig) {
        Vibration.vibrate(duration: 40);
      } else {
        Vibration.vibrate(duration: 70);
      }
    });
  }

  // Zeigt nur noch das Feedback an — der Übergang zur nächsten Frage
  // erfolgt nicht mehr automatisch, sondern erst wenn der Spieler den
  // Weiter-Button antippt (siehe _weiterTippen).
  void _timerAbgelaufen() {
    if (_showFeedback || _session == null) return;
    _vibriereAntwort(false);
    setState(() {
      _showFeedback = true;
      _feedbackRichtig = false;
      _gewahlteAntwort = null;
    });
  }

  // ── Antwort-Handler ────────────────────────────────────────────────────────

  void _antwortGewaehlt(String antwort) {
    if (_showFeedback || _session == null) return;
    _stopCountdown();
    final frage = _session!.aktuelleFrage;
    if (frage == null) return;
    final richtig = antwort == frage.richtigeAntwort;
    _vibriereAntwort(richtig);
    setState(() {
      _gewahlteAntwort = antwort;
      _showFeedback = true;
      _feedbackRichtig = richtig;
    });
    // Kein Auto-Übergang mehr: der Spieler bestätigt manuell mit "Weiter"
    // (siehe _weiterTippen), auch bei Grenzketten-Rätsel mit zusätzlicher
    // Route+Erklärung — dort gibt es jetzt beliebig viel Lesezeit statt
    // einer festen 2600ms-Verzögerung.
  }

  bool _eingabeIstRichtig(String eingabe, String richtigeAntwort, String iso2) {
    final norm = normalisiereEingabe(eingabe);
    if (norm == normalisiereEingabe(richtigeAntwort)) return true;
    final aliase = laenderAliase[iso2] ?? const [];
    return aliase.any((a) => normalisiereEingabe(a) == norm);
  }

  void _eingabeBestaetigen() {
    if (_eingabeBestaetigt || _session == null) return;
    final frage = _session!.aktuelleFrage;
    if (frage == null) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _stopCountdown();
    final richtig = _eingabeIstRichtig(text, frage.richtigeAntwort, frage.laenderCode);
    _vibriereAntwort(richtig);
    setState(() {
      _eingabeBestaetigt = true;
      _showFeedback = true;
      _feedbackRichtig = richtig;
      _gewahlteAntwort = text;
    });
    // Kein Auto-Übergang mehr: Weiter-Button in _EingabeUI/_weiterTippen.
  }

  void _sortierPruefen() {
    if (_sortierGeprueft || _session == null) return;
    final frage = _session!.aktuelleFrage;
    if (frage == null) return;
    _stopCountdown();
    final richtig = _sortierReihenfolge.join(',') == frage.richtigeAntwort;
    _vibriereAntwort(richtig);
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
    _vibriereAntwort(richtig);
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

  // ── Weiter-Button (MC-/Umriss-/Grenzketten-/Eingabe-Modi) ────────────────────
  //
  // Sortierspiel und Preisschätzen haben ihre eigenen Weiter-Handler
  // (_sortierWeiter, _preisWeiter) mit modusspezifischer Nachbearbeitung —
  // diese Methode deckt alle übrigen Modi ab, die einfach nur richtig/falsch
  // werten und weiterrücken (inkl. abgelaufenem Timer, siehe
  // _timerAbgelaufen, wo genau wie bei einer falschen Antwort verfahren
  // wird).
  void _weiterTippen() {
    if (_session == null) return;
    if (_feedbackRichtig) {
      _session!.richtigeAntwortVerarbeiten();
    } else {
      _session!.falscheAntwortVerarbeiten();
    }
    if (_eingabeBestaetigt) {
      _textCtrl.clear();
      setState(() => _eingabeBestaetigt = false);
    }
    _vorruecken();
  }

  /// true für Modi, die ihren eigenen Weiter-Button mitbringen (Ergebnis-
  /// Ansicht mit zusätzlichen Werten/Erklärung) — der globale Weiter-Button
  /// unten im build() wird für diese Modi unterdrückt, damit er nicht doppelt
  /// erscheint.
  bool _hatEigenenWeiterButton(LernModus m) =>
      m == LernModus.sortierSpiel || m == LernModus.preisSchaetzen;

  // ── Level-Skip (Rewarded Ad) — überspringt die GANZE Station ──────────────
  //
  // Sitzt in der AppBar (siehe build()), nicht mehr unten bei den
  // Antwortmöglichkeiten — das war der alte, pro-Frage-Skip. Nach
  // erfolgreich angesehener Rewarded Ad gilt die komplette Station als
  // übersprungen: kein Punktgewinn, kein Eintrag in die Wiederholungsrunde,
  // aber die nächste Station wird freigeschaltet (siehe
  // FortschrittService.stationUeberspringenUndAbschnittPruefen). In der
  // Wiederholungsrunde gibt es keine "nächste Station" — dort schließt
  // Skip stattdessen direkt den Abschnitt ab, genau wie ein regulär
  // beendeter Durchlauf ohne verbleibende falsche Fragen.
  Future<void> _levelSkippen() async {
    if (_session == null || _levelSkipLoading) return;
    setState(() => _levelSkipLoading = true);
    final belohnt = await AdService.zeigeRewardedAd(onBelohnt: () {});
    if (!mounted) return;
    setState(() => _levelSkipLoading = false);
    if (!belohnt) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t(
            'Werbung aktuell nicht verfügbar, versuch es später erneut')),
        backgroundColor: const Color(0xFF888888),
      ));
      return;
    }
    _stopCountdown();
    if (widget.istWiederholungsrunde) {
      await FortschrittService.wiederholungAbschliessen(
          widget.wiederholungsAbschnittId!);
    } else {
      await FortschrittService.stationUeberspringenUndAbschnittPruefen(
          widget.station!.id);
    }
    if (!mounted) return;
    Navigator.pop(context);
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
    // DEBUG (Bug 2 — Stationsbutton-Bug nach Level 5): jeden Schritt dieses
    // Ablaufs protokollieren, um zu sehen, ob/wo der Ablauf nach der 5.
    // Station hängen bleibt (Verdacht: await auf den Interstitial-Trigger).
    // ignore: avoid_print
    print('[StationFertig] gestartet für Station ${widget.station?.id}');
    _stopCountdown();
    setState(() => _showFeedback = false);

    // MUSS vor stationAbschliessen() laufen: das schreibt unconditionally
    // den "letzte Aktivität"-Zeitstempel, den streakAktualisieren() für die
    // Tagesdifferenz-Berechnung braucht — danach aufgerufen würde die
    // Streak nie erhöht werden (Differenz wäre immer 0).
    // Streak erhöhen und ggf. feiern — bewusst hier: direkt nach dem
    // Streak-Update und VOR Abzeichen-Popup, Interstitial und Navigation
    // zurück zum Lernpfad, damit der Moment nicht mit anderen Overlays
    // kollidiert. Blockiert, bis der Nutzer die Feier weggetippt hat.
    //
    // Derselbe Aufruf steckt hinter dem Debug-Button in den Einstellungen
    // (siehe streakErhoehenUndFeiern) — es gibt nur diesen einen Pfad.
    final (alterStreak, neuerStreak) = await streakErhoehenUndFeiern(context);
    // ignore: avoid_print
    print('[StationFertig] streakErhoehenUndFeiern() fertig: '
        '$alterStreak -> $neuerStreak');
    if (!mounted) return;

    if (widget.istWiederholungsrunde) {
      // ignore: avoid_print
      print('[StationFertig] Zweig: istWiederholungsrunde -> wiederholungAbschliessen');
      await FortschrittService.wiederholungAbschliessen(
          widget.wiederholungsAbschnittId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('🎉 Abschnitt vollständig abgeschlossen!')),
        backgroundColor: const Color(0xFF4A9E4A),
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
    // ignore: avoid_print
    print('[StationFertig] stationAbschliessen() fertig');

    // Kontinent-/Meilenstein-Abzeichen hängen am Lernpfad-Fortschritt, nicht
    // an Tages-Challenges -> hier prüfen, statt erst beim nächsten Challenge-
    // Abschluss (sonst würde ein neues Abzeichen erst viel später auffallen).
    final neueAbzeichen = await AbzeichenService.pruefeNachLernpfadFortschritt();
    // ignore: avoid_print
    print('[StationFertig] pruefeNachLernpfadFortschritt() fertig, '
        'neueAbzeichen=${neueAbzeichen.length}, mounted=$mounted');
    if (mounted && neueAbzeichen.isNotEmpty) {
      await AbzeichenPopup.zeigen(context, neueAbzeichen);
      // ignore: avoid_print
      print('[StationFertig] AbzeichenPopup.zeigen() fertig');
    }
    if (!mounted) return;

    // Nach JEDEM Stationsabschluss (nie mitten in einer laufenden Frage) —
    // zeigt selbst nur, wenn genug Stationen + genug Zeit seit der letzten
    // Anzeige vergangen sind (siehe AdService.pruefeUndZeigeInterstitial).
    // BEWUSST NICHT awaited: die Werbe-Anzeige ist rein optional und darf
    // die Navigation zur nächsten Station niemals verzögern oder (bei einem
    // Fehler) blockieren — beide Vorgänge laufen unabhängig voneinander.
    // pruefeUndZeigeInterstitial()/zeigeInterstitialFallsBereit() fangen
    // etwaige Fehler intern ab, ein nicht awaiteter Fehler dort führt daher
    // nicht zu einer unbehandelten Exception.
    // ignore: avoid_print
    print('[StationFertig] triggere AdService.pruefeUndZeigeInterstitial() (nicht awaited)');
    unawaited(AdService.pruefeUndZeigeInterstitial());

    final letzteStation = FortschrittService.istLetzteStationImAbschnitt(widget.station!.id);
    // ignore: avoid_print
    print('[StationFertig] istLetzteStationImAbschnitt=$letzteStation');
    if (!letzteStation) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // Letzte Station: Wiederholung prüfen
    final abschnittId = _abschnittId();
    final wdhNoetig =
        await FortschrittService.wiederholungNoetig(abschnittId);
    // ignore: avoid_print
    print('[StationFertig] letzte Station im Abschnitt $abschnittId, wdhNoetig=$wdhNoetig');

    if (!wdhNoetig) {
      await FortschrittService.wiederholungAbschliessen(abschnittId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('🎉 Perfekt! Abschnitt abgeschlossen!')),
        backgroundColor: const Color(0xFF4A9E4A),
      ));
      Navigator.pop(context);
      return;
    }

    // Wiederholung nötig: KEIN automatischer Start mehr — der Abschnitt
    // bleibt bewusst unabgeschlossen (wiederholungAbschliessen() wird erst
    // beim tatsächlichen Abschluss der Wiederholungsrunde aufgerufen, siehe
    // oben istWiederholungsrunde-Zweig). Der Spieler startet die
    // Wiederholung stattdessen bewusst über die Geschenk-Kachel im
    // Lernpfad (siehe home_screen.dart _MeilensteinBtn /
    // _HomeScreenState._wiederholungTippen). Einfach normal zum Lernpfad
    // zurückkehren, wie nach jeder anderen Station auch.
    // ignore: avoid_print
    print('[StationFertig] Wiederholung nötig für $abschnittId — kehre normal zum Lernpfad '
        'zurück, Start jetzt über die Geschenk-Kachel statt automatisch');
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

    // Nutzt den tatsächlichen Modus der geladenen Frage statt
    // widget.station!.modus — station_session_service.dart kann bei
    // "pensionierten" Modi (Länderpool welt-/abschnittsweit ausgeschöpft)
    // zur Spielzeit auf einen anderen, noch aktiven Modus ausweichen (siehe
    // _pensionierterErsatz). Der Titel muss diese Abweichung mitgehen, sonst
    // zeigt er einen anderen Modus an als tatsächlich gespielt wird.
    final titel = widget.istWiederholungsrunde
        ? t('🔄 Wiederholungsrunde')
        : lernModusLabel(frage?.modus ?? widget.station!.modus);

    return Scaffold(
      backgroundColor: kHintergrund,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2D),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(titel,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: LevelSkipButton(
                  loading: _levelSkipLoading, onTap: _levelSkippen),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          // Animiert den Balken flüssig zum neuen Fortschritt statt beim
          // Weiterrücken ruckartig zu springen — TweenAnimationBuilder
          // interpoliert automatisch vom zuletzt angezeigten Wert zum neuen
          // `end`, ein manuelles Mitführen des alten Werts ist nicht nötig.
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: session.fortschritt),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, wert, child) => LinearProgressIndicator(
              value: wert,
              minHeight: 6,
              backgroundColor: const Color(0xFF2A4A3A),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4A9E4A)),
            ),
          ),
        ),
      ),
      body: frage == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_timerGesamt > 0)
                  _TimerBar(countdown: _countdown, gesamt: _timerGesamt),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              // zentriert automatisch WENN der Inhalt
                              // kleiner ist als minHeight — bei zu großem
                              // Inhalt wird stattdessen normal gescrollt,
                              // keine Zentrierung erzwungen, kein Overflow
                              children: [
                                _frageWidget(frage),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Der Weiter-Button ist IMMER im Baum und wird nur ein-/
                // ausgeblendet — vorher wurde er erst bei _showFeedback
                // eingefügt, wodurch die Column beim Antworten plötzlich ein
                // Kind mehr bekam und Frage+Antworten darüber nach oben
                // sprangen. Da der Button dauerhaft mitlayoutet wird, ist sein
                // Platz von Anfang an reserviert; bewusst KEINE hartkodierte
                // SizedBox-Höhe, denn die tatsächliche Höhe hängt vom
                // Text-Scale des Geräts ab und würde sonst überlaufen.
                // IgnorePointer verhindert, dass der unsichtbare Button
                // antippbar ist.
                if (!_hatEigenenWeiterButton(frage.modus))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: AnimatedOpacity(
                      opacity: _showFeedback ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_showFeedback,
                        child: _WeiterButton(onTap: _weiterTippen),
                      ),
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
      LernModus.hauptstaedteEingabe ||
      LernModus.flaggenQuizEingabe ||
      LernModus.umrissEingabe =>
        _EingabeUI(
          frage: f,
          controller: _textCtrl,
          bestaetigt: _eingabeBestaetigt,
          showFeedback: _showFeedback,
          feedbackRichtig: _feedbackRichtig,
          onBestaetigen: _eingabeBestaetigen,
          geoRings: _geoRings,
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
      LernModus.grenzkettenRaetsel => _GrenzkettenUI(
          frage: f,
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

class _TimerBar extends StatefulWidget {
  final int countdown;
  final int gesamt;
  const _TimerBar({required this.countdown, required this.gesamt});

  @override
  State<_TimerBar> createState() => _TimerBarState();
}

class _TimerBarState extends State<_TimerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulsCtrl;

  @override
  void initState() {
    super.initState();
    _pulsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (widget.countdown / widget.gesamt).clamp(0.0, 1.0);
    // Rot + Pulsieren nur in den letzten 3 Sekunden (absolut, nicht
    // prozentual) — bei kurzen Timern (15s) fällt das mit der 20%-Marke
    // zusammen, bei längeren (30-40s) ist es ein bewusst enges Warnfenster.
    final kritisch = widget.countdown <= 3;
    final color = kritisch
        ? const Color(0xFFD94040)
        : fraction > 0.5
            ? const Color(0xFF4A9E4A)
            : const Color(0xFFD98C30);

    final bar = Column(
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
              '${widget.countdown}s',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ),
      ],
    );

    if (!kritisch) return bar;
    return AnimatedBuilder(
      animation: _pulsCtrl,
      builder: (context, child) =>
          Opacity(opacity: 0.55 + 0.45 * _pulsCtrl.value, child: child),
      child: bar,
    );
  }
}

// ── Hilfsfunktionen ────────────────────────────────────────────────────────────

const _diakritikaErsatz = {
  'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss',
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Normalisiert Nutzer-Eingaben für die Eingabe-Modi: klein geschrieben,
/// Umlaute/Akzente auf ASCII abgebildet, Bindestriche/Apostrophe und
/// Mehrfach-Leerzeichen vereinheitlicht — toleriert also z.B. "Suedafrika"
/// für "Südafrika" oder "Cote d Ivoire" für "Côte d'Ivoire".
String normalisiereEingabe(String s) {
  var t = s.trim().toLowerCase();
  _diakritikaErsatz.forEach((von, nach) => t = t.replaceAll(von, nach));
  t = t.replaceAll(RegExp(r"[-'’]"), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

Country? _countryByIso2(String iso2) {
  if (iso2.isEmpty) return null;
  return countries.cast<Country?>().firstWhere(
    (c) => c?.iso2 == iso2,
    orElse: () => null,
  );
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

// Dauer des Wackelns bei falscher Antwort. Vorher 150ms — das war der Grund,
// warum auf dem Gerät praktisch nichts zu sehen war: bei 60fps sind 150ms nur
// 9 Frames, und da die Amplitude zusätzlich mit exp(-5t) abklang, war schon
// ab Frame 3 alles vorbei (siehe wackelOffset). Übrig blieb ein Ausschlag von
// ~3px über 2 Frames — technisch lief die Animation, sichtbar war sie nicht.
const kWackelDauer = Duration(milliseconds: 400);

// Gedämpftes Wackeln für eine falsch angetippte Antwort — 3 Ausschläge über
// die volle Animationsdauer, Amplitude klingt exponentiell ab. [t] läuft von
// 0.0 bis 1.0.
//
// Amplitude (6→11px) und Dämpfung (exp(-5t)→exp(-2.5t)) wurden zusammen mit
// kWackelDauer angehoben, damit die Bewegung tatsächlich wahrnehmbar ist: mit
// diesen Werten liegt der erste Ausschlag bei ~9px und auch der dritte noch
// bei ~4px, statt wie zuvor nach zwei Frames unter die Sichtbarkeitsschwelle
// zu fallen. Der abschließende Wert bei t=1.0 bleibt praktisch 0, der Button
// kehrt also exakt an seine Position zurück.
double wackelOffset(double t) {
  final gedaempft = exp(-t * 2.5);
  return sin(t * pi * 6) * 11 * gedaempft;
}

// Leichtgewichtige Wiederverwendung des Wackel-Effekts (siehe wackelOffset)
// für die Bild-Kachel-Modi (Flaggen/Umriss Multiple), die ihre eigene
// Border-basierte Farbgebung behalten (Bild-Kacheln können nicht wie
// Text-Buttons flächig grün/rot eingefärbt werden) — nur das Wackeln bei
// falscher Wahl wird hier übernommen, kein Häkchen/Farbverlauf.
class _WackelTile extends StatefulWidget {
  final bool falschGewaehlt;
  final Widget child;
  const _WackelTile({required this.falschGewaehlt, required this.child});

  @override
  State<_WackelTile> createState() => _WackelTileState();
}

class _WackelTileState extends State<_WackelTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wackelCtrl;

  @override
  void initState() {
    super.initState();
    _wackelCtrl = AnimationController(vsync: this, duration: kWackelDauer);
  }

  @override
  void didUpdateWidget(covariant _WackelTile old) {
    super.didUpdateWidget(old);
    if (!old.falschGewaehlt && widget.falschGewaehlt) {
      if (kDebugMode) debugPrint('[Wackel/Kachel] Start — forward(from: 0)');
      _wackelCtrl.forward(from: 0);
    } else if (!widget.falschGewaehlt && old.falschGewaehlt) {
      _wackelCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _wackelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _wackelCtrl,
      builder: (context, child) {
        final dx =
            widget.falschGewaehlt ? wackelOffset(_wackelCtrl.value) : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

class _AntwortButton extends StatefulWidget {
  final String text;
  final Widget? leading;
  final bool showFeedback;
  final bool istRichtig;
  final bool istGewaehlt;
  final bool feedbackRichtig;
  final VoidCallback? onTap;

  const _AntwortButton({
    required this.text,
    this.leading,
    required this.showFeedback,
    required this.istRichtig,
    required this.istGewaehlt,
    required this.feedbackRichtig,
    this.onTap,
  });

  @override
  State<_AntwortButton> createState() => _AntwortButtonState();
}

class _AntwortButtonState extends State<_AntwortButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wackelCtrl;

  bool get _istFalschGewaehlt =>
      widget.showFeedback && widget.istGewaehlt && !widget.feedbackRichtig;

  @override
  void initState() {
    super.initState();
    _wackelCtrl = AnimationController(vsync: this, duration: kWackelDauer);
  }

  bool _warFalschGewaehlt(_AntwortButton w) =>
      w.showFeedback && w.istGewaehlt && !w.feedbackRichtig;

  @override
  void didUpdateWidget(covariant _AntwortButton old) {
    super.didUpdateWidget(old);
    // Wackeln nur EINMAL auslösen: exakt beim Übergang zu "dieser Button
    // wurde falsch gewählt" — nicht bei jedem Rebuild (verhindert
    // Doppel-Animation bei schnellem Durchklicken).
    //
    // Der Übergang wird über den vorherigen Wert von _istFalschGewaehlt
    // selbst geprüft, nicht mehr über old.showFeedback: Letzteres traf nur zu,
    // wenn showFeedback im SELBEN Rebuild von false auf true kippte, und ging
    // damit leer aus, sobald der Screen zwischendurch noch einmal baute (z.B.
    // durch den Countdown-Tick) oder das Feedback bereits stand, als die Wahl
    // gesetzt wurde.
    if (!_warFalschGewaehlt(old) && _istFalschGewaehlt) {
      if (kDebugMode) {
        debugPrint('[Wackel/Button] Start "${widget.text}" — forward(from: 0)');
      }
      _wackelCtrl.forward(from: 0);
    } else if (!widget.showFeedback && old.showFeedback) {
      _wackelCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _wackelCtrl.dispose();
    super.dispose();
  }

  Color get _bgColor {
    if (!widget.showFeedback) return const Color(0xFFEAEAE5);
    if (widget.istRichtig) return const Color(0xFF4A9E4A);
    if (_istFalschGewaehlt) return const Color(0xFFE53935);
    return const Color(0xFFEAEAE5);
  }

  Color get _textColor {
    if (!widget.showFeedback) return const Color(0xFF1a1a1a);
    if (widget.istRichtig) return Colors.white;
    if (_istFalschGewaehlt) return Colors.white;
    return const Color(0xFF888888);
  }

  @override
  Widget build(BuildContext context) {
    // Die richtige Antwort blendet sanft grün ein (300ms, kein Wackeln) —
    // der falsch gewählte Button reagiert schneller (150ms) UND wackelt.
    final faerbDauer = widget.istRichtig && !widget.istGewaehlt
        ? const Duration(milliseconds: 300)
        : const Duration(milliseconds: 150);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _wackelCtrl,
          builder: (context, child) {
            final dx =
                _istFalschGewaehlt ? wackelOffset(_wackelCtrl.value) : 0.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: AnimatedContainer(
            duration: faerbDauer,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
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

// ── Weiter-Button ──────────────────────────────────────────────────────────────
//
// Exakt im Stil von ChallengeFertigButton (Tages-Challenges, siehe
// widgets/challenge_fertig_button.dart) — 1:1 dieselben Werte für Farbe,
// Radius, Border, Schatten-Offset und Schriftgröße übernommen, damit beide
// Weiter-artigen Buttons der App identisch aussehen.
class _WeiterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WeiterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF4A9E4A),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: const Color(0xFF1A1A1A), width: 2.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0xFF1A1A1A), offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Text(t('Weiter'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

// ── Skip-Button (Frage überspringen, nur nach Rewarded Ad) ─────────────────────
//
// Bewusst dezenter als der Weiter-Button (grau statt grün, kein 3D-Schatten,
// kleiner) und IMMER sichtbar — auch bevor überhaupt geantwortet wurde —
// damit der Spieler jede Frage abbrechen kann, die ihm nicht gefällt.
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
        Text(
          t('Welchem Land gehört diese Flagge?'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              showFeedback: showFeedback,
              istRichtig: opt == frage.richtigeAntwort,
              istGewaehlt: opt == gewaehlt,
              feedbackRichtig: feedbackRichtig,
              onTap: showFeedback ? null : () => onAntwort(opt),
            )),
      ],
    );
  }
}

// ── Grenzketten-Rätsel ──────────────────────────────────────────────────────

class _GrenzkettenUI extends StatelessWidget {
  final Frage frage;
  final String? gewaehlt;
  final bool showFeedback, feedbackRichtig;
  final void Function(String) onAntwort;

  const _GrenzkettenUI({
    required this.frage,
    required this.gewaehlt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onAntwort,
  });

  @override
  Widget build(BuildContext context) {
    final vonIso = frage.meta['vonIso'] as String? ?? '';
    final nachIso = frage.meta['nachIso'] as String? ?? '';
    final von = _countryByIso2(vonIso);
    final nach = _countryByIso2(nachIso);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                children: [
                  FlaggenWidget(countryCode: vonIso, width: 56, height: 36, borderRadius: 6),
                  const SizedBox(height: 6),
                  Text(von?.name ?? vonIso,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF888888)),
            ),
            Expanded(
              child: Column(
                children: [
                  FlaggenWidget(countryCode: nachIso, width: 56, height: 36, borderRadius: 6),
                  const SizedBox(height: 6),
                  Text(nach?.name ?? nachIso,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          t('Auf dem Landweg von {von} nach {nach}: durch welches dieser Länder MUSST du dabei NICHT fahren?', {
            'von': von?.name ?? vonIso,
            'nach': nach?.name ?? nachIso,
          }),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        ...frage.antwortOptionen.map((iso2) {
          final land = _countryByIso2(iso2);
          return _AntwortButton(
            text: land?.name ?? iso2,
            leading: FlaggenWidget(
                countryCode: iso2, width: 32, height: 21, borderRadius: 4),
            showFeedback: showFeedback,
            istRichtig: iso2 == frage.richtigeAntwort,
            istGewaehlt: iso2 == gewaehlt,
            feedbackRichtig: feedbackRichtig,
            onTap: showFeedback ? null : () => onAntwort(iso2),
          );
        }),
        if (showFeedback) ...[
          const SizedBox(height: 8),
          _GrenzkettenRoute(frage: frage),
        ],
      ],
    );
  }
}

class _GrenzkettenRoute extends StatelessWidget {
  final Frage frage;
  const _GrenzkettenRoute({required this.frage});

  @override
  Widget build(BuildContext context) {
    final kette = (frage.meta['kette'] as List<dynamic>?)?.cast<String>() ?? const [];
    final erklaerung = frage.meta['erklaerung'] as String?;
    final routeText =
        kette.map((iso2) => _countryByIso2(iso2)?.name ?? iso2).join(' → ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAE5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Die richtige Route:'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF888888))),
          const SizedBox(height: 4),
          Text(routeText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          if (erklaerung != null) ...[
            const SizedBox(height: 8),
            Text(t(erklaerung),
                style: const TextStyle(fontSize: 12, color: Color(0xFF555555), height: 1.3)),
          ],
        ],
      ),
    );
  }
}

// ── 2-Spalten-Grid ohne Viewport ─────────────────────────────────────────────
//
// Ersetzt GridView.count(shrinkWrap: true): dessen RenderShrinkWrappingViewport
// verweigert Intrinsic-Höhen-Anfragen (siehe IntrinsicHeight in
// _StationQuizScreenState.build für die Vertikal-Zentrierung) mit einer
// Exception ("does not support returning intrinsic dimensions") — bricht die
// komplette Frage-Anzeige ab, sobald ein Antwort-Grid im Baum steckt. Baut
// denselben 2-Spalten-Look aus normalen Row/Column-Widgets, die Intrinsic-
// Höhen-Berechnung unterstützen.
Widget zweiSpaltenGrid(
  List<Widget> children, {
  required double childAspectRatio,
  double mainAxisSpacing = 12,
  double crossAxisSpacing = 12,
}) {
  final rows = <Widget>[];
  for (var i = 0; i < children.length; i += 2) {
    if (i > 0) rows.add(SizedBox(height: mainAxisSpacing));
    final zweites = i + 1 < children.length ? children[i + 1] : null;
    rows.add(Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child:
                AspectRatio(aspectRatio: childAspectRatio, child: children[i])),
        SizedBox(width: crossAxisSpacing),
        Expanded(
          child: zweites == null
              ? const SizedBox.shrink()
              : AspectRatio(aspectRatio: childAspectRatio, child: zweites),
        ),
      ],
    ));
  }
  return Column(children: rows);
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
        zweiSpaltenGrid(
          childAspectRatio: 1.5,
          frage.antwortOptionen.map((iso2) {
            Color border = Colors.transparent;
            if (showFeedback) {
              if (iso2 == frage.richtigeAntwort) {
                border = const Color(0xFF4A9E4A);
              } else if (iso2 == gewaehlt && !feedbackRichtig) {
                border = const Color(0xFFD94040);
              }
            }
            return _WackelTile(
              falschGewaehlt:
                  showFeedback && iso2 == gewaehlt && !feedbackRichtig,
              child: GestureDetector(
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
      final emojis = LocaleService.istEnglisch ? sektorEmojisEn : sektorEmojis;
      final emoji = emojis[opt] ?? '';
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
              showFeedback: showFeedback,
              istRichtig: opt == frage.richtigeAntwort,
              istGewaehlt: opt == gewaehlt,
              feedbackRichtig: feedbackRichtig,
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
  final Map<String, List<List<Offset>>> geoRings;

  const _EingabeUI({
    required this.frage,
    required this.controller,
    required this.bestaetigt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onBestaetigen,
    this.geoRings = const {},
  });

  // Zeigt den Reiz je nach Modus: Hauptstädte fragt nach der Hauptstadt eines
  // sichtbaren Landes (Flagge+Name verraten hier nichts), Flaggen/Umriss
  // fragen NACH dem Land selbst -> Name darf hier nicht mit angezeigt werden.
  Widget _buildReiz() {
    switch (frage.modus) {
      case LernModus.flaggenQuizEingabe:
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FlaggenWidget(
              countryCode: frage.laenderCode, width: 220, height: 145, borderRadius: 12),
        );
      case LernModus.umrissEingabe:
        final rings = geoRings[frage.laenderCode] ?? [];
        final geoLoaded = geoRings.isNotEmpty;
        return Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFFDFF2E1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: !geoLoaded
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
              : rings.isEmpty
                  ? const Center(child: Text('🗺️', style: TextStyle(fontSize: 52)))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CustomPaint(painter: _UmrissPainter(rings: rings)),
                    ),
        );
      default:
        return _LandHeader(iso2: frage.laenderCode);
    }
  }

  String get _hintText => switch (frage.modus) {
        LernModus.flaggenQuizEingabe || LernModus.umrissEingabe => t('Land eingeben…'),
        _ => t('Hauptstadt eingeben…'),
      };

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
        _buildReiz(),
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
            decoration: InputDecoration(
              hintText: _hintText,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => onBestaetigen(),
          ),
        ),
        if (showFeedback) ...[
          const SizedBox(height: 12),
          Text(
            feedbackRichtig
                ? t('✅ Richtig!')
                : t('❌ Richtig war: {a}', {'a': frage.richtigeAntwort}),
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
            child: Text(t('Bestätigen'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
        Text(
          t('↑ Größtes oben  |  Kleinstes unten ↓'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: reihenfolge.length * 64.0,
          child: ReorderableListView.builder(
            shrinkWrap: true,
            // Ganze Kachel soll als Griff dienen (nicht nur ein schmaler
            // Handle am rechten Rand) -> Standard-Handles aus, stattdessen
            // den kompletten Container unten in ReorderableDragStartListener
            // einwickeln.
            buildDefaultDragHandles: false,
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
              return ReorderableDragStartListener(
                key: ValueKey(iso2),
                index: i,
                child: Container(
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
            child: Text(t('Reihenfolge prüfen'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
              ? t('Richtig (nach {kategorie}, größte zuerst):', {'kategorie': kategorieLabel})
              : t('Richtige Reihenfolge:'),
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
              ? t('✅ Perfekte Reihenfolge!')
              : t('{a} von {b} richtig sortiert', {
                  'a': '$anzahlRichtig',
                  'b': '${richtigeReihenfolge.length}',
                }),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: anzahlRichtig == richtigeReihenfolge.length
                ? const Color(0xFF4A9E4A)
                : const Color(0xFFD94040),
          ),
        ),
        const SizedBox(height: 16),
        _WeiterButton(onTap: onWeiter),
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
            Text(t('(Platz {n})', {'n': '$nutzerPlatz'}),
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

String _formatGrosswert(double v, String einheitDe) {
  final einheit = t(einheitDe);
  if (einheitDe == 'Jahre') return '${v.toStringAsFixed(1)} $einheit';
  final n = v.round();
  final abs = n.abs();
  final en = LocaleService.istEnglisch;
  if (abs >= 1000000000) {
    return en
        ? '${(n / 1000000000).toStringAsFixed(1)}B $einheit'
        : '${(n / 1000000000).toStringAsFixed(1)} Mrd. $einheit';
  }
  if (abs >= 1000000) {
    return en
        ? '${(n / 1000000).toStringAsFixed(1)}M $einheit'
        : '${(n / 1000000).toStringAsFixed(1)} Mio. $einheit';
  }
  if (abs >= 1000) {
    return en
        ? '${(n / 1000).toStringAsFixed(1)}K $einheit'
        : '${(n / 1000).toStringAsFixed(1)} Tsd. $einheit';
  }
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
            child: Text(t('Schätzung bestätigen'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
        Text(t('Deine Schätzung: {v}', {'v': fmt(sliderWert)}),
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
                feedbackRichtig ? t('✅ Richtig! (±20%)') : t('❌ Daneben'),
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
                t('Tatsächlicher Wert: {v}', {'v': fmt(zielwert)}),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1a1a1a)),
              ),
              if (abweichungProzent != null) ...[
                const SizedBox(height: 4),
                Text(
                  t('Du lagst {p}% zu {richtung}', {
                    'p': abweichungProzent.abs().toStringAsFixed(0),
                    'richtung': abweichungProzent > 0 ? t('hoch') : t('niedrig'),
                  }),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _WeiterButton(onTap: onWeiter),
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
        Text(
          t('Welchem Land gehört dieser Umriss?'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🗺️', style: TextStyle(fontSize: 52)),
                        const SizedBox(height: 8),
                        Text(t('Kein Umriss verfügbar'),
                            style: const TextStyle(
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
              showFeedback: showFeedback,
              istRichtig: opt == frage.richtigeAntwort,
              istGewaehlt: opt == gewaehlt,
              feedbackRichtig: feedbackRichtig,
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
          t('Welcher Umriss gehört zu {emoji} {name}?', {
            'emoji': co?.flagEmoji ?? '',
            'name': co?.name ?? frage.richtigeAntwort,
          }),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        zweiSpaltenGrid(
          childAspectRatio: 1.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          frage.antwortOptionen.map((iso2) {
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
            return _WackelTile(
              falschGewaehlt:
                  showFeedback && iso2 == gewaehlt && !feedbackRichtig,
              child: GestureDetector(
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

  // Mindest-Durchmesser (px) für winzige Insel-Ringe (z.B. einzelne Malediven-
  // oder Kiribati-Atolle), die nach der Skalierung sonst unter 1px fallen und
  // unsichtbar würden — solche Ringe zeichnen wir als kleinen Punkt statt als
  // (nicht mehr erkennbaren) Pfad.
  static const _minInselDurchmesser = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (rings.isEmpty) return;
    // Padding proportional zur Canvas-Größe: bei den kleinen Grid-Kacheln des
    // Multiple-Choice-Modus (~130x110px) frisst ein fixes 20px-Padding einen
    // zu großen Anteil der Fläche; bei den großen Karten bleibt es bei ~20px.
    final pad = (size.shortestSide * 0.09).clamp(8.0, 20.0);
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
    // Kleine Renderflächen (Grid-Kacheln) bekommen einen dünneren Rand, damit
    // er bei winzigen Ländern/Zwergstaaten nicht die Füllfläche überdeckt.
    final strichstaerke = size.shortestSide < 130 ? 1.0 : 1.5;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = color.withAlpha(178)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strichstaerke
      ..isAntiAlias = true;
    for (final r in proj) {
      if (r.length < 3) continue;
      double rMinX = r[0].dx, rMaxX = r[0].dx, rMinY = r[0].dy, rMaxY = r[0].dy;
      for (final p in r) {
        if (p.dx < rMinX) rMinX = p.dx;
        if (p.dx > rMaxX) rMaxX = p.dx;
        if (p.dy < rMinY) rMinY = p.dy;
        if (p.dy > rMaxY) rMaxY = p.dy;
      }
      final renderedW = (rMaxX - rMinX) * sc;
      final renderedH = (rMaxY - rMinY) * sc;
      if (max(renderedW, renderedH) < _minInselDurchmesser) {
        final cx = (rMinX + rMaxX) / 2 * sc + dX;
        final cy = (rMinY + rMaxY) / 2 * sc + dY;
        canvas.drawCircle(
            Offset(cx, cy), _minInselDurchmesser / 2, fill..isAntiAlias = true);
        continue;
      }
      final path = Path()..moveTo(r[0].dx * sc + dX, r[0].dy * sc + dY);
      for (final p in r.skip(1)) {
        path.lineTo(p.dx * sc + dX, p.dy * sc + dY);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_UmrissPainter o) => o.rings != rings || o.color != color;
}
