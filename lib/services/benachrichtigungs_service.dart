import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tzdaten;
import 'package:timezone/timezone.dart' as tz;

import '../data/erinnerungs_sprueche.dart';
import '../l10n/uebersetzungen.dart';
import 'fortschritt_service.dart';
import 'spielzeit_service.dart';

/// Stand der Erlaubnis-Abfrage. Siehe [BenachrichtigungsService.sollDialogZeigen].
enum ErlaubnisStand {
  /// Noch nie gefragt.
  offen,

  /// Der Nutzer hat einmal "Später" gewählt — ein zweites Angebot folgt.
  spaeter,

  /// Endgültig abgeschlossen: erteilt, oder zweimal vertagt.
  erledigt,
}

/// Tägliche Erinnerungen und Streak-Warnung als LOKALE Benachrichtigungen.
///
/// Bewusst ohne Firebase Cloud Messaging: die Erinnerung hängt allein an
/// Uhrzeit und lokalem Spielstand, dafür braucht es keinen Server, keine
/// Push-Token-Verwaltung und keine Netzverbindung.
///
/// ── Warum ein Vorrat statt einer täglich wiederkehrenden Benachrichtigung ──
///
/// Das Plugin kann mit `matchDateTimeComponents: DateTimeComponents.time` eine
/// täglich wiederkehrende Benachrichtigung planen. Die hat aber festen Text —
/// wer eine Woche nicht spielt, bekommt siebenmal denselben Satz. Stattdessen
/// werden [kVorlaufTage] EINZELNE Benachrichtigungen mit je eigenem Text
/// geplant und bei jedem Stationsabschluss neu aufgebaut.
///
/// Der Vorrat ist zugleich die Antwort auf "nur wenn heute noch nicht gespielt
/// wurde": eine geplante Benachrichtigung kann zur Auslösezeit nichts mehr
/// prüfen. Also wird beim Spielen abgesagt und neu geplant — ab dem nächsten
/// Tag.
class BenachrichtigungsService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  // ── Schlüssel ──────────────────────────────────────────────────────────────
  static const _kAktiv = 'erinnerung_aktiv';
  static const _kStreakWarnung = 'erinnerung_streak_warnung';
  static const _kErlaubnisStand = 'erinnerung_erlaubnis_stand';
  static const _kStationsZaehler = 'erinnerung_stationen';
  static const _kBeutelTaeglich = 'erinnerung_beutel_taeglich';
  static const _kBeutelStreak = 'erinnerung_beutel_streak';

  // ── Kennwerte ──────────────────────────────────────────────────────────────

  /// So viele Tage im Voraus wird geplant. Wer eine Woche nicht hereinschaut,
  /// braucht keine achte Erinnerung — dann ist die App nichts für ihn.
  static const int kVorlaufTage = 7;

  /// Uhrzeit der Streak-Warnung: spät genug, dass der Tag fast vorbei ist,
  /// früh genug für eine Station davor.
  static const int kStreakMinute = 20 * 60 + 30;

  /// Liegt die tägliche Erinnerung näher als das an der Streak-Warnung,
  /// entfällt die Warnung — zwei Benachrichtigungen kurz hintereinander wirken
  /// wie Drängeln.
  static const int kMindestAbstandMinuten = 90;

  /// Ab so vielen abgeschlossenen Stationen wird zum ERSTEN Mal gefragt.
  static const int kStationenBisErsteFrage = 1;

  /// Ab so vielen wird nach einem "Später" ein ZWEITES (und letztes) Mal
  /// gefragt.
  static const int kStationenBisZweiteFrage = 5;

  // ID-Bereiche, damit sich die beiden Anlässe nie gegenseitig überschreiben.
  static const int _idTaeglichBasis = 1000;
  static const int _idStreak = 2000;

  static const String _kanalId = 'geomania_erinnerungen';

  /// Lokale Benachrichtigungen gibt es auf Web nicht in der Form, die diese
  /// Funktion braucht: `zonedSchedule()` wirft dort UnsupportedError und
  /// `pendingNotificationRequests()` liefert immer eine leere Liste. Statt
  /// überall Ausnahmen zu fangen, ist die ganze Funktion auf Web abgeschaltet
  /// — die App läuft im Browser weiter, nur ohne Erinnerungen.
  static bool get verfuegbar => !kIsWeb;

  static bool _bereit = false;

  // ── Start ──────────────────────────────────────────────────────────────────

  /// Einmalig beim App-Start aufzurufen (siehe main.dart).
  ///
  /// Fragt bewusst NOCH KEINE Erlaubnis an: auf iOS zeigt das System sein
  /// Fenster genau einmal, und wer beim allerersten Start gefragt wird, weiß
  /// noch gar nicht, wofür. Deshalb stehen alle `request…Permission`-Schalter
  /// der Darwin-Einstellungen auf false — sonst löste `initialize()` selbst
  /// den Systemdialog aus und verbrennte den einen Versuch.
  static Future<void> initialisieren() async {
    if (!verfuegbar || _bereit) return;

    tzdaten.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Ohne Zeitzone bliebe tz.local auf UTC stehen und die Erinnerung käme
      // um Stunden verschoben. Ein Absturz beim Start wäre aber schlimmer als
      // eine verschobene Erinnerung, deshalb nur abfangen.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    // Android 8+ verlangt einen Kanal, sonst erscheint gar nichts.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _kanalId,
            'Erinnerungen',
            description: 'Tägliche Erinnerung und Streak-Warnung',
          ));
    }

    _bereit = true;
  }

  // ── Einstellungen ──────────────────────────────────────────────────────────

  static Future<bool> erinnerungenAktiv() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAktiv) ?? true;
  }

  static Future<void> setzeErinnerungenAktiv(bool aktiv) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAktiv, aktiv);
    await neuPlanen();
  }

  static Future<bool> streakWarnungAktiv() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kStreakWarnung) ?? true;
  }

  static Future<void> setzeStreakWarnungAktiv(bool aktiv) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStreakWarnung, aktiv);
    await neuPlanen();
  }

  // ── Systemerlaubnis ────────────────────────────────────────────────────────

  /// True, wenn das Betriebssystem Benachrichtigungen derzeit zulässt.
  static Future<bool> systemErlaubnisVorhanden() async {
    if (!verfuegbar) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final stand = await ios?.checkPermissions();
        return stand?.isEnabled ?? false;
      }
    } catch (_) {
      // Plattform ohne Umsetzung (z.B. Desktop-Testlauf) — dann eben nicht.
    }
    return false;
  }

  /// Löst den SYSTEMDIALOG aus. Nur nach ausdrücklicher Zustimmung im eigenen
  /// Dialog aufrufen, siehe [sollDialogZeigen].
  static Future<bool> systemErlaubnisAnfragen() async {
    if (!verfuegbar) return false;
    var erteilt = false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        erteilt = await android?.requestNotificationsPermission() ?? false;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        erteilt = await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (_) {
      erteilt = false;
    }

    // In jedem Fall abgeschlossen: iOS fragt ohnehin nur einmal, und ein
    // erneutes Anbieten würde nichts mehr bewirken.
    await _setzeErlaubnisStand(ErlaubnisStand.erledigt);
    if (erteilt) await neuPlanen();
    return erteilt;
  }

  /// Öffnet die Benachrichtigungs-Einstellungen der App im System.
  static Future<void> systemEinstellungenOeffnen() async {
    if (!verfuegbar) return;
    try {
      await _plugin.openAppNotificationSettings();
    } catch (_) {
      // Auf manchen Android-Versionen nicht verfügbar — dann passiert nichts.
    }
  }

  // ── Der eigene Erlaubnis-Dialog ────────────────────────────────────────────

  static Future<ErlaubnisStand> erlaubnisStand() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kErlaubnisStand);
    return ErlaubnisStand.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ErlaubnisStand.offen,
    );
  }

  static Future<void> _setzeErlaubnisStand(ErlaubnisStand stand) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kErlaubnisStand, stand.name);
  }

  /// Merkt sich ein "Später".
  ///
  /// Beim ersten Mal bleibt die Tür offen (zweites Angebot nach
  /// [kStationenBisZweiteFrage] Stationen), beim zweiten Mal ist Schluss —
  /// dreimal fragen wäre Nörgeln.
  static Future<void> dialogVertagt() async {
    final stand = await erlaubnisStand();
    await _setzeErlaubnisStand(stand == ErlaubnisStand.offen
        ? ErlaubnisStand.spaeter
        : ErlaubnisStand.erledigt);
  }

  /// Entscheidet, ob der EIGENE Dialog (nicht der des Systems) fällig ist.
  ///
  /// Der Umweg über einen eigenen Dialog ist der Kern des Ablaufs: iOS zeigt
  /// sein Systemfenster nur ein einziges Mal. Wird dort abgelehnt, hilft nur
  /// noch der Weg über die Systemeinstellungen — den geht praktisch niemand.
  /// Also wird zuerst im App-Stil erklärt, wofür, und der Systemdialog nur
  /// nach einem "Ja, gerne" ausgelöst.
  static Future<bool> sollDialogZeigen() async {
    if (!verfuegbar) return false;
    final stand = await erlaubnisStand();
    if (stand == ErlaubnisStand.erledigt) return false;

    // Erlaubnis schon vorhanden (z.B. auf Android unter 13 automatisch) — dann
    // gibt es nichts zu fragen.
    if (await systemErlaubnisVorhanden()) {
      await _setzeErlaubnisStand(ErlaubnisStand.erledigt);
      return false;
    }

    final zaehler = await stationsZaehler();
    return stand == ErlaubnisStand.offen
        ? zaehler >= kStationenBisErsteFrage
        : zaehler >= kStationenBisZweiteFrage;
  }

  static Future<int> stationsZaehler() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kStationsZaehler) ?? 0;
  }

  // ── Auslöser aus dem Spiel ─────────────────────────────────────────────────

  /// Nach JEDEM Stationsabschluss aufzurufen.
  ///
  /// Hält die Uhrzeit fest, zählt die Station für die Erlaubnis-Abfrage und
  /// plant die Benachrichtigungen neu — dadurch entfällt die Erinnerung für
  /// heute automatisch.
  static Future<void> stationAbgeschlossen() async {
    await SpielzeitService.protokolliere();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStationsZaehler, (await stationsZaehler()) + 1);
    await neuPlanen();
  }

  // ── Planung ────────────────────────────────────────────────────────────────

  /// Verwirft alle geplanten Benachrichtigungen und baut sie neu auf.
  ///
  /// Immer vollständig neu statt einzeln nachzujustieren: die Planung hängt an
  /// Uhrzeit, Streak, Sprache und beiden Schaltern. Ein Neuaufbau kann nicht
  /// in einen halb aktualisierten Zustand geraten.
  static Future<void> neuPlanen() async {
    if (!verfuegbar) return;
    await initialisieren();
    await _plugin.cancelAll();

    if (!await erinnerungenAktiv()) return;
    if (!await systemErlaubnisVorhanden()) return;

    final minute = await SpielzeitService.erinnerungsMinute();
    final heuteGespielt = await SpielzeitService.hatHeuteGespielt();
    final jetzt = tz.TZDateTime.now(tz.local);

    // Die Tage, an denen erinnert wird. Heute kommt nur in Frage, wenn noch
    // nicht gespielt wurde UND die Uhrzeit noch bevorsteht. Die Schleife läuft
    // deshalb über kVorlaufTage + 1 Tage: fällt heute weg, rückt ein Tag am
    // Ende nach.
    final termine = <tz.TZDateTime>[];
    for (var versatz = 0; versatz <= kVorlaufTage; versatz++) {
      if (termine.length == kVorlaufTage) break;
      if (versatz == 0 && heuteGespielt) continue;
      final ziel = _anTag(jetzt, versatz, minute);
      if (ziel.isAfter(jetzt)) termine.add(ziel);
    }

    final texte = await _zieheTexte(_kBeutelTaeglich,
        ErinnerungsSprueche.taeglich.length, termine.length);
    for (var i = 0; i < termine.length; i++) {
      final (titel, text) = ErinnerungsSprueche.taeglich[texte[i]];
      await _plane(_idTaeglichBasis + i, t(titel), t(text), termine[i]);
    }

    await _planeStreakWarnung(minute);
  }

  /// Die Streak-Warnung, bewusst nur für EINEN Tag.
  ///
  /// Weiter im Voraus ginge nicht ehrlich: Bliebe der Spieler weg, wäre die
  /// Serie schon am Tag darauf gerissen — eine Warnung "deine 12-Tage-Serie
  /// läuft ab" spräche dann über eine Serie, die es nicht mehr gibt. Beim
  /// nächsten Stationsabschluss wird ohnehin neu geplant.
  static Future<void> _planeStreakWarnung(int taeglicheMinute) async {
    if (!await streakWarnungAktiv()) return;

    final streak = await FortschrittService.laufenderStreak();
    if (streak <= 0) return;

    // Zwei kurz aufeinanderfolgende Benachrichtigungen wirken wie Drängeln.
    // Liegt die tägliche Erinnerung ohnehin spät, reicht sie allein.
    //
    // Der Vergleich der bloßen Uhrzeiten genügt: die tägliche Erinnerung liegt
    // an JEDEM Tag des Vorrats auf derselben Minute. Fallen beide auf denselben
    // Tag, ist ihr Abstand genau diese Differenz; fallen sie auf verschiedene
    // Tage, liegen ohnehin Stunden dazwischen.
    if ((taeglicheMinute - kStreakMinute).abs() < kMindestAbstandMinuten) {
      return;
    }

    final jetzt = tz.TZDateTime.now(tz.local);
    final heuteGespielt = await SpielzeitService.hatHeuteGespielt();
    // Heute ist die Serie noch am Leben; wurde heute schon gespielt, ist sie
    // für heute gesichert und der nächste gefährdete Tag ist morgen.
    final ziel = _anTag(jetzt, heuteGespielt ? 1 : 0, kStreakMinute);
    if (!ziel.isAfter(jetzt)) return;

    final index = (await _zieheTexte(
            _kBeutelStreak, ErinnerungsSprueche.streak.length, 1))
        .first;
    final (titel, text) = ErinnerungsSprueche.streak[index];
    final tage = {'tage': '$streak'};
    await _plane(_idStreak, t(titel, tage), t(text, tage), ziel);
  }

  static tz.TZDateTime _anTag(tz.TZDateTime bezug, int versatz, int minute) =>
      tz.TZDateTime(tz.local, bezug.year, bezug.month, bezug.day + versatz,
          minute ~/ 60, minute % 60);

  static Future<void> _plane(
      int id, String titel, String text, tz.TZDateTime zeitpunkt) async {
    await _plugin.zonedSchedule(
      id: id,
      title: titel,
      body: text,
      scheduledDate: zeitpunkt,
      // Der Zeitpunkt steckt zusätzlich in der Nutzlast: der geplante Termin
      // ist sonst nicht mehr auslesbar, weil PendingNotificationRequest nur
      // Id, Titel, Text und Nutzlast mitführt.
      payload: zeitpunkt.toIso8601String(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _kanalId,
          'Erinnerungen',
          channelDescription: 'Tägliche Erinnerung und Streak-Warnung',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Bewusst KEIN exakter Alarm: exakte Alarme brauchen seit Android 12 die
      // Sonderberechtigung SCHEDULE_EXACT_ALARM, die Google Play nur für
      // Wecker und Kalender freigibt. Für eine Erinnerung ist es einerlei, ob
      // sie 19:00 oder 19:04 erscheint — und so bleibt die App ohne
      // Sonderberechtigung installierbar.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Zieht [anzahl] Textindizes aus dem persistenten Beutel (siehe
  /// [ErinnerungsSprueche.ziehe]) und schreibt den Reststand zurück.
  static Future<List<int>> _zieheTexte(
      String schluessel, int gesamt, int anzahl) async {
    if (anzahl <= 0) return const [];
    final prefs = await SharedPreferences.getInstance();
    final rest = (prefs.getStringList(schluessel) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .where((i) => i < gesamt)
        .toList();

    List<int>? neuerRest;
    final gezogen = ErinnerungsSprueche.ziehe(anzahl, gesamt, rest,
        restNachher: (r) => neuerRest = r);
    await prefs.setStringList(
        schluessel, (neuerRest ?? const <int>[]).map((i) => '$i').toList());
    return gezogen;
  }
}
