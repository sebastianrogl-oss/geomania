import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'firebase_options.dart';
import 'services/ad_service.dart';
import 'services/auth_service.dart';
import 'services/fortschritt_service.dart';
import 'services/locale_service.dart';
import 'screens/home_screen.dart';
import 'screens/rangliste_screen.dart';
import 'screens/profil_screen.dart';
import 'screens/anzeigename_screen.dart';
import 'theme/app_theme.dart';
import 'l10n/uebersetzungen.dart';

// ATT (App Tracking Transparency) ist nur auf iOS von Apple vorgeschrieben —
// Android nutzt weiterhin ausschließlich das bestehende Google-UMP-Consent.
Future<void> pruefeATTFallsIOS() async {
  if (!Platform.isIOS) return;

  final status = await AppTrackingTransparency.trackingAuthorizationStatus;

  if (status == TrackingStatus.notDetermined) {
    // Kurze Verzögerung von Apple empfohlen (System braucht kurz Zeit nach
    // App-Start, bevor der native Dialog zuverlässig angezeigt wird).
    await Future.delayed(const Duration(milliseconds: 500));
    await AppTrackingTransparency.requestTrackingAuthorization();
  }
}

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

  // Anonym anmelden (unsichtbar für Nutzer)
  await AuthService.anonymAnmelden();

  // Vor runApp() laden, damit die App gleich in der zuletzt gewählten
  // Sprache startet statt kurz Deutsch aufzublitzen.
  await LocaleService.laden();

  runApp(const GeoManiaApp());

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
      // Auf iOS zusätzlich zum UMP-Formular: Apples eigener ATT-Dialog, ohne
      // den Google AdMob laut App-Store-Datenschutzangaben keine
      // Geräte-ID-/Werbedaten für Tracking nutzen darf.
      await pruefeATTFallsIOS();
      await MobileAds.instance.initialize();
      // Interstitial früh vorladen, damit es beim ersten Trigger (siehe
      // AdService.pruefeUndZeigeInterstitial) sofort bereitsteht statt erst
      // nachzuladen und die Anzeige zu verpassen.
      AdService.ladeInterstitialAd();
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
  @override
  Widget build(BuildContext context) {
    if (!AuthService.hatAnzeigename) {
      return AnzeigenameScreen(
        onFertig: () => setState(() {}),
      );
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
