import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// ── Kontinent-Karte mit gelernten Ländern ────────────────────────────────────
//
// Zeichnet die Länder EINES Kontinents als vereinfachte Polygone und färbt
// sie nach Lernstand. Die in der gerade gespielten Station neu dazugekommenen
// Länder leuchten nacheinander auf.

const _cNichtGelernt = Color(0xFFDDDAD2);
const _cNichtGelerntRand = Color(0xFFC4C1B9);
const _cFrueher = Color(0xFFA8C9A8);
const _cNeu = Color(0xFF4A9E4A);
const _cRand = Color(0xFF9E9C96);

/// Toleranz der Polygon-Vereinfachung in Grad (Douglas-Peucker).
///
/// 0.08° entspricht rund 8 km. Bei der vergrößerten Karte (bis 360px Höhe)
/// trägt diese Auflösung sichtbar: Italiens Stiefel, Skandinaviens Form und
/// die iberische Halbinsel bleiben eindeutig erkennbar. Die Vereinfachung
/// läuft einmalig beim Laden und wird gecacht — pro Frame wird nur noch
/// gezeichnet, die Rendering-Last hängt allein an der Punktzahl.
const kVereinfachungsToleranz = 0.08;

/// Länder, deren Polygone für die Kartendarstellung östlich eines
/// Längengrads abgeschnitten werden.
///
/// Russland reicht bis 190°E und würde die Europa-Karte so weit aufblähen,
/// dass vom eigentlichen Europa kaum etwas übrig bliebe. 60°E ist die
/// gängige Näherung für die Ostgrenze Europas (dahinter beginnt Sibirien).
///
/// Betrifft AUSSCHLIESSLICH diese Karte — die GeoJSON-Quelldaten und alle
/// anderen Verwendungen (Umriss-Quiz usw.) bleiben unberührt.
///
/// Türkei und Kasachstan stehen nicht in der Europa-Länderliste des
/// Lernpfads und brauchen deshalb keine Beschränkung.
const kOstgrenzen = <String, double>{
  'RU': 60.0,
};

/// Weit abliegende Außengebiete, die den sichtbaren Bereich aufblähen.
///
/// Anders als bei Russland wird hier NICHT geschnitten, sondern der ganze
/// Ring verworfen, wenn sein Schwerpunkt außerhalb liegt — es sind
/// eigenständige Inseln, kein zusammenhängendes Festland. Ein Schnitt würde
/// dort nur Artefakte erzeugen.
///
/// [nord] / [west] verstehen sich als Grenze des BEIBEHALTENEN Bereichs.
class Aussengrenze {
  final double? nord;
  final double? west;
  const Aussengrenze({this.nord, this.west});
}

const kAussengrenzen = <String, Aussengrenze>{
  // Svalbard liegt bei 76-80°N, das norwegische Festland endet bei ~71°N.
  'NO': Aussengrenze(nord: 71.5),
  // Azoren (-25 bis -31°W) und Madeira (-17°W); Festland endet bei ~-9.5°W.
  'PT': Aussengrenze(west: -12.0),
  // Kanaren (-13 bis -18°W, 27-29°N); Festland endet bei ~-9.3°W.
  'ES': Aussengrenze(west: -12.0),
};

/// Farbwechsel eines neu gelernten Landes. Mit der übrigen Schluss-Ansicht
/// um den Faktor 1.33 gestreckt.
const kAufleuchtenDauer = Duration(milliseconds: 530);
/// Kurzes Überstrahlen direkt zu Beginn des Farbwechsels.
const kGlowDauer = Duration(milliseconds: 265);
/// Zeitfenster, über das die neuen Länder verteilt aufleuchten. Der Versatz
/// ergibt sich daraus und der Anzahl — dadurch endet die Sequenz immer
/// ungefähr gleich, egal ob ein Land dazukam oder acht.
int versatzFuer(int anzahlNeu, int fensterMs) {
  if (anzahlNeu <= 1) return 0;
  final rest = fensterMs - kAufleuchtenDauer.inMilliseconds;
  // Obergrenze mitgestreckt (×1.33), damit sie bei wenigen Ländern nicht
  // vorzeitig greift und die Sequenz kürzer ausfällt als vorgesehen.
  return (rest / (anzahlNeu - 1)).round().clamp(0, 530);
}

