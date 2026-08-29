import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zentrale Stelle für AdMob-Werbung: seltene, automatische Interstitials
/// nach abgeschlossenen Lernpfad-Stationen und Tages-Challenges, sowie
/// Rewarded-Ads für Kontinent- und Profilbild-Freischaltung.
///
/// Beide Plattformen nutzen die echten Ad-Unit-IDs (siehe auch
/// APPLICATION_ID in AndroidManifest.xml / GADApplicationIdentifier in
/// Info.plist).
class AdService {
  static String get _rewardedAdUnitId {
    if (!kIsWeb && Platform.isIOS) {
      return 'ca-app-pub-4580295867570231/9086346625';
    }
    return 'ca-app-pub-4580295867570231/7023169929';
  }

  static String get _interstitialAdUnitId {
    if (!kIsWeb && Platform.isIOS) {
      return 'ca-app-pub-4580295867570231/9684992288';
    }
    return 'ca-app-pub-4580295867570231/8176469497';
  }

  static RewardedAd? _rewardedAd;
  static InterstitialAd? _interstitialAd;

  // ── REWARDED ────────────────────────────────────────────────────────────

  static Future<void> ladeRewardedAd() async {
    // google_mobile_ads unterstützt Flutter Web nicht — jeder Plugin-Aufruf
    // würde dort mit MissingPluginException abstürzen. Web bleibt bewusst
    // ohne Werbung (betrifft nur Chrome-Testläufe, nicht die echten
    // Android-/iOS-Zielplattformen).
    if (kIsWeb) {
      return;
    }
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded Ad Fehler: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Zeigt eine Rewarded-Ad und ruft [onBelohnt] auf, sobald der Nutzer die
  /// Belohnung tatsächlich verdient hat (Ad bis zum Ende angesehen). Gibt
  /// zurück, ob die Belohnung erteilt wurde — false z.B. bei fehlendem
  /// Internet (Ad konnte nicht geladen werden) oder wenn der Nutzer die Ad
  /// vorzeitig abbricht.
  static Future<bool> zeigeRewardedAd({
    required VoidCallback onBelohnt,
  }) async {
    if (kIsWeb) return false;
    if (_rewardedAd == null) {
      await ladeRewardedAd();
      if (_rewardedAd == null) {
        return false;
      }
    }

    bool wurdeBelohnt = false;
    // show() löst seine Future auf, sobald der native Anzeigebefehl abgesetzt
    // wurde — NICHT wenn der Nutzer die Ad fertig angesehen hat (bestätigt im
    // Paket-Quellcode: RewardedAd.show() ruft nur
    // instanceManager.showAdWithoutView() auf, dessen Future sich sofort nach
    // dem nativen Show-Aufruf auflöst). Reward und Dismiss kommen über
    // separate, spätere Callbacks. Deshalb hier per Completer auf das
    // tatsächliche Ende (Dismiss oder Fehlschlag) warten, statt auf await
    // show() selbst.
    final fertig = Completer<bool>();
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        ladeRewardedAd(); // nächste Rewarded-Ad direkt vorladen
        if (!fertig.isCompleted) fertig.complete(wurdeBelohnt);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        if (!fertig.isCompleted) fertig.complete(false);
      },
    );

