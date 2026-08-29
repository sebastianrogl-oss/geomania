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
///
/// [laenge] ist mit ffprobe an der ausgelieferten Datei gemessen, nicht
/// geschätzt. Sie ist die Rechengrundlage für [spieler]: Ein Spieler ist rund
/// [laenge] lang belegt, [spieler] davon tragen also einen Auslöser alle
/// `laenge / spieler`.
enum Klang {
  /// Richtige Antwort — bei zügigem Spiel (antworten, weiter, antworten) kann
  /// sich die nächste Antwort mit der vorigen überschneiden.
  richtig('correct.mp3', 3, Duration(milliseconds: 1463)),

  /// Falsche Antwort, sonst wie [richtig].
  falsch('wrong.mp3', 3, Duration(milliseconds: 1752)),

  /// Knopfdruck — Weiter-Knopf, Stationsstart, untere Leiste. Der Klang, der
  /// am dichtesten hintereinander kommt: Wer hektisch tippt, schafft drei bis
  /// vier Tipps je Sekunde. Bei 0,16 s Länge decken vier Spieler das ab.
  knopf('button.mp3', 4, Duration(milliseconds: 157)),

  /// Abzeichen freigeschaltet, im Moment des Aufpralls. Mehrere Abzeichen
  /// zeigt AbzeichenPopup.zeigen() nacheinander mit await — es kann sich nie
  /// mit sich selbst überschneiden.
  muenze('coin.mp3', 1, Duration(milliseconds: 1097)),

  /// Schluss-Ansicht, zum Start der hochzählenden Kennzahlen. Lang, aber
  /// genau einmal je Stationsabschluss.
  sieg('winning.mp3', 1, Duration(milliseconds: 3912)),

  /// Der Wisch beim Kartenwechsel in Higher or Lower.
  ///
  /// ZWEI Spieler, nicht einer: Hier stand „sehr kurz, ein Spieler reicht" —
  /// nachgemessen ist die Datei 1,07 s lang, und in Higher or Lower folgen
  /// die Kartenwechsel deutlich dichter aufeinander. Der zweite Wisch schnitt
  /// den ersten ab.
  wisch('wisch.mp3', 2, Duration(milliseconds: 1071)),

  /// Die Rastung der Regler — Rang-Balken und grosses Schätzen.
  ///
  /// Derzeit ohne Aufrufer: Die Rastung meldet sich nur noch über die
  /// Vibration. Der Klang bleibt vorbereitet, weil er dort jederzeit wieder
  /// dazukommen kann.
  ///
  /// ALS WAV, NICHT ALS MP3, und das ist kein Geschmacksurteil. Die einst
  /// gelieferte blopp.mp3 war 104,5 ms lang, davon 51,6 ms Stille am Anfang
  /// und 26,3 ms am Ende — hörbar sind nur 27 ms in der Mitte (mit ffprobe
  /// nachgemessen, Spitze bei 61,7 ms). Die führende Stille ist die
  /// Encoder-Verzögerung von MP3: Jeder Klick käme rund 50 ms nach dem
  /// Fingerkontakt, also fast eine ganze Mindestpause zu spät, und zwei
  /// Klicks in Folge überlappten sich zur Hälfte. Ein Neu-Encodieren als MP3
  /// bringt dieselbe Verzögerung wieder mit; PCM hat sie prinzipbedingt
  /// nicht.
  ///
  /// Die Datei hier ist der herausgeschnittene hörbare Teil: 32 ms, mono,
  /// 2,9 KB. Die mp3 daneben ist raus — sie wurde nur noch mitgeliefert.
  blopp('blopp.wav', 2, Duration(milliseconds: 32));

  const Klang(this.datei, this.spieler, this.laenge);
  final String datei;
  final int spieler;

  /// Gemessene Spieldauer der Datei.
  final Duration laenge;
}

/// Ein Klang und seine vorbereiteten Spieler, reihum vergeben.
///
/// Reihum und nicht „der nächste freie": Ob ein Spieler noch klingt, ist auf
/// Android gar nicht feststellbar (siehe [SoundService], Abschnitt „Warum
/// kein AudioPool mehr"). Reihum ist die Antwort darauf — bei [Klang.spieler]
/// Spielern wird immer der am längsten zurückliegende wiederverwendet, und
/// das ist genau der, der am ehesten fertig ist.
class _Klangspur {
  _Klangspur(this.spieler)
      : lautstaerken = List<double>.filled(spieler.length, 1.0),
        zuruecksetzen = List<Future<void>?>.filled(spieler.length, null);

