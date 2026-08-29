import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/services/profilbild_service.dart';

/// Coiny und Globus werden als Profilbild vergrössert in ihren Kreis gesetzt
/// ([ProfilbildService.kWeitformatFaktor]). Das geht nur auf, solange die
/// Figur dabei im Kreis bleibt — sonst schneidet das ClipOval ihr die Hand
/// oder die Füsse ab.
///
/// Der Test misst die sichtbaren Bildpunkte aus den Dateien nach und rechnet
/// die Darstellung durch: BoxFit.contain in einem Quadrat, dann die
/// Vergrösserung um den Mittelpunkt, dann der Kreis. Wer die Bilder
/// austauscht oder den Faktor erhöht, bekommt hier einen Fehlschlag statt
/// einer beschnittenen Figur auf dem Gerät.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dateien = [
    'coin_normal',
    'coin_winken',
    'coin_denken',
    'coin_ueberrascht',
    'globus_normal',
    'globus_winken',
    'globus_denken',
    'globus_ueberrascht',
  ];

  for (final datei in dateien) {
    test('$datei bleibt im Kreis', () async {
      final roh = await rootBundle.load('assets/icons/deko/$datei.png');
      final codec = await ui.instantiateImageCodec(roh.buffer.asUint8List());
      final bild = (await codec.getNextFrame()).image;
      final daten = await bild.toByteData(format: ui.ImageByteFormat.rawRgba);

      // Die Vergrösserung, bei der die Figur den Kreis zum ersten Mal
      // verlässt: der kleinste Abstand-Kehrwert über alle sichtbaren Punkte.
      //
      // Gerechnet im Einheitsquadrat des Kreises. BoxFit.contain legt das
      // 677x369-Bild auf die volle Breite und lässt oben und unten Rand;
      // Transform.scale dehnt anschliessend um den Mittelpunkt (0,5 / 0,5),
      // und der Kreis hat den Radius 0,5.
      final hoehenAnteil = bild.height / bild.width;
      var grenze = double.infinity;
      for (var y = 0; y < bild.height; y++) {
        for (var x = 0; x < bild.width; x++) {
          final alpha = daten!.getUint8((y * bild.width + x) * 4 + 3);
          if (alpha <= 8) continue;
          final dx = (x + 0.5) / bild.width - 0.5;
          final dy = ((y + 0.5) / bild.height - 0.5) * hoehenAnteil;
          final r = (dx * dx + dy * dy);
          if (r <= 0) continue;
          final maxFaktor = 0.5 / (r <= 0 ? 1e-9 : _wurzel(r));
          if (maxFaktor < grenze) grenze = maxFaktor;
        }
      }

      // ignore: avoid_print
      print('$datei: bleibt bis Faktor ${grenze.toStringAsFixed(2)} im Kreis '
          '(gesetzt: ${ProfilbildService.kWeitformatFaktor})');

      expect(ProfilbildService.kWeitformatFaktor, lessThan(grenze),
          reason: '$datei würde bei Faktor '
              '${ProfilbildService.kWeitformatFaktor} angeschnitten — '
              'die Figur bleibt nur bis ${grenze.toStringAsFixed(2)} im Kreis');
    });
  }
}

double _wurzel(double x) {
  var r = x;
  for (var i = 0; i < 40; i++) {
    r = 0.5 * (r + x / r);
  }
  return r;
}
