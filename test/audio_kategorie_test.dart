import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/services/sound_service.dart';

/// Die Audio-Kategorie der App.
///
/// ══ WARUM ES DIESEN TEST GIBT ═══════════════════════════════════════════════
///
/// Die AVAudioSession ist EIN Zustand für die ganze App, und jedes Plugin darf
/// ihn anfassen. `video_player_avfoundation` tut das beim ersten Videoplayer:
/// Sein `initialize()` ruft `upgradeAudioSessionCategory` mit
/// `requestedCategory: .playback`, kommentiert mit "Allow audio playback when
/// the Ring/Silent switch is set to silent". Die Funktion hebt die Kategorie
/// nur AN und nimmt das nie zurück.
///
/// In GeoMania läuft so ein Video im Halbzeit-Moment und beim
/// Stationsabschluss — ab dem ersten überhörte die App den Stummschalter.
///
/// Am Gerät lässt sich das hier nicht nachstellen: Die Kategorie zu setzen
/// verlangt iOS, und `Platform.isIOS` ist auf dem Rechner falsch. Prüfbar ist
/// aber, dass die Rückstellung an der richtigen Stelle steht, dass sie kein
/// Video umgehen kann, und auf welche Kategorie sie zurückstellt.
void main() {
  final dienst = File('lib/services/sound_service.dart').readAsStringSync();
  final video = File('lib/widgets/ergebnis_video.dart').readAsStringSync();

  group('Die Kategorie selbst', () {
    test('Ist ambient, nicht playback', () {
      // ambient mischt sich unter fremde Musik UND schweigt beim
      // Stummschalter. Genau das ist die Entscheidung: Ein Spiel, das bei
      // umgelegtem Stummschalter trotzdem tönt, ist im Zug eine Zumutung.
      expect(SoundService.iosSitzung.avAudioSessionCategory,
          AVAudioSessionCategory.ambient);
    });

    test('Anschieben und Zurückstellen nutzen dieselbe Vorgabe', () {
      // Zwei Stellen setzen die Kategorie. Liefen sie auseinander, stellte
      // die eine wieder her, was die andere nicht gemeint hat.
      expect('configure(iosSitzung)'.allMatches(dienst).length, 2,
          reason: 'Es gibt eine Kategorie-Vorgabe zu viel oder zu wenig');
    });
  });

  group('Das Video stellt sie zurück', () {
    test('Direkt nach dem Anlegen des Controllers', () {
      // Umgestellt wird beim Anlegen, also muss es beim Anlegen zurück. Ein
      // Video läuft hier eine Minute oder länger — bis dispose() zu warten
      // hiesse, genau so lange auf playback zu sitzen.
      final anlegen = video.indexOf('await ctrl.initialize()');
      final zurueck =
          video.indexOf('SoundService.audioKategorieWiederherstellen()');
      final anzeigen = video.indexOf('setState(() => _ctrl = ctrl)');
      expect(zurueck, greaterThan(0),
          reason: 'Die Kategorie bleibt auf playback stehen');
      expect(anlegen, lessThan(zurueck));
      expect(zurueck, lessThan(anzeigen),
          reason: 'Erst zurückstellen, dann das Video zeigen');
    });

    test('Auch wenn das Video gar nicht lädt', () {
      // Die Umstellung passiert im Plugin, sobald die Plattform überhaupt
      // angesprochen wird. Ob die Datei sich laden lässt, spielt dafür keine
      // Rolle — ein `return` im catch-Zweig hätte die Kategorie verstellt
      // zurückgelassen.
      final fang = video.indexOf('catch (fehler)');
      final zurueck =
          video.indexOf('SoundService.audioKategorieWiederherstellen()');
      expect(fang, lessThan(zurueck));
      expect(video.substring(fang, zurueck).contains('return'), isFalse,
          reason: 'Der Fehlerweg kehrt zurück, bevor zurückgestellt wird');
    });

    test('Es gibt nur diese eine Stelle mit einem Videoplayer', () {
      // Sonst käme ein Video an der Rückstellung vorbei — und die Kategorie
      // bliebe wieder hängen, ohne dass jemand es sähe. Halbzeit-Moment und
      // Stationsabschluss teilen sich dieses Widget.
      final treffer = <String>[];
      for (final datei in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final inhalt = datei.readAsStringSync();
        // Nur echter Code, keine Erwähnung im Kommentar.
        final code = inhalt
            .split('\n')
            .where((z) => !z.trimLeft().startsWith('//') && !z.trimLeft().startsWith('///'))
            .join('\n');
        if (code.contains('VideoPlayerController.')) treffer.add(datei.path);
      }
      expect(treffer, hasLength(1),
          reason: 'Videoplayer ausserhalb von ergebnis_video.dart: $treffer');
      expect(treffer.first, endsWith('ergebnis_video.dart'));
    });
  });

  test('Auf Android und im Test passiert nichts', () {
    // Auf Android gibt es keine AVAudioSession, und der Audio-Fokus wird hier
    // ausdrücklich nicht angefasst.
    final ab = dienst.indexOf('static Future<void> audioKategorieWiederherstellen');
    expect(ab, greaterThan(0));
    final rumpf = dienst.substring(ab, dienst.indexOf('\n  static ', ab + 40));
    expect(rumpf.contains('if (kIsWeb || !Platform.isIOS) return;'), isTrue);
  });
}
