import 'dart:math';
import 'package:flutter/material.dart';
import '../data/country_rankings.dart';
import '../l10n/uebersetzungen.dart';
import '../services/abzeichen_service.dart';
import '../services/locale_service.dart';
import '../services/challenge_ergebnis_service.dart';
import '../services/challenge_panel_signal.dart';
import '../services/challenge_rekord_service.dart';
import '../services/daily_challenge.dart';
import '../services/daily_resume_service.dart';
import '../services/tages_seed_service.dart';
import '../services/skala_service.dart';
import '../services/rangliste_service.dart';
import '../services/regler_rastung.dart';
import '../services/knopf_rueckmeldung.dart';
import '../widgets/abzeichen_popup.dart';
import '../widgets/challenge_fertig_button.dart';
import '../widgets/ergebnis_karten.dart';
import '../widgets/flaggen_widget.dart' show zeigeFlagge;
import '../widgets/rangliste_ergebnis_karte.dart';
import '../widgets/schaetz_balken.dart';
import '../widgets/spiel_erklaerung.dart';
import '../theme/app_theme.dart';

// ── Question ──────────────────────────────────────────────────────────────────
//
// Nutzt dieselben Kategorien (RankingCategory aus country_rankings.dart) wie
// Higher/Lower und Ranking-Quiz, statt einer eigenen, kleineren Kategorie-Liste.

class _Frage {
  final CountryRanking land;
  final RankingCategory kat;
  _Frage(this.land, this.kat);
}

// ── Ergebnis pro Frage (für die finale Ergebnisliste) ───────────────────────

class _SchaetzErgebnis {
  final String landIso;
  final String landName;
  final String kategorieLabel;
  final bool istProzentKategorie;
  final double abweichung;
  final int punkte;

  const _SchaetzErgebnis({
    required this.landIso,
    required this.landName,
    required this.kategorieLabel,
    required this.istProzentKategorie,
    required this.abweichung,
    required this.punkte,
  });

  Map<String, dynamic> toJson() => {
    'landIso': landIso,
    'landName': landName,
    'kategorieLabel': kategorieLabel,
    'istProzentKategorie': istProzentKategorie,
    'abweichung': abweichung,
    'punkte': punkte,
  };

  static _SchaetzErgebnis fromJson(Map<String, dynamic> j) => _SchaetzErgebnis(
    landIso: j['landIso'] as String,
    landName: j['landName'] as String,
    kategorieLabel: j['kategorieLabel'] as String,
    istProzentKategorie: j['istProzentKategorie'] as bool,
    abweichung: (j['abweichung'] as num).toDouble(),
    punkte: j['punkte'] as int,
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PreisSchaetzenScreen extends StatefulWidget {
  /// Wenn true: zeigt nur das heute bereits erzielte Ergebnis erneut an,
  /// startet KEINE neue Runde (für "Ergebnis ansehen" im Start-Screen).
  final bool nurAnsicht;
  const PreisSchaetzenScreen({super.key, this.nurAnsicht = false});
  @override
  State<PreisSchaetzenScreen> createState() => _PreisSchaetzenScreenState();
}

class _PreisSchaetzenScreenState extends State<PreisSchaetzenScreen>
    with TickerProviderStateMixin {
  /// Fragen je Tagesrunde. Von 8 auf 5 gekürzt.
  ///
  /// Alles andere im Screen rechnet mit `_fragen.length` und zieht damit von
  /// selbst mit: die Punkteanzeige "{a}/{b}", die Punktreihe über der Frage,
  /// die Ergebnisliste am Ende und die Abbruchbedingung der Runde.
  static const _kFragen = 5;

  /// Höchstpunktzahl je Frage — siehe [_punkteFuer], das auf 0..100 begrenzt.
  static const _kMaxPtsProFrage = 100;

  /// Höchstpunktzahl einer Runde. Hängt an [_kFragen] und darf NICHT wieder
  /// als feste Zahl geschrieben werden: an ihr hängen die Anzeige
  /// "Rekord {a} / {b}" und die Erkennung der perfekten Runde.
  static const _kMaxPts = _kFragen * _kMaxPtsProFrage;
  static const _kId = 'preis';

  /// Skalenstriche unter dem Balken: zehn Abschnitte, also elf Striche.
  ///
  /// Hinter dieser Achse stehen keine abzählbaren Stufen wie beim Ranking,
  /// sondern ein stufenloser Wertebereich — die Striche sind reine
  /// Orientierung.
  static const _kSkalenAbschnitte = 10;

  late final RankingCategory _heutigeKat;
  List<_Frage> _fragen = [];
  int _idx = 0;
  SkalaErgebnis? _skala;
  double _sliderVal = 50;

  /// Klick und Stoss beim Überfahren einer Skalenmarke — derselbe Baustein
  /// wie beim Rang-Balken im Länder-Ranking, damit sich beide Regler gleich
  /// anfühlen. Bisher rastete dieser hier gar nicht.
  final _rastung = ReglerRastung();

  bool _beantwortet = false;
  bool _fertig = false;
  int _gesamt = 0;
  int _letztePts = 0;
  double _abweichung = 0;
  int? _rekord;
  bool _neuerRekord = false;

  // Eine gedeckelte Rekord-Anzeige gibt es nicht mehr: Der Bestwert wird
  // nirgends mehr gezeigt. Der GESPEICHERTE Wert bleibt unangetastet — er
  // entscheidet weiter über die Abzeichen.
  final List<_SchaetzErgebnis> _alleErgebnisse = [];

  late final AnimationController _ptsCtrl;
  late Animation<double> _ptsAnim;

  /// Fährt die Markierung nach dem Bestätigen auf den echten Wert — siehe
  /// [_fahreZurAntwort].
  late final AnimationController _fahrt;
  Animation<double>? _fahrtAnim;

  /// Aktuelle Position der Markierung, 0 bis 1 auf der Rundenskala.
  double _fahrtAnteil = 0;

  @override
  void initState() {
    super.initState();
    // Tägliche Kategorie seed-basiert bestimmen (gleich den ganzen Tag)
    final katIdx = Random(
      TagesSeedService.seedFuer(_kId) + 999,
    ).nextInt(rankingCategories.length);
    _heutigeKat = rankingCategories[katIdx];
    _ptsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _ptsAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ptsCtrl, curve: Curves.elasticOut));
    _fahrt = AnimationController(vsync: this, duration: kFahrtDauer);
    if (widget.nurAnsicht) {
      _ladeHeutigesErgebnis();
    } else {
      _ladeUndStarte();
    }
  }

