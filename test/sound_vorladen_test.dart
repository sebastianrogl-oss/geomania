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

    test('Die Sitzung wird beim Laden eingerichtet und aktiviert', () {
      expect(ab, greaterThan(0));
      expect(dienst.contains('await _sitzungAnschieben();'), isTrue);
      // AUSDRÜCKLICH, nicht als Nebenwirkung. Der Versuch aus Build 22 ging
      // über onSoundComplete() im Plugin und half am Gerät nicht.
      expect(rumpf.contains('s.configure('), isTrue,
          reason: 'Die Sitzung wird nicht eingerichtet');
      expect(rumpf.contains('s.setActive(true)'), isTrue,
          reason: 'Ohne setActive bleibt es beim alten Verhalten');
      final einrichten = rumpf.indexOf('s.configure(');
      expect(einrichten, lessThan(rumpf.indexOf('s.setActive(true)')),
          reason: 'Aktiviert wird eine Sitzung, deren Kategorie schon steht');
    });

    test('Die Kategorie bleibt ambient', () {
      // Sie mischt sich unter fremde Musik UND schweigt beim Stummschalter.
      // playback täte beides nicht.
      expect(rumpf.contains('AVAudioSessionCategory.ambient'), isTrue);
    });

    test('Genau einmal, und nur auf iOS', () {
      // Auf Android wäre setActive(true) eine Anforderung des Audio-Fokus —
      // genau das, was hier nicht passieren soll (audioFocus none, damit
      // fremde Musik unverändert weiterläuft).
      expect(rumpf.contains('!Platform.isIOS || _sitzungAngeschoben'), isTrue);
      expect(rumpf.contains('_sitzungAngeschoben = true;'), isTrue);
    });

    test('Ein Fehlschlag hält das Laden nicht auf', () {
      expect(rumpf.contains('catch (e)'), isTrue,
          reason: 'Ohne aktive Sitzung soll es beim alten Verhalten bleiben, '
              'nicht beim gar keinen Ton');
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
