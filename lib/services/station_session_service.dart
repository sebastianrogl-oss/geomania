import 'dart:convert';
import 'dart:math';
import '../data/alle_laender.dart';
import '../data/countries.dart';
import '../data/country_rankings.dart';
import '../data/currencies.dart';
import '../data/laender_fakten.dart';
import '../data/laender_gebaeude.dart';
import '../data/laender_nachbarn.dart';
import '../data/lernpfad_data.dart';
import '../data/wirtschaftssektoren.dart';
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
  final String label;
  final String einheit;
  final double? Function(String iso2) wert;
  const _SpielKategorie(this.id, this.label, this.einheit, this.wert);
}

// ── Flaggenfarben (nur die wichtigsten Länder — Rest: Modus wird sauber
// übersprungen, siehe _flaggenFarbeQuiz) ──────────────────────────────────────

const Map<String, String> _flaggenFarben = {
  // Europa
  'DE': 'Schwarz-Rot-Gold', 'AT': 'Rot-Weiß-Rot', 'FR': 'Blau-Weiß-Rot',
  'IT': 'Grün-Weiß-Rot', 'ES': 'Rot-Gelb-Rot', 'NL': 'Rot-Weiß-Blau',
  'BE': 'Schwarz-Gelb-Rot', 'CH': 'Rot-Weiß', 'SE': 'Blau-Gelb',
  'NO': 'Rot-Weiß-Blau', 'DK': 'Rot-Weiß', 'FI': 'Weiß-Blau',
  'PL': 'Weiß-Rot', 'HU': 'Rot-Weiß-Grün', 'GR': 'Blau-Weiß',
  'RO': 'Blau-Gelb-Rot', 'IE': 'Grün-Weiß-Orange', 'UA': 'Blau-Gelb',
  'RU': 'Weiß-Blau-Rot', 'LU': 'Rot-Weiß-Hellblau', 'BG': 'Weiß-Grün-Rot',
  'LT': 'Gelb-Grün-Rot', 'EE': 'Blau-Schwarz-Weiß', 'IS': 'Blau-Weiß-Rot',
  'CZ': 'Weiß-Rot-Blau', 'SK': 'Weiß-Blau-Rot', 'SI': 'Weiß-Blau-Rot',
  'HR': 'Rot-Weiß-Blau', 'RS': 'Rot-Blau-Weiß', 'AL': 'Rot-Schwarz',
  'MT': 'Weiß-Rot',
  // Amerika
  'US': 'Rot-Weiß-Blau', 'CA': 'Rot-Weiß-Rot', 'MX': 'Grün-Weiß-Rot',
  'BR': 'Grün-Gelb-Blau', 'AR': 'Hellblau-Weiß-Hellblau', 'CO': 'Gelb-Blau-Rot',
  'CL': 'Weiß-Rot-Blau', 'PE': 'Rot-Weiß-Rot', 'VE': 'Gelb-Blau-Rot',
  'EC': 'Gelb-Blau-Rot', 'BO': 'Rot-Gelb-Grün', 'UY': 'Weiß-Blau',
  'PY': 'Rot-Weiß-Blau',
  // Afrika
  'NG': 'Grün-Weiß-Grün', 'EG': 'Rot-Weiß-Schwarz', 'ZA': 'Bunt',
  'KE': 'Schwarz-Rot-Grün', 'ET': 'Grün-Gelb-Rot', 'GH': 'Rot-Gelb-Grün',
  'MA': 'Rot-Grün', 'DZ': 'Grün-Weiß', 'TN': 'Rot', 'CI': 'Orange-Weiß-Grün',
  'SN': 'Grün-Gelb-Rot', 'CM': 'Grün-Rot-Gelb', 'ML': 'Grün-Gelb-Rot',
  // Asien
  'CN': 'Rot-Gelb', 'JP': 'Weiß-Rot', 'IN': 'Orange-Weiß-Grün',
  'TH': 'Rot-Weiß-Blau', 'VN': 'Rot-Gelb', 'ID': 'Rot-Weiß',
  'IR': 'Grün-Weiß-Rot', 'PK': 'Weiß-Grün', 'BD': 'Grün-Rot',
  'SG': 'Rot-Weiß', 'KR': 'Weiß', 'PH': 'Blau-Rot-Weiß',
  'MY': 'Rot-Weiß-Blau', 'SA': 'Grün', 'AE': 'Rot-Grün-Weiß-Schwarz',
  // Ozeanien
  'AU': 'Blau-Rot-Weiß', 'NZ': 'Blau-Rot-Weiß',
};

