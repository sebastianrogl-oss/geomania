import 'package:flutter/material.dart';

// ── Layout-Definitionen ───────────────────────────────────────────────────────
// a = Abschnitt-Index (0-basiert), s = Station-Index (0-basiert)
// links: true → Icon LINKS von Station | links: false → Icon RECHTS von Station

const _europaLayout = [
  (a: 0, s:  2, datei: 'europa_eiffelturm.png',  links: true),   // A1 S3
  (a: 0, s: 14, datei: 'europa_windmuehle.png',   links: false),  // A1 S15
  (a: 1, s:  6, datei: 'europa_bigben.png',        links: true),   // A2 S7
  (a: 1, s: 14, datei: 'europa_akropolis.png',     links: true),   // A2 S15
  (a: 2, s: 18, datei: 'europa_berlin.png',        links: true),   // A3 S19
  (a: 3, s:  6, datei: 'europa_stonehenge.png',    links: true),   // A4 S7
];

const _suedamLayout = [
  (a: 0, s:  2, datei: 'suedamerika_lama.png',      links: true),   // A1 S3
  (a: 0, s: 14, datei: 'suedamerika_palme.png',     links: false),  // A1 S15
  (a: 1, s:  6, datei: 'suedamerika_tukan.png',     links: true),   // A2 S7
  (a: 1, s: 14, datei: 'suedamerika_jaguar.png',    links: true),   // A2 S15
  (a: 2, s: 18, datei: 'suedamerika_tempel.png',    links: true),   // A3 S19
  (a: 3, s:  6, datei: 'suedamerika_dschungle.png', links: true),   // A4 S7
];

const _nordamLayout = [
  (a: 0, s:  2, datei: 'nordamerika_baer.png',          links: true),  // A1 S3
  (a: 0, s: 14, datei: 'nordamerika_kaktus.png',        links: false), // A1 S15
  (a: 1, s:  6, datei: 'nordamerika_mountain.png',      links: true),  // A2 S7
  (a: 1, s: 14, datei: 'nordamerika_adler.png',         links: true),  // A2 S15
  (a: 2, s: 18, datei: 'nordamerika_wolkenkratzer.png', links: true),  // A3 S19
  (a: 3, s:  6, datei: 'nordamerika_burger.png',        links: true),  // A4 S7
];

const _afrikaLayout = [
  (a: 0, s:  2, datei: 'afrika_pyramide.png', links: true),   // A1 S3
  (a: 0, s: 14, datei: 'afrika_elefant.png',  links: false),  // A1 S15
  (a: 1, s:  6, datei: 'afrika_giraffe.png',  links: true),   // A2 S7
  (a: 1, s: 14, datei: 'afrika_nashorn.png',  links: true),   // A2 S15
  (a: 2, s: 18, datei: 'afrika_baobab.png',   links: true),   // A3 S19
  (a: 3, s:  6, datei: 'afrika_afrika.png',   links: true),   // A4 S7
];

const _asienLayout = [
  (a: 0, s:  2, datei: 'asien_fuji.png',          links: true),   // A1 S3
  (a: 0, s: 14, datei: 'asien_panda.png',          links: false),  // A1 S15
  (a: 1, s:  6, datei: 'asien_kirschbluete.png',   links: true),   // A2 S7
  (a: 1, s: 14, datei: 'asien_reisfeld.png',       links: true),   // A2 S15
  (a: 2, s: 18, datei: 'asien_temple.png',          links: true),   // A3 S19
  (a: 3, s:  6, datei: 'asien_bambus.png',          links: true),   // A4 S7
];

const _ozeanienLayout = [
  (a: 0, s:  2, datei: 'ozeanien_kaenguru.png',  links: true),   // A1 S3
  (a: 0, s: 14, datei: 'ozeanien_koala.png',      links: false),  // A1 S15
  (a: 1, s:  6, datei: 'ozeanien_opernhaus.png',  links: true),   // A2 S7
  (a: 1, s: 14, datei: 'ozeanien_shark.png',      links: true),   // A2 S15
  (a: 2, s: 18, datei: 'ozeanien_welle.png',      links: true),   // A3 S19
  (a: 3, s:  6, datei: 'ozeanien_island.png',     links: true),   // A4 S7
];

