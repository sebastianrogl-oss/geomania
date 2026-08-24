import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'services/ad_service.dart';
import 'services/auth_service.dart';
import 'services/benachrichtigungs_service.dart';
import 'services/fortschritt_service.dart';
import 'services/locale_service.dart';
import 'services/onboarding_service.dart';
import 'services/sound_service.dart';
import 'screens/home_screen.dart';
import 'screens/rangliste_screen.dart';
import 'screens/profil_screen.dart';
import 'screens/anmelde_screen.dart';
import 'screens/anzeigename_screen.dart';
import 'screens/willkommen_screen.dart';
import 'theme/app_theme.dart';
import 'l10n/uebersetzungen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Nur Hochformat erlaubt — App-Layout ist nicht für Querformat ausgelegt.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // KEINE stille Anmeldung mehr beim Start. Vorher meldete die App jeden
  // unsichtbar anonym an; damit gab es zwar sofort eine uid, aber auch ein
  // Konto, das an genau dieses Gerät gebunden war und sich nie einem Menschen
  // zuordnen liess. Angemeldet wird jetzt sichtbar über den AnmeldeScreen —
  // siehe StartWrapper.

  // Vor runApp() laden, damit die App gleich in der zuletzt gewählten
  // Sprache startet statt kurz Deutsch aufzublitzen.
  await LocaleService.laden();

  // Richtet Zeitzone, Plugin und Android-Kanal ein — fragt aber BEWUSST noch
  // keine Erlaubnis an. Die kommt erst nach der ersten abgeschlossenen
  // Station, siehe BenachrichtigungsService.sollDialogZeigen. Auf Web ein
  // No-op, dort gibt es keine planbaren Benachrichtigungen.
  await BenachrichtigungsService.initialisieren();

  // Lädt die Klangeffekte vor, damit der erste Ton nicht verzögert kommt.
  // Auf Web ein No-op, siehe SoundService.verfuegbar.
  await SoundService.initialisieren();

  runApp(const GeoManiaApp());

  // Den Vorrat geplanter Benachrichtigungen bei jedem Start auffrischen: er
  // reicht nur BenachrichtigungsService.kVorlaufTage weit, und die
  // Systemerlaubnis kann zwischenzeitlich entzogen worden sein. Nicht
  // awaited — die App soll deswegen nicht später starten.
  unawaited(BenachrichtigungsService.neuPlanen());

  // google_mobile_ads unterstützt Flutter Web nicht — jeder Plugin-Aufruf
  // würde dort mit MissingPluginException abstürzen. Betrifft nur Chrome-
  // Testläufe, nicht die echten Android-/iOS-Zielplattformen.
  if (!kIsWeb) {
    // ERST NACH runApp() bzw. dem ersten gezeichneten Frame starten, NICHT
    // davor: Androids nativer Cold-Start-Splashscreen wird erst entfernt,
    // sobald Flutter seinen ersten Frame gezeichnet hat — das passiert
    // erst durch runApp(). Das UMP-Consent-Formular ist ein eigenes
    // System-Overlay-Fenster, das zwar unabhängig davon rendern kann, aber
    // solange der native Splash noch obenauf liegt, sieht der Nutzer davon
    // nichts und kann es nicht bestätigen — ein Deadlock, wenn man (wie
    // zuerst versucht) die komplette Consent-Prüfung samt Warten auf die
    // Nutzer-Entscheidung VOR runApp() abwickelt.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // GDPR/UMP-Einwilligung ZUERST klären (zeigt das Consent-Formular nur
      // für Nutzer in EEA/UK/Schweiz, sonst kehrt sofort zurück) — erst
      // danach darf AdMob initialisiert werden.
      await AdService.pruefeUndZeigeConsent();
      await MobileAds.instance.initialize();
      // Interstitial UND Rewarded Ad früh vorladen, damit beide beim ersten
      // Trigger (siehe AdService.pruefeUndZeigeInterstitial bzw.
      // zeigeRewardedAd) sofort bereitstehen statt erst synchron
      // nachzuladen — das war beim Rewarded Ad zu langsam und führte zu
      // "Werbung nicht verfügbar".
      AdService.ladeInterstitialAd();
      AdService.ladeRewardedAd();
    });
  }
}

class GeoManiaApp extends StatelessWidget {
  const GeoManiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder statt StatelessWidget-Build direkt: ein
    // Sprachwechsel (LocaleService.sprache) baut die komplette App neu —
    // dasselbe Rebuild-Muster wie FortschrittService.resetSignal an anderer
    // Stelle im Code.
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.sprache,
      builder: (context, sprache, _) {
        return MaterialApp(
          title: 'GeoMania',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: const StartWrapper(),
        );
      },
    );
  }
}

