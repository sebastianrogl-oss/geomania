import 'dart:convert';
import 'dart:math';
import '../data/alle_laender.dart';
import '../data/countries.dart';
import '../data/country_rankings.dart';
import '../data/currencies.dart';
import '../data/economic_blocks.dart';
import '../data/laender_fakten.dart';
import '../data/laender_gebaeude.dart';
import '../data/laender_grenzketten.dart';
import '../data/laender_nachbarn.dart';
import '../data/lernpfad_data.dart';
import '../data/wirtschaftssektoren.dart';
import '../l10n/uebersetzungen.dart';
import '../l10n/waehrungen_kuerzel_en.dart';
import '../l10n/wirtschaftssektoren_en.dart';
import 'locale_service.dart';
import 'antwort_generator.dart';
import 'fortschritt_service.dart';
import 'skala_service.dart';
import 'tages_seed_service.dart';

final _rng = Random();

// ── Frage ─────────────────────────────────────────────────────────────────────

class Frage {
  final String id;
  final String frage;
  final String richtigeAntwort;
  List<String> antwortOptionen;
  final LernModus modus;
  /// ISO2 des Landes das angezeigt/gefragt wird.
  final String laenderCode;
  /// Zusatzdaten je nach Modus (Einheit, Skala, Kategorie, …)
  final Map<String, dynamic> meta;
  int falschBeantwortet;

  Frage({
    required this.id,
    required this.frage,
    required this.richtigeAntwort,
    required this.antwortOptionen,
    required this.modus,
    required this.laenderCode,
    Map<String, dynamic>? meta,
    this.falschBeantwortet = 0,
  }) : meta = meta ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'frage': frage,
        'richtigeAntwort': richtigeAntwort,
        'antwortOptionen': antwortOptionen,
        'modus': modus.name,
        'laenderCode': laenderCode,
        'meta': meta,
        'falschBeantwortet': falschBeantwortet,
      };

  factory Frage.fromJson(Map<String, dynamic> json) => Frage(
        id: json['id'] as String,
        frage: json['frage'] as String,
        richtigeAntwort: json['richtigeAntwort'] as String,
        antwortOptionen:
            (json['antwortOptionen'] as List<dynamic>).cast<String>(),
        modus: LernModus.values.firstWhere(
          (m) => m.name == json['modus'],
          orElse: () => LernModus.flaggenQuizBild,
        ),
        laenderCode: json['laenderCode'] as String? ?? '',
        meta: Map<String, dynamic>.from(json['meta'] as Map? ?? {}),
        falschBeantwortet: json['falschBeantwortet'] as int? ?? 0,
      );
}

// ── StationSession ────────────────────────────────────────────────────────────

class StationSession {
  final String stationId;
  final bool istWiederholungsRunde;
  final bool hatTimer;

  List<Frage> aktiveFragen;
  List<Frage> falscheFragen;
  int aktuellerIndex;
  int richtigeAntworten;
  int falscheAntworten;

  /// Grundlage der Sternevergabe: JEDE Frage zählt genau einmal, sobald sie
  /// beantwortet ist — richtig oder falsch.
  ///
  /// Bis eben war das schlicht [richtigeAntworten], und das ging auf, weil
  /// eine falsche Frage so lange zurück in die Warteschlange wanderte, bis
  /// sie stimmte: Am Ende war jede Frage einmal richtig. Für die Modi in
  /// [kOhneWiederholung] gilt das nicht mehr — dort ist eine falsche Antwort
  /// endgültig. Ohne diesen Zähler würde eine Station mit 6 Fragen und einem
  /// Fehler nur noch 5 Sterne geben, obwohl sich an der Station nichts
  /// geändert hat.
  int sterneBasis;

  StationSession({
    required this.stationId,
    required this.aktiveFragen,
    this.istWiederholungsRunde = false,
    this.hatTimer = false,
    List<Frage>? falscheFragen,
    this.aktuellerIndex = 0,
    this.richtigeAntworten = 0,
    this.falscheAntworten = 0,
    this.sterneBasis = 0,
  }) : falscheFragen = falscheFragen ?? [];

  Frage? get aktuelleFrage =>
      aktuellerIndex < aktiveFragen.length ? aktiveFragen[aktuellerIndex] : null;

  bool get istFertig => aktuellerIndex >= aktiveFragen.length;

  double get fortschritt {
    if (aktiveFragen.isEmpty) return 1.0;
    return (aktuellerIndex / aktiveFragen.length).clamp(0.0, 1.0);
  }

  // ── Antwort-Logik ──────────────────────────────────────────────────────────

  void richtigeAntwortVerarbeiten() {
    richtigeAntworten++;
    // Ohne Bedingung, und das ist kein Versehen: Richtig beantwortet wird
    // jede Frage höchstens einmal — danach ist sie aus der Warteschlange
    // raus, und ein Duplikat lässt falscheAntwortVerarbeiten() gar nicht erst
    // entstehen. Bei den Modi mit Wiederholung ist das zugleich der einzige
    // Zeitpunkt, an dem die Frage für die Sterne zählt.
    sterneBasis++;
    aktuellerIndex++;
  }

  /// FALSCHE ANTWORT: Frage genau einmal ans Ende hängen (kein Duplikat).
  ///
  /// AUSSER bei den Modi in [kOhneWiederholung] — dort ist der Fehler
  /// endgültig und es geht zur nächsten Frage. Wer eine Einwohnerzahl daneben
  /// geschätzt oder ein Länder-Ranking falsch sortiert hat, lernt nichts
  /// daraus, dieselbe Aufgabe direkt noch einmal vorgelegt zu bekommen —
  /// er hat die Lösung ja gerade gesehen.
  void falscheAntwortVerarbeiten() {
    final frage = aktuelleFrage;
    if (frage == null) return;
    falscheAntworten++;
    final ohneWiederholung = kOhneWiederholung.contains(frage.modus);
    // Für die Sterne zählt die Frage genau einmal. Bei den Modi MIT
    // Wiederholung passiert das erst, wenn sie richtig beantwortet ist;
    // hier ist es der einzige Zeitpunkt, an dem sie überhaupt vorkommt.
    if (ohneWiederholung && frage.falschBeantwortet == 0) sterneBasis++;
    frage.falschBeantwortet++;
    frage.antwortOptionen = List.from(frage.antwortOptionen)..shuffle(_rng);
    if (!ohneWiederholung) {
      // Nur anhängen wenn noch kein Duplikat dieser Frage in der Queue wartet
      final nochNichtDrin = !aktiveFragen
          .skip(aktuellerIndex + 1)
          .any((f) => f.id == frage.id);
      if (nochNichtDrin) aktiveFragen.add(frage);
      // falscheFragen ist der Pool der WIEDERHOLUNGSRUNDE am Abschnittsende
      // (siehe falscheFragenAlsJson und FortschrittService.
      // sammelFalscheFragenFuerAbschnitt). Dieselbe Auswahl, derselbe Grund.
      if (!falscheFragen.any((f) => f.id == frage.id)) {
        falscheFragen.add(frage);
      }
    }
    aktuellerIndex++;
  }

  /// TIMER abgelaufen → wie falsche Antwort.
  void timerAbgelaufen() => falscheAntwortVerarbeiten();

  /// JSON der falschen Fragen (für Abschnitts-Wiederholung).
  String falscheFragenAlsJson() =>
      jsonEncode(falscheFragen.map((f) => f.toJson()).toList());

