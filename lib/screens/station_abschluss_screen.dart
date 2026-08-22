import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../data/lernpfad_data.dart';
import '../l10n/uebersetzungen.dart';
import '../services/einstellungen_service.dart';
import '../services/gelernte_fakten_service.dart';
import '../services/sound_service.dart';
import '../widgets/ergebnis_video.dart';
import '../widgets/kontinent_karte.dart';
import '../theme/app_theme.dart';

// ── Schluss-Ansicht nach einer Lernpfad-Station ──────────────────────────────
//
// Erscheint nach dem letzten Weiter-Tipp einer Station und vor der Rückkehr
// zum Lernpfad. Zeigt Ergebnis, Kennzahlen und den Fortschritt über die
// Station hinaus.
//
// Die Elemente erscheinen bewusst nacheinander statt gemeinsam — das dehnt den
// Moment und lässt ihn wertiger wirken. Alle Zeitpunkte stehen in _kAuftritte.

/// Oben läuft ein Video, das zum Ergebnis passt — welches, entscheidet
/// abschlussVideo() in widgets/ergebnis_video.dart, dieselbe Einstufung, nach
/// der auch [_ueberschrift] gewählt wird.
///
/// Dieses Bild springt ein, solange das Video lädt, und falls es gar nicht
/// lädt. So bleibt an der Stelle immer etwas stehen, nie eine leere Fläche.
const kAbschlussBild = 'assets/icons/deko/coin_winken.png';

// ── Timing der gestaffelten Einblendung ──────────────────────────────────────
//
// Erst erscheinen die Karten, dann zählen ihre Werte nacheinander hoch, zuletzt
// füllt sich der Kontinent-Balken. Jede Stufe setzt an, wenn die vorige steht.
//
// Gegenüber der ersten Fassung um den Faktor 1.33 gestreckt (~3s -> ~4s):
// dieselbe Struktur und dieselben relativen Abstände, nur mehr Ruhe.
//
//    0ms  Bild (Fade + Scale, 530ms)
//  400ms  Überschrift (400ms)
//  800ms  Kennzahlen, Balken und Karte erscheinen GEMEINSAM (530ms)
// 1330ms  alle Animationen starten PARALLEL:
//           - drei Kennzahlen zählen hoch (2930ms)  -> fertig 4260ms
//           - Balken füllt sich (3190ms)            -> fertig 4520ms
//           - Länder leuchten auf, verteilt über 3720ms
// 4000ms  Weiter-Button
//
// Die Zähler laufen mit easeOutQuart: sie starten schnell und bremsen zum
// Ende deutlich ab, sodass die Zahl spürbar "landet".
const _kAuftritte = {
  'bild': 0,
  'ueberschrift': 400,
  'inhalt': 800,
  'animationen': 1330,
  'button': 4000,
};
const _kBildDauer = Duration(milliseconds: 530);
const _kFadeDauer = Duration(milliseconds: 400);
const _kInhaltDauer = Duration(milliseconds: 530);
const _kZaehlDauer = Duration(milliseconds: 2930);
const _kBalkenDauer = Duration(milliseconds: 3190);
/// Zeitfenster, über das die neuen Länder verteilt aufleuchten.
const _kAufleuchtenFenster = 3720;
const _kZaehlKurve = Curves.easeOutQuart;

// ── Vibration ────────────────────────────────────────────────────────────────
//
// Da alles parallel läuft, orientiert sich die Haptik am Gesamtfortschritt:
// gleichmäßige Impulse über den Animationszeitraum mit steigender Stärke,
// abgeschlossen von einem deutlichen Schlag. Kam kein neues Land dazu, fällt
// die Sequenz deutlich ruhiger aus.
// Abstände mitgestreckt (×1.33), damit die Sequenz synchron zu den
// Animationen bleibt. Impulsdauern und Amplituden sind haptische
// Eigenschaften und bleiben unverändert.
const _kImpulsAbstandMs = 465;
const _kImpulsDauerMs = 45;
const _kImpulsStaerkeVon = 50;
const _kImpulsStaerkeBis = 130;
// Kurz bevor der Weiter-Button erscheint.
const _kAbschlussAbMs = 3860;
const _kAbschlussDauerMs = 120;
const _kAbschlussStaerke = 180;
/// Ohne neue Länder: nur zwei sanfte Impulse und ein schwächerer Abschluss.
const _kRuhigeImpulse = 2;
const _kRuhigerAbschlussStaerke = 90;