const _weltLayout = [
  (a: 0, s:  2, datei: 'welt_globus.png',          links: true),   // A1 S3
  (a: 0, s: 14, datei: 'welt_flugzeug.png',        links: false),  // A1 S15
  (a: 1, s:  6, datei: 'welt_kompass.png',          links: true),   // A2 S7
  (a: 1, s: 14, datei: 'welt_rakete.png',           links: true),   // A2 S15
  (a: 2, s: 18, datei: 'welt_heißluftballon.png',   links: true),   // A3 S19
  (a: 3, s:  6, datei: 'welt_weltkarte.png',        links: true),   // A4 S7
];

// ── Rendering ─────────────────────────────────────────────────────────────────

const double _iconSizeEuropa = 94.5;  // 135 × 0,7
const double _iconSizeAndere = 75.6;  // 108 × 0,7
const double _btnRadius = 41.0;
const double _gap       = 130.0;      // 100 + 30

Widget _dekoImage(String datei, double left, double top, double size) => Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: Image.asset(
        'assets/icons/deko/$datei',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) {
          // ignore: avoid_print
          print('ICON FEHLER: $err');
          return const SizedBox.shrink();
        },
      ),
    );

// Alle Deko-Bilder außer dem Globus (welt_globus.png) rücken 50px näher an
// den Pfad heran (kleinerer Gap), damit in der Handyansicht (schmaler
// Screen) mehr Abstand zum Bildschirmrand bleibt. Globus bewusst
// ausgenommen — seine Position war bereits passend. Die Münze (siehe
// muenze_widget.dart) ist ein eigenständiges Widget außerhalb dieser Deko-
// Ebene und daher von dieser Verschiebung ohnehin nicht betroffen.
const double _gapVerschiebung = 50.0;

List<Widget> _layoutOverlays(
  List<({int a, int s, String datei, bool links})> layout,
  List<List<Offset>> stationenProAbschnitt,
  double screenWidth,
  double size,
) {
  final overlays = <Widget>[];
  for (final p in layout) {
    if (p.a >= stationenProAbschnitt.length) continue;
    final abschnitt = stationenProAbschnitt[p.a];
    if (p.s >= abschnitt.length) continue;
    final pos = abschnitt[p.s];
    final gap =
        p.datei == 'welt_globus.png' ? _gap : _gap - _gapVerschiebung;
    final double left = p.links
        ? (pos.dx - _btnRadius - gap - size).clamp(0.0, screenWidth - size)
        : (pos.dx + _btnRadius + gap).clamp(0.0, screenWidth - size);
    overlays.add(_dekoImage(p.datei, left, pos.dy - size / 2, size));
  }
  return overlays;
}

/// Alle Kontinente: feste Positionen identisch zu Europa (A1 S3/S15, A2 S7/S15, A3 S19, A4 S7).
/// Europa: 135px | Andere: 108px (20% kleiner).
List<Widget> pfadDekoOverlays({
  required String kontinentId,
  required List<Offset> allePositionen,
  List<List<Offset>> stationenProAbschnitt = const [],
  required double screenWidth,
}) {
  if (stationenProAbschnitt.isEmpty) return [];

  final (layout, size) = switch (kontinentId) {
    'europa'      => (_europaLayout,    _iconSizeEuropa),
    'suedamerika' => (_suedamLayout,    _iconSizeAndere),
    'nordamerika' => (_nordamLayout,    _iconSizeAndere),
    'afrika'      => (_afrikaLayout,    _iconSizeAndere),
    'asien'       => (_asienLayout,     _iconSizeAndere),
    'ozeanien'    => (_ozeanienLayout,  _iconSizeAndere),
    'welt'        => (_weltLayout,      _iconSizeAndere),
    _             => (_europaLayout,    _iconSizeEuropa),
  };

  return _layoutOverlays(layout, stationenProAbschnitt, screenWidth, size);
}
