import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/services/station_session_service.dart';

// ── Innerhalb einer Station kommt keine Frage zweimal ────────────────────────
//
// Die einzige erlaubte Wiederholung ist die zur KORREKTUR: Wer bei Flagge,
// Umriss oder Hauptstadt danebenliegt, bekommt dieselbe Frage später noch
// einmal (siehe kModiMitWiederholung und wiederholung_in_station_test.dart).
// Das passiert in der Session, nicht im Generator — geprüft wird hier der
// ERSTE Durchgang.
//
// VORGESCHICHTE: 48 der 594 Stationen stellten dieselbe Frage mehrfach.
// _pick() füllte mit Wiederholungen auf, sobald der Modus den Abschnitts-Pool
// zu dünn gesiebt hatte — achtmal „Welche Währung hat dieses Land?" mit
// Serbien, siebenmal „Welches Land grenzt an Papua-Neuguinea?".
//
// Dagegen steht jetzt eine Kette aus drei Stufen:
//
//   1. Trägt der Abschnitt den Modus nicht (weniger als die Hälfte der Fragen
//      aus eigenen Ländern), wird der MODUS getauscht — dieselben Länder,
//      andere Frageart.
//   2. Fehlen nur einzelne Länder, wird der POOL erweitert: erst der
//      Kontinent des Abschnitts, dann die ganze Welt.
//   3. Reicht auch das nicht, wird die Station KÜRZER. Doppelt nie.

String _kennung(Frage f) =>
    '${f.modus.name}|${f.laenderCode}|${f.frage}|${f.richtigeAntwort}';

List<String> _doppelte(List<Frage> fragen) {
  final zaehler = <String, int>{};
  for (final f in fragen) {
    zaehler[_kennung(f)] = (zaehler[_kennung(f)] ?? 0) + 1;
  }
  return zaehler.entries
      .where((e) => e.value > 1)
      .map((e) => '${e.value}x ${e.key}')
      .toList();
}

