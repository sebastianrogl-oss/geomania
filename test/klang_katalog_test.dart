import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/services/sound_service.dart';

// ── Der Klang-Katalog ────────────────────────────────────────────────────────
//
// [Klang] trägt drei Angaben je Effekt: Datei, Zahl der Spieler und gemessene
// Länge. Die Länge ist keine Dokumentation — [SoundService] rechnet mit ihr:
// Nach `laenge + Nachlauf` wird der Spieler zurückgesetzt und ist erst dann
// wieder startbereit. Eine zu kurz eingetragene Länge schneidet den Klang ab,
// eine zu lange blockiert den Spieler unnötig.
//
// Geprüft wird deshalb gegen die Dateien selbst, soweit das ohne Audio-Stack
// geht: dass sie da sind, und dass die Angabe zur Datei passt (bei WAV lässt
// sich die Dauer aus dem Kopf ausrechnen).

/// Dauer einer unkomprimierten WAV-Datei aus ihrem Kopf.
///
/// Nur die zwei Felder, die dafür nötig sind: Byte-Rate an Offset 28 und die
/// Grösse des data-Blocks. Reicht für die eine WAV-Datei im Katalog und
/// erspart eine Abhängigkeit.
Duration? _wavDauer(File f) {
  final b = f.readAsBytesSync();
  if (b.length < 44) return null;
  if (String.fromCharCodes(b.sublist(0, 4)) != 'RIFF') return null;
  int le32(int o) => b[o] | b[o + 1] << 8 | b[o + 2] << 16 | b[o + 3] << 24;
  final byteRate = le32(28);
  if (byteRate == 0) return null;
  // data-Block suchen; vor ihm können weitere Blöcke stehen.
  var o = 12;
  while (o + 8 <= b.length) {
    final id = String.fromCharCodes(b.sublist(o, o + 4));
    final groesse = le32(o + 4);
    if (id == 'data') {
      return Duration(microseconds: (groesse * 1000000 / byteRate).round());
    }
    o += 8 + groesse + (groesse.isOdd ? 1 : 0);
  }
  return null;
}

void main() {
  group('Jeder Klang', () {
    for (final k in Klang.values) {
      test('${k.name}: Datei liegt in assets/sounds', () {
        expect(File('assets/sounds/${k.datei}').existsSync(), isTrue,
            reason: '${k.datei} fehlt — der Effekt fiele stumm aus');
      });

      test('${k.name}: Länge und Spielerzahl sind gesetzt', () {
        expect(k.laenge, greaterThan(Duration.zero),
            reason: 'ohne Länge wird der Spieler sofort zurückgesetzt');
        expect(k.spieler, greaterThanOrEqualTo(1));
      });
    }
  });

  test('Die Dateinamen sind klein geschrieben', () {
    // Android-Assets sind gross-/kleinschreibungsempfindlich. Zwei Dateien
    // lagen schon einmal als .MP3 im Ordner und wurden auf dem Gerät nie
    // geladen, während sie unter Windows im Test durchliefen.
    for (final k in Klang.values) {
      expect(k.datei, k.datei.toLowerCase(), reason: '${k.datei} hat Grossbuchstaben');
    }
  });

  test('Die Rastung nutzt WAV, nicht MP3', () {
    // Der Grund steht ausführlich am Enum: MP3 bringt rund 50 ms
    // Encoder-Stille an den Anfang, und das ist bei einem 32-ms-Klick fast
    // die doppelte Länge des Klangs selbst.
    expect(Klang.blopp.datei, endsWith('.wav'));
  });

  test('Die eingetragene Länge der WAV-Datei stimmt mit der Datei überein',
      () {
    final gemessen = _wavDauer(File('assets/sounds/${Klang.blopp.datei}'));
    expect(gemessen, isNotNull, reason: 'WAV-Kopf nicht lesbar');
    expect(
      (gemessen!.inMilliseconds - Klang.blopp.laenge.inMilliseconds).abs(),
      lessThanOrEqualTo(5),
      reason: 'Datei ist ${gemessen.inMilliseconds} ms lang, eingetragen sind '
          '${Klang.blopp.laenge.inMilliseconds} ms',
    );
  });

  group('Die Spielerzahl trägt den Auslöse-Rhythmus', () {
    // Ein Spieler ist rund `laenge` lang belegt. Bei n Spielern verkraftet
    // ein Klang also einen Auslöser alle `laenge / n`, ohne dass gewartet
    // werden muss. Für die beiden Klänge, die schnell hintereinander kommen
    // können, ist das hier festgehalten — sie sind der Grund für den Umbau
    // des Dienstes.

    test('knopf trägt vier Tipps je Sekunde', () {
      final abstand = Klang.knopf.laenge.inMilliseconds / Klang.knopf.spieler;
      expect(abstand, lessThanOrEqualTo(250),
          reason: 'Bei hektischem Tippen käme ein Tipp ins Warten');
    });

    test('richtig und falsch tragen eine Antwort alle 0,7 s', () {
      for (final k in [Klang.richtig, Klang.falsch]) {
        final abstand = k.laenge.inMilliseconds / k.spieler;
        expect(abstand, lessThanOrEqualTo(700),
            reason: '${k.name}: ${abstand.round()} ms zwischen zwei freien '
                'Spielern');
      }
    });

    test('wisch hat mehr als einen Spieler', () {
      // Stand auf 1 mit dem Vermerk „sehr kurz" — die Datei ist 1,07 s lang,
      // und in Higher or Lower folgen die Kartenwechsel dichter.
      expect(Klang.wisch.spieler, greaterThan(1));
    });
  });
}
