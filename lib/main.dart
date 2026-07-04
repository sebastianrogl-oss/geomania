import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/rangliste_screen.dart';
import 'screens/profil_screen.dart';
import 'screens/anzeigename_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Anonym anmelden (unsichtbar für Nutzer)
  await AuthService.anonymAnmelden();

  runApp(const GeoManiaApp());
}

class GeoManiaApp extends StatelessWidget {
  const GeoManiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoMania',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const StartWrapper(),
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const RanglisteScreen(),
    const ProfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_rounded),
            label: 'Rangliste',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