const _cGruen = Color(0xFF4A9E4A);
const _cDunkel = Color(0xFF1A1A1A);
const _cMittel = Color(0xFF888888);
/// Sollte dem Hintergrund der Videos entsprechen, sonst zeichnet sich deren
/// Rand als Kante ab. Liegt zentral in theme/app_theme.dart.
const _cHintergrund = kHintergrund;

class StationAbschlussScreen extends StatefulWidget {
  final LernWelt welt;
  final int richtig;
  final int gesamtFragen;
  /// Verdiente Sterne. Entspricht den richtigen Antworten, ist beim
  /// Wiederholen einer bereits abgeschlossenen Station aber 0 — Sterne gibt es
  /// nur beim ersten Mal (siehe FortschrittService.stationAbschliessen).
  final int sterne;
  final Duration dauer;
  /// Gelernte Länder VOR der Station. Die Differenz zum aktuellen Stand
  /// ergibt, welche Länder in dieser Station dazukamen — sie leuchten auf der
  /// Karte auf, und daran hängt auch der kräftigere Balken-Impuls.
  final Set<String> gelerntVorher;

  const StationAbschlussScreen({
    super.key,
    required this.welt,
    required this.richtig,
    required this.gesamtFragen,
    required this.sterne,
    required this.dauer,
    required this.gelerntVorher,
  });

  static Future<void> zeigen(
    BuildContext context, {
    required LernWelt welt,
    required int richtig,
    required int gesamtFragen,
    required int sterne,
    required Duration dauer,
    required Set<String> gelerntVorher,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StationAbschlussScreen(
          welt: welt,
          richtig: richtig,
          gesamtFragen: gesamtFragen,
          sterne: sterne,
          dauer: dauer,
          gelerntVorher: gelerntVorher,
        ),
      ),
    );
  }

  @override
  State<StationAbschlussScreen> createState() => _StationAbschlussScreenState();
}

class _StationAbschlussScreenState extends State<StationAbschlussScreen> {
  // Werden gesetzt, sobald die gelernten Fakten geladen sind.
  (int, int)? _kontinent;
  /// In dieser Station neu dazugekommene Länder DIESES Kontinents, in stabiler
  /// Reihenfolge — sie leuchten auf der Karte nacheinander auf.
  List<String> _neuGelernt = const [];
  Set<String> _alleGelernt = const {};
  /// Umrisse des Kontinents; null solange sie geladen werden.
  LaenderRinge? _ringe;

  // Vorab geladen, damit die Impulse ohne dazwischenliegendes await exakt zu
  // ihrem Zeitpunkt feuern.
  bool _vibrationErlaubt = false;
  bool _hatAmplitude = false;

  /// Verzögerung der Animationen, gerechnet ab dem Erscheinen ihres Blocks —
  /// die Kinder kennen nur ihre eigene Einblendung, nicht die absolute Zeit.
  int get _animationenAbMs =>
      _kAuftritte['animationen']! - _kAuftritte['inhalt']!;


  @override
  void initState() {
    super.initState();
    _vibrationVorbereiten();
    _ladeFortschritt();
  }

  Future<void> _vibrationVorbereiten() async {
    final erlaubt = await EinstellungenService.vibrationAktiv;
    if (!erlaubt || !mounted) return;
    final amplitude = await Vibration.hasAmplitudeControl();
    if (!mounted) return;
    _vibrationErlaubt = true;
    _hatAmplitude = amplitude;
  }

