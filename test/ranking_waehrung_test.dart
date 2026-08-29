import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geomania/data/currencies.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/services/station_session_service.dart';

// ── Zwei Zusicherungen an den Fragen-Generator ───────────────────────────────
//
// 1. LÄNDER-RANKING: eine Kategorie für die ganze Station. Welche es ist,
//    bleibt Zufall — aber ein fester, an der Stations-ID hängender.
//
// 2. WÄHRUNG → LAND: Die Frage nennt nur noch den Währungsnamen, ohne den
//    Code in Klammern. Damit sie eindeutig bleibt, darf innerhalb einer
//    Station kein zweites Land denselben ANGEZEIGTEN Namen tragen — die
//    Kurznamen werfen zusammen, was der Code trennte („Dollar" steht für
//    sechs Währungen).

LernStation _station(LernModus modus, List<String> laender,
        {String id = 'test', int fragen = 5}) =>
    LernStation(
      id: id,
      modus: modus,
      fragenAnzahl: fragen,
      laenderCodes: laender,
      kategorien: const [],
      schwierigkeitsgrad: 2,
    );

const _europa = [
  'DE', 'FR', 'IT', 'ES', 'PL', 'SE', 'NO', 'GR', 'RO', 'HU',
  'CH', 'AT', 'PT', 'NL', 'BE', 'DK', 'FI', 'CZ', 'BG', 'HR',
];
const _welt = [
  'US', 'CA', 'AU', 'NZ', 'SG', 'JP', 'CN', 'IN', 'BR', 'AR',
  'ZA', 'NG', 'EG', 'KE', 'MA', 'TR', 'RU', 'MX', 'TH', 'ID',
];

/// Nutzen die beiden Länder (nach Namen) dieselbe Währung?
///
/// Gegen die Rohdaten geprüft, nicht gegen die Anzeige: Der Test soll auch
/// dann anschlagen, wenn jemand die Kurznamen umbaut.
bool _nutztWaehrungVon(String landName, String anderesLand) {
  final a = currencies.where((c) => c.countryName == landName).firstOrNull;
  final b = currencies.where((c) => c.countryName == anderesLand).firstOrNull;
  if (a == null || b == null) return landName == anderesLand;
  return a.currencyCode == b.currencyCode;
}

/// Steht das Land (nach Namen) überhaupt im Währungsdatensatz?
bool _waehrungBekannt(String landName) =>
    currencies.any((c) => c.countryName == landName);

