import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/services/station_session_service.dart';

// ── Was passiert nach einer falschen Antwort INNERHALB einer Station? ─────────
//
// Zwei Verhalten, je nach Modus:
//
//  • Flagge, Umriss, Hauptstadt ([kModiMitWiederholung]) — die Frage wandert
//    zurück ans Ende der Warteschlange und kommt so lange wieder, bis sie
//    sitzt. Genau dafür ist die Station da.
//
//  • Alles andere ([kOhneWiederholung]) — der Fehler ist endgültig, es geht
//    zur nächsten Frage. Wer gerade daneben geschätzt hat, hat die Lösung
//    schon gesehen; dieselbe Aufgabe direkt noch einmal ist keine Übung.
//
// Der zweite Fall ist neu. Er ist der Grund für [StationSession.sterneBasis]:
// Die Sterne hingen bisher an den RICHTIGEN Antworten, und das ging nur auf,
// weil am Ende jede Frage einmal richtig war. Diese Tests halten beides
// zusammen fest — das Nicht-Wiederholen und die unveränderte Sternezahl.

Frage _frage(String id, LernModus modus) => Frage(
      id: id,
      frage: 'Frage $id',
      richtigeAntwort: 'richtig',
      antwortOptionen: const ['richtig', 'falsch'],
      modus: modus,
      laenderCode: 'DE',
    );

StationSession _session(LernModus modus, {int fragen = 3}) => StationSession(
      stationId: 'test_station',
      aktiveFragen: [
        for (var i = 0; i < fragen; i++) _frage('f$i', modus),
      ],
    );

void main() {
  group('Modi ohne Wiederholung — der Fehler ist endgültig', () {
    // Ein Vertreter je Familie: Schätzen, Spielen, Zufallswissen.
    const modi = [
      LernModus.laenderRanking,
      LernModus.preisSchaetzen,
      LernModus.zufallsFakt,
      LernModus.sortierSpiel,
      LernModus.waehrungsQuiz,
    ];

    for (final m in modi) {
      test('${m.name}: falsche Frage kommt nicht zurück', () {
        final s = _session(m);
        s.falscheAntwortVerarbeiten();
        expect(s.aktiveFragen.length, 3,
            reason: 'die Warteschlange ist gewachsen — die Frage kam zurück');
        expect(s.istFertig, isFalse);
        s.falscheAntwortVerarbeiten();
        s.falscheAntwortVerarbeiten();
        expect(s.istFertig, isTrue,
            reason: 'nach drei Antworten muss die Station durch sein');
      });

      test('${m.name}: nichts landet in der Wiederholungsrunde', () {
        final s = _session(m);
        s.falscheAntwortVerarbeiten();
        expect(s.falscheFragen, isEmpty);
      });
    }

    test('Drei Fragen, alle falsch — trotzdem drei Sterne', () {
      final s = _session(LernModus.laenderRanking);
      s.falscheAntwortVerarbeiten();
      s.falscheAntwortVerarbeiten();
      s.falscheAntwortVerarbeiten();
      expect(s.richtigeAntworten, 0);
      expect(s.sterneBasis, 3,
          reason: 'ein Stern je beantworteter Frage, nicht je richtiger');
    });

    test('Gemischt beantwortet — ein Stern je Frage', () {
      final s = _session(LernModus.preisSchaetzen, fragen: 5);
      s.richtigeAntwortVerarbeiten();
      s.falscheAntwortVerarbeiten();
      s.richtigeAntwortVerarbeiten();
      s.falscheAntwortVerarbeiten();
      s.richtigeAntwortVerarbeiten();
      expect(s.istFertig, isTrue);
      expect(s.sterneBasis, 5);
    });
  });

  group('Modi mit Wiederholung — unverändert', () {
    const modi = [
      LernModus.flaggenQuizBild,
      LernModus.umrissMultiple,
      LernModus.hauptstaedteEingabe,
    ];

    for (final m in modi) {
      test('${m.name}: falsche Frage kommt zurück', () {
        final s = _session(m);
        s.falscheAntwortVerarbeiten();
        expect(s.aktiveFragen.length, 4);
        expect(s.aktiveFragen.last.id, 'f0');
      });

      test('${m.name}: die Frage landet in der Wiederholungsrunde', () {
        final s = _session(m);
        s.falscheAntwortVerarbeiten();
        expect(s.falscheFragen.map((f) => f.id), ['f0']);
      });
    }

    test('Eine falsche Frage zählt für die Sterne genau einmal', () {
      // Sie kommt zurück, wird beim zweiten Anlauf richtig — und darf dann
      // nicht doppelt zählen, weil sonst mehr Sterne herauskämen als Fragen
      // in der Station stehen.
      final s = _session(LernModus.flaggenQuizBild, fragen: 3);
      s.falscheAntwortVerarbeiten(); // f0 falsch -> hinten dran
      s.richtigeAntwortVerarbeiten(); // f1
      s.richtigeAntwortVerarbeiten(); // f2
      s.richtigeAntwortVerarbeiten(); // f0 im zweiten Anlauf
      expect(s.istFertig, isTrue);
      expect(s.richtigeAntworten, 3);
      expect(s.sterneBasis, 3);
    });

    test('Mehrfach falsch, dann richtig — immer noch ein Stern', () {
      final s = _session(LernModus.umrissBild, fragen: 1);
      s.falscheAntwortVerarbeiten();
      s.falscheAntwortVerarbeiten();
      s.falscheAntwortVerarbeiten();
      s.richtigeAntwortVerarbeiten();
      expect(s.sterneBasis, 1);
      expect(s.falscheFragen.length, 1,
          reason: 'auch die Wiederholungsrunde bekommt sie nur einmal');
    });
  });

  test('Eine unterbrochene Session aus der Zeit davor kennt sterneBasis nicht',
      () {
    // Alte gespeicherte Stände haben das Feld nicht. Dort war die Grundlage
    // exakt richtigeAntworten — sonst verlöre ein Spieler mitten in einer
    // Station seine bereits verdienten Sterne.
    final s = StationSession.fromJson({
      'stationId': 'alt',
      'aktiveFragen': [_frage('f0', LernModus.flaggenQuizBild).toJson()],
      'falscheFragen': <dynamic>[],
      'aktuellerIndex': 4,
      'richtigeAntworten': 4,
      'falscheAntworten': 1,
    });
    expect(s.sterneBasis, 4);
  });

  test('sterneBasis übersteht das Speichern und Laden', () {
    final s = _session(LernModus.laenderRanking);
    s.falscheAntwortVerarbeiten();
    s.richtigeAntwortVerarbeiten();
    final wieder = StationSession.fromJson(s.toJson());
    expect(wieder.sterneBasis, 2);
  });
}