  /// Klang und Haptik zum Start der Animationen.
  ///
  /// Aufbauende Vibrations-Sequenz über den gesamten Animationszeitraum:
  /// gleichmäßige Impulse mit steigender Stärke, abgeschlossen von einem
  /// deutlichen Schlag. Dazu der Sieg-Klang, siehe unten.
  ///
  /// Hiess vorher _vibrationsketteStarten — seit dem Klang stimmt der Name
  /// nicht mehr. Der Klang haengt bewusst NICHT an der Vibrations-Erlaubnis:
  /// die wird erst in _vibriere() geprueft, der Ton hat mit dem Ton-Schalter
  /// seinen eigenen.
  ///
  /// Wird erst gestartet, wenn feststeht, ob neue Länder dazukamen — ohne sie
  /// fällt die Sequenz bewusst ruhiger aus.
  void _rueckmeldungsketteStarten() {
    final mitNeuen = _neuGelernt.isNotEmpty;
    final start = _kAuftritte['animationen']!;

    // Der Sieg-Klang beginnt GENAU mit den hochzählenden Kennzahlen, also zum
    // selben Zeitpunkt wie der erste Vibrationsimpuls — beide hängen an
    // _kAuftritte['animationen'], damit sie zusammen verschieben, wenn dort
    // jemand etwas ändert.
    //
    // Die Datei ist 3,91 s lang, die Zähler laufen 2,93 s ab dieser Marke.
    // Der Klang trägt also noch etwa eine Sekunde über das Ende der Zahlen
    // hinaus, ungefähr bis der Weiter-Knopf erscheint — er läuft aus, statt
    // abgeschnitten zu werden.
    _timer.add(Timer(
      Duration(milliseconds: start),
      () => SoundService.spiele(Klang.sieg),
    ));
    final anzahl = mitNeuen
        ? ((_kAbschlussAbMs - start) / _kImpulsAbstandMs).floor()
        : _kRuhigeImpulse;

    for (var i = 0; i < anzahl; i++) {
      // Linear ansteigend, sodass der letzte Impuls vor dem Abschluss am
      // kräftigsten ist.
      final anteil = anzahl <= 1 ? 1.0 : i / (anzahl - 1);
      final staerke = (_kImpulsStaerkeVon +
              anteil * (_kImpulsStaerkeBis - _kImpulsStaerkeVon))
          .round();
      _timer.add(Timer(
        Duration(milliseconds: start + i * _kImpulsAbstandMs),
        () => _vibriere(_kImpulsDauerMs, staerke),
      ));
    }

    _timer.add(Timer(
      const Duration(milliseconds: _kAbschlussAbMs),
      () => _vibriere(
        _kAbschlussDauerMs,
        mitNeuen ? _kAbschlussStaerke : _kRuhigerAbschlussStaerke,
      ),
    ));
  }

  void _vibriere(int dauerMs, int staerke) {
    if (!_vibrationErlaubt || !mounted) return;
    if (_hatAmplitude) {
      Vibration.vibrate(duration: dauerMs, amplitude: staerke);
    } else {
      Vibration.vibrate(duration: dauerMs);
    }
  }

  final List<Timer> _timer = [];