LernStation _station(LernModus modus, List<String> laender, int fragen) =>
    LernStation(
      id: 'test_ohne_kontext',
      modus: modus,
      fragenAnzahl: fragen,
      laenderCodes: laender,
      kategorien: const [],
      schwierigkeitsgrad: 2,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Der ganze Lernpfad', () {
    // Der Durchlauf baut alle 594 Stationen einmal auf. Das dauert, ist aber
    // die einzige Prüfung, die auch die Modi erwischt, die nur an wenigen
    // Stellen im Pfad stehen.
    test('Keine Station stellt dieselbe Frage zweimal', () async {
      final verstoesse = <String>[];
      for (final welt in lernwelten) {
        for (final abschnitt in welt.abschnitte) {
          for (final station in abschnitt.stationen) {
            // Frischer Fortschritt je Station: Sonst hinge das Ergebnis am
            // Round-Robin-Stand der vorher gebauten Stationen.
            SharedPreferences.setMockInitialValues({});
            final fragen =
                await FragenGenerator.generiereFragenFuerStation(station);
            final doppelt = _doppelte(fragen);
            if (doppelt.isNotEmpty) {
              verstoesse.add(
                  '${station.id} (${station.modus.name}): ${doppelt.join(", ")}');
            }
          }
        }
      }
      expect(verstoesse, isEmpty,
          reason: 'Stationen mit doppelter Frage:\n${verstoesse.join("\n")}');
    }, timeout: const Timeout(Duration(minutes: 10)));

    test('Keine Station verliert dabei Fragen', () async {
      // Die Gegenprobe zur Entdopplung: Stufe 3 der Kette (kürzere Station)
      // ist die Rückfallebene, nicht der Normalfall. Träte sie irgendwo im
      // Pfad ein, hätte jemand Daten entfernt oder eine Fragenzahl erhöht,
      // ohne dass Modus-Tausch und Pool-Erweiterung das auffangen.
      final zuKurz = <String>[];
      for (final welt in lernwelten) {
        for (final abschnitt in welt.abschnitte) {
          for (final station in abschnitt.stationen) {
            SharedPreferences.setMockInitialValues({});
            final fragen =
                await FragenGenerator.generiereFragenFuerStation(station);
            if (fragen.length < station.fragenAnzahl) {
              zuKurz.add('${station.id} (${station.modus.name}): '
                  '${fragen.length} statt ${station.fragenAnzahl}');
            }
          }
        }
      }
      expect(zuKurz, isEmpty, reason: zuKurz.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 10)));
  });

  group('Die drei Stufen einzeln', () {
    test('Stufe 2 — winziger Pool wird aufgefüllt, nicht wiederholt', () async {
      // Zwei Länder, acht Fragen. Vorher kamen sechs Wiederholungen.
      final fragen = await FragenGenerator.generiereFragenFuerStation(
          _station(LernModus.flaggenQuizBild, ['DE', 'FR'], 8));
      expect(_doppelte(fragen), isEmpty);
      expect(fragen.length, 8, reason: 'aus der Welt aufgefüllt');
      expect(
          fragen.map((f) => f.laenderCode).where(['DE', 'FR'].contains).length,
          2,
          reason: 'die beiden eigenen Länder bleiben drin');
    });

    test('Stufe 1 — trägt der Abschnitt den Modus nicht, wechselt der Modus',
        () async {
      // Inselstaaten ohne Landgrenze: Nur Papua-Neuguinea hätte einen
      // Nachbarn. Statt sieben Fragen über fremde Länder wird daraus ein
      // Flaggen-Quiz über genau diese sieben.
      const inseln = ['PG', 'FJ', 'WS', 'TO', 'VU', 'SB', 'NZ'];
      final fragen = await FragenGenerator.generiereFragenFuerStation(
          _station(LernModus.nachbarland, inseln, 7));
      expect(_doppelte(fragen), isEmpty);
      expect(fragen.every((f) => f.modus != LernModus.nachbarland), isTrue,
          reason: 'der Modus hätte getauscht werden müssen');
      expect(fragen.every((f) => inseln.contains(f.laenderCode)), isTrue,
          reason: 'der Tausch behält die Länder des Abschnitts: '
              '${fragen.map((f) => f.laenderCode).toList()}');
    });

    test('Stufe 1 vor Stufe 2 — lieber eigener Abschnitt als eigener Modus',
        () async {
      // Dieselbe Reihenfolge bei der Währung: Im Datensatz stehen 78 Länder,
      // in diesem Abschnitt genau eines. Den Pool zu erweitern ginge — die
      // Welt hat Währungen genug —, ergäbe aber einen Europa-Abschnitt über
      // asiatische Währungen.
      const europaDuenn = ['RS', 'BA', 'ME', 'MK', 'AL', 'MD', 'BY', 'UA'];
      final fragen = await FragenGenerator.generiereFragenFuerStation(
          _station(LernModus.waehrungsQuiz, europaDuenn, 8));
      expect(_doppelte(fragen), isEmpty);
      expect(fragen.every((f) => europaDuenn.contains(f.laenderCode)), isTrue,
          reason: 'fremde Länder statt Modus-Tausch: '
              '${fragen.map((f) => f.laenderCode).toList()}');
    });

    test('Sortierspiel — keine zwei Runden mit derselben Fünfergruppe',
        () async {
      // Hier ist die Frage kein Land, sondern eine Ländergruppe: Bei genau
      // fünf tauglichen Ländern gab es nur eine mögliche Runde, und die
      // Station stellte sie dreimal.
      final fragen = await FragenGenerator.generiereFragenFuerStation(
          _station(LernModus.sortierSpiel, ['BR', 'AR', 'CL', 'CO', 'PE'], 3));
      expect(_doppelte(fragen), isEmpty);
      final gruppen = fragen
          .map((f) =>
              (List<String>.from(f.meta['laenderCodes'] as List)..sort())
                  .join(','))
          .toList();
      expect(gruppen.toSet().length, gruppen.length,
          reason: 'zweimal dieselbe Fünfergruppe: $gruppen');
    });
  });
}