/// Geladene und vereinfachte Polygone je ISO-Code.
typedef LaenderRinge = Map<String, List<List<Offset>>>;

class KontinentKartenDaten {
  /// Lädt die Umrisse der übergebenen Länder aus dem GeoJSON, filtert
  /// Kleinstinseln und vereinfacht die Polygone.
  ///
  /// Einmal geladen und gecacht — die Datei ist groß, und die Karte kann pro
  /// Sitzung mehrfach erscheinen.
  static LaenderRinge? _cache;
  static Set<String>? _cacheFuer;

  static Future<LaenderRinge> laden(Set<String> isoCodes) async {
    if (_cache != null && setEquals(_cacheFuer, isoCodes)) return _cache!;

    final raw =
        await rootBundle.loadString('assets/geo/ne_50m_countries.geojson');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final features = json['features'] as List;

    var punkteVorher = 0;
    var punkteNachher = 0;
    final ringe = <String, List<List<Offset>>>{};

    for (final f in features) {
      final props = f['properties'] as Map<String, dynamic>;
      final iso2Raw = props['ISO_A2'] as String? ?? '';
      final iso2 =
          iso2Raw == '-99' ? (props['ISO_A2_EH'] as String? ?? '') : iso2Raw;
      if (!isoCodes.contains(iso2)) continue;

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
      if (rs.isEmpty) continue;

      // Gleiche Filterung wie im Umriss-Quiz: Kleinstinseln und weit
      // entfernte Exklaven raus, damit die Bounding Box nicht verzerrt.
      var gefiltert = _filterRinge(rs);

      // Ostwärts ausufernde Länder beschneiden (siehe kOstgrenzen).
      final grenze = kOstgrenzen[iso2];
      if (grenze != null) {
        gefiltert = _beschneideOestlich(gefiltert, grenze);
      }
      // Abliegende Inselgruppen ganz verwerfen (siehe kAussengrenzen).
      final aussen = kAussengrenzen[iso2];
      if (aussen != null) {
        gefiltert = _ohneAussengebiete(gefiltert, aussen);
      }
      final vereinfacht = <List<Offset>>[];
      for (final r in gefiltert) {
        punkteVorher += r.length;
        final v = _vereinfache(r, kVereinfachungsToleranz);
        punkteNachher += v.length;
        // Unter 3 Punkten ist es keine Fläche mehr.
        if (v.length >= 3) vereinfacht.add(v);
      }
      if (vereinfacht.isNotEmpty) ringe[iso2] = vereinfacht;
    }

    if (kDebugMode) {
      debugPrint('[KontinentKarte] ${ringe.length} Länder geladen, '
          'Stützpunkte $punkteVorher -> $punkteNachher '
          '(Toleranz $kVereinfachungsToleranz)');
    }

    _cache = ringe;
    _cacheFuer = isoCodes;
    return ringe;
  }

  static List<Offset> _ring(List coords) => coords
      .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
      .toList();

  /// Behält nur Ringe, deren Bounding-Box-Fläche mindestens 10% der größten
  /// erreicht (übernommen aus outline_quiz_screen.dart).
  static List<List<Offset>> _filterRinge(List<List<Offset>> rs) {
    if (rs.length <= 1) return rs;
    double flaeche(List<Offset> r) {
      var minX = r[0].dx, maxX = r[0].dx, minY = r[0].dy, maxY = r[0].dy;
      for (final p in r) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      return (maxX - minX) * (maxY - minY);
    }

    final flaechen = rs.map(flaeche).toList();
    final maxF = flaechen.reduce(max);
    return [
      for (var i = 0; i < rs.length; i++)
        if (flaechen[i] >= maxF * 0.10) rs[i],
    ];
  }

  /// Verwirft ganze Ringe, deren Schwerpunkt jenseits der Grenze liegt.
  static List<List<Offset>> _ohneAussengebiete(
    List<List<Offset>> ringe,
    Aussengrenze grenze,
  ) {
    return ringe.where((r) {
      var summeX = 0.0, summeY = 0.0;
      for (final p in r) {
        summeX += p.dx;
        summeY += p.dy;
      }
      final mitteX = summeX / r.length;
      final mitteY = summeY / r.length;
      if (grenze.nord != null && mitteY > grenze.nord!) return false;
      if (grenze.west != null && mitteX < grenze.west!) return false;
      return true;
    }).toList();
  }