  @override
  void dispose() {
    for (final t in _timer) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _ladeFortschritt() async {
    final kontinent =
        await GelernteFaktenService.kontinentFortschritt(widget.welt);
    final gelernt = await GelernteFaktenService.gelernteLaender();
    // Nur Länder dieses Kontinents, und nur die, die vorher noch nicht dabei
    // waren. Sortiert, damit die Aufleucht-Reihenfolge stabil bleibt.
    final zurWelt = widget.welt.laenderCodes.toSet();
    final neu = gelernt
        .where((iso) =>
            zurWelt.contains(iso) && !widget.gelerntVorher.contains(iso))
        .toList()
      ..sort();
    final ringe = await KontinentKartenDaten.laden(zurWelt);
    if (!mounted) return;
    setState(() {
      _kontinent = kontinent;
      _alleGelernt = gelernt;
      _neuGelernt = neu;
      _ringe = ringe;
    });
    // Erst jetzt steht fest, ob neue Länder dazukamen — davon hängt ab, wie
    // kräftig die Sequenz ausfällt.
    _rueckmeldungsketteStarten();
  }

  /// Trefferquote in Prozent. Die Kennzahl-Karte zeigt sie statt der
  /// absoluten Anzahl; die Schwellen der Überschrift unten rechnen unabhängig
  /// davon weiter mit dem ungerundeten Anteil.
  int get _prozentRichtig {
    if (widget.gesamtFragen == 0) return 0;
    return (widget.richtig / widget.gesamtFragen * 100).round();
  }

  // Die Schwellen selbst stehen in widgets/ergebnis_video.dart — dieselbe
  // Funktion wählt auch das Video. So können Überschrift und Video nicht
  // auseinanderlaufen.
  String get _ueberschrift {
    switch (ergebnisStufe(widget.richtig, widget.gesamtFragen)) {
      case ErgebnisStufe.perfekt:
        return t('Perfekt!');
      case ErgebnisStufe.stark:
        return t('Stark gemacht!');
      case ErgebnisStufe.solide:
        return t('Gut gemacht!');
      case ErgebnisStufe.aufholen:
        return t('Weiter üben!');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fläche für das spätere SVG: an die Bildschirmhöhe gebunden, aber
    // begrenzt, damit auf kleinen Geräten die Kennzahlen nicht verdrängt
    // werden und auf großen kein Riesenbild entsteht.
    final schirmHoehe = MediaQuery.of(context).size.height;
    final bildHoehe = (schirmHoehe * 0.30).clamp(160.0, 240.0);
    final kartenHoehe = (schirmHoehe * 0.42).clamp(240.0, 360.0);

    return Scaffold(
      backgroundColor: _cHintergrund,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // Der Inhalt scrollt, der Weiter-Button bleibt unten fixiert:
          // Bild, Kennzahlen, Balken und Karte zusammen passen auf kleineren
          // Geräten sonst nicht mehr auf den Schirm.
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
              _Auftritt(
                verzoegerungMs: _kAuftritte['bild']!,
                dauer: _kBildDauer,
                mitScale: true,
                child: ErgebnisVideo(
                  pfad: abschlussVideo(widget.richtig, widget.gesamtFragen),
                  hoehe: bildHoehe,
                  platzhalterBild: kAbschlussBild,
                ),
              ),
              const SizedBox(height: 20),
              _Auftritt(
                verzoegerungMs: _kAuftritte['ueberschrift']!,
                dauer: _kFadeDauer,
                child: Text(
                  _ueberschrift,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _cDunkel,
                  ),
                ),
              ),
                      const SizedBox(height: 24),
                      // Kennzahlen, Balken und Karte erscheinen GEMEINSAM;
                      // danach laufen ihre Animationen parallel.
                      _Auftritt(
                        verzoegerungMs: _kAuftritte['inhalt']!,
                        dauer: _kInhaltDauer,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _ZaehlKarte(
                                    icon: Icons.timer_outlined,
                                    label: t('Zeit'),
                                    ziel: widget.dauer.inSeconds,
                                    startAbMs: _animationenAbMs,
                                    dauer: _kZaehlDauer,
                                    formatierer: _sekundenAlsZeit,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ZaehlKarte(
                                    icon: Icons.check_circle_outline_rounded,
                                    label: t('Richtige'),
                                    ziel: _prozentRichtig,
                                    startAbMs: _animationenAbMs,
                                    dauer: _kZaehlDauer,
                                    formatierer: (n) => '$n%',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _ZaehlKarte(
                                    icon: Icons.star_rounded,
                                    label: t('Sterne'),
                                    ziel: widget.sterne,
                                    startAbMs: _animationenAbMs,
                                    dauer: _kZaehlDauer,
                                    formatierer: (n) => '$n',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _KontinentFortschritt(
                              welt: widget.welt,
                              werte: _kontinent,
                              startAbMs: _animationenAbMs,
                            ),
                            const SizedBox(height: 16),
                            // Solange die Umrisse laden, bleibt die Fläche
                            // leer reserviert, damit nichts springt.
                            SizedBox(
                              height: kartenHoehe,
                              child: _ringe == null
                                  ? const SizedBox.shrink()
                                  : KontinentKarte(
                                      ringe: _ringe!,
                                      frueherGelernt: _alleGelernt
                                          .where((iso) =>
                                              !_neuGelernt.contains(iso))
                                          .toSet(),
                                      neuGelernt: _neuGelernt,
                                      fensterMs: _kAufleuchtenFenster,
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _Auftritt(
                verzoegerungMs: _kAuftritte['button']!,
                dauer: _kFadeDauer,
                child: _WeiterButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gestaffelter Auftritt ────────────────────────────────────────────────────
//
// Blendet sein Kind nach [verzoegerungMs] ein — wahlweise mit leichtem
// Hochgleiten (Karten) oder Hineinwachsen (Bild). Ein Widget für alle
// Elemente, damit die Staffelung an einer Stelle definiert bleibt.
class _Auftritt extends StatefulWidget {
  final int verzoegerungMs;
  final Duration dauer;
  final bool mitScale;
  final Widget child;

  const _Auftritt({
    required this.verzoegerungMs,
    required this.dauer,
    required this.child,
    this.mitScale = false,
  });

  @override
  State<_Auftritt> createState() => _AuftrittState();
}

class _AuftrittState extends State<_Auftritt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.dauer);
    Future.delayed(Duration(milliseconds: widget.verzoegerungMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget inhalt = widget.child;
    if (widget.mitScale) {
      inhalt = ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0)
            .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
        child: inhalt,
      );
    }
    return FadeTransition(opacity: _ctrl, child: inhalt);
  }
}

// ── Kennzahl-Karten ──────────────────────────────────────────────────────────
//
// Karten-Optik der App: weiß, abgerundet, dunkle Outline mit hartem Schatten
// (siehe .claude/skills/geomania-design).
class _KennzahlKarte extends StatelessWidget {
  final IconData icon;
  final String wert;
  final String label;
  /// Ersetzt [wert], wenn gesetzt — für die hochzählende Sterne-Zahl.
  final Widget? wertWidget;

  const _KennzahlKarte({
    required this.icon,
    required this.wert,
    required this.label,
    this.wertWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cDunkel, width: 2),
        boxShadow: const [
          BoxShadow(color: _cDunkel, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: _cGruen),
          const SizedBox(height: 6),
          wertWidget ??
              Text(
                wert,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _cDunkel,
                ),
              ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _cMittel,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sekunden als "1:24".
String _sekundenAlsZeit(int sekunden) {
  final min = sekunden ~/ 60;
  final sek = sekunden % 60;
  return '$min:${sek.toString().padLeft(2, '0')}';
}

/// Kennzahl-Karte, deren Wert hochzählt. Der Zähler startet zeitversetzt zum
/// Erscheinen der Karte, damit erst die Karte ankommt und dann die Zahl läuft.
///
/// [formatierer] macht aus dem laufenden Zählwert den angezeigten Text — so
/// zählt die Zeit in Sekunden hoch und wird als "1:24" dargestellt, und bei
/// den Richtigen bleibt die Gesamtzahl hinter dem Schrägstrich stehen.
class _ZaehlKarte extends StatefulWidget {
  final IconData icon;
  final String label;
  final int ziel;
  final int startAbMs;
  final Duration dauer;
  final String Function(int) formatierer;

  const _ZaehlKarte({
    required this.icon,
    required this.label,
    required this.ziel,
    required this.startAbMs,
    required this.dauer,
    required this.formatierer,
  });

  @override
  State<_ZaehlKarte> createState() => _ZaehlKarteState();
}

class _ZaehlKarteState extends State<_ZaehlKarte> {
  int _ziel = 0;
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(Duration(milliseconds: widget.startAbMs), () {
      if (mounted) setState(() => _ziel = widget.ziel);
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _KennzahlKarte(
      icon: widget.icon,
      wert: widget.formatierer(widget.ziel),
      label: widget.label,
      wertWidget: TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: _ziel),
        duration: widget.dauer,
        curve: _kZaehlKurve,
        builder: (context, wert, child) => Text(
          widget.formatierer(wert),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _cDunkel,
          ),
        ),
      ),
    );
  }
}

// ── Kontinent-Fortschritt ────────────────────────────────────────────────────
class _KontinentFortschritt extends StatefulWidget {
  final LernWelt welt;
  final (int, int)? werte;
  final int startAbMs;

  const _KontinentFortschritt({
    required this.welt,
    required this.werte,
    required this.startAbMs,
  });

  @override
  State<_KontinentFortschritt> createState() => _KontinentFortschrittState();
}

class _KontinentFortschrittState extends State<_KontinentFortschritt> {
  // Erst wenn gesetzt, laufen Zahl und Balken los — sonst wären sie schon
  // beim Erscheinen des Blocks voll.
  bool _laeuft = false;
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(Duration(milliseconds: widget.startAbMs), () {
      if (mounted) setState(() => _laeuft = true);
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    super.dispose();
  }

  LernWelt get welt => widget.welt;
  (int, int)? get werte => widget.werte;

  @override
  Widget build(BuildContext context) {
    // Solange die Werte noch geladen werden, bleibt der Platz reserviert —
    // sonst springt das Layout, sobald sie eintreffen.
    final (gelernt, gesamt) = werte ?? (0, welt.totalLaender);
    // Vor dem Start stehen Zahl und Balken auf 0 und laufen dann gemeinsam
    // auf den Zielwert.
    final zielZahl = _laeuft ? gelernt : 0;
    final anteil = (gesamt == 0 || !_laeuft) ? 0.0 : gelernt / gesamt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Zahl und Balken laufen synchron: beide hängen an derselben Dauer
        // und Kurve und starten mit dem Erscheinen dieses Blocks.
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: zielZahl),
          duration: _kBalkenDauer,
          curve: Curves.easeOutCubic,
          builder: (context, wert, child) => Text(
            t('{a} von {b} Ländern in {welt}', {
              'a': '$wert',
              'b': '$gesamt',
              'welt': welt.name,
            }),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _cMittel,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: anteil),
            duration: _kBalkenDauer,
            curve: Curves.easeOutCubic,
            builder: (context, wert, child) => LinearProgressIndicator(
              value: wert,
              minHeight: 8,
              backgroundColor: const Color(0xFFD0D0CB),
              valueColor: const AlwaysStoppedAnimation<Color>(_cGruen),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Weiter-Button ────────────────────────────────────────────────────────────
//
// Exakt der 3D-Stil der App (siehe widgets/challenge_fertig_button.dart):
// gleiche Farbe, Radius, Rand und harter Schatten.
class _WeiterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WeiterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _cGruen,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _cDunkel, width: 2.5),
          boxShadow: const [
            BoxShadow(color: _cDunkel, offset: Offset(0, 4), blurRadius: 0),
          ],
        ),
        child: Text(
          t('Weiter'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