  @override
  void dispose() {
    _ptsCtrl.dispose();
    _fahrt.dispose();
    super.dispose();
  }

  /// Zeigt das heute bereits erzielte Ergebnis erneut an, ohne eine neue
  /// Runde zu starten (siehe PreisSchaetzenScreen.nurAnsicht). Die Fragen-
  /// Liste wird aus dem beim Abschluss gespeicherten Detail-Ergebnis
  /// rekonstruiert (ChallengeErgebnisService), nicht neu berechnet.
  Future<void> _ladeHeutigesErgebnis() async {
    _rekord = await ChallengeRekordService.getRekord(_kId);
    final heute = await ChallengeRekordService.getHeutigePunkte(_kId) ?? 0;
    final detail = await ChallengeErgebnisService.laden(_kId);
    final ergebnisseRoh = (detail?['ergebnisse'] as List<dynamic>?) ?? [];
    final ergebnisse = ergebnisseRoh
        .map((e) => _SchaetzErgebnis.fromJson(e as Map<String, dynamic>))
        .toList();
    setState(() {
      _gesamt = heute;
      _neuerRekord = _rekord != null && heute >= _rekord!;
      _alleErgebnisse
        ..clear()
        ..addAll(ergebnisse);
      _fertig = true;
    });
  }

  Future<void> _ladeUndStarte() async {
    _rekord = await ChallengeRekordService.getRekord(_kId);
    _starteFragen();

    final zwischenstand = await DailyResumeService.laden(_kId);
    if (zwischenstand == null) return;
    final idx = zwischenstand['idx'] as int? ?? 0;
    final gesamt = zwischenstand['gesamt'] as int? ?? 0;
    if (idx <= 0 || idx >= _fragen.length) return;
    final ergebnisseRoh = (zwischenstand['ergebnisse'] as List<dynamic>?) ?? [];
    final ergebnisse = ergebnisseRoh
        .map((e) => _SchaetzErgebnis.fromJson(e as Map<String, dynamic>))
        .toList();
    // _skala wurde bereits oben in _starteFragen() EINMAL für die ganze
    // Runde berechnet — hier nur noch die Startposition des Sliders für
    // die fortgesetzte Frage neu bestimmen, NICHT die Skala selbst.
    final sk = _skala!;
    final start = sk.wertAn(TagesSeedService.startBruch(idx));
    setState(() {
      _idx = idx;
      _gesamt = gesamt;
      _sliderVal = start.clamp(sk.min, sk.max);
      _beantwortet = false;
      _rastung.ruecksetzen();
      _letztePts = 0;
      _abweichung = 0;
      _alleErgebnisse
        ..clear()
        ..addAll(ergebnisse);
    });
  }

  Future<void> _zwischenstandSpeichern() async {
    await DailyResumeService.speichern(_kId, {
      'idx': _idx,
      'gesamt': _gesamt,
      'ergebnisse': _alleErgebnisse.map((e) => e.toJson()).toList(),
    });
  }

  void _starteFragen() {
    final kat = _heutigeKat;
    final rng = Random(TagesSeedService.seedFuer(_kId));

    // Verschiedene Länder für die tägliche Kategorie
    final pool =
        countryRankings
            .where((c) => (kat.getValue(c) ?? -1) > 0)
            .where((c) => kat.id != 'area' || (c.area ?? 0) >= 0.1)
            .toList()
          ..shuffle(rng);

    final fragen = pool
        .take(_kFragen)
        .map((land) => _Frage(land, kat))
        .toList();

    // EINMAL pro Tages-Runde aus den ECHTEN Werten der tatsächlich gezogenen
    // Länder berechnet — bleibt danach für alle Fragen dieser Runde
    // unverändert (siehe SkalaService.ausRundenWerten).
    final werteDieserRunde = fragen
        .map((f) => f.kat.getValue(f.land)!)
        .toList();
    final sk = fragen.isNotEmpty
        ? SkalaService.ausRundenWerten(kat.id, werteDieserRunde)
        : null;
    final start = sk != null ? sk.wertAn(TagesSeedService.startBruch(0)) : 50.0;

    setState(() {
      _fragen = fragen;
      _idx = 0;
      _skala = sk;
      _sliderVal = start.clamp(sk?.min ?? 0, sk?.max ?? 100);
      _gesamt = 0;
      _fertig = false;
      _beantwortet = false;
      _rastung.ruecksetzen();
      _letztePts = 0;
      _abweichung = 0;
      _neuerRekord = false;
      _alleErgebnisse.clear();
    });
  }

  /// Der Finger zieht den Griff. [p] ist die Position auf dem Balken von 0
  /// bis 1 — dieselbe Einheit, in der auch die Rastung rechnet.
  ///
  /// Wo gerastet wird, entscheidet [ReglerRastung] mit ihrem eigenen feinen
  /// Raster. Früher hing es an den zehn sichtbaren Abschnitten dieser Skala —
  /// über den ganzen Balken also zehn Klicks, was sich leer anfühlte.
  void _ziehen(double p) {
    _rastung.ziehen(anteil: p);
    setState(() => _sliderVal = _skala!.wertAn(p));
  }