  final List<AudioPlayer> spieler;
  int _naechster = 0;

  /// Je Spieler das noch laufende Zurücksetzen, sonst null.
  ///
  /// Das Zurücksetzen (`stop()`) ist der teuerste Aufruf im ganzen Ablauf —
  /// am Gerät zwischen 137 und 880 ms. Es MUSS sein (siehe [SoundService],
  /// Abschnitt „Warum vor dem Abspielen gestoppt wird"), aber es muss nicht
  /// zwischen Tipp und Ton liegen: Es läuft nach dem Verklingen im
  /// Hintergrund, damit der Spieler beim nächsten Mal sofort bereit ist.
  ///
  /// Der Eintrag ist die Bremse für den Ausnahmefall, dass derselbe Spieler
  /// erneut drankommt, bevor sein Zurücksetzen durch ist — dann wird darauf
  /// gewartet, statt ins Leere zu starten.
  final List<Future<void>?> zuruecksetzen;

  /// Zuletzt gesetzte Lautstärke je Spieler — damit der Aufruf auf dem
  /// heissen Pfad entfällt, solange sich nichts ändert (und das ist der
  /// Normalfall: alle Aufrufer spielen mit voller Stärke). Startwert 1.0,
  /// weil die Spieler genau so angelegt werden.
  final List<double> lautstaerken;

  AudioPlayer nimm() {
    final p = spieler[_naechster];
    _naechster = (_naechster + 1) % spieler.length;
    return p;
  }

  int get zuletztVergeben =>
      (_naechster - 1 + spieler.length) % spieler.length;
}

