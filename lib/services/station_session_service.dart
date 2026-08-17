import 'dart:convert';
import 'dart:math';
import '../data/alle_laender.dart';
import '../data/countries.dart';
import '../data/country_rankings.dart';
import '../data/currencies.dart';
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

  StationSession({
    required this.stationId,
    required this.aktiveFragen,
    this.istWiederholungsRunde = false,
    this.hatTimer = false,
    List<Frage>? falscheFragen,
    this.aktuellerIndex = 0,
    this.richtigeAntworten = 0,
    this.falscheAntworten = 0,
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
    aktuellerIndex++;
  }

  /// FALSCHE ANTWORT: Frage genau einmal ans Ende hängen (kein Duplikat).
  void falscheAntwortVerarbeiten() {
    final frage = aktuelleFrage;
    if (frage == null) return;
    falscheAntworten++;
    frage.falschBeantwortet++;
    frage.antwortOptionen = List.from(frage.antwortOptionen)..shuffle(_rng);
    // Nur anhängen wenn noch kein Duplikat dieser Frage in der Queue wartet
    final nochNichtDrin = !aktiveFragen
        .skip(aktuellerIndex + 1)
        .any((f) => f.id == frage.id);
    if (nochNichtDrin) aktiveFragen.add(frage);
    if (!falscheFragen.any((f) => f.id == frage.id)) {
      falscheFragen.add(frage);
    }
    aktuellerIndex++;
  }

  /// TIMER abgelaufen → wie falsche Antwort.
  void timerAbgelaufen() => falscheAntwortVerarbeiten();

  /// SKIP (nach Rewarded Ad): Frage einfach überspringen — zählt WEDER als
  /// richtig NOCH als falsch (keine Punktzahl-/Wiederholungsrunden-
  /// Auswirkung), im Gegensatz zu falscheAntwortVerarbeiten() oben.
  void frageUeberspringen() {
    aktuellerIndex++;
  }

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

  // Wählt [n] Länder aus [pool], wiederholt wenn nötig (für kleine Listen).
  static List<String> _pick(List<String> pool, int n) {
    final shuffled = List.of(pool)..shuffle(_rng);
    if (shuffled.length >= n) return shuffled.take(n).toList();
    final result = <String>[];
    while (result.length < n) {
      result.addAll(shuffled.take(n - result.length));
    }
    return result;
  }

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
      final schonDa = eindeutigerPool.where((c) => bereits.contains(c)).toList();
      gezogen.addAll(
          _pick(schonDa.isEmpty ? eindeutigerPool : schonDa, n - gezogen.length));
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
  static Future<List<String>> _pickKern(
      List<String> pool, int n, LernStation station) async {
    final kontext = stationKontext(station.id);
    if (kontext == null) return _pick(pool, n);
    final (welt, abschnitt, _) = kontext;
    return _pickRoundRobin(pool, n, welt.id, _rrModusKey(welt, abschnitt, station.modus));
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
  static Future<List<Frage>> generiereFragenFuerStation(
      LernStation station) async {
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
  static List<String> _umrissPool(List<String> pool) {
    final gefiltert = pool.where(kannAlsUmrissErscheinen).toList();
    return gefiltert.isEmpty ? pool : gefiltert;
  }

  static Future<List<Frage>> _umrissBild(LernStation station, List<String> pool) async {
    final kontId = _normalisiereKontinent(_kontinent(station));
    final ausgewaehlt =
        await _pickKern(_umrissPool(pool), station.fragenAnzahl, station);
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
    final ausgewaehlt =
        await _pickKern(_umrissPool(pool), station.fragenAnzahl, station);
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
    final ausgewaehlt = await _pickKern(pool, station.fragenAnzahl, station);
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
    final ausgewaehlt = await _pickKern(pool, station.fragenAnzahl, station);
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
    final ausgewaehlt =
        await _pickKern(_umrissPool(pool), station.fragenAnzahl, station);
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

  static String _kuerzeWaehrungsname(CurrencyData curr) =>
      LocaleService.istEnglisch
          ? (waehrungsKuerzelEn[curr.currencyCode] ?? curr.currencyName)
          : (_waehrungsKuerzel[curr.currencyCode] ?? curr.currencyName);

  // ── Währungs-Quiz ───────────────────────────────────────────────────────────

  static Future<List<Frage>> _waehrung(
    LernStation station, List<String> pool, String kontinent, int schw) async {
    final mitWaehrung = pool.where((c) => _waehrungByIso2!.containsKey(c)).toList();
    if (mitWaehrung.isEmpty) return await _hauptstaedteMultiple(station, pool, kontinent, schw);

    final ausgewaehlt = _pick(mitWaehrung, station.fragenAnzahl);
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
    final kategoriePool =
        kontinentPool.where((iso2) => kategorie.wert(iso2) != null).toList();

    final fragen = <Frage>[];
    for (int runde = 0; runde < station.fragenAnzahl; runde++) {
      final fuenf = _pick(kategoriePool, 5);

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
    final ausgewaehlt = _pick(kontinentPool, station.fragenAnzahl);

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
    final mitSektor =
        pool.where((c) => _sektorByIso2!.containsKey(c)).toList();
    if (mitSektor.isEmpty) return await _flaggenBild(station, pool, 'Welt', schw);

    final ausgewaehlt = _pick(mitSektor, station.fragenAnzahl);
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
    final mitNachbarn =
        pool.where((c) => (nachbarn[c] ?? const []).isNotEmpty).toList();
    // Inselstaaten ohne Landgrenze: Modus überspringen, Flaggen-Quiz statt.
    if (mitNachbarn.isEmpty) return await _flaggenBild(station, pool, kontinent, schw);

    final ausgewaehlt = _pick(mitNachbarn, station.fragenAnzahl);
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
        frage: 'Welches Land grenzt an ${co.name}?',
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
    final mitBip = pool.where((c) => (_country(c)?.gdp ?? 0) > 0).toList();
    if (mitBip.isEmpty) {
      return await _hauptstaedteMultiple(
          station, pool, 'Welt', station.schwierigkeitsgrad);
    }

    final ausgewaehlt = _pick(mitBip, station.fragenAnzahl);
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
    final mitFlaeche = pool.where((c) => _ranking(c)?.area != null).toList();
    if (mitFlaeche.isEmpty) {
      return await _hauptstaedteMultiple(
          station, pool, 'Welt', station.schwierigkeitsgrad);
    }

    final ausgewaehlt = _pick(mitFlaeche, station.fragenAnzahl);
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
    final mitWaehrung = pool.where((c) => _waehrungByIso2!.containsKey(c)).toList();
    // Nur Länder deren Währung innerhalb des Pools eindeutig ist — sonst
    // gäbe es mehrere "richtige" Länder für dieselbe Währung (z.B. Euro).
    final eindeutig = mitWaehrung.where((iso2) {
      final code = _waehrungByIso2![iso2]!.currencyCode;
      return mitWaehrung.where((c) => _waehrungByIso2![c]!.currencyCode == code).length == 1;
    }).toList();
    if (eindeutig.isEmpty) return await _hauptstaedteMultiple(station, pool, 'Welt', station.schwierigkeitsgrad);

    final ausgewaehlt = _pick(eindeutig, station.fragenAnzahl);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      final curr = _waehrungByIso2![iso2]!;
      final waehrungsName = '${_kuerzeWaehrungsname(curr)} (${curr.currencyCode})';
      final distrIso2 = AntwortGenerator.generiereOptionenAusListe(
              iso2, eindeutig, anzahlOptionen: 4)
          .where((c) => c != iso2)
          .take(3)
          .toList();
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
      );
    }).toList();
  }

  // ── Extremfrage (Superlativ) ─────────────────────────────────────────────
  //
  // Frage-Text passend zur Kategorie UND Richtung (größte/meiste vs.
  // kleinste/wenigste) — dieselbe Zuordnung wird von _extremFrage() und
  // _extremFrageLeicht() genutzt, damit beide Varianten konsistent klingen.
  static String _extremFrageText(String katId, bool kleinstes) => switch (katId) {
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
      };

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
    final ausgewaehlt = <LandFakt>[];
    while (ausgewaehlt.length < station.fragenAnzahl) {
      ausgewaehlt.addAll(shuffled.take(station.fragenAnzahl - ausgewaehlt.length));
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
    if (gefiltert.isEmpty) {
      // Kein kuratierter Eintrag für diesen Kontinent (z.B. Südamerika,
      // strukturell keine eindeutige Kette möglich) -> Modus für diese
      // Station überspringen, kein Crash, keine leere Frage.
      return await _flaggenBild(station, pool, kontinent, schw);
    }

    final ausgewaehlt =
        await _pickGrenzketten(gefiltert, station.fragenAnzahl, station);
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
}