  void _bestaetigen() {
    // Nur der Knopfklang. Ob die Schätzung gut war, sagt die Punktzahl —
    // richtig/falsch gibt es in den Tages-Challenges bewusst nicht.
    knopfRueckmeldung();
    final q = _fragen[_idx];
    final real = q.kat.getValue(q.land)!;
    final sk = _skala!;

    // Rundungs-Gleichstand: der Spieler sieht auf dem Slider NUR den
    // formatierten/gerundeten Wert (sk.format), nicht den Rohwert. Runden
    // Schätzung und echter Wert auf denselben angezeigten Text, wirkt eine
    // als "falsch" gewertete Antwort willkürlich, obwohl der Spieler optisch
    // exakt getroffen hat. Nutzt bewusst denselben Formatierer wie die
    // Anzeige (nicht eine separat geschätzte Nachkommastellen-Zahl), damit
    // die Toleranz nie von der tatsächlich sichtbaren Rundung abweicht —
    // gleiches Prinzip wie der Rundungs-Gleichstand in higher_lower_screen.dart.
    final rundungsGleichstand =
        _sliderVal != real && sk.format(_sliderVal) == sk.format(real);

    // Abweichung relativ zur gezeigten Skalenbreite (nicht zum echten Wert)
    // -> macht die Schwierigkeit über alle Kategorien/Länder EINHEITLICH fair
    // vergleichbar, statt Länder mit großen absoluten Werten zu bevorzugen
    // und Zwergstaaten/kleine Werte unfair zu bestrafen. Nutzt exakt dieselbe
    // Skala, die auch für die Slider-Marker-Positionierung gilt. Gilt jetzt
    // AUCH für die Prozent-Kategorien (Inflation, Waldanteil, Korruption,
    // Pressefreiheit) — die vorherige Sonderbehandlung mit fester absoluter
    // Prozentpunkte-Toleranz war über verschiedene Prozent-Kategorien nicht
    // fair vergleichbar (3 Punkte Abweichung bei "Kinder pro Frau", Skala
    // 0-7, ist etwas völlig anderes als 3 Punkte bei "Inflation", Skala kann
    // durch ein Ausreißer-Land 0-70 breit sein). Die skalen-relative Methode
    // berücksichtigt automatisch, wie breit die jeweils gezogene Runden-Skala
    // tatsächlich ist.
    // Der Abstand kommt aus der Skala selbst (SkalaErgebnis.abstand): bei den
    // logarithmischen Kategorien zählt damit das VERHÄLTNIS statt der
    // Differenz, bei allen anderen bleibt es beim Anteil an der Skalenbreite.
    // Der Rundungs-Gleichstand steht bewusst davor und bleibt unberührt — wer
    // optisch exakt trifft, bekommt die volle Punktzahl, auch wenn der Rohwert
    // um ein Tausendstel abweicht.
    final dev = rundungsGleichstand
        ? 0.0
        : sk.abstand(_sliderVal, real).clamp(0.0, 100.0);
    final pts = rundungsGleichstand ? _kMaxPtsProFrage : _punkteFuer(dev);
    _ptsCtrl.forward(from: 0);
    _fahreZurAntwort(sk.positionVon(_sliderVal), sk.positionVon(real));
    setState(() {
      _beantwortet = true;
      _abweichung = dev;
      _letztePts = pts;
      _gesamt += pts;
      _alleErgebnisse.add(
        _SchaetzErgebnis(
          landIso: q.land.iso2,
          landName: q.land.name,
          kategorieLabel: q.kat.label,
          istProzentKategorie: _istProzentKategorie(q.kat.id),
          abweichung: dev,
          punkte: pts,
        ),
      );
    });
  }

  // Kategorien mit fester 0-100-Skala (Prozent/Index-Punkte) — wird NICHT
  // mehr für die Abweichungs-/Punkteberechnung genutzt (die ist jetzt für
  // alle Kategorien einheitlich skalen-relativ, siehe _bestaetigen()),
  // sondern ausschließlich noch für die reine Werte-Anzeige/Rundenskalen-
  // Clamp-Logik in SkalaService (Grenzen der Rundenskala bleiben bei
  // Prozent-Kategorien auf 0-100 begrenzt).
  bool _istProzentKategorie(String id) => SkalaService.istProzentKategorie(id);

  /// Der Belohnungsmoment: Nach dem Bestätigen wandert die Markierung sichtbar
  /// auf den echten Wert, während der eigene Tipp als Pflock stehen bleibt.
  ///
  /// Dieselbe Mechanik wie im Länder-Ranking des Lernpfads — Bauteil, Dauer
  /// und Kurve kommen aus [SchaetzBalken] (widgets/schaetz_balken.dart), damit
  /// sich der Moment an beiden Stellen gleich anfühlt. Hier ist die Achse
  /// stufenlos statt in Rangplätzen; umgerechnet wird über dieselbe Skala,
  /// die auch den Regler bedient.
  void _fahreZurAntwort(double von, double bis) {
    _fahrtAnteil = von;
    _fahrtAnim = Tween<double>(begin: von, end: bis)
        .animate(CurvedAnimation(parent: _fahrt, curve: kFahrtKurve))
      ..addListener(() {
        if (mounted) setState(() => _fahrtAnteil = _fahrtAnim!.value);
      });
    _fahrt.forward(from: 0);
  }

  Future<void> _weiter() async {
    knopfRueckmeldung();
    if (_idx + 1 >= _fragen.length) {
      // Die Runde ist zu Ende.
      //
      // DER SIEG-KLANG STEHT WEITER UNTEN, nicht hier. Er gehörte einmal
      // hierher, damit er unmittelbar auf den Tipp folgt — aber dazwischen
      // liegt das Abzeichen-Popup, und das bringt seinen eigenen Klang mit.
      // Der Sieg-Fanfare lief dadurch hinter der Abzeichen-Animation ab,
      // während beim eigentlichen Ergebnis Stille herrschte. Jetzt: erst die
      // Abzeichen, dann der Klang, dann das Ergebnis.
      _neuerRekord = await ChallengeRekordService.setzeFallsBesser(
        _kId,
        _gesamt,
      );
      await ChallengeRekordService.speichereHeutigePunkte(_kId, _gesamt);
      await ChallengeRekordService.summeErhoehen(_kId, _gesamt.toDouble());
      await RanglisteService.ergebnisSpeichernMitBereinigung(
        challengeId: 'schaetzen',
        wert: _gesamt,
      );
      await DailyChallenge.markDone(_kId);
      await DailyResumeService.loeschen(_kId);
      await ChallengeErgebnisService.speichern(_kId, {
        'ergebnisse': _alleErgebnisse.map((e) => e.toJson()).toList(),
      });
      final neueAbzeichen = await AbzeichenService.pruefeNachChallengeAbschluss(
        heutePerfekt: _gesamt >= _kMaxPts,
        neuerRekordHeute: _neuerRekord,
      );
      if (mounted && neueAbzeichen.isNotEmpty) {
        await AbzeichenPopup.zeigen(context, neueAbzeichen);
      }
      if (!mounted) return;
      setState(() {
        _fertig = true;
        _rekord = _gesamt > (_rekord ?? 0) ? _gesamt : _rekord;
      });
      return;
    }
    final nextIdx = _idx + 1;
    // _skala bleibt für die ganze Runde unverändert (siehe _starteFragen())
    // — hier wird NUR die Slider-Startposition innerhalb dieser festen
    // Skala neu bestimmt, nicht die Skala selbst.
    final sk = _skala!;
    final start = sk.wertAn(TagesSeedService.startBruch(nextIdx));
    // Neue Frage: Fahrt stoppen und die Markierung freigeben, sonst liefe
    // sie beim naechsten Bestaetigen von der alten Stelle los.
    _fahrt.stop();
    _fahrtAnim = null;
    setState(() {
      _idx = nextIdx;
      _sliderVal = start.clamp(sk.min, sk.max);
      _beantwortet = false;
      _rastung.ruecksetzen();
      _letztePts = 0;
      _abweichung = 0;
    });
    _zwischenstandSpeichern();
  }

