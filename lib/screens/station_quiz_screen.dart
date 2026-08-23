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
import '../services/benachrichtigungs_service.dart';
import '../services/einstellungen_service.dart';
import '../services/fortschritt_service.dart';
import '../services/gelernte_fakten_service.dart';
import '../services/onboarding_service.dart';
import '../services/skala_service.dart';
import '../services/sound_service.dart';
import '../services/station_session_service.dart';
import '../widgets/abzeichen_popup.dart';
import '../widgets/erinnerung_dialog.dart';
import '../widgets/flaggen_widget.dart';
import '../widgets/halbzeit_inhalt.dart';
import '../widgets/level_skip_button.dart';
import '../widgets/spiel_erklaerung.dart';
import '../widgets/streak_feier_overlay.dart';
import 'station_abschluss_screen.dart';
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
  // Startzeitpunkt der Station für die Dauer in der Schluss-Ansicht.
  DateTime? _stationStart;
  // Gelernte Länder beim Stationsstart — die Schluss-Ansicht bildet daraus
  // die Differenz und weiß so, welche Länder in DIESER Station dazukamen.
  Set<String> _gelerntVorher = const {};
  // Der Halbzeit-Moment erscheint höchstens einmal pro Station.
  bool _halbzeitGezeigt = false;
  // Solange gesetzt, zeigt der Inhaltsbereich den Halbzeit-Moment statt einer
  // Frage; der Completer hält _vorruecken so lange an.
  bool _zeigeHalbzeit = false;
  bool _halbzeitButtonSichtbar = false;
  Completer<void>? _halbzeitFertig;
  // Key des gerade angezeigten Inhalts — unterscheidet im Wisch-Übergang das
  // eingehende vom abgehenden Kind (siehe _inhaltMitWisch).
  Key? _aktuellerInhaltKey;

  // Länder-Ranking: Stand des Zahlenschlosses für die aktuelle Frage.
  bool _rankingBestaetigt = false;
  int _rankingEingabe = 0;

  // Nachbarschafts-Kette: der fertig gebaute Weg der aktuellen Frage.
  bool _ketteFertig = false;
  List<String> _ketteWeg = const [];

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
        m == LernModus.umrissEingabe ||
        // Der Flächen-Vergleich zeichnet zwei Silhouetten und braucht die
        // Geometrie damit genauso — nur stehen seine beiden Länder nicht in
        // den Antwortoptionen (das sind Zahlen), sondern in laenderCode und
        // meta['kleinesLand'].
        m == LernModus.flaechenVergleich;
    final brauchtGeo = session.aktiveFragen.any((f) => istUmrissModus(f.modus));
    if (brauchtGeo) {
      try {
        final rings = await _ladeGeoRings();
        // Hochauflösende Einzeldateien für Quiz-Länder nachladen
        final quizIsos = session.aktiveFragen
            .where((f) => istUmrissModus(f.modus))
            .expand((f) => [
                  f.laenderCode,
                  ...f.antwortOptionen,
                  if (f.meta['kleinesLand'] is String)
                    f.meta['kleinesLand'] as String,
                ])
            .where((s) => s.isNotEmpty && s.length == 2)
            .toSet();
        await _upgradeRingsMitEinzelDateien(rings, quizIsos);
        if (mounted) setState(() => _geoRings = rings);
      } catch (e) {
        debugPrint('GeoJSON konnte nicht geladen werden: $e');
      }
    }

    if (!mounted) return;
    // Ab hier läuft die Station für den Spieler — Startpunkt für die in der
    // Schluss-Ansicht gezeigte Dauer. Bewusst erst nach dem Laden, damit
    // Lade- und GeoJSON-Zeit nicht mitzählen.
    _stationStart = DateTime.now();
    // Stand VOR der Station festhalten: die Schluss-Ansicht bildet daraus
    // die Differenz und weiß, welche Länder neu dazugekommen sind.
    GelernteFaktenService.gelernteLaender().then((menge) {
      if (mounted) _gelerntVorher = menge;
    });
    setState(() {
      _session = session;
      _loading = false;
    });
    _initFrageState(session.aktuelleFrage);
    // Die Anleitung MUSS vor dem Countdown kommen: sonst läuft in einem
    // Meister-Abschnitt die Uhr, während der Spieler noch liest.
    await _zeigeAnleitungFallsErstesMal(session.aktuelleFrage?.modus);
    if (!mounted) return;
    if (session.hatTimer) _startCountdown();
  }

  /// Öffnet beim ERSTEN Vorkommen eines Modus mit eigener Bedienung dessen
  /// Anleitung — einmal je Modus, danach nie wieder von selbst.
  ///
  /// Der Merker wird gesetzt, BEVOR das Sheet erscheint: wer die App
  /// mittendrin schliesst, soll die Anleitung nicht beim nächsten Start
  /// erneut vorgesetzt bekommen. Sie bleibt ja über den Knopf in der
  /// Spielfläche jederzeit erreichbar.
  ///
  /// Läuft absichtlich über den Modus der ersten FRAGE und nicht über
  /// station.modus: bei zu dünner Datenlage weicht der Generator auf einen
  /// anderen Modus aus (siehe ermittleTatsaechlichenModus), und dann wäre die
  /// Anleitung die zum falschen Spiel.
  Future<void> _zeigeAnleitungFallsErstesMal(LernModus? modus) async {
    if (modus == null || !kModiMitAnleitung.contains(modus)) return;
    if (await OnboardingService.modusErklaerungGezeigt(modus)) return;
    await OnboardingService.merkeModusErklaerung(modus);
    if (!mounted) return;

    // Auf den ersten Frame warten: das Sheet braucht einen aufgebauten Baum,
    // und setState() oben ist zu diesem Zeitpunkt noch nicht gezeichnet.
    final fertig = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        fertig.complete();
        return;
      }
      await zeigeModusAnleitung(context, modus);
      fertig.complete();
    });
    await fertig.future;
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
    } else if (frage.modus == LernModus.laenderRanking) {
      setState(() {
        _rankingBestaetigt = false;
        _rankingEingabe = 0;
      });
    } else if (frage.modus == LernModus.nachbarschaftsKette) {
      setState(() {
        _ketteFertig = false;
        _ketteWeg = const [];
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
  /// Haptik UND Klang zur Antwort.
  ///
  /// Beides an EINER Stelle, weil beides denselben Auslöser hat: die sieben
  /// Auswertungswege der Modi (Antippen, Eingabe, Sortieren, Schätzen,
  /// Ranking, Kette, Zeitablauf) rufen alle hierher. Zwei getrennte Methoden
  /// wären sieben Gelegenheiten, eine davon zu vergessen.
  ///
  /// Hiess vorher _vibriereAntwort — der Name stimmt nicht mehr, seit auch
  /// ein Ton dranhängt.
  void _antwortRueckmeldung(bool richtig) {
    SoundService.spiele(richtig ? Klang.richtig : Klang.falsch);
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
    _antwortRueckmeldung(false);
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
    _antwortRueckmeldung(richtig);
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
    _antwortRueckmeldung(richtig);
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
    _antwortRueckmeldung(richtig);
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
      _faktErfassen();
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
    _antwortRueckmeldung(richtig);
    setState(() {
      _preisBestaetigt = true;
      _showFeedback = true;
      _feedbackRichtig = richtig;
    });
    // Kein Auto-Timer: der tatsächliche Wert + Abweichung braucht Zeit zum
    // Lesen — der Nutzer bestätigt manuell mit "Weiter" (siehe _preisWeiter).
  }

  // ── Nachbarschafts-Kette ──────────────────────────────────────────────────

  /// Wird aufgerufen, sobald der Spieler das Zielland erreicht hat.
  ///
  /// Die Prüfung ist strukturell und passiert im Widget selbst: dort sind nur
  /// echte Nachbarn des aktuellen Landes antippbar, ein ungültiger Schritt
  /// kann also gar nicht entstehen. Hier bleibt zu bewerten, wie LANG der
  /// Weg geworden ist — gemessen am kürzesten aus der Breitensuche.
  void _ketteZielErreicht(List<String> weg) {
    if (_ketteFertig || _session == null) return;
    final frage = _session!.aktuelleFrage;
    if (frage == null) return;
    _stopCountdown();
    final optimum = (frage.meta['optimum'] as num?)?.toInt() ?? 0;
    final schritte = weg.length - 1;
    final richtig = schritte - optimum <= kKetteToleranz;
    _antwortRueckmeldung(richtig);
    setState(() {
      _ketteWeg = weg;
      _ketteFertig = true;
      _showFeedback = true;
      _feedbackRichtig = richtig;
    });
  }

  void _ketteWeiter() {
    if (_session == null) return;
    if (_feedbackRichtig) {
      _faktErfassen();
      _session!.richtigeAntwortVerarbeiten();
    } else {
      _session!.falscheAntwortVerarbeiten();
    }
    setState(() {
      _ketteFertig = false;
      _ketteWeg = const [];
      _showFeedback = false;
    });
    _vorruecken();
  }

  // ── Länder-Ranking (Zahlenschloss) ────────────────────────────────────────

  void _rankingBestaetigen(int eingabe) {
    if (_rankingBestaetigt || _session == null) return;
    final frage = _session!.aktuelleFrage;
    if (frage == null) return;
    _stopCountdown();
    final rang = int.tryParse(frage.richtigeAntwort) ?? 0;
    // Kein exakter Treffer verlangt: der genaue Rangplatz ist nicht erratbar.
    // Als richtig zählt, wer im Band der guten Punktzahl landet — dieselbe
    // Logik wie die 20-Prozent-Toleranz beim Preis-Schätzen.
    final richtig = (eingabe - rang).abs() <= kRankingToleranz;
    _antwortRueckmeldung(richtig);
    setState(() {
      _rankingEingabe = eingabe;
      _rankingBestaetigt = true;
      _showFeedback = true;
      _feedbackRichtig = richtig;
    });
    // Kein Auto-Timer: der echte Rang, die Abweichung und der Wert brauchen
    // Zeit zum Lesen — weiter geht es per Tipp (siehe _rankingWeiter).
  }

  void _rankingWeiter() {
    if (_session == null) return;
    if (_feedbackRichtig) {
      _faktErfassen();
      _session!.richtigeAntwortVerarbeiten();
    } else {
      _session!.falscheAntwortVerarbeiten();
    }
    setState(() {
      _rankingBestaetigt = false;
      _showFeedback = false;
    });
    _vorruecken();
  }

  void _preisWeiter() {
    if (_session == null) return;
    if (_feedbackRichtig) {
      _faktErfassen();
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
    // Der Weiter-Knopf ist der einzige Knopf, den der Spieler in einer
    // Station immer wieder drückt — deshalb sitzt der Knopfton hier und
    // nicht in den einzelnen Modus-Oberflächen.
    SoundService.spiele(Klang.knopf);
    if (_feedbackRichtig) {
      _faktErfassen();
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
      m == LernModus.sortierSpiel ||
      m == LernModus.preisSchaetzen ||
      // Das Zahlenschloss trägt seinen Bestätigen- bzw. Weiter-Button selbst,
      // damit er direkt unter den Walzen sitzt statt am Bildschirmfuß.
      m == LernModus.laenderRanking ||
      // Die Nachbarschafts-Kette hat bis zum Erreichen des Ziels gar keinen
      // Weiter-Button — sie endet, wenn der Weg steht.
      m == LernModus.nachbarschaftsKette;

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

  /// Verbucht die gerade richtig beantwortete Frage dauerhaft.
  ///
  /// Muss VOR richtigeAntwortVerarbeiten() laufen — danach zeigt
  /// aktuelleFrage bereits auf die nächste Frage. Bewusst nicht awaited: das
  /// Schreiben in die Prefs darf den Übergang zur nächsten Frage nicht
  /// verzögern, und ein Fehler dabei soll das Quiz nicht anhalten.
  void _faktErfassen() {
    final frage = _session?.aktuelleFrage;
    if (frage == null) return;
    unawaited(GelernteFaktenService.frageRichtig(frage));
  }

  Future<void> _vorruecken() async {
    if (!mounted) return;
    if (_session!.istFertig) {
      _stationFertig();
    } else {
      setState(() {
        _showFeedback = false;
        _gewahlteAntwort = null;
      });
      _session!.speichernFortschritt();
      // Halbzeit-Moment VOR dem Neustart des Countdowns: der Timer wurde beim
      // Antworten gestoppt und läuft erst nach dem Wegtippen wieder an,
      // niemand verliert also Zeit durch das Overlay.
      await _halbzeitPruefen();
      if (!mounted) return;
      if (_session!.hatTimer) _startCountdown();
      _initFrageState(_session!.aktuelleFrage);
    }
  }

  /// Zeigt nach der halben Fragenzahl einmalig den Motivations-Moment.
  ///
  /// Kein eigener Screen und kein Overlay: nur der Inhaltsbereich wird
  /// getauscht, AppBar samt Fortschrittsbalken und Skip-Button sowie der
  /// Weiter-Button bleiben stehen. Der Completer hält den Ablauf an, bis der
  /// Spieler "Weiter" tippt — von außen verhält sich die Methode damit wie
  /// ein blockierender Dialog.
  ///
  /// Nicht in Wiederholungsrunden: dort ist die Fragenzahl variabel (nur die
  /// zuvor falsch beantworteten Fragen), eine "Halbzeit" wäre dort ohne
  /// Aussage. Tages-Challenges laufen über eigene Screens und erreichen
  /// diesen Code ohnehin nie.
  Future<void> _halbzeitPruefen() async {
    if (_halbzeitGezeigt || widget.istWiederholungsrunde) return;
    final session = _session!;
    final gesamt = session.aktiveFragen.length;
    // Bei sehr kurzen Stationen ergibt ein Halbzeit-Moment keinen Sinn.
    if (gesamt < 4) return;
    if (session.aktuellerIndex != gesamt ~/ 2) return;

    _halbzeitGezeigt = true;
    _halbzeitFertig = Completer<void>();
    setState(() {
      _zeigeHalbzeit = true;
      _halbzeitButtonSichtbar = false;
    });
    // Der Weiter-Button erscheint erst, wenn Bild und Spruch stehen.
    Future.delayed(const Duration(milliseconds: kHalbzeitButtonAb), () {
      if (mounted && _zeigeHalbzeit) {
        setState(() => _halbzeitButtonSichtbar = true);
      }
    });
    await _halbzeitFertig!.future;
  }

  void _halbzeitWeiter() {
    if (!_zeigeHalbzeit) return;
    setState(() {
      _zeigeHalbzeit = false;
      _halbzeitButtonSichtbar = false;
    });
    _halbzeitFertig?.complete();
    _halbzeitFertig = null;
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

    // Hält die Uhrzeit für die "übliche Spielzeit" fest und plant die
    // Erinnerungen neu — dadurch entfällt die heutige Erinnerung von selbst.
    // MUSS nach dem Streak-Update laufen: die Streak-Warnung liest den Stand,
    // den dieses gerade geschrieben hat.
    //
    // Bewusst VOR dem Wiederholungsrunde-Zweig: auch eine Wiederholungsrunde
    // ist Spielzeit und soll die Erinnerung für heute verfallen lassen.
    // Bewusst nicht hinter `if (!mounted)`: die Buchführung hängt nicht daran,
    // ob der Bildschirm noch steht.
    await BenachrichtigungsService.stationAbgeschlossen();

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
    final vergebeneSterne = await FortschrittService.stationAbschliessen(
      widget.station!.id,
      _session!.richtigeAntworten,
      _session!.falscheAntworten,
      falscheFragenJson: _session!.falscheFragenAlsJson(),
    );
    // ignore: avoid_print
    print('[StationFertig] stationAbschliessen() fertig, '
        'vergebeneSterne=$vergebeneSterne');

    // Schluss-Ansicht: Ergebnis, Kennzahlen und Kontinent-Fortschritt. Läuft
    // VOR Abzeichen-Popup und Interstitial, damit der Spieler zuerst sein
    // Ergebnis sieht; blockiert bis "Weiter" getippt wurde.
    final kontext = stationKontext(widget.station!.id);
    if (mounted && kontext != null) {
      await StationAbschlussScreen.zeigen(
        context,
        welt: kontext.$1,
        richtig: _session!.richtigeAntworten,
        gesamtFragen:
            _session!.richtigeAntworten + _session!.falscheAntworten,
        sterne: vergebeneSterne,
        dauer: _stationStart == null
            ? Duration.zero
            : DateTime.now().difference(_stationStart!),
        gelerntVorher: _gelerntVorher,
      );
    }
    if (!mounted) return;

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

    // Erlaubnis für Erinnerungen erfragen — nach der ersten abgeschlossenen
    // Station, nicht beim ersten Start. Der Platz ist bewusst gewählt: nach
    // Ergebnis und Abzeichen (der Spieler hat gerade etwas geschafft) und noch
    // VOR dem Interstitial, denn eine Vollbild-Werbung würde den Dialog
    // verdecken.
    if (await BenachrichtigungsService.sollDialogZeigen()) {
      if (!mounted) return;
      await ErinnerungDialog.zeigen(context);
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
          // Der Anleitungs-Knopf stand hier und ist unter die Kopfzeile
          // gewandert, in die helle Spielfläche (siehe unten im body).
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

                // Anleitungs-Knopf: rechtsbündig ganz oben in der hellen
                // Fläche, unter dem Skip-Knopf der Kopfzeile.
                //
                // Er steht BEWUSST im Layout und nicht als Overlay über der
                // Frage: so kann er mit keinem Modus überlappen, egal wie
                // dessen Spielfläche aussieht. Und er steht ausserhalb des
                // Scrollbereichs darunter, damit er beim Scrollen nicht
                // weglaüft und in jedem Modus an derselben Stelle sitzt.
                //
                // Einzige Ausnahme: hat die Station einen Timer, schiebt
                // dessen Balken ihn um seine Höhe nach unten — der Balken
                // trägt rechts seinen eigenen Sekundenzähler, unter den der
                // Knopf gehört, nicht daneben.
                //
                // Nur für Modi mit hinterlegter Anleitung — sonst öffnete der
                // Knopf nichts (zeigeModusAnleitung steigt bei leerer
                // Anleitung aus).
                if (kModiMitAnleitung.contains(frage.modus))
                  Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _FragezeichenKnopf(
                        onTap: () => zeigeModusAnleitung(context, frage.modus),
                      ),
                    ),
                  ),
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
                                _inhaltMitWisch(session, frage),
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
                // Im Halbzeit-Moment gehört der Button diesem Moment (und
                // erscheint zeitversetzt), sonst dem Feedback zur Frage. In
                // beiden Fällen dieselbe Position und dasselbe Widget — für
                // den Spieler bleibt der Button einfach stehen.
                if (_zeigeHalbzeit || !_hatEigenenWeiterButton(frage.modus))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Builder(builder: (context) {
                      final sichtbar = _zeigeHalbzeit
                          ? _halbzeitButtonSichtbar
                          : _showFeedback;
                      return AnimatedOpacity(
                        opacity: sichtbar ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: !sichtbar,
                          child: _WeiterButton(
                            onTap: _zeigeHalbzeit
                                ? _halbzeitWeiter
                                : _weiterTippen,
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            ),
    );
  }

  /// Inhaltsbereich mit horizontalem Wisch-Übergang.
  ///
  /// Zentral hier statt in jedem Modus einzeln: alle Modi laufen durch
  /// _frageWidget und bekommen den Übergang dadurch automatisch. Auch der
  /// Halbzeit-Moment ist eingeschlossen, damit sich der Wechsel dorthin und
  /// zurück genauso anfühlt wie zwischen zwei Fragen.
  ///
  /// Der Key ist entscheidend: nur wenn er sich ändert, erkennt der
  /// AnimatedSwitcher überhaupt einen Wechsel. Er enthält deshalb den
  /// Fragen-Index UND den Halbzeit-Zustand.
  Widget _inhaltMitWisch(StationSession session, Frage? frage) {
    final Widget inhalt;
    final Key key;
    if (_zeigeHalbzeit) {
      // Derselbe Key-Raum wie die Fragen, nur mit einem Zusatz: dadurch ist
      // es für den AnimatedSwitcher technisch ein ganz normaler Wechsel und
      // wischt zwangsläufig in dieselbe Richtung — vorheriger Inhalt nach
      // links raus, neuer von rechts herein, auch beim Verlassen.
      key = ValueKey('frage_${session.aktuellerIndex}_halbzeit');
      inhalt = HalbzeitInhalt(
        richtigBisher: session.richtigeAntworten,
        beantwortet: session.aktuellerIndex,
      );
    } else {
      key = ValueKey('frage_${session.aktuellerIndex}');
      inhalt = _frageMitAnleitung(frage!);
    }
    _aktuellerInhaltKey = key;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        // Der Switcher fährt die Animation für das ALTE Kind RÜCKWÄRTS. Mit
        // nur einer Richtung würde die alte Frage deshalb dorthin
        // zurückgleiten, wo die neue herkommt (beide rechts) — es sähe aus,
        // als würde zurückgeblättert.
        //
        // Deshalb bekommt jedes Kind seine eigene Richtung: das eingehende
        // startet rechts und läuft zur Mitte, das abgehende läuft von der
        // Mitte nach links. Erkennbar am Key — nur das aktuelle Kind trägt
        // _aktuellerInhaltKey.
        final istEingehend = child.key == _aktuellerInhaltKey;
        return SlideTransition(
          position: Tween<Offset>(
            begin: istEingehend ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        // Standard-Layout stapelt zentriert; die abgehende Frage darf dabei
        // die Größe des Bereichs nicht mehr bestimmen, sonst springt die
        // Höhe bei unterschiedlich hohen Modi.
        return Stack(
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      child: KeyedSubtree(key: key, child: inhalt),
    );
  }

  /// Die Spielfläche eines Modus, darüber die modus-eigenen Knöpfe.
  ///
  /// Der Anleitungs-Knopf stand früher hier, beschriftet. Er ist als rundes
  /// Fragezeichen in die Kopfzeile gewandert (siehe [_FragezeichenKnopf]) —
  /// die Anleitung ist überall dieselbe Geste, und über der Spielfläche
  /// nahm sie in jeder Frage eine Zeile weg.
  ///
  /// Übrig bleibt hier, was WIRKLICH zur einzelnen Frage gehört: bei "Was
  /// gehört nicht dazu?" die Liste der möglichen Gemeinsamkeiten. Sie ist
  /// keine Anleitung, sondern Teil der Aufgabe, und bleibt deshalb bewusst
  /// an ihrem Platz.
  Widget _frageMitAnleitung(Frage f) {
    if (f.modus != LernModus.wasGehoertNichtDazu) return _frageWidget(f);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _SpielflaechenKnopf(
            icon: Icons.list_alt_rounded,
            beschriftung: t('Kategorien'),
            onTap: () => zeigeQuartettHilfe(context),
          ),
        ),
        const SizedBox(height: 10),
        _frageWidget(f),
      ],
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
      LernModus.zweiWahrheiten => _ZweiWahrheitenUI(
          frage: f,
          gewaehlt: _gewahlteAntwort,
          showFeedback: _showFeedback,
          feedbackRichtig: _feedbackRichtig,
          onAntwort: _antwortGewaehlt,
        ),
      LernModus.wasGehoertNichtDazu => _WasGehoertNichtDazuUI(
          frage: f,
          gewaehlt: _gewahlteAntwort,
          showFeedback: _showFeedback,
          feedbackRichtig: _feedbackRichtig,
          onAntwort: _antwortGewaehlt,
        ),
      LernModus.nachbarschaftsKette => _NachbarschaftsKetteUI(
          frage: f,
          bestaetigt: _ketteFertig,
          feedbackRichtig: _feedbackRichtig,
          weg: _ketteWeg,
          onZielErreicht: _ketteZielErreicht,
          onWeiter: _ketteWeiter,
        ),
      LernModus.laenderRanking => _LaenderRankingUI(
          frage: f,
          bestaetigt: _rankingBestaetigt,
          feedbackRichtig: _feedbackRichtig,
          eingabe: _rankingEingabe,
          onBestaetigen: _rankingBestaetigen,
          onWeiter: _rankingWeiter,
        ),
      LernModus.flaechenVergleich => _FlaechenVergleichUI(
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
              // hint als Widget statt hintText: bei grosser Systemschrift
              // (ab 1.3) passte "Hauptstadt eingeben…" nicht mehr in das Feld
              // und wurde abgeschnitten. Die FittedBox verkleinert den
              // Platzhalter dann so weit, dass er ganz dasteht — bei normaler
              // Schriftgroesse aendert sie nichts, denn scaleDown vergroessert
              // nie.
              hint: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _hintText,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
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

// ══════════════════════════════════════════════════════════════════════════════
// Flächen-Vergleich — zwei Umrisse im gemeinsamen Maßstab
// ══════════════════════════════════════════════════════════════════════════════
//
// Leitgröße der Komposition ist die Kantenlänge der Vergleichsfläche; alle
// übrigen Maße dieses Blocks sind Anteile davon. Wird die Fläche später
// größer, wandern Innenabstand und Randstärke im Verhältnis mit.

/// Leitgröße: Anteil der Bildschirmhöhe, den die Vergleichsfläche einnimmt.
const _kVergleichHoeheAnteil = 0.30;
const _kVergleichMin = 180.0;
const _kVergleichMax = 300.0;

/// Innenabstand der Zeichenfläche — verhindert, dass der Umriss die Kante
/// berührt.
const _kVergleichPadAnteil = 0.06;

/// Randstärke der beiden Silhouetten.
const _kVergleichRandAnteil = 0.009;

/// Waagerechter Abstand zwischen den Umrissen, als Anteil ihrer
/// zusammengenommenen Breite.
const _kVergleichLuecke = 0.10;

/// Schriftgröße der Ländernamen, als Anteil der kürzeren Kante.
const _kVergleichNameAnteil = 0.055;

/// Das größere Land im helleren Grün, das kleinere im vollen Akzentgrün: so
/// bleibt der kleine Umriss trotz seiner Fläche gut sichtbar.
const _cVergleichGross = Color(0xFF9ACD9A);
const _cVergleichKlein = Color(0xFF4A9E4A);
const _cVergleichRand = Color(0xFF1A1A1A);

/// Lambert-azimutale FLÄCHENTREUE Projektion, zentriert auf den Schwerpunkt
/// der übergebenen Ringe.
///
/// Bewusst nicht die Mercator-Projektion aus [_UmrissPainter]: Mercator
/// streckt Flächen mit dem Quadrat des Breitengrad-Kosinus — Grönland
/// erschiene dort etwa so groß wie Afrika, obwohl es vierzehnmal kleiner ist.
/// Für einen Modus, dessen ganze Aussage im Größenverhältnis liegt, ist das
/// die eine Sache, die nicht schiefgehen darf.
///
/// Die azimutale Variante hält zusätzlich die Form nahe am gewohnten
/// Kartenbild. Eine zylindrische flächentreue Projektion wäre ebenso
/// flächentreu, würde die Länder aber je nach Breitengrad unterschiedlich
/// stark platt drücken — zwei Länder nebeneinander sähen dann verschieden
/// verzerrt aus.
List<List<Offset>> _laeaProjektion(List<List<Offset>> ringe) {
  if (ringe.isEmpty) return const [];
  double sx = 0, sy = 0;
  var n = 0;
  for (final r in ringe) {
    for (final p in r) {
      sx += p.dx;
      sy += p.dy;
      n++;
    }
  }
  if (n == 0) return const [];
  final lam0 = sx / n * pi / 180;
  final phi0 = sy / n * pi / 180;
  final sinPhi0 = sin(phi0), cosPhi0 = cos(phi0);

  return ringe
      .map((r) => r.map((p) {
            final lam = p.dx * pi / 180, phi = p.dy * pi / 180;
            final dLam = lam - lam0;
            final cosC =
                sinPhi0 * sin(phi) + cosPhi0 * cos(phi) * cos(dLam);
            // Am Gegenpol ist die Projektion nicht definiert. Bei einem
            // einzelnen Land, das um seinen eigenen Schwerpunkt projiziert
            // wird, kann das nicht eintreten — der Schutz kostet nichts.
            final k = sqrt(2 / max(1 + cosC, 1e-9));
            return Offset(
              k * cos(phi) * sin(dLam),
              // Norden zeigt in Bildschirmkoordinaten nach unten.
              -k * (cosPhi0 * sin(phi) - sinPhi0 * cos(phi) * cos(dLam)),
            );
          }).toList())
      .toList();
}

Rect? _ringeBbox(List<List<Offset>> ringe) {
  double minX = double.infinity, maxX = double.negativeInfinity;
  double minY = double.infinity, maxY = double.negativeInfinity;
  for (final r in ringe) {
    for (final p in r) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
  }
  if (minX > maxX || minY > maxY) return null;
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

class _VergleichsPainter extends CustomPainter {
  final List<List<Offset>> grossRinge;
  final List<List<Offset>> kleinRinge;
  final String grossName;
  final String kleinName;

  const _VergleichsPainter({
    required this.grossRinge,
    required this.kleinRinge,
    required this.grossName,
    required this.kleinName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gross = _laeaProjektion(grossRinge);
    final klein = _laeaProjektion(kleinRinge);
    final bbGross = _ringeBbox(gross), bbKlein = _ringeBbox(klein);
    if (bbGross == null || bbKlein == null) return;
    if (bbGross.width <= 0 || bbGross.height <= 0) return;
    if (bbKlein.width <= 0 || bbKlein.height <= 0) return;

    final pad = size.shortestSide * _kVergleichPadAnteil;
    // Streifen am unteren Rand für die beiden Ländernamen.
    final schrift = size.shortestSide * _kVergleichNameAnteil;
    final namenHoehe = schrift * 1.5;
    final avW = size.width - 2 * pad;
    final avH = size.height - 2 * pad - namenHoehe;
    if (avW <= 0 || avH <= 0) return;

    // Abstand zwischen den beiden Umrissen, in Projektionseinheiten, damit er
    // beim Skalieren im Verhältnis bleibt.
    final lueckeProj = (bbGross.width + bbKlein.width) * _kVergleichLuecke;
    final gesamtBreite = bbGross.width + bbKlein.width + lueckeProj;
    final maxHoehe = max(bbGross.height, bbKlein.height);

    // DER GEMEINSAME MASSSTAB — der Kern dieses Modus. Beide Umrisse werden
    // mit exakt demselben Faktor gezeichnet; ein eigener Maßstab je Land
    // würde die Aussage der Darstellung zerstören. Der Faktor ist so groß,
    // dass das PAAR den Bereich ausfüllt — nebeneinander kann das größere
    // Land ihn nicht allein ausfüllen, ohne das kleinere hinauszudrängen.
    final skala = min(avW / gesamtBreite, avH / maxHoehe);

    // Gemeinsame Grundlinie: beide Umrisse stehen unten auf derselben Kante,
    // dadurch ist der Größenunterschied direkt ablesbar.
    final grundlinie = pad + avH;
    final linkerRand = pad + (avW - gesamtBreite * skala) / 2;
    final randStaerke = size.shortestSide * _kVergleichRandAnteil;

    // Links das größere, rechts das kleinere — absteigend gelesen wirkt der
    // Unterschied unmittelbarer als andersherum.
    final grossX = linkerRand;
    final kleinX = linkerRand + (bbGross.width + lueckeProj) * skala;

    _zeichne(canvas, gross, bbGross, skala, grossX, grundlinie,
        fuellung: _cVergleichGross, randStaerke: randStaerke);
    _zeichne(canvas, klein, bbKlein, skala, kleinX, grundlinie,
        fuellung: _cVergleichKlein, randStaerke: randStaerke);

    _name(canvas, grossName, grossX + bbGross.width * skala / 2,
        grundlinie + schrift * 0.35, schrift, size.width);
    _name(canvas, kleinName, kleinX + bbKlein.width * skala / 2,
        grundlinie + schrift * 0.35, schrift, size.width);
  }

  /// Zeichnet [ringe] so, dass die linke Kante auf [x] und die untere Kante
  /// auf [grundlinie] liegt.
  void _zeichne(
    Canvas canvas,
    List<List<Offset>> ringe,
    Rect bbox,
    double skala,
    double x,
    double grundlinie, {
    required Color fuellung,
    required double randStaerke,
  }) {
    final pfad = Path();
    for (final r in ringe) {
      if (r.length < 3) continue;
      for (var i = 0; i < r.length; i++) {
        final p = Offset(
          (r[i].dx - bbox.left) * skala + x,
          (r[i].dy - bbox.bottom) * skala + grundlinie,
        );
        if (i == 0) {
          pfad.moveTo(p.dx, p.dy);
        } else {
          pfad.lineTo(p.dx, p.dy);
        }
      }
      pfad.close();
    }
    canvas.drawPath(
        pfad,
        Paint()
          ..color = fuellung
          ..style = PaintingStyle.fill
          ..isAntiAlias = true);
    canvas.drawPath(
        pfad,
        Paint()
          ..color = _cVergleichRand
          ..style = PaintingStyle.stroke
          ..strokeWidth = randStaerke
          ..isAntiAlias = true);
  }

  /// Ländername mittig unter dem jeweiligen Umriss.
  ///
  /// Im Painter statt als Flutter-Text, weil nur hier bekannt ist, wo die
  /// beiden Umrisse nach der gemeinsamen Skalierung tatsächlich sitzen — eine
  /// Row darunter könnte sich nur raten.
  void _name(Canvas canvas, String text, double mitteX, double oben,
      double schrift, double maxBreite) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: schrift,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1A1A),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxBreite / 2);
    tp.paint(canvas, Offset(mitteX - tp.width / 2, oben));
  }

  @override
  bool shouldRepaint(covariant _VergleichsPainter old) =>
      old.grossRinge != grossRinge ||
      old.kleinRinge != kleinRinge ||
      old.grossName != grossName ||
      old.kleinName != kleinName;
}

class _FlaechenVergleichUI extends StatelessWidget {
  final Frage frage;
  final Map<String, List<List<Offset>>> geoRings;
  final String? gewaehlt;
  final bool showFeedback, feedbackRichtig;
  final void Function(String) onAntwort;

  const _FlaechenVergleichUI({
    required this.frage,
    required this.geoRings,
    required this.gewaehlt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onAntwort,
  });

  @override
  Widget build(BuildContext context) {
    final kleinIso = frage.meta['kleinesLand'] as String? ?? '';
    final grossRinge = geoRings[frage.laenderCode] ?? const <List<Offset>>[];
    final kleinRinge = geoRings[kleinIso] ?? const <List<Offset>>[];
    final geladen = grossRinge.isNotEmpty && kleinRinge.isNotEmpty;

    final kante = (MediaQuery.of(context).size.height * _kVergleichHoeheAnteil)
        .clamp(_kVergleichMin, _kVergleichMax);

    return Column(
      children: [
        Text(
          frage.frage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: kante,
          child: geladen
              ? CustomPaint(
                  painter: _VergleichsPainter(
                    grossRinge: grossRinge,
                    kleinRinge: kleinRinge,
                    grossName: _countryByIso2(frage.laenderCode)?.name ??
                        frage.laenderCode,
                    kleinName: _countryByIso2(kleinIso)?.name ?? kleinIso,
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
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

// ══════════════════════════════════════════════════════════════════════════════
// Was gehört nicht dazu? — vier Länderkarten im 2×2-Raster
// ══════════════════════════════════════════════════════════════════════════════

/// Leitgröße der Kachel: Seitenverhältnis Breite zu Höhe. Flagge, Name und
/// Innenabstand darunter sind Anteile der Kachelbreite, damit sie beim
/// Skalieren zusammenbleiben.
const _kQuartettSeitenverhaeltnis = 1.25;
const _kQuartettFlaggeAnteil = 0.52;
const _kQuartettNameAnteil = 0.105;
const _kQuartettPadAnteil = 0.09;
const _kQuartettAbstand = 12.0;

class _QuartettKachel extends StatelessWidget {
  final String iso2;
  final bool showFeedback, istRichtig, istGewaehlt;
  final VoidCallback? onTap;

  /// Kachelbreite als Leitgröße — vom Aufrufer berechnet, NICHT über einen
  /// LayoutBuilder gemessen. Der gesamte Fragen-Inhalt steckt in einem
  /// IntrinsicHeight (siehe build()), und ein LayoutBuilder kann dort ebenso
  /// wenig eine intrinsische Höhe melden wie ein GridView.
  final double breite;

  const _QuartettKachel({
    required this.iso2,
    required this.showFeedback,
    required this.istRichtig,
    required this.istGewaehlt,
    required this.breite,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Farbgebung wie bei den Antwort-Buttons: nach dem Antworten wird die
    // gesuchte Kachel grün, eine falsch gewählte rot — alles andere bleibt
    // neutral, damit der Blick auf der Auflösung landet.
    Color flaeche = Colors.white;
    Color rand = const Color(0xFF1A1A1A);
    if (showFeedback && istRichtig) {
      flaeche = const Color(0xFFE8F5E9);
      rand = const Color(0xFF2E7D32);
    } else if (showFeedback && istGewaehlt) {
      flaeche = const Color(0xFFFFEBEE);
      rand = const Color(0xFFD94040);
    }

    final co = _countryByIso2(iso2);
    return SizedBox(
      width: breite,
      height: breite / _kQuartettSeitenverhaeltnis,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(breite * _kQuartettPadAnteil),
          decoration: BoxDecoration(
            color: flaeche,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: rand, width: 2),
            boxShadow: [
              BoxShadow(color: rand, offset: const Offset(0, 4), blurRadius: 0),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FlaggenWidget(
                countryCode: iso2,
                width: breite * _kQuartettFlaggeAnteil,
                height: breite * _kQuartettFlaggeAnteil * 0.66,
                borderRadius: 5,
              ),
              SizedBox(height: breite * 0.07),
              // Lange Ländernamen (Bosnien und Herzegowina) müssen in die
              // Kachel passen, ohne dass die Kachelhöhe springt.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    co?.name ?? iso2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: breite * _kQuartettNameAnteil,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WasGehoertNichtDazuUI extends StatelessWidget {
  final Frage frage;
  final String? gewaehlt;
  final bool showFeedback, feedbackRichtig;
  final void Function(String) onAntwort;

  const _WasGehoertNichtDazuUI({
    required this.frage,
    required this.gewaehlt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onAntwort,
  });

  @override
  Widget build(BuildContext context) {
    final optionen = frage.antwortOptionen;
    // Leitgröße der Kacheln: die halbe nutzbare Breite. Der Screen legt 16px
    // Innenabstand je Seite an (SingleChildScrollView in build()), dazwischen
    // liegt der Kachelabstand.
    final kachelBreite =
        (MediaQuery.sizeOf(context).width - 32 - _kQuartettAbstand) / 2;
    return Column(
      children: [
        // Der Kategorien-Knopf stand hier, sitzt jetzt eine Ebene höher
        // (siehe _frageMitAnleitung) — dort war er zeitweise mit dem
        // Anleitungs-Knopf in einer Zeile; der ist inzwischen als rundes
        // Fragezeichen in die Kopfzeile gewandert, der Kategorien-Knopf
        // bleibt als einziger über der Spielfläche.
        Text(
          frage.frage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        // Zwei Reihen statt GridView: der gesamte Fragen-Inhalt steckt in
        // einem IntrinsicHeight, und ein GridView ist ein Viewport, der dort
        // keine intrinsische Höhe melden kann ("RenderShrinkWrappingViewport
        // does not support returning intrinsic dimensions"). Reihen aus
        // SizedBoxen haben das Problem nicht.
        for (var reihe = 0; reihe < 2; reihe++) ...[
          if (reihe > 0) const SizedBox(height: _kQuartettAbstand + 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var spalte = 0; spalte < 2; spalte++) ...[
                if (spalte > 0) const SizedBox(width: _kQuartettAbstand),
                if (reihe * 2 + spalte < optionen.length)
                  _QuartettKachel(
                    iso2: optionen[reihe * 2 + spalte],
                    breite: kachelBreite,
                    showFeedback: showFeedback,
                    istRichtig:
                        optionen[reihe * 2 + spalte] == frage.richtigeAntwort,
                    istGewaehlt: optionen[reihe * 2 + spalte] == gewaehlt,
                    onTap: showFeedback
                        ? null
                        : () => onAntwort(optionen[reihe * 2 + spalte]),
                  ),
              ],
            ],
          ),
        ],
        // Die Auflösung ist der Lerneffekt des Modus: sie sagt, WAS die
        // anderen drei verbindet. Ohne sie bliebe nur ein Ratespiel.
        if (showFeedback) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEAE5),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    frage.meta['aufloesung'] as String? ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Länder-Ranking — Zahlenschloss
// ══════════════════════════════════════════════════════════════════════════════
//
// Leitgröße ist die Walzenhöhe; Ziffergröße, Rahmenstärke und Breite der
// Walzen sind Anteile davon.

/// Leitgröße: die Kantenlänge EINES Schlosses. Es ist quadratisch, alle
/// weiteren Maße leiten sich daraus ab.
const _kSchlossGroesse = 96.0;

/// Randstärke des Schlossrahmens.
const _kSchlossRand = 2.5;

/// Höhe des Sichtfensters — die Innenfläche des Rahmens.
///
/// Die itemExtent der Walze ist GENAU so hoch. Nur dann steht immer exakt
/// eine Ziffer im Fenster und keine Nachbarziffer ragt angeschnitten herein.
const _kSchlossFenster = _kSchlossGroesse - 2 * _kSchlossRand;

const _kZifferGroesseAnteil = 0.55; // ~52pt bei 96px Kantenlänge
const _kSchlossRadiusAnteil = 0.17;

/// Abstand zwischen den drei getrennten Schlössern.
const _kSchlossAbstand = 14.0;

/// Rang-Zeichen links vor den Schlössern. Bewusst klein gegenüber den 53pt
/// großen Ziffern: es soll die Zahl einordnen, nicht mit ihr konkurrieren.
const _kRangZeichenGroesse = 18.0;
const _kRangZeichenAbstand = 8.0;

/// Ziffern je Stelle. Die Hunderterstelle führt nur 0 und 1 — mehr als 199
/// Rangplätze gibt es in keiner Kategorie (die größten Felder umfassen 197
/// Länder), Ziffern ab 2 wären dort tote Wege.
const _kZiffernProWalze = [2, 10, 10];

/// Höchster überhaupt vergebener Rangplatz — Rückfallwert, wenn eine Frage
/// die Feldgröße nicht mitliefert.
const _kMaxRang = 197;

const _cSchlossRahmen = Color(0xFF1A1A1A);
const _cSchlossGrund = Color(0xFFF4F5EE);

/// Toleranz in Rangplätzen, bis zu der die Antwort als richtig zählt.
///
/// Der exakte Rangplatz ist nicht erratbar — hier gilt dieselbe Logik wie bei
/// der 20-Prozent-Toleranz des Preis-Schätzens: gefragt ist ein Gefühl für
/// die Größenordnung, nicht auswendig gelernte Tabellen.
const kRankingToleranz = 15;

/// Punktekurve nach Abweichung in Rangplätzen.
///
/// Kontinuierlich statt in Stufen, wie beim Preis-Schätzen
/// (100 * exp(-dev/17)). Die ersten fünf Plätze sind frei, danach fällt die
/// Kurve so ab, dass die gewünschten Bänder herauskommen: 15 Plätze → 62,
/// 35 → 24, 70 → 5, darüber praktisch null.
int rankingPunkte(int abweichung) {
  if (abweichung <= 5) return 100;
  return (100 * exp(-(abweichung - 5) / 21)).round().clamp(0, 100);
}

/// Ein einzelnes Schloss: eine Walze in eigenem Rahmen.
///
/// Drei davon stehen nebeneinander statt einer durchgehenden Leiste — jedes
/// mit eigenem Rand und eigener Grundfläche, damit man die drei Stellen als
/// getrennte Räder liest.
class _Walze extends StatelessWidget {
  final FixedExtentScrollController controller;
  final bool gesperrt;
  final ValueChanged<int> onZiffer;

  /// Anzahl der Ziffern dieser Walze. Die Hunderterstelle führt nur 0 und 1:
  /// mehr als 199 Rangplätze gibt es in keiner Kategorie, Ziffern ab 2 wären
  /// dort tote Wege.
  final int ziffern;

  const _Walze({
    required this.controller,
    required this.gesperrt,
    required this.onZiffer,
    this.ziffern = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSchlossGroesse,
      height: _kSchlossGroesse,
      decoration: BoxDecoration(
        color: _cSchlossGrund,
        borderRadius:
            BorderRadius.circular(_kSchlossGroesse * _kSchlossRadiusAnteil),
        border: Border.all(color: _cSchlossRahmen, width: _kSchlossRand),
        boxShadow: const [
          BoxShadow(
              color: _cSchlossRahmen, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      // Doppelt geklippt: der Container schneidet an der abgerundeten Ecke,
      // die Walze selbst noch einmal an ihrem Fenster.
      clipBehavior: Clip.antiAlias,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        // Genau die Fensterhöhe: eine Ziffer füllt das Fenster aus, die
        // benachbarten liegen vollständig außerhalb.
        itemExtent: _kSchlossFenster,
        clipBehavior: Clip.hardEdge,
        // squeeze 1.0 statt 1.15: gestauchte Elemente rücken näher zusammen
        // und würden die Nachbarziffern wieder ins Fenster schieben.
        squeeze: 1.0,
        // Flach statt zylindrisch — bei nur einer sichtbaren Ziffer bringt
        // die Wölbung nichts und würde die große Ziffer verzerren.
        perspective: 0.001,
        diameterRatio: 100,
        physics: gesperrt
            ? const NeverScrollableScrollPhysics()
            : const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (i) => onZiffer(i % ziffern),
        // Endlos-Delegate: eine echte Schlosswalze hat keinen Anfang und kein
        // Ende, die letzte Ziffer geht direkt in die erste über.
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var z = 0; z < ziffern; z++)
              Center(
                child: Text(
                  '$z',
                  style: const TextStyle(
                    fontSize: _kSchlossGroesse * _kZifferGroesseAnteil,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                    height: 1.0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LaenderRankingUI extends StatefulWidget {
  final Frage frage;
  final bool bestaetigt, feedbackRichtig;
  final int eingabe;
  final void Function(int) onBestaetigen;
  final VoidCallback onWeiter;

  const _LaenderRankingUI({
    required this.frage,
    required this.bestaetigt,
    required this.feedbackRichtig,
    required this.eingabe,
    required this.onBestaetigen,
    required this.onWeiter,
  });

  @override
  State<_LaenderRankingUI> createState() => _LaenderRankingUIState();
}

class _LaenderRankingUIState extends State<_LaenderRankingUI> {
  late final List<FixedExtentScrollController> _ctrl = [
    for (var i = 0; i < 3; i++) FixedExtentScrollController(initialItem: 0),
  ];
  final _ziffern = [0, 0, 0];

  // Vibrations-Einstellungen VORAB laden: zwischen dem Einrasten der Walze
  // und dem Impuls darf kein await liegen, sonst kommt er zu spät.
  bool _vibrationAn = false;
  bool _hatAmplitude = false;

  @override
  void initState() {
    super.initState();
    EinstellungenService.vibrationAktiv.then((aktiv) async {
      if (!aktiv) return;
      final amp = await Vibration.hasAmplitudeControl();
      if (mounted) {
        setState(() {
          _vibrationAn = true;
          _hatAmplitude = amp;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _LaenderRankingUI old) {
    super.didUpdateWidget(old);
    // Der Belohnungsmoment: nach dem Bestätigen drehen die Walzen sichtbar auf
    // den echten Rangplatz weiter.
    if (!old.bestaetigt && widget.bestaetigt) _dreheAufAntwort();
  }

  @override
  void dispose() {
    for (final c in _ctrl) {
      c.dispose();
    }
    super.dispose();
  }

  /// Kurzer, sehr dezenter Impuls beim Einrasten einer Ziffer.
  void _rasten() {
    if (!_vibrationAn) return;
    if (_hatAmplitude) {
      Vibration.vibrate(duration: 20, amplitude: 40);
    } else {
      Vibration.vibrate(duration: 20);
    }
  }

  /// Der eingestellte Rangplatz, auf das gültige Feld begrenzt.
  ///
  /// Die dynamische Beschränkung der Einerwalze (bei 1_9 nur noch bis 5) habe
  /// ich bewusst weggelassen: die Walzen sind Endlos-Räder, deren Kinderzahl
  /// sich mitten im Drehen ändern müsste — das ruckelt und fühlt sich kaputt
  /// an. Stattdessen wird hier gekappt. 000 gibt es als Rangplatz nicht und
  /// zählt als 001.
  int get _eingabe {
    final roh = _ziffern[0] * 100 + _ziffern[1] * 10 + _ziffern[2];
    final feld =
        (widget.frage.meta['gesamt'] as num?)?.toInt() ?? _kMaxRang;
    return roh.clamp(1, feld);
  }

  void _dreheAufAntwort() {
    final rang = int.tryParse(widget.frage.richtigeAntwort) ?? 0;
    final ziel = [rang ~/ 100 % 10, rang ~/ 10 % 10, rang % 10];
    for (var i = 0; i < 3; i++) {
      // Immer VORWÄRTS drehen und mindestens eine volle Umdrehung: das sieht
      // nach einem Schloss aus, das aufspringt, statt nach einem Sprung.
      // Modulo je Walze, weil die Hunderterstelle nur zwei Ziffern hat.
      final n = _kZiffernProWalze[i];
      final jetzt = _ctrl[i].selectedItem;
      final schritte = ((ziel[i] - _ziffern[i]) % n + n) % n + n;
      _ctrl[i].animateToItem(
        jetzt + schritte,
        duration: Duration(milliseconds: 700 + i * 160),
        curve: Curves.easeOutBack,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.frage;
    final rang = int.tryParse(f.richtigeAntwort) ?? 0;
    final gesamt = (f.meta['gesamt'] as num?)?.toInt() ?? 0;
    final abweichung = (widget.eingabe - rang).abs();

    return Column(
      children: [
        if (f.laenderCode.isNotEmpty) ...[
          _LandHeader(iso2: f.laenderCode),
          const SizedBox(height: 14),
        ],
        Text(
          f.frage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          t('Platz 1 = höchster Wert · {n} Länder gewertet',
              {'n': '$gesamt'}),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF888888)),
        ),
        const SizedBox(height: 20),

        // ── Die drei Schlösser ───────────────────────────────────────────
        //
        // FittedBox: die Reihe ist mit Rang-Zeichen rund 340px breit, auf
        // einem 360px-Gerät stehen nach den Seitenrändern aber nur 328px zur
        // Verfügung. Statt umzubrechen oder überzulaufen skaliert die
        // Komposition dort als Ganzes herunter — die Verhältnisse zwischen
        // Zeichen, Schlössern und Abständen bleiben erhalten.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Das Rang-Zeichen steht LINKS: "#143" liest sich in der
              // richtigen Reihenfolge, und im Deutschen steht "Platz" ohnehin
              // vor der Zahl, nicht dahinter.
              Padding(
                padding: const EdgeInsets.only(right: _kRangZeichenAbstand),
                child: Text(
                  '#',
                  style: TextStyle(
                    fontSize: _kRangZeichenGroesse,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF888888),
                  ),
                ),
              ),
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: _kSchlossAbstand),
                _Walze(
                  controller: _ctrl[i],
                  gesperrt: widget.bestaetigt,
                  ziffern: _kZiffernProWalze[i],
                  onZiffer: (z) {
                    if (_ziffern[i] == z) return;
                    setState(() => _ziffern[i] = z);
                    if (!widget.bestaetigt) _rasten();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),

        if (!widget.bestaetigt)
          GestureDetector(
            onTap: () => widget.onBestaetigen(_eingabe),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF4A9E4A),
                borderRadius: BorderRadius.circular(50),
                border:
                    Border.all(color: const Color(0xFF1A1A1A), width: 2.5),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xFF1A1A1A),
                      offset: Offset(0, 4),
                      blurRadius: 0),
                ],
              ),
              child: Text(
                t('Bestätigen'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          )
        else ...[
          _RankingAufloesung(
            frage: f,
            rang: rang,
            abweichung: abweichung,
            richtig: widget.feedbackRichtig,
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: widget.onWeiter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF4A9E4A),
                borderRadius: BorderRadius.circular(50),
                border:
                    Border.all(color: const Color(0xFF1A1A1A), width: 2.5),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xFF1A1A1A),
                      offset: Offset(0, 4),
                      blurRadius: 0),
                ],
              ),
              child: Text(
                t('Weiter'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Auflösung nach dem Bestätigen: echter Rang, Abweichung, echter Wert.
class _RankingAufloesung extends StatelessWidget {
  final Frage frage;
  final int rang, abweichung;
  final bool richtig;

  const _RankingAufloesung({
    required this.frage,
    required this.rang,
    required this.abweichung,
    required this.richtig,
  });

  @override
  Widget build(BuildContext context) {
    final wert = (frage.meta['wert'] as num?)?.toDouble();
    final einheit = frage.meta['einheit'] as String? ?? '';
    final emoji = frage.meta['emoji'] as String? ?? '';
    final punkte = rankingPunkte(abweichung);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: richtig ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: richtig
                ? const Color(0xFF2E7D32)
                : const Color(0xFFD94040),
            width: 2),
      ),
      child: Column(
        children: [
          Text(
            t('Platz {n}', {'n': '$rang'}),
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 4),
          Text(
            abweichung == 0
                ? t('Genau richtig!')
                : t('{n} Plätze daneben · {p} Punkte',
                    {'n': '$abweichung', 'p': '$punkte'}),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888)),
          ),
          if (wert != null) ...[
            const SizedBox(height: 10),
            Text(
              // _formatGrosswert statt eigener Formatierung: es übersetzt die
              // Einheit und kürzt große Zahlen sprachrichtig ("1.4B" statt
              // "1,4 Mrd."). Meine erste Fassung hatte beides hartcodiert
              // deutsch.
              '$emoji  ${_formatGrosswert(wert, einheit)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A)),
            ),
          ],
        ],
      ),
    );
  }

}

// ══════════════════════════════════════════════════════════════════════════════
// Zwei Wahrheiten, eine Lüge — drei Karten mit Auflösungs-Effekt
// ══════════════════════════════════════════════════════════════════════════════
//
// Die Karten stehen UNTEREINANDER, nicht nebeneinander. Gemessen an 450
// erzeugten Aussagen: Median 31 Zeichen, 90. Perzentil 40, längste 114 (die
// kuratierten Fun-Facts sind ganze Sätze). Drei Spalten auf einem 360dp
// breiten Gerät ließen je Karte rund 11 Zeichen pro Zeile — der längste Text
// bräuchte elf Zeilen, und alle drei Karten würden auf diese Höhe gezogen.
// Volle Breite untereinander ergibt dagegen rund 38 Zeichen pro Zeile: der
// Median passt in eine Zeile, der längste Text in vier.

/// Leitgröße des Effekts: der Schattenversatz der ruhenden Karte. Hebung und
/// Rücktritt sind Vielfache davon, damit die drei Zustände zusammenbleiben.
const _kAussageSchattenRuhe = 4.0;
const _kAussageSchattenVorn = 6.0;
const _kAussageSchattenZurueck = 2.0;

const _kAussageDauer = Duration(milliseconds: 600);

/// Kurzes Wackeln der falsch getippten Karte, bevor sie zurücktritt.
const _kAussageWackeln = Duration(milliseconds: 300);

// ── Reihenfolge der Auflösung ───────────────────────────────────────────────
//
// Der Ablauf hängt vom Ergebnis ab, nicht von der Position der Karten. Bei
// richtiger Antwort steht zuerst der Fund im Vordergrund, bei falscher zuerst
// der Irrtum — danach jeweils der Rest.

/// Richtig geraten: die gesuchte Karte hebt sich sofort, die beiden anderen
/// treten danach nacheinander zurück (von oben nach unten).
const _kFolgeRichtig = [
  Duration(milliseconds: 400),
  Duration(milliseconds: 600),
];

/// Falsch geraten: die getippte Karte wackelt ab 0ms und tritt ab 300ms
/// zurück, danach hebt sich die gesuchte, zuletzt geht die dritte zurück.
const _kFalschLuegeAb = Duration(milliseconds: 600);
const _kFalschRestAb = Duration(milliseconds: 900);

const _kAussageScaleVorn = 1.03;
const _kAussageScaleZurueck = 0.94;
const _kAussageHubVorn = -4.0;
const _kAussageHubZurueck = 4.0;
const _kAussageDeckkraftZurueck = 0.5;

/// Seitlicher Rand um jede Karte, damit die vergrößerte Karte nie über den
/// verfügbaren Bereich hinausragt.
///
/// Bei Scale 1.03 wächst eine Karte um 1,5 % ihrer Breite je Seite — auf
/// einem Tablet mit rund 700px nutzbarer Breite sind das gut 5px. 8px lassen
/// auch dort Luft und wirken zugleich als Abstand nach außen.
const _kAussageSeitenrand = 8.0;

/// Die Erklärung erscheint erst, wenn ALLE Karten stehen — sonst konkurriert
/// sie mit der Bewegung um die Aufmerksamkeit.
const _kErklaerungDauer = Duration(milliseconds: 250);

const _cAussageRuhe = Color(0xFFFFFDF7);
const _cAussageZurueck = Color(0xFFDDDAD2);
const _cAussageVorn = Color(0xFF4A9E4A);

class _AussageKarte extends StatefulWidget {
  /// Die gesuchte falsche Aussage — sie wird bei der Auflösung hervorgehoben,
  /// unabhängig davon, was der Spieler getippt hat.
  final bool istLuege;
  final bool istGewaehlt, showFeedback, feedbackRichtig;
  final String text;
  final VoidCallback? onTap;

  /// Wann die Bewegung dieser Karte beginnt. Kommt vom Aufrufer, weil nur
  /// der die Rollen aller drei Karten kennt.
  final Duration startVerzoegerung;

  /// Ob die Karte vor dem Zurücktreten wackelt (die falsch getippte).
  final bool wackelt;

  const _AussageKarte({
    required this.text,
    required this.istLuege,
    required this.istGewaehlt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.startVerzoegerung,
    required this.wackelt,
    this.onTap,
  });

  @override
  State<_AussageKarte> createState() => _AussageKarteState();
}

class _AussageKarteState extends State<_AussageKarte>
    with TickerProviderStateMixin {
  late final AnimationController _wackelCtrl =
      AnimationController(vsync: this, duration: _kAussageWackeln);
  late final AnimationController _aufloesungCtrl =
      AnimationController(vsync: this, duration: _kAussageDauer);

  @override
  void initState() {
    super.initState();
    // Beim Wechsel zur nächsten Frage wird der Screen neu gebaut; steht das
    // Feedback schon, muss die Karte ohne Animation im Endzustand starten.
    if (widget.showFeedback) _aufloesungCtrl.value = 1;
  }

  @override
  void didUpdateWidget(covariant _AussageKarte old) {
    super.didUpdateWidget(old);
    if (!old.showFeedback && widget.showFeedback) _starteAufloesung();
    if (old.showFeedback && !widget.showFeedback) {
      _aufloesungCtrl.value = 0;
      _wackelCtrl.value = 0;
    }
  }

  Future<void> _starteAufloesung() async {
    // Erst der Platz in der Folge — welcher das ist, bestimmt der Aufrufer
    // anhand der Rollen aller drei Karten.
    if (widget.startVerzoegerung > Duration.zero) {
      await Future<void>.delayed(widget.startVerzoegerung);
      if (!mounted || !widget.showFeedback) return;
    }
    // Die falsch getippte Karte wackelt als Signal, bevor sie zurücktritt.
    if (widget.wackelt) {
      await _wackelCtrl.forward(from: 0);
      if (!mounted) return;
    }
    _aufloesungCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _wackelCtrl.dispose();
    _aufloesungCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_wackelCtrl, _aufloesungCtrl]),
      builder: (context, _) {
        final roh = _aufloesungCtrl.value;
        // easeOutBack schwingt über 1.0 hinaus — das trägt die Hebung, darf
        // aber nicht in Farben und Deckkraft laufen, sonst kippen die Werte
        // aus ihrem gültigen Bereich.
        final hebung = Curves.easeOutBack.transform(roh);
        final ruecktritt = Curves.easeOut.transform(roh);
        final farbT = roh.clamp(0.0, 1.0);

        final double scale, hub, schatten, deckkraft;
        final Color flaeche, rand, schrift;
        if (widget.istLuege) {
          scale = 1 + (_kAussageScaleVorn - 1) * hebung;
          hub = _kAussageHubVorn * hebung;
          schatten = _kAussageSchattenRuhe +
              (_kAussageSchattenVorn - _kAussageSchattenRuhe) * farbT;
          deckkraft = 1.0;
          flaeche = Color.lerp(_cAussageRuhe, _cAussageVorn, farbT)!;
          rand = const Color(0xFF1A1A1A);
          schrift = Color.lerp(const Color(0xFF1A1A1A), Colors.white, farbT)!;
        } else {
          scale = 1 + (_kAussageScaleZurueck - 1) * ruecktritt;
          hub = _kAussageHubZurueck * ruecktritt;
          schatten = _kAussageSchattenRuhe +
              (_kAussageSchattenZurueck - _kAussageSchattenRuhe) * farbT;
          deckkraft = 1 - (1 - _kAussageDeckkraftZurueck) * farbT;
          flaeche = Color.lerp(_cAussageRuhe, _cAussageZurueck, farbT)!;
          rand = Color.lerp(
              const Color(0xFF1A1A1A), const Color(0xFF888888), farbT)!;
          schrift = Color.lerp(
              const Color(0xFF1A1A1A), const Color(0xFF888888), farbT)!;
        }

        final dx = widget.wackelt ? wackelOffset(_wackelCtrl.value) : 0.0;
        // Häkchen nur, wenn der Spieler die Lüge selbst gefunden hat.
        final zeigeHaken =
            widget.istLuege && widget.showFeedback && widget.feedbackRichtig;

        return Transform.translate(
          offset: Offset(dx, hub),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: deckkraft,
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: flaeche,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: rand, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: rand,
                        offset: Offset(0, schatten),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: schrift,
                          ),
                        ),
                      ),
                      if (zeigeHaken) ...[
                        const SizedBox(width: 8),
                        Opacity(
                          opacity: farbT,
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Blendet die Begründung verzögert ein.
class _ErklaerungEinblendung extends StatefulWidget {
  final String text;
  final Duration verzoegerung;
  const _ErklaerungEinblendung(
      {required this.text, required this.verzoegerung});

  @override
  State<_ErklaerungEinblendung> createState() => _ErklaerungEinblendungState();
}

class _ErklaerungEinblendungState extends State<_ErklaerungEinblendung> {
  bool _sichtbar = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.verzoegerung, () {
      if (mounted) setState(() => _sichtbar = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _sichtbar ? 1 : 0,
      duration: _kErklaerungDauer,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEAE5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZweiWahrheitenUI extends StatelessWidget {
  final Frage frage;
  final String? gewaehlt;
  final bool showFeedback, feedbackRichtig;
  final void Function(String) onAntwort;

  const _ZweiWahrheitenUI({
    required this.frage,
    required this.gewaehlt,
    required this.showFeedback,
    required this.feedbackRichtig,
    required this.onAntwort,
  });

  @override
  Widget build(BuildContext context) {
    final erklaerung = frage.meta['erklaerung'] as String? ?? '';
    final optionen = frage.antwortOptionen;

    // ── Wer wann dran ist ────────────────────────────────────────────────
    //
    // Die Reihenfolge richtet sich nach der Rolle der Karte, nicht nach ihrer
    // Position: richtig geraten heißt zuerst den Fund zeigen, falsch geraten
    // zuerst den Irrtum.
    final luegeIndex = optionen.indexOf(frage.richtigeAntwort);
    final gewaehltIndex = gewaehlt == null ? -1 : optionen.indexOf(gewaehlt!);
    final starts = List<Duration>.filled(optionen.length, Duration.zero);
    final wackelt = List<bool>.filled(optionen.length, false);

    if (showFeedback) {
      if (feedbackRichtig) {
        // Gesuchte Karte sofort, die beiden anderen danach von oben nach
        // unten.
        var rang = 0;
        for (var i = 0; i < optionen.length; i++) {
          if (i == luegeIndex) continue;
          starts[i] = _kFolgeRichtig[rang.clamp(0, _kFolgeRichtig.length - 1)];
          rang++;
        }
      } else {
        for (var i = 0; i < optionen.length; i++) {
          if (i == gewaehltIndex) {
            wackelt[i] = true; // startet bei 0, tritt nach dem Wackeln zurück
          } else if (i == luegeIndex) {
            starts[i] = _kFalschLuegeAb;
          } else {
            starts[i] = _kFalschRestAb;
          }
        }
      }
    }

    // Die Erklärung wartet, bis die letzte Karte fertig ist.
    var ende = Duration.zero;
    for (var i = 0; i < optionen.length; i++) {
      final fertig = starts[i] +
          (wackelt[i] ? _kAussageWackeln : Duration.zero) +
          _kAussageDauer;
      if (fertig > ende) ende = fertig;
    }

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
        const SizedBox(height: 22),
        for (var i = 0; i < optionen.length; i++) ...[
          // Seitlicher Rand außerhalb der Skalierung: dadurch wächst die
          // hervorgehobene Karte in diesen Rand hinein statt über ihn hinaus.
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: _kAussageSeitenrand),
            child: _AussageKarte(
              text: optionen[i],
              startVerzoegerung: starts[i],
              wackelt: wackelt[i],
              istLuege: optionen[i] == frage.richtigeAntwort,
              istGewaehlt: optionen[i] == gewaehlt,
              showFeedback: showFeedback,
              feedbackRichtig: feedbackRichtig,
              onTap: showFeedback ? null : () => onAntwort(optionen[i]),
            ),
          ),
          // Zwischenraum großzügig: die hervorgehobene Karte wächst um 3 %
          // und hebt sich um 4px — ohne Luft würde sie die Nachbarn berühren.
          const SizedBox(height: 18),
        ],
        if (showFeedback && erklaerung.isNotEmpty) ...[
          const SizedBox(height: 4),
          _ErklaerungEinblendung(text: erklaerung, verzoegerung: ende),
        ],
      ],
    );
  }
}

/// Beschrifteter Hilfe-Button in der Spielfläche.
///
/// Bewusst nicht in der AppBar: dort sitzen Fortschritt und Skip, und die
/// Hilfe gehört inhaltlich zur Frage, nicht zur Station.
///
/// War ursprünglich fest auf "Was gehört nicht dazu?" verdrahtet (hiess
/// _KategorienKnopf und trug Beschriftung und Symbol fest im Rumpf). Er nimmt
/// beides jetzt als Parameter — die Optik bleibt für alle Aufrufer dieselbe,
/// und das ist der Punkt: ein Spieler soll den Knopf wiedererkennen, egal in
/// welchem Modus er ihn zuerst gesehen hat.
class _SpielflaechenKnopf extends StatelessWidget {
  final IconData icon;
  final String beschriftung;
  final VoidCallback onTap;

  const _SpielflaechenKnopf({
    required this.icon,
    required this.beschriftung,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF1A1A1A)),
            const SizedBox(width: 6),
            Text(
              beschriftung,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Runder Fragezeichen-Knopf oben rechts in der hellen Spielfläche — öffnet
/// die Anleitung des laufenden Modus.
///
/// Er ersetzt den beschrifteten Knopf, der früher über der Frage stand, und
/// sass zwischenzeitlich in der dunkelgrünen Kopfzeile. Auf dem hellen Grund
/// braucht er andere Farben: weisse Fläche mit dunkler Outline statt heller
/// Linien auf Grün — dieselbe Sprache wie die Karten der App.
///
/// Der Kreis ist bewusst kleiner als die Tippfläche: 27 px wirken neben dem
/// Skip-Knopf zurückhaltend, 44 px sind das Mindestmaß für einen Finger. Der
/// Kreis sitzt am RECHTEN Rand seiner Tippfläche, damit er mit dem Inhalt
/// darunter auf einer Kante steht; die überzählige Fläche liegt links, wo
/// nichts ist.
class _FragezeichenKnopf extends StatelessWidget {
  final VoidCallback onTap;
  const _FragezeichenKnopf({required this.onTap});

  /// 0.8 der früheren 34 px.
  static const _kreis = 27.0;
  static const _tippflaeche = 44.0;
  static const _symbol = _kreis * 0.5;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: t('Anleitung'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _tippflaeche,
          height: _tippflaeche,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: _kreis,
              height: _kreis,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5),
              ),
              child: const Icon(Icons.question_mark_rounded,
                  size: _symbol, color: Color(0xFF1A1A1A)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Öffnet die ausführliche Anleitung eines Modus.
///
/// Nutzt zeigeSpielErklaerung() aus widgets/spiel_erklaerung.dart — dasselbe
/// Bottom-Sheet, das die vier Tages-Challenges schon verwenden. Der Lernpfad
/// hatte bisher gar keinen Zugang dazu.
Future<void> zeigeModusAnleitung(BuildContext context, LernModus modus) {
  final absaetze = lernModusAnleitung(modus);
  if (absaetze.isEmpty) return Future<void>.value();
  return zeigeSpielErklaerung(
    context,
    titel: t('{modus} — so geht es', {'modus': lernModusLabel(modus)}),
    abschnitte: absaetze,
    farbe: const Color(0xFF4A9E4A),
  );
}

/// Overlay mit den Merkmalen, auf die "Was gehört nicht dazu?" prüfen kann.
///
/// Die Liste kommt aus [FragenGenerator.quartettKategorien] und damit aus
/// derselben Quelle, die der Generator auswertet — sie kann nicht veralten.
void zeigeQuartettHilfe(BuildContext context) => zeigeListenHilfe(
      context,
      titel: t('Mögliche Gemeinsamkeiten'),
      untertitel: t('Drei der vier Länder teilen genau eines dieser Merkmale.'),
      eintraege: FragenGenerator.quartettKategorien,
    );

/// Overlay mit Titel, erklärender Zeile und einer Aufzählung.
///
/// Vorher steckten Titel, Zeile und die Kategorien-Liste fest im Rumpf, die
/// Funktion hiess zeigeQuartettHilfe und war nur für einen Modus zu
/// gebrauchen. Jetzt trägt sie nur noch die Darstellung; WAS aufgezählt wird,
/// gibt der Aufrufer mit.
///
/// Für Fliesstext ist zeigeSpielErklaerung() aus
/// widgets/spiel_erklaerung.dart zuständig — eine Aufzählung braucht die
/// kompaktere Form, ein Bottom-Sheet über den halben Bildschirm wäre für
/// sieben Stichworte zu viel Aufhebens.
void zeigeListenHilfe(
  BuildContext context, {
  required String titel,
  required String untertitel,
  required List<String> eintraege,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => GestureDetector(
      // Antippen irgendwo schließt — zusätzlich zum Schließen-Button und zum
      // Tippen auf den abgedunkelten Hintergrund.
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(ctx).pop(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xFF1A1A1A),
                  offset: Offset(0, 4),
                  blurRadius: 0),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                untertitel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF888888),
                ),
              ),
              const SizedBox(height: 14),
              for (final kategorie in eintraege)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4A9E4A))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          kategorie,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9E4A),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: const Color(0xFF1A1A1A), width: 2),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0xFF1A1A1A),
                            offset: Offset(0, 3),
                            blurRadius: 0),
                      ],
                    ),
                    child: Text(
                      t('Schließen'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
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

// ══════════════════════════════════════════════════════════════════════════════
// Nachbarschafts-Kette — den Weg selbst bauen
// ══════════════════════════════════════════════════════════════════════════════

/// Punkte nach Abweichung vom kürzesten Weg.
///
/// Anders als beim Länder-Ranking keine stetige Kurve: hier gibt es nur
/// ganze Schritte, und bereits zwei Umwege sind ein deutlich anderer Weg.
int kettePunkte(int schritte, int optimum) => switch (schritte - optimum) {
      <= 0 => 100,
      1 => 70,
      2 => 35,
      _ => 0,
    };

/// Bis zu wie vielen Schritten über dem Optimum die Antwort noch als richtig
/// zählt. Ein einzelner Umweg ist Geografie-Wissen, kein Fehler.
const kKetteToleranz = 1;

const _kKetteFlaggeBreite = 34.0;
const _kKetteChipRadius = 10.0;

/// Ein antippbares Nachbarland.
class _NachbarChip extends StatelessWidget {
  final String iso2;
  final bool istZiel;
  final VoidCallback? onTap;
  const _NachbarChip({required this.iso2, required this.istZiel, this.onTap});

  @override
  Widget build(BuildContext context) {
    final co = _countryByIso2(iso2);
    // Das Zielland wird hervorgehoben — ohne diesen Hinweis übersieht man
    // leicht, dass der nächste Schritt schon der letzte sein kann.
    final rand = istZiel ? const Color(0xFF4A9E4A) : const Color(0xFF1A1A1A);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: istZiel ? const Color(0xFFE8F5E9) : const Color(0xFFFFFDF7),
          borderRadius: BorderRadius.circular(_kKetteChipRadius),
          border: Border.all(color: rand, width: 2),
          boxShadow: [
            BoxShadow(color: rand, offset: const Offset(0, 3), blurRadius: 0),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlaggenWidget(
                countryCode: iso2,
                width: _kKetteFlaggeBreite,
                height: _kKetteFlaggeBreite * 0.66,
                borderRadius: 4),
            const SizedBox(width: 7),
            ConstrainedBox(
              // Lange Namen dürfen den Chip nicht über die Zeile treiben.
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                co?.name ?? iso2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine Länderkette als Flaggenfolge mit Pfeilen.
class _KettenBand extends StatelessWidget {
  final List<String> kette;
  final double flaggenBreite;
  const _KettenBand({required this.kette, this.flaggenBreite = 30});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 6,
      children: [
        for (var i = 0; i < kette.length; i++) ...[
          if (i > 0)
            const Icon(Icons.arrow_forward_rounded,
                size: 15, color: Color(0xFF888888)),
          FlaggenWidget(
              countryCode: kette[i],
              width: flaggenBreite,
              height: flaggenBreite * 0.66,
              borderRadius: 3),
        ],
      ],
    );
  }
}

class _NachbarschaftsKetteUI extends StatefulWidget {
  final Frage frage;
  final bool bestaetigt, feedbackRichtig;

  /// Der vom Spieler gebaute Weg — steht erst nach dem Erreichen des Ziels
  /// fest und wird dann vom Screen zurückgereicht.
  final List<String> weg;
  final void Function(List<String> weg) onZielErreicht;
  final VoidCallback onWeiter;

  const _NachbarschaftsKetteUI({
    required this.frage,
    required this.bestaetigt,
    required this.feedbackRichtig,
    required this.weg,
    required this.onZielErreicht,
    required this.onWeiter,
  });

  @override
  State<_NachbarschaftsKetteUI> createState() => _NachbarschaftsKetteUIState();
}

class _NachbarschaftsKetteUIState extends State<_NachbarschaftsKetteUI> {
  late List<String> _pfad;

  String get _startIso => widget.frage.meta['startIso'] as String? ?? '';
  String get _zielIso => widget.frage.meta['zielIso'] as String? ?? '';
  int get _optimum => (widget.frage.meta['optimum'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _pfad = [_startIso];
  }

  @override
  void didUpdateWidget(covariant _NachbarschaftsKetteUI old) {
    super.didUpdateWidget(old);
    // Neue Frage im selben Widget: von vorn beginnen.
    if (old.frage.id != widget.frage.id) {
      _pfad = [_startIso];
    }
  }

  void _waehle(String iso2) {
    if (widget.bestaetigt) return;
    setState(() => _pfad = [..._pfad, iso2]);
    // Ziel erreicht: die Frage ist vorbei, der Screen wertet aus.
    if (iso2 == _zielIso) widget.onZielErreicht(_pfad);
  }

  void _zurueck() {
    if (widget.bestaetigt || _pfad.length <= 1) return;
    setState(() => _pfad = _pfad.sublist(0, _pfad.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    // Nach der Auswertung den zurückgereichten Weg zeigen, davor den eigenen
    // Zwischenstand.
    final pfad = widget.bestaetigt && widget.weg.isNotEmpty ? widget.weg : _pfad;
    final aktuell = pfad.last;
    final nachbarnDesAktuellen =
        (FragenGenerator.grenzGraph()[aktuell] ?? const <String>{}).toList()
          // Schon besuchte Länder ausblenden: ein Weg, der sich selbst
          // kreuzt, ist nie kürzer und würde die Auswahl nur zustellen.
          .where((n) => !pfad.contains(n))
          .toList()
      ..sort((a, b) {
        // Das Zielland immer zuerst, sonst alphabetisch — bei vierzehn
        // Nachbarn wäre eine zufällige Reihenfolge mühsam zu überblicken.
        if (a == _zielIso) return -1;
        if (b == _zielIso) return 1;
        final an = _countryByIso2(a)?.name ?? a;
        final bn = _countryByIso2(b)?.name ?? b;
        return an.compareTo(bn);
      });

    final startCo = _countryByIso2(_startIso);
    final zielCo = _countryByIso2(_zielIso);

    return Column(
      children: [
        // ── Start und Ziel ───────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                children: [
                  FlaggenWidget(
                      countryCode: _startIso,
                      width: 56,
                      height: 36,
                      borderRadius: 6),
                  const SizedBox(height: 6),
                  Text(startCo?.name ?? _startIso,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child:
                  Icon(Icons.arrow_forward_rounded, color: Color(0xFF888888)),
            ),
            Expanded(
              child: Column(
                children: [
                  FlaggenWidget(
                      countryCode: _zielIso,
                      width: 56,
                      height: 36,
                      borderRadius: 6),
                  const SizedBox(height: 6),
                  Text(zielCo?.name ?? _zielIso,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          widget.frage.frage,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),

        // ── Die bisher gebaute Kette ─────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAEAE5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                t('Dein Weg · {n} Schritte', {'n': '${pfad.length - 1}'}),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888888)),
              ),
              const SizedBox(height: 8),
              _KettenBand(kette: pfad),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (!widget.bestaetigt) ...[
          // ── Zurück ──────────────────────────────────────────────────────
          if (pfad.length > 1)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _zurueck,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF7),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFF888888), width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.undo_rounded,
                          size: 15, color: Color(0xFF888888)),
                      const SizedBox(width: 6),
                      Text(t('Schritt zurück'),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF888888))),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // ── Auswahl der Nachbarn ────────────────────────────────────────
          Text(
            t('Nachbarn von {land}', {
              'land': _countryByIso2(aktuell)?.name ?? aktuell,
            }),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF888888)),
          ),
          const SizedBox(height: 10),
          if (nachbarnDesAktuellen.isEmpty)
            // Sackgasse: alle Nachbarn liegen schon im Weg.
            Text(
              t('Von hier geht es nicht weiter — nimm einen Schritt zurück.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD94040)),
            )
          else
            // Wrap statt Raster mit eigenem Scrollbereich: der Fragen-Inhalt
            // steckt im IntrinsicHeight des Screens, und jeder Viewport
            // (GridView/ListView) kann dort keine Höhe melden. Die Chips
            // fließen deshalb in Zeilen um, und bei vierzehn Nachbarn
            // scrollt einfach die Seite.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final n in nachbarnDesAktuellen)
                  _NachbarChip(
                    iso2: n,
                    istZiel: n == _zielIso,
                    onTap: () => _waehle(n),
                  ),
              ],
            ),
        ] else ...[
          _KettenAufloesung(
            frage: widget.frage,
            weg: pfad,
            optimum: _optimum,
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: widget.onWeiter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF4A9E4A),
                borderRadius: BorderRadius.circular(50),
                border:
                    Border.all(color: const Color(0xFF1A1A1A), width: 2.5),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0xFF1A1A1A),
                      offset: Offset(0, 4),
                      blurRadius: 0),
                ],
              ),
              child: Text(
                t('Weiter'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Auflösung: eigener Weg, Bewertung und — falls nicht optimal — der
/// kürzeste Weg zum Vergleich.
class _KettenAufloesung extends StatelessWidget {
  final Frage frage;
  final List<String> weg;
  final int optimum;

  const _KettenAufloesung({
    required this.frage,
    required this.weg,
    required this.optimum,
  });

  @override
  Widget build(BuildContext context) {
    final schritte = weg.length - 1;
    final optimal = schritte <= optimum;
    final punkte = kettePunkte(schritte, optimum);
    final besterWeg =
        (frage.meta['optimalerWeg'] as List<dynamic>?)?.cast<String>() ??
            const <String>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: optimal ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color:
                optimal ? const Color(0xFF2E7D32) : const Color(0xFFF9A825),
            width: 2),
      ),
      child: Column(
        children: [
          Text(
            optimal
                ? t('Kürzester Weg!')
                : t('Ziel erreicht · {p} Punkte', {'p': '$punkte'}),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 6),
          Text(
            t('Der kürzeste Weg braucht {n} Schritte — du hast {m} gebraucht.',
                {'n': '$optimum', 'm': '$schritte'}),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888)),
          ),
          if (!optimal && besterWeg.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(t('Der kürzeste Weg:'),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF888888))),
            const SizedBox(height: 6),
            _KettenBand(kette: besterWeg, flaggenBreite: 26),
          ],
        ],
      ),
    );
  }
}
