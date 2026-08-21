import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geomania/data/countries.dart';
import 'package:geomania/data/laender_grenzketten.dart';
import 'package:geomania/data/laender_nachbarn.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/services/station_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final gueltigeIsos = countries.map((c) => c.iso2).toSet();

  test('Alle ISO-Codes in grenzkettenRaetsel existieren in countries.dart', () {
    for (final r in grenzkettenRaetsel) {
      for (final iso in [r.vonLandIso, r.nachLandIso, ...r.mussDurchIso, r.keinTransitIso]) {
        expect(gueltigeIsos.contains(iso), true,
            reason: '${r.id}: ISO "$iso" existiert nicht in countries.dart');
      }
    }
  });

  test('mussDurchIso hat immer genau 3 Einträge', () {
    for (final r in grenzkettenRaetsel) {
      expect(r.mussDurchIso.length, 3,
          reason: '${r.id}: mussDurchIso hat ${r.mussDurchIso.length} statt 3 Einträge');
    }
  });

  test('Keine Duplikate innerhalb eines Eintrags', () {
    for (final r in grenzkettenRaetsel) {
      final alle = [r.vonLandIso, ...r.mussDurchIso, r.nachLandIso, r.keinTransitIso];
      expect(alle.toSet().length, alle.length,
          reason: '${r.id}: enthält Duplikate unter $alle');
    }
  });

  test('mussDurchIso bildet über die nachbarn-Map eine durchgängige Kette '
      'von vonLandIso zu nachLandIso', () {
    for (final r in grenzkettenRaetsel) {
      final kette = [r.vonLandIso, ...r.mussDurchIso, r.nachLandIso];
      for (int i = 1; i < kette.length; i++) {
        final a = kette[i - 1];
        final b = kette[i];
        final aGrenztAnB = (nachbarn[a] ?? const []).contains(b);
        final bGrenztAnA = (nachbarn[b] ?? const []).contains(a);
        expect(aGrenztAnB || bGrenztAnA, true,
            reason: '${r.id}: $a → $b ist laut nachbarn-Map kein Grenzübergang '
                '(Kette: ${kette.join(' → ')})');
      }
    }
  });

  test('keinTransitIso ist NICHT Teil der Pflicht-Route', () {
    for (final r in grenzkettenRaetsel) {
      final kette = {r.vonLandIso, ...r.mussDurchIso, r.nachLandIso};
      expect(kette.contains(r.keinTransitIso), false,
          reason: '${r.id}: keinTransitIso "${r.keinTransitIso}" ist Teil der '
              'eigentlichen Route ${kette.join(', ')}');
    }
  });

  test('Jeder Kontinent-Wert ist einer der bekannten Kontinent-IDs', () {
    const bekannt = {'europa', 'afrika', 'asien', 'nordamerika', 'suedamerika', 'ozeanien'};
    for (final r in grenzkettenRaetsel) {
      expect(bekannt.contains(r.kontinent), true,
          reason: '${r.id}: unbekannter Kontinent "${r.kontinent}"');
    }
  });

  test('grenzkettenRaetsel kommt im Lernpfad vor, aber erst ab Level 2 '
      '(außer bei Welt, die laut Teil 3 des Block-Umbaus bewusst von Anfang '
      'an den vollen Modus-Satz nutzt)', () {
    var gefunden = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.grenzkettenRaetsel) continue;
          gefunden++;
          if (welt.id == 'welt') continue;
          expect(a.stufe, greaterThanOrEqualTo(2),
              reason: '${s.id}: grenzkettenRaetsel in Level-1-Abschnitt ${a.id}');
        }
      }
    }
    expect(gefunden, greaterThan(0), reason: 'grenzkettenRaetsel kommt nirgends vor');
  });

  test('grenzkettenRaetsel fällt auf Südamerika-Station ohne Crash zurück '
      '(kein kuratierter Eintrag für den Kontinent)', () async {
    final suedamWelt = lernwelten.firstWhere((w) => w.id == 'suedamerika');
    final abschnitt2 = suedamWelt.abschnitte.firstWhere((a) => a.stufe == 2);
    final echteStation = abschnitt2.stationen.first;
    final testStation = LernStation(
      id: echteStation.id,
      modus: LernModus.grenzkettenRaetsel,
      fragenAnzahl: echteStation.fragenAnzahl,
      laenderCodes: echteStation.laenderCodes,
      kategorien: echteStation.kategorien,
      schwierigkeitsgrad: echteStation.schwierigkeitsgrad,
    );
    final fragen = await FragenGenerator.generiereFragenFuerStation(testStation);
    expect(fragen.length, testStation.fragenAnzahl,
        reason: 'Fallback für grenzkettenRaetsel ohne Kontinent-Eintrag lieferte '
            'falsche Anzahl (${fragen.length} statt ${testStation.fragenAnzahl})');
  });

  test('grenzkettenRaetsel-Fragen zeigen die richtige Route in meta.kette', () async {
    // Nimm eine echte Europa-Station und erzwinge grenzkettenRaetsel, um die
    // Frage-Struktur (Optionen, Route, Erklärung) zu prüfen.
    final europaWelt = lernwelten.firstWhere((w) => w.id == 'europa');
    final abschnitt2 = europaWelt.abschnitte.firstWhere((a) => a.stufe == 2);
    final echteStation = abschnitt2.stationen.first;
    final testStation = LernStation(
      id: echteStation.id,
      modus: LernModus.grenzkettenRaetsel,
      fragenAnzahl: echteStation.fragenAnzahl,
      laenderCodes: echteStation.laenderCodes,
      kategorien: echteStation.kategorien,
      schwierigkeitsgrad: echteStation.schwierigkeitsgrad,
    );
    final fragen = await FragenGenerator.generiereFragenFuerStation(testStation);
    expect(fragen.length, testStation.fragenAnzahl);
    for (final f in fragen) {
      expect(f.antwortOptionen.length, 4, reason: f.id);
      expect(f.antwortOptionen, contains(f.richtigeAntwort), reason: f.id);
      expect(f.antwortOptionen.toSet().length, f.antwortOptionen.length,
          reason: '${f.id}: doppelte Antwortoptionen');
      final kette = f.meta['kette'] as List<dynamic>?;
      expect(kette, isNotNull, reason: '${f.id}: keine Route in meta gespeichert');
      expect(kette!.length, 5, reason: '${f.id}: Route sollte 5 Länder haben (von+3+nach)');
      expect(kette.contains(f.richtigeAntwort), false,
          reason: '${f.id}: richtige Antwort ist Teil der eigentlichen Route');
    }
  });
}