  /// Schneidet alle Punkte östlich von [grenze] ab und schließt das Polygon
  /// entlang des Längengrads.
  ///
  /// Statt Punkte einfach wegzuwerfen (was eine schräge, falsche Kante
  /// ergäbe) werden die Schnittpunkte mit dem Meridian interpoliert — die
  /// Ostkante verläuft dadurch sauber senkrecht.
  static List<List<Offset>> _beschneideOestlich(
    List<List<Offset>> ringe,
    double grenze,
  ) {
    final ergebnis = <List<Offset>>[];
    for (final ring in ringe) {
      final neu = <Offset>[];
      for (var i = 0; i < ring.length; i++) {
        final a = ring[i];
        final b = ring[(i + 1) % ring.length];
        final aDrin = a.dx <= grenze;
        final bDrin = b.dx <= grenze;

        if (aDrin) neu.add(a);
        // Kante quert den Meridian: Schnittpunkt einfügen.
        if (aDrin != bDrin && b.dx != a.dx) {
          final t = (grenze - a.dx) / (b.dx - a.dx);
          neu.add(Offset(grenze, a.dy + t * (b.dy - a.dy)));
        }
      }
      if (neu.length >= 3) ergebnis.add(neu);
    }
    return ergebnis;
  }

  /// Douglas-Peucker: behält die Punkte, die die Form tragen, und wirft alle
  /// weg, die weniger als [toleranz] von der Verbindungslinie abweichen.
  /// Bewusst kein simples "jeder n-te Punkt" — das würde markante Ecken
  /// genauso wegwerfen wie belanglose Küstenzacken.
  static List<Offset> _vereinfache(List<Offset> punkte, double toleranz) {
    if (punkte.length < 3) return punkte;

    double abstand(Offset p, Offset a, Offset b) {
      final dx = b.dx - a.dx;
      final dy = b.dy - a.dy;
      if (dx == 0 && dy == 0) return (p - a).distance;
      final t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / (dx * dx + dy * dy);
      final tk = t.clamp(0.0, 1.0);
      return (p - Offset(a.dx + tk * dx, a.dy + tk * dy)).distance;
    }

    List<Offset> rekursiv(List<Offset> pts) {
      if (pts.length < 3) return pts;
      var maxAbstand = 0.0;
      var index = 0;
      for (var i = 1; i < pts.length - 1; i++) {
        final d = abstand(pts[i], pts.first, pts.last);
        if (d > maxAbstand) {
          maxAbstand = d;
          index = i;
        }
      }
      if (maxAbstand <= toleranz) return [pts.first, pts.last];
      final links = rekursiv(pts.sublist(0, index + 1));
      final rechts = rekursiv(pts.sublist(index));
      return [...links.sublist(0, links.length - 1), ...rechts];
    }

    return rekursiv(punkte);
  }
}

class KontinentKarte extends StatefulWidget {
  final LaenderRinge ringe;
  /// Länder, die schon vor dieser Station gelernt waren.
  final Set<String> frueherGelernt;
  /// In dieser Station neu dazugekommen — leuchten nacheinander auf.
  final List<String> neuGelernt;
  /// Zeitfenster, über das sich die Aufleucht-Sequenz erstreckt.
  final int fensterMs;

  const KontinentKarte({
    super.key,
    required this.ringe,
    required this.frueherGelernt,
    required this.neuGelernt,
    required this.fensterMs,
  });

  @override
  State<KontinentKarte> createState() => _KontinentKarteState();
}

