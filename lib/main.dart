import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/fortschritt_service.dart';
import 'services/locale_service.dart';
import 'screens/home_screen.dart';
import 'screens/rangliste_screen.dart';
import 'screens/profil_screen.dart';
import 'screens/anzeigename_screen.dart';
import 'theme/app_theme.dart';
import 'l10n/uebersetzungen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Anonym anmelden (unsichtbar für Nutzer)
  await AuthService.anonymAnmelden();

  // Vor runApp() laden, damit die App gleich in der zuletzt gewählten
  // Sprache startet statt kurz Deutsch aufzublitzen.
  await LocaleService.laden();

  runApp(const GeoManiaApp());
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
