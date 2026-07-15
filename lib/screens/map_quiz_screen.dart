import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/stats_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/countries.dart';
import '../l10n/uebersetzungen.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
const _cOcean = Color(0xFF8EC8DC);
const _cLand = Color(0xFF4A9E4A);
const _cLandHover = Color(0xFF3D8B3D); // ~15% darker, desktop hover
const _cBorder = Color(0xFF1B5E20);
const _cLandDim = Color(0xFF2E5E2E);
const _cBorderDim = Color(0xFF1A3A1A);
const _cRed = Color(0xFFE53935);
const _cRedBorder = Color(0xFFB71C1C);

const double _maxZ = 10.0;

class MapQuizScreen extends StatefulWidget {
  final int questionCount;
  final bool isDaily;
  final String? continent;
  const MapQuizScreen({super.key, this.questionCount = 10, this.isDaily = false, this.continent});

  @override
  State<MapQuizScreen> createState() => _MapQuizScreenState();
}

// Approximate center+zoom per continent so the map starts focused there
const _kContinentCenter = <String, (double lat, double lng, double zoom)>{
  'Europa':       (54.0,  15.0,  3.5),
  'Nordamerika':  (40.0, -95.0,  2.8),
  'Südamerika':   (-15.0, -60.0, 3.0),
  'Asien':        (37.0,  88.0,  2.5),
  'Afrika':       (2.0,   20.0,  2.8),
  'Ozeanien':     (-20.0, 148.0, 3.2),
};

// Geographic bounds per continent (minLat, minLon, maxLat, maxLon).
// Used to dim overseas-territory rings that belong to a country in another continent
// (e.g. France's Guiana ring showing bright during Europe quiz).
// Ozeanien omitted — Pacific islands straddle the date line, skip geo-filter there.
const _kContinentBounds = <String, (double, double, double, double)>{
  'Europa':      (26.0, -32.0, 82.0,  62.0),
  'Nordamerika': ( 4.0,-170.0, 86.0, -10.0),
  'Südamerika':  (-58.0, -84.0, 16.0, -26.0),
  'Asien':       (-12.0,  24.0, 82.0, 180.0),
  'Afrika':      (-35.0, -18.0, 38.0,  52.0),
};

class _MapQuizScreenState extends State<MapQuizScreen> {
  int _totalQ = 0;

  final _mapCtrl = MapController();

  final _listenerKey = GlobalKey();
  double _dynMinZoom = 2.0;

  bool _loading = true;
  List<_GeoFeature> _geoFeatures = [];
  List<Polygon> _basePolygons = [];

  Set<String>? _continentIso2s;
  LatLng _mapInitCenter = const LatLng(20, 10);
  double? _mapInitZoom;

  late List<Country> _questions;
  int _current = 0;
  bool _answered = false;
  int _totalScore = 0;
  bool _finished = false;
  String? _hoveredIso2;
  Map<String, bool> _countryAnswers = {};
  Set<String> _wrongFirst = {};     // iso2s found only after a wrong first guess → shown red
  String? _hoveredDotIso2;          // iso2 whose small-island dot is currently hovered
  Set<String> _largeIso2s = {};     // iso2s that have at least one large (non-smallIsland) polygon