// ── Größte Stadt (nur wo abweichend von der Hauptstadt) ───────────────────────

const Map<String, String> _groessteStaedte = {
  'TR': 'Istanbul', 'AU': 'Sydney', 'US': 'New York City', 'BR': 'São Paulo',
  'CA': 'Toronto', 'IN': 'Mumbai', 'CH': 'Zürich', 'NG': 'Lagos',
  'ZA': 'Johannesburg', 'MM': 'Yangon', 'PK': 'Karachi', 'KZ': 'Almaty',
  'CI': 'Abidjan', 'BJ': 'Cotonou', 'TZ': 'Dar es Salaam', 'NZ': 'Auckland',
  'VN': 'Ho-Chi-Minh-Stadt', 'EC': 'Guayaquil', 'BO': 'Santa Cruz de la Sierra',
  'MA': 'Casablanca', 'CM': 'Douala', 'LK': 'Colombo',
};

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

    for (final c in currencies) {
      for (final co in countries) {
        if (co.name == c.countryName) {
          _waehrungByIso2![co.iso2] = c;
          break;
        }
      }
    }
    for (final s in wirtschaftssektoren) {
      for (final co in countries) {
        if (co.name == s.countryName) {
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

  // ── Länder-Round-Robin für Kern-Modi (Flaggen/Hauptstädte/Umriss) ─────────
  //
  // Anders als _pick() zieht diese Variante bevorzugt Länder, die im
  // jeweiligen Thema dieses Abschnitts noch nicht dran waren — erst wenn
  // der ganze Länderpool durch ist, darf sich eins wiederholen (und dann
  // beginnt automatisch eine neue Runde).

  static Future<List<String>> _pickRoundRobin(List<String> pool, int n,
      String weltId, String abschnittId, String thema) async {
    final eindeutigerPool = pool.toSet().toList();
    final bereits =
        await FortschrittService.rrBereitsAbgefragt(weltId, abschnittId, thema);

    final neu = eindeutigerPool.where((c) => !bereits.contains(c)).toList()
      ..shuffle(_rng);
    final gezogen = <String>[...neu.take(n)];

    if (gezogen.length < n) {
      // Zu wenig unverbrauchte Länder übrig -> mit bereits abgefragten
      // auffüllen (gemischt).
      final schonDa = eindeutigerPool.where((c) => bereits.contains(c)).toList();
      gezogen.addAll(
          _pick(schonDa.isEmpty ? eindeutigerPool : schonDa, n - gezogen.length));
    }

    final aktualisiert = {...bereits, ...gezogen};
    // Ganzer Pool durch -> zurücksetzen, damit die nächste Ziehung eine
    // frische Runde durch den Kontinent beginnt.
    final naechsterStand = aktualisiert.length >= eindeutigerPool.length
        ? <String>{}
        : aktualisiert;
    await FortschrittService.rrSpeichern(
        weltId, abschnittId, thema, naechsterStand);

    return gezogen;
  }

  /// Ermittelt Welt/Abschnitt/Thema der Station und delegiert an
  /// _pickRoundRobin(). Fällt auf reines _pick() zurück, falls die Station
  /// keinem festen Platz im Lernpfad zugeordnet ist (z.B. in Tests).
  static Future<List<String>> _pickKern(
      List<String> pool, int n, LernStation station) async {
    final kontext = stationKontext(station.id);
    if (kontext == null) return _pick(pool, n);
    final (welt, abschnitt, _) = kontext;
    final thema = lernModusThema(station.modus);
    return _pickRoundRobin(pool, n, welt.id, abschnitt.id, thema);
  }

  /// Haupteinstieg: generiert alle Fragen für eine Station.
  static Future<List<Frage>> generiereFragenFuerStation(
      LernStation station) async {
    _initCaches();
    final pool = station.laenderCodes.where((c) => c != '*').toList();
    if (pool.isEmpty) return [];
    final kontinent = _kontinent(station);
    final schwierigkeit = station.schwierigkeitsgrad;

    switch (station.modus) {
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
      case LernModus.hauptstadtZuLand:
        return await _hauptstadtZuLand(station, pool);
      case LernModus.groessteStadt:
        return _groessteStadtQuiz(station, pool);
      case LernModus.flaggenFarbe:
        return await _flaggenFarbeQuiz(station, pool, kontinent, schwierigkeit);
      case LernModus.extremFrageLeicht:
        return _extremFrageLeicht(station, pool);
      case LernModus.zufallsFakt:
        return _zufallsFakt(station, kontinent);
      case LernModus.bekanntesGebaeude:
        return _bekanntesGebaeude(station, kontinent);
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
        frage: 'Welche Flagge gehört zu ${co?.name ?? iso2}?',
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

  static Future<List<Frage>> _umrissBild(LernStation station, List<String> pool) async {
    final kontId = _normalisiereKontinent(_kontinent(station));
    final ausgewaehlt = await _pickKern(pool, station.fragenAnzahl, station);
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
    final ausgewaehlt = await _pickKern(pool, station.fragenAnzahl, station);
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
        frage: 'Was ist die Hauptstadt von ${co.name}?',
        richtigeAntwort: co.capital,
        antwortOptionen: optionen,
        modus: LernModus.hauptstaedteMultiple,
        laenderCode: iso2,
      );
    }).toList();
  }

  // ── Hauptstädte: Texteingabe ────────────────────────────────────────────────

  static Future<List<Frage>> _hauptstaedteEingabe(
      LernStation station, List<String> pool) async {
    final ausgewaehlt = await _pickKern(pool, station.fragenAnzahl, station);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      return Frage(
        id: '${station.id}_he_${e.key}',
        frage: 'Was ist die Hauptstadt von ${co.name}?',
        richtigeAntwort: co.capital,
        antwortOptionen: const [],
        modus: LernModus.hauptstaedteEingabe,
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
      _waehrungsKuerzel[curr.currencyCode] ?? curr.currencyName;

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
      final richtig = '${_kuerzeWaehrungsname(curr)} (${curr.currencyCode})';

      // Distraktoren: erst gleiche Region, dann global — dedupliziert nach Code
      final kandidaten = [
        ..._waehrungByIso2!.entries
            .where((d) => d.key != iso2 && _country(d.key)?.region == co.region),
        ..._waehrungByIso2!.entries
            .where((d) => d.key != iso2 && _country(d.key)?.region != co.region),
      ]..shuffle(_rng);

      final geseheneCodes = <String>{curr.currencyCode};
      final distrOpts = <String>[];
      for (final d in kandidaten) {
        if (geseheneCodes.contains(d.value.currencyCode)) continue;
        geseheneCodes.add(d.value.currencyCode);
        distrOpts.add('${_kuerzeWaehrungsname(d.value)} (${d.value.currencyCode})');
        if (distrOpts.length >= 3) break;
      }

      final optionen = [richtig, ...distrOpts]..shuffle(_rng);

      return Frage(
        id: '${station.id}_w_${e.key}',
        frage: 'Welche Währung hat dieses Land?',
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
        frage: 'Sortiere nach: ${kategorie.label} (größte zuerst)',
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
        frage: 'Schätze: ${kategorie.label} von ${co.name}',
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

  static Future<List<Frage>> _wirtschaftssektoren(
      LernStation station, List<String> pool, int schw) async {
    final mitSektor =
        pool.where((c) => _sektorByIso2!.containsKey(c)).toList();
    if (mitSektor.isEmpty) return await _flaggenBild(station, pool, 'Welt', schw);

    final ausgewaehlt = _pick(mitSektor, station.fragenAnzahl);
    final alleSektoren = sektorEmojis.keys.toList();

    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      final sektor = _sektorByIso2![iso2]!;
      final richtig = sektor.mainSector;
      final distr = alleSektoren.where((s) => s != richtig).toList()
        ..shuffle(_rng);
      final optionen = [richtig, ...distr.take(3)]..shuffle(_rng);

      return Frage(
        id: '${station.id}_wi_${e.key}',
        frage: 'Welcher Wirtschaftssektor dominiert in ${co.name}?',
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

      final distraktorKandidaten = countries
          .where((c) =>
              c.iso2 != iso2 &&
              c.iso2 != richtig &&
              !echteNachbarn.contains(c.iso2))
          .toList()
        ..shuffle(_rng);
      final optionen = [
        richtigName,
        ...distraktorKandidaten.take(3).map((c) => c.name),
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
        frage: 'Wie hoch ist das BIP (Bruttoinlandsprodukt) von ${co.name}?',
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
        frage: 'Wie groß ist die Fläche von ${co.name}?',
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
        frage: 'Welches Land nutzt $waehrungsName?',
        richtigeAntwort: co.name,
        antwortOptionen: optionen,
        modus: LernModus.waehrungZuLand,
        // Absichtlich leer: würde sonst per Landkopf die Antwort verraten.
        laenderCode: '',
      );
    }).toList();
  }

  // ── Extremfrage (Superlativ) ─────────────────────────────────────────────

  static List<Frage> _extremFrage(LernStation station, List<String> pool) {
    const typen = ['meiste', 'wenigste', 'bip'];
    final fragen = <Frage>[];
    for (int i = 0; i < station.fragenAnzahl; i++) {
      final vier = _pick(pool, 4).map((iso2) => _country(iso2)!).toList();
      final typ = typen[i % typen.length];
      late Country extrem;
      late String frageText;
      switch (typ) {
        case 'meiste':
          extrem = vier.reduce((a, b) => a.population > b.population ? a : b);
          frageText = 'Welches dieser Länder hat die meisten Einwohner?';
        case 'wenigste':
          extrem = vier.reduce((a, b) => a.population < b.population ? a : b);
          frageText = 'Welches dieser Länder hat die wenigsten Einwohner?';
        default:
          extrem = vier.reduce((a, b) => a.gdp > b.gdp ? a : b);
          frageText = 'Welches dieser Länder hat die größte Wirtschaft (BIP)?';
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

  // ── Hauptstadt → Land (umgekehrtes Hauptstädte-Quiz) ─────────────────────

  static Future<List<Frage>> _hauptstadtZuLand(LernStation station, List<String> pool) async {
    // Nur Länder deren Hauptstadt innerhalb des Pools eindeutig ist.
    final eindeutig = pool.where((iso2) {
      final cap = _country(iso2)?.capital;
      if (cap == null) return false;
      return pool.where((c) => _country(c)?.capital == cap).length == 1;
    }).toList();
    if (eindeutig.isEmpty) {
      return await _hauptstaedteMultiple(
          station, pool, 'Welt', station.schwierigkeitsgrad);
    }

    final ausgewaehlt = await _pickKern(eindeutig, station.fragenAnzahl, station);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
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
        id: '${station.id}_hzl_${e.key}',
        frage: 'Welches Land hat die Hauptstadt ${co.capital}?',
        richtigeAntwort: co.name,
        antwortOptionen: optionen,
        modus: LernModus.hauptstadtZuLand,
        // Absichtlich leer: würde sonst per Landkopf die Antwort verraten.
        laenderCode: '',
      );
    }).toList();
  }

  // ── Größte Stadt ───────────────────────────────────────────────────────

  static String _stadtFuer(Country co) => _groessteStaedte[co.iso2] ?? co.capital;

  static List<Frage> _groessteStadtQuiz(LernStation station, List<String> pool) {
    final ausgewaehlt = _pick(pool, station.fragenAnzahl);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      final richtig = _stadtFuer(co);
      final distrIso2 = AntwortGenerator.generiereOptionenAusListe(
              iso2, pool, anzahlOptionen: 4)
          .where((c) => c != iso2)
          .take(3)
          .toList();
      final optionen = [
        richtig,
        ...distrIso2.map((c) {
          final dc = _country(c);
          return dc == null ? c : _stadtFuer(dc);
        }),
      ]..shuffle(_rng);

      return Frage(
        id: '${station.id}_gs_${e.key}',
        frage: 'Was ist die größte Stadt von ${co.name}?',
        richtigeAntwort: richtig,
        antwortOptionen: optionen,
        modus: LernModus.groessteStadt,
        laenderCode: iso2,
      );
    }).toList();
  }

  // ── Flaggenfarben ──────────────────────────────────────────────────────

  static Future<List<Frage>> _flaggenFarbeQuiz(
      LernStation station, List<String> pool, String kontinent, int schw) async {
    final mitFarben = pool.where((c) => _flaggenFarben.containsKey(c)).toList();
    // Nur Länder deren Farbkombination innerhalb des Pools eindeutig ist
    // (manche Flaggen sind sich sehr ähnlich, z.B. Slowenien/Slowakei).
    final eindeutig = mitFarben.where((iso2) {
      final farbe = _flaggenFarben[iso2]!;
      return mitFarben.where((c) => _flaggenFarben[c] == farbe).length == 1;
    }).toList();
    if (eindeutig.isEmpty) return await _flaggenBild(station, pool, kontinent, schw);

    final ausgewaehlt = _pick(eindeutig, station.fragenAnzahl);
    return ausgewaehlt.asMap().entries.map((e) {
      final iso2 = e.value;
      final co = _country(iso2)!;
      final richtig = _flaggenFarben[iso2]!;
      final distrKandidaten = eindeutig.where((c) => c != iso2).toList()
        ..shuffle(_rng);
      final optionen = [
        richtig,
        ...distrKandidaten.take(3).map((c) => _flaggenFarben[c]!),
      ]..shuffle(_rng);

      return Frage(
        id: '${station.id}_ff_${e.key}',
        frage: 'Welche Farben hat die Flagge von ${co.name}?',
        richtigeAntwort: richtig,
        antwortOptionen: optionen,
        modus: LernModus.flaggenFarbe,
        laenderCode: iso2,
      );
    }).toList();
  }

  // ── Extremfrage leicht (nur sehr bekannte Länder) ─────────────────────────

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
      final nachFlaeche = i.isEven;
      final mitFlaeche =
          kandidatenPool.where((c) => _ranking(c)?.area != null).toList();
      final vierIso2 = (nachFlaeche && mitFlaeche.length >= 4)
          ? _pick(mitFlaeche, 4)
          : _pick(kandidatenPool, 4);
      final benutzeFlaeche =
          nachFlaeche && vierIso2.every((c) => _ranking(c)?.area != null);
      final vier = vierIso2.map((iso2) => _country(iso2)!).toList();

      late Country extrem;
      late String frageText;
      if (benutzeFlaeche) {
        extrem = vier.reduce((a, b) =>
            _ranking(a.iso2)!.area! > _ranking(b.iso2)!.area! ? a : b);
        frageText = 'Welches dieser Länder ist am größten (Fläche)?';
      } else {
        extrem = vier.reduce((a, b) => a.population > b.population ? a : b);
        frageText = 'Welches dieser Länder hat die meisten Einwohner?';
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
        frage: fakt.frage,
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
        frage: 'In welchem Land steht ${geb.bauwerk}?',
        richtigeAntwort: richtig,
        antwortOptionen: optionen,
        modus: LernModus.bekanntesGebaeude,
        // Absichtlich leer: das gesuchte Land ist die Antwort selbst.
        laenderCode: '',
      );
    }).toList();
  }
}
