import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zentrale Stelle für AdMob-Werbung: seltene, automatische Interstitials
/// nach abgeschlossenen Lernpfad-Stationen, sowie Rewarded-Ads für
/// Kontinent- und Profilbild-Freischaltung.
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
    // DEBUG (Bug 5 — Rewarded Ads "nicht verfügbar"): kompletten Ladevorgang
    // inkl. verwendeter Ad-Unit-ID und AdMob-Fehlermeldung protokollieren.
    final startZeit = DateTime.now();
    // ignore: avoid_print
    print('[Ad/Rewarded] ladeRewardedAd() aufgerufen um $startZeit, '
        'kIsWeb=$kIsWeb, adUnitId=$_rewardedAdUnitId, '
        'bereits geladenes _rewardedAd vorhanden: ${_rewardedAd != null}');
    if (kIsWeb) {
      // ignore: avoid_print
      print('[Ad/Rewarded] kIsWeb -> lade nicht (Web wird bewusst ohne Werbung betrieben)');
      return;
    }
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          // ignore: avoid_print
          print('[Ad/Rewarded] onAdLoaded nach '
              '${DateTime.now().difference(startZeit).inMilliseconds}ms — Ad erfolgreich geladen');
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          // ignore: avoid_print
          print('[Ad/Rewarded] onAdFailedToLoad nach '
              '${DateTime.now().difference(startZeit).inMilliseconds}ms — code=${error.code}, '
              'domain=${error.domain}, message=${error.message}, '
              'responseInfo=${error.responseInfo}');
          print('Rewarded Ad Fehler: $error');
          _rewardedAd = null;
        },
      ),
    );
    // ignore: avoid_print
    print('[Ad/Rewarded] RewardedAd.load()-Aufruf abgeschickt (Callback kommt asynchron)');
  }

  /// Zeigt eine Rewarded-Ad und ruft [onBelohnt] auf, sobald der Nutzer die
  /// Belohnung tatsächlich verdient hat (Ad bis zum Ende angesehen). Gibt
  /// zurück, ob die Belohnung erteilt wurde — false z.B. bei fehlendem
  /// Internet (Ad konnte nicht geladen werden) oder wenn der Nutzer die Ad
  /// vorzeitig abbricht.
  static Future<bool> zeigeRewardedAd({
    required VoidCallback onBelohnt,
  }) async {
    // DEBUG (Bug 5 — Rewarded Ads "nicht verfügbar"): jeden Schritt bis zum
    // Anzeigen (oder Scheitern) protokollieren — insbesondere ob beim
    // Antippen bereits ein vorgeladenes Ad vorhanden ist, oder ob hier zum
    // ersten Mal (zu spät) synchron nachgeladen werden muss.
    // ignore: avoid_print
    print('[Ad/Rewarded] zeigeRewardedAd() aufgerufen, kIsWeb=$kIsWeb, '
        'bereits vorgeladenes _rewardedAd vorhanden: ${_rewardedAd != null}');
    if (kIsWeb) return false;
    if (_rewardedAd == null) {
      // ignore: avoid_print
      print('[Ad/Rewarded] KEIN vorgeladenes Ad -> lade jetzt synchron nach (verzögert die Anzeige)');
      await ladeRewardedAd();
      if (_rewardedAd == null) {
        // ignore: avoid_print
        print('[Ad/Rewarded] Nachladen fehlgeschlagen -> "Werbung nicht verfügbar" wird zurückgegeben');
        return false;
      }
    }

    bool wurdeBelohnt = false;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        // ignore: avoid_print
        print('[Ad/Rewarded] onAdDismissedFullScreenContent — wurdeBelohnt=$wurdeBelohnt, lade nächstes Rewarded-Ad vor');
        ad.dispose();
        _rewardedAd = null;
        ladeRewardedAd(); // nächste Rewarded-Ad direkt vorladen
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        // ignore: avoid_print
        print('[Ad/Rewarded] onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _rewardedAd = null;
      },
    );

    // ignore: avoid_print
    print('[Ad/Rewarded] rufe await _rewardedAd!.show() auf...');
    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        // ignore: avoid_print
        print('[Ad/Rewarded] onUserEarnedReward: type=${reward.type}, amount=${reward.amount}');
        wurdeBelohnt = true;
        onBelohnt();
      },
    );

    // ignore: avoid_print
    print('[Ad/Rewarded] zeigeRewardedAd() beendet, wurdeBelohnt=$wurdeBelohnt');
    return wurdeBelohnt;
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
    // DEBUG (Bug 2 — Stationsbutton-Bug nach Level 5): jeden Schritt
    // protokollieren, inkl. ob überhaupt ein vorgeladenes Interstitial
    // bereitsteht und wie lange der await auf show() tatsächlich dauert.
    // ignore: avoid_print
    print('[Ad/Interstitial] zeigeInterstitialFallsBereit() gestartet, '
        'kIsWeb=$kIsWeb, _interstitialAd==null: ${_interstitialAd == null}');
    if (kIsWeb) return;
    if (_interstitialAd == null) {
      // ignore: avoid_print
      print('[Ad/Interstitial] kein vorgeladenes Ad vorhanden -> überspringe show()');
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        // ignore: avoid_print
        print('[Ad/Interstitial] onAdDismissedFullScreenContent gefeuert');
        ad.dispose();
        _interstitialAd = null;
        ladeInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        // ignore: avoid_print
        print('[Ad/Interstitial] onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _interstitialAd = null;
      },
    );

    final vorShow = DateTime.now();
    // ignore: avoid_print
    print('[Ad/Interstitial] rufe await _interstitialAd!.show() auf...');
    try {
      await _interstitialAd!.show();
      // ignore: avoid_print
      print('[Ad/Interstitial] show() zurückgekehrt nach '
          '${DateTime.now().difference(vorShow).inMilliseconds}ms (OHNE Exception)');
    } catch (e, st) {
      // ignore: avoid_print
      print('[Ad/Interstitial] show() warf EXCEPTION nach '
          '${DateTime.now().difference(vorShow).inMilliseconds}ms: $e\n$st');
      rethrow;
    }
  }

  // ── Seltener automatischer Interstitial-Trigger ────────────────────────
  //
  // Zwei Bedingungen MÜSSEN beide erfüllt sein (verhindert zu häufige UND
  // erzwingt nicht zu seltene Anzeigen): mindestens 5 abgeschlossene
  // Lernpfad-Stationen seit der letzten Anzeige UND mindestens 5 Minuten
  // seit der letzten Anzeige vergangen.

  static const _kStationenSeitAd = 'stationen_seit_letzter_ad';
  static const _kLetzteAdZeitpunkt = 'letzte_ad_zeitpunkt';
  static const _kMindestStationen = 5;
  static const _kMindestMinuten = 5;

  /// Nach JEDEM Abschluss einer Lernpfad-Station aufrufen (nie mitten in
  /// einer laufenden Frage) — erhöht den Stationszähler und zeigt bei
  /// Bedarf ein Interstitial.
  static Future<void> pruefeUndZeigeInterstitial() async {
    final startZeit = DateTime.now();
    // ignore: avoid_print
    print('[Ad/Interstitial] pruefeUndZeigeInterstitial() aufgerufen um $startZeit');
    final prefs = await SharedPreferences.getInstance();

    final stationenSeitAd = (prefs.getInt(_kStationenSeitAd) ?? 0) + 1;
    await prefs.setInt(_kStationenSeitAd, stationenSeitAd);

    final letzteAdZeit = prefs.getString(_kLetzteAdZeitpunkt);
    final genugStationen = stationenSeitAd >= _kMindestStationen;
    final genugZeitVergangen = letzteAdZeit == null ||
        DateTime.now().difference(DateTime.parse(letzteAdZeit)).inMinutes >=
            _kMindestMinuten;

    // ignore: avoid_print
    print('[Ad/Interstitial] stationenSeitAd=$stationenSeitAd '
        '(Schwelle $_kMindestStationen), letzteAdZeit=$letzteAdZeit, '
        'genugStationen=$genugStationen, genugZeitVergangen=$genugZeitVergangen');

    if (genugStationen && genugZeitVergangen) {
      // ignore: avoid_print
      print('[Ad/Interstitial] Bedingungen erfüllt -> zeigeInterstitialFallsBereit() wird aufgerufen');
      await zeigeInterstitialFallsBereit();
      await prefs.setInt(_kStationenSeitAd, 0);
      await prefs.setString(
          _kLetzteAdZeitpunkt, DateTime.now().toIso8601String());
    } else {
      // ignore: avoid_print
      print('[Ad/Interstitial] Bedingungen NICHT erfüllt -> kein Ad-Versuch diesmal');
    }
    // ignore: avoid_print
    print('[Ad/Interstitial] pruefeUndZeigeInterstitial() beendet nach '
        '${DateTime.now().difference(startZeit).inMilliseconds}ms');
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
