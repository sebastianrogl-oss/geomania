import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'einstellungen_service.dart';

/// Die Klangeffekte der App.
///
/// Bewusst ein eigener Dienst und nicht in [EinstellungenService]: dort liegt
/// nur der Schalter, hier das Abspielen.
/// Die Klangeffekte, jeder mit der Zahl gleichzeitig bereitgehaltener Spieler.
///
/// [spieler] richtet sich nach LÄNGE und AUSLÖSER: nur wenn ein Klang noch
/// läuft, während er erneut ausgelöst wird, braucht es einen zweiten Spieler.
/// Alle werden vorab angelegt, damit auch die Überlagerung ohne Verzögerung
/// einsetzt — ein erst im Moment des Bedarfs erzeugter Spieler käme hörbar zu
/// spät.
enum Klang {
  /// Richtige Antwort. 1,46 s — bei zügigem Spiel (antworten, weiter,
  /// antworten) kann sich die nächste Antwort damit überschneiden.
  richtig('correct.mp3', 2),

  /// Falsche Antwort. 1,75 s, sonst wie [richtig].
  falsch('wrong.mp3', 2),

  /// Knopfdruck — Weiter-Knopf und Stationsstart. Mit 0,16 s so kurz, dass
  /// eine Überlagerung zwei Tipps im Abstand von weniger als einer Sechstel-
  /// sekunde bräuchte. Der zweite Spieler ist reine Vorsorge und kostet fast
  /// nichts.
  knopf('button.mp3', 2),

  /// Abzeichen freigeschaltet, im Moment des Aufpralls. 1,10 s, und mehrere
  /// Abzeichen zeigt AbzeichenPopup.zeigen() nacheinander mit await — es
  /// kann sich nie mit sich selbst überschneiden.
  muenze('coin.mp3', 1),

  /// Schluss-Ansicht, zum Start der hochzählenden Kennzahlen. 3,91 s, aber
  /// genau einmal je Stationsabschluss.
  sieg('winning.mp3', 1);

  const Klang(this.datei, this.spieler);
  final String datei;
  final int spieler;
}

/// Spielt kurze Klangeffekte ab, ohne die Musik des Nutzers zu unterbrechen.
///
/// ── Warum audioplayers mit AudioPool ──────────────────────────────────────
///
/// Gebraucht wird nicht ein Abspieler, sondern viele sehr kurze, die sich
/// überlagern dürfen: eine richtige Antwort kann auf einen noch klingenden
/// Knopfdruck folgen. [AudioPool] hält je Klang mehrere vorbereitete Spieler
/// bereit und reicht bei jedem Start den nächsten freien heraus — genau das
/// Muster, das ein einzelner AudioPlayer nicht kann, weil ein zweiter Start
/// den ersten abschneiden würde.
///
/// [PlayerMode.lowLatency] hält die Datei entschlüsselt im Speicher, statt sie
/// bei jedem Start neu zu öffnen. Ohne das liegt zwischen Tipp und Ton eine
/// hörbare Verzögerung.
///
/// ── Fremde Musik nicht unterbrechen ───────────────────────────────────────
///
/// Der [AudioContext] ist von Hand gebaut statt über AudioContextConfig, weil
/// dessen Kurzform hier zwei schlechte Ergebnisse liefert: mit
/// `respectSilence` landet Android auf usageType notificationRingtone (die
/// Effekte lägen dann auf der Klingelton-Lautstärke), ohne es landet iOS auf
/// der Kategorie playback (die überhört den Stummschalter).
///
/// Von Hand:
/// - Android: usageType `game`, contentType `sonification` und audioFocus
///   `none`. Ohne Fokus-Anforderung läuft fremde Musik unverändert weiter —
///   sie wird weder pausiert noch leiser geregelt.
/// - iOS: Kategorie `ambient`. Sie mischt sich von sich aus unter laufende
///   Wiedergabe UND schweigt, wenn der Stummschalter umgelegt ist. Die Option
///   mixWithOthers darf dabei nicht gesetzt werden — das Paket verbietet sie
///   ausdrücklich für ambient, weil sie dort schon gilt.
class SoundService {
  static final Map<Klang, AudioPool> _pools = {};

  /// Zwischengespeicherter Schalterstand.
  ///
  /// [EinstellungenService.soundAktiv] liest SharedPreferences, und das ist
  /// asynchron. Zwischen Tipp und Ton darf aber kein await liegen, sonst
  /// kommt der Klang hörbar zu spät — dasselbe Vorgehen wie bei der Vibration
  /// in abzeichen_popup.dart.
  static bool _tonAn = true;

  static bool _bereit = false;

  /// Auf Web spielt das Paket zwar, aber ohne Nutzergeste verweigern Browser
  /// die Wiedergabe und werfen dabei. Da die App im Browser ohnehin nur zum
  /// Prüfen läuft, bleibt der Ton dort ganz aus.
  static bool get verfuegbar => !kIsWeb;

  /// Lädt alle Klänge vor. Einmalig beim App-Start aufzurufen.
  ///
  /// Ohne dieses Vorladen entsteht beim allerersten Abspielen eines Klangs
  /// eine deutliche Verzögerung, weil die Datei dann erst vom Speicher geholt
  /// und entschlüsselt wird.
  static Future<void> initialisieren() async {
    if (!verfuegbar || _bereit) return;
    _bereit = true;

    _tonAn = await EinstellungenService.soundAktiv;

    final kontext = AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    );

    for (final klang in Klang.values) {
      try {
        // min == max: alle Spieler entstehen hier und keiner erst im Moment
        // des Bedarfs. Reicht der Vorrat wider Erwarten doch nicht, legt
        // AudioPool von sich aus einen weiteren an — dieser eine käme dann
        // verzögert, statt dass der Klang ganz ausfiele.
        _pools[klang] = await AudioPool.create(
          source: AssetSource('sounds/${klang.datei}'),
          audioContext: kontext,
          minPlayers: klang.spieler,
          maxPlayers: klang.spieler,
          playerMode: PlayerMode.lowLatency,
        );
      } catch (e) {
        // Ein fehlender oder defekter Klang darf die App nicht aufhalten —
        // er fällt dann einfach aus.
        debugPrint('[Sound] ${klang.datei} nicht ladbar: $e');
      }
    }
  }

  /// Übernimmt den Schalter aus den Einstellungen.
  static void setzeTonAktiv(bool aktiv) => _tonAn = aktiv;

  /// Spielt [klang], sofern der Ton eingeschaltet ist.
  ///
  /// Bewusst NICHT awaited aufzurufen: der Klang ist Beiwerk, und niemand
  /// soll auf ihn warten. Fehler werden verschluckt — ein stummer Effekt ist
  /// allemal besser als eine Ausnahme mitten im Spiel.
  static void spiele(Klang klang) {
    if (!verfuegbar || !_tonAn) return;
    final pool = _pools[klang];
    if (pool == null) return;
    pool.start().catchError((Object e) {
      debugPrint('[Sound] ${klang.datei} nicht abspielbar: $e');
      return () async {};
    });
  }
}
