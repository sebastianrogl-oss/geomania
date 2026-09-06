import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/services/station_session_service.dart';

/// Die erste Station jeder Welt.
///
/// ══ WAS VORHER PASSIERTE ════════════════════════════════════════════════
///
/// Festgelegt war nur die allererste Station des GANZEN Pfads. Jede weitere
/// Welt begann mit dem, was die Verteilung gerade übrig hatte — gemessen:
///
///   Europa      flaggenQuizBild
///   Südamerika  hauptstaedteMultiple
///   Nordamerika waehrungsQuiz
///   Afrika      flaggenQuizMultiple
///   Asien       umrissMultiple
///   Ozeanien    zweiWahrheiten
///   Welt        waehrungZuLand
///
/// Eine neue Welt ist aber jedes Mal ein Anfang: andere Länder, nichts davon
/// schon geübt. Der Umriss eines unbekannten Landes ist dafür der härteste
/// Einstieg, die Flagge der leichteste.
void main() {
  test('Jede Welt beginnt mit einem Flaggen-Quiz', () async {
    // ══ ZWEIMAL GEPRÜFT, UND DAS IST DER PUNKT ═══════════════════════════
    //
    // Dieser Test sah nur auf station.modus — den Modus im PFAD. Am Gerät
    // stand trotzdem ein Nachbarland-Quiz an erster Stelle, und der Test
    // blieb grün.
    //
    // Denn was gespielt (und im Stations-Blatt angezeigt) wird, entscheidet
    // ermittleTatsaechlichenModus: Ein Kern-Modus, der laut Rotations-Tracker
    // jedes Land seines Pools schon gebracht hat, gilt als pensioniert und
    // wird zur Spielzeit ersetzt. Das ist die Sicht, die der Spieler sieht —
    // also muss sie mitgeprüft werden.
    SharedPreferences.setMockInitialValues({});
    for (final welt in lernwelten) {
      final erste = welt.abschnitte.first.stationen.first;
      expect(erste.modus, LernModus.flaggenQuizBild,
          reason: 'Pfad: ${welt.id} beginnt mit ${erste.modus.name}');
      expect(await FragenGenerator.ermittleTatsaechlichenModus(erste),
          LernModus.flaggenQuizBild,
          reason: 'Laufzeit: ${welt.id} wird als etwas anderes gespielt');
    }
  });

  test('Die Vierer-Regel bleibt dabei unangetastet', () {
    // Der Welteinstieg ist eine ABFRAGE. Endete die Welt davor mit vier
    // Abfragen, wäre er die fünfte in Folge — genau an der Naht, an der
    // solche Ketten schon einmal entstanden sind. Der letzte Abschnitt jeder
    // Welt bekommt deshalb eine Reserve (siehe ketteReserve).
    //
    // Geprüft wird der ganze Pfad am Stück, ueber Welt- und
    // Abschnittsgrenzen hinweg — dasselbe Mass wie in lernpfad_test.dart.
    var kette = 0;
    var laengste = 0;
    String? schlimmste;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (istSpielModus(s.modus)) {
            kette = 0;
          } else {
            kette++;
            if (kette > laengste) {
              laengste = kette;
              schlimmste = s.id;
            }
          }
        }
      }
    }
    expect(laengste, lessThanOrEqualTo(kMaxAbfrageKette),
        reason: 'Kette der Länge $laengste bei $schlimmste');
  });

  test('Vor dem Welteinstieg endet die Kette bei höchstens drei', () {
    // Die Gegenprobe zur Reserve: Genau das macht Platz für das angepinnte
    // Flaggen-Quiz. Ohne sie waere der Test darueber die einzige Warnung —
    // und der Grund dafuer nicht zu erkennen.
    for (var i = 1; i < lernwelten.length; i++) {
      final davor = lernwelten[i - 1].abschnitte.last.stationen;
      var kette = 0;
      for (final s in davor) {
        kette = istSpielModus(s.modus) ? 0 : kette + 1;
      }
      expect(kette, lessThanOrEqualTo(kMaxAbfrageKette - 1),
          reason: '${lernwelten[i - 1].id} endet mit $kette Abfragen — '
              '${lernwelten[i].id} kann dann nicht mit einer beginnen');
    }
  });

  test('Der Pfad ist deterministisch — zweimal gebaut, zweimal gleich', () {
    // Der Modus einer Station muss feststehen, egal wann man sie oeffnet.
    // Ein Spieler, der beim ersten Mal ein Nachbarland-Quiz sieht und beim
    // "Noch mal spielen" ein Flaggen-Quiz, haelt die App zu Recht fuer
    // kaputt.
    //
    // Der Pfad selbst enthaelt keinen Zufall; dieser Test haelt das fest,
    // falls jemand spaeter einen einbaut.
    List<String> abzug() => [
          for (final w in lernwelten)
            for (final a in w.abschnitte)
              for (final s in a.stationen) '${s.id}=${s.modus.name}',
        ];

    final ersterAbzug = abzug();
    expect(abzug(), ersterAbzug);
    expect(ersterAbzug.length, greaterThan(500),
        reason: 'Der Pfad ist kleiner als erwartet');

    // Und dieselbe Frage aus einer zweiten Richtung: Ein wiederholter
    // Zugriff auf denselben Abschnitt liefert dieselbe Station.
    final a = abschnittById('asien_1')!;
    expect(a.stationen.first.modus, abschnittById('asien_1')!.stationen.first.modus);
  });

  test('Der Welteinstieg hat keine eigene Bedienung', () {
    // [kNichtAlsWelteinstieg] galt schon vorher und bleibt gueltig: Wer eine
    // Welt betritt, soll zuerst etwas antippen duerfen — kein Regler, keine
    // Karten-Sortierung. Das Flaggen-Quiz erfuellt das, aber die Regel soll
    // stehen bleiben, falls hier je etwas anderes hinkommt.
    for (final welt in lernwelten) {
      final erste = welt.abschnitte.first.stationen.first;
      expect(kNichtAlsWelteinstieg.contains(erste.modus), isFalse,
          reason: '${welt.id} beginnt mit ${erste.modus.name}');
    }
  });
}
