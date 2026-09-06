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
    // Aus dem TestFlight-Test (Build 20): Im ersten Level blieb es stumm, bis
    // der Halbzeit-Moment kam — ab da klang alles. In audioplayers_darwin
    // 6.5.0 gibt es genau eine Stelle, die AVAudioSession.setActive anfasst
    // (controlAudioSession), und genau einen Aufrufer dafür:
    // onSoundComplete(), also das natürliche ENDE eines Klangs. resume()
    // aktiviert nichts. Der erste Klang, der wirklich durchläuft, schaltet
    // die Sitzung scharf.
    final ab = dienst.indexOf('static Future<void> _sitzungAnschieben');
    final rumpf = ab < 0
        ? ''
        : dienst.substring(ab, dienst.indexOf('\n  static ', ab + 40));

    test('Es gibt einen Anstoss beim Laden', () {
      expect(ab, greaterThan(0),
          reason: 'Ohne ihn fällt alles bis zum ersten durchgelaufenen Klang '
              'in die stumme Phase');
      expect(dienst.contains('await _sitzungAnschieben();'), isTrue);
    });

    test('Der Klang läuft zu ENDE, statt sofort gestoppt zu werden', () {
      // Genau daran scheiterte der erste Anlauf: Ein gestoppter Klang meldet
      // kein Ende (AVPlayerItemDidPlayToEndTime bleibt aus), und ohne Ende
      // wird die Sitzung nie aktiviert. Derselbe Kreis wie im Spiel.
      expect(rumpf.contains('onPlayerComplete.first'), isTrue,
          reason: 'Der Anstoss wartet nicht auf das Ende — dann aktiviert er '
              'die Sitzung auch nicht');
      final abo = rumpf.indexOf('onPlayerComplete.first');
      final start = rumpf.indexOf('p.resume()');
      expect(abo, lessThan(start),
          reason: 'Bei 157 ms wäre das Ende durch, bevor jemand hinhört');
    });

    test('Er ist unhörbar und lässt die Lautstärke stehen', () {
      // _Klangspur.lautstaerken geht von 1.0 aus. Bliebe der Spieler nach
      // dem Anstoss auf 0, wäre er für immer stumm — und nichts würde es
      // melden, weil der Aufruf auf dem heissen Pfad ja gerade entfällt.
      expect(rumpf.indexOf('setVolume(0)'), greaterThan(0));
      expect(rumpf.indexOf('setVolume(1)'),
          greaterThan(rumpf.indexOf('setVolume(0)')));
    });

    test('Er hängt nicht, wenn das Ende ausbleibt', () {
      expect(rumpf.contains('onTimeout'), isTrue,
          reason: 'Ohne Notausgang bliebe das Laden daran stehen');
    });

    test('Genau einmal, und nur auf iOS', () {
      // Die Sitzung gilt für die ganze App — einer genügt. Auf Android läuft
      // lowLatency über SoundPool, ganz ohne Sitzung.
      expect(rumpf.contains('!Platform.isIOS || _sitzungAngeschoben'), isTrue);
      expect(rumpf.contains('_sitzungAngeschoben = true;'), isTrue);
    });

    test('Erst die Sitzung, dann das Nachreichen', () {
      // Ein nachgereichter Klang, der in die stumme Phase fällt, wäre für
      // den Spieler dasselbe wie gar keiner.
      final sitzung = dienst.indexOf('await _sitzungAnschieben();');
      final nachreichen = dienst.indexOf('_nachreichenAlle();');
      expect(sitzung, greaterThan(0));
      expect(sitzung, lessThan(nachreichen));
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