/// Ist jedes Zeichen ein Währungssymbol nach Unicode?
///
/// Bewusst NEU geschrieben und nicht aus dem Dienst geholt: Der Test soll die
/// Zusicherung prüfen, nicht die Implementierung gegen sich selbst. Wer die
/// Blöcke dort versehentlich aufweicht, fällt hier auf.
bool _istWaehrungsZeichen(String s) {
  const bloecke = [
    [0x24, 0x24],
    [0xA2, 0xA5],
    [0x58F, 0x58F],
    [0x60B, 0x60B],
    [0x9F2, 0x9F3],
    [0xE3F, 0xE3F],
    [0x17DB, 0x17DB],
    [0x20A0, 0x20C0],
    [0xFDFC, 0xFDFC],
    [0xFF04, 0xFF04],
  ];
  if (s.isEmpty) return false;
  return s.runes
      .every((r) => bloecke.any((b) => r >= b[0] && r <= b[1]));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Länder-Ranking: eine Kategorie je Station', () {
    for (final fall in {'europa': _europa, 'welt': _welt}.entries) {
      test('${fall.key} — alle Fragen tragen dieselbe Kategorie', () async {
        final fragen = await FragenGenerator.generiereFragenFuerStation(
            _station(LernModus.laenderRanking, fall.value, id: 'lr_${fall.key}'));
        expect(fragen, isNotEmpty);
        final kategorien =
            fragen.map((f) => f.meta['kategorie'] as String?).toSet();
        expect(kategorien.length, 1,
            reason: 'gemischte Kategorien in einer Station: $kategorien');
      });
    }

    test('Dieselbe Station bekommt immer dieselbe Kategorie', () async {
      // Der Würfel hängt an der Stations-ID, nicht an der Uhrzeit: Wer eine
      // Station abbricht und neu beginnt, findet dieselbe Kategorie vor.
      final a = await FragenGenerator.generiereFragenFuerStation(
          _station(LernModus.laenderRanking, _europa, id: 'lr_fest'));
      final b = await FragenGenerator.generiereFragenFuerStation(
          _station(LernModus.laenderRanking, _europa, id: 'lr_fest'));
      expect(a.first.meta['kategorie'], b.first.meta['kategorie']);
    });

    test('Verschiedene Stationen bekommen nicht alle dieselbe', () async {
      // Sonst wäre es keine zufällige Wahl, sondern eine feste.
      final gesehen = <String>{};
      for (var i = 0; i < 12; i++) {
        final fragen = await FragenGenerator.generiereFragenFuerStation(
            _station(LernModus.laenderRanking, _europa, id: 'lr_streu_$i'));
        final kat = fragen.first.meta['kategorie'] as String?;
        if (kat != null) gesehen.add(kat);
      }
      expect(gesehen.length, greaterThan(1),
          reason: 'zwölf Stationen, und immer dieselbe Kategorie: $gesehen');
    });

    test('Kein Land kommt zweimal vor', () async {
      final fragen = await FragenGenerator.generiereFragenFuerStation(
          _station(LernModus.laenderRanking, _europa, id: 'lr_doppelt'));
      final laender = fragen.map((f) => f.laenderCode).toList();
      expect(laender.toSet().length, laender.length);
    });
  });

  group('Währung → Land: kein Code in Klammern', () {
    for (final fall in {'europa': _europa, 'welt': _welt}.entries) {
      test('${fall.key} — keine Klammer im Fragetext', () async {
        final fragen = await FragenGenerator.generiereFragenFuerStation(
            _station(LernModus.waehrungZuLand, fall.value, id: 'wl_${fall.key}'));
        expect(fragen, isNotEmpty);
        for (final f in fragen) {
          // Nur Fragen dieses Modus prüfen: Bei zu dünnem Länderpool weicht
          // der Generator auf Hauptstädte aus, und deren Text darf Klammern
          // enthalten.
          if (f.modus != LernModus.waehrungZuLand) continue;
          expect(f.frage, isNot(contains('(')),
              reason: 'Klammer im Fragetext: "${f.frage}"');
        }
      });

      test('${fall.key} — jede Währung kommt nur einmal vor', () async {
        // Die eigentliche Zusicherung hinter dem Wegfall des Codes: Stünden
        // zwei Fragen mit demselben Währungsnamen in einer Station, wäre
        // mindestens eine davon mehrdeutig.
        final fragen = await FragenGenerator.generiereFragenFuerStation(
            _station(LernModus.waehrungZuLand, fall.value, id: 'wl_u_${fall.key}'));
        final texte = fragen
            .where((f) => f.modus == LernModus.waehrungZuLand)
            .map((f) => f.frage)
            .toList();
        expect(texte.toSet().length, texte.length,
            reason: 'zweimal dieselbe Währung gefragt: $texte');
      });

      test('${fall.key} — jede Frage trägt ein Zeichen oder bewusst keins',
          () async {
        // Der Schlüssel MUSS da sein: An ihm erkennt die Oberfläche, dass
        // eine Münze über die Frage gehört. Sein Wert darf leer sein — dann
        // hat die Währung kein echtes Zeichen und die Münze bleibt blank.
        //
        // Was NICHT vorkommen darf, ist eine Abkürzung als Prägung: „Fr",
        // „NT$", „KSh". Deshalb wird jedes nicht-leere Zeichen dagegen
        // geprüft, ob es überhaupt ein Währungssymbol ist.
        final fragen = await FragenGenerator.generiereFragenFuerStation(
            _station(LernModus.waehrungZuLand, fall.value,
                id: 'wl_sym_${fall.key}'));
        for (final f in fragen) {
          if (f.modus != LernModus.waehrungZuLand) continue;
          expect(f.meta.containsKey('symbol'), isTrue,
              reason: 'kein Zeichen-Schlüssel bei "${f.frage}"');
          final symbol = f.meta['symbol'] as String;
          if (symbol.isEmpty) continue;
          expect(_istWaehrungsZeichen(symbol), isTrue,
              reason: '"$symbol" ist eine Abkürzung, kein Währungszeichen');
        }
      });
    }

    test('Kein Ablenker nutzt dieselbe Währung wie die Antwort', () async {
      // AM GERÄT AUFGEFALLEN: "Welches Land nutzt Euro?" mit Luxemburg,
      // Finnland, Nordmazedonien und Deutschland — drei davon richtig.
      //
      // Ursache war der allgemeine Ablenker-Generator: Er füllt aus dem
      // ganzen Kontinent auf, sobald die übergebene Liste zu kurz ist, und
      // ging dabei am Währungsfilter vorbei. Ein Pool aus einem einzigen
      // Land — wie im Debug-Testmodus — reichte dafür aus.
      const einLand = ['DE'];
      final fragen = await FragenGenerator.generiereFragenFuerStation(
          _station(LernModus.waehrungZuLand, einLand,
              id: 'wl_ablenker', fragen: 1));
      for (final f in fragen) {
        if (f.modus != LernModus.waehrungZuLand) continue;
        final richtige = f.antwortOptionen
            .where((o) => _nutztWaehrungVon(o, f.richtigeAntwort))
            .toList();
        expect(richtige, [f.richtigeAntwort],
            reason: 'mehrere Optionen nutzen dieselbe Währung: $richtige');

        // ZWEITER ANLAUF, ebenfalls am Gerät gesehen: Zypern nutzt den Euro,
        // fehlt aber in currencies.dart — es liess sich also gar nicht
        // prüfen und stand trotzdem neben Deutschland in der Auswahl.
        // Seither kommen Ablenker nur noch aus dem Währungsdatensatz.
        for (final opt in f.antwortOptionen) {
          expect(_waehrungBekannt(opt), isTrue,
              reason: '"$opt" steht nicht im Währungsdatensatz und lässt '
                  'sich damit nicht gegen die Antwort prüfen');
        }
      }
    });

    test('Das Zeichen verrät die Antwort nicht', () async {
      // Zu einem Zeichen gehören oft mehrere Länder — es ist ein Hinweis,
      // keine Lösung. Geprüft wird das Gegenteil des Verrats: dass das
      // Zeichen in keiner der vier Antwortmöglichkeiten steht.
      final fragen = await FragenGenerator.generiereFragenFuerStation(
          _station(LernModus.waehrungZuLand, _europa, id: 'wl_verrat'));
      for (final f in fragen) {
        if (f.modus != LernModus.waehrungZuLand) continue;
        final symbol = f.meta['symbol'] as String;
        if (symbol.isEmpty) continue;
        for (final opt in f.antwortOptionen) {
          expect(opt.contains(symbol), isFalse,
              reason: 'Zeichen "$symbol" steht in der Option "$opt"');
        }
      }
    });
  });
}
