import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/services/sound_service.dart';

/// Das Vorladen der Klangeffekte.
///
/// ══ WARUM ES DIESEN TEST GIBT ═══════════════════════════════════════════════
///
/// Gemeldet vom iPhone: Im ersten halben Level nach dem Start kommt kein Ton,
/// danach schon. Zwei Dinge trafen zusammen:
///
///   1. Ein Auslöser, dessen Klang noch nicht bereit war, wurde WORTLOS
///      verworfen — `if (spur == null) return;`. Kein Nachreichen, kein
///      Protokoll, nichts.
///   2. Auf iOS gibt es im Abspielweg von audioplayers_darwin kein
///      `AVAudioSession.setActive(true)`; jede Wiedergabe verlässt sich auf
///      die stillschweigende Aktivierung durch iOS, und die kommt nicht
///      sofort.
///
/// Der Ton selbst lässt sich im Test nicht abspielen — dafür braucht es das
/// Plugin und ein Gerät. Prüfbar ist aber, dass die Vorkehrungen dagegen im
/// Code stehen und nicht bei der nächsten Umbauaktion verschwinden.
void main() {
  final dienst = File('lib/services/sound_service.dart').readAsStringSync();
  final start = File('lib/main.dart').readAsStringSync();

  group('Reihenfolge des Ladens', () {
    test('Die Klänge des ersten halben Levels kommen zuerst', () {
      // Mehr passiert dort nicht: Knopfdruck beim Start der Station, danach
      // richtig und falsch. Sieg, Münze, Wisch und Blopp haben Zeit.
      expect(SoundService.zuerstGeladen,
          containsAll([Klang.knopf, Klang.richtig, Klang.falsch]));
    });

    test('Kein Klang wird doppelt oder gar nicht geladen', () {
      // Die zweite Runde lädt alles, was nicht in der ersten war. Steht ein
      // Klang doppelt in der Liste, legt er doppelt so viele Spieler an.
      expect(SoundService.zuerstGeladen.toSet().length,
          SoundService.zuerstGeladen.length,
          reason: 'Doppelter Eintrag in zuerstGeladen');
      for (final k in SoundService.zuerstGeladen) {
        expect(Klang.values, contains(k));
      }
    });
  });

  group('Auslöser vor dem Laden gehen nicht verloren', () {
    test('spiele() verwirft einen frühen Auslöser nicht mehr', () {
      // Das war der Kern: ein blankes return, wenn die Spur fehlt.
      expect(dienst.contains('if (!_geladen) _verpasst[klang]'), isTrue,
          reason: 'Ein Tipp in das Ladefenster fällt wieder stumm aus');
    });

    test('Nachgereicht wird nur kurz', () {
      // Ein Ton, der zwei Sekunden nach dem Tipp kommt, gehört zu nichts
      // mehr — er klingt dann nach einem Fehler statt nach einer
      // Rückmeldung.
      expect(SoundService.nachreichFenster.inSeconds, lessThanOrEqualTo(3));
      expect(SoundService.nachreichFenster, greaterThan(Duration.zero));
    });

    test('Nach dem Laden wird wieder verworfen', () {
      // Sonst sammelte sich alles an, was gar nicht ladbar war, und die
      // Wartezeit hätte kein Ende.
      expect(dienst.contains('_verpasst.clear()'), isTrue);
    });
  });

  group('Die iOS-Audio-Sitzung läuft vor dem ersten Tipp an', () {
    test('Jeder Spieler wird beim Laden lautlos angestossen', () {
      expect(dienst.contains('await _warmlaufen(p)'), isTrue,
          reason: 'Ohne Anlauf fällt der erste Ton in die Lücke, in der iOS '
              'die Audio-Sitzung noch hochfährt');
    });

    test('Der Anlauf ist unhörbar und lässt die Lautstärke stehen', () {
      // _Klangspur.lautstaerken geht von 1.0 aus. Bliebe der Spieler nach
      // dem Anlauf auf 0, wäre er für immer stumm — und nichts würde es
      // melden, weil der Aufruf auf dem heissen Pfad ja gerade entfällt.
      final ab = dienst.indexOf('static Future<void> _warmlaufen');
      expect(ab, greaterThan(0));
      final rumpf = dienst.substring(ab, dienst.indexOf('\n  static ', ab + 30));
      expect(rumpf.indexOf('setVolume(0)'), greaterThan(0));
      expect(rumpf.indexOf('setVolume(1)'),
          greaterThan(rumpf.indexOf('setVolume(0)')));
    });

    test('Nur auf iOS', () {
      // Auf Android läuft lowLatency über SoundPool, ganz ohne Audio-Sitzung
      // — und stop() ist dort der teuerste Aufruf im ganzen Ablauf.
      expect(dienst.contains('if (kIsWeb || !Platform.isIOS) return;'), isTrue);
    });
  });

  group('Geladen wird nach dem ersten Bild', () {
    test('Der Start wartet nicht mehr darauf', () {
      expect(start.contains('await SoundService.initialisieren()'), isFalse,
          reason: 'Sechzehn AVPlayer nacheinander, bevor etwas zu sehen ist');
    });

    test('Aber es wird angestossen', () {
      expect(start.contains('unawaited(SoundService.initialisieren())'), isTrue);
    });

    test('In einem eigenen Rückruf, nicht hinter der Werbe-Einwilligung', () {
      // Der Rückruf für die Werbung wartet auf das UMP-Formular und damit
      // unter Umständen auf eine Entscheidung des Nutzers. Der Ton hinge
      // dann hinter einem Dialog.
      final ton = start.indexOf('unawaited(SoundService.initialisieren())');
      final consent = start.indexOf('AdService.pruefeUndZeigeConsent');
      expect(ton, greaterThan(0));
      expect(consent, greaterThan(0));
      expect(ton, lessThan(consent),
          reason: 'Der Ton wird erst nach der Einwilligung geladen');
    });
  });
}