    unawaited(_rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        wurdeBelohnt = true;
        onBelohnt();
      },
    ));

    return fertig.future;
  }

  // ── INTERSTITIAL ────────────────────────────────────────────────────────

  static Future<void> ladeInterstitialAd() async {
    if (kIsWeb) return;
    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Zeigt das vorgeladene Interstitial, falls eins bereitsteht — sonst
  /// passiert nichts (kein Fehler/Warten: Interstitials sind rein optional
  /// und dürfen den Nutzer nie blockieren).
  static Future<void> zeigeInterstitialFallsBereit() async {
    if (kIsWeb) return;
    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        ladeInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
      },
    );

    // Ein Fehler beim Anzeigen (z.B. Ad zwischenzeitlich verbraucht, keine
    // aktive Activity im richtigen Moment) darf NIEMALS die aufrufende
    // Navigation zur nächsten Station blockieren — Interstitials sind rein
    // optional. Deshalb hier bewusst NICHT erneut werfen, nur loggen.
    try {
      await _interstitialAd!.show();
    } catch (e, stack) {
      debugPrint('Interstitial Fehler (nicht kritisch): $e\n$stack');
      _interstitialAd = null;
    }
  }

  // ── Seltener automatischer Interstitial-Trigger ────────────────────────
  //
  // Zwei Bedingungen MÜSSEN beide erfüllt sein (verhindert zu häufige UND
  // erzwingt nicht zu seltene Anzeigen): mindestens 4 abgeschlossene
  // Lernpfad-Stationen seit der letzten Anzeige UND mindestens 5 Minuten
  // seit der letzten Anzeige vergangen.

  static const _kStationenSeitAd = 'stationen_seit_letzter_ad';
  static const _kLetzteAdZeitpunkt = 'letzte_ad_zeitpunkt';
  static const _kMindestStationen = 4;
  static const _kMindestMinuten = 5;

  /// Nach JEDEM Abschluss einer Lernpfad-Station aufrufen (nie mitten in
  /// einer laufenden Frage) — erhöht den Stationszähler und zeigt bei
  /// Bedarf ein Interstitial.
  static Future<void> pruefeUndZeigeInterstitial() async {
    final prefs = await SharedPreferences.getInstance();

    final stationenSeitAd = (prefs.getInt(_kStationenSeitAd) ?? 0) + 1;
    await prefs.setInt(_kStationenSeitAd, stationenSeitAd);

    final letzteAdZeit = prefs.getString(_kLetzteAdZeitpunkt);
    final genugStationen = stationenSeitAd >= _kMindestStationen;
    final genugZeitVergangen = letzteAdZeit == null ||
        DateTime.now().difference(DateTime.parse(letzteAdZeit)).inMinutes >=
            _kMindestMinuten;


    if (genugStationen && genugZeitVergangen) {
      await zeigeInterstitialFallsBereit();
      await prefs.setInt(_kStationenSeitAd, 0);
      await prefs.setString(
          _kLetzteAdZeitpunkt, DateTime.now().toIso8601String());
    } else {
    }
  }

  // ── Interstitial nach Tages-Challenges ─────────────────────────────────
  //
  // Unabhängig vom Stationszähler: einmal, sobald die zweite Tages-Challenge
  // des Tages erledigt ist, und einmal, sobald alle erledigt sind. Die
  // gesetzten Marken hängen am Tagesdatum, damit pro Tag höchstens diese
  // zwei Anzeigen entstehen — auch wenn eine Challenge (z.B. nach dem
  // Debug-Zurücksetzen) ein zweites Mal abgeschlossen wird.
  //
  // Die 5-Minuten-Sperre der Stations-Interstitials gilt hier bewusst NICHT:
  // Wer die vier Challenges am Stück durchspielt, käme sonst nie über die
  // zweite Marke hinaus. Der Zeitstempel wird trotzdem gesetzt und der
  // Stationszähler zurückgesetzt, damit unmittelbar danach nicht noch ein
  // Stations-Interstitial hinterherkommt.

  static const _kChallengeAdMarken = 'challenge_ad_marken';

  /// Nach jedem Abschluss einer Tages-Challenge aufrufen (zentral aus
  /// DailyChallenge.markDone). [erledigteHeute] ist die Anzahl der heute
  /// bereits erledigten Challenges inklusive der gerade abgeschlossenen,
  /// [gesamtAnzahl] die Anzahl aller Tages-Challenges.
  static Future<void> pruefeUndZeigeInterstitialNachChallenge(
    int erledigteHeute,
    int gesamtAnzahl,
  ) async {
    final schwelle = erledigteHeute >= gesamtAnzahl
        ? 'alle'
        : (erledigteHeute >= 2 ? 'zwei' : null);
    if (schwelle == null) return;

    final jetzt = DateTime.now();
    final tag = '${jetzt.year}-${jetzt.month.toString().padLeft(2, '0')}-'
        '${jetzt.day.toString().padLeft(2, '0')}';
    final marke = '$tag:$schwelle';

    final prefs = await SharedPreferences.getInstance();
    final marken = prefs.getStringList(_kChallengeAdMarken) ?? const <String>[];
    if (marken.contains(marke)) {
      return;
    }

    await zeigeInterstitialFallsBereit();

    // Nur die Marken von heute behalten — die Liste soll nicht mitwachsen.
    await prefs.setStringList(_kChallengeAdMarken, [
      for (final m in marken)
        if (m.startsWith('$tag:')) m,
      marke,
    ]);
    await prefs.setInt(_kStationenSeitAd, 0);
    await prefs.setString(
        _kLetzteAdZeitpunkt, DateTime.now().toIso8601String());
  }

  // ── UMP (User Messaging Platform) — GDPR/EEA-Einwilligung ───────────────
  //
  // Muss abgeschlossen sein BEVOR MobileAds.instance.initialize() läuft.
  // Außerhalb der EEA/UK/Schweiz liefert isConsentFormAvailable() sofort
  // false zurück, die App startet dann ohne spürbare Verzögerung weiter.

  /// Beim App-Start aufrufen, bevor AdMob initialisiert wird. Holt den
  /// aktuellen Einwilligungsstatus und zeigt bei Bedarf (Nutzer in
  /// EEA/UK/Schweiz, noch keine Wahl getroffen) das UMP-Consent-Formular.
  static Future<void> pruefeUndZeigeConsent() async {
    if (kIsWeb) return;

    final completer = Completer<void>();
    final params = ConsentRequestParameters();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          await _ladeUndZeigeConsentForm();
        }
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        // Fehler beim Laden der Consent-Info (z.B. kein Internet) — darf
        // die App nicht blockieren, AdMob startet trotzdem (liefert dann
        // ggf. nur nicht-personalisierte Werbung als Sicherheitsnetz).
        debugPrint('Consent-Info Fehler: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  static Future<void> _ladeUndZeigeConsentForm() async {
    final completer = Completer<void>();
    ConsentForm.loadConsentForm(
      (ConsentForm consentForm) async {
        final status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show((FormError? formError) {
            if (formError != null) {
              debugPrint('Consent-Form Anzeige-Fehler: ${formError.message}');
            }
            if (!completer.isCompleted) completer.complete();
          });
        } else {
          if (!completer.isCompleted) completer.complete();
        }
      },
      (FormError formError) {
        debugPrint('Consent-Form Lade-Fehler: ${formError.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  /// Für "Werbeeinstellungen verwalten" in den Einstellungen — Nutzer muss
  /// seine Einwilligung laut GDPR jederzeit ändern können, nicht nur beim
  /// ersten App-Start.
  ///
  /// Nutzt bewusst Googles eigene "Privacy Options"-Form
  /// ([ConsentForm.showPrivacyOptionsForm]) statt einfach erneut
  /// [_ladeUndZeigeConsentForm] aufzurufen: Das normale Consent-Formular
  /// zeigt sich laut UMP-Design nur, solange getConsentStatus() ==
  /// required — nach einer bereits getroffenen Wahl ist der Status
  /// "obtained", ein erneuter loadConsentForm()+show()-Aufruf bliebe dann
  /// wirkungslos (lädt das Formular, zeigt es aber nie an). Die
  /// Privacy-Options-Form ist der von Google vorgesehene Weg, eine bereits
  /// getroffene Entscheidung jederzeit zu widerrufen/ändern.
  ///
  /// Gibt zurück, ob ein Formular verfügbar war und angezeigt wurde (false
  /// z.B. außerhalb EU/UK/Schweiz, wo UMP nicht zwingend ist).
  static Future<bool> zeigeConsentEinstellungen() async {
    if (kIsWeb) return false;

    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    if (status != PrivacyOptionsRequirementStatus.required) return false;

    await ConsentForm.showPrivacyOptionsForm((FormError? formError) {
      if (formError != null) {
        debugPrint('Privacy-Options-Form Fehler: ${formError.message}');
      }
    });
    return true;
  }
}