class _KontinentKarteState extends State<KontinentKarte>
    with SingleTickerProviderStateMixin {
  // EIN Controller für die ganze Sequenz; jedes Land bekommt daraus sein
  // eigenes Zeitfenster. Ein Controller pro Land wäre bei vielen Ländern
  // unnötig teuer.
  late final AnimationController _ctrl;

  int get _anzahlNeu => widget.neuGelernt.length;
  int get _versatz => versatzFuer(_anzahlNeu, widget.fensterMs);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.fensterMs),
    );
    if (_anzahlNeu > 0) _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Fortschritt eines neu gelernten Landes: 0 = noch grau, 1 = fertig grün.
  double _fortschritt(int index) {
    final gesamtMs = _ctrl.duration!.inMilliseconds;
    if (gesamtMs == 0) return 1;
    final msJetzt = _ctrl.value * gesamtMs;
    final start = index * _versatz;
    final t = (msJetzt - start) / kAufleuchtenDauer.inMilliseconds;
    return t.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final fortschritte = <String, double>{};
        for (var i = 0; i < _anzahlNeu; i++) {
          fortschritte[widget.neuGelernt[i]] = _fortschritt(i);
        }
        return CustomPaint(
          painter: _KontinentPainter(
            ringe: widget.ringe,
            frueherGelernt: widget.frueherGelernt,
            neuFortschritt: fortschritte,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _KontinentPainter extends CustomPainter {
  final LaenderRinge ringe;
  final Set<String> frueherGelernt;
  final Map<String, double> neuFortschritt;

  _KontinentPainter({
    required this.ringe,
    required this.frueherGelernt,
    required this.neuFortschritt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (ringe.isEmpty) return;

    // Bounding Box über alle Länder des Kontinents.
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final rs in ringe.values) {
      for (final r in rs) {
        for (final p in r) {
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }
      }
    }
    // Ein Längengrad ist nur auf dem Äquator so lang wie ein Breitengrad; auf
    // Europas Höhe (~54°N) schrumpft er auf gut die Hälfte. Ohne Korrektur
    // zieht eine reine Lat/Lon-Darstellung die Karte deshalb sichtbar in die
    // Breite. Der Faktor cos(mittlere Breite) stellt die Proportionen her.
    final mittlereBreite = (minY + maxY) / 2;
    final laengenFaktor = cos(mittlereBreite * pi / 180).abs().clamp(0.1, 1.0);

    final breite = (maxX - minX) * laengenFaktor;
    final hoehe = maxY - minY;
    if (breite <= 0 || hoehe <= 0) return;

    // EIN gemeinsamer Faktor für beide Achsen — der kleinere gewinnt, damit
    // der Kontinent in beide Richtungen passt und unverzerrt bleibt.
    final skala = min(size.width / breite, size.height / hoehe);
    final versatzX = (size.width - breite * skala) / 2;
    final versatzY = (size.height - hoehe * skala) / 2;

    Offset abbilden(Offset p) => Offset(
          versatzX + (p.dx - minX) * laengenFaktor * skala,
          // GeoJSON zählt die Breite nach oben, der Canvas nach unten.
          versatzY + (maxY - p.dy) * skala,
        );

    final randStift = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (final eintrag in ringe.entries) {
      final iso = eintrag.key;
      final pfad = Path();
      for (final r in eintrag.value) {
        if (r.length < 3) continue;
        pfad.moveTo(abbilden(r.first).dx, abbilden(r.first).dy);
        for (var i = 1; i < r.length; i++) {
          final p = abbilden(r[i]);
          pfad.lineTo(p.dx, p.dy);
        }
        pfad.close();
      }

      final (fuellung, rand) = _farben(iso);
      canvas.drawPath(pfad, Paint()..color = fuellung);
      canvas.drawPath(pfad, randStift..color = rand);
    }
  }

  (Color, Color) _farben(String iso) {
    final t = neuFortschritt[iso];
    if (t != null) {
      // Farbwechsel Grau -> kräftiges Grün, mit kurzem Überstrahlen zu
      // Beginn: in der ersten Hälfte des Glow-Fensters wird die Zielfarbe
      // aufgehellt und pendelt sich dann darauf ein.
      final basis = Color.lerp(_cNichtGelernt, _cNeu, t)!;
      final glowAnteil =
          kGlowDauer.inMilliseconds / kAufleuchtenDauer.inMilliseconds;
      final glow = t < glowAnteil ? sin(t / glowAnteil * pi) * 0.45 : 0.0;
      final farbe = glow > 0 ? Color.lerp(basis, Colors.white, glow)! : basis;
      return (farbe, _cRand);
    }
    if (frueherGelernt.contains(iso)) return (_cFrueher, _cRand);
    return (_cNichtGelernt, _cNichtGelerntRand);
  }

  @override
  bool shouldRepaint(_KontinentPainter alt) =>
      alt.neuFortschritt != neuFortschritt ||
      alt.frueherGelernt != frueherGelernt ||
      alt.ringe != ringe;
}
