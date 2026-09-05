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
import 'services/haptik_service.dart';
import 'services/knopf_rueckmeldung.dart';
import 'services/fortschritt_service.dart';
import 'services/locale_service.dart';
import 'services/onboarding_service.dart';
import 'services/sound_service.dart';
import 'services/spielstand_sync.dart';
import 'services/urgestein_service.dart';
import 'screens/home_screen.dart';
import 'screens/rangliste_screen.dart';
import 'screens/profil_screen.dart';
import 'screens/anmelde_screen.dart';
import 'widgets/gradnetz.dart';
import 'screens/anzeigename_screen.dart';
import 'screens/willkommen_screen.dart';
import 'theme/app_theme.dart';
import 'theme/scroll_verhalten.dart';
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
  await HaptikService.initialisieren();

  // Urgestein an alle, die schon vor diesem Update gespielt haben.
  //
  // MUSS VOR runApp() LAUFEN, und das ist der Kern der Sache: Erst danach
  // gibt es eine Oberfläche, auf der jemand spielen könnte. Zu diesem
  // Zeitpunkt hat eine frische Installation garantiert keinen Fortschritt —
  // und genau daran wird der Bestandsspieler erkannt. Liefe die Prüfung
  // später, könnte ein Neuling seine erste Station abgeschlossen haben und
  // erschiene als Alt-Nutzer. Begründung im Einzelnen: [UrgesteinService].
  await UrgesteinService.pruefeBeimStart();

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
          // Einheitliches Nachfedern statt der Plattform-Voreinstellung —
          // die Begründung im Einzelnen steht bei [AppScrollVerhalten].
          scrollBehavior: const AppScrollVerhalten(),
          // OHNE const, und das ist der ganze Unterschied zwischen einem
          // Sprachwechsel, der durchschlägt, und einem, der nur den
          // Umschalter selbst umfärbt.
          //
          // Ein const-Widget ist kanonisiert: Bei jedem Neubau steht hier
          // dieselbe Instanz. Flutter vergleicht in Element.updateChild das
          // alte mit dem neuen Widget, findet sie identisch — und lässt den
          // ganzen Teilbaum darunter unangetastet stehen. Der Umschalter fiel
          // dabei nicht auf, weil er selbst auf LocaleService hört; alles
          // andere ("Wie sollen wir dich nennen?", der Anmelde-Screen, der
          // Lernpfad) blieb in der alten Sprache stehen, bis der Screen aus
          // einem anderen Grund neu gebaut wurde.
          //
          // Eine neue Instanz je Durchlauf hat denselben Typ und keinen Key,
          // wird also nicht ersetzt, sondern aktualisiert: Der State und
          // damit auch ein schon eingetippter Name bleiben erhalten, nur
          // build() läuft wieder — und mit ihm jedes t().
          home: StartWrapper(),
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

class _StartWrapperState extends State<StartWrapper> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _ladeOnboardingStand();
    _pruefeName();
    // Kein eigener Aufruf für den Programmstart nötig: authStateChanges
    // liefert den aktuellen Anmeldestand beim Abonnieren sofort mit. Ein
    // zusätzlicher Anstoss hier wäre nur ein zweiter Cloud-Zugriff für
    // dasselbe Ergebnis.
    _anmeldung = AuthService.anmeldeStand.listen((nutzer) {
      if (!mounted) return;
      setState(() => _nameGewaehlt = null);
      _pruefeName();
      // Der eigentliche Moment des Zusammenführens. Bewusst ohne await und
      // ohne Wartefenster in der Oberfläche: Gespielt wird gegen die
      // SharedPreferences, die Cloud zieht im Hintergrund nach. Ändert sich
      // dabei etwas, meldet es der Abgleich über FortschrittService.
      if (nutzer != null) unawaited(SpielstandSync.beimAnmelden());
    });
  }

  Future<void> _pruefeName() async {
    if (!AuthService.istAngemeldetFuerApp) return;
    final ja = await AuthService.hatEigenenNamen();
    if (mounted) setState(() => _nameGewaehlt = ja);
  }

  /// Der letzte verlässliche Moment, um zu sichern.
  ///
  /// Nach `paused` darf das Betriebssystem die App jederzeit beenden, ohne
  /// noch einmal zu fragen — ein laufender Sammel-Timer käme dann nie mehr
  /// zum Zug. `detached` kommt auf Android oft gar nicht mehr an, deshalb
  /// hängt hier nichts daran.
  @override
  void didChangeAppLifecycleState(AppLifecycleState zustand) {
    if (zustand == AppLifecycleState.paused) {
      unawaited(SpielstandSync.jetztSichern());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      // Kein leerer Bildschirm mehr, sondern derselbe Hintergrund wie auf den
      // Einstiegs-Screens. Vorher stand hier eine nackte Farbfläche: Das
      // Gradnetz verschwand für die Dauer der Firestore-Abfrage — am Gerät
      // gemessen bis zu 1,2 s — und kam danach zurück. Jetzt bleibt der
      // Untergrund über den ganzen Übergang stehen.
      //
      // schritt 0, also die Drehung des Anmelde-Screens: Diese Wartezeit
      // gehört noch zum Anfang des Einstiegs. So ändert sich das Netz während
      // des Wartens gar nicht, und die Drehung passiert erst beim Wechsel auf
      // den Zielscreen — ein Übergang statt zweier.
      return Scaffold(
        backgroundColor: kHintergrund,
        body: GradnetzHintergrund(
          schritt: 0,
          // Ein Zeichen, dass gearbeitet wird — aber erst, wenn es sich
          // lohnt. Der Normalfall ist unter einer Sekunde durch; ein Kringel,
          // der dabei kurz aufblitzt, wirkt hektischer als gar keiner.
          // Bleibt es länger, sieht der Nutzer sonst eine leere Fläche und
          // hält die App für kaputt.
          child: FutureBuilder<void>(
            future: Future<void>.delayed(const Duration(milliseconds: 1200)),
            builder: (context, schnappschuss) {
              if (schnappschuss.connectionState != ConnectionState.done) {
                return const SizedBox.expand();
              }
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFF4A9E4A),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    if (_nameGewaehlt == false) {
      return AnzeigenameScreen(
        onFertig: () => setState(() => _nameGewaehlt = true),
      );
    }
    if (_willkommenGezeigt == false) {
      return WillkommenScreen(onFertig: _willkommenFertig);
    }
    // Auch hier ohne const — aus demselben Grund wie beim home der
    // MaterialApp oben: Ein Sprachwechsel baut diesen Screen neu, und eine
    // kanonisierte const-Instanz käme unverändert wieder heraus. Der ganze
    // Hauptbereich (Lernpfad, Rangliste, Profil, untere Leiste) bliebe dann
    // in der alten Sprache stehen.
    return MainScreen();
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
          knopfRueckmeldung();
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