/// Spielt kurze Klangeffekte ab, ohne die Musik des Nutzers zu unterbrechen.
///
/// ── Warum kein AudioPool mehr ─────────────────────────────────────────────
///
/// Hier lief [AudioPool] aus dem audioplayers-Paket. Es hält je Klang
/// mehrere Spieler bereit und reicht bei jedem Start den nächsten freien
/// heraus — dem Namen nach genau das, was gebraucht wird. In Verbindung mit
/// [PlayerMode.lowLatency] ist es aber die falsche Wahl, aus zwei Gründen:
///
/// 1. DER RÜCKWEG FEHLT. `AudioPool.start()` gibt eine Funktion zurück, und
///    nur ihr Aufruf legt den Spieler zurück. Bei [PlayerMode.mediaPlayer]
///    nimmt das Paket einem das ab, indem es sich an `onPlayerComplete`
///    hängt; bei lowLatency tut es das ausdrücklich nicht (audio_pool.dart:
///    `if (playerMode != PlayerMode.lowLatency)`), weil dieses Ereignis dort
///    nicht kommt — auf Android läuft lowLatency über SoundPool, und der
///    meldet kein Ende. Ein Aufrufer, der die Funktion nicht selbst aufruft,
///    leert den Pool also dauerhaft.
///
/// 2. DER HEISSE PFAD IST GESPERRT. `start()` läuft unter einem Lock und
///    wartet auf mehrere Plattform-Aufrufe. Zwei Tipps kurz hintereinander
///    stehen damit hintereinander in der Schlange, statt nebeneinander zu
///    klingen.
///
/// Am Gerät gemessen (SM A136B, zwölf schnelle Tipps): Ab dem dritten Tipp
/// baute der Pool jedes Mal einen komplett neuen Spieler, die Zeit vom Tipp
/// bis zum Ton stieg von 445 ms auf 1709 ms, und die Zahl der belegten
/// Spieler wuchs auf 12, ohne je wieder zu sinken. Ein nachgerüsteter
/// Rückweg per Timer half nicht: Er kann erst starten, wenn `start()`
/// aufgelöst ist, und genau darauf wartet man ja.
///
/// Stattdessen jetzt: eigene Spieler je Klang, reihum vergeben (siehe
/// [_Klangspur]). Kein Lock, keine Erzeugung im Moment des Bedarfs, kein
/// Leck — die Zahl der Spieler steht ab dem Start fest.
///
/// ── Warum vor dem Abspielen gestoppt wird ─────────────────────────────────
///
/// `stop()` sieht nach unnötiger Arbeit aus, ist aber Pflicht. Ohne
/// Ende-Ereignis bleibt ein SoundPool-Spieler nach dem Verklingen intern auf
/// „spielt" stehen: `WrappedPlayer.play()` kehrt dann sofort zurück
/// (`if (!playing …)`), und `SoundPoolPlayer.start()` würde einen längst
/// beendeten Stream fortsetzen wollen. Ergebnis wäre Stille. Erst `stop()`
/// setzt beides zurück, sodass der nächste Start einen neuen Stream öffnet.
///
/// [PlayerMode.lowLatency] hält die Datei entschlüsselt im Speicher, statt sie
/// bei jedem Start neu zu öffnen. Ohne das liegt zwischen Tipp und Ton eine
/// hörbare Verzögerung. Die Datei selbst wird dabei nur EINMAL geladen, auch
/// wenn mehrere Spieler auf sie zeigen — SoundPool teilt sich die soundId
/// über die Quelle (SoundPoolPlayer.urlSource). Mehr Spieler kosten also
/// kaum etwas.
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
  static final Map<Klang, _Klangspur> _spuren = {};

  /// Zuschlag auf [Klang.laenge], bevor ein Spieler zurückgesetzt wird.
  /// Deckt die Verzögerung zwischen dem Auslösen und dem tatsächlichen
  /// Einsetzen des Tons ab.
  static const _kNachlauf = Duration(milliseconds: 120);

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
        final spieler = <AudioPlayer>[];
        for (var i = 0; i < klang.spieler; i++) {
          final p = AudioPlayer();
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setAudioContext(kontext);
          await p.setSource(AssetSource('sounds/${klang.datei}'));
          await p.setReleaseMode(ReleaseMode.stop);
          spieler.add(p);
        }
        _spuren[klang] = _Klangspur(spieler);
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
  /// [lautstaerke] von 0 bis 1, voreingestellt volle Stärke. Der Aufruf an den
  /// Spieler entfällt, solange sich der Wert nicht ändert — derzeit spielt
  /// jeder Aufrufer mit voller Stärke, der heisse Pfad kommt damit mit zwei
  /// Plattform-Aufrufen aus. Die Abstufung liegt AUF dem Ton-Schalter, nicht
  /// neben ihm: Steht der Schalter aus, kehrt die Methode vorher zurück.
  ///
  /// Kehrt sofort zurück und wartet auf nichts: der Klang ist Beiwerk,
  /// niemand soll auf ihn warten. Fehler werden verschluckt — ein stummer
  /// Effekt ist allemal besser als eine Ausnahme mitten im Spiel.
  static void spiele(Klang klang, {double lautstaerke = 1.0}) {
    if (!verfuegbar || !_tonAn) return;
    final spur = _spuren[klang];
    if (spur == null) return;
    final spieler = spur.nimm();
    final index = spur.zuletztVergeben;
    final staerke = lautstaerke.clamp(0.0, 1.0);
    _abspielen(spur, spieler, index, staerke, klang);
  }

  static Future<void> _abspielen(
    _Klangspur spur,
    AudioPlayer spieler,
    int index,
    double staerke,
    Klang klang,
  ) async {
    try {
      // Der Normalfall: Das Zurücksetzen ist längst durch, hier steht null,
      // und es wird nicht gewartet.
      final offen = spur.zuruecksetzen[index];
      if (offen != null) await offen;
      if (spur.lautstaerken[index] != staerke) {
        await spieler.setVolume(staerke);
        spur.lautstaerken[index] = staerke;
      }
      await spieler.resume();
      _spaeterZuruecksetzen(spur, spieler, index, klang);
    } catch (e) {
      debugPrint('[Sound] ${klang.datei} nicht abspielbar: $e');
    }
  }

  /// Setzt den Spieler zurück, sobald der Klang verklungen ist.
  ///
  /// Erst danach ist er wieder startbereit — siehe Klassenkommentar. Der
  /// Zuschlag [_kNachlauf] deckt die Verzögerung zwischen dem Auslösen und
  /// dem tatsächlichen Einsetzen des Tons ab; ohne ihn würde der Klang an
  /// seinem Ende abgeschnitten.
  static void _spaeterZuruecksetzen(
    _Klangspur spur,
    AudioPlayer spieler,
    int index,
    Klang klang,
  ) {
    spur.zuruecksetzen[index] =
        Future<void>.delayed(klang.laenge + _kNachlauf, () async {
      try {
        await spieler.stop();
      } catch (e) {
        debugPrint('[Sound] ${klang.datei} nicht rücksetzbar: $e');
      }
    }).whenComplete(() => spur.zuruecksetzen[index] = null);
  }
}