  // dev = Abweichung in Prozent der gezeigten Skalenbreite (siehe
  // _bestaetigen). Kontinuierliche Exponentialkurve statt fester Stufen:
  // vorher sprang die Punktzahl z.B. von 0,5% bis 1,5% Abweichung konstant
  // bei 95 — 0,6% und 1,4% Abweichung wurden also IDENTISCH bewertet, obwohl
  // 1,4% mehr als doppelt so weit daneben liegt. Mit 100*exp(-dev/17) zählt
  // jede einzelne Abweichungs-Einheit spürbar, statt in Sprüngen zu springen.
  //
  // Divisor 17 wurde per Least-Squares gegen die alte Stufen-Funktion an den
  // Referenzpunkten [0,1,3,5,8,12,18,25,35,50]% kalibriert (kleinster
  // quadratischer Fehler bei D≈16,9, auf 17 gerundet) — trifft die alten
  // ungefähren Eckpunkte weiterhin (0%→100, ~5%→75, ~12%→49, ~18%→35 exakt,
  // ~35%→13), fühlt sich also insgesamt weder strenger noch großzügiger an
  // als vorher, differenziert aber jeden Zwischenwert fein statt stufig:
  //   dev   0%   1%   3%   5%   8%  12%  18%  25%  35%  50%
  //   alt  100   95   88   78   65   50   35   20    8    0
  //   neu  100   94   84   75   62   49   35   23   13    5
  int _punkteFuer(double dev) {
    final punkte = _kMaxPtsProFrage * exp(-dev / 17);
    return punkte.round().clamp(0, _kMaxPtsProFrage);
  }
  // Die Kurzbewertung ("Sehr gut!", "Weiter üben!") ist entfallen: Sie
  // gehörte in den Kopf der alten Ergebniskarte. Die Auflösung auf dem
  // Regler kommt mit Punktzahl und Abweichung aus.


  Color _farbe(int p) {
    if (p >= 90) return const Color(0xFF4A9E4A);
    if (p >= 70) return const Color(0xFF7CB342);
    if (p >= 50) return const Color(0xFFF9A825);
    if (p >= 30) return const Color(0xFFF57C00);
    return const Color(0xFFE53935);
  }

  // Ganzzahlige Rundung würde bei sehr kleinen Werten (z.B. Tourismus-
  // einnahmen/Militärausgaben winziger Länder) fälschlich "0" anzeigen,
  // obwohl der Wert ungleich null ist — dann fest auf 2 Nachkommastellen
  // ausweichen, sonst ganzzahlig runden wie gewohnt.
  String _fmtGerundetOderZweiDezimal(double v, String einheit) {
    final en = LocaleService.istEnglisch;
    if (v == 0) return '0 $einheit';
    if (v.round() == 0) {
      final s = v.toStringAsFixed(2);
      return '${en ? s : s.replaceAll('.', ',')} $einheit';
    }
    return '${v.round()} $einheit';
  }

  // Geldbeträge in Milliarden USD — Deutsch bleibt "X Mrd. USD", Englisch
  // wird als "$X billion" ausgeschrieben (Dollarzeichen vorangestellt statt
  // nachgestelltem "USD", wie in natürlichem Englisch üblich).
  String _fmtGeldMrd(double milliardenWert) {
    final zahl = _fmtGerundetOderZweiDezimal(milliardenWert, '').trim();
    return LocaleService.istEnglisch ? '\$$zahl billion' : '$zahl Mrd. USD';
  }

