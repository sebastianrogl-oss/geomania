import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/abzeichen_data.dart';
import '../data/countries.dart';
import '../data/lernpfad_data.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/einstellungen_service.dart';
import '../services/fortschritt_service.dart';
import '../services/locale_service.dart';
import '../l10n/uebersetzungen.dart';
import '../widgets/abzeichen_popup.dart';
import '../widgets/streak_feier_overlay.dart';
import 'station_quiz_screen.dart';

const _bg = Color(0xFFF5F4F0);
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
  // Fallback, falls PackageInfo.fromPlatform() fehlschlägt (z.B. Plugin auf
  // der Plattform nicht verfügbar) — besser eine plausible als gar keine
  // Versionsangabe.
  String _appVersion = '1.0.2';

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
  }

  Future<void> _toggleVibration(bool v) async {
    setState(() => _vibration = v);
    await EinstellungenService.setzeVibrationAktiv(v);
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
        title: Text(t('Einstellungen'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
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
      onTap: onTap,
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
      onTap: onTap,
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
  final ValueChanged<bool> onChanged;

  const _SwitchZeile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _textMid),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _textDark)),
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
                for (final m in LernModus.values)
                  DropdownMenuItem(value: m, child: Text(lernModusLabel(m))),
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
