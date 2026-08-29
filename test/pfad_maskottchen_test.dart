import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Coiny-Figuren am Rand des Lernpfads hängen bewusst über den
/// Bildschirmrand hinaus (siehe `_kCoinyNachAussen` in pfad_maskottchen.dart).
/// Das geht nur auf, solange der Überstand kleiner ist als der durchsichtige
/// Rand der Bilddatei — sonst würde die Figur beschnitten.
///
/// Der Test misst diesen Rand aus der Datei selbst, statt sich auf eine
/// abgeschriebene Zahl zu verlassen: Wer die Bilder austauscht, bekommt hier
/// einen Fehlschlag statt einer angeschnittenen Figur auf dem Gerät.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// So gross wird die Datei im Lernpfad gezeichnet (BoxFit.contain in einem
  /// quadratischen Kasten dieser Kantenlänge).
  const anzeigeGroesse = 264.6;

  /// So weit darf der Kasten über den Bildschirmrand hinausragen.
  const ueberstand = 30.0;

  const dateien = [
    'coin_normal',
    'coin_winken',
    'coin_denken',
    'coin_ueberrascht',
  ];

  for (final datei in dateien) {
    test('$datei: durchsichtiger Rand trägt den Überstand', () async {
      final roh = await rootBundle.load('assets/icons/deko/$datei.png');
      final codec = await ui.instantiateImageCodec(roh.buffer.asUint8List());
      final bild = (await codec.getNextFrame()).image;
      final daten =
          await bild.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(daten, isNotNull);

      // Erste und letzte Spalte, in der überhaupt etwas Sichtbares steht.
      var linkeKante = bild.width;
      var rechteKante = -1;
      for (var x = 0; x < bild.width; x++) {
        for (var y = 0; y < bild.height; y++) {
          final alpha = daten!.getUint8((y * bild.width + x) * 4 + 3);
          if (alpha > 8) {
            if (x < linkeKante) linkeKante = x;
            if (x > rechteKante) rechteKante = x;
            break;
          }
        }
      }
      expect(rechteKante, greaterThan(0), reason: '$datei ist ganz leer');

      // BoxFit.contain in einem Quadrat: Es zählt die längere Kante, hier die
      // Breite (die Dateien sind Querformat).
      final faktor = anzeigeGroesse /
          (bild.width > bild.height ? bild.width : bild.height);
      final randLinks = linkeKante * faktor;
      final randRechts = (bild.width - 1 - rechteKante) * faktor;

      expect(randLinks, greaterThan(ueberstand),
          reason: '$datei hat links nur ${randLinks.toStringAsFixed(1)} px '
              'durchsichtigen Rand — der Überstand von $ueberstand px würde '
              'die Figur anschneiden');
      expect(randRechts, greaterThan(ueberstand),
          reason: '$datei hat rechts nur ${randRechts.toStringAsFixed(1)} px '
              'durchsichtigen Rand — der Überstand von $ueberstand px würde '
              'die Figur anschneiden');

      // ignore: avoid_print
      print('$datei: ${bild.width}x${bild.height}, sichtbar von $linkeKante '
          'bis $rechteKante -> Rand links ${randLinks.toStringAsFixed(1)} px, '
          'rechts ${randRechts.toStringAsFixed(1)} px');
    });
  }
}