  // Englisches Ordinal-Suffix (1st, 2nd, 3rd, 4th, 11th, 21st, ...) — die
  // 11./12./13. sind Sonderfälle (immer "th"), sonst entscheidet die letzte
  // Ziffer.
  String _ordinalSuffixEn(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  // Lokalisierte Ordnungszahl für Ranglisten-Platzierungen in Fließtext
  // ("5.-größte" / "5th largest").
  String _rangOrdinal(int rank) {
    if (LocaleService.istEnglisch) return '$rank${_ordinalSuffixEn(rank)}';
    return '$rank.';
  }

  String _fakt(_Frage q, double realVal) {
    final pool =
        countryRankings.where((c) => (q.kat.getValue(c) ?? -1) > 0).toList()
          ..sort((a, b) {
            final av = q.kat.getValue(a)!;
            final bv = q.kat.getValue(b)!;
            return bv.compareTo(av);
          });
    final rank = pool.indexWhere((c) => c.iso2 == q.land.iso2) + 1;
    final name = q.land.name;
    final rankStr = '$rank';
    switch (q.kat.id) {
      case 'gdpPerCapita':
        return rank <= 3
            ? t(
                '{name} gehört zu den reichsten Ländern der Welt (Platz {rank}).',
                {'name': name, 'rank': rankStr},
              )
            : t('{name} liegt auf Platz {rank} beim BIP pro Kopf.', {
                'name': name,
                'rank': rankStr,
              });
      case 'population':
        return rank == 1
            ? t('{name} ist das bevölkerungsreichste Land der Welt.', {
                'name': name,
              })
            : t(
                '{name} ist das {rankOrd}-bevölkerungsreichste Land der Welt.',
                {'name': name, 'rankOrd': _rangOrdinal(rank)},
              );
      case 'area':
        return rank == 1
            ? t('{name} ist das größte Land der Welt nach Fläche.', {
                'name': name,
              })
            : t('{name} ist das {rankOrd}-größte Land der Welt.', {
                'name': name,
                'rankOrd': _rangOrdinal(rank),
              });
      case 'lifeExpectancy':
        return rank <= 5
            ? t(
                'Die Lebenserwartung in {name} gehört zu den höchsten weltweit.',
                {'name': name},
              )
            : t('In {name} leben die Menschen im Schnitt {val} Jahre.', {
                'name': name,
                'val': realVal.toStringAsFixed(1),
              });
      case 'minimumWage':
        return rank <= 3
            ? t(
                '{name} hat einen der höchsten Mindestlöhne der Welt (Platz {rank}).',
                {'name': name, 'rank': rankStr},
              )
            : t(
                'In {name} liegt der Mindestlohn bei {val} USD im Monat (Platz {rank}).',
                {'name': name, 'val': '${realVal.round()}', 'rank': rankStr},
              );
      case 'coastline':
        return rank == 1
            ? t('{name} hat die längste Küstenlinie der Welt.', {'name': name})
            : t('{name} hat eine Küstenlinie von {val} km (Platz {rank}).', {
                'name': name,
                'val': '${realVal.round()}',
                'rank': rankStr,
              });
      case 'gdpTotal':
        return rank <= 3
            ? t(
                '{name} gehört zu den größten Volkswirtschaften der Welt (Platz {rank}).',
                {'name': name, 'rank': rankStr},
              )
            : t('{name} erwirtschaftet ein BIP von {val} (Platz {rank}).', {
                'name': name,
                'val': _fmtGeldMrd(realVal / 1e9),
                'rank': rankStr,
              });
      case 'internet':
        return rank <= 5
            ? t(
                '{name} gehört zu den schnellsten Ländern beim Internet (Platz {rank}).',
                {'name': name, 'rank': rankStr},
              )
            : t(
                '{name} hat eine Download-Geschwindigkeit von {val} Mbps (Platz {rank}).',
                {'name': name, 'val': '${realVal.round()}', 'rank': rankStr},
              );
      case 'corruption':
        return rank <= 5
            ? t(
                '{name} ist eines der am wenigsten korrupten Länder weltweit (Platz {rank}).',
                {'name': name, 'rank': rankStr},
              )
            : t(
                '{name} erreicht {val} von 100 Punkten im Korruptionsindex (Platz {rank}).',
                {'name': name, 'val': '${realVal.round()}', 'rank': rankStr},
              );
      case 'press_freedom':
        return rank <= 5
            ? t(
                '{name} gehört zu den pressefreiesten Ländern der Welt (Platz {rank}).',
                {'name': name, 'rank': rankStr},
              )
            : t(
                '{name} erreicht {val} von 100 Punkten beim Pressefreiheitsindex (Platz {rank}).',
                {'name': name, 'val': '${realVal.round()}', 'rank': rankStr},
              );
      case 'happiness':
        return rank == 1
            ? t('{name} ist das glücklichste Land der Welt.', {'name': name})
            : t(
                '{name} liegt auf Platz {rank} im World Happiness Report (Score: {val}).',
                {
                  'name': name,
                  'rank': rankStr,
                  'val': realVal.toStringAsFixed(2),
                },
              );
      case 'tourism':
        return rank <= 3
            ? t(
                '{name} gehört zu den top Reisezielen weltweit (Platz {rank} nach Einnahmen).',
                {'name': name, 'rank': rankStr},
              )
            : t('{name} erwirtschaftet {val} durch Tourismus (Platz {rank}).', {
                'name': name,
                'val': _fmtGeldMrd(realVal),
                'rank': rankStr,
              });
      case 'military':
        return rank == 1
            ? t('{name} hat das größte Militärbudget der Welt.', {'name': name})
            : t('{name} gibt {val} für das Militär aus (Platz {rank}).', {
                'name': name,
                'val': _fmtGeldMrd(realVal),
                'rank': rankStr,
              });
      case 'birth_rate':
        return rank == 1
            ? t('{name} hat die höchste Geburtenrate weltweit.', {'name': name})
            : t(
                'In {name} kommen im Schnitt {val} Kinder pro Frau zur Welt (Platz {rank}).',
                {
                  'name': name,
                  'val': realVal.toStringAsFixed(1),
                  'rank': rankStr,
                },
              );
      case 'forest':
        return rank <= 5
            ? t(
                '{name} gehört zu den waldreichsten Ländern der Welt (Platz {rank}).',
                {'name': name, 'rank': rankStr},
              )
            : t(
                '{val} der Fläche von {name} sind von Wald bedeckt (Platz {rank}).',
                {
                  'val': _fmtGerundetOderZweiDezimal(realVal, '%'),
                  'name': name,
                  'rank': rankStr,
                },
              );
      case 'alcohol':
        return rank <= 3
            ? t(
                '{name} gehört zu den Ländern mit dem höchsten Alkoholkonsum der Welt (Platz {rank}).',
                {'name': name, 'rank': rankStr},
              )
            : t(
                'In {name} werden im Schnitt {val} Liter Alkohol pro Kopf getrunken (Platz {rank}).',
                {
                  'name': name,
                  'val': realVal.toStringAsFixed(1),
                  'rank': rankStr,
                },
              );
      case 'olympics':
        return rank == 1
            ? t('{name} hat die meisten Olympia-Medaillen aller Zeiten.', {
                'name': name,
              })
            : t(
                '{name} hat {val} olympische Medaillen gewonnen (Platz {rank}).',
                {'name': name, 'val': '${realVal.round()}', 'rank': rankStr},
              );
      case 'highest_point':
        return rank == 1
            ? t('{name} hat den höchsten Punkt der Welt.', {'name': name})
            : t(
                'Der höchste Punkt in {name} liegt auf {val} m (Platz {rank}).',
                {'name': name, 'val': '${realVal.round()}', 'rank': rankStr},
              );
      case 'inflation':
        return rank == 1
            ? t('{name} hat die höchste Inflationsrate der Welt.', {
                'name': name,
              })
            : t(
                'Die Inflationsrate in {name} liegt bei {val} % (Platz {rank}).',
                {
                  'name': name,
                  'val': realVal.toStringAsFixed(1),
                  'rank': rankStr,
                },
              );
      case 'debt':
        return rank == 1
            ? t(
                '{name} hat die höchsten Staatsschulden relativ zur Wirtschaftsleistung.',
                {'name': name},
              )
            : t(
                'Die Staatsschulden in {name} liegen bei {val} % des BIP (Platz {rank}).',
                {'name': name, 'val': '${realVal.round()}', 'rank': rankStr},
              );
      default:
        return t('{name} liegt auf Platz {rank} bei {kat}.', {
          'name': name,
          'rank': rankStr,
          'kat': q.kat.label,
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kHintergrund,
      appBar: AppBar(
        backgroundColor: kHintergrund,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => ChallengePanelSignal.zurueckZumPanel(context),
        ),
        // FittedBox um beide Zeilen: bei grosser Systemschrift passte der
        // Spielname nicht mehr in die Kopfzeile und wurde abgeschnitten
        // (gemessen ab Skala 1.3). Er wird jetzt so weit verkleinert, dass er
        // ganz dasteht — bei normaler Schriftgroesse aendert sich nichts,
        // denn scaleDown vergroessert nie. Gleiche Loesung wie bei der
        // Ueberschrift der Einstellungen.
        // Der TITEL steht links neben dem Zurück-Pfeil, wie im Ranking Quiz;
        // die KATEGORIE darunter bleibt mittig, wie sie es immer war.
        //
        // Dafür braucht die Spalte CrossAxisAlignment.stretch: Sonst wäre sie
        // nur so breit wie ihr breitestes Kind, und "mittig" hiesse mittig
        // unter dem Titel statt mittig in der Leiste. Gestreckt bekommen
        // beide FittedBoxen die volle Breite der Titelzone und richten ihren
        // Text darin selbst aus.
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // WÄHREND DER RUNDE steht in der Leiste nur die Punktzahl. Der
            // Spielname ist raus wie in den drei anderen Challenges, und die
            // Kategorie ebenfalls: Sie steht auf der Länderkarte darunter als
            // grüne Pille, in der Kopfzeile war sie doppelt.
            //
            // AUF DEM ERGEBNIS-SCHIRM trägt die Leiste den Spielnamen und
            // darunter die Kategorie. Dort gibt es keine Länderkarte mehr, die
            // die Kategorie zeigen könnte, und die Leiste stünde sonst leer.
            if (_fertig) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  t('Das große Schätzen'),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _heutigeKat.label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ] else if (_gesamt > 0)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  t('{n} Pkt.', {'n': '$_gesamt'}),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ErklaerungButton(
              titel: t('Das große Schätzen — Spielregeln'),
              farbe: const Color(0xFFF9A825),
              abschnitte: [
                t(
                  'Zu einem Land und einer Kategorie (z.B. Bevölkerung, BIP pro Kopf) siehst du eine Skala mit einem Schieberegler.',
                ),
                t(
                  'Bewege den Regler auf die Position, an der du den echten Wert vermutest, und bestätige deine Schätzung.',
                ),
                t(
                  'Je näher deine Schätzung am tatsächlichen Wert liegt, desto mehr Punkte bekommst du für diese Frage.',
                ),
                // Alltagssprachlich formuliert: keine Rede von Logarithmus,
                // Verhältnis oder Skalentyp. Es soll nur erklären, warum bei
                // Bevölkerung oder Fläche "knapp daneben" etwas anderes
                // bedeutet als bei Lebenserwartung.
                t(
                  'Bei Kategorien mit sehr großen Unterschieden — etwa Fläche oder Bevölkerung — kommt es darauf an, wie oft deine Schätzung in den echten Wert passt, nicht wie viel dazwischenliegt. Das Doppelte zu raten ist dort immer gleich weit daneben, egal ob es um 40 oder um 40 Millionen geht.',
                ),
                t(
                  'Das Spiel besteht aus mehreren Fragen hintereinander — am Ende siehst du deine Gesamtpunktzahl und alle Antworten im Überblick.',
                ),
              ],
            ),
          ),
        ],
      ),
      body: _fertig ? _buildErgebnis() : _buildQuiz(),
    );
  }

  // ── Quiz ──────────────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    if (_fragen.isEmpty || _skala == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4A9E4A)),
      );
    }
    final q = _fragen[_idx];
    final realVal = q.kat.getValue(q.land)!;
    final sk = _skala!;

    // EINE LAGE für beide Zustände.
    //
    // Der Block sitzt mittig im verbleibenden Platz, etwas über der
    // geometrischen Mitte. Der Versatz nach oben entsteht dadurch, dass die
    // ConstrainedBox eine um das Doppelte von [nachOben] kürzere Mindesthöhe
    // bekommt: Die Spalte zentriert sich in einem kleineren Kasten, der oben
    // am Sichtfeld beginnt.
    //
    // KEINE Fallunterscheidung mehr nach [_beantwortet]. Sie stand hier,
    // solange die Auflösung eine eigene, viel höhere Ansicht war. Seit sie auf
    // dem Regler stattfindet und ihre Zeilen ihren Platz schon vorher
    // freihalten, ist der Block in beiden Zuständen exakt gleich hoch — eine
    // Umschaltung würde ihn nur ohne Not verschieben.
    const rand = EdgeInsets.fromLTRB(20, 10, 20, 32);
    const nachOben = 36.0;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, platz) => SingleChildScrollView(
          padding: rand,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (platz.maxHeight - rand.vertical - 2 * nachOben)
                  .clamp(0.0, double.infinity),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Das Rekord-Banner stand hier und ist raus: Während der Runde
                // hilft der eigene Bestwert nicht — er lenkt vom Schätzen ab
                // und drückte den Rest der Seite nach unten. Inzwischen ist er
                // auch vom Ergebnis-Schirm verschwunden, in allen vier
                // Challenges.

                // ── Fortschritt ──────────────────────────────────────────────
                Row(
                  children: List.generate(_fragen.length, (i) {
                    final col = i < _idx
                        ? const Color(0xFF4A9E4A)
                        : i == _idx
                        ? const Color(0xFF4A9E4A).withValues(alpha: 0.4)
                        : const Color(0xFFD0D0CB);
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 5,
                        decoration: BoxDecoration(
                          color: col,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    t('Frage {a} von {b}', {
                      'a': '${_idx + 1}',
                      'b': '${_fragen.length}',
                    }),
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Länder-Karte ─────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 22,
                    horizontal: 20,
                  ),
                  child: Column(
                    children: [
                      zeigeFlagge(
                        q.land.iso2,
                        width: 80,
                        height: 54,
                        borderRadius: 6,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        q.land.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A9E4A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          q.kat.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Regler und Auflösung ─────────────────────────────────────
                //
                // EIN Block für beide Zustände, nicht zwei, die einander
                // ablösen.
                //
                // Vorher verschwand nach dem Bestätigen die ganze Regler-
                // Ansicht und an ihrer Stelle stand eine grosse Ergebniskarte
                // mit eigenem Rahmen, eigenem Punkte-Kopf und einer zweiten,
                // kleineren Skala darin. Der Sprung war so gross, dass es sich
                // wie ein anderer Screen anfühlte — obwohl dieselbe Frage
                // gemeint war.
                //
                // Jetzt bleibt der Regler stehen und löst sich AUF SICH SELBST
                // auf: Der Tipp bleibt als Pflock, eine zweite Markierung
                // fährt zum echten Wert, dazwischen liegt der Abstand. Es ist
                // buchstäblich derselbe Balken, der im Lernpfad den
                // Länder-Ranking-Modus bedient ([SchaetzBalken]).
                //
                // ALLES, WAS NACH DEM BESTÄTIGEN DAZUKOMMT, HÄLT SCHON VORHER
                // SEINEN PLATZ: Die Zeilen stehen in einem Visibility mit
                // maintainSize, sind also unsichtbar, aber vermessen. Dadurch
                // rückt beim Auflösen nichts — der Knopf bleibt, wo er war.
                Center(
                  child: Text(
                    sk.format(_sliderVal),
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    t('Deine Schätzung'),
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Der Balken rechnet in Anteilen von 0 bis 1 — welche Achse
                // dahinter steht, weiss allein die Skala. Bei linearen
                // Kategorien ist die Umrechnung die Identität; bei den
                // logarithmischen sitzen die Stufen auf gleichen
                // VERHÄLTNISSEN statt gleichen Differenzen, sodass sich die
                // Länder nicht im linken Zehntel drängen.
                SchaetzBalken(
                  anteil: _beantwortet
                      ? _fahrtAnteil
                      : sk.positionVon(_sliderVal),
                  marken: markenGleichmaessig(_kSkalenAbschnitte),
                  geraten: _beantwortet ? sk.positionVon(_sliderVal) : null,
                  echt: _beantwortet ? sk.positionVon(realVal) : null,
                  onZiehen: _beantwortet ? null : _ziehen,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sk.format(sk.min),
                      style: const TextStyle(
                        color: Color(0xFFBBBBBB),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      sk.format(sk.max),
                      style: const TextStyle(
                        color: Color(0xFFBBBBBB),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Der echte Wert und die Punkte — ergänzend zum Balken, nicht
                // an seiner Stelle.
                Visibility(
                  visible: _beantwortet,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  // ALLE DREI ZEILEN EINZEILIG, notfalls verkleinert.
                  //
                  // Der freigehaltene Platz stimmt nur, solange keine Zeile
                  // umbricht. Vor dem Bestätigen stehen dort Platzhalterwerte
                  // (0 Punkte, 0,0 % Abweichung) — die sind kürzer als die
                  // echten, und auf 320 px bei Schriftskala 1.5 brach die
                  // Abweichungszeile beim Auflösen auf zwei Zeilen um. Der
                  // Knopf sprang dadurch um 26 px nach unten.
                  child: Column(
                    // Gestreckt, damit die FittedBoxen die volle Breite
                    // bekommen und ihren Text darin mittig setzen — die
                    // äussere Spalte richtet links aus.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          t('Richtiger Wert: {v}', {'v': sk.format(realVal)}),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFF4A9E4A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Die Punktzahl bekommt den einzigen Effekt der Seite:
                      // einen kurzen Sprung. ScaleTransition zeichnet nur
                      // anders, es verändert den Platzbedarf nicht — die Zeile
                      // darunter bleibt also stehen.
                      ScaleTransition(
                        scale: _ptsAnim,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            t('+{n} Punkte', {'n': '$_letztePts'}),
                            maxLines: 1,
                            style: TextStyle(
                              color: _farbe(_letztePts),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          t('Abweichung: {n} % der Skala', {
                            'n': LocaleService.istEnglisch
                                ? _abweichung.toStringAsFixed(1)
                                : _abweichung
                                    .toStringAsFixed(1)
                                    .replaceAll('.', ','),
                          }),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Der Fakt zur Frage. Auch er hält seinen Platz vorher schon
                // frei — sein Text steht ja fest, sobald die Frage steht.
                Visibility(
                  visible: _beantwortet,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAEAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Color(0xFF888888),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fakt(q, realVal),
                            style: const TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Derselbe Knopf für beide Zustände, an derselben Stelle —
                // nur die Beschriftung und das Ziel wechseln.
                GestureDetector(
                  onTap: _beantwortet ? _weiter : _bestaetigen,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9E4A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      !_beantwortet
                          ? t('Bestätigen')
                          : _idx + 1 >= _fragen.length
                              ? t('Ergebnis anzeigen')
                              : t('Weiter →'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Ergebnis ──────────────────────────────────────────────────────────────

  Widget _buildErgebnis() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              children: [
                // Der eigene Bestwert stand hier und ist raus — in allen vier
                // Challenges (siehe ranking_game_screen.dart). Die Überschrift
                // "Ergebnis" in der Kopfzeile tritt an seine Stelle.
                const SizedBox(height: 8),
                RanglisteErgebnisKarte(
                  challengeId: 'schaetzen',
                  eigenerWert: _gesamt,
                  punkteLabel: t('Gesamtpunktzahl'),
                  farbe: const Color(0xFFF9A825),
                  punkteAnzeige: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$_gesamt',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        TextSpan(
                          text: ' / $_kMaxPts',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB0AEA8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Divider(color: Color(0xFFD0CEC8)),
          ),
          const SizedBox(height: 4),
          // Der Verlauf als wischbarer Kartenstapel statt als Scrollliste —
          // dieselbe Bauform wie bei den anderen drei Tages-Challenges und
          // beim Willkommens-Screen (siehe ergebnis_karten.dart). Kopf,
          // Punktzahl und Fertig-Knopf bleiben, wo sie waren.
          Expanded(
            child: _alleErgebnisse.isEmpty
                ? const SizedBox.shrink()
                : Builder(builder: (context) {
                    // ALLE FÜNF RUNDEN AUF EINE KARTE — dafür musste die
                    // Zeile schrumpfen, nicht die Rechnung geschönt werden:
                    // Der Innenrand ist von 12 auf 9 herunter, und die
                    // Kategorie ist aus der Unterzeile raus (siehe
                    // _ErgebnisZeile). Damit ist eine Zeile rund 56 statt 80
                    // hoch, und fünf passen auf ein Blatt.
                    //
                    // Bei sehr grosser Systemschrift rechnet dieselbe Formel
                    // wieder auf zwei Karten herunter. Das ist richtig so —
                    // eine überfüllte Karte wäre schlechter als eine zweite.
                    final proKarte = wischZeilenProKarte(context,
                        zeilenHoehe: 56, abzugOben: 230);
                    final gruppen = <List<_SchaetzErgebnis>>[];
                    for (var i = 0; i < _alleErgebnisse.length; i += proKarte) {
                      gruppen.add(_alleErgebnisse.sublist(
                          i,
                          i + proKarte > _alleErgebnisse.length
                              ? _alleErgebnisse.length
                              : i + proKarte));
                    }
                    return WischKartenStapel(
                      karten: [
                        for (final gruppe in gruppen)
                          (context, hoehe) => _ErgebnisListeKarte(
                                ergebnisse: gruppe,
                                farbe: _farbe,
                              ),
                      ],
                    );
                  }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ChallengeFertigButton(
              onTap: () => ChallengePanelSignal.zurueckZumPanel(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ergebnis-Liste (alle Fragen der Runde) ───────────────────────────────────

/// Eine Karte des Verlaufs: die Runden dieses Ausschnitts.
///
/// Trug vorher den harten 3D-Rahmen der App (schwarzer Rand, versetzter
/// Schatten). Als Wischkarte nimmt sie die ruhigere [WischKarte] — ein
/// Schlagschatten machte aus dem Blatt ein Objekt, das über der Fläche
/// schwebt, und beim Wischen wanderte er mit.
///
/// OHNE ÜBERSCHRIFT und mit gleichmässig verteilten Zeilen: Die Runden stehen
/// in derselben Reihenfolge, in der sie gespielt wurden, und die Nummern
/// ergeben sich daraus von selbst — „Runden 1–5" sagte nichts, was die Karte
/// nicht ohnehin zeigt, und drückte die Zeilen an den oberen Rand. Der Platz
/// gehört jetzt ihnen: [MainAxisAlignment.spaceEvenly] verteilt sie über die
/// ganze Kartenhöhe, mit gleichen Abständen oben, dazwischen und unten.
///
/// KEIN Notfall-Scrollen hier: Ein Scrollbereich hat keine feste Höhe, und
/// ohne feste Höhe kann spaceEvenly nichts verteilen. Dass es trotzdem passt,
/// sichert die Zeilenrechnung in [_buildErgebnis] — bei grosser Schrift gibt
/// sie weniger Zeilen je Karte aus, statt eine Karte zu überfüllen.
class _ErgebnisListeKarte extends StatelessWidget {
  final List<_SchaetzErgebnis> ergebnisse;
  final Color Function(int) farbe;

  const _ErgebnisListeKarte({
    required this.ergebnisse,
    required this.farbe,
  });

  @override
  Widget build(BuildContext context) {
    return WischKarte(
      innenrand: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in ergebnisse)
            _ErgebnisZeile(ergebnis: e, farbe: farbe(e.punkte)),
        ],
      ),
    );
  }
}

class _ErgebnisZeile extends StatelessWidget {
  final _SchaetzErgebnis ergebnis;
  final Color farbe;

  const _ErgebnisZeile({required this.ergebnis, required this.farbe});

  @override
  Widget build(BuildContext context) {
    // Jetzt für ALLE Kategorien einheitlich skalen-relativ (siehe
    // _bestaetigen() in _PreisSchaetzenScreenState).
    final abweichungText = t('{n} % der Skala daneben', {
      'n': LocaleService.istEnglisch
          ? ergebnis.abweichung.toStringAsFixed(1)
          : ergebnis.abweichung.toStringAsFixed(1).replaceAll('.', ','),
    });
    return Padding(
      // 9 statt 12 senkrecht: Damit alle fünf Runden auf EINE Karte passen
      // und der Stapel nicht wegen einer einzigen überzähligen Zeile auf zwei
      // Karten geht. Siehe auch die Zeilenhöhe in _buildErgebnis().
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          zeigeFlagge(ergebnis.landIso, width: 36, height: 24, borderRadius: 4),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ergebnis.landName,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                // OHNE die Kategorie. Eine Runde hat nur EINE Kategorie
                // ([_heutigeKat], siehe _starteFragen), und die steht bereits
                // in der Kopfzeile über dem Ergebnis. In jeder Zeile wiederholt
                // brach der Text auf schmalen Schirmen um und machte die Zeile
                // eine ganze Textzeile höher — genau die Höhe, an der die
                // fünfte Runde von der Karte fiel.
                Text(
                  abweichungText,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${ergebnis.punkte}',
            style: TextStyle(
              color: farbe,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