  // Wrong-answer blink state
  bool _waitingForCorrect = false;
  bool _blinkOn = false;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _mapCtrl.dispose();
    super.dispose();
  }

  // ─── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/geo/ne_50m_countries.geojson');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final features = json['features'] as List;

    _geoFeatures = [];
    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>;
      // ISO_A2_EH is more complete than ISO_A2 (Norway, France, Kosovo fixed)
      final rawIso = (props['ISO_A2_EH'] as String? ?? '').isNotEmpty &&
              (props['ISO_A2_EH'] as String? ?? '') != '-99'
          ? props['ISO_A2_EH'] as String
          : (props['ISO_A2'] as String? ?? '');
      final iso2 = (rawIso.isEmpty || rawIso == '-99') ? '' : rawIso;
      final name = props['NAME'] as String? ?? '';

      if (iso2 == 'AQ' || name == 'Antarctica') continue;

      final geo = f['geometry'] as Map<String, dynamic>;
      final type = geo['type'] as String;
      final coords = geo['coordinates'] as List;
      final rings = <List<LatLng>>[];
      if (type == 'Polygon') {
        rings.add(_ring(coords[0] as List));
      } else if (type == 'MultiPolygon') {
        for (final poly in coords) {
          rings.add(_ring((poly as List)[0] as List));
        }
      }
      if (rings.isEmpty) continue;

      // Compute centroid + bbox of the largest ring for small-island fallback.
      final ring0 = rings.first;
      double sumLat = 0, sumLng = 0;
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      for (final p in ring0) {
        sumLat += p.latitude; sumLng += p.longitude;
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      final centroid = LatLng(sumLat / ring0.length, sumLng / ring0.length);
      final bboxDeg = (maxLat - minLat) * (maxLng - minLng);

      _geoFeatures.add(_GeoFeature(
        iso2: iso2, name: name, rings: rings,
        centroid: centroid, smallIsland: bboxDeg < 0.3,
      ));
    }

    // iso2s that have at least one large polygon — used to exclude sub-island dots
    // (e.g. Spain's Canary Islands feature has the same iso2 as mainland Spain)
    _largeIso2s = _geoFeatures
        .where((f) => !f.smallIsland && f.iso2.isNotEmpty)
        .map((f) => f.iso2)
        .toSet();

    // Continent iso2 set for dim-coloring and tap-blocking
    Set<String>? continentIso2s;
    if (widget.continent != null) {
      continentIso2s = countries
          .where((c) => c.region == widget.continent)
          .map((c) => c.iso2)
          .toSet();
      final v = _kContinentCenter[widget.continent!];
      if (v != null) {
        _mapInitCenter = LatLng(v.$1, v.$2);
        _mapInitZoom = v.$3;
      }
    }
    _continentIso2s = continentIso2s;

    _basePolygons = _geoFeatures
        .expand((f) {
          return f.rings.map((r) {
            bool dim;
            if (continentIso2s == null) {
              dim = false;
            } else if (!continentIso2s.contains(f.iso2)) {
              dim = true;
            } else {
              // Country is in continent — but check if this ring is geographically
              // inside the continent (filters out overseas territories like French Guiana).
              final lat = r.fold(0.0, (s, p) => s + p.latitude) / r.length;
              final lon = r.fold(0.0, (s, p) => s + p.longitude) / r.length;
              dim = !_inContinentBounds(LatLng(lat, lon));
            }
            return Polygon(
              points: r,
              color: (dim ? _cLandDim : _cLand).withValues(alpha: 0.92),
              borderColor: dim ? _cBorderDim : _cBorder,
              borderStrokeWidth: 0.9,
            );
          });
        })
        .toList();

    final geoSet = _geoFeatures.map((f) => f.iso2).toSet();
    final pool = countries
        .where((c) => geoSet.contains(c.iso2) &&
            (widget.continent == null || c.region == widget.continent))
        .toList()
      ..shuffle(Random());
    _questions = pool.take(widget.questionCount).toList();

    if (mounted) {
      setState(() {
        _totalQ = _questions.length;
        _loading = false;
      });
    }
  }

  List<LatLng> _ring(List coords) => coords.map((p) {
        final pt = p as List;
        return LatLng((pt[1] as num).toDouble(), (pt[0] as num).toDouble());
      }).toList();

  // ─── Mercator helpers for cursor-aware scroll-wheel zoom ──────────────────
  //
  // Standard Web-Mercator (EPSG:3857):
  //   world size at zoom z = 256 · 2^z pixels
  //   X increases east, Y increases south (screen convention)

  double _ws(double z) => 256.0 * pow(2.0, z);

  double _lngToX(double lng, double ws) => (lng + 180) / 360 * ws;

  double _latToY(double lat, double ws) {
    final s = sin(lat * pi / 180);
    return (0.5 - log((1 + s) / (1 - s)) / (4 * pi)) * ws;
  }

  double _xToLng(double x, double ws) => x / ws * 360 - 180;

  double _yToLat(double y, double ws) {
    final n = pi - 2 * pi * y / ws;
    return 180 / pi * atan(0.5 * (exp(n) - exp(-n)));
  }

  /// LatLng at screen pixel offset (dx, dy) from the map's visible centre.
  LatLng _screenToLatLng(LatLng center, double zoom, double dx, double dy) {
    final ws = _ws(zoom);
    return LatLng(
      _yToLat(_latToY(center.latitude, ws) + dy, ws),
      _xToLng(_lngToX(center.longitude, ws) + dx, ws),
    );
  }

  // Maximum center longitude such that the viewport edge never exceeds ±180°.
  //   halfViewportLon = (screenWidth/2) / worldPixelWidth * 360°
  //   maxCenterLon    = 180° − halfViewportLon   (≥ 0)
  double _maxCenterLon(double screenWidth, double zoom) =>
      (180.0 - (screenWidth / 2) / _ws(zoom) * 360.0).clamp(0.0, 180.0);

  // Called on every camera change (drag, fling, etc.).
  // Snaps the center back if a drag would show the second world copy.
  void _onPositionChanged(MapCamera camera, bool _) {
    final box = _listenerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final maxLon = _maxCenterLon(box.size.width, camera.zoom);
    final clampedLon =
        camera.center.longitude.clamp(-maxLon, maxLon);
    if ((clampedLon - camera.center.longitude).abs() > 0.001) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapCtrl.move(
            LatLng(camera.center.latitude, clampedLon),
            camera.zoom,
          );
        }
      });
    }
  }

  // ─── Tap / scoring ─────────────────────────────────────────────────────────

  void _onTap(TapPosition _, LatLng pt) {
    if (_answered) return;

    // PIP hit test
    String? hit;
    for (final f in _geoFeatures) {
      for (final ring in f.rings) {
        if (_pip(pt, ring)) { hit = f.iso2; break; }
      }
      if (hit != null) break;
    }
    // Small-island enlargement (100 km radius around centroid)
    if (hit == null) {
      _GeoFeature? best;
      double bestDist = 100.0;
      for (final f in _geoFeatures) {
        if (!f.smallIsland) continue;
        if (_continentIso2s != null && !_continentIso2s!.contains(f.iso2)) continue;
        final d = _haversine(pt, f.centroid);
        if (d < bestDist) { bestDist = d; best = f; }
      }
      if (best != null) hit = best.iso2;
    }
    // Ocean snap: find absolute nearest country by centroid
    if (hit == null) {
      _GeoFeature? nearest;
      double nearestDist = double.infinity;
      for (final f in _geoFeatures) {
        if (f.iso2.isEmpty) continue;
        if (_continentIso2s != null && !_continentIso2s!.contains(f.iso2)) continue;
        final d = _haversine(pt, f.centroid);
        if (d < nearestDist) { nearestDist = d; nearest = f; }
      }
      if (nearest != null) hit = nearest.iso2;
    }
    // Ignore dimmed (non-continent) taps
    if (_continentIso2s != null && hit != null && !_continentIso2s!.contains(hit)) return;
    if (hit == null) return;

    _handleHit(hit, pt);
  }

  void _handleHit(String iso2, LatLng tapPt) {
    if (_answered) return;
    if (_continentIso2s != null && !_continentIso2s!.contains(iso2)) return;

    final country = _questions[_current];

    // ── Already waiting for correct answer after a wrong guess ───────────────
    if (_waitingForCorrect) {
      if (iso2 == country.iso2) {
        _stopBlink();
        _countryAnswers[country.iso2] = true;
        _wrongFirst.add(country.iso2); // found after wrong guess → shown red
        setState(() {
          _waitingForCorrect = false;
          _answered = true;
        });
        Future.delayed(const Duration(milliseconds: 700), _next);
      }
      // Wrong taps during blink are silently ignored — only the target counts
      return;
    }

    // ── First tap ────────────────────────────────────────────────────────────
    final correct = iso2 == country.iso2;
    _countryAnswers[country.iso2] = correct;

    if (correct) {
      final dist = _haversine(tapPt, LatLng(country.latitude, country.longitude));
      final pts  = _calcPoints(dist, true);
      setState(() {
        _answered    = true;
        _totalScore += pts;
      });
      Future.delayed(const Duration(milliseconds: 900), _next);
    } else {
      setState(() => _waitingForCorrect = true);
      _startBlink();
    }
  }

  void _startBlink() {
    _blinkTimer?.cancel();
    _blinkOn = true;
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (mounted) setState(() => _blinkOn = !_blinkOn);
    });
  }

  void _stopBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    _blinkOn = false;
  }

  // Returns true if pt is within the continent's geographic bounding box.
  // Used to exclude overseas-territory rings from highlight/dim logic.
  bool _inContinentBounds(LatLng pt) {
    if (widget.continent == null) return true;
    final b = _kContinentBounds[widget.continent!];
    if (b == null) return true; // Ozeanien or unknown → no geo filter
    return pt.latitude >= b.$1 && pt.longitude >= b.$2 &&
           pt.latitude <= b.$3 && pt.longitude <= b.$4;
  }

  bool _pip(LatLng p, List<LatLng> poly) {
    bool inside = false;
    int j = poly.length - 1;
    for (int i = 0; i < poly.length; i++) {
      final xi = poly[i].longitude, yi = poly[i].latitude;
      final xj = poly[j].longitude, yj = poly[j].latitude;
      if (((yi > p.latitude) != (yj > p.latitude)) &&
          p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final s = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * pi / 180) *
            cos(b.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(s), sqrt(1 - s));
  }

  int _calcPoints(double km, bool onTarget) {
    if (onTarget || km < 50) return 1000;
    if (km < 200) return 850;
    if (km < 500) return 650;
    if (km < 1000) return 450;
    if (km < 2000) return 250;
    if (km < 4000) return 100;
    return 0;
  }

  void _next() {
    _stopBlink();
    if (_current + 1 >= _totalQ) {
      StatsService.saveResult(category: 'map', isDaily: widget.isDaily, score: _totalScore, total: _totalQ * 1000);
      if (!widget.isDaily) {
        StatsService.saveCountryAnswers(category: 'map', answers: Map.of(_countryAnswers));
        StatsService.saveLernenDoneToday('map');
      }
      setState(() => _finished = true);
    } else {
      setState(() {
        _current++;
        _answered = false;
        _waitingForCorrect = false;
      });
    }
  }

  void _changeZoom(double delta) {
    final z = (_mapCtrl.camera.zoom + delta).clamp(_dynMinZoom, _maxZ);
    _mapCtrl.move(_mapCtrl.camera.center, z);
  }

  // ─── Hover (desktop mouse) ─────────────────────────────────────────────────

  void _updateHover(PointerHoverEvent event) {
    if (_loading || _answered || _waitingForCorrect) return;
    final box = _listenerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final cam = _mapCtrl.camera;
    final sz = box.size;
    final dx = event.localPosition.dx - sz.width / 2;
    final dy = event.localPosition.dy - sz.height / 2;
    final pt = _screenToLatLng(cam.center, cam.zoom, dx, dy);

    String? hit;
    for (final f in _geoFeatures) {
      if (_continentIso2s != null && !_continentIso2s!.contains(f.iso2)) continue;
      for (final ring in f.rings) {
        if (_pip(pt, ring)) { hit = f.iso2; break; }
      }
      if (hit != null) break;
    }
    if (hit != _hoveredIso2) setState(() => _hoveredIso2 = hit);
  }

  List<Polygon> _hoverPolygons() {
    if (_hoveredIso2 == null) return [];
    return _geoFeatures
        .where((f) => f.iso2 == _hoveredIso2)
        .expand((f) => f.rings
            .where((r) {
              final lat = r.fold(0.0, (s, p) => s + p.latitude) / r.length;
              final lon = r.fold(0.0, (s, p) => s + p.longitude) / r.length;
              return _inContinentBounds(LatLng(lat, lon));
            })
            .map((r) => Polygon(
                  points: r,
                  color: _cLandHover.withValues(alpha: 0.92),
                  borderColor: _cBorder,
                  borderStrokeWidth: 0.9,
                )))
        .toList();
  }

  // ─── Highlight polygons ────────────────────────────────────────────────────

  List<Polygon> _highlights() {
    if (_countryAnswers.isEmpty && !_answered && !_waitingForCorrect) return [];
    final targetIso2 = _questions[_current].iso2;
    final List<Polygon> out = [];
    for (final f in _geoFeatures) {
      Color? fill;
      Color border = Colors.transparent;
      double bw = 0;
      // White: answered correctly on the FIRST try
      if (_countryAnswers[f.iso2] == true && !_wrongFirst.contains(f.iso2)) {
        fill = Colors.white;
        border = const Color(0xFF888888);
        bw = 2.0;
      }
      // Red: found only after a wrong first guess — stays red permanently
      else if (_wrongFirst.contains(f.iso2)) {
        fill = _cRed;
        border = _cRedBorder;
        bw = 2.0;
      }
      // Target blinks RED when wrong answer was given — shows player where to click
      else if (_waitingForCorrect && f.iso2 == targetIso2) {
        fill = _blinkOn ? _cRed : Colors.transparent;
        border = _blinkOn ? _cRedBorder : Colors.transparent;
        bw = _blinkOn ? 2.0 : 0;
      }
      if (fill != null && fill != Colors.transparent) {
        for (final r in f.rings) {
          final lat = r.fold(0.0, (s, p) => s + p.latitude) / r.length;
          final lon = r.fold(0.0, (s, p) => s + p.longitude) / r.length;
          if (!_inContinentBounds(LatLng(lat, lon))) continue;
          out.add(Polygon(
              points: r,
              color: fill,
              borderColor: border,
              borderStrokeWidth: bw));
        }
      }
    }
    return out;
  }

  List<Marker> _smallIslandMarkers() {
    final knownIso2s = countries.map((c) => c.iso2).toSet();
    final targetIso2 = _questions.isNotEmpty && _current < _questions.length
        ? _questions[_current].iso2
        : null;

    return _geoFeatures
        .where((f) => f.smallIsland && f.iso2.isNotEmpty)
        // Only quiz countries (no overseas territory sub-polygons)
        .where((f) => knownIso2s.contains(f.iso2))
        // Exclude sub-island features of countries that also have a large polygon
        // (e.g. Spain's Canary Islands share iso2 "ES" with mainland Spain)
        .where((f) => !_largeIso2s.contains(f.iso2))
        .where((f) => _continentIso2s == null || _continentIso2s!.contains(f.iso2))
        .map((f) {
          final isTarget = f.iso2 == targetIso2;
          final isWrongFirst = _wrongFirst.contains(f.iso2);
          final isCorrect = _countryAnswers[f.iso2] == true && !isWrongFirst;
          final blinkRed = _waitingForCorrect && isTarget && _blinkOn;
          final isHovered = _hoveredDotIso2 == f.iso2;

          Color dotColor;
          Color borderCol;
          if (isCorrect) {
            dotColor = Colors.white;
            borderCol = const Color(0xFF555555);
          } else if (isWrongFirst) {
            dotColor = _cRed;
            borderCol = _cRedBorder;
          } else if (blinkRed) {
            dotColor = _cRed;
            borderCol = _cRedBorder;
          } else if (isHovered) {
            dotColor = const Color(0xFFBBBBBB);
            borderCol = const Color(0xFF444444);
          } else {
            dotColor = Colors.white;
            borderCol = const Color(0xFF555555);
          }

          return Marker(
            point: f.centroid,
            width: 22,
            height: 22,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoveredDotIso2 = f.iso2),
              onExit: (_) => setState(() => _hoveredDotIso2 = null),
              child: GestureDetector(
                onTap: () => _handleHit(f.iso2, f.centroid),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: Border.all(color: borderCol, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.40), blurRadius: 3)],
                  ),
                  margin: const EdgeInsets.all(6),
                ),
              ),
            ),
          );
        })
        .toList();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cOcean,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(t('Karte meistern'),
            style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (!_loading && !_finished)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(t('{n} Pkt.', {'n': '$_totalScore'}),
                    style: const TextStyle(
                        color: Color(0xFF4A9E4A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : _finished
              ? _buildResult()
              : _buildQuiz(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 16),
        Text(t('Weltkarte wird geladen…'),
            style:
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildQuiz() {
    return Column(children: [
      _buildHeader(),
      Expanded(child: _buildMapStack()),
      if (_waitingForCorrect) _buildWrongHint(),
    ]);
  }

  Widget _buildMapStack() {
    // LayoutBuilder gives us the actual pixel width of the map area.
    // We use it to compute the minimum zoom at which the world exactly fills
    // the viewport — at this zoom the world is never narrower than the screen,
    // so the user can never scroll sideways to see a second copy of the world.
    //
    // Mercator world width at zoom z = 256 · 2^z  pixels
    // → minZoom = log₂(viewportWidth / 256)
    return LayoutBuilder(builder: (context, constraints) {
      _dynMinZoom = (log(constraints.maxWidth / 256) / log(2))
          .clamp(1.5, 4.0);

      return MouseRegion(
        onHover: _updateHover,
        onExit: (_) { if (_hoveredIso2 != null) setState(() => _hoveredIso2 = null); },
        child: Listener(
        key: _listenerKey,
        child: Stack(children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _mapInitCenter,
              initialZoom: max(_dynMinZoom, _mapInitZoom ?? _dynMinZoom),
              minZoom: _dynMinZoom,
              maxZoom: _maxZ,
              onTap: _onTap,
              onPositionChanged: _onPositionChanged,
              backgroundColor: _cOcean,
              cameraConstraint: CameraConstraint.containCenter(
                bounds: LatLngBounds(
                  const LatLng(-60, -180),
                  const LatLng(80, 180),
                ),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.pinchMove |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.doubleTapDragZoom |
                    InteractiveFlag.flingAnimation |
                    InteractiveFlag.scrollWheelZoom,
              ),
            ),
            children: [
              PolygonLayer(polygons: _basePolygons),
              if (!_answered && !_waitingForCorrect) PolygonLayer(polygons: _hoverPolygons()),
              PolygonLayer(polygons: _highlights()),
              MarkerLayer(markers: _smallIslandMarkers()),
            ],
          ),

          // +/− buttons: drive zoom via MapController regardless of pointer routing
          Positioned(
            right: 12,
            bottom: 16,
            child: Column(children: [
              _ZoomButton(icon: Icons.add, onTap: () => _changeZoom(1.0)),
              const SizedBox(height: 6),
              _ZoomButton(icon: Icons.remove, onTap: () => _changeZoom(-1.0)),
            ]),
          ),
        ]),
      ),  // Listener
      );  // MouseRegion
    });
  }

  Widget _buildHeader() {
    final country = _questions[_current];
    return Container(
      color: const Color(0xFFF5F5F0),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(children: [
        _totalQ <= 25
            ? Row(
                children: List.generate(_totalQ, (i) {
                  final c = i < _current
                      ? const Color(0xFF4A9E4A)
                      : i == _current
                          ? const Color(0xFFF9A825)
                          : const Color(0xFFD0D0CB);
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 4,
                      decoration: BoxDecoration(
                          color: c, borderRadius: BorderRadius.circular(2)),
                    ),
                  );
                }),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: _totalQ > 0 ? _current / _totalQ : 0,
                  backgroundColor: const Color(0xFFD0D0CB),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF4A9E4A)),
                  minHeight: 4,
                ),
              ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(country.flagEmoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(t('Wo liegt {land}?', {'land': country.name}),
                style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        if (!_answered && !_waitingForCorrect)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                t('Tippe auf die Karte  ·  Scrollrad oder +/− zum Zoomen'),
                style: const TextStyle(color: Color(0xFF999999), fontSize: 11)),
          ),
      ]),
    );
  }

  Widget _buildWrongHint() {
    final country = _questions[_current];
    return Container(
      color: const Color(0xFFF5F5F0),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(children: [
        const Text('❌', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Falsch! Finde das richtige Land.'),
                style: const TextStyle(color: Color(0xFFC62828), fontSize: 13, fontWeight: FontWeight.w700)),
            Text('${country.flagEmoji} ${t('Wo liegt {land}?', {'land': country.name})}',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildResult() {
    final maxPossible = _totalQ * 1000;
    final pct = (_totalScore / maxPossible * 100).round();
    final emoji = pct >= 80 ? '🏆' : pct >= 50 ? '🗺️' : '📚';
    final grade = pct >= 80
        ? t('Karten-Experte!')
        : pct >= 50
            ? t('Gut gemacht!')
            : t('Weiter üben!');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Spacer(),
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(grade,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(t('{score} / {max} Punkte', {'score': '$_totalScore', 'max': '$maxPossible'}),
              style: const TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 32),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Center(
              child: Text('$pct%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const Spacer(),
          if (!widget.isDaily)
            GestureDetector(
              onTap: _restart,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(t('Nochmal spielen'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          if (!widget.isDaily) const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(t('Zurück'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _restart() {
    final geoSet = _geoFeatures.map((f) => f.iso2).toSet();
    final pool = countries
        .where((c) => geoSet.contains(c.iso2) &&
            (widget.continent == null || c.region == widget.continent))
        .toList()
      ..shuffle(Random());
    _stopBlink();
    _countryAnswers = {};
    _wrongFirst = {};
    _hoveredDotIso2 = null;
    setState(() {
      _questions = pool.take(widget.questionCount).toList();
      _totalQ = _questions.length;
      _current = 0;
      _totalScore = 0;
      _finished = false;
      _answered = false;
      _waitingForCorrect = false;
    });
  }
}

// ─── Zoom button ──────────────────────────────────────────────────────────────

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF1B5E20), size: 22),
      ),
    );
  }
}

// ─── Tap marker ───────────────────────────────────────────────────────────────
// Bullseye: outer ring + centre dot, both perfectly centred.
// ─── Data model ───────────────────────────────────────────────────────────────

class _GeoFeature {
  final String iso2, name;
  final List<List<LatLng>> rings;
  final LatLng centroid;     // average of first ring, used for small-island fallback
  final bool smallIsland;    // bbox < 0.3 deg² → needs enlarged hit-area
  const _GeoFeature({
    required this.iso2,
    required this.name,
    required this.rings,
    required this.centroid,
    required this.smallIsland,
  });
}