  // ── Serialisierung ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'stationId': stationId,
        'istWiederholungsRunde': istWiederholungsRunde,
        'hatTimer': hatTimer,
        'aktiveFragen': aktiveFragen.map((f) => f.toJson()).toList(),
        'falscheFragen': falscheFragen.map((f) => f.toJson()).toList(),
        'aktuellerIndex': aktuellerIndex,
        'richtigeAntworten': richtigeAntworten,
        'falscheAntworten': falscheAntworten,
        'sterneBasis': sterneBasis,
      };

  factory StationSession.fromJson(Map<String, dynamic> json) => StationSession(
        stationId: json['stationId'] as String,
        aktiveFragen: (json['aktiveFragen'] as List<dynamic>)
            .map((e) => Frage.fromJson(e as Map<String, dynamic>))
            .toList(),
        falscheFragen: (json['falscheFragen'] as List<dynamic>)
            .map((e) => Frage.fromJson(e as Map<String, dynamic>))
            .toList(),
        istWiederholungsRunde:
            json['istWiederholungsRunde'] as bool? ?? false,
        hatTimer: json['hatTimer'] as bool? ?? false,
        aktuellerIndex: json['aktuellerIndex'] as int? ?? 0,
        richtigeAntworten: json['richtigeAntworten'] as int? ?? 0,
        falscheAntworten: json['falscheAntworten'] as int? ?? 0,
        // Sessions, die vor der Umstellung unterbrochen wurden, kennen das
        // Feld nicht. Dort war die Sternegrundlage genau richtigeAntworten —
        // damit läuft eine angefangene Station sauber zu Ende.
        sterneBasis: json['sterneBasis'] as int? ??
            json['richtigeAntworten'] as int? ??
            0,
      );

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> speichernFortschritt() async {
    await FortschrittService.stationFortschrittSpeichern(
      stationId,
      aktuellerIndex: aktuellerIndex,
      aktiveFragenJson: jsonEncode(toJson()),
    );
  }

  /// Lädt eine unterbrochene Session — null wenn keine vorhanden.
  static Future<StationSession?> laden(String stationId) async {
    final data = await FortschrittService.ladeStationFortschritt(stationId);
    if (data == null) return null;
    try {
      final decoded = jsonDecode(data['aktivJson'] as String);
      return StationSession.fromJson(decoded as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Neue Session für die Abschnitts-Wiederholungsrunde.
  static StationSession fuerWiederholungsrunde(
    String abschnittId,
    String falscheFragenJson,
  ) {
    final fragen = (jsonDecode(falscheFragenJson) as List<dynamic>)
        .map((e) => Frage.fromJson(e as Map<String, dynamic>))
        .toList()
      ..shuffle(_rng);
    return StationSession(
      stationId: '${abschnittId}_wiederholung',
      aktiveFragen: fragen,
      istWiederholungsRunde: true,
    );
  }
}

// ── Vergleichs-Kategorie (Sortier-Spiel & Preis-Schätzen) ─────────────────────

class _SpielKategorie {
  final String id;
  final String labelDe;
  final String einheit;
  final double? Function(String iso2) wert;
  const _SpielKategorie(this.id, this.labelDe, this.einheit, this.wert);

  // Live-Getter statt gespeichertem Feld: _spielKategorien ist `static
  // final` und wird beim ersten Zugriff EINMALIG ausgewertet — ein zur
  // Ladezeit gebackenes t()-Ergebnis würde bei einem Sprachwechsel mitten
  // in der App-Laufzeit stehen bleiben. Als Getter wird bei JEDEM Zugriff
  // frisch übersetzt.
  String get label => t(labelDe);
}

// Kehrt _normalisiereKontinent() um: 'europa' → 'Europa' usw. — für den
// dynamischen Ablenker-Fallback in _zufallsFakt.
const Map<String, String> _kontinentAnzeigename = {
  'europa': 'Europa', 'suedamerika': 'Südamerika', 'nordamerika': 'Nordamerika',
  'afrika': 'Afrika', 'asien': 'Asien', 'ozeanien': 'Ozeanien',
};

// ── FragenGenerator ───────────────────────────────────────────────────────────

class FragenGenerator {
  // Caches (lazy-init beim ersten Aufruf)
  static Map<String, CurrencyData>? _waehrungByIso2;
  static Map<String, SektorData>?   _sektorByIso2;

  static void _initCaches() {
    if (_waehrungByIso2 != null) return;
    _waehrungByIso2 = {};
    _sektorByIso2   = {};

    // co.nameDe (nicht co.name!) — countryName in currencies.dart/
    // wirtschaftssektoren.dart ist immer Deutsch, unabhängig von der
    // App-Sprache. co.name ist ein lokalisierter Getter (siehe Country in
    // countries.dart) und würde diesen Abgleich im Englisch-Modus brechen.
    for (final c in currencies) {
      for (final co in countries) {
        if (co.nameDe == c.countryName) {
          _waehrungByIso2![co.iso2] = c;
          break;
        }
      }
    }
    for (final s in wirtschaftssektoren) {
      for (final co in countries) {
        if (co.nameDe == s.countryName) {
          _sektorByIso2![co.iso2] = s;
          break;
        }
      }
    }
  }

  static Country? _country(String iso2) =>
      countries.cast<Country?>().firstWhere(
            (c) => c?.iso2 == iso2,
            orElse: () => null,
          );

  // Feingranulare Subregion (z.B. 'westeuropa', 'ostafrika') für plausiblere
  // Ablenker im Nachbarland-Quiz — countries.dart's Country.region ist nur
  // der Kontinent, alle_laender.dart's Land.region ist die echte Subregion.
  static Land? _land(String iso2) => alleLaender.cast<Land?>().firstWhere(
        (l) => l?.iso == iso2,
        orElse: () => null,
      );

  static CountryRanking? _ranking(String iso2) =>
      countryRankings.cast<CountryRanking?>().firstWhere(
            (c) => c?.iso2 == iso2,
            orElse: () => null,
          );

  static String _kontinent(LernStation station) {
    for (final w in lernwelten) {
      for (final a in w.abschnitte) {
        for (final s in a.stationen) {
          if (s.id == station.id) return w.kontinent;
        }
      }
    }
    return 'Welt';
  }

  // Vergleichs-Kategorien für Sortier-Spiel & Preis-Schätzen: liefert null
  // wenn für ein Land keine echten Daten vorliegen (statt eines irreführenden
  // 0-Fallbacks). bevoelkerung/bipGesamt/bipProKopf kommen aus [Country] und
  // sind für alle Länder im Spiel garantiert vorhanden; die übrigen stammen
  // aus [CountryRanking] und sind bewusst nullable (dort steht null für
  // "keine verlässlichen Daten").
  static double? _rankingWert(String iso2, double? Function(CountryRanking) f) {
    final r = _ranking(iso2);
    if (r == null) return null;
    return f(r);
  }

  static final List<_SpielKategorie> _spielKategorien = [
    _SpielKategorie('bevoelkerung', 'Bevölkerung', 'Einwohner',
        (iso2) => _country(iso2)?.population.toDouble()),
    // gdp: 0 ist in Country ein Platzhalter für "keine verlässlichen Daten"
    // (z.B. Nordkorea, Kuba, Afghanistan) — kein echter Wert von 0 USD.
    _SpielKategorie('bipGesamt', 'BIP gesamt', 'USD', (iso2) {
      final co = _country(iso2);
      if (co == null || co.gdp <= 0) return null;
      return co.gdp.toDouble();
    }),
    _SpielKategorie('bipProKopf', 'BIP pro Kopf', 'USD', (iso2) {
      final co = _country(iso2);
      if (co == null || co.population <= 0 || co.gdp <= 0) return null;
      return co.gdp / co.population;
    }),
    _SpielKategorie('flaeche', 'Fläche', 'km²',
        (iso2) => _rankingWert(iso2, (r) => r.area)),
    _SpielKategorie('lebenserwartung', 'Lebenserwartung', 'Jahre',
        (iso2) => _rankingWert(iso2, (r) => r.lifeExpectancy)),
    _SpielKategorie('kuestenlange', 'Küstenlänge', 'km',
        (iso2) => _rankingWert(iso2, (r) => r.coastlineKm)),
    _SpielKategorie('mindestlohn', 'Mindestlohn', 'USD/Monat',
        (iso2) => _rankingWert(iso2, (r) => r.minimumWageUsd)),
  ];

  // Wählt bis zu [n] VERSCHIEDENE Länder aus [pool].
  //
  // Füllte früher mit Wiederholungen auf, sobald der Pool kleiner war als
  // [n] — daraus wurden in 48 der 594 Stationen doppelte Fragen: achtmal
  // „Welche Währung hat dieses Land?" mit Serbien, siebenmal „Welches Land
  // grenzt an Papua-Neuguinea?". Wer zu wenig Länder hat, bekommt jetzt
  // weniger; das Auffüllen macht _erweitert() aus echten anderen Ländern.
  static List<String> _pick(List<String> pool, int n) =>
      (pool.toSet().toList()..shuffle(_rng)).take(n).toList();

  // ── Auffüllen, wenn der Abschnitt allein nicht reicht ─────────────────────
  //
  // Jeder Modus siebt den Abschnitts-Pool erst auf das, was er braucht:
  // Umriss vorhanden, Landgrenze vorhanden, Währung im Datensatz. Bleiben
  // danach weniger als [n] Länder übrig, stockt diese Stelle [gewaehlt] auf
  // — erst aus dem Kontinent des Abschnitts, dann aus der ganzen Welt,
  // beides durch denselben Filter [taugt], der schon die Auswahl erzeugt hat.
  //
  // Zweite Stufe der Kette: Der Modus-Tausch (siehe _traegtAbschnitt) kommt
  // VORHER und hat Vorrang — fremde Länder in einem Kontinent-Abschnitt sind
  // die kleinere, aber immer noch spürbare Abweichung. Reicht auch das
  // Auffüllen nicht, kommen eben weniger Länder zurück. Doppelt kommt nie
  // etwas.
  //
  // Die Reihenfolge von [gewaehlt] bleibt, nur der Nachschub wird gemischt:
  // Bei den Kern-Modi steckt in ihr der Schwierigkeits-Verlauf des
  // Round-Robin-Zyklus (siehe _festeReihenfolge), den ein Mischen zerstören
  // würde.
  static List<String> _erweitert(
    List<String> gewaehlt,
    int n,
    String kontinent,
    bool Function(String) taugt,
  ) {
    final ergebnis = <String>[];
    final drin = <String>{};
    for (final c in gewaehlt) {
      if (drin.add(c)) ergebnis.add(c);
    }
    if (ergebnis.length >= n) return ergebnis.take(n).toList();

    final stufen = <Iterable<String>>[
      if (kontinent != 'Welt')
        countries.where((c) => c.region == kontinent).map((c) => c.iso2),
      countries.map((c) => c.iso2),
    ];
    for (final stufe in stufen) {
      final nachschub = stufe.where((c) => !drin.contains(c) && taugt(c)).toList()
        ..shuffle(_rng);
      for (final c in nachschub) {
        if (ergebnis.length >= n) break;
        drin.add(c);
        ergebnis.add(c);
      }
      if (ergebnis.length >= n) break;
    }
    return ergebnis;
  }

  /// Trägt der Abschnitts-Pool diesen Modus überhaupt?
  ///
  /// Erste Stufe der Kette: Schafft der Abschnitt nicht einmal die Hälfte
  /// der Fragen aus eigenen Ländern, wird der Modus getauscht statt der Pool
  /// erweitert. Ein Umriss-Quiz in der Karibik, für das genau ein Umriss
  /// vorliegt, wird so zum Flaggen-Quiz mit denselben sieben Ländern —
  /// statt zu einem Umriss-Quiz über halb Südamerika.
  ///
  /// Die Hälfte ist die Grenze, weil die Station darunter ihr Thema ohnehin
  /// nicht mehr trägt: Bei sieben Fragen und drei tauglichen Ländern käme
  /// die Mehrheit von auswärts.
  static bool _traegtAbschnitt(int vorhanden, int gebraucht) =>
      vorhanden * 2 >= gebraucht;

  /// Beim Auffüllen aus dem Kontinent oder der Welt muss die Hauptstadt auch
  /// hinterlegt sein — sonst stünde die Frage ohne Antwort da. Im
  /// Abschnitts-Pool selbst trifft das auf kein Land zu; die Prüfung gilt
  /// dem Nachschub.
  static bool _hatHauptstadt(String iso2) =>
      (_country(iso2)?.capital ?? '').isNotEmpty;

  // ── Graduelle Schwierigkeits-Einmischung ──────────────────────────────────
  //
  // Reihenfolge INNERHALB der (unveränderten) Abschnitts-Länderliste: statt
  // rein zufällig zu ziehen, wird EINMALIG zu Beginn des Round-Robin-Zyklus
  // eine gewichtete Ziehreihenfolge berechnet und dauerhaft gespeichert
  // (A-Res-Verfahren) — leichte Länder tendieren an den Anfang dieser festen
  // Liste, schwere ans Ende. Die Kern-Modi ziehen dann der Reihe nach aus
  // dieser EINEN feststehenden Liste, statt bei jeder Station neu zu würfeln
  // — das verhindert das Hin-und-Her-Springen zwischen leicht und schwer
  // innerhalb eines Abschnitts und ergibt stattdessen einen durchgehenden,
  // sanften Trend von leicht (Anfang) zu schwer (Ende).

  static double _gewichtFuerIso(String iso2, double fortschritt) {
    final schwierigkeit = landByIso[iso2]?.schwierigkeit ?? 2;
    final basisGewicht = {
          1: 1.0 - fortschritt * 0.6,
          2: 0.3 + fortschritt * 0.5,
          3: 0.1 + fortschritt * 0.7,
        }[schwierigkeit] ??
        0.5;
    return basisGewicht.clamp(0.05, 1.5);
  }

  /// Gewichtete Ziehreihenfolge, EINMALIG für den ganzen Pool berechnet:
  /// die Liste wird Position für Position aufgebaut (A-Res je Position,
  /// score = u^(1/gewicht)), wobei das Gewicht jeder Position mit ihrem
  /// eigenen Fortschritt (0.0 = erste Position, nahe 1.0 = letzte) variiert
  /// — genau wie gewichtFuerLand() es für "wie weit ist der Abschnitt schon
  /// fortgeschritten" vorsieht, nur dass hier die POSITION IN DER FESTEN
  /// LISTE die Rolle der Stationsposition übernimmt. Das Ergebnis wird
  /// einmalig gespeichert (siehe _festeReihenfolge) und danach nur noch der
  /// Reihe nach abgearbeitet, nie neu gewürfelt.
  static List<String> _gewichteteReihenfolge(List<String> isos) {
    final rest = List<String>.from(isos)..shuffle(_rng);
    final ergebnis = <String>[];
    final gesamt = isos.length;
    while (rest.isNotEmpty) {
      final fortschritt = gesamt <= 1 ? 0.0 : ergebnis.length / gesamt;
      String? bestIso;
      double bestScore = -1;
      for (final iso2 in rest) {
        final gewicht = _gewichtFuerIso(iso2, fortschritt);
        final u = _rng.nextDouble().clamp(1e-9, 1.0);
        final score = pow(u, 1 / gewicht).toDouble();
        if (score > bestScore) {
          bestScore = score;
          bestIso = iso2;
        }
      }
      ergebnis.add(bestIso!);
      rest.remove(bestIso);
    }
    return ergebnis;
  }

  /// Lädt die feste, gewichtete Ziehreihenfolge für (Welt, Modus) — berechnet
  /// sie beim allerersten Aufruf bzw. sobald der freigeschaltete Pool wächst
  /// (Abschnittswechsel) NEU über den dann aktuellen Pool, damit die neu
  /// hinzugekommenen Länder mit eingewichtet werden. Bleibt sonst über alle
  /// Stationen DIESES EINEN Modus hinweg gleich, statt bei jeder Station neu
  /// gewürfelt zu werden.
  static Future<List<String>> _festeReihenfolge(
      List<String> eindeutigerPool, String weltId, String key) async {
    final gespeichert = await FortschrittService.ladeFesteReihenfolge(weltId, key);
    if (gespeichert != null &&
        gespeichert.toSet().difference(eindeutigerPool.toSet()).isEmpty &&
        eindeutigerPool.toSet().difference(gespeichert.toSet()).isEmpty) {
      return gespeichert;
    }
    final neu = _gewichteteReihenfolge(eindeutigerPool);
    await FortschrittService.speichereFesteReihenfolge(weltId, key, neu);
    return neu;
  }

  // ── Länder-Round-Robin, GETRENNT PRO EINZELNEM MODUS, DURCHGÄNGIG ─────────
  // ÜBER DIE GANZE WELT (kein Reset pro Abschnitt) ───────────────────────────
  //
  // [key] ist der exakte Modus-Name (z.B. 'flaggenQuizBild',
  // 'flaggenQuizMultiple', 'flaggenQuizEingabe', ...) — jeder der 8 Kern-/
  // Eingabe-Modi hat seinen eigenen, isolierten Zyklus. Das "bereits
  // gezogen"-Set ist WELT-WEIT und wächst kontinuierlich über alle
  // Abschnitte hinweg — es wird NICHT beim Abschnittswechsel zurückgesetzt.
  // [pool] ist der aktuell FREIGESCHALTETE Länderpool (abschnittsabhängig,
  // wächst mit dem Fortschritt) — davon werden die im Tracker noch nicht
  // vorkommenden bevorzugt gezogen; reicht das nicht, wird mit bereits
  // gezogenen aus dem aktuellen Pool aufgefüllt.
  //
  // Ein Modus gilt erst als "pensioniert", wenn das WELT-WEITE Tracker-Set
  // den GRÖSSTEN Länderpool der Welt komplett abdeckt (siehe
  // _pensionierterErsatz in generiereFragenFuerStation) — bis dahin wächst
  // das Set einfach weiter, es gibt keinen automatischen Zyklus-Reset mehr.
  static Future<List<String>> _pickRoundRobin(
      List<String> pool, int n, String weltId, String key) async {
    final eindeutigerPool = pool.toSet().toList();
    final bereits = await FortschrittService.rrBereitsAbgefragt(weltId, key);
    final feste = await _festeReihenfolge(eindeutigerPool, weltId, key);

    final neu = feste.where((c) => !bereits.contains(c)).toList();
    final gezogen = <String>[...neu.take(n)];

    if (gezogen.length < n) {
      // Im aktuell freigeschalteten Pool nicht genug unverbrauchte Länder
      // übrig -> mit bereits abgefragten (aus DIESEM Pool) auffüllen, OHNE
      // das Tracker-Set zurückzusetzen (kein Reset mehr pro Abschnitt).
      //
      // `rest` schliesst aus, was schon in `gezogen` steht: Ohne das kam
      // dasselbe Land in einer Station zweimal, sobald der Pool leer war
      // und noch nichts abgefragt (`schonDa` leer, `eindeutigerPool` also
      // die Rückfallebene — und der überschneidet sich mit `gezogen`).
      final rest = eindeutigerPool.where((c) => !gezogen.contains(c)).toList();
      final schonDa = rest.where((c) => bereits.contains(c)).toList();
      gezogen.addAll(
          _pick(schonDa.isEmpty ? rest : schonDa, n - gezogen.length));
    }

    final aktualisiert = {...bereits, ...gezogen};
    await FortschrittService.rrSpeichern(weltId, key, aktualisiert);

    return gezogen;
  }

  /// Modus-Schlüssel für den Round-Robin-Tracker: bei "Welt" bleibt er
  /// EXAKT der Modus-Name (welt-weiter, durchgängiger Zyklus über alle
  /// Abschnitte, siehe _pickRoundRobin). Bei den 6 Block-Kontinenten wird
  /// die Abschnitt-ID mit eingemischt, weil dort jeder Block bewusst
  /// disjunkt ist: der Zyklus jedes Kern-/Eingabe-Modus wird an jeder
  /// Block-Grenze (= Abschnittswechsel) NEU gestartet, statt über den
  /// ganzen Kontinent hinweg zu laufen.
  static String _rrModusKey(LernWelt welt, LernAbschnitt abschnitt, LernModus modus) =>
      welt.id == 'welt' ? modus.name : '${abschnitt.id}_${modus.name}';

  /// Ermittelt Welt/Abschnitt der Station und delegiert an _pickRoundRobin()
  /// mit dem Round-Robin-Schlüssel aus _rrModusKey() (siehe dort). Fällt auf
  /// reines _pick() zurück, falls die Station keinem festen Platz im
  /// Lernpfad zugeordnet ist (z.B. in Tests).
  ///
  /// Bleibt der Zyklus unter [n] — der Karibik-Block hat sieben Länder, die
  /// Station acht Fragen —, wird mit [_erweitert] aufgestockt statt ein Land
  /// ein zweites Mal zu bringen. [taugt] ist dabei derselbe Filter, mit dem
  /// der Aufrufer schon [pool] gesiebt hat (nur die Umriss-Modi brauchen
  /// einen; Flagge, Hauptstadt und Name hat jedes Land).
  static Future<List<String>> _pickKern(
      List<String> pool, int n, LernStation station,
      {bool Function(String)? taugt}) async {
    final kontext = stationKontext(station.id);
    final gezogen = kontext == null
        ? _pick(pool, n)
        : await _pickRoundRobin(pool, n, kontext.$1.id,
            _rrModusKey(kontext.$1, kontext.$2, station.modus));
    if (gezogen.length >= n) return gezogen;
    return _erweitert(gezogen, n, _kontinent(station), taugt ?? (_) => true);
  }

  // ── Pensionierung: Modus fällt aus, sobald er für diese Welt WELT-WEIT ────
  // (nicht nur im aktuellen Abschnitt) alle Länder des größten Pools dieser
  // Welt schon einmal gezogen hat. Greift nur zur Spielzeit (bewusst leicht-
  // gewichtige Lösung, siehe Nutzer-Entscheidung): die Pfad-Karte zeigt
  // weiterhin den ursprünglich zugewiesenen Modus, nur die tatsächliche
  // Fragen-Generierung weicht dann auf einen noch aktiven Modus aus.

  static const _kernUndEingabeModi = {
    LernModus.flaggenQuizBild,
    LernModus.flaggenQuizMultiple,
    LernModus.flaggenQuizEingabe,
    LernModus.umrissBild,
    LernModus.umrissMultiple,
    LernModus.umrissEingabe,
    LernModus.hauptstaedteMultiple,
    LernModus.hauptstaedteEingabe,
  };

  static Future<bool> _istPensioniert(String weltId, String modusKey, Set<String> vollerPool) async {
    if (vollerPool.isEmpty) return false;
    final bereits = await FortschrittService.rrBereitsAbgefragt(weltId, modusKey);
    return vollerPool.difference(bereits).isEmpty;
  }

  /// Liefert einen Ersatz-Modus, falls [modus] für diese Station bereits
  /// pensioniert ist — sonst null (Original-Modus bleibt gültig). Bei
  /// "Welt" gilt ein Modus erst als pensioniert, wenn er WELT-WEIT (über
  /// alle Abschnitte hinweg) den größten Länderpool komplett abgedeckt hat
  /// (unverändert seit dem letzten Umbau). Bei den 6 Block-Kontinenten
  /// bezieht sich "pensioniert" dagegen NUR auf den Block/die Länderliste
  /// DIESES Abschnitts (station.laenderCodes) — passend zum eigenen,
  /// abschnittsweise zurückgesetzten Zyklus aus _rrModusKey().
  /// Bevorzugt Unterhaltungs-Modi aus dem Level-Pool dieser Station, dann
  /// noch nicht pensionierte Kern-/Eingabe-Modi, als letzten Rückfall
  /// zufallsFakt (nie pensioniert, kein leerer Pool möglich).
  static Future<LernModus?> _pensionierterErsatz(
      LernModus modus, LernStation station) async {
    if (!_kernUndEingabeModi.contains(modus)) return null;
    final kontext = stationKontext(station.id);
    if (kontext == null) return null;
    final (welt, abschnitt, _) = kontext;
    final vollerPool = welt.id == 'welt'
        ? welt.laenderCodes.toSet()
        : station.laenderCodes.toSet();

    if (!await _istPensioniert(
        welt.id, _rrModusKey(welt, abschnitt, modus), vollerPool)) {
      return null;
    }

    final levelPool = modiFuerLevel(station.schwierigkeitsgrad);
    final unterhaltungsKandidaten =
        levelPool.where((m) => !_kernUndEingabeModi.contains(m)).toList();
    if (unterhaltungsKandidaten.isNotEmpty) {
      return unterhaltungsKandidaten[
          station.id.hashCode.abs() % unterhaltungsKandidaten.length];
    }

    for (final kandidat in levelPool) {
      if (kandidat == modus || !_kernUndEingabeModi.contains(kandidat)) continue;
      if (!await _istPensioniert(
          welt.id, _rrModusKey(welt, abschnitt, kandidat), vollerPool)) {
        return kandidat;
      }
    }

    // Alle Kern-/Eingabe-Modi pensioniert UND kein Unterhaltungs-Modus im
    // Level-Pool (sollte praktisch nie vorkommen) -> fester Rückfall.
    return LernModus.zufallsFakt;
  }

  /// Ermittelt den Modus, der beim (Neu-)Start dieser Station TATSÄCHLICH
  /// gespielt würde — berücksichtigt die Pensionierungs-Substitution (siehe
  /// _pensionierterErsatz). Für die Stations-Sheet-Anzeige in home_screen.dart:
  /// Label/Icon sollen immer zum tatsächlich geöffneten Quiz passen, nicht
  /// nur zum ursprünglich zugewiesenen station.modus.
  ///
  /// Eine bereits ABGESCHLOSSENE Station behält beim Replay IMMER ihren
  /// ursprünglichen Modus — die Pensionierungs-Substitution greift nur noch
  /// für den ersten, noch nicht abgeschlossenen Durchlauf (Nutzer-Entscheidung:
  /// ein wiederholtes Spielen soll nicht plötzlich einen anderen Modus als
  /// beim letzten Mal zeigen, nur weil der Block-Pool inzwischen ausgeschöpft
  /// wurde).
  static Future<LernModus> ermittleTatsaechlichenModus(
      LernStation station) async {
    if (await FortschrittService.istStationAbgeschlossen(station.id)) {
      return station.modus;
    }
    return await _pensionierterErsatz(station.modus, station) ?? station.modus;
  }

  /// Haupteinstieg: generiert alle Fragen für eine Station.
  /// Wirft Fragen weg, die in dieser Station schon einmal vorkommen.
  ///
  /// Letzte Stufe der Kette und die eigentliche Zusicherung: Egal was ein
  /// einzelner Modus baut — innerhalb einer Station kommt keine Frage
  /// zweimal. Die Modi darüber sorgen dafür, dass hier praktisch nie etwas
  /// wegfällt; diese Stelle deckt den Rest ab, auch bei einem Modus, den es
  /// heute noch nicht gibt.
  ///
  /// Die Frage IST ihr Text plus das gezeigte Land: Bei Flagge und Umriss
  /// steht im Text nur „Welchem Land gehört dieser Umriss?", unterschieden
  /// wird dort über [Frage.laenderCode]. Beim Sortierspiel wiederum ist der
  /// Ländercode leer und die Ländergruppe steckt in der richtigen Antwort.
  ///
  /// NICHT betroffen ist die Wiederholung nach einer falschen Antwort — die
  /// hängt die Frage in der Session erneut an die Warteschlange (siehe
  /// [StationSession.beantworte] und [kModiMitWiederholung]) und ist
  /// ausdrücklich gewollt.
  static List<Frage> _ohneDoppelte(List<Frage> fragen) {
    final gesehen = <String>{};
    return fragen
        .where((f) => gesehen.add(
            '${f.modus.name}|${f.laenderCode}|${f.frage}|${f.richtigeAntwort}'))
        .toList();
  }

  static Future<List<Frage>> generiereFragenFuerStation(
      LernStation station) async =>
      _ohneDoppelte(await _baueFragen(station));

  static Future<List<Frage>> _baueFragen(LernStation station) async {
    _initCaches();
    final pool = station.laenderCodes.where((c) => c != '*').toList();
    if (pool.isEmpty) return [];
    final kontinent = _kontinent(station);
    final schwierigkeit = station.schwierigkeitsgrad;
    final modus = await ermittleTatsaechlichenModus(station);

    switch (modus) {
      case LernModus.flaggenQuizBild:
        return await _flaggenBild(station, pool, kontinent, schwierigkeit);
      case LernModus.flaggenQuizMultiple:
        return await _flaggenMultiple(station, pool, kontinent, schwierigkeit);
      case LernModus.hauptstaedteMultiple:
        return await _hauptstaedteMultiple(station, pool, kontinent, schwierigkeit);
      case LernModus.hauptstaedteEingabe:
        return await _hauptstaedteEingabe(station, pool);
      case LernModus.waehrungsQuiz:
        return await _waehrung(station, pool, kontinent, schwierigkeit);
      case LernModus.sortierSpiel:
        return _sortierSpiel(station, pool, kontinent);
      case LernModus.preisSchaetzen:
        return _preisSchaetzen(station, pool, kontinent);
      case LernModus.wirtschaftssektoren:
        return await _wirtschaftssektoren(station, pool, schwierigkeit);
      case LernModus.umrissBild:
        return await _umrissBild(station, pool);
      case LernModus.umrissMultiple:
        return await _umrissMultiple(station, pool);
      case LernModus.flaggenQuizEingabe:
        return await _flaggenQuizEingabe(station, pool);
      case LernModus.umrissEingabe:
        return await _umrissEingabe(station, pool);
      case LernModus.nachbarland:
        return await _nachbarland(station, pool, kontinent, schwierigkeit);
      case LernModus.bipGesamt:
        return await _bipGesamtQuiz(station, pool);
      case LernModus.flaeche:
        return await _flaecheQuiz(station, pool);
      case LernModus.extremFrage:
        return _extremFrage(station, pool);
      case LernModus.waehrungZuLand:
        return await _waehrungZuLand(station, pool);
      case LernModus.extremFrageLeicht:
        return _extremFrageLeicht(station, pool);
      case LernModus.zufallsFakt:
        return _zufallsFakt(station, kontinent);
      case LernModus.bekanntesGebaeude:
        return _bekanntesGebaeude(station, kontinent);
      case LernModus.grenzkettenRaetsel:
        return await _grenzkettenRaetsel(
            station, pool, kontinent, schwierigkeit);
      case LernModus.flaechenVergleich:
        return _flaechenVergleich(station, pool);
      case LernModus.zweiWahrheiten:
        return _zweiWahrheiten(station, pool);
      case LernModus.wasGehoertNichtDazu:
        return _wasGehoertNichtDazu(station, pool);
      case LernModus.laenderRanking:
        return _laenderRanking(station, pool);
      case LernModus.nachbarschaftsKette:
        return _nachbarschaftsKette(station, pool);
    }
  }

  // ── Flaggen: Bild → Land wählen ────────────────────────────────────────────

  static Future<List<Frage>> _flaggenBild(
    LernStation station, List<String> pool, String kontinent, int schw) async {
    final ausgewaehlt = await _pickKern(pool, station.fragenAnzahl, station);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2);
      final optionenIso2 = AntwortGenerator.generiereOptionenAusListe(
          iso2, pool, anzahlOptionen: 4);
      final optionenNamen = optionenIso2
          .map((c) => _country(c)?.name ?? c)
          .toList();
      return Frage(
        id: '${station.id}_fb_${e.key}',
        frage: '',
        richtigeAntwort: co?.name ?? iso2,
        antwortOptionen: optionenNamen,
        modus: LernModus.flaggenQuizBild,
        laenderCode: iso2,
        meta: {'typ': 'flagge_zu_land'},
      );
    }).toList();
  }

  // ── Flaggen: Land sehen → Flagge wählen ────────────────────────────────────

  static Future<List<Frage>> _flaggenMultiple(
    LernStation station, List<String> pool, String kontinent, int schw) async {
    final ausgewaehlt = await _pickKern(pool, station.fragenAnzahl, station);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2);
      final optionen = AntwortGenerator.generiereOptionenAusListe(
          iso2, pool, anzahlOptionen: 4);
      return Frage(
        id: '${station.id}_fm_${e.key}',
        frage: t('Welche Flagge gehört zu {land}?', {'land': co?.name ?? iso2}),
        richtigeAntwort: iso2,
        antwortOptionen: optionen, // ISO2-Codes → UI zeigt FlaggenWidget
        modus: LernModus.flaggenQuizMultiple,
        laenderCode: iso2,
        meta: {'typ': 'land_zu_flagge'},
      );
    }).toList();
  }

  // Normalisiert Lernpfad-Kontinentname → alle_laender.dart-Format
  static String _normalisiereKontinent(String k) => const {
    'Europa': 'europa', 'Südamerika': 'suedamerika',
    'Nordamerika': 'nordamerika', 'Afrika': 'afrika',
    'Asien': 'asien', 'Ozeanien': 'ozeanien',
  }[k] ?? 'europa';

  // ── Umriss: Silhouette sehen → Land wählen ─────────────────────────────────

  // Für den Umriss-Ausschluss (Zwergstaaten/kleine Inselstaaten, siehe
  // kUmrissAusschluss) gefilterter Pool — fällt auf den ungefilterten Pool
  // zurück, falls eine Station ausschließlich aus ausgeschlossenen Ländern
  // besteht (verhindert eine leere Fragenliste).
  /// Länder des Abschnitts, die im Umriss-Quiz erscheinen dürfen.
  ///
  /// Fiel früher auf den ungefilterten Pool zurück, wenn NICHTS taugte —
  /// dann standen Zwergstaaten als Umriss da. Jetzt liefert die Stelle
  /// ehrlich die leere Liste; ob das reicht, entscheidet der Aufrufer mit
  /// [_traegtAbschnitt] und weicht sonst auf das Flaggen-Quiz aus.
  static List<String> _umrissPool(List<String> pool) =>
      pool.where(kannAlsUmrissErscheinen).toList();

  static Future<List<Frage>> _umrissBild(LernStation station, List<String> pool) async {
    final kontId = _normalisiereKontinent(_kontinent(station));
    final umrisse = _umrissPool(pool);
    // Karibik: von sieben Ländern hat genau eines einen brauchbaren Umriss.
    // Dann lieber dieselben sieben Länder als Flaggen-Quiz (gleiche Form der
    // Frage: Bild sehen, Land wählen) als ein Umriss-Quiz über halb
    // Südamerika.
    if (!_traegtAbschnitt(umrisse.length, station.fragenAnzahl)) {
      return await _flaggenBild(
          station, pool, _kontinent(station), station.schwierigkeitsgrad);
    }
    final ausgewaehlt = await _pickKern(umrisse, station.fragenAnzahl, station,
        taugt: kannAlsUmrissErscheinen);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2);
      final optionenIso2 = generiereUmrissOptionen(iso2, kontId);
      final optionenNamen =
          optionenIso2.map((c) => _country(c)?.name ?? landByIso[c]?.name ?? c).toList();
      return Frage(
        id: '${station.id}_ub_${e.key}',
        frage: '',
        richtigeAntwort: co?.name ?? landByIso[iso2]?.name ?? iso2,
        antwortOptionen: optionenNamen,
        modus: LernModus.umrissBild,
        laenderCode: iso2,
      );
    }).toList();
  }

  // ── Umriss: Land sehen → Silhouette wählen ──────────────────────────────────

  static Future<List<Frage>> _umrissMultiple(LernStation station, List<String> pool) async {
    final kontId = _normalisiereKontinent(_kontinent(station));
    final umrisse = _umrissPool(pool);
    // Ausweichmodus wie bei _umrissBild, hier auf die Gegenrichtung: Land
    // sehen, Bild wählen.
    if (!_traegtAbschnitt(umrisse.length, station.fragenAnzahl)) {
      return await _flaggenMultiple(
          station, pool, _kontinent(station), station.schwierigkeitsgrad);
    }
    final ausgewaehlt = await _pickKern(umrisse, station.fragenAnzahl, station,
        taugt: kannAlsUmrissErscheinen);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final optionen = generiereUmrissOptionen(iso2, kontId);
      return Frage(
        id: '${station.id}_um_${e.key}',
        frage: '',
        richtigeAntwort: iso2,
        antwortOptionen: optionen,
        modus: LernModus.umrissMultiple,
        laenderCode: iso2,
      );
    }).toList();
  }

  // ── Hauptstädte: Multiple Choice ────────────────────────────────────────────

  static Future<List<Frage>> _hauptstaedteMultiple(
    LernStation station, List<String> pool, String kontinent, int schw) async {
    final ausgewaehlt = await _pickKern(pool, station.fragenAnzahl, station,
        taugt: _hatHauptstadt);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      // Distraktoren: andere Hauptstädte aus selber Region
      final distrIso2 = AntwortGenerator.generiereOptionenAusListe(
              iso2, pool, anzahlOptionen: 4)
          .where((c) => c != iso2)
          .take(3)
          .toList();
      final optionen = [co.capital, ...distrIso2.map((c) => _country(c)?.capital ?? c)]
        ..shuffle(_rng);
      return Frage(
        id: '${station.id}_hm_${e.key}',
        frage: t('Was ist die Hauptstadt von {land}?', {'land': co.name}),
        richtigeAntwort: co.capital,
        antwortOptionen: optionen,
        modus: LernModus.hauptstaedteMultiple,
        laenderCode: iso2,
      );
    }).toList();
  }

  // ── Hauptstädte: Texteingabe ────────────────────────────────────────────────
  //
  // _pickKern() nutzt den EXAKTEN Modus-Namen als Round-Robin-Schlüssel ->
  // eigener, von hauptstaedteMultiple komplett isolierter Zyklus.
  static Future<List<Frage>> _hauptstaedteEingabe(
      LernStation station, List<String> pool) async {
    final ausgewaehlt = await _pickKern(pool, station.fragenAnzahl, station,
        taugt: _hatHauptstadt);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      return Frage(
        id: '${station.id}_he_${e.key}',
        frage: t('Was ist die Hauptstadt von {land}?', {'land': co.name}),
        richtigeAntwort: co.capital,
        antwortOptionen: const [],
        modus: LernModus.hauptstaedteEingabe,
        laenderCode: iso2,
        meta: {'eingabe': true},
      );
    }).toList();
  }

  // ── Flaggen: Texteingabe ────────────────────────────────────────────────────
  //
  // Eigener, von flaggenQuizBild/flaggenQuizMultiple komplett isolierter
  // Round-Robin-Zyklus (siehe Kommentar bei _hauptstaedteEingabe).
  static Future<List<Frage>> _flaggenQuizEingabe(
      LernStation station, List<String> pool) async {
    final ausgewaehlt = await _pickKern(pool, station.fragenAnzahl, station);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      return Frage(
        id: '${station.id}_fe_${e.key}',
        frage: t('Welchem Land gehört diese Flagge?'),
        richtigeAntwort: co.name,
        antwortOptionen: const [],
        modus: LernModus.flaggenQuizEingabe,
        laenderCode: iso2,
        meta: {'eingabe': true},
      );
    }).toList();
  }

  // ── Umriss: Texteingabe ─────────────────────────────────────────────────────
  //
  // Eigener, von umrissBild/umrissMultiple komplett isolierter Round-Robin-
  // Zyklus (siehe Kommentar bei _hauptstaedteEingabe).
  static Future<List<Frage>> _umrissEingabe(
      LernStation station, List<String> pool) async {
    final umrisse = _umrissPool(pool);
    // Ausweichmodus wie bei _umrissBild, hier auf die Tastatur-Variante:
    // Bild sehen, Ländernamen tippen.
    if (!_traegtAbschnitt(umrisse.length, station.fragenAnzahl)) {
      return await _flaggenQuizEingabe(station, pool);
    }
    final ausgewaehlt = await _pickKern(umrisse, station.fragenAnzahl, station,
        taugt: kannAlsUmrissErscheinen);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2);
      return Frage(
        id: '${station.id}_ue_${e.key}',
        frage: t('Welchem Land gehört dieser Umriss?'),
        richtigeAntwort: co?.name ?? landByIso[iso2]?.name ?? iso2,
        antwortOptionen: const [],
        modus: LernModus.umrissEingabe,
        laenderCode: iso2,
        meta: {'eingabe': true},
      );
    }).toList();
  }

  // ── Währungsnamen ohne Ländervorsilbe ──────────────────────────────────────

  static const _waehrungsKuerzel = {
    // Europa
    'GBP': 'Pfund',      'CHF': 'Franken',   'SEK': 'Krone',
    'NOK': 'Krone',      'DKK': 'Krone',     'PLN': 'Złoty',
    'CZK': 'Krone',      'HUF': 'Forint',    'RON': 'Leu',
    'RUB': 'Rubel',      'TRY': 'Lira',      'UAH': 'Hrywnja',
    'BGN': 'Lew',        'RSD': 'Dinar',
    // Nordamerika
    'USD': 'Dollar',     'CAD': 'Dollar',    'MXN': 'Peso',
    // Südamerika
    'BRL': 'Real',       'ARS': 'Peso',      'COP': 'Peso',
    'CLP': 'Peso',       'PEN': 'Sol',       'VES': 'Bolívar',
    // Asien – Ostasien
    'JPY': 'Yen',        'CNY': 'Yuan',      'KRW': 'Won',
    'SGD': 'Dollar',     'TWD': 'Dollar',    'MNT': 'Tögrög',
    // Asien – Südostasien
    'IDR': 'Rupiah',     'THB': 'Baht',      'MYR': 'Ringgit',
    'PHP': 'Peso',       'VND': 'Dong',      'MMK': 'Kyat',
    'KHR': 'Riel',       'LAK': 'Kip',
    // Asien – Südasien / Zentralasien
    'INR': 'Rupie',      'PKR': 'Rupie',     'BDT': 'Taka',
    'LKR': 'Rupie',      'NPR': 'Rupie',     'KZT': 'Tenge',
    'UZS': 'Sum',        'GEL': 'Lari',      'AMD': 'Dram',
    'AZN': 'Manat',
    // Naher Osten
    'SAR': 'Riyal',      'AED': 'Dirham',    'ILS': 'Schekel',
    'QAR': 'Riyal',      'KWD': 'Dinar',     'BHD': 'Dinar',
    'OMR': 'Rial',       'JOD': 'Dinar',     'IQD': 'Dinar',
    'IRR': 'Rial',
    // Afrika
    'ZAR': 'Rand',       'NGN': 'Naira',     'EGP': 'Pfund',
    'MAD': 'Dirham',     'KES': 'Schilling', 'GHS': 'Cedi',
    'ETB': 'Birr',       'TZS': 'Schilling', 'DZD': 'Dinar',
    'TND': 'Dinar',
    // Ozeanien
    'AUD': 'Dollar',     'NZD': 'Dollar',
  };

  // ── Echte Währungszeichen ──────────────────────────────────────────────────
  //
  // Auf die Münze über der Frage gehört ein ZEICHEN — €, ₹, ฿ —, keine
  // Abkürzung. „Fr", „NT$" oder „KSh" sind Kürzel des Namens; als Prägung
  // sähen sie aus, als hätte jemand mit dem Kugelschreiber auf die Münze
  // geschrieben. Wo es kein Zeichen gibt, bleibt die Münze blank.
  //
  // ENTSCHIEDEN WIRD NACH UNICODE, nicht nach Gefühl: Ein Zeichen zählt,
  // wenn jedes seiner Zeichen in einem der Blöcke steht, die Unicode als
  // Währungssymbol führt (Kategorie Sc). Das trennt sauber:
  //
  //   € £ $ ¥ ₹ ₩ ₽ ₺ ₴ ₦ ₨ ₸ ₮ ₭ ₾ ₼ ₵ ₱ ₪ ₫ ฿ ៛ ৳ ֏ ﷼   → Münze
  //   Fr  kr  zł  Kč  Ft  lei  Rp  RM  KSh  R$  NT$  د.إ    → blank
  //
  // Die Liste wächst damit von selbst mit, wenn jemand in currencies.dart
  // ein echtes Zeichen nachträgt — ohne dass hier etwas anzupassen wäre.
  static const List<List<int>> _kZeichenBloecke = [
    [0x24, 0x24], // $
    [0xA2, 0xA5], // ¢ £ ¤ ¥
    [0x58F, 0x58F], // ֏ Dram
    [0x60B, 0x60B], // ؋ Afghani
    [0x7FE, 0x7FF],
    [0x9F2, 0x9F3], // ৲ ৳ Taka
    [0x9FB, 0x9FB],
    [0xAF1, 0xAF1],
    [0xBF9, 0xBF9],
    [0xE3F, 0xE3F], // ฿ Baht
    [0x17DB, 0x17DB], // ៛ Riel
    [0x20A0, 0x20C0], // Der Währungssymbol-Block: ₠ bis ₿
    [0xA838, 0xA838],
    [0xFDFC, 0xFDFC], // ﷼ Rial
    [0xFE69, 0xFE69],
    [0xFF04, 0xFF04],
    [0xFFE0, 0xFFE1],
    [0xFFE5, 0xFFE6],
  ];

  /// Währungen, deren echtes Zeichen in currencies.dart als Abkürzung steht.
  ///
  /// Nachgetragen statt im Datensatz geändert: Dort hängen der Währungs-Screen
  /// und die Fun-Facts mit dran, und „Rs" ist als AUSGESCHRIEBENE Abkürzung
  /// dort nicht falsch. Für die Prägung braucht es das Zeichen selbst.
  ///
  /// ₨ ist das Rupien-Zeichen und gilt für Sri Lanka und Nepal so gut wie für
  /// Pakistan; ﷼ ist das Rial-Zeichen und gilt für Saudi-Arabien, Katar und
  /// Oman so gut wie für den Iran, wo es schon eingetragen ist.
  static const Map<String, String> _kZeichenNachtrag = {
    'LKR': '₨',
    'NPR': '₨',
    'SAR': '﷼',
    'QAR': '﷼',
    'OMR': '﷼',
  };

  static bool _istWaehrungsZeichen(String s) {
    if (s.isEmpty) return false;
    return s.runes.every((r) =>
        _kZeichenBloecke.any((b) => r >= b[0] && r <= b[1]));
  }

  /// Das Zeichen für die Münze — leer, wenn die Währung keines hat.
  static String _waehrungsZeichen(CurrencyData curr) {
    final roh = _kZeichenNachtrag[curr.currencyCode] ?? curr.currencySymbol;
    return _istWaehrungsZeichen(roh) ? roh : '';
  }

  static String _kuerzeWaehrungsname(CurrencyData curr) =>
      LocaleService.istEnglisch
          ? (waehrungsKuerzelEn[curr.currencyCode] ?? curr.currencyName)
          : (_waehrungsKuerzel[curr.currencyCode] ?? curr.currencyName);

  // ── Währungs-Quiz ───────────────────────────────────────────────────────────

  static Future<List<Frage>> _waehrung(
    LernStation station, List<String> pool, String kontinent, int schw) async {
    bool hatWaehrung(String c) => _waehrungByIso2!.containsKey(c);
    final mitWaehrung = pool.where(hatWaehrung).toList();
    // In europa_3 steht genau ein Land des Abschnitts im Währungsdatensatz —
    // dann acht Fragen über fremde Länder zu stellen wäre schlechter als
    // dieselben Länder nach ihren Hauptstädten zu fragen.
    if (!_traegtAbschnitt(mitWaehrung.length, station.fragenAnzahl)) {
      return await _hauptstaedteMultiple(station, pool, kontinent, schw);
    }

    final ausgewaehlt = _erweitert(_pick(mitWaehrung, station.fragenAnzahl),
        station.fragenAnzahl, kontinent, hatWaehrung);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      final curr = _waehrungByIso2![iso2]!;
      // Nur der Name der Währung — der Code (z.B. "(EUR)") wurde bewusst
      // entfernt, war für die meisten Spieler ohnehin nicht aussagekräftig.
      final richtig = _kuerzeWaehrungsname(curr);

      // Distraktoren: erst gleiche Region, dann global — weiterhin nach
      // currencyCode dedupliziert (verlässlicher als der angezeigte Name:
      // verhindert Duplikate auch wenn zwei unterschiedliche Währungen
      // zufällig denselben verkürzten Namen hätten), zusätzlich nach dem
      // angezeigten Namen selbst, damit nie zwei identisch aussehende
      // Optionen im selben Fragensatz landen.
      final kandidaten = [
        ..._waehrungByIso2!.entries
            .where((d) => d.key != iso2 && _country(d.key)?.region == co.region),
        ..._waehrungByIso2!.entries
            .where((d) => d.key != iso2 && _country(d.key)?.region != co.region),
      ]..shuffle(_rng);

      final geseheneCodes = <String>{curr.currencyCode};
      final geseheneNamen = <String>{richtig};
      final distrOpts = <String>[];
      for (final d in kandidaten) {
        if (geseheneCodes.contains(d.value.currencyCode)) continue;
        final name = _kuerzeWaehrungsname(d.value);
        if (geseheneNamen.contains(name)) continue;
        geseheneCodes.add(d.value.currencyCode);
        geseheneNamen.add(name);
        distrOpts.add(name);
        if (distrOpts.length >= 3) break;
      }

      final optionen = [richtig, ...distrOpts]..shuffle(_rng);

      return Frage(
        id: '${station.id}_w_${e.key}',
        frage: t('Welche Währung hat dieses Land?'),
        richtigeAntwort: richtig,
        antwortOptionen: optionen,
        modus: LernModus.waehrungsQuiz,
        laenderCode: iso2,
      );
    }).toList();
  }

  // ── Sortier-Spiel ───────────────────────────────────────────────────────────

  /// Nur Länder aus dem Kontinent des Abschnitts (bei "Welt"-Abschnitten
  /// bleibt der Pool unangetastet — dort ist Kontinent-Mix beabsichtigt).
  static List<String> _poolFuerKontinent(List<String> pool, String kontinent) {
    if (kontinent == 'Welt') return pool;
    final gefiltert =
        pool.where((iso2) => _country(iso2)?.region == kontinent).toList();
    return gefiltert.isNotEmpty ? gefiltert : pool;
  }

  static List<Frage> _sortierSpiel(
      LernStation station, List<String> pool, String kontinent) {
    final kontinentPool = _poolFuerKontinent(pool, kontinent);

    // EINE Kategorie für die GESAMTE Station (nicht pro Runde) — sie muss
    // für mindestens 5 Länder im Pool echte Daten haben, sonst wäre kein
    // Sortier-Durchgang möglich.
    final gueltigeKategorien = _spielKategorien
        .where((k) =>
            kontinentPool.where((iso2) => k.wert(iso2) != null).length >= 5)
        .toList();
    final kategorie = gueltigeKategorien.isEmpty
        ? _spielKategorien.first
        : gueltigeKategorien[_rng.nextInt(gueltigeKategorien.length)];
    bool hatWert(String iso2) => kategorie.wert(iso2) != null;
    // Genug Länder für DREI verschiedene Fünfergruppen: Bei genau fünf
    // tauglichen Ländern gibt es nur eine einzige mögliche Runde, und die
    // Station stellte dreimal dieselbe Aufgabe. Sieben reichen für die
    // üblichen drei Runden; fehlen sie im Abschnitt, kommen sie aus dem
    // Kontinent.
    final eigene = kontinentPool.where(hatWert).toList();
    final gebraucht = 5 + station.fragenAnzahl - 1;
    // Nur AUFfüllen, nie kürzen: _erweitert() gibt genau [gebraucht] zurück,
    // und ein Abschnitt mit zwanzig tauglichen Ländern soll seine Vielfalt
    // behalten statt auf sieben eingedampft zu werden.
    final kategoriePool = eigene.length >= gebraucht
        ? eigene
        : _erweitert(eigene, gebraucht, kontinent, hatWert);

    final fragen = <Frage>[];
    // Zwei Runden mit denselben fünf Ländern wären zweimal dieselbe Aufgabe
    // — die Reihenfolge ist ja dieselbe. Verglichen wird die Gruppe, nicht
    // die gemischte Anzeige.
    final gesehen = <String>{};
    for (int runde = 0; runde < station.fragenAnzahl; runde++) {
      List<String>? neueGruppe;
      for (var versuch = 0; versuch < 20 && neueGruppe == null; versuch++) {
        final kandidat = _pick(kategoriePool, 5);
        if (gesehen.add((List.of(kandidat)..sort()).join(','))) {
          neueGruppe = kandidat;
        }
      }
      // Der Pool gibt keine neue Fünfergruppe mehr her — dann hat die
      // Station eben weniger Runden statt einer doppelten.
      if (neueGruppe == null) break;
      final fuenf = neueGruppe;

      // Größte zuerst.
      final sortiert = List.of(fuenf)
        ..sort((a, b) => kategorie.wert(b)!.compareTo(kategorie.wert(a)!));
      final gemischt = List.of(sortiert)..shuffle(_rng);

      fragen.add(Frage(
        id: '${station.id}_s_$runde',
        frage: t('Sortiere nach: {k} (größte zuerst)', {'k': kategorie.label}),
        richtigeAntwort: sortiert.join(','),
        antwortOptionen: gemischt,
        modus: LernModus.sortierSpiel,
        laenderCode: '',
        meta: {
          'kategorie': kategorie.id,
          'kategorieLabel': kategorie.label,
          'laenderCodes': fuenf,
          'sortierung': 'absteigend',
          'einheit': kategorie.einheit,
          'werte': {for (final iso2 in fuenf) iso2: kategorie.wert(iso2)},
        },
      ));
    }
    return fragen;
  }

  // ── Preis schätzen ──────────────────────────────────────────────────────────

  // Nur Kategorien, für die SkalaService eine adaptive Skala berechnen kann
  // (kuestenlange hat keine — bleibt dem Sortierspiel vorbehalten, wo nur
  // die Reihenfolge zählt, kein Zahlenbereich).
  static final List<_SpielKategorie> _preisKategorien = _spielKategorien
      .where((k) => const {
            'bevoelkerung', 'bipGesamt', 'bipProKopf', 'flaeche',
            'lebenserwartung', 'mindestlohn',
          }.contains(k.id))
      .toList();

  static List<Frage> _preisSchaetzen(
      LernStation station, List<String> pool, String kontinent) {
    final kontinentPool = _poolFuerKontinent(pool, kontinent);
    // Kein Modus-Tausch nötig: Einwohnerzahl und Fläche hat praktisch jedes
    // Land, der Filter greift also nie so hart wie bei Währung oder Umriss.
    // Das Auffüllen steht trotzdem da, weil _pick() nicht mehr wiederholt.
    bool hatPreisWert(String c) => _preisKategorien.any((k) => k.wert(c) != null);
    final ausgewaehlt = _erweitert(
        _pick(kontinentPool.where(hatPreisWert).toList(), station.fragenAnzahl),
        station.fragenAnzahl,
        kontinent,
        hatPreisWert);

    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      // Nur Kategorien mit echten Daten für DIESES Land verwenden.
      final gueltig =
          _preisKategorien.where((k) => k.wert(iso2) != null).toList();
      final kategorie =
          gueltig.isEmpty ? _spielKategorien.first : gueltig[_rng.nextInt(gueltig.length)];
      final wert = kategorie.wert(iso2)!;
      // Adaptive Skala wie bei der Tages-Challenge: kleines Land → kleine
      // Skala (statt eines festen Kontinent-weiten Bereichs).
      final skala = SkalaService.fuerKategorie(kategorie.id, wert)!;
      // Startwert nicht mittig — deterministisch versetzter Bruchteil,
      // dieselbe Formel wie beim Tages-Schätzen.
      final start = (skala.min + TagesSeedService.startBruch(e.key) * (skala.max - skala.min))
          .clamp(skala.min, skala.max);

      return Frage(
        id: '${station.id}_p_${e.key}',
        frage: t('Schätze: {k} von {land}', {'k': kategorie.label, 'land': co.name}),
        richtigeAntwort: wert.toString(),
        antwortOptionen: const [],
        modus: LernModus.preisSchaetzen,
        laenderCode: iso2,
        meta: {
          'kategorie': kategorie.id,
          'kategorieLabel': kategorie.label,
          'min': skala.min,
          'max': skala.max,
          'schritt': skala.schritt,
          'start': start,
        },
      );
    }).toList();
  }

  // ── Wirtschaftssektoren ─────────────────────────────────────────────────────

  // sektorEmojis-Keys (wirtschaftssektoren.dart) und SektorData.mainSector
  // bleiben bewusst Deutsch (Daten-Vergleichsbasis) — nur der angezeigte
  // Antworttext wird hier lokalisiert.
  static String _sektorAnzeigename(String mainSectorDe) =>
      LocaleService.istEnglisch
          ? (wirtschaftssektorenEn[mainSectorDe] ?? mainSectorDe)
          : mainSectorDe;

  static Future<List<Frage>> _wirtschaftssektoren(
      LernStation station, List<String> pool, int schw) async {
    bool hatSektor(String c) => _sektorByIso2!.containsKey(c);
    final mitSektor = pool.where(hatSektor).toList();
    if (!_traegtAbschnitt(mitSektor.length, station.fragenAnzahl)) {
      return await _flaggenBild(station, pool, 'Welt', schw);
    }

    final ausgewaehlt = _erweitert(_pick(mitSektor, station.fragenAnzahl),
        station.fragenAnzahl, _kontinent(station), hatSektor);
    final alleSektoren = sektorEmojis.keys.map(_sektorAnzeigename).toList();

    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      final sektor = _sektorByIso2![iso2]!;
      final richtig = _sektorAnzeigename(sektor.mainSector);
      final distr = alleSektoren.where((s) => s != richtig).toList()
        ..shuffle(_rng);
      final optionen = [richtig, ...distr.take(3)]..shuffle(_rng);

      return Frage(
        id: '${station.id}_wi_${e.key}',
        frage: t('Welcher Wirtschaftssektor dominiert in {land}?', {'land': co.name}),
        richtigeAntwort: richtig,
        antwortOptionen: optionen,
        modus: LernModus.wirtschaftssektoren,
        laenderCode: iso2,
        meta: {'topExports': sektor.topExports},
      );
    }).toList();
  }

  // ── Nachbarland ──────────────────────────────────────────────────────────

  static Future<List<Frage>> _nachbarland(
      LernStation station, List<String> pool, String kontinent, int schw) async {
    bool hatNachbarn(String c) => (nachbarn[c] ?? const []).isNotEmpty;
    final mitNachbarn = pool.where(hatNachbarn).toList();
    // Inselstaaten ohne Landgrenze: Modus überspringen, Flaggen-Quiz statt.
    // In ozeanien_1 hat genau ein Land des Abschnitts überhaupt eine
    // Landgrenze (Papua-Neuguinea) — daher kam die Frage siebenmal.
    if (!_traegtAbschnitt(mitNachbarn.length, station.fragenAnzahl)) {
      return await _flaggenBild(station, pool, kontinent, schw);
    }

    final ausgewaehlt = _erweitert(_pick(mitNachbarn, station.fragenAnzahl),
        station.fragenAnzahl, kontinent, hatNachbarn);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      final echteNachbarn = nachbarn[iso2] ?? const <String>[];
      final richtig = echteNachbarn[_rng.nextInt(echteNachbarn.length)];
      final richtigName = _country(richtig)?.name ?? richtig;

      final ablenker = _ablenkerNachbarland(iso2, echteNachbarn);
      final optionen = [
        richtigName,
        ...ablenker.map((c) => c.name),
      ]..shuffle(_rng);

      return Frage(
        id: '${station.id}_nb_${e.key}',
        // Über t() mit Platzhalter statt direkter Interpolation: interpoliert
        // ließe sich der Satz gar nicht übersetzen, weil der Ländername
        // mitten im Schlüssel stünde.
        frage: t('Welches Land grenzt an {land}?', {'land': co.name}),
        richtigeAntwort: richtigName,
        antwortOptionen: optionen,
        modus: LernModus.nachbarland,
        laenderCode: iso2,
      );
    }).toList();
  }

  /// Zieht 3 plausible Ablenker für das Nachbarland-Quiz — bevorzugt
  /// "Nachbarn der Nachbarn" (grenzen an einen echten Nachbarn, sind aber
  /// selbst keiner -> "fast richtig"), dann übrige Länder derselben
  /// Subregion (z.B. 'westeuropa'), dann Fallback auf den ganzen Kontinent,
  /// und zuletzt (praktisch nie nötig) den gesamten Länder-Pool.
  static List<Country> _ablenkerNachbarland(
      String iso2, List<String> echteNachbarn) {
    final land = _land(iso2);

    final nachbarnDerNachbarn = <String>{};
    for (final n in echteNachbarn) {
      nachbarnDerNachbarn.addAll(nachbarn[n] ?? const []);
    }
    nachbarnDerNachbarn.removeAll(echteNachbarn);
    nachbarnDerNachbarn.remove(iso2);

    final ergebnis = <String>[...nachbarnDerNachbarn]..shuffle(_rng);

    if (ergebnis.length < 3 && land != null) {
      final selbeRegion = alleLaender
          .where((l) =>
              l.region == land.region &&
              l.iso != iso2 &&
              !echteNachbarn.contains(l.iso) &&
              !ergebnis.contains(l.iso))
          .map((l) => l.iso)
          .toList()
        ..shuffle(_rng);
      ergebnis.addAll(selbeRegion);
    }

    if (ergebnis.length < 3 && land != null) {
      final selberKontinent = alleLaender
          .where((l) =>
              l.kontinent == land.kontinent &&
              l.iso != iso2 &&
              !echteNachbarn.contains(l.iso) &&
              !ergebnis.contains(l.iso))
          .map((l) => l.iso)
          .toList()
        ..shuffle(_rng);
      ergebnis.addAll(selberKontinent);
    }

    if (ergebnis.length < 3) {
      final rest = countries
          .where((c) =>
              c.iso2 != iso2 &&
              !echteNachbarn.contains(c.iso2) &&
              !ergebnis.contains(c.iso2))
          .map((c) => c.iso2)
          .toList()
        ..shuffle(_rng);
      ergebnis.addAll(rest);
    }

    return ergebnis.take(3).map((i) => _country(i)!).toList();
  }

  // ── Gesamt-BIP ─────────────────────────────────────────────────────────────

  static String _bipFuer(Country co) =>
      SkalaService.bipGesamt(co.gdp.toDouble()).format(co.gdp.toDouble());

  static Future<List<Frage>> _bipGesamtQuiz(LernStation station, List<String> pool) async {
    // gdp: 0 ist ein Platzhalter für "keine Daten" (siehe _SpielKategorie).
    bool hatBip(String c) => (_country(c)?.gdp ?? 0) > 0;
    final mitBip = pool.where(hatBip).toList();
    if (!_traegtAbschnitt(mitBip.length, station.fragenAnzahl)) {
      return await _hauptstaedteMultiple(
          station, pool, 'Welt', station.schwierigkeitsgrad);
    }

    final ausgewaehlt = _erweitert(_pick(mitBip, station.fragenAnzahl),
        station.fragenAnzahl, _kontinent(station), hatBip);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      final richtig = _bipFuer(co);
      final distrIso2 = AntwortGenerator.generiereOptionenAusListe(
              iso2, mitBip, anzahlOptionen: 4)
          .where((c) => c != iso2)
          .take(3)
          .toList();
      final optionen = [
        richtig,
        ...distrIso2.map((c) => _bipFuer(_country(c)!)),
      ]..shuffle(_rng);

      return Frage(
        id: '${station.id}_bg_${e.key}',
        frage: t('Wie hoch ist das BIP (Bruttoinlandsprodukt) von {land}?', {'land': co.name}),
        richtigeAntwort: richtig,
        antwortOptionen: optionen,
        modus: LernModus.bipGesamt,
        laenderCode: iso2,
      );
    }).toList();
  }

  // ── Fläche ───────────────────────────────────────────────────────────────

  static String _flaecheFuer(double area) => SkalaService.flaeche(area).format(area);

  static Future<List<Frage>> _flaecheQuiz(LernStation station, List<String> pool) async {
    bool hatFlaeche(String c) => _ranking(c)?.area != null;
    final mitFlaeche = pool.where(hatFlaeche).toList();
    if (!_traegtAbschnitt(mitFlaeche.length, station.fragenAnzahl)) {
      return await _hauptstaedteMultiple(
          station, pool, 'Welt', station.schwierigkeitsgrad);
    }

    final ausgewaehlt = _erweitert(_pick(mitFlaeche, station.fragenAnzahl),
        station.fragenAnzahl, _kontinent(station), hatFlaeche);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      final area = _ranking(iso2)!.area!;
      final richtig = _flaecheFuer(area);
      final distrIso2 = AntwortGenerator.generiereOptionenAusListe(
              iso2, mitFlaeche, anzahlOptionen: 4)
          .where((c) => c != iso2)
          .take(3)
          .toList();
      final optionen = [
        richtig,
        ...distrIso2.map((c) => _flaecheFuer(_ranking(c)!.area!)),
      ]..shuffle(_rng);

      return Frage(
        id: '${station.id}_fl_${e.key}',
        frage: t('Wie groß ist die Fläche von {land}?', {'land': co.name}),
        richtigeAntwort: richtig,
        antwortOptionen: optionen,
        modus: LernModus.flaeche,
        laenderCode: iso2,
      );
    }).toList();
  }

  // ── Währung → Land (umgekehrtes Währungsquiz) ────────────────────────────

  static Future<List<Frage>> _waehrungZuLand(LernStation station, List<String> pool) async {
    // Jede Währung darf in der Station nur EINMAL gefragt werden — sonst
    // stünden zwei Fragen „Welches Land nutzt Franken?" mit verschiedenen
    // richtigen Antworten nebeneinander.
    //
    // EINDEUTIG HEISST SEIT DEM WEGFALL DES CODES: auch der ANGEZEIGTE Name
    // muss einmalig sein, nicht nur der Währungscode. Vorher stand in der
    // Frage "Franken (CHF)", und der Code trennte, was der Kurzname
    // zusammenwirft: "Dollar" steht für USD, CAD, SGD, TWD, AUD und NZD,
    // "Krone" für SEK, NOK, DKK und CZK, "Dinar" für sieben Währungen.
    //
    // Gezogen wird der Reihe nach, statt vorher zu filtern: Früher fiel
    // JEDES Land raus, dessen Währung im Pool mehrfach vorkam — von 54
    // afrikanischen Ländern blieben sechs übrig, und _pick() füllte den Rest
    // mit Wiederholungen auf. Jetzt kommt das erste Franc-Land durch und nur
    // die weiteren werden übersprungen.
    final codes = <String>{};
    final namen = <String>{};
    final gewaehlt = <String>[];
    void nimm(Iterable<String> kandidaten) {
      for (final iso2 in kandidaten) {
        if (gewaehlt.length >= station.fragenAnzahl) return;
        final curr = _waehrungByIso2![iso2];
        if (curr == null) continue;
        final name = _kuerzeWaehrungsname(curr);
        if (codes.contains(curr.currencyCode) || namen.contains(name)) continue;
        codes.add(curr.currencyCode);
        namen.add(name);
        gewaehlt.add(iso2);
      }
    }

    nimm(pool.toSet().toList()..shuffle(_rng));
    // Trägt der Abschnitt den Modus nicht, lieber ein anderer Modus mit den
    // eigenen Ländern als dieser mit fremden (Stufe 1 der Kette).
    if (!_traegtAbschnitt(gewaehlt.length, station.fragenAnzahl)) {
      return await _hauptstaedteMultiple(
          station, pool, 'Welt', station.schwierigkeitsgrad);
    }
    if (gewaehlt.length < station.fragenAnzahl) {
      final kontinent = _kontinent(station);
      final drin = gewaehlt.toSet();
      final rest = _waehrungByIso2!.keys.where((c) => !drin.contains(c));
      if (kontinent != 'Welt') {
        nimm(rest.where((c) => _country(c)?.region == kontinent).toList()
          ..shuffle(_rng));
      }
      nimm(rest.toList()..shuffle(_rng));
    }

    final ausgewaehlt = gewaehlt;
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      final curr = _waehrungByIso2![iso2]!;
      // Nur der Name, ohne den Code in Klammern — wie in der Gegenrichtung
      // (siehe _waehrung): Für die meisten Spieler sagt "(CHF)" nichts, und
      // wer den Code kennt, kennt auch das Land. Dass der Name allein
      // trennscharf bleibt, sichert der Filter oben.
      final waehrungsName = _kuerzeWaehrungsname(curr);
      // ── ABLENKER, DIE NICHT AUCH RICHTIG SIND ──────────────────────────
      //
      // NICHT über AntwortGenerator.generiereOptionenAusListe: Das füllt aus
      // dem ganzen Kontinent auf, sobald die übergebene Liste zu kurz ist,
      // und geht dabei am Währungsfilter vorbei. Auf einem dünnen Pool kam
      // so heraus: "Welches Land nutzt Euro?" mit Luxemburg, Finnland,
      // Nordmazedonien und Deutschland — drei davon richtig. Am Gerät
      // gesehen, nicht ausgedacht.
      //
      // Hier wird stattdessen selbst gezogen, mit genau einer Bedingung:
      // Kein Ablenker darf dieselbe Währung tragen wie die Antwort — weder
      // denselben Code noch denselben angezeigten Namen. Bevorzugt aus
      // derselben Weltgegend, dann global aufgefüllt.
      // NUR LÄNDER MIT BEKANNTER WÄHRUNG kommen als Ablenker in Frage. Wer
      // nicht im Währungsdatensatz steht, lässt sich nicht prüfen — und
      // genau das ging schief: Zypern nutzt den Euro, fehlt aber in
      // currencies.dart, rutschte damit durch jede Prüfung und stand neben
      // Deutschland in der Auswahl. Zweiter Anlauf, wieder am Gerät gesehen.
      //
      // Der Datensatz trägt rund 80 Länder — für drei Ablenker mehr als
      // genug.
      bool andereWaehrung(String c) {
        final andere = _waehrungByIso2![c]!;
        return andere.currencyCode != curr.currencyCode &&
            _kuerzeWaehrungsname(andere) != waehrungsName;
      }

      final mitBekannterWaehrung = _waehrungByIso2!.keys
          .where((c) => c != iso2 && andereWaehrung(c))
          .toList();
      final gleicheGegend = mitBekannterWaehrung
          .where((c) => _country(c)?.region == co.region)
          .toList()
        ..shuffle(_rng);
      final restDerWelt = mitBekannterWaehrung
          .where((c) => _country(c)?.region != co.region)
          .toList()
        ..shuffle(_rng);
      final distrIso2 = [...gleicheGegend, ...restDerWelt].take(3).toList();
      final optionen = [
        co.name,
        ...distrIso2.map((c) => _country(c)?.name ?? c),
      ]..shuffle(_rng);

      return Frage(
        id: '${station.id}_wl_${e.key}',
        frage: t('Welches Land nutzt {w}?', {'w': waehrungsName}),
        richtigeAntwort: co.name,
        antwortOptionen: optionen,
        modus: LernModus.waehrungZuLand,
        // Absichtlich leer: würde sonst per Landkopf die Antwort verraten.
        laenderCode: '',
        // Das Währungszeichen für die Münze über der Frage (siehe
        // _WaehrungMuenze im Quiz-Screen). Es verrät nichts: Zum Zeichen
        // gehören oft mehrere Länder, und wer € erkennt, weiss deshalb noch
        // nicht, welches der vier Länder in der Auswahl gemeint ist.
        //
        // Leer heisst: Die Währung hat kein echtes Zeichen, die Münze bleibt
        // blank. Der Schlüssel steht trotzdem da — an ihm erkennt die
        // Oberfläche, dass hier überhaupt eine Münze hingehört.
        meta: {'symbol': _waehrungsZeichen(curr)},
      );
    }).toList();
  }

  // ── Extremfrage (Superlativ) ─────────────────────────────────────────────
  //
  // Frage-Text passend zur Kategorie UND Richtung (größte/meiste vs.
  // kleinste/wenigste) — dieselbe Zuordnung wird von _extremFrage() und
  // _extremFrageLeicht() genutzt, damit beide Varianten konsistent klingen.
  /// Fragetext des Superlativ-Quiz.
  ///
  /// Der deutsche Satz ist zugleich der Übersetzungsschlüssel — dasselbe
  /// Muster wie lernModusLabel(). Vorher lieferte die Funktion rohe Strings,
  /// die als Frage durchgereicht und im Screen ungefiltert angezeigt wurden;
  /// im englischen Modus stand dort Deutsch.
  ///
  /// Das wiegt schwerer, als die Zahl der Sätze vermuten lässt: dieser Modus
  /// ist der Rückfall ALLER fünf neuen Modi bei zu dünner Datenlage (siehe
  /// die _extremFrage-Aufrufe dort), er wird also auch dann sichtbar, wenn
  /// man ihn gar nicht angesteuert hat.
  static String _extremFrageText(String katId, bool kleinstes) =>
      t(switch (katId) {
        'bevoelkerung' => kleinstes
            ? 'Welches dieser Länder hat die wenigsten Einwohner?'
            : 'Welches dieser Länder hat die meisten Einwohner?',
        'flaeche' => kleinstes
            ? 'Welches dieser Länder ist am kleinsten (Fläche)?'
            : 'Welches dieser Länder ist am größten (Fläche)?',
        'bipGesamt' => kleinstes
            ? 'Welches dieser Länder hat die kleinste Wirtschaft (BIP)?'
            : 'Welches dieser Länder hat die größte Wirtschaft (BIP)?',
        'bipProKopf' => kleinstes
            ? 'Welches dieser Länder hat das niedrigste BIP pro Kopf?'
            : 'Welches dieser Länder hat das höchste BIP pro Kopf?',
        'lebenserwartung' => kleinstes
            ? 'Welches dieser Länder hat die niedrigste Lebenserwartung?'
            : 'Welches dieser Länder hat die höchste Lebenserwartung?',
        'kuestenlange' => kleinstes
            ? 'Welches dieser Länder hat die kürzeste Küste?'
            : 'Welches dieser Länder hat die längste Küste?',
        'mindestlohn' => kleinstes
            ? 'Welches dieser Länder hat den niedrigsten Mindestlohn?'
            : 'Welches dieser Länder hat den höchsten Mindestlohn?',
        _ => 'Welches dieser Länder hat die meisten Einwohner?',
      });

  // Rotiert reihum durch alle 7 Vergleichs-Kategorien (statt nur "meiste/
  // wenigste Einwohner" + "BIP") und fragt abwechselnd nach dem größten UND
  // dem kleinsten Wert, damit die Fragen abwechslungsreicher werden.
  static const _extremKategorienProfi = [
    'bevoelkerung', 'flaeche', 'bipGesamt', 'bipProKopf',
    'lebenserwartung', 'kuestenlange', 'mindestlohn',
  ];

  static List<Frage> _extremFrage(LernStation station, List<String> pool) {
    final fragen = <Frage>[];
    for (int i = 0; i < station.fragenAnzahl; i++) {
      final katId = _extremKategorienProfi[i % _extremKategorienProfi.length];
      final kategorie = _spielKategorien.firstWhere((k) => k.id == katId);
      // Bei jedem zweiten Durchlauf durch alle Kategorien nach dem
      // kleinsten statt dem größten Wert fragen (analog zur bisherigen
      // "meiste/wenigste Einwohner"-Abwechslung, jetzt für jede Kategorie).
      final kleinstes = (i ~/ _extremKategorienProfi.length).isOdd;

      final mitDaten = pool.where((c) => kategorie.wert(c) != null).toList();
      final vierIso2 =
          mitDaten.length >= 4 ? _pick(mitDaten, 4) : _pick(pool, 4);
      final nutzbar = vierIso2.every((c) => kategorie.wert(c) != null);
      final vier = vierIso2.map((iso2) => _country(iso2)!).toList();

      late Country extrem;
      late String frageText;
      if (nutzbar) {
        extrem = kleinstes
            ? vier.reduce((a, b) =>
                kategorie.wert(a.iso2)! < kategorie.wert(b.iso2)! ? a : b)
            : vier.reduce((a, b) =>
                kategorie.wert(a.iso2)! > kategorie.wert(b.iso2)! ? a : b);
        frageText = _extremFrageText(katId, kleinstes);
      } else {
        extrem = vier.reduce((a, b) => a.population > b.population ? a : b);
        frageText = _extremFrageText('bevoelkerung', false);
      }

      fragen.add(Frage(
        id: '${station.id}_ex_$i',
        frage: frageText,
        richtigeAntwort: extrem.name,
        antwortOptionen: vier.map((c) => c.name).toList()..shuffle(_rng),
        modus: LernModus.extremFrage,
        laenderCode: '', // keine Landvorschau — würde die Antwort verraten
      ));
    }
    return fragen;
  }

  // ── Extremfrage leicht (nur sehr bekannte Länder) ─────────────────────────
  //
  // Nur die vier intuitivsten Kategorien (keine "kleinste/wenigste"-Variante
  // — das bleibt der Profi-Variante vorbehalten, damit Einsteiger-Fragen
  // einfach zu verstehen bleiben).
  static const _extremKategorienLeicht = [
    'bevoelkerung', 'flaeche', 'bipGesamt', 'lebenserwartung',
  ];

  static List<Frage> _extremFrageLeicht(LernStation station, List<String> pool) {
    // Nur die bevölkerungsreichsten (= bekanntesten) Länder des Pools als
    // Kandidaten, damit die Frage für Einsteiger intuitiv lösbar bleibt.
    final bekannt = List.of(pool)
      ..sort((a, b) =>
          (_country(b)?.population ?? 0).compareTo(_country(a)?.population ?? 0));
    final grenze = (bekannt.length * 0.6).ceil().clamp(4, bekannt.length);
    final kandidatenPool = bekannt.take(grenze).toList();

    final fragen = <Frage>[];
    for (int i = 0; i < station.fragenAnzahl; i++) {
      final katId = _extremKategorienLeicht[i % _extremKategorienLeicht.length];
      final kategorie = _spielKategorien.firstWhere((k) => k.id == katId);
      final mitDaten =
          kandidatenPool.where((c) => kategorie.wert(c) != null).toList();
      final vierIso2 = mitDaten.length >= 4
          ? _pick(mitDaten, 4)
          : _pick(kandidatenPool, 4);
      final nutzbar = vierIso2.every((c) => kategorie.wert(c) != null);
      final vier = vierIso2.map((iso2) => _country(iso2)!).toList();

      late Country extrem;
      late String frageText;
      if (nutzbar) {
        extrem = vier.reduce((a, b) =>
            kategorie.wert(a.iso2)! > kategorie.wert(b.iso2)! ? a : b);
        frageText = _extremFrageText(katId, false);
      } else {
        extrem = vier.reduce((a, b) => a.population > b.population ? a : b);
        frageText = _extremFrageText('bevoelkerung', false);
      }

      fragen.add(Frage(
        id: '${station.id}_exl_$i',
        frage: frageText,
        richtigeAntwort: extrem.name,
        antwortOptionen: vier.map((c) => c.name).toList()..shuffle(_rng),
        modus: LernModus.extremFrageLeicht,
        laenderCode: '', // keine Landvorschau — würde die Antwort verraten
      ));
    }
    return fragen;
  }

  // ── Zufalls-Fakt (Rätsel-artiger Fun-Fact) ────────────────────────────────

  static List<Frage> _zufallsFakt(LernStation station, String kontinent) {
    // Bei "Welt"-Abschnitten Fakten aus allen Kontinenten mischen, sonst
    // nur die des eigenen Kontinents (fällt auf den Gesamt-Pool zurück,
    // falls für einen Kontinent zu wenige kuratiert sind).
    final faktKontId = _normalisiereKontinent(kontinent);
    final gefiltert = kontinent == 'Welt'
        ? laenderFakten
        : laenderFakten.where((f) => f.kontinent == faktKontId).toList();
    final pool = gefiltert.isEmpty ? laenderFakten : gefiltert;

    final shuffled = List.of(pool)..shuffle(_rng);
    final ausgewaehlt = shuffled.take(station.fragenAnzahl).toList();
    if (ausgewaehlt.length < station.fragenAnzahl) {
      // Für Nordamerika sind fünf Fakten kuratiert, die Station stellt acht
      // Fragen — die letzten drei kamen doppelt. Lieber ein Fakt aus einem
      // anderen Kontinent als derselbe zweimal.
      final rest = laenderFakten.where((f) => !ausgewaehlt.contains(f)).toList()
        ..shuffle(_rng);
      ausgewaehlt.addAll(rest.take(station.fragenAnzahl - ausgewaehlt.length));
    }

    return ausgewaehlt.asMap().entries.map((e) {
      final fakt = e.value;
      final richtig = _country(fakt.richtigesLandIso)?.name ?? fakt.richtigesLandIso;

      // Kuratierte Ablenker zuerst; falls davon (z.B. wegen fehlendem
      // Land in der Datenbank) weniger als 3 übrig bleiben, dynamisch aus
      // demselben Kontinent auffüllen — nie crashen, nie leere Optionen.
      final kuratiert = fakt.ablenkerIso
          .map((iso2) => _country(iso2)?.name)
          .whereType<String>()
          .toList();
      final ablenker = <String>[...kuratiert];
      if (ablenker.length < 3) {
        final region = _kontinentAnzeigename[fakt.kontinent];
        final kandidaten = countries.where((c) =>
            c.iso2 != fakt.richtigesLandIso &&
            !fakt.ablenkerIso.contains(c.iso2) &&
            (region == null || c.region == region));
        for (final c in kandidaten) {
          if (ablenker.length >= 3) break;
          if (!ablenker.contains(c.name)) ablenker.add(c.name);
        }
      }
      final optionen = [richtig, ...ablenker.take(3)]..shuffle(_rng);

      return Frage(
        id: '${station.id}_zf_${e.key}',
        frage: t(fakt.frage),
        richtigeAntwort: richtig,
        antwortOptionen: optionen,
        modus: LernModus.zufallsFakt,
        // Absichtlich leer: das gesuchte Land ist die Antwort selbst.
        laenderCode: '',
      );
    }).toList();
  }

  // ── Bekanntes Gebäude / Wahrzeichen ────────────────────────────────────

  static List<Frage> _bekanntesGebaeude(LernStation station, String kontinent) {
    final gebKontId = _normalisiereKontinent(kontinent);
    final gefiltert = kontinent == 'Welt'
        ? laenderGebaeude
        : laenderGebaeude.where((g) => g.kontinent == gebKontId).toList();
    final pool = gefiltert.isEmpty ? laenderGebaeude : gefiltert;

    final shuffled = List.of(pool)..shuffle(_rng);
    final ausgewaehlt = <LandGebaeude>[];
    while (ausgewaehlt.length < station.fragenAnzahl) {
      ausgewaehlt.addAll(shuffled.take(station.fragenAnzahl - ausgewaehlt.length));
    }

    return ausgewaehlt.asMap().entries.map((e) {
      final geb = e.value;
      final richtig = _country(geb.richtigesLandIso)?.name ?? geb.richtigesLandIso;

      final kuratiert = geb.ablenkerIso
          .map((iso2) => _country(iso2)?.name)
          .whereType<String>()
          .toList();
      final ablenker = <String>[...kuratiert];
      if (ablenker.length < 3) {
        final region = _kontinentAnzeigename[geb.kontinent];
        final kandidaten = countries.where((c) =>
            c.iso2 != geb.richtigesLandIso &&
            !geb.ablenkerIso.contains(c.iso2) &&
            (region == null || c.region == region));
        for (final c in kandidaten) {
          if (ablenker.length >= 3) break;
          if (!ablenker.contains(c.name)) ablenker.add(c.name);
        }
      }
      final optionen = [richtig, ...ablenker.take(3)]..shuffle(_rng);

      return Frage(
        id: '${station.id}_gb_${e.key}',
        frage: t('In welchem Land steht {bauwerk}?', {'bauwerk': t(geb.bauwerk)}),
        richtigeAntwort: richtig,
        antwortOptionen: optionen,
        modus: LernModus.bekanntesGebaeude,
        // Absichtlich leer: das gesuchte Land ist die Antwort selbst.
        laenderCode: '',
      );
    }).toList();
  }

  // ── Grenzketten-Rätsel ─────────────────────────────────────────────────

  static Future<List<Frage>> _grenzkettenRaetsel(
      LernStation station, List<String> pool, String kontinent, int schw) async {
    final kontId = _normalisiereKontinent(kontinent);
    final gefiltert = kontinent == 'Welt'
        ? grenzkettenRaetsel
        : grenzkettenRaetsel.where((r) => r.kontinent == kontId).toList();
    if (!_traegtAbschnitt(gefiltert.length, station.fragenAnzahl)) {
      // Kein oder kaum ein kuratierter Eintrag für diesen Kontinent (z.B.
      // Südamerika, strukturell keine eindeutige Kette möglich) -> Modus für
      // diese Station überspringen, kein Crash, keine leere Frage.
      return await _flaggenBild(station, pool, kontinent, schw);
    }

    var ausgewaehlt =
        await _pickGrenzketten(gefiltert, station.fragenAnzahl, station);
    if (ausgewaehlt.length < station.fragenAnzahl) {
      // Für Europa sind sieben Ketten kuratiert, die Station stellt acht
      // Fragen — die achte kam vorher als Wiederholung einer der sieben.
      // Jetzt kommt sie aus einem anderen Kontinent: Eine Kette ist ohnehin
      // an ihre Länder gebunden, nicht an den Abschnitt.
      final drin = ausgewaehlt.map((r) => r.id).toSet();
      final nachschub =
          grenzkettenRaetsel.where((r) => !drin.contains(r.id)).toList()
            ..shuffle(_rng);
      ausgewaehlt = [
        ...ausgewaehlt,
        ...nachschub.take(station.fragenAnzahl - ausgewaehlt.length),
      ];
    }
    return ausgewaehlt.asMap().entries.map((e) {
      final r = e.value;
      final von = _country(r.vonLandIso)?.name ?? r.vonLandIso;
      final nach = _country(r.nachLandIso)?.name ?? r.nachLandIso;
      final optionen = [r.keinTransitIso, ...r.mussDurchIso]..shuffle(_rng);
      final kette = [r.vonLandIso, ...r.mussDurchIso, r.nachLandIso];

      return Frage(
        id: '${station.id}_gk_${e.key}',
        frage: t('Auf dem Landweg von {von} nach {nach}: durch welches dieser Länder MUSST du dabei NICHT fahren?',
            {'von': von, 'nach': nach}),
        richtigeAntwort: r.keinTransitIso,
        antwortOptionen: optionen,
        modus: LernModus.grenzkettenRaetsel,
        // Absichtlich leer: die Antwort ist eine ISO-Option, kein Landkopf.
        laenderCode: '',
        meta: {
          'vonIso': r.vonLandIso,
          'nachIso': r.nachLandIso,
          'kette': kette,
          if (r.erklaerung != null) 'erklaerung': r.erklaerung,
        },
      );
    }).toList();
  }

  /// Anti-Wiederholung für Grenzketten-Einträge innerhalb eines Abschnitts,
  /// über dieselbe Round-Robin-Persistenz wie die Länder-Kern-Modi (nur mit
  /// Rätsel-IDs statt ISO-Codes und einem eigenen Thema-Schlüssel).
  static Future<List<GrenzkettenRaetsel>> _pickGrenzketten(
      List<GrenzkettenRaetsel> pool, int n, LernStation station) async {
    final byId = {for (final r in pool) r.id: r};
    final ids = pool.map((r) => r.id).toList();
    final kontext = stationKontext(station.id);
    final List<String> gezogen;
    if (kontext == null) {
      gezogen = _pick(ids, n);
    } else {
      final (welt, abschnitt, _) = kontext;
      // Grenzketten-IDs sind keine ISO-Codes -> die Schwierigkeits-Gewichtung
      // (landByIso-Lookup) greift hier ohnehin nicht und fällt neutral auf
      // schwierigkeit=2 zurück, die feste Reihenfolge bleibt effektiv nah am
      // Zufall — unproblematisch, da Grenzketten kein Kern-Modus ist. Anders
      // als die Kern-/Eingabe-Modi bleibt Grenzketten bewusst PRO ABSCHNITT
      // gescoped (Abschnitt-ID Teil des Schlüssels) — kein welt-weiter
      // Zyklus/keine Pensionierung dafür verlangt.
      gezogen = await _pickRoundRobin(ids, n, welt.id, 'grenzketten_${abschnitt.id}');
    }
    return gezogen.map((id) => byId[id]!).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Flächen-Vergleich — "Wie oft passt X in Y?"
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Noch nicht im Lernpfad: erreichbar nur über den Debug-Bereich der
  // Einstellungen (siehe Kommentar am LernModus-Enum).

  /// Zulässiges Größenverhältnis eines Paares.
  ///
  /// Unter Faktor 2 ist der Unterschied auf der Karte kaum zu sehen und die
  /// Frage hätte keine sinnvolle Antwort. Über Faktor 100 schrumpft das
  /// kleinere Land beim gemeinsamen Maßstab auf wenige Pixel und ist als
  /// Umriss nicht mehr erkennbar — genau das ist aber der Kern des Modus.
  static const _kVergleichMinFaktor = 2.0;
  static const _kVergleichMaxFaktor = 100.0;

  /// Rundet auf eine Zahl, die als Antwort natürlich wirkt: unter 10 exakt,
  /// bis 100 auf Fünfer, darüber auf Zehner. Ein Ergebnis wie "37×" wirkt
  /// erfunden genau, "35×" liest sich wie eine echte Antwortmöglichkeit.
  static int _rundeVergleichswert(double v) {
    if (v < 10) return v.round().clamp(2, 9);
    if (v <= 100) return (v / 5).round() * 5;
    return (v / 10).round() * 10;
  }

  /// Drei plausible Ablenker eng um [echt] herum.
  ///
  /// Fenster vom 0,7- bis zum 1,6-fachen des echten Werts. Eine weite
  /// Streuung machte die Frage zu leicht: wer 2×, 7×, 15× und 40× sieht,
  /// schließt das Unsinnige aus, statt zu schätzen. Bei 6×, 7×, 8×, 10× muss
  /// man das Größenverhältnis tatsächlich einschätzen.
  ///
  /// Bei kleinen echten Werten trägt dieses Fenster nicht: bei echt=2 reicht
  /// es von 1,4 bis 3,2 und enthält nach dem Runden nur die 3 — die 1 fällt
  /// weg, weil es in diesem Modus kein Verhältnis unter 2 gibt (siehe
  /// _kVergleichMinFaktor). Dann wird additiv nach außen erweitert: die
  /// nächstgelegenen Zahlen über und unter dem echten Wert, bis drei
  /// verschiedene zusammen sind. Das bleibt genauso eng und funktioniert ab
  /// dem kleinstmöglichen Wert.
  static List<int> _vergleichsAblenker(int echt) {
    final kandidaten = <int>{};
    void nimm(num roh) {
      final k = _rundeVergleichswert(roh.toDouble());
      if (k >= 2 && k != echt) kandidaten.add(k);
    }

    // Multiplikatives Fenster in feinen Schritten abtasten — bei großen
    // Werten rundet _rundeVergleichswert auf Fünfer bzw. Zehner, gröbere
    // Schritte würden dort Lücken lassen.
    for (var f = 0.70; f <= 1.601; f += 0.05) {
      nimm(echt * f);
    }
    for (var d = 1; kandidaten.length < 3 && d <= 20; d++) {
      nimm(echt - d);
      nimm(echt + d);
    }

    return (kandidaten.toList()..shuffle(_rng)).take(3).toList();
  }

  /// Ausweich-Modus der fuenf neuen Modi, wenn die Datenlage einer Station
  /// nicht reicht.
  ///
  /// Hauptstaedte statt des frueheren Superlativ-Quiz, aus drei Gruenden:
  /// die Daten decken alle 197 Laender ab, der Ausweichweg kann also nicht
  /// selbst ins Leere laufen; sechs bestehende Modi weichen ohnehin dorthin
  /// aus, das Muster ist etabliert; und der Modus steht weiterhin in jedem
  /// Pool, faellt dem Spieler also nicht als Fremdkoerper auf. Das
  /// Superlativ-Quiz ist seit der Pool-Umstellung nirgends mehr regulaer zu
  /// sehen — als Ausweichziel haette es wie ein Fehler gewirkt.
  static Future<List<Frage>> _ausweichHauptstaedte(
          LernStation station, List<String> pool) =>
      _hauptstaedteMultiple(
          station, pool, _kontinent(station), station.schwierigkeitsgrad);

  // ══════════════════════════════════════════════════════════════════════════
  // Paare ziehen — die gemeinsame Stelle für Flächen-Vergleich und
  // Nachbarschafts-Kette
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Beide Modi stellen eine Frage aus ZWEI Ländern und dürfen kein Land
  // zweimal verwenden. Sie hatten dieselbe Schleife doppelt stehen — und
  // damit auch denselben Fehler zweimal.
  //
  // ── WARUM EIN DURCHLAUF NICHT GENÜGT ──────────────────────────────────────
  //
  // Hier stand einmal "Ein Durchlauf über die gemischte Kandidatenliste
  // genügt: fällt ein Land aus, rückt einfach das nächste nach." Das stimmt
  // nicht, und der Satz hat den Fehler jahrelang plausibel aussehen lassen.
  //
  // Die Paarbildung geht gierig vor: Jedes Land nimmt sich den erstbesten
  // freien Partner. Eine frühe Paarung kann damit einem später betrachteten
  // Land seinen EINZIGEN möglichen Partner wegnehmen — das Land findet dann
  // keinen mehr, wird übersprungen, und am Ende fehlt eine Frage. Gemessen
  // an 60 Durchgängen über den ganzen Lernpfad traf das afrika_2_10
  // (Flächen-Vergleich, 7 Fragen aus 18 Ländern — also 14 der 18 müssen
  // paarweise aufgehen) in 4 Fällen und suedamerika_2_11
  // (Nachbarschafts-Kette) in einem. An den Daten liegt es nicht: dieselbe
  // Station geht in den übrigen Durchgängen auf, es entscheidet allein die
  // Ziehreihenfolge.
  //
  // ── WARUM DER ZWEITE DURCHLAUF EIN PAAR AUFTRENNT ────────────────────────
  //
  // Ein schlichter zweiter Durchlauf über die übrig gebliebenen Länder
  // brächte nachweislich nichts. Ein übersprungenes Land bleibt frei; bei
  // jedem später betrachteten Land wurde es also bereits mitgeprüft und für
  // unpassend befunden. Übrig gebliebene Länder sind damit UNTEREINANDER
  // unverträglich — ein zweiter Durchlauf über sie fände dieselbe leere
  // Menge wie der erste.
  //
  // Es hilft nur, eine bestehende Paarung aufzutrennen: Findet sich für ein
  // übrig gebliebenes X ein bereits vergebenes A, das zu X passt, und kommt
  // As bisheriger Partner B mit einem anderen übrig gebliebenen Y zusammen,
  // dann werden aus einem Paar zwei. Genau das macht [_paareZiehen] in
  // seinem zweiten Durchlauf.
  //
  // WER HIER AUFRÄUMT: Der zweite Durchlauf ist kein Sicherheitsnetz für
  // einen selten gewordenen Fall, sondern der Grund, warum die betroffenen
  // Stationen überhaupt ihre volle Fragenzahl liefern. keine_doppelten_-
  // fragen_test.dart ("Keine Station verliert dabei Fragen") fällt ohne ihn
  // in rund jedem achten Lauf um.

  /// Zieht Paare aus [kandidaten], bis [anzahl] Stück beisammen sind.
  ///
  /// [partnerFuer] liefert alle Länder, die zu `erster` passen — ohne die
  /// bereits vergebenen und ohne `erster` selbst. Die Reihenfolge darin ist
  /// egal, gemischt wird hier.
  ///
  /// [baue] darf null liefern, wenn sich aus dem Paar doch keine Frage bauen
  /// lässt; dann wird der nächste Partner probiert, statt das ganze Land
  /// fallen zu lassen.
  static List<T> _paareZiehen<T>({
    required List<String> kandidaten,
    required int anzahl,
    required List<String> Function(String erster, Set<String> vergeben)
        partnerFuer,
    required T? Function(String erster, String zweiter, int index) baue,
  }) {
    // Erst die PAARE bilden, die Fragen erst ganz am Ende. Ein Paar
    // aufzutrennen heisst sonst, in einer Liste schon gebauter Fragen die
    // richtige wiederzufinden und zu ersetzen — Indexrechnerei, bei der ein
    // Fehler still eine falsche Frage entfernt.
    final paare = <List<String>>[];
    final vergeben = <String>{};

    // ── Erster Durchlauf: gierig ────────────────────────────────────────────
    for (final erster in List<String>.from(kandidaten)..shuffle(_rng)) {
      if (paare.length >= anzahl) break;
      if (vergeben.contains(erster)) continue;
      final moeglich = partnerFuer(erster, vergeben)..shuffle(_rng);
      if (moeglich.isEmpty) continue;
      paare.add([erster, moeglich.first]);
      vergeben.addAll([erster, moeglich.first]);
    }

    // ── Zweiter Durchlauf: ein Paar auftrennen ──────────────────────────────
    if (paare.length < anzahl) {
      final uebrig = kandidaten.where((c) => !vergeben.contains(c)).toList()
        ..shuffle(_rng);

      for (final x in uebrig) {
        if (paare.length >= anzahl) break;
        if (vergeben.contains(x)) continue;

        // Wer passt zu X? Unter den FREIEN hat der erste Durchlauf schon
        // nachgesehen und nichts gefunden — es bleiben die vergebenen.
        final passendeZuX = partnerFuer(x, const <String>{})
            .where(vergeben.contains)
            .toList()
          ..shuffle(_rng);

        for (final a in passendeZuX) {
          final idx = paare.indexWhere((p) => p.contains(a));
          if (idx < 0) continue;
          final b = paare[idx][0] == a ? paare[idx][1] : paare[idx][0];

          // Wäre (A,B) aufgetrennt: A ginge zu X. Findet B dann noch einen
          // anderen Übriggebliebenen, sind aus einem Paar zwei geworden.
          final gesperrt = {...vergeben}
            ..removeAll([a, b])
            ..add(x)
            ..add(a);
          final fuerB = partnerFuer(b, gesperrt)..shuffle(_rng);
          if (fuerB.isEmpty) continue;

          paare[idx] = [x, a];
          paare.add([b, fuerB.first]);
          vergeben.addAll([x, fuerB.first]);
          break;
        }
      }
    }

    // ── Und jetzt erst die Fragen ───────────────────────────────────────────
    final raus = <T>[];
    for (final paar in paare) {
      if (raus.length >= anzahl) break;
      // null heisst: aus diesem Paar liess sich doch keine Frage bauen. Das
      // ist eine Absicherung, kein Normalfall — [partnerFuer] soll solche
      // Paare gar nicht erst anbieten.
      final gebaut = baue(paar[0], paar[1], raus.length);
      if (gebaut != null) raus.add(gebaut);
    }
    return raus;
  }

  static Future<List<Frage>> _flaechenVergleich(
      LernStation station, List<String> pool) async {
    // Nur Länder mit Flächendaten UND brauchbarem Umriss: der Modus zeigt
    // beide Silhouetten, die Zwergstaaten aus kUmrissAusschluss fallen
    // deshalb genauso raus wie im Umriss-Quiz.
    final kandidaten = pool
        .where((c) =>
            (_ranking(c)?.area ?? 0) > 0 && kannAlsUmrissErscheinen(c))
        .toList();
    if (kandidaten.length < 2) return _ausweichHauptstaedte(station, pool);

    final flaeche = {for (final c in kandidaten) c: _ranking(c)!.area!};

    // Innerhalb einer Station kommt jedes Land höchstens EINMAL vor — egal ob
    // als großes oder als kleines. Damit kann sich auch keine Paarung
    // wiederholen, und es fällt nicht auf, dass zweimal dasselbe Land die
    // Vorlage gibt. Wie die Paare gebildet werden — und warum ein Durchlauf
    // dafür nicht reicht — steht bei [_paareZiehen].
    return _paareZiehen<Frage>(
      kandidaten: kandidaten,
      anzahl: station.fragenAnzahl,
      // Der Partner ist immer das KLEINERE Land: der Faktor ist gross/klein
      // und muss mindestens 2 sein.
      partnerFuer: (gross, vergeben) => kandidaten.where((k) {
        if (k == gross || vergeben.contains(k)) return false;
        final f = flaeche[gross]! / flaeche[k]!;
        return f >= _kVergleichMinFaktor && f <= _kVergleichMaxFaktor;
      }).toList(),
      baue: (gross, klein, index) {
        final echt = _rundeVergleichswert(flaeche[gross]! / flaeche[klein]!);
        final optionen = [
          '$echt×',
          ..._vergleichsAblenker(echt).map((v) => '$v×'),
        ]..shuffle(_rng);

        final grossCo = _country(gross);
        final kleinCo = _country(klein);
        return Frage(
          id: '${station.id}_fv_$index',
          frage: t('Wie oft passt {klein} in {gross}?', {
            'klein': kleinCo?.name ?? landByIso[klein]?.name ?? klein,
            'gross': grossCo?.name ?? landByIso[gross]?.name ?? gross,
          }),
          richtigeAntwort: '$echt×',
          antwortOptionen: optionen,
          modus: LernModus.flaechenVergleich,
          // Das GROSSE Land steht im laenderCode: es gibt den Maßstab vor und
          // ist das Land, auf das sich die Frage bezieht. Das kleine kommt
          // über meta dazu — Frage trägt nur ein laenderCode-Feld.
          laenderCode: gross,
          meta: {'kleinesLand': klein, 'verhaeltnis': echt},
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Zwei Wahrheiten, eine Lüge
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Noch nicht im Lernpfad: erreichbar nur über den Debug-Bereich.

  /// Baut eine Aussage samt ihrer Herkunft, oder null bei fehlendem Text.
  ///
  /// Die Familie verhindert, dass zwei Aussagen derselben Vorlage in einer
  /// Frage landen — sonst stünden z.B. zwei Hauptstadt-Sätze nebeneinander,
  /// von denen sich einer schon durch den Widerspruch verrät.
  static (String, String)? _aussage(String familie, String? text) =>
      (text == null || text.isEmpty) ? null : (text, familie);

  /// Setzt den Satzpunkt nur, wenn nicht schon einer da ist.
  ///
  /// Formatierte Bevölkerungszahlen enden je nach Größenordnung selbst auf
  /// einen Punkt ("3,4 Mio.") — ohne diese Prüfung stünde dort "3,4 Mio..".
  static String _mitSatzpunkt(String s) => s.endsWith('.') ? s : '$s.';

  static String _bevoelkerungsText(double einwohner) =>
      SkalaService.bevoelkerung(einwohner).format(einwohner);

  static String _bevoelkerungsAussage(double einwohner) => _mitSatzpunkt(
      t('Die Bevölkerung liegt bei etwa {n}',
          {'n': _bevoelkerungsText(einwohner)}));

  /// Alle WAHREN Aussagen, die sich für [iso2] aus den Daten belegen lassen.
  static List<(String, String)> _wahreAussagen(String iso2) {
    final co = _country(iso2);
    if (co == null) return const [];
    final ergebnis = <(String, String)?>[];

    ergebnis.add(_aussage(
        'hauptstadt', t('Die Hauptstadt ist {stadt}.', {'stadt': co.capital})));

    final waehrung = _waehrungByIso2![iso2];
    if (waehrung != null) {
      // "Die Währung heißt X" statt "Hier wird mit X bezahlt": die
      // Währungsnamen stehen in currencies.dart im Nominativ, im Dativ
      // ergäbe das falsches Deutsch ("mit Georgischer Lari bezahlt").
      ergebnis.add(_aussage(
          'waehrung',
          t('Die Währung heißt {waehrung}.',
              {'waehrung': t(waehrung.currencyName)})));
    }

    final echteNachbarn = nachbarn[iso2] ?? const <String>[];
    if (echteNachbarn.isNotEmpty) {
      final n = echteNachbarn[_rng.nextInt(echteNachbarn.length)];
      // "Ein Nachbarland ist X" statt "{land} grenzt an X": Ländernamen im
      // Plural (Malediven, Niederlande, Philippinen) bekämen sonst ein
      // Verb im Singular. Das gefragte Land steht ohnehin schon in der
      // Frage darüber, im Satz wird es nicht gebraucht.
      ergebnis.add(_aussage(
          'nachbar',
          t('Ein Nachbarland ist {nachbar}.', {
            'nachbar': _country(n)?.name ?? landByIso[n]?.name ?? n,
          })));
    }

    if (co.population > 0) {
      ergebnis.add(_aussage(
          'bevoelkerung', _bevoelkerungsAussage(co.population.toDouble())));
    }

    // Kuratierte Fun-Facts: bereits als Aussagesatz formuliert und in
    // sektorFunFactsEn/waehrungsFunFactsEn übersetzt, deshalb 1:1 nutzbar.
    final sektor = _sektorByIso2![iso2];
    if (sektor != null && sektor.funFact.isNotEmpty) {
      ergebnis.add(_aussage('sektorFakt', t(sektor.funFact)));
    }
    // Währungs-Fun-Facts nur, wenn die Währung genau diesem Land gehört —
    // der Euro-Fakt wäre sonst eine "Aussage über Portugal", die genauso auf
    // 19 andere Länder zutrifft.
    if (waehrung != null && waehrung.funFact.isNotEmpty) {
      final teilen = _waehrungByIso2!.values
          .where((w) => w.currencyCode == waehrung.currencyCode)
          .length;
      if (teilen == 1) {
        ergebnis.add(_aussage('waehrungFakt', t(waehrung.funFact)));
      }
    }

    return ergebnis.whereType<(String, String)>().toList();
  }

  /// Länder derselben Subregion (sonst desselben Kontinents, sonst der Welt)
  /// als Quelle für den ausgetauschten Wert. Eine asiatische Hauptstadt bei
  /// einem europäischen Land wäre auf den ersten Blick zu erkennen.
  static List<String> _regionsNachbarn(String iso2) {
    final land = _land(iso2);
    if (land != null) {
      final subregion = alleLaender
          .where((l) => l.region == land.region && l.iso != iso2)
          .map((l) => l.iso)
          .where((i) => _country(i) != null)
          .toList();
      if (subregion.length >= 3) return subregion..shuffle(_rng);
      final kontinent = alleLaender
          .where((l) => l.kontinent == land.kontinent && l.iso != iso2)
          .map((l) => l.iso)
          .where((i) => _country(i) != null)
          .toList();
      if (kontinent.length >= 3) return kontinent..shuffle(_rng);
    }
    return countries.map((c) => c.iso2).where((i) => i != iso2).toList()
      ..shuffle(_rng);
  }

  /// Die ERFUNDENE Aussage — eine wahre Vorlage mit ausgetauschtem Wert.
  ///
  /// Jede Variante prüft ihren Austausch gegen dieselben Daten, aus denen die
  /// wahren Aussagen stammen; nur was dort nachweislich NICHT zutrifft, wird
  /// verwendet. Vorlagen ohne solche Prüfmöglichkeit — die kuratierten
  /// Fun-Facts — kommen als Lüge nicht in Frage.
  /// Liefert zusätzlich zur Aussage die BEGRÜNDUNG, warum sie falsch ist.
  ///
  /// Möglich ist das, weil hier beide Werte vorliegen: der ausgetauschte und
  /// der echte. Später aus dem fertigen Fragetext lässt sich das nicht mehr
  /// rekonstruieren, deshalb wandert die Begründung gleich mit in die Frage.
  static ({String text, String familie, String erklaerung})? _erfundeneAussage(
      String iso2, Set<String> vergebeneFamilien) {
    final co = _country(iso2);
    if (co == null) return null;
    final kandidatenLaender = _regionsNachbarn(iso2);
    final familien = ['hauptstadt', 'waehrung', 'nachbar', 'bevoelkerung']
        .where((f) => !vergebeneFamilien.contains(f))
        .toList()
      ..shuffle(_rng);

    for (final familie in familien) {
      switch (familie) {
        case 'hauptstadt':
          for (final anderes in kandidatenLaender) {
            final fremd = _country(anderes)!;
            // Gegen BEIDE Sprachformen prüfen: der Fragetext wird in der
            // gerade aktiven Sprache erzeugt und gespeichert, ein späterer
            // Sprachwechsel darf die Aussage nicht wahr werden lassen.
            if (fremd.capitalDe == co.capitalDe) continue;
            if (fremd.capital == co.capital) continue;
            return (
              text: t('Die Hauptstadt ist {stadt}.', {'stadt': fremd.capital}),
              familie: familie,
              erklaerung: t('Die Hauptstadt ist {richtig}, nicht {falsch}.',
                  {'richtig': co.capital, 'falsch': fremd.capital}),
            );
          }
        case 'waehrung':
          final eigene = _waehrungByIso2![iso2];
          if (eigene == null) continue;
          for (final anderes in kandidatenLaender) {
            final fremd = _waehrungByIso2![anderes];
            if (fremd == null) continue;
            // Über den Code vergleichen, nicht über den Namen: derselbe Euro
            // trägt in beiden Einträgen denselben Code, während zwei
            // verschiedene "Dollar" sich im Namen nur ähneln.
            if (fremd.currencyCode == eigene.currencyCode) continue;
            if (fremd.currencyName == eigene.currencyName) continue;
            return (
              text: t('Die Währung heißt {waehrung}.',
                  {'waehrung': t(fremd.currencyName)}),
              familie: familie,
              erklaerung: t('Die Währung ist {richtig}, nicht {falsch}.', {
                'richtig': t(eigene.currencyName),
                'falsch': t(fremd.currencyName),
              }),
            );
          }
        case 'nachbar':
          final echte = nachbarn[iso2] ?? const <String>[];
          for (final anderes in kandidatenLaender) {
            // Beide Richtungen prüfen: die Nachbarn-Map ist gepflegt, aber
            // eine einseitig fehlende Kante würde hier eine wahre Aussage
            // als Lüge ausgeben.
            if (echte.contains(anderes)) continue;
            if ((nachbarn[anderes] ?? const []).contains(iso2)) continue;
            return (
              text: t('Ein Nachbarland ist {nachbar}.',
                  {'nachbar': _country(anderes)!.name}),
              familie: familie,
              // Bewusst als "haben keine gemeinsame Grenze" formuliert: die
              // Konstruktion trägt beide Länder als Subjekte und funktioniert
              // damit auch bei Namen im Plural (Malediven, Niederlande).
              erklaerung: t('{land} und {falsch} haben keine gemeinsame Grenze.',
                  {'land': co.name, 'falsch': _country(anderes)!.name}),
            );
          }
        case 'bevoelkerung':
          if (co.population <= 0) continue;
          for (final anderes in kandidatenLaender) {
            final fremd = _country(anderes)!;
            if (fremd.population <= 0) continue;
            // "etwa" macht kleine Abweichungen zur Auslegungsfrage — deshalb
            // mindestens Faktor 4 Abstand. Dann ist die Aussage eindeutig
            // falsch und nicht bloß ungenau.
            final verhaeltnis = fremd.population / co.population;
            if (verhaeltnis > 0.25 && verhaeltnis < 4) continue;
            return (
              text: _bevoelkerungsAussage(fremd.population.toDouble()),
              familie: familie,
              erklaerung: _mitSatzpunkt(t(
                  'Die Bevölkerung liegt bei etwa {richtig}, nicht bei {falsch}',
                  {
                    'richtig': _bevoelkerungsText(co.population.toDouble()),
                    'falsch': _bevoelkerungsText(fremd.population.toDouble()),
                  })),
            );
          }
      }
    }
    return null;
  }

  static Future<List<Frage>> _zweiWahrheiten(
      LernStation station, List<String> pool) async {
    final brauchbar = pool.where((c) => _country(c) != null).toList();
    if (brauchbar.isEmpty) return _ausweichHauptstaedte(station, pool);

    final fragen = <Frage>[];
    // Ein Durchlauf über die gemischte Liste: dadurch kann kein Land zweimal
    // gefragt werden. Länder ohne genug belegbare Aussagen werden einfach
    // übersprungen.
    {
      final reihenfolge = List<String>.from(brauchbar)..shuffle(_rng);
      for (final iso2 in reihenfolge) {
        if (fragen.length >= station.fragenAnzahl) break;
        final wahr = _wahreAussagen(iso2)..shuffle(_rng);
        if (wahr.length < 2) continue;

        // Zwei wahre Aussagen aus VERSCHIEDENEN Vorlagen.
        final gewaehlt = <(String, String)>[];
        final familien = <String>{};
        for (final a in wahr) {
          if (gewaehlt.length == 2) break;
          if (familien.contains(a.$2)) continue;
          gewaehlt.add(a);
          familien.add(a.$2);
        }
        if (gewaehlt.length < 2) continue;

        final luege = _erfundeneAussage(iso2, familien);
        if (luege == null) continue;

        final co = _country(iso2)!;
        final optionen = [luege.text, gewaehlt[0].$1, gewaehlt[1].$1]
          ..shuffle(_rng);
        fragen.add(Frage(
          id: '${station.id}_zw_${fragen.length}',
          frage:
              t('Welche Aussage über {land} stimmt NICHT?', {'land': co.name}),
          richtigeAntwort: luege.text,
          antwortOptionen: optionen,
          modus: LernModus.zweiWahrheiten,
          laenderCode: iso2,
          meta: {
            'luegenFamilie': luege.familie,
            // Die Begründung entsteht beim Erzeugen der Lüge, wo echter und
            // ausgetauschter Wert beide vorliegen — die Auflösung im Screen
            // kann sie nicht mehr herleiten.
            'erklaerung': luege.erklaerung,
          },
        ));
      }
    }
    return fragen;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Was gehört nicht dazu?
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Noch nicht im Lernpfad: erreichbar nur über den Debug-Bereich.

  /// Anzeigename einer Kontinent-ID aus alle_laender.dart.
  ///
  /// Bewusst NICHT kontinentNameFuerId() aus portfolio_daten.dart: dessen
  /// ID-Raum stammt aus dem Portfolio-Modell und kennt nur ein gemeinsames
  /// 'amerika'. Für 'nordamerika' und 'suedamerika' fiel es auf "Andere"
  /// zurück — in beiden Sprachen falsch. Die Namen hier sind bereits über
  /// uebersetzungen_lernen.dart übersetzt.
  static String _kontinentAnzeige(String id) => t(switch (id) {
        'europa' => 'Europa',
        'asien' => 'Asien',
        'afrika' => 'Afrika',
        'nordamerika' => 'Nordamerika',
        'suedamerika' => 'Südamerika',
        'ozeanien' => 'Ozeanien',
        _ => id,
      });

  /// Die prüfbaren Merkmale. Amtssprache fehlt bewusst — dafür liegen im
  /// Projekt keine Daten vor (weder countries.dart noch alle_laender.dart
  /// führen eine Sprache).
  static List<_Merkmal> get _merkmale => [
        _Merkmal(
          'kontinent',
          'Kontinent',
          (iso) => _land(iso)?.kontinent,
          (w) => t('Die anderen drei liegen alle in {wert}.',
              {'wert': _kontinentAnzeige(w)}),
        ),
        _Merkmal(
          'waehrung',
          'Währung',
          (iso) => _waehrungByIso2![iso]?.currencyCode,
          (w) {
            final name = _waehrungByIso2!.values
                .firstWhere((c) => c.currencyCode == w)
                .currencyName;
            return t('Die anderen drei bezahlen alle mit {wert}.',
                {'wert': t(name)});
          },
        ),
        // EU-Mitgliedschaft als JA/NEIN statt als Block-Name: der generische
        // Block-Wert wäre für die meisten Länder "Keiner davon" — und "diese
        // drei sind in keinem Bündnis" ist keine Gemeinsamkeit, die man lernt.
        _Merkmal(
          'eu',
          'EU-Mitgliedschaft',
          (iso) => primaryBlockFor(iso) == 'EU' ? 'ja' : 'nein',
          (w) => w == 'ja'
              ? t('Die anderen drei sind alle EU-Mitglied.')
              : t('Die anderen drei sind alle kein EU-Mitglied.'),
        ),
        _Merkmal(
          'binnenstaat',
          'Binnenstaat oder Küste',
          (iso) {
            final k = _ranking(iso)?.coastlineKm;
            return k == null ? null : (k == 0 ? 'ja' : 'nein');
          },
          (w) => w == 'ja'
              ? t('Die anderen drei sind alle Binnenstaaten ohne Meereszugang.')
              : t('Die anderen drei haben alle einen Meereszugang.'),
        ),
        _Merkmal(
          'halbkugel',
          'Nord- oder Südhalbkugel',
          (iso) {
            final co = _country(iso);
            return co == null ? null : (co.latitude >= 0 ? 'nord' : 'sued');
          },
          (w) => w == 'nord'
              ? t('Die anderen drei liegen alle auf der Nordhalbkugel.')
              : t('Die anderen drei liegen alle auf der Südhalbkugel.'),
        ),
        _Merkmal(
          'hauptsektor',
          'Wichtigster Wirtschaftssektor',
          (iso) => _sektorByIso2![iso]?.mainSector,
          (w) => t('Die anderen drei leben hauptsächlich von: {wert}.',
              {'wert': t(w)}),
        ),
      ];

  /// Die Merkmale, auf die "Was gehört nicht dazu?" prüfen kann — übersetzt,
  /// für den Hilfe-Dialog im Quiz.
  ///
  /// Kommt aus derselben Liste, die der Generator auswertet, plus der
  /// Grenz-Beziehung, die kein Merkmal eines einzelnen Landes ist. Dadurch
  /// kann die angezeigte Liste nicht von den geprüften Merkmalen abweichen.
  static List<String> get quartettKategorien => [
        for (final m in _merkmale) t(m.label),
        t('Gemeinsame Grenze zu einem Land'),
      ];

  /// Länder, an die GENAU DREI des Quartetts grenzen — je Außenseiter ein
  /// Beispiel-Grenzland.
  ///
  /// Kein normales Merkmal: Nachbarschaft ist keine Eigenschaft eines
  /// einzelnen Landes, sondern eine Beziehung. Zeigen mehrere solche Länder
  /// auf verschiedene Außenseiter, landen beide in der Rückgabe und die
  /// Eindeutigkeitsprüfung verwirft das Quartett von selbst.
  static Map<String, String> _grenzKandidaten(List<String> vier) {
    final umgebung = <String>{};
    for (final iso in vier) {
      umgebung.addAll(nachbarn[iso] ?? const []);
    }
    umgebung.removeAll(vier);

    final ergebnis = <String, String>{};
    for (final x in umgebung) {
      final ohne =
          vier.where((i) => !(nachbarn[i] ?? const []).contains(x)).toList();
      if (ohne.length != 1) continue;
      ergebnis.putIfAbsent(ohne.first, () => x);
    }
    return ergebnis;
  }

  /// Alle Länder des Quartetts, die sich als "gehört nicht dazu" begründen
  /// ließen, samt der Begründung.
  ///
  /// Entscheidend für die Eindeutigkeit ist die Zahl der möglichen
  /// AUSSENSEITER, nicht die der Merkmale: zeigen Kontinent und Währung beide
  /// auf dasselbe Land, gibt es weiterhin genau eine richtige Antwort — die
  /// Frage ist dann sogar besser begründet, nicht mehrdeutig. Erst zwei
  /// verschiedene Außenseiter machen sie unlösbar.
  static Map<String, String> _aussenseiterKandidaten(List<String> vier) {
    final ergebnis = <String, String>{};

    for (final m in _merkmale) {
      final werte = {for (final i in vier) i: m.wert(i)};
      // Fehlt für auch nur ein Land der Wert, ist das Merkmal für dieses
      // Quartett nicht bewertbar — geraten wird nicht.
      if (werte.values.any((v) => v == null)) continue;

      final gruppen = <String, List<String>>{};
      for (final e in werte.entries) {
        (gruppen[e.value!] ??= []).add(e.key);
      }
      // Gesucht ist genau das Muster 3+1. "Alle vier gleich" und "alle vier
      // verschieden" liefern keinen Außenseiter; 2+2 ebenfalls nicht — dort
      // gibt es keinen einzelnen, der herausfällt.
      if (gruppen.length != 2) continue;
      final einzel = gruppen.values.where((g) => g.length == 1).toList();
      final drei = gruppen.values.where((g) => g.length == 3).toList();
      if (einzel.length != 1 || drei.length != 1) continue;

      ergebnis.putIfAbsent(
          einzel.first.first, () => m.aufloesung(werte[drei.first.first]!));
    }

    for (final e in _grenzKandidaten(vier).entries) {
      final land = _country(e.value)?.name ?? landByIso[e.value]?.name ?? e.value;
      ergebnis.putIfAbsent(e.key,
          () => t('Die anderen drei grenzen alle an {land}.', {'land': land}));
    }
    return ergebnis;
  }

  /// Zählt die Versuche des letzten Generatorlaufs — nur für Messungen im
  /// Debug-Bereich, im Spielbetrieb ohne Bedeutung.
  static int letzteQuartettVersuche = 0;

  static Future<List<Frage>> _wasGehoertNichtDazu(
      LernStation station, List<String> pool) async {
    final kandidaten =
        pool.where((c) => _country(c) != null && _land(c) != null).toList();
    if (kandidaten.length < 8) return _ausweichHauptstaedte(station, pool);

    final fragen = <Frage>[];
    // Kein Land darf in zwei Quartetten derselben Station auftauchen — das
    // schließt doppelte Quartette mit ein.
    final benutzteLaender = <String>{};
    // Damit nicht fünfmal hintereinander "drei liegen auf derselben
    // Halbkugel" kommt: schon verwendete Merkmale werden zurückgestellt,
    // solange es noch unbenutzte gibt.
    final benutzteMerkmale = <String>{};
    var versuche = 0;
    // Obergrenze als Notbremse: ohne sie könnte ein Pool ohne jedes
    // eindeutige Quartett (sehr kleiner Kontinent) endlos drehen.
    const maxVersuche = 6000;

    // ── Notausfahrt aus der Merkmals-Rotation ────────────────────────────────
    //
    // Es gibt genau SECHS Merkmale, und eine Station stellt genau SECHS
    // Fragen. Bei der letzten ist damit nur noch ein Merkmal unbenutzt — und
    // ohne diese Notausfahrt wäre die Schleife darauf festgenagelt. Lässt
    // sich daraus aus den verbliebenen rund 26 Ländern kein eindeutiges 3+1
    // mehr bauen, dreht sie bis [maxVersuche] und die Station kommt eine
    // Frage zu kurz.
    //
    // Gemessen an je 500 Läufen traf das welt_1_05 zweimal und welt_1_24
    // einmal; bei JEDEM Ausfall waren alle 6000 Versuche aufgebraucht,
    // während ein normaler Lauf mit rund 40 auskommt. Mit ausgeschalteter
    // Rotation: kein einziger Ausfall in 1000 Läufen.
    //
    // Die Rotation bleibt trotzdem — sie ist der Grund, warum nicht fünfmal
    // hintereinander "drei liegen auf derselben Halbkugel" kommt. Sie wird
    // nur nachgiebig, wenn sie sich festgefahren hat. Der Schwellenwert
    // liegt weit über dem Normalbedarf (~40 Versuche für SECHS Fragen, also
    // rund sieben je Frage), greift also nur im Klemmfall.
    const merkmalNotausfahrt = 50;
    var seitLetzterFrage = 0;

    while (fragen.length < station.fragenAnzahl && versuche < maxVersuche) {
      versuche++;
      seitLetzterFrage++;

      // Gezielt konstruieren statt blind würfeln: erst ein Merkmal wählen,
      // dann drei Länder mit gleichem Wert und eines mit abweichendem. Rein
      // zufällige Quartette hätten fast nie einen Außenseiter — und wenn,
      // dann meist gleich mehrere.
      final alle = _merkmale;
      final offen = alle.where((x) => !benutzteMerkmale.contains(x.id)).toList();
      final auswahl = (offen.isEmpty || seitLetzterFrage > merkmalNotausfahrt)
          ? alle
          : offen;
      final m = auswahl[_rng.nextInt(auswahl.length)];

      final nachWert = <String, List<String>>{};
      for (final i in kandidaten) {
        if (benutzteLaender.contains(i)) continue;
        final w = m.wert(i);
        if (w != null) (nachWert[w] ??= []).add(i);
      }
      final gruppen =
          nachWert.entries.where((e) => e.value.length >= 3).toList();
      if (gruppen.isEmpty) continue;

      final ziel = gruppen[_rng.nextInt(gruppen.length)];
      final drei = _pick(ziel.value, 3);
      if (drei.length < 3) continue;
      final abweichend = kandidaten
          .where((i) =>
              !drei.contains(i) &&
              !benutzteLaender.contains(i) &&
              m.wert(i) != null &&
              m.wert(i) != ziel.key)
          .toList();
      if (abweichend.isEmpty) continue;

      final aussen = abweichend[_rng.nextInt(abweichend.length)];
      final vier = [...drei, aussen];

      final moegliche = _aussenseiterKandidaten(vier);
      // Genau ein begründbarer Außenseiter — und es muss der sein, auf den
      // die Konstruktion gezielt hat.
      if (moegliche.length != 1 || !moegliche.containsKey(aussen)) continue;

      benutzteLaender.addAll(vier);
      benutzteMerkmale.add(m.id);
      // Die Notausfahrt gilt je Frage, nicht für die ganze Station: Jede
      // Frage bekommt ihre eigenen 50 Versuche mit der Rotation, bevor sie
      // nachgibt.
      seitLetzterFrage = 0;
      fragen.add(Frage(
        id: '${station.id}_wg_${fragen.length}',
        frage: t('Welches Land passt nicht zu den anderen?'),
        // ISO-Codes statt Namen: die Kacheln zeigen Flagge UND Namen, beides
        // wird aus dem Code aufgelöst.
        richtigeAntwort: aussen,
        antwortOptionen: [...vier]..shuffle(_rng),
        modus: LernModus.wasGehoertNichtDazu,
        // Kein Landkopf: eine Vorschau würde hier nichts zeigen, was nicht
        // ohnehin auf den vier Kacheln steht.
        laenderCode: '',
        meta: {'aufloesung': moegliche[aussen]!},
      ));
    }
    letzteQuartettVersuche = versuche;
    return fragen;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Länder-Ranking — Rangplatz per Zahlenschloss
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Noch nicht im Lernpfad: erreichbar nur über den Debug-Bereich.

  /// Kategorien, in denen ein RANGPLATZ eine Aussage hat.
  ///
  /// Ausgewählt nach zwei Kriterien, beide an den Daten gemessen:
  /// genug Länder mit Werten (sonst bezieht sich "Platz 40" auf ein
  /// Restfeld), und genug verschiedene Werte (sonst entstehen lange
  /// Gleichstands-Ketten, in denen die Reihenfolge willkürlich ist).
  ///
  /// Die Auswahl ist an den Daten gemessen, nicht geschätzt. Aufgenommen ist
  /// eine Kategorie nur, wenn der größte Gleichstands-Block höchstens sieben
  /// Länder umfasst und mindestens 150 Länder überhaupt Werte haben.
  ///
  /// Bewusst NICHT dabei, jeweils mit dem gemessenen Grund:
  /// - Geburtenrate (größter Block 15, 92 % aller Länder im Gleichstand),
  ///   Internetgeschwindigkeit (14 / 84 %), Pressefreiheit (12 / 87 %),
  ///   Tourismus (11 / 77 %), Militärausgaben (9 / 75 %), Korruptionsindex
  ///   (8 / 89 %), Alkoholkonsum (8 / 78 %): dort sind die Werte so grob
  ///   gerundet, dass der Rangplatz innerhalb langer Ketten willkürlich wird.
  /// - Mindestlohn (nur 148 Länder haben einen nationalen) und
  ///   Olympia-Medaillen (nur 113 mit Wert, die Mehrheit bei 0): ein
  ///   Rangplatz bezöge sich auf ein Restfeld.
  /// - Inflationsrate: gut verteilt, aber der Rang wechselt mit dem
  ///   Vorzeichen die Bedeutung.
  static const _kRankingKategorien = [
    'population', // Block 1, 0 % Gleichstand, 197 Länder
    'area', // Block 1, 0 %, 197
    'gdpTotal', // Block 1, 0 %, 192
    'highest_point', // Block 2, 5 %, 195
    'coastline', // Block 2, 11 %, 152 (Binnenstaaten haben keinen Wert)
    'debt', // Block 3, 13 %, 176
    'happiness', // Block 5, 48 %, 190
    'lifeExpectancy', // Block 5, 57 %, 196
    'forest', // Block 6, 78 %, 166
    'gdpPerCapita', // Block 7, 44 %, 192
  ];

  static Future<List<Frage>> _laenderRanking(
      LernStation station, List<String> pool) async {
    final erlaubt = rankingCategories
        .where((k) => _kRankingKategorien.contains(k.id))
        .toList();
    if (erlaubt.isEmpty) return _ausweichHauptstaedte(station, pool);

    // ── EINE KATEGORIE FÜR DIE GANZE STATION ────────────────────────────────
    //
    // Vorher wechselte sie von Frage zu Frage: erst Bevölkerung, dann
    // Waldanteil, dann BIP. Jede Frage begann damit von vorn — man musste
    // sich bei jeder neu überlegen, worum es überhaupt geht, und konnte kein
    // Gefühl für die Skala aufbauen.
    //
    // WELCHE es ist, bleibt Zufall, aber ein fester: Der Würfel hängt an der
    // Stations-ID, nicht an der Uhrzeit. Dieselbe Station zeigt damit immer
    // dieselbe Kategorie — auch nach einem Abbruch mitten drin, und für jeden
    // Spieler dieselbe.
    //
    // Genommen wird die erste Kategorie, die genug Länder aus dem Pool trägt.
    // Trägt keine die volle Fragenzahl, gewinnt die mit den meisten: lieber
    // eine Station mit vier Fragen zu EINER Kategorie als fünf zu dreien.
    final kandidaten = List.of(erlaubt)..shuffle(Random(station.id.hashCode));

    ({RankingCategory kat, List<CountryRanking> feld, List<String> waehlbar})?
        beste;
    for (final kat in kandidaten) {
      // Die Rangliste geht über ALLE Länder mit Daten, nicht über den
      // Stationspool: ein Rangplatz ist nur dann eine Aussage, wenn er sich
      // auf das ganze Feld bezieht.
      final feld = countryRankings.where((r) => kat.getValue(r) != null).toList()
        ..sort((a, b) => kat.getValue(b)!.compareTo(kat.getValue(a)!));
      if (feld.length < 20) continue;

      final imFeld = feld.map((r) => r.iso2).toSet();
      final waehlbar = pool.where(imFeld.contains).toList();
      if (waehlbar.isEmpty) continue;

      if (waehlbar.length >= station.fragenAnzahl) {
        beste = (kat: kat, feld: feld, waehlbar: waehlbar);
        break;
      }
      if (beste == null || waehlbar.length > beste.waehlbar.length) {
        beste = (kat: kat, feld: feld, waehlbar: waehlbar);
      }
    }
    if (beste == null) return _ausweichHauptstaedte(station, pool);

    final kat = beste.kat;
    final feld = beste.feld;
    // Kein Land zweimal in einer Station.
    final laender = (List.of(beste.waehlbar)..shuffle(_rng))
        .take(station.fragenAnzahl)
        .toList();

    final fragen = <Frage>[];
    for (final iso in laender) {
      final rang = feld.indexWhere((r) => r.iso2 == iso) + 1;
      final wert = kat.getValue(feld[rang - 1])!;
      final co = _country(iso);

      fragen.add(Frage(
          id: '${station.id}_lr_${fragen.length}',
          // "in der Kategorie X" statt "beim X": die Kategorienamen haben
          // unterschiedliche Genera (die Bevölkerung, der Waldanteil, das
          // BIP) — mit Artikel ergäbe eine feste Vorlage falsches Deutsch.
          frage: t('Welchen Platz belegt {land} in der Kategorie {kategorie}?',
              {'land': co?.name ?? iso, 'kategorie': kat.label}),
          richtigeAntwort: '$rang',
          antwortOptionen: const [],
          modus: LernModus.laenderRanking,
          laenderCode: iso,
          meta: {
            'kategorie': kat.id,
            'kategorieLabel': kat.label,
            'rang': rang,
            'gesamt': feld.length,
            'wert': wert,
            'einheit': kat.unit,
            'emoji': kat.emoji,
          },
      ));
    }
    return fragen;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Nachbarschafts-Kette — Weg von A nach B selbst bauen
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Noch nicht im Lernpfad: erreichbar nur über den Debug-Bereich.

  /// Zulässige Weglänge in Grenzübertritten.
  ///
  /// Unter 3 wäre die Aufgabe in einem Zug gelöst, über 5 wird die Kette
  /// unübersichtlich und die Zahl möglicher Irrwege zu groß.
  static const kKetteMinSchritte = 3;
  static const kKetteMaxSchritte = 5;

  /// Symmetrische Nachbarschaft, einmal aufgebaut und dann gecacht.
  ///
  /// laender_nachbarn.dart ist nicht garantiert symmetrisch — das
  /// Prüfskript zu den Grenzketten akzeptiert eine Kante ausdrücklich, wenn
  /// sie nur in EINER Richtung eingetragen ist (a in nachbarn[b] ODER b in
  /// nachbarn[a]). Für diesen Modus muss beides zusammenpassen: die Auswahl
  /// im Screen und die Wegsuche im Generator dürfen nicht von verschiedenen
  /// Kanten ausgehen, sonst bietet die Oberfläche einen Schritt an, den die
  /// Bestenlösung nicht kennt — oder umgekehrt.
  static Map<String, Set<String>>? _grenzGraphCache;

  static Map<String, Set<String>> grenzGraph() {
    if (_grenzGraphCache != null) return _grenzGraphCache!;
    final g = <String, Set<String>>{};
    void kante(String a, String b) {
      if (a == b) return;
      (g[a] ??= <String>{}).add(b);
      (g[b] ??= <String>{}).add(a);
    }

    for (final e in nachbarn.entries) {
      for (final n in e.value) {
        kante(e.key, n);
      }
    }
    // Nur Länder behalten, die auch in countries.dart stehen — der Screen
    // zeigt Flagge und Name, beides kommt von dort.
    final bekannt = countries.map((c) => c.iso2).toSet();
    final gefiltert = <String, Set<String>>{};
    for (final e in g.entries) {
      if (!bekannt.contains(e.key)) continue;
      final n = e.value.where(bekannt.contains).toSet();
      if (n.isNotEmpty) gefiltert[e.key] = n;
    }
    _grenzGraphCache = gefiltert;
    return gefiltert;
  }

  /// Kürzester Weg von [start] nach [ziel] als Länderfolge (inklusive
  /// beider Enden), oder null wenn keiner existiert.
  ///
  /// Breitensuche: findet garantiert einen Weg mit der kleinsten Zahl an
  /// Grenzübertritten. Inselstaaten ohne Landgrenze stehen gar nicht erst im
  /// Graphen und fallen dadurch von selbst heraus.
  static List<String>? kuerzesterWeg(String start, String ziel) {
    final g = grenzGraph();
    if (!g.containsKey(start) || !g.containsKey(ziel)) return null;
    if (start == ziel) return [start];

    final vorgaenger = <String, String>{start: start};
    final schlange = <String>[start];
    var kopf = 0;
    while (kopf < schlange.length) {
      final aktuell = schlange[kopf++];
      for (final n in g[aktuell]!) {
        if (vorgaenger.containsKey(n)) continue;
        vorgaenger[n] = aktuell;
        if (n == ziel) {
          final weg = <String>[ziel];
          var p = ziel;
          while (p != start) {
            p = vorgaenger[p]!;
            weg.add(p);
          }
          return weg.reversed.toList();
        }
        schlange.add(n);
      }
    }
    return null;
  }

  /// Alle vom Startland aus erreichbaren Länder mit ihrer Distanz.
  static Map<String, int> _distanzen(String start) {
    final g = grenzGraph();
    final d = <String, int>{start: 0};
    final schlange = <String>[start];
    var kopf = 0;
    while (kopf < schlange.length) {
      final aktuell = schlange[kopf++];
      for (final n in g[aktuell] ?? const <String>{}) {
        if (d.containsKey(n)) continue;
        d[n] = d[aktuell]! + 1;
        schlange.add(n);
      }
    }
    return d;
  }

  static Future<List<Frage>> _nachbarschaftsKette(
      LernStation station, List<String> pool) async {
    final g = grenzGraph();
    // Nur Länder mit Landgrenze kommen als Start in Frage.
    final kandidaten = pool.where(g.containsKey).toList()..shuffle(_rng);
    if (kandidaten.isEmpty) return _ausweichHauptstaedte(station, pool);

    // Kein Land zweimal in einer Station — weder als Start noch als Ziel.
    // Dieselbe Paarbildung wie beim Flächen-Vergleich, samt zweitem
    // Durchlauf; die Begründung steht bei [_paareZiehen].
    final fragen = _paareZiehen<Frage>(
      kandidaten: kandidaten,
      anzahl: station.fragenAnzahl,
      // Ziele sind alle Länder in passender Entfernung — nicht nur die aus
      // dem Pool: Der Weg darf über die ganze Karte führen, gefragt wird
      // nach der Verbindung, nicht nach dem Abschnitt.
      partnerFuer: (start, vergeben) => _distanzen(start)
          .entries
          .where((e) =>
              e.value >= kKetteMinSchritte &&
              e.value <= kKetteMaxSchritte &&
              !vergeben.contains(e.key) &&
              e.key != start)
          .map((e) => e.key)
          .toList(),
      baue: (start, ziel, index) {
        // Bei endlicher Entfernung gibt es immer einen Weg — die Prüfung ist
        // eine Absicherung, kein erwarteter Fall.
        final weg = kuerzesterWeg(start, ziel);
        if (weg == null) return null;

        final startCo = _country(start), zielCo = _country(ziel);
        return Frage(
          id: '${station.id}_nk_$index',
          frage: t(
              'Finde einen Weg von {start} nach {ziel} — nur über Nachbarländer.',
              {
                'start': startCo?.name ?? start,
                'ziel': zielCo?.name ?? ziel,
              }),
          // Der kürzeste Weg als Zeichenkette. Verglichen wird damit NICHT:
          // die Prüfung ist strukturell (siehe _ketteFertig im Quiz-Screen).
          // Das Feld trägt hier den Referenzwert, so wie es beim Preis-Schätzen
          // den Zielwert und beim Länder-Ranking den Rangplatz trägt.
          richtigeAntwort: weg.join('>'),
          antwortOptionen: const [],
          modus: LernModus.nachbarschaftsKette,
          laenderCode: start,
          meta: {
            'startIso': start,
            'zielIso': ziel,
            'optimum': weg.length - 1,
            'optimalerWeg': weg,
          },
        );
      },
    );
    // Kein einziges brauchbares Paar: In Ozeanien hat genau ein Land eine
    // Landgrenze, in Südamerika liegen zwischen zwei beliebigen Ländern
    // höchstens 3 Grenzübertritte. Statt einer leeren Fragenliste — die eine
    // Station unspielbar machen würde — auf einen anderen Modus ausweichen,
    // wie es auch das Grenzketten-Rätsel für Kontinente ohne Einträge tut.
    if (fragen.isEmpty) return _ausweichHauptstaedte(station, pool);
    return fragen;
  }
}

/// Ein prüfbares Merkmal eines Landes für "Was gehört nicht dazu?".
///
/// [wert] liefert null, wenn für das Land keine Daten vorliegen — solche
/// Merkmale werden für das betroffene Quartett übersprungen statt geraten.
/// [aufloesung] formuliert aus dem geteilten Wert die Gemeinsamkeit der DREI;
/// sie ist der eigentliche Lerneffekt des Modus.
class _Merkmal {
  final String id;

  /// Deutsche Bezeichnung für den Hilfe-Dialog im Quiz. Steht hier und nicht
  /// im Screen, damit die angezeigte Liste nicht von den tatsächlich
  /// geprüften Merkmalen abweichen kann.
  final String label;
  final String? Function(String iso2) wert;
  final String Function(String gemeinsamerWert) aufloesung;
  const _Merkmal(this.id, this.label, this.wert, this.aufloesung);
}
