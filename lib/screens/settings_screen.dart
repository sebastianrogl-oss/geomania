import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/abzeichen_data.dart';
import '../data/countries.dart';
import '../data/lernpfad_data.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/benachrichtigungs_service.dart';
import '../services/einstellungen_service.dart';
import '../services/challenge_ergebnis_service.dart';
import '../services/challenge_rekord_service.dart';
import '../services/daily_challenge.dart';
import '../services/daily_resume_service.dart';
import '../services/portfolio_service.dart';
import '../services/haptik_service.dart';
import '../services/knopf_rueckmeldung.dart';
import '../services/streak_ziel_service.dart';
import '../services/fortschritt_service.dart';
import '../services/locale_service.dart';
import '../services/onboarding_service.dart';
import '../services/profilbild_service.dart';
import '../services/sound_service.dart';
import '../services/spielzeit_service.dart';
import '../l10n/uebersetzungen.dart';
import '../widgets/abzeichen_popup.dart';
import '../services/abzeichen_service.dart';
import '../widgets/streak_feier_overlay.dart';
import 'station_quiz_screen.dart';
import 'streak_ziel_screen.dart';
import '../theme/app_theme.dart';

const _bg = kHintergrund;
const _textDark = Color(0xFF1A1A1A);
const _textMid = Color(0xFF888888);
const _accent = Color(0xFF4A9E4A);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _anzeigename = '';
  bool _sound = true;
  bool _vibration = true;

  // ── Erinnerungen ───────────────────────────────────────────────────────────
  bool _erinnerungen = true;
  bool _streakWarnung = true;
  bool _systemErlaubnis = false;
  int _erinnerungsMinute = SpielzeitService.kVorgabeMinute;
  bool _zeitManuell = false;
  int _spielzeitEintraege = 0;
  // Fallback, falls PackageInfo.fromPlatform() fehlschlägt (z.B. Plugin auf
  // der Plattform nicht verfügbar) — besser eine plausible als gar keine
  // Versionsangabe.
  String _appVersion = '1.1.0';

  @override
  void initState() {
    super.initState();
    _load();
    _ladeAppVersion();
    // Sprachwechsel von hier aus soll den Screen selbst sofort neu
    // aufbauen (z.B. der Checkmark bei Deutsch/English), nicht erst nach
    // einem Neustart der ganzen App.
    LocaleService.sprache.addListener(_onSpracheGeaendert);
  }

  @override
  void dispose() {
    LocaleService.sprache.removeListener(_onSpracheGeaendert);
    super.dispose();
  }

  void _onSpracheGeaendert() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final sound = await EinstellungenService.soundAktiv;
    final vibration = await EinstellungenService.vibrationAktiv;
    if (!mounted) return;
    setState(() {
      _anzeigename = AuthService.anzeigename ?? t('Spieler');
      _sound = sound;
      _vibration = vibration;
    });
    await _ladeErinnerungen();
  }

  /// Getrennt von [_load], weil es nach jeder Änderung erneut gebraucht wird —
  /// die Erlaubnis kann sich außerhalb der App geändert haben, und die
  /// ermittelte Uhrzeit wandert mit jedem Spieltag.
  Future<void> _ladeErinnerungen() async {
    final aktiv = await BenachrichtigungsService.erinnerungenAktiv();
    final streak = await BenachrichtigungsService.streakWarnungAktiv();
    final erlaubnis = await BenachrichtigungsService.systemErlaubnisVorhanden();
    final manuell = await SpielzeitService.manuelleMinute();
    final minute = await SpielzeitService.erinnerungsMinute();
    final eintraege = (await SpielzeitService.protokollierteMinuten()).length;
    if (!mounted) return;
    setState(() {
      _erinnerungen = aktiv;
      _streakWarnung = streak;
      _systemErlaubnis = erlaubnis;
      _erinnerungsMinute = minute;
      _zeitManuell = manuell != null;
      _spielzeitEintraege = eintraege;
    });
  }

  // Liest die Versionsnummer zur Laufzeit aus den nativen Plattform-Metadaten
  // (bei jedem Build automatisch aus pubspec.yaml übernommen) statt sie hier
  // fest zu codieren — muss bei zukünftigen Versions-Updates nie mehr von
  // Hand angepasst werden.
  Future<void> _ladeAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {
      // Fallback-Wert in _appVersion bleibt bestehen — kein Absturz.
    }
  }

  // ── Sprache ────────────────────────────────────────────────────────────────

  Future<void> _spracheWaehlen(String code) async {
    await LocaleService.setzeSprache(code);
    // Die Texte der geplanten Benachrichtigungen sind zum Planungszeitpunkt
    // festgelegt und würden sonst noch tagelang in der alten Sprache
    // erscheinen.
    await BenachrichtigungsService.neuPlanen();
  }

  // ── Erinnerungen ───────────────────────────────────────────────────────────

  Future<void> _toggleErinnerungen(bool wert) async {
    setState(() => _erinnerungen = wert);
    await BenachrichtigungsService.setzeErinnerungenAktiv(wert);

    // Beim EINschalten ohne Systemerlaubnis nachfassen: den eigenen Dialog
    // braucht es hier nicht mehr — wer den Schalter umlegt, hat die Frage
    // schon beantwortet.
    if (wert && !_systemErlaubnis) {
      await BenachrichtigungsService.systemErlaubnisAnfragen();
    }
    await _ladeErinnerungen();
  }

  Future<void> _toggleStreakWarnung(bool wert) async {
    setState(() => _streakWarnung = wert);
    await BenachrichtigungsService.setzeStreakWarnungAktiv(wert);
    await _ladeErinnerungen();
  }

  /// Uhrzeit von Hand setzen — oder die Automatik wiederherstellen.
  Future<void> _erinnerungszeitAendern() async {
    final gewaehlt = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: _erinnerungsMinute ~/ 60, minute: _erinnerungsMinute % 60),
      helpText: t('Erinnerungszeit'),
    );
    if (gewaehlt == null) return;

    await SpielzeitService.setzeManuelleMinute(
        gewaehlt.hour * 60 + gewaehlt.minute);
    await BenachrichtigungsService.neuPlanen();
    await _ladeErinnerungen();
  }

  Future<void> _erinnerungszeitAutomatisch() async {
    await SpielzeitService.setzeManuelleMinute(null);
    await BenachrichtigungsService.neuPlanen();
    await _ladeErinnerungen();
  }

  /// Uhrzeit plus die Herkunft der Angabe. Ohne den Zusatz wäre nicht
  /// erkennbar, ob die App schon genug über den eigenen Rhythmus weiß oder
  /// bloß die Vorgabe zeigt.
  String _zeitUntertitel() {
    final zeit = SpielzeitService.formatiere(_erinnerungsMinute);
    if (_zeitManuell) return t('{zeit} · von dir gesetzt', {'zeit': zeit});
    if (_spielzeitEintraege < SpielzeitService.kMindestEintraege) {
      return t('{zeit} · Vorgabe, noch zu wenige Spieltage', {'zeit': zeit});
    }
    return t('{zeit} · aus deinen letzten {n} Spieltagen',
        {'zeit': zeit, 'n': '$_spielzeitEintraege'});
  }

  // ── DEBUG: Benachrichtigungen (nur kDebugMode) ────────────────────────────

  Future<void> _debugSofortSenden() async {
    await BenachrichtigungsService.debugSofortSenden();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🔔 Benachrichtigung gesendet'),
      backgroundColor: Color(0xFFB8570A),
    ));
  }

  /// Setzt alle Onboarding-Merker zurück: Willkommens-Screen und die
  /// Anleitungen der vier Modi mit eigener Bedienung.
  ///
  /// Der Willkommens-Screen erscheint erst beim nächsten App-Start wieder —
  /// StartWrapper liest den Merker in seinem initState, und der läuft nicht
  /// noch einmal, solange die App offen ist. Das steht in der Meldung, damit
  /// beim Testen niemand vergeblich darauf wartet.
  Future<void> _debugOnboardingZuruecksetzen() async {
    await OnboardingService.debugZuruecksetzen();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🎓 Onboarding zurückgesetzt — Modus-Anleitungen sofort, '
          'Willkommens-Screen beim nächsten App-Start'),
      backgroundColor: Color(0xFFB8570A),
    ));
  }

  // Setzt die Ziel-Abfrage zurück und zeigt den Screen sofort — sonst käme er
  // erst nach der zweiten abgeschlossenen Station wieder, und nach einer
  // getroffenen Wahl gar nicht mehr.
  Future<void> _debugStreakZiel() async {
    await StreakZielService.zuruecksetzen();
    if (!mounted) return;
    await StreakZielScreen.zeigen(context);
    if (!mounted) return;
    final ziel = await StreakZielService.ziel();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ziel == null
          ? '🔥 Kein Ziel gesetzt (später entschieden)'
          : '🔥 Ziel gespeichert: $ziel Tage'),
      backgroundColor: const Color(0xFFB8570A),
    ));
  }

  Future<void> _debugErlaubnisZuruecksetzen() async {
    await BenachrichtigungsService.debugDialogZuruecksetzen();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🔔 Erlaubnis-Dialog zurückgesetzt — die SYSTEM-Erlaubnis '
          'bleibt bestehen'),
      backgroundColor: Color(0xFFB8570A),
    ));
    await _ladeErinnerungen();
  }

  /// Zeigt den tatsächlichen Stand aus dem Betriebssystem, nicht die eigene
  /// Buchführung — nur so fällt auf, wenn beide auseinanderlaufen.
  Future<void> _debugGeplanteAnzeigen() async {
    final geplant = await BenachrichtigungsService.geplante();
    final erlaubnis = await BenachrichtigungsService.systemErlaubnisVorhanden();
    final stand = await BenachrichtigungsService.erlaubnisStand();
    final zaehler = await BenachrichtigungsService.stationsZaehler();
    final minuten = await SpielzeitService.protokollierteMinuten();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🐞 Geplante Benachrichtigungen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Systemerlaubnis: ${erlaubnis ? "ja" : "nein"}\n'
                  'Dialog-Stand: ${stand.name}\n'
                  'Stationen gezählt: $zaehler\n'
                  'Spielzeiten: ${minuten.map(SpielzeitService.formatiere).join(", ")}',
                  style: const TextStyle(fontSize: 12, color: _textMid)),
              const SizedBox(height: 14),
              if (geplant.isEmpty)
                const Text('Nichts geplant.',
                    style: TextStyle(fontSize: 13, color: _textMid))
              else
                for (final g in geplant)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${g.id}  ${g.zeitpunkt}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _textDark)),
                        Text('${g.titel} — ${g.text}',
                            style: const TextStyle(
                                fontSize: 12, color: _textMid)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  // ── Anzeigename ────────────────────────────────────────────────────────────

  void _anzeigenameAendern() {
    final controller = TextEditingController(text: _anzeigename);
    String? fehlerText;
    bool speichert = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) {
            final text = controller.text.trim();
            final gueltig = text.length >= 2 && text.length <= 16;
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('Anzeigename ändern'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _textDark, width: 2),
                    ),
                    child: TextField(
                      controller: controller,
                      maxLength: 16,
                      autofocus: true,
                      onChanged: (_) => setModalState(() => fehlerText = null),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: t('Dein Name'),
                        border: InputBorder.none,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  if (!gueltig && text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(t('Muss zwischen 2 und 16 Zeichen lang sein'),
                        style: const TextStyle(fontSize: 12, color: Color(0xFFCC0000))),
                  ],
                  if (fehlerText != null) ...[
                    const SizedBox(height: 6),
                    Text(fehlerText!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFCC0000))),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (gueltig && !speichert)
                          ? () async {
                              setModalState(() => speichert = true);
                              final ergebnis =
                                  await AuthService.setzeAnzeigenameEindeutig(text);
                              if (ergebnis != AnzeigenameErgebnis.erfolgreich) {
                                setModalState(() {
                                  speichert = false;
                                  fehlerText = ergebnis ==
                                          AnzeigenameErgebnis.bereitsVergeben
                                      ? t('Dieser Name ist schon vergeben — bitte wähle einen anderen.')
                                      : t('Etwas ist schiefgelaufen — bitte versuch es erneut.');
                                });
                                return;
                              }
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              setState(() => _anzeigename = text);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFCCCCCC),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: speichert
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(t('Speichern'),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Ton & Haptik ───────────────────────────────────────────────────────────

  Future<void> _toggleSound(bool v) async {
    setState(() => _sound = v);
    await EinstellungenService.setzeSoundAktiv(v);
    // Der Dienst hält den Stand zwischengespeichert, damit zwischen Tipp und
    // Ton kein await auf SharedPreferences liegt — deshalb muss er hier
    // ausdrücklich nachgezogen werden.
    SoundService.setzeTonAktiv(v);
    // Sofort hörbar machen, was der Schalter bewirkt: beim EINschalten ein
    // kurzer Knopfton. Beim Ausschalten bleibt es naturgemäß still.
    if (v) SoundService.spiele(Klang.knopf);
  }

  Future<void> _toggleVibration(bool v) async {
    setState(() => _vibration = v);
    await EinstellungenService.setzeVibrationAktiv(v);
    // Wie beim Ton: Der Dienst hält den Stand zwischengespeichert, damit
    // zwischen Auslöser und Stoss kein await auf SharedPreferences liegt.
    HaptikService.setzeAktiv(v);
    // Sofort spürbar machen, was der Schalter bewirkt.
    if (v) HaptikService.spiele(HaptikArt.mittel);
  }

  // ── Lernfortschritt zurücksetzen ─────────────────────────────────────────

  Future<void> _fortschrittZuruecksetzen() async {
    // Nur noch "Abbrechen" + "Alles zurücksetzen" — die frühere Option, nur
    // die aktuelle Welt zurückzusetzen, wurde bewusst entfernt (auf Wunsch).
    final bestaetigt1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Fortschritt zurücksetzen')),
        content: Text(t('Der gesamte Fortschritt wird zurückgesetzt.')),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Abbrechen')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Alles zurücksetzen'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (bestaetigt1 != true) return;

    if (!mounted) return;
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('Bist du sicher?')),
        content: Text(t(
            'Das setzt deinen Lernpfad-Fortschritt zurück (Stationen, Kontinente). Deine Tages-Challenge-Ergebnisse und Ranglisten bleiben davon unberührt.')),
        actionsAlignment: MainAxisAlignment.start,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Abbrechen')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('Zurücksetzen'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (bestaetigt != true) return;

    // NUR der Lernpfad (lokal) — Tages-Challenges/Ranglisten sind davon
    // bewusst unabhängig und bleiben unangetastet (siehe Anfrage: der
    // Zusatz aus einem früheren Umbau, der hier auch die Firestore-
    // Ranglisten löschte, wurde wieder entfernt).
    await FortschrittService.allesDatenZuruecksetzen();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t('✅ Fortschritt wurde zurückgesetzt')),
      backgroundColor: _accent,
    ));
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  // ── Werbeeinstellungen (UMP-Consent) ────────────────────────────────────

  Future<void> _werbeeinstellungenVerwalten() async {
    final verfuegbar = await AdService.zeigeConsentEinstellungen();
    if (!verfuegbar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('Aktuell keine Werbeeinstellungen verfügbar')),
      ));
    }
  }

  // ── Feedback ─────────────────────────────────────────────────────────────

  Future<void> _feedbackGeben() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'northlightapps@gmx.at',
      queryParameters: {'subject': 'GeoMania Feedback'},
    );
    final erfolg = await launchUrl(uri);
    if (!erfolg && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('Kein Mail-Programm gefunden')),
      ));
    }
  }

  // ── DEBUG: Streak-Feier simulieren (nur kDebugMode) ───────────────────────
  //
  // Erhöht den ECHTEN Streak um 1 und löst dabei die Feier aus, damit sie sich
  // testen lässt, ohne auf echte Kalendertage zu warten.
  //
  // Der Trick steckt allein im Zurückdatieren: streakAktualisieren() erhöht
  // den Streak nur, wenn die letzte Aktivität einen Tag zurückliegt. Der
  // Debug-Button setzt deshalb nur diesen Zeitstempel auf gestern und ruft
  // danach streakErhoehenUndFeiern() auf — also exakt dieselbe Funktion, die
  // auch nach einem echten Level-Abschluss läuft (siehe
  // station_quiz_screen.dart `_stationFertig`). Es gibt keine parallele
  // Animations- oder Streak-Logik für den Testfall.
  //
  // Dadurch: 1. Antippen 0 -> 1 (Fall A, grau -> rot), danach jeweils +1
  // (Fall B, roter Pop-Impuls).
  Future<void> _streakSimulieren() async {
    await FortschrittService.debugLetzteAktivitaetAufGestern();
    if (!mounted) return;
    final (alt, neu) = await streakErhoehenUndFeiern(context);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('🐞 Streak $alt → $neu '
          '(${neu == 1 ? 'Fall A: grau → rot' : 'Fall B: Pop-Impuls'})'),
    ));
  }

  Future<void> _streakZuruecksetzen() async {
    await FortschrittService.debugStreakZuruecksetzen();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🐞 Streak auf 0 zurückgesetzt — '
          'nächste Simulation zeigt wieder Fall A'),
    ));
  }

  // ── DEBUG: Abzeichen-Freischaltung simulieren (nur kDebugMode) ────────────
  //
  // Zeigt die Freischalt-Animation mit Beispiel-Abzeichen aus der echten
  // Abzeichen-Liste. Aufgerufen wird ausschließlich AbzeichenPopup.zeigen() —
  // exakt dieselbe Methode, die auch der Spielbetrieb nutzt (siehe
  // station_quiz_screen.dart `_stationFertig` nach
  // AbzeichenService.pruefeNachLernpfadFortschritt). Es gibt keine separate
  // Test-Variante der Animation.
  //
  // [anzahl] > 1 nutzt die Warteschlangen-Logik von zeigen() (ein Overlay
  // nach dem anderen) und lässt damit auch den "1 / 3"-Zähler testen.
  //
  // Der Debug-Weg unterscheidet sich vom echten nur darin, WELCHE Abzeichen
  // übergeben werden — im Spielbetrieb die tatsächlich neu erreichten, hier
  // die ersten [anzahl] der Liste. Nichts wird dabei freigeschaltet oder
  // gespeichert.
  Future<void> _abzeichenSimulieren(int anzahl) async {
    final beispiele = alleAbzeichen.take(anzahl).toList();
    await AbzeichenPopup.zeigen(context, beispiele);
  }

  // ── Abmelden ──────────────────────────────────────────────────────────────
  //
  // Der lokale Spielstand bleibt liegen — er hängt an SharedPreferences, nicht
  // am Konto. Wer sich mit demselben Konto wieder anmeldet, findet also alles
  // vor; wer ein anderes nimmt, spielt auf demselben Gerät weiter, bekommt
  // aber eine andere Cloud-Identität.
  Future<void> _abmelden() async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (kontext) => AlertDialog(
        title: Text(t('Abmelden?')),
        content: Text(t('Dein Fortschritt auf diesem Gerät bleibt erhalten. '
            'Zum Weiterspielen musst du dich wieder anmelden.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(kontext, false),
            child: Text(t('Abbrechen')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(kontext, true),
            child: Text(t('Abmelden')),
          ),
        ],
      ),
    );
    if (ja != true) return;
    await AuthService.abmelden();
    if (!mounted) return;
    // Bis zur Wurzel zurück: dort hängt der StartWrapper am Anmeldestand und
    // zeigt von selbst wieder den Anmelde-Screen.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── DEBUG: Testkonto löschen (nur kDebugMode) ─────────────────────────────
  //
  // Räumt das anonyme Testkonto samt reserviertem Namen und Spieler-Dokument
  // weg, damit sich der ganze Ablauf — Anmelden, Namen wählen, Willkommen —
  // beliebig oft von vorne durchspielen lässt. Setzt zusätzlich den
  // Willkommens-Merker zurück, sonst würde der Screen beim nächsten Durchlauf
  // übersprungen.
  Future<void> _testkontoLoeschen() async {
    if (!AuthService.istTestkonto) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('Nur für Testkonten (Debug)')),
        backgroundColor: const Color(0xFFB8570A),
      ));
      return;
    }
    final erfolg = await AuthService.testkontoLoeschen();
    await OnboardingService.debugZuruecksetzen();
    if (!mounted) return;
    if (!erfolg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('Löschen fehlgeschlagen (Debug)')),
        backgroundColor: const Color(0xFFB8570A),
      ));
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── DEBUG: Ehrenmünze "Urgestein" (nur kDebugMode) ────────────────────────
  //
  // Anders als _abzeichenSimulieren() oben schaltet das hier WIRKLICH frei —
  // es geht denselben Weg, den später auch die echte Verleihung nimmt
  // (AbzeichenService.verleihen), und zeigt danach dasselbe Popup wie der
  // Spielbetrieb. Danach steht die Münze am Ende des Münzalbums.
  //
  // "Entziehen" gibt es dazu, damit sich der Ablauf mehrfach durchspielen
  // lässt, ohne den ganzen Spielstand zurückzusetzen.
  Future<void> _urgesteinVerleihen() async {
    final neu = await AbzeichenService.verleihen('urgestein');
    if (!mounted) return;
    final abzeichen = abzeichenById('urgestein');
    if (neu && abzeichen != null) {
      await AbzeichenPopup.zeigen(context, [abzeichen]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t('Urgestein war schon verliehen')),
        backgroundColor: const Color(0xFFB8570A),
      ));
    }
  }

  Future<void> _urgesteinEntziehen() async {
    await AbzeichenService.entziehen('urgestein');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t('Urgestein entzogen')),
      backgroundColor: const Color(0xFFB8570A),
    ));
  }

  // ── DEBUG: Sterne (nur kDebugMode) ────────────────────────────────────────
  //
  // Beide Buttons schreiben dieselben Keys wie der echte Spielbetrieb:
  // die verdienten Sterne den Zähler aus FortschrittService (den auch
  // stationAbschliessen füllt), die ausgegebenen den aus ProfilbildService.
  // Es gibt keine getrennte Test-Haltung.
  Future<void> _sterneHinzufuegen() async {
    await FortschrittService.debugSterneHinzufuegen(1000);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🐞 +1000 Sterne'),
    ));
  }

  Future<void> _sterneZuruecksetzen() async {
    await FortschrittService.debugSterneZuruecksetzen();
    await ProfilbildService.debugSterneKaeufeZuruecksetzen();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🐞 Sterne auf 0, gekaufte Profilbilder entfernt'),
    ));
  }

  // ── DEBUG: Tages-Challenges zurücksetzen (nur kDebugMode) ─────────────────
  //
  // Macht den heutigen Tag wieder spielbar — alle vier Challenges, nicht nur
  // eine. Gedacht zum Durchspielen von Ablauf und Ergebnis-Schirmen, ohne bis
  // Mitternacht warten zu müssen.
  //
  // ZURÜCKGESETZT WIRD NUR DER HEUTIGE TAG:
  //  * die Erledigt-Marken im Panel (DailyChallenge),
  //  * die heute erzielten Punkte (ChallengeRekordService),
  //  * das gespeicherte Detail-Ergebnis für "Ergebnis ansehen",
  //  * ein liegengebliebener Zwischenstand,
  //  * beim Portfolio zusätzlich Kapital und Verlaufspunkt des Tages.
  //
  // STEHEN BLEIBEN Rekorde, Serien, Spieltage, Spielzähler, Punktesummen,
  // Abzeichen und bereits hochgeladene Ranglisten-Einträge. Sie gehören zur
  // Spielhistorie, nicht zum heutigen Tag; ein zweiter Durchgang zählt dort
  // also mit. Für einen wirklich sauberen Stand ist der Fortschritts-Reset
  // weiter oben der richtige Weg.
  Future<void> _tagesChallengesZuruecksetzen() async {
    // Dieselben IDs, unter denen die vier Screens speichern — nicht die der
    // Rangliste ('schaetzen', 'higherlower', 'ranking'), die eine eigene
    // Benennung hat.
    const ids = ['preis', 'higher_lower', 'ranking_game', 'portfolio'];

    await DailyChallenge.debugHeuteLeeren();
    for (final id in ids) {
      await ChallengeRekordService.debugHeutigePunkteLoeschen(id);
      await ChallengeErgebnisService.debugLoeschen(id);
      await DailyResumeService.debugLoeschen(id);
    }
    await PortfolioService.debugHeuteZuruecksetzen();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🐞 Tages-Challenges zurückgesetzt — Rekorde und '
          'Serien bleiben'),
      backgroundColor: Color(0xFFB8570A),
    ));
  }

  // ── DEBUG: Alles freischalten (nur kDebugMode) ────────────────────────────
  //
  // Schaltet nur die PRÜFUNG aus, statt Fortschritt zu schreiben — siehe
  // FortschrittService.debugAllesFreischalten. Sterne, Abzeichen und
  // Statistiken bleiben dadurch unangetastet.
  Future<void> _allesFreischalten() async {
    await FortschrittService.debugAllesFreischalten();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🐞 Alle Stationen freigeschaltet'),
    ));
  }

  Future<void> _freischaltungZuruecksetzen() async {
    await FortschrittService.debugFreischaltungZuruecksetzen();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('🐞 Freischaltung zurückgesetzt'),
    ));
  }

  // ── DEBUG: Neue Modi (nur kDebugMode) ─────────────────────────────────────
  //
  // Flächen-Vergleich und Zwei Wahrheiten stehen bewusst in KEINER Modi-Liste
  // der Level (siehe Kommentar am LernModus-Enum) und können deshalb nie über
  // eine echte Station erscheinen. Dieser Weg ist ihr einziger Zugang,
  // solange sie in Erprobung sind.
  Future<void> _neueModiTesten() async {
    const neueModi = [
      LernModus.flaechenVergleich,
      LernModus.zweiWahrheiten,
      LernModus.wasGehoertNichtDazu,
      LernModus.laenderRanking,
      LernModus.nachbarschaftsKette,
    ];
    final modus = await showDialog<LernModus>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('🐞 ${t('Welchen Modus testen?')}'),
        children: [
          for (final m in neueModi)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  lernModusLabel(m),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
    if (modus == null || !mounted) return;

    // Weltweiter Pool statt eines einzelnen Landes wie beim Testmodus: der
    // Flächen-Vergleich braucht Länder-PAARE mit passendem Größenverhältnis,
    // und beide Modi sollen die Bandbreite der Daten zeigen.
    //
    // Zeitgestempelte ID aus demselben Grund wie beim Testmodus: dadurch
    // kennt stationKontext() die Station nicht, die Pensionierungs-
    // Substitution greift nicht und der gewählte Modus bleibt erhalten.
    final debugStation = LernStation(
      id: 'debug_neuemodi_${DateTime.now().millisecondsSinceEpoch}',
      modus: modus,
      fragenAnzahl: 5,
      laenderCodes: countries.map((c) => c.iso2).toList(),
      kategorien: const [],
      schwierigkeitsgrad: 2,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StationQuizScreen(station: debugStation)),
    );
  }

  // ── DEBUG: Testmodus (nur kDebugMode, nie im Release-Build) ────────────────
  //
  // Erlaubt Entwicklern, eine EXAKTE Land+Modus-Kombination direkt zu öffnen
  // statt eine zufällige Frage aus dem Lernpfad ziehen zu müssen — z.B. um
  // gezielt zu prüfen, wie ein bestimmtes Land (z.B. Kosovo, Taiwan) in einem
  // bestimmten Quiz-Modus (z.B. Umriss-Quiz) dargestellt wird.
  Future<void> _testmodusOeffnen() async {
    final ergebnis = await showDialog<(String, LernModus)>(
      context: context,
      builder: (_) => const _DebugTestmodusDialog(),
    );
    if (ergebnis == null || !mounted) return;
    final (land, modus) = ergebnis;

    // Synthetische Station mit einem einzigen Land als Pool statt einer
    // echten Lernpfad-Station — dadurch zieht der Fragen-Generator
    // (station_session_service.dart) IMMER genau dieses Land, keine
    // Zufallsauswahl. Eine eindeutige, zeitgestempelte ID sorgt dafür, dass
    // nie eine alte gespeicherte Debug-Session wiederverwendet wird UND dass
    // stationKontext()/_pensionierterErsatz() diese ID nicht kennt (kein
    // Lernpfad-Eintrag) — die Pensionierungs-Substitution greift dadurch
    // nicht, der gewählte Modus bleibt garantiert exakt erhalten.
    final debugStation = LernStation(
      id: 'debug_testmodus_${DateTime.now().millisecondsSinceEpoch}',
      modus: modus,
      fragenAnzahl: 5,
      laenderCodes: [land],
      kategorien: const [],
      schwierigkeitsgrad: 2,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StationQuizScreen(station: debugStation)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _textDark,
        elevation: 0,
        // FittedBox: bei Systemschrift 1.5 passte die Überschrift auf einem
        // 320-px-Schirm nicht mehr in die Kopfzeile und wurde abgeschnitten.
        // Sie wird jetzt so weit verkleinert, dass sie ganz dasteht — bei
        // normaler Schriftgröße ändert sich nichts.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(t('Einstellungen'),
              maxLines: 1,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _SectionHeader(t('PROFIL')),
            _Card(children: [
              _Zeile(
                icon: Icons.person_outline_rounded,
                title: t('Anzeigename ändern'),
                subtitle: _anzeigename,
                onTap: _anzeigenameAendern,
              ),
              const _Trenner(),
              _Zeile(
                icon: Icons.logout_rounded,
                title: t('Abmelden'),
                onTap: _abmelden,
              ),
            ]),
            const SizedBox(height: 24),

            _SectionHeader(t('SPRACHE')),
            _Card(children: [
              _SpracheZeile(
                label: 'Deutsch',
                aktiv: LocaleService.sprache.value == 'de',
                onTap: () => _spracheWaehlen('de'),
              ),
              const _Trenner(),
              _SpracheZeile(
                label: 'English',
                aktiv: LocaleService.sprache.value == 'en',
                onTap: () => _spracheWaehlen('en'),
              ),
            ]),
            const SizedBox(height: 24),

            _SectionHeader(t('TON & HAPTIK')),
            _Card(children: [
              _SwitchZeile(
                icon: Icons.volume_up_rounded,
                title: t('Soundeffekte'),
                value: _sound,
                onChanged: _toggleSound,
              ),
              const _Trenner(),
              _SwitchZeile(
                icon: Icons.vibration_rounded,
                title: t('Vibration'),
                value: _vibration,
                onChanged: _toggleVibration,
              ),
            ]),
            const SizedBox(height: 24),

            // Auf Web gibt es keine planbaren Benachrichtigungen (siehe
            // BenachrichtigungsService.verfuegbar) — dort bliebe der ganze
            // Bereich wirkungslos und wird deshalb gar nicht erst gezeigt.
            if (BenachrichtigungsService.verfuegbar) ...[
              _SectionHeader(t('ERINNERUNGEN')),
              _Card(children: [
                _SwitchZeile(
                  icon: Icons.notifications_active_outlined,
                  title: t('Erinnerungen'),
                  value: _erinnerungen,
                  onChanged: _toggleErinnerungen,
                ),
                const _Trenner(),
                _Zeile(
                  icon: Icons.schedule_rounded,
                  title: t('Erinnerungszeit'),
                  subtitle: _zeitUntertitel(),
                  onTap: _erinnerungen ? _erinnerungszeitAendern : null,
                ),
                // Nur anbieten, wenn es auch etwas zurückzusetzen gibt.
                if (_zeitManuell) ...[
                  const _Trenner(),
                  _Zeile(
                    icon: Icons.auto_mode_rounded,
                    title: t('Wieder automatisch ermitteln'),
                    onTap: _erinnerungszeitAutomatisch,
                  ),
                ],
                const _Trenner(),
                _SwitchZeile(
                  icon: Icons.local_fire_department_outlined,
                  title: t('Streak-Warnung'),
                  value: _streakWarnung,
                  onChanged: _erinnerungen ? _toggleStreakWarnung : null,
                ),
              ]),
              // Ohne Systemerlaubnis richtet der Schalter oben nichts aus —
              // der Hinweis nennt den einzigen Weg zurück.
              if (!_systemErlaubnis) ...[
                const SizedBox(height: 8),
                _ErlaubnisHinweis(
                  onTap: BenachrichtigungsService.systemEinstellungenOeffnen,
                ),
              ],
              const SizedBox(height: 24),
            ],

            // Nur im Debug-Build sichtbar — niemals im Release, siehe
            // _testmodusOeffnen()-Kommentar.
            if (kDebugMode) ...[
              _SectionHeader(t('DEBUG')),
              _Card(children: [
                _Zeile(
                  icon: Icons.bug_report_rounded,
                  title: t('Testmodus: bestimmtes Land/Modus öffnen'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _testmodusOeffnen,
                ),
                _Zeile(
                  icon: Icons.local_fire_department_rounded,
                  title: t('Streak simulieren (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _streakSimulieren,
                ),
                _Zeile(
                  icon: Icons.restart_alt_rounded,
                  title: t('Streak zurücksetzen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _streakZuruecksetzen,
                ),
                _Zeile(
                  icon: Icons.workspace_premium_rounded,
                  title: t('Abzeichen-Freischaltung simulieren (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: () => _abzeichenSimulieren(1),
                ),
                _Zeile(
                  icon: Icons.filter_3_rounded,
                  title: t('3 Abzeichen gleichzeitig simulieren (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: () => _abzeichenSimulieren(3),
                ),
                _Zeile(
                  icon: Icons.person_off_rounded,
                  title: t('Testkonto löschen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _testkontoLoeschen,
                ),
                _Zeile(
                  icon: Icons.hail_rounded,
                  title: t('Urgestein verleihen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _urgesteinVerleihen,
                ),
                _Zeile(
                  icon: Icons.undo_rounded,
                  title: t('Urgestein entziehen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _urgesteinEntziehen,
                ),
                _Zeile(
                  icon: Icons.star_rounded,
                  title: t('+1000 Sterne (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _sterneHinzufuegen,
                ),
                _Zeile(
                  icon: Icons.money_off_rounded,
                  title: t('Sterne zurücksetzen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _sterneZuruecksetzen,
                ),
                _Zeile(
                  icon: Icons.science_rounded,
                  title: t('Neue Modi testen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _neueModiTesten,
                ),
                _Zeile(
                  icon: Icons.today_rounded,
                  title: t('Tages-Challenges zurücksetzen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _tagesChallengesZuruecksetzen,
                ),
                _Zeile(
                  icon: Icons.lock_open_rounded,
                  title: t('Alle Stationen freischalten (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _allesFreischalten,
                ),
                _Zeile(
                  icon: Icons.lock_reset_rounded,
                  title: t('Freischaltung zurücksetzen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _freischaltungZuruecksetzen,
                ),
                _Zeile(
                  icon: Icons.notifications_active_rounded,
                  title: t('Benachrichtigung sofort senden (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _debugSofortSenden,
                ),
                _Zeile(
                  icon: Icons.replay_rounded,
                  title: t('Erlaubnis-Dialog zurücksetzen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _debugErlaubnisZuruecksetzen,
                ),
                _Zeile(
                  icon: Icons.list_alt_rounded,
                  title: t('Geplante Benachrichtigungen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _debugGeplanteAnzeigen,
                ),
                _Zeile(
                  icon: Icons.school_outlined,
                  title: t('Onboarding zurücksetzen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _debugOnboardingZuruecksetzen,
                ),
                _Zeile(
                  icon: Icons.local_fire_department_outlined,
                  title: t('Streak-Ziel zeigen (Debug)'),
                  titleColor: const Color(0xFFB8570A),
                  onTap: _debugStreakZiel,
                ),
              ]),
              const SizedBox(height: 24),
            ],

            _SectionHeader(t('LERNFORTSCHRITT')),
            _Card(children: [
              _Zeile(
                icon: Icons.restart_alt_rounded,
                title: t('Fortschritt zurücksetzen'),
                titleColor: const Color(0xFFCC0000),
                onTap: _fortschrittZuruecksetzen,
              ),
            ]),
            const SizedBox(height: 24),

            _SectionHeader(t('ÜBER DIE APP')),
            _Card(children: [
              _Zeile(
                icon: Icons.info_outline_rounded,
                title: t('Version'),
                subtitle: _appVersion,
              ),
              const _Trenner(),
              _Zeile(
                icon: Icons.privacy_tip_outlined,
                title: t('Werbeeinstellungen verwalten'),
                onTap: _werbeeinstellungenVerwalten,
              ),
              const _Trenner(),
              _Zeile(
                icon: Icons.mail_outline_rounded,
                title: t('Feedback geben'),
                onTap: _feedbackGeben,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Bausteine ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              color: _textMid,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5)),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _textDark, width: 2),
        boxShadow: const [
          BoxShadow(color: _textDark, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Trenner extends StatelessWidget {
  const _Trenner();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Color(0xFFE0E0DB), thickness: 1, height: 1);
}

class _Zeile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback? onTap;

  const _Zeile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // Jede Zeile dieses Screens ist ein Knopf — die Rückmeldung sitzt
      // deshalb hier und nicht in den rund zwanzig Handlern.
      onTap: onTap == null
          ? null
          : () {
              knopfRueckmeldung();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: titleColor ?? _textMid),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: titleColor ?? _textDark)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(fontSize: 12, color: _textMid)),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: _textMid, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SpracheZeile extends StatelessWidget {
  final String label;
  final bool aktiv;
  final VoidCallback onTap;

  const _SpracheZeile({
    required this.label,
    required this.aktiv,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        knopfRueckmeldung();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: aktiv ? FontWeight.w800 : FontWeight.w600,
                      color: aktiv ? _accent : _textDark)),
            ),
            if (aktiv)
              const Icon(Icons.check_circle_rounded, color: _accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SwitchZeile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;

  /// Null schaltet die Zeile ab (ausgegrauter Schalter). Genutzt für die
  /// Streak-Warnung, solange die Erinnerungen insgesamt aus sind — ein
  /// bedienbarer Unterschalter unter einem ausgeschalteten Hauptschalter wäre
  /// irreführend.
  final ValueChanged<bool>? onChanged;

  const _SwitchZeile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final aus = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 20, color: aus ? _textMid.withValues(alpha: 0.5) : _textMid),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: aus ? _textMid : _textDark)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _accent,
          ),
        ],
      ),
    );
  }
}

/// Hinweis, dass das Betriebssystem Benachrichtigungen sperrt.
///
/// Bewusst nicht als weitere _Card-Zeile, sondern abgesetzt und in Warnfarbe:
/// solange das hier steht, bewirken die Schalter darüber nichts, und das soll
/// nicht wie eine beiläufige Nebeninformation aussehen.
class _ErlaubnisHinweis extends StatelessWidget {
  final VoidCallback onTap;
  const _ErlaubnisHinweis({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB8570A), width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notifications_off_outlined,
                size: 20, color: Color(0xFFB8570A)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t('Benachrichtigungen sind für GeoMania im System '
                    'ausgeschaltet. Zum Einschalten hier tippen.'),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A4308),
                    height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── DEBUG: Testmodus-Dialog (nur kDebugMode) ────────────────────────────────
//
// Zwei Dropdowns (Land + Quiz-Modus) + Bestätigen-Button. Gibt bei
// Bestätigung ein (iso2, LernModus)-Record zurück, das
// _SettingsScreenState._testmodusOeffnen() direkt in eine synthetische
// LernStation umsetzt — kein Bezug zu echten Lernpfad-Daten, rein für
// Entwickler-Zwecke.
class _DebugTestmodusDialog extends StatefulWidget {
  const _DebugTestmodusDialog();

  @override
  State<_DebugTestmodusDialog> createState() => _DebugTestmodusDialogState();
}

class _DebugTestmodusDialogState extends State<_DebugTestmodusDialog> {
  late String _land = countries.first.iso2;
  late LernModus _modus = LernModus.values.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🐞 Testmodus: Land/Modus öffnen'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nur im Debug-Build sichtbar. Öffnet die Kombination '
                'direkt, ohne Bezug zum echten Lernpfad-Fortschritt.',
                style: TextStyle(fontSize: 12, color: _textMid)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _land,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Land'),
              items: [
                for (final c in countries)
                  DropdownMenuItem(value: c.iso2, child: Text('${c.name} (${c.iso2})')),
              ],
              onChanged: (v) => setState(() => _land = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<LernModus>(
              initialValue: _modus,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Quiz-Modus'),
              items: [
                // Der Enum-Name hinter dem Anzeigenamen — NUR hier.
                //
                // Die Anzeigenamen kommen ohne Klammerzusatz aus, dadurch
                // heißen mehrere Modi gleich: dreimal "Flaggen-Quiz", dreimal
                // "Umriss-Quiz", je zweimal "Hauptstädte", "Währungs-Quiz"
                // und "Superlativ-Quiz". Im Spiel stört das nicht, hier schon
                // — in dieser Liste wählt man ja genau den einen Modus aus,
                // den man testen will.
                for (final m in LernModus.values)
                  DropdownMenuItem(
                    value: m,
                    child: Text('${lernModusLabel(m)} (${m.name})'),
                  ),
              ],
              onChanged: (v) => setState(() => _modus = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, (_land, _modus)),
          child: const Text('Öffnen'),
        ),
      ],
    );
  }
}