class StartWrapper extends StatefulWidget {
  const StartWrapper({super.key});

  @override
  State<StartWrapper> createState() => _StartWrapperState();
}

class _StartWrapperState extends State<StartWrapper> {
  /// null = noch nicht gelesen. Solange bleibt der Bildschirm leer statt für
  /// einen Sekundenbruchteil den Willkommens-Screen zu zeigen, den ein alter
  /// Spieler gar nicht sehen soll.
  bool? _willkommenGezeigt;

  /// null = noch nicht geprüft. Ob der Spieler in GeoMania selbst einen Namen
  /// gewählt hat, steht in seinem spieler-Dokument und muss geladen werden —
  /// der displayName des Kontos taugt dafür nicht, siehe
  /// AuthService.hatEigenenNamen.
  bool? _nameGewaehlt;

  /// Auf An- und Abmeldung hören, damit "Abmelden" in den Einstellungen ohne
  /// Umweg wieder auf dem Anmelde-Screen landet.
  StreamSubscription<User?>? _anmeldung;

  @override
  void initState() {
    super.initState();
    _ladeOnboardingStand();
    _pruefeName();
    _anmeldung = AuthService.anmeldeStand.listen((_) {
      if (!mounted) return;
      setState(() => _nameGewaehlt = null);
      _pruefeName();
    });
  }

  Future<void> _pruefeName() async {
    if (!AuthService.istAngemeldetFuerApp) return;
    final ja = await AuthService.hatEigenenNamen();
    if (mounted) setState(() => _nameGewaehlt = ja);
  }

  @override
  void dispose() {
    _anmeldung?.cancel();
    super.dispose();
  }

  Future<void> _ladeOnboardingStand() async {
    final gezeigt = await OnboardingService.willkommenGezeigt();
    if (mounted) setState(() => _willkommenGezeigt = gezeigt);
  }

  Future<void> _willkommenFertig() async {
    await OnboardingService.merkeWillkommen();
    if (mounted) setState(() => _willkommenGezeigt = true);
  }

  @override
  Widget build(BuildContext context) {
    // Reihenfolge beim allerersten Start:
    // Anmeldung -> Name -> Willkommen -> Lernpfad.
    if (!AuthService.istAngemeldetFuerApp) {
      return AnmeldeScreen(onAngemeldet: _pruefeName);
    }
    if (_nameGewaehlt == null || _willkommenGezeigt == null) {
      return const Scaffold(backgroundColor: kHintergrund);
    }
    if (_nameGewaehlt == false) {
      return AnzeigenameScreen(
        onFertig: () => setState(() => _nameGewaehlt = true),
      );
    }
    if (_willkommenGezeigt == false) {
      return WillkommenScreen(onFertig: _willkommenFertig);
    }
    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  // IndexedStack hält ProfilScreen/RanglisteScreen dauerhaft am Leben ->
  // initState()/_load() würde nach dem ALLERERSTEN Aufbau nie wieder laufen,
  // die Anzeige bliebe für immer auf dem Stand von damals stehen. Ein neuer
  // Key bei jedem Tab-Wechsel erzwingt eine frische Instanz (= frischer
  // Ladevorgang, z.B. damit ein gerade gespieltes Tagesspiel in der Rangliste
  // auftaucht statt auf dem Stand vor dem Spiel stehen zu bleiben).
  int _profilReloadKey = 0;
  int _ranglisteReloadKey = 0;

  @override
  void initState() {
    super.initState();
    // Nach einem Fortschritts-Reset (Einstellungen-Screen) zurück zu Home
    // springen und Profil beim nächsten Besuch neu laden.
    FortschrittService.resetSignal.addListener(_onResetSignal);
  }

  @override
  void dispose() {
    FortschrittService.resetSignal.removeListener(_onResetSignal);
    super.dispose();
  }

  void _onResetSignal() {
    setState(() {
      _currentIndex = 0;
      _profilReloadKey++;
    });
  }

  void _gehezuProfil() => setState(() {
        _currentIndex = 2;
        _profilReloadKey++;
      });

  void _gehezuRangliste() => setState(() {
        _currentIndex = 1;
        _ranglisteReloadKey++;
      });

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onProfilTap: _gehezuProfil),
      RanglisteScreen(key: ValueKey(_ranglisteReloadKey)),
      ProfilScreen(key: ValueKey(_profilReloadKey)),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            _gehezuRangliste();
          } else if (index == 2) {
            _gehezuProfil();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFFEAEAE5),
        selectedItemColor: const Color(0xFF4A9E4A),
        unselectedItemColor: const Color(0xFFBBBBBB),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        elevation: 0,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: t('Home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.emoji_events_rounded),
            label: t('Rangliste'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            label: t('Profil'),
          ),
        ],
      ),
    );
  }
}
