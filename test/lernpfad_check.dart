import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/services/station_session_service.dart';

// Erwartete Stationsanzahl pro Abschnitt — darf sich durch den Umbau der
// Modus-Verteilung NICHT verändert haben.
const erwarteteAnzahl = {
  'europa_1': 17, 'europa_2': 18, 'europa_3': 22, 'europa_4': 25,
  'suedamerika_1': 10, 'suedamerika_2': 12, 'suedamerika_3': 14, 'suedamerika_4': 16,
  'nordamerika_1': 12, 'nordamerika_2': 14, 'nordamerika_3': 18, 'nordamerika_4': 20,
  'afrika_1': 18, 'afrika_2': 22, 'afrika_3': 26, 'afrika_4': 30,
  'asien_1': 16, 'asien_2': 20, 'asien_3': 24, 'asien_4': 28,
  'ozeanien_1': 10, 'ozeanien_2': 12, 'ozeanien_3': 14, 'ozeanien_4': 16,
  'welt_1': 25, 'welt_2': 30, 'welt_3': 35, 'welt_4': 40,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('1) Stationsanzahl pro Abschnitt unverändert', () {
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        expect(a.stationen.length, erwarteteAnzahl[a.id],
            reason: 'Abschnitt ${a.id}');
      }
    }
  });

  test('2) Kein Modus wiederholt sich direkt hintereinander', () {
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (int i = 1; i < a.stationen.length; i++) {
          expect(a.stationen[i].modus == a.stationen[i - 1].modus, false,
              reason: '${a.id} Station $i: ${a.stationen[i].modus}');
        }
      }
    }
  });

  test('2b) Kein THEMA wiederholt sich direkt hintereinander (z.B. Flagge-Bild → Flagge-Multiple verboten)', () {
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (int i = 1; i < a.stationen.length; i++) {
          final vorher = lernModusThema(a.stationen[i - 1].modus);
          final jetzt = lernModusThema(a.stationen[i].modus);
          expect(jetzt == vorher, false,
              reason: '${a.id} Station $i: Thema "$jetzt" wiederholt sich '
                  '(${a.stationen[i - 1].modus.name} → ${a.stationen[i].modus.name})');
        }
      }
    }
  });

  test('2c) Allererste Station im gesamten Pfad (Europa Abschnitt 1) ist flaggenQuizBild', () {
    final ersteStation = lernwelten.first.abschnitte.first.stationen.first;
    expect(ersteStation.modus, LernModus.flaggenQuizBild);
  });

  test('2d) Varianten eines mehrfach vorkommenden Themas werden möglichst breit genutzt', () {
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        final proThema = <String, Set<LernModus>>{};
        for (final s in a.stationen) {
          final thema = lernModusThema(s.modus);
          (proThema[thema] ??= {}).add(s.modus);
        }
        // Themen mit mehreren bekannten Varianten:
        const gruppen = {
          'flaggen': {
            LernModus.flaggenQuizBild,
            LernModus.flaggenQuizMultiple,
            LernModus.flaggenFarbe,
          },
          'umriss': {LernModus.umrissBild, LernModus.umrissMultiple},
          'hauptstaedte': {
            LernModus.hauptstaedteMultiple,
            LernModus.hauptstaedteEingabe,
            LernModus.hauptstadtZuLand,
          },
          'waehrung': {LernModus.waehrungsQuiz, LernModus.waehrungZuLand},
        };
        for (final entry in gruppen.entries) {
          final genutzt = proThema[entry.key];
          if (genutzt == null) continue;
          final anzahlStationenDiesesThemas =
              a.stationen.where((s) => lernModusThema(s.modus) == entry.key).length;
          final variantenImPool =
              entry.value.where((m) => modiFuerLevel(a.stufe).contains(m)).toList();
          if (anzahlStationenDiesesThemas >= 2 && variantenImPool.length >= 2) {
            // So viele verschiedene Varianten wie möglich, begrenzt durch
            // Anzahl der Stationen dieses Themas bzw. Pool-Größe.
            final erwartet = anzahlStationenDiesesThemas < variantenImPool.length
                ? anzahlStationenDiesesThemas
                : variantenImPool.length;
            expect(genutzt.length, erwartet,
                reason: '${a.id}: Thema "${entry.key}" kommt ${anzahlStationenDiesesThemas}x vor, '
                    'nutzt aber nur $genutzt (Pool hat $variantenImPool)');
          }
        }
      }
    }
  });

  test('2e) Gleichmäßige Verteilung: kein Modus dominiert einen Abschnitt', () {
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        final zaehler = <LernModus, int>{};
        for (final s in a.stationen) {
          zaehler[s.modus] = (zaehler[s.modus] ?? 0) + 1;
        }
        final anzahlModi = modiFuerLevel(a.stufe).length;
        final erwarteterMax = (a.stationen.length / anzahlModi).ceil() + 1;
        for (final entry in zaehler.entries) {
          expect(entry.value <= erwarteterMax, true,
              reason: '${a.id}: ${entry.key.name} kommt ${entry.value}x vor '
                  '(erwartet max. $erwarteterMax bei ${a.stationen.length} Stationen / $anzahlModi Modi)');
        }
      }
    }
  });

  test('3) Neue Modi kommen tatsächlich im Lernpfad vor', () {
    final neueModi = {
      LernModus.nachbarland,
      LernModus.bipGesamt,
      LernModus.flaeche,
      LernModus.extremFrage,
      LernModus.waehrungZuLand,
    };
    final gefunden = <LernModus, int>{};
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (neueModi.contains(s.modus)) {
            gefunden[s.modus] = (gefunden[s.modus] ?? 0) + 1;
          }
        }
      }
    }
    for (final m in neueModi) {
      // ignore: avoid_print
      print('${m.name}: ${gefunden[m] ?? 0}x');
      expect(gefunden[m] ?? 0, greaterThan(0), reason: '${m.name} fehlt komplett');
    }
  });

  test('4) Einsteiger nutzt nur die leichten Modi, Meister enthält den vollen Modus-Satz', () {
    final level1Modi = <LernModus>{};
    final level4Modi = <LernModus>{};
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (a.stufe == 1) level1Modi.add(s.modus);
          if (a.stufe == 4) level4Modi.add(s.modus);
        }
      }
    }
    // Level 1 darf die schwersten Modi nicht enthalten.
    expect(level1Modi.contains(LernModus.hauptstaedteEingabe), false);
    expect(level1Modi.contains(LernModus.extremFrage), false);
    expect(level1Modi.contains(LernModus.wirtschaftssektoren), false);
    // Level 4 enthält den kompletten Modus-Satz (alle 15 Modi).
    expect(level4Modi.length, LernModus.values.length);
  });

  test('4c) Level 1 (Einsteiger) hat einen deutlich größeren Pool (9+ Modi)', () {
    expect(modiFuerLevel(1).length, greaterThanOrEqualTo(9));
  });

  test('4d) Neue Einsteiger-Modi kommen tatsächlich im Lernpfad vor', () {
    final neueModi = {
      LernModus.hauptstadtZuLand,
      LernModus.groessteStadt,
      LernModus.flaggenFarbe,
      LernModus.extremFrageLeicht,
    };
    final gefunden = <LernModus, int>{};
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (neueModi.contains(s.modus)) {
            gefunden[s.modus] = (gefunden[s.modus] ?? 0) + 1;
          }
        }
      }
    }
    for (final m in neueModi) {
      // ignore: avoid_print
      print('${m.name}: ${gefunden[m] ?? 0}x');
      expect(gefunden[m] ?? 0, greaterThan(0), reason: '${m.name} fehlt komplett');
    }
  });

  test('4e) hauptstadtZuLand und extremFrageLeicht verraten das Land nicht (laenderCode leer)', () async {
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.hauptstadtZuLand &&
              s.modus != LernModus.extremFrageLeicht) {
            continue;
          }
          for (final f in await FragenGenerator.generiereFragenFuerStation(s)) {
            expect(f.laenderCode, '', reason: '${f.id} verrät das Land');
          }
        }
      }
    }
  });

  test('4f) HARTE REGEL: kein Modus wiederholt sich, bevor nicht der ganze Pool einmal dran war', () {
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        final poolGroesse = modiFuerLevel(a.stufe).length;
        final gesehen = <LernModus>{};
        for (final s in a.stationen) {
          if (gesehen.contains(s.modus)) {
            expect(gesehen.length, poolGroesse,
                reason: '${a.id}: ${s.modus.name} wiederholt sich, bevor alle '
                    '$poolGroesse Modi des Pools einmal dran waren '
                    '(bisher nur ${gesehen.length}: $gesehen)');
          }
          gesehen.add(s.modus);
        }
      }
    }
  });

  test('4g) zufallsFakt kommt vor, verrät das Land nicht, und Fakten passen zum Kontinent', () async {
    int gefunden = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.zufallsFakt) continue;
          gefunden++;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          expect(fragen.length, s.fragenAnzahl, reason: s.id);
          for (final f in fragen) {
            expect(f.laenderCode, '', reason: '${f.id} verrät das Land');
            expect(f.antwortOptionen, contains(f.richtigeAntwort));
            expect(f.antwortOptionen.toSet().length, f.antwortOptionen.length,
                reason: '${f.id}: doppelte Antwortoptionen');
          }
        }
      }
    }
    expect(gefunden, greaterThan(0), reason: 'zufallsFakt kommt nirgends vor');
  });

  test('4h) bekanntesGebaeude kommt vor, verrät das Land nicht, Optionen sauber', () async {
    int gefunden = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.bekanntesGebaeude) continue;
          gefunden++;
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          expect(fragen.length, s.fragenAnzahl, reason: s.id);
          for (final f in fragen) {
            expect(f.frage, startsWith('In welchem Land steht '));
            expect(f.laenderCode, '', reason: '${f.id} verrät das Land');
            expect(f.antwortOptionen, contains(f.richtigeAntwort));
            expect(f.antwortOptionen.length, 4, reason: f.id);
            expect(f.antwortOptionen.toSet().length, f.antwortOptionen.length,
                reason: '${f.id}: doppelte Antwortoptionen');
          }
        }
      }
    }
    expect(gefunden, greaterThan(0), reason: 'bekanntesGebaeude kommt nirgends vor');
  });

  test('4i) bekanntesGebaeude ist NICHT in Level 1 (Einsteiger)', () {
    expect(modiFuerLevel(1).contains(LernModus.bekanntesGebaeude), false);
  });

  test('4b) flaggenQuizBild ist wieder ein aktiver Modus (nicht mehr nur Fallback)', () {
    final anzahl = lernwelten
        .expand((w) => w.abschnitte)
        .expand((a) => a.stationen)
        .where((s) => s.modus == LernModus.flaggenQuizBild)
        .length;
    expect(anzahl, greaterThan(1),
        reason: 'flaggenQuizBild sollte mehrfach vorkommen, nicht nur an Station 1');
  });

  test('3b) Kontinent-Zuordnung und Wahr/Falsch sind NICHT eingebaut', () {
    final alleNamen = LernModus.values.map((m) => m.name).toSet();
    expect(alleNamen.contains('kontinentZuordnung'), false);
    expect(alleNamen.contains('wahrOderFalsch'), false);
  });

  test('8) Länder-Round-Robin: Kern-Modus deckt nach genug Wiederholungen den gesamten Kontinent ab (auch Zwergstaaten)', () async {
    SharedPreferences.setMockInitialValues({});
    final a = abschnittById('europa_3')!;
    final station = a.stationen.firstWhere((s) =>
        s.modus == LernModus.flaggenQuizBild ||
        s.modus == LernModus.flaggenQuizMultiple);
    final vollerPool = station.laenderCodes.toSet();
    expect(vollerPool.length, greaterThan(40)); // ganz Europa (47 Länder)

    final gesehen = <String>{};
    // ceil(47/8) = 6 Züge für einen vollen Zyklus -> 14 Züge = >2 Zyklen.
    for (int i = 0; i < 14; i++) {
      final fragen = await FragenGenerator.generiereFragenFuerStation(station);
      gesehen.addAll(fragen.map((f) => f.laenderCode).where((c) => c.isNotEmpty));
    }

    expect(gesehen.containsAll(vollerPool), true,
        reason: 'Fehlende Länder nach 14 Zügen: ${vollerPool.difference(gesehen)}');
    for (final zwerg in ['VA', 'SM', 'LI', 'AD', 'MC']) {
      expect(gesehen.contains(zwerg), true, reason: '$zwerg wurde nie gezogen');
    }
  });

  test('9) Länder-Round-Robin: kein Land wiederholt sich im Thema, bevor der Kontinent einmal durch ist', () async {
    SharedPreferences.setMockInitialValues({});
    final a = abschnittById('europa_3')!;
    final station = a.stationen.firstWhere((s) =>
        s.modus == LernModus.flaggenQuizBild ||
        s.modus == LernModus.flaggenQuizMultiple);
    final vollerPool = station.laenderCodes.toSet();

    final gesehen = <String>{};
    for (int zug = 0; zug < 20; zug++) {
      final vorZug = Set<String>.from(gesehen);
      final restNoch = vollerPool.difference(vorZug).length;
      final fragen = await FragenGenerator.generiereFragenFuerStation(station);
      final gezogen =
          fragen.map((f) => f.laenderCode).where((c) => c.isNotEmpty).toList();
      final wiederholungen = gezogen.where((c) => vorZug.contains(c)).toList();
      if (wiederholungen.isNotEmpty) {
        // Wiederholung ist NUR erlaubt, wenn der Rest-Pool nicht mehr
        // ausreicht, um die volle Stationsgröße an frischen Ländern zu
        // liefern (z.B. 47 Länder / 8 pro Station geht nicht glatt auf —
        // der letzte Zug eines Zyklus füllt dann bewusst mit bereits
        // gesehenen Ländern auf, siehe _pickRoundRobin).
        expect(restNoch, lessThan(station.fragenAnzahl),
            reason: 'Zug $zug: Wiederholung $wiederholungen obwohl noch '
                '$restNoch frische Länder übrig gewesen wären');
      }
      gesehen.addAll(gezogen);
    }
  });

  test('10) Länder-Round-Robin gilt NICHT für Unterhaltungs-Modi (bleiben frei gezogen)', () async {
    SharedPreferences.setMockInitialValues({});
    final a = abschnittById('europa_3')!;
    final station =
        a.stationen.firstWhere((s) => s.modus == LernModus.zufallsFakt);
    // Reiner Rauch-Test: mehrfaches Ziehen funktioniert weiterhin ohne
    // Round-Robin-Fehler (Unterhaltungs-Modi nutzen _pick(), nicht _pickKern()).
    for (int i = 0; i < 5; i++) {
      final fragen = await FragenGenerator.generiereFragenFuerStation(station);
      expect(fragen, isNotEmpty);
    }
  });

  test('5) Fragen-Generierung crasht nie und liefert nie 0 Fragen', () async {
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);
          expect(fragen, isNotEmpty,
              reason: '${s.id} (${s.modus.name}) erzeugt 0 Fragen');
          expect(fragen.length, s.fragenAnzahl,
              reason: '${s.id} (${s.modus.name}) falsche Fragenanzahl');
        }
      }
    }
  });

  test('6) nachbarland auf Ozeanien (reine Inselstaaten) crasht nicht', () async {
    final ozeanienNachbar = lernwelten
        .firstWhere((w) => w.id == 'ozeanien')
        .abschnitte
        .expand((a) => a.stationen)
        .where((s) => s.modus == LernModus.nachbarland)
        .toList();
    for (final s in ozeanienNachbar) {
      final fragen = await FragenGenerator.generiereFragenFuerStation(s);
      expect(fragen, isNotEmpty);
      // PG ist der einzige Ozeanien-Nachbar mit Landgrenze (zu ID) — alle
      // anderen sind Inseln, der Generator muss also auf Fallback ausweichen
      // oder auf PG zurückgreifen, darf aber nicht abstürzen/leer bleiben.
    }
  });

  test('7) Welt-Profi/Meister (vorher *-Bug) erzeugen jetzt Fragen', () async {
    for (final id in ['welt_3', 'welt_4']) {
      final a = abschnittById(id)!;
      for (final s in a.stationen) {
        final fragen = await FragenGenerator.generiereFragenFuerStation(s);
        expect(fragen, isNotEmpty, reason: '$id Station ${s.id}');
      }
    }
  });
}
