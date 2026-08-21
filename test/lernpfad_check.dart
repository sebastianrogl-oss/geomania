import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geomania/data/alle_laender.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/services/fortschritt_service.dart';
import 'package:geomania/services/station_session_service.dart';

// Erwartete Stationsanzahl pro Abschnitt. Ursprüngliche Werte wurden um 1-3
// Stationen aufgestockt (siehe _baueAbschnitt "Polster"), damit der
// Zickzack-Pfad mittig vor dem Checkpoint endet — mit echten, spielbaren
// Stationen statt der früheren rein dekorativen Füll-Punkte.
const erwarteteAnzahl = {
  'europa_1': 21, 'europa_2': 25, 'europa_3': 25, 'europa_4': 25,
  'suedamerika_1': 13, 'suedamerika_2': 13, 'suedamerika_3': 17,
  'nordamerika_1': 13, 'nordamerika_2': 17, 'nordamerika_3': 21, 'nordamerika_4': 21,
  'afrika_1': 21, 'afrika_2': 25, 'afrika_3': 29, 'afrika_4': 33,
  'asien_1': 21, 'asien_2': 21, 'asien_3': 25, 'asien_4': 29,
  'ozeanien_1': 13, 'ozeanien_2': 13, 'ozeanien_3': 17,
  'welt_1': 25, 'welt_2': 33, 'welt_3': 37, 'welt_4': 41,
};

/// Welt nutzt (siehe Teil 3 des Block-Umbaus) von Anfang an den VOLLEN
/// Modus-Satz (Level 4) statt des stufen-abhängigen Pools, weil sie keine
/// Block-Vollrotation pro Abschnitt braucht und dadurch mehr Raum für
/// Abwechslung hat. Tests, die sich auf "den für diesen Abschnitt genutzten
/// Modus-Pool" beziehen, müssen das hier berücksichtigen.
int _poolLevelFuer(LernWelt welt, LernAbschnitt a) => welt.id == 'welt' ? 4 : a.stufe;

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
            LernModus.flaggenQuizEingabe,
          },
          'umriss': {
            LernModus.umrissBild,
            LernModus.umrissMultiple,
            LernModus.umrissEingabe,
          },
          'hauptstaedte': {
            LernModus.hauptstaedteMultiple,
            LernModus.hauptstaedteEingabe,
          },
          'waehrung': {LernModus.waehrungsQuiz, LernModus.waehrungZuLand},
        };
        for (final entry in gruppen.entries) {
          final genutzt = proThema[entry.key];
          if (genutzt == null) continue;
          final anzahlStationenDiesesThemas =
              a.stationen.where((s) => lernModusThema(s.modus) == entry.key).length;
          final variantenImPool = entry.value
              .where((m) => modiFuerLevel(_poolLevelFuer(welt, a)).contains(m))
              .toList();
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
        final anzahlModi = modiFuerLevel(_poolLevelFuer(welt, a)).length;
        final erwarteterMax = (a.stationen.length / anzahlModi).ceil() + 1;
        for (final entry in zaehler.entries) {
          expect(entry.value <= erwarteterMax, true,
              reason: '${a.id}: ${entry.key.name} kommt ${entry.value}x vor '
                  '(erwartet max. $erwarteterMax bei ${a.stationen.length} Stationen / $anzahlModi Modi)');
        }
      }
    }
  });

  test('3) Jeder Modus aus dem Pool kommt im Lernpfad auch wirklich vor', () {
    // Früher stand hier eine feste Liste der damals neuen Modi. Die ist bei
    // jeder Pool-Umstellung veraltet — zuletzt, als bipGesamt, flaeche und
    // extremFrage aus den Pools genommen wurden und der Test rot wurde,
    // obwohl genau das gewollt war.
    //
    // Stattdessen jetzt die allgemeine Regel: was im Pool des höchsten Levels
    // steht, muss auch irgendwo gezogen werden. Ein Modus, der im Pool steht,
    // aber durch kModusSperrenProWelt oder die Auswahllogik nirgends zum Zug
    // kommt, ist ein echter Fehler — und der fällt hier auf, ohne dass jemand
    // eine Liste pflegen muss.
    final gefunden = <LernModus, int>{};
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          gefunden[s.modus] = (gefunden[s.modus] ?? 0) + 1;
        }
      }
    }
    for (final m in modiFuerLevel(4)) {
      // ignore: avoid_print
      print('${m.name}: ${gefunden[m] ?? 0}x');
      expect(gefunden[m] ?? 0, greaterThan(0),
          reason: '${m.name} steht im Pool, kommt aber in keiner Station vor');
    }
  });

  test('4) Einsteiger nutzt nur die leichten Modi (außer Welt, die laut '
      'Teil 3 bewusst von Anfang an den vollen Modus-Satz nutzt), '
      'Meister enthält den vollen Modus-Satz', () {
    final level1Modi = <LernModus>{};
    final level4Modi = <LernModus>{};
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (a.stufe == 1 && welt.id != 'welt') level1Modi.add(s.modus);
          if (a.stufe == 4) level4Modi.add(s.modus);
        }
      }
    }
    // Level 1 darf die schwersten Modi nicht enthalten. Die 3 Eingabe-
    // Varianten sind seit der Korrektur bewusst AUSGENOMMEN: sie dürfen
    // schon in Level 1 vorkommen (die Reihenfolge-Regel pro Abschnitt
    // bleibt trotzdem in Kraft, siehe Test 4j).
    expect(level1Modi.contains(LernModus.extremFrage), false);
    expect(level1Modi.contains(LernModus.wirtschaftssektoren), false);

    // Level 4 enthält den kompletten POOL-Satz — nicht mehr den kompletten
    // Enum. Fünf Modi (bipGesamt, flaeche, extremFrage, extremFrageLeicht,
    // bekanntesGebaeude) sind aus den Pools genommen worden, ihre Generatoren
    // aber erhalten geblieben. Gegen LernModus.values.length zu prüfen hiesse
    // zu verlangen, dass auch pensionierte Modi vorkommen.
    expect(level4Modi.length, modiFuerLevel(4).length);
  });

  test('4c) Level 1 (Einsteiger) hat einen deutlich größeren Pool (9+ Modi)', () {
    expect(modiFuerLevel(1).length, greaterThanOrEqualTo(9));
  });

  test('4d) Die Spiel-Modi des Einsteiger-Pools kommen in Level 1 auch vor', () {
    // Vorher stand hier extremFrageLeicht, das inzwischen aus den Pools
    // genommen wurde. An seiner Stelle prüft der Test jetzt die drei
    // Spiel-Modi, die Level 1 seit der Rhythmus-Umstellung hat.
    //
    // Der Punkt ist nicht, DASS sie irgendwo vorkommen — das deckt Test 3 ab
    // — sondern dass sie schon in Level 1 vorkommen. Genau dort sollen sie
    // die langen Abfrage-Ketten aufbrechen; landeten sie durch eine
    // Pool-Umstellung erst ab Level 2, fiele das sonst niemandem auf.
    final spielModiL1 = {
      LernModus.zweiWahrheiten,
      LernModus.laenderRanking,
      LernModus.sortierSpiel,
    };
    final gefunden = <LernModus, int>{};
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        if (a.stufe != 1 || welt.id == 'welt') continue;
        for (final s in a.stationen) {
          if (spielModiL1.contains(s.modus)) {
            gefunden[s.modus] = (gefunden[s.modus] ?? 0) + 1;
          }
        }
      }
    }
    for (final m in spielModiL1) {
      // ignore: avoid_print
      print('${m.name} in Level 1: ${gefunden[m] ?? 0}x');
      expect(gefunden[m] ?? 0, greaterThan(0),
          reason: '${m.name} kommt in keinem Einsteiger-Abschnitt vor');
    }
  });

  test('4e) extremFrageLeicht verrät das Land nicht (laenderCode leer)', () async {
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          if (s.modus != LernModus.extremFrageLeicht) {
            continue;
          }
          for (final f in await FragenGenerator.generiereFragenFuerStation(s)) {
            expect(f.laenderCode, '', reason: '${f.id} verrät das Land');
          }
        }
      }
    }
  });

  test('4f) HARTE REGEL: höchstens kMaxAbfrageKette Abfrage-Stationen am Stück',
      () {
    // Diese Prüfung hat die frühere Regel "kein Modus wiederholt sich, bevor
    // nicht der ganze Pool einmal dran war" ersetzt. Die alte Regel verteilte
    // zwar gleichmäßig, sagte aber nichts über den RHYTHMUS: sie war erfüllt,
    // während zwanzig Abfrage-Stationen am Stück liefen. Das gewichtete
    // Round-Robin hat sie bewusst aufgegeben — Spiel-Modi dürfen jetzt früher
    // wiederkommen als Abfrage-Modi, das ist der ganze Zweck der Gewichtung.
    //
    // Geprüft wird deshalb der ganze Pfad am Stück und NICHT je Abschnitt:
    // genau an den Abschnitts- und Weltgrenzen entstanden die langen Ketten,
    // weil ein Abschnitt mit Abfrage endete und der nächste damit begann.
    var kette = 0;
    var laengsteKette = 0;
    var spiele = 0;
    var gesamt = 0;
    String? schlimmsteStelle;

    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          gesamt++;
          if (istSpielModus(s.modus)) {
            spiele++;
            kette = 0;
          } else {
            kette++;
            if (kette > laengsteKette) {
              laengsteKette = kette;
              schlimmsteStelle = s.id;
            }
          }
        }
      }
    }

    final anteil = spiele * 100 / gesamt;
    // ignore: avoid_print
    print('längste Abfrage-Kette: $laengsteKette (bei $schlimmsteStelle), '
        'Spiel-Anteil: ${anteil.toStringAsFixed(1)} %, '
        'Lockerungen: $lockerungenAbfrageKette');

    expect(laengsteKette, lessThanOrEqualTo(kMaxAbfrageKette),
        reason: 'Abfrage-Kette der Länge $laengsteKette bei $schlimmsteStelle');

    // Die Vierer-Regel wird gelockert, wenn unter den erlaubten Kandidaten
    // kein Spiel-Modus ist (siehe erzeugeModusSequenz). Derzeit kommt das im
    // ganzen Pfad kein einziges Mal vor. Schlüge das um, wäre die Kette oben
    // zwar weiterhin kurz, aber nur weil die Regel nachgegeben hat — deshalb
    // hier getrennt geprüft.
    expect(lockerungenAbfrageKette, 0,
        reason: 'Die Vierer-Regel musste $lockerungenAbfrageKette mal '
            'gelockert werden');

    // Untergrenze, kein Sollwert: gemessen sind es 40,2 %. Die 33 % sind ein
    // Rückfall-Wächter mit Luft nach unten — er soll anschlagen, wenn eine
    // Pool-Änderung die Spiel-Modi wieder verdrängt, und nicht bei jeder
    // Verschiebung um einen Prozentpunkt.
    expect(anteil, greaterThanOrEqualTo(33.0),
        reason: 'Spiel-Anteil auf ${anteil.toStringAsFixed(1)} % gefallen');
  });

  test('4f2) Auch die schwächste Welt hat noch genug Spiel-Modi', () {
    // Der Gesamtanteil kann eine einzelne Welt verdecken. Südamerika und
    // Ozeanien liegen durch ihre Sperrlisten am unteren Ende (je 26 %), die
    // 20 % sind auch hier Wächter und kein Sollwert.
    for (final welt in lernwelten) {
      final stationen = welt.abschnitte.expand((a) => a.stationen).toList();
      final spiele = stationen.where((s) => istSpielModus(s.modus)).length;
      final anteil = spiele * 100 / stationen.length;
      // ignore: avoid_print
      print('${welt.id}: ${anteil.toStringAsFixed(0)} % Spiel-Modi');
      expect(anteil, greaterThanOrEqualTo(20.0),
          reason: '${welt.id} hat nur ${anteil.toStringAsFixed(1)} % '
              'Spiel-Modi');
    }
  });

  test('4j) Eingabe-Varianten (flaggen/umriss/hauptstaedte) erscheinen erst, '
      'nachdem genug leichtere Varianten desselben Themas vorkamen', () {
    const vorbedingung = {
      LernModus.hauptstaedteEingabe: 1,
      LernModus.flaggenQuizEingabe: 1,
      LernModus.umrissEingabe: 1,
    };
    var gefundenGesamt = 0;
    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        final bisher = <LernModus>[];
        for (final s in a.stationen) {
          final noetig = vorbedingung[s.modus];
          if (noetig != null) {
            gefundenGesamt++;
            final thema = lernModusThema(s.modus);
            final leichtereBisher =
                bisher.where((m) => m != s.modus && lernModusThema(m) == thema).length;
            expect(leichtereBisher, greaterThanOrEqualTo(noetig),
                reason: '${a.id}: ${s.modus.name} kam nach nur $leichtereBisher '
                    'leichteren Varianten des Themas "$thema" (erwartet: >= $noetig)');
          }
          bisher.add(s.modus);
        }
      }
    }
    expect(gefundenGesamt, greaterThan(0),
        reason: 'Keine Eingabe-Variante kam im gesamten Lernpfad vor');
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

  test('4h) Die pensionierten Modi kommen in keinem Pool und keiner Station vor',
      () {
    // Hier standen vorher zwei Prüfungen zu bekanntesGebaeude: dass der Modus
    // vorkommt (4h) und dass er nicht in Level 1 steht (4i). Die erste ist
    // hinfällig, seit der Modus aus den Pools genommen wurde; die zweite war
    // damit nur noch trivial wahr.
    //
    // An ihrer Stelle die umgekehrte Aussage, die etwas taugt: Diese fünf
    // Modi sind bewusst stillgelegt. Ihre Generatoren bleiben erhalten und
    // liessen sich jederzeit wieder eintragen — aber solange sie draussen
    // sind, sollen sie es auch bleiben und nicht durch eine unbedachte
    // Pool-Änderung zurückkommen.
    //
    // extremFrage ist der Sonderfall: als Modus stillgelegt, als FUNKTION
    // aber weiter in Gebrauch — sie ist Teil der Ausweichkette im
    // Fragen-Generator. Geprüft wird deshalb der Modus, nicht die Funktion.
    const pensioniert = {
      LernModus.bipGesamt,
      LernModus.flaeche,
      LernModus.extremFrage,
      LernModus.extremFrageLeicht,
      LernModus.bekanntesGebaeude,
    };

    for (final m in pensioniert) {
      for (var level = 1; level <= 4; level++) {
        expect(modiFuerLevel(level).contains(m), false,
            reason: '${m.name} steht wieder im Pool von Level $level');
      }
    }

    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          expect(pensioniert.contains(s.modus), false,
              reason: '${s.id} nutzt den stillgelegten Modus ${s.modus.name}');
        }
      }
    }
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

  test('8) Länder-Round-Robin: Kern-Modus deckt nach genug Wiederholungen den gesamten Block ab (auch Zwergstaaten)', () async {
    SharedPreferences.setMockInitialValues({});
    // europa_3 ist seit dem Block-Umbau (Teil 1/4/6) Block C: 15 Länder,
    // inkl. aller Zwergstaaten — nicht mehr "ganz Europa" (das ist jetzt
    // erst der Wiederholungs-Abschnitt europa_4, siehe Test 19b).
    final a = abschnittById('europa_3')!;
    final station = a.stationen.firstWhere((s) =>
        s.modus == LernModus.flaggenQuizBild ||
        s.modus == LernModus.flaggenQuizMultiple);
    final vollerPool = station.laenderCodes.toSet();
    expect(vollerPool.length, 15); // Block C

    final gesehen = <String>{};
    // ceil(15/8) = 2 Züge für einen vollen Zyklus dieses Blocks.
    for (int i = 0; i < 2; i++) {
      final fragen = await FragenGenerator.generiereFragenFuerStation(station);
      gesehen.addAll(fragen.map((f) => f.laenderCode).where((c) => c.isNotEmpty));
    }

    expect(gesehen.containsAll(vollerPool), true,
        reason: 'Fehlende Länder nach 2 Zügen: ${vollerPool.difference(gesehen)}');
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
    // Nur bis zur vollen Abdeckung (ceil(15/8) = 2 Züge) — danach ist der
    // Modus pensioniert (siehe Test 18), ein weiterer Zug würde einen
    // anderen Modus liefern und die "kein Wiederholen"-Prüfung wäre nicht
    // mehr sinnvoll auf DIESEN Modus anwendbar.
    for (int zug = 0; zug < 2; zug++) {
      final vorZug = Set<String>.from(gesehen);
      final restNoch = vollerPool.difference(vorZug).length;
      final fragen = await FragenGenerator.generiereFragenFuerStation(station);
      final gezogen =
          fragen.map((f) => f.laenderCode).where((c) => c.isNotEmpty).toList();
      final wiederholungen = gezogen.where((c) => vorZug.contains(c)).toList();
      if (wiederholungen.isNotEmpty) {
        // Wiederholung ist NUR erlaubt, wenn der Rest-Pool nicht mehr
        // ausreicht, um die volle Stationsgröße an frischen Ländern zu
        // liefern (Block C hat 15 Länder / 8 pro Station geht nicht glatt
        // auf — der letzte Zug eines Zyklus füllt dann bewusst mit bereits
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

  test('12) Alle drei Eingabe-Varianten sind bereits ab Abschnitt 1 '
      '(Einsteiger) grundsätzlich verfügbar, nicht erst ab Level 2/3', () {
    final level1Modi = modiFuerLevel(1);
    for (final m in [
      LernModus.hauptstaedteEingabe,
      LernModus.flaggenQuizEingabe,
      LernModus.umrissEingabe,
    ]) {
      expect(level1Modi.contains(m), true,
          reason: '${m.name} fehlt im Level-1-Pool');
    }
  });

  test('13) Eingabe-Varianten haben ihre EIGENE Round-Robin-Abdeckung, '
      'getrennt von der Bild-/Multiple-Variante desselben Themas', () async {
    SharedPreferences.setMockInitialValues({});
    final a = abschnittById('europa_3')!;
    final multipleStation =
        a.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizMultiple);
    final eingabeStation =
        a.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizEingabe);
    final vollerPool = multipleStation.laenderCodes.toSet();

    // Multiple zuerst ziehen -> deren eigenes Tracking füllt sich.
    final ausMultiple = await FragenGenerator.generiereFragenFuerStation(multipleStation);
    final isoMultiple = ausMultiple.map((f) => f.laenderCode).toSet();

    // Eingabe zieht unabhängig davon -> darf dieselben Länder ziehen, die
    // Multiple gerade schon genutzt hat (kein gemeinsames Tracking).
    // ceil(15/8) = 2 Züge decken Block C komplett ab (danach pensioniert,
    // siehe Test 18 — mehr Züge wären hier nicht mehr aussagekräftig).
    final gesehenEingabe = <String>{};
    var ueberschneidungGefunden = false;
    for (int zug = 0; zug < 2; zug++) {
      final fragen = await FragenGenerator.generiereFragenFuerStation(eingabeStation);
      final gezogen = fragen.map((f) => f.laenderCode).toSet();
      if (gezogen.intersection(isoMultiple).isNotEmpty) ueberschneidungGefunden = true;
      gesehenEingabe.addAll(gezogen);
    }
    expect(ueberschneidungGefunden, true,
        reason: 'flaggenQuizEingabe hat nie ein von flaggenQuizMultiple '
            'bereits gezogenes Land genutzt — getrenntes Tracking sollte das '
            'aber erlauben');
    expect(gesehenEingabe.containsAll(vollerPool), true,
        reason: 'flaggenQuizEingabe deckt nach 2 eigenen Zügen nicht den '
            'vollen Pool ab: fehlend ${vollerPool.difference(gesehenEingabe)}');
  });

  test('14) Innerhalb EINER Eingabe-Variante wiederholt sich kein Land, '
      'bevor der eigene Abschnitts-Pool einmal durch ist', () async {
    SharedPreferences.setMockInitialValues({});
    final a = abschnittById('europa_3')!;
    final station =
        a.stationen.firstWhere((s) => s.modus == LernModus.umrissEingabe);
    final vollerPool = station.laenderCodes.toSet();

    final gesehen = <String>{};
    // ceil(15/8) = 2 Züge für einen vollen Zyklus von Block C — danach
    // greift Pensionierung (Test 18) und ein weiterer Zug würde einen
    // anderen Modus liefern, was diese Prüfung verfälschen würde.
    for (int zug = 0; zug < 2; zug++) {
      final vorZug = Set<String>.from(gesehen);
      final restNoch = vollerPool.difference(vorZug).length;
      final fragen = await FragenGenerator.generiereFragenFuerStation(station);
      final gezogen = fragen.map((f) => f.laenderCode).toList();
      final wiederholungen = gezogen.where((c) => vorZug.contains(c)).toList();
      if (wiederholungen.isNotEmpty) {
        expect(restNoch, lessThan(station.fragenAnzahl),
            reason: 'Zug $zug: Wiederholung $wiederholungen in umrissEingabe, '
                'obwohl noch $restNoch frische Länder übrig gewesen wären');
      }
      gesehen.addAll(gezogen);
    }
  });

  test('11) Graduelle Schwierigkeit: frühe Stationen eines Abschnitts ziehen im '
      'Schnitt leichtere Länder (Kern-Modi) als späte Stationen', () async {
    // Jedes Thema (flaggen/hauptstaedte/umriss) hat seit Teil 4 seine EIGENE
    // feste Ziehreihenfolge — daher pro Thema separat in früh/spät bucketn
    // (statt alle Kern-Modi über die absolute Stationsposition zu mischen,
    // was durch die themen-eigenen Zyklen unnötig verrauscht wäre), über
    // mehrere Abschnitte UND mehrere unabhängige Durchläufe gepoolt.
    const themen = ['flaggen', 'hauptstaedte', 'umriss'];
    const abschnittIds = ['afrika_4', 'asien_4', 'europa_4', 'welt_4'];

    final fruehWerte = <int>[];
    final spaetWerte = <int>[];

    for (int durchlauf = 0; durchlauf < 3; durchlauf++) {
      for (final id in abschnittIds) {
        SharedPreferences.setMockInitialValues({});
        final a = abschnittById(id)!;
        for (final thema in themen) {
          final stationenDiesesThemas = a.stationen
              .where((s) => lernModusThema(s.modus) == thema)
              .toList();
          final mitte = stationenDiesesThemas.length ~/ 2;

          for (int i = 0; i < stationenDiesesThemas.length; i++) {
            final s = stationenDiesesThemas[i];
            final fragen = await FragenGenerator.generiereFragenFuerStation(s);
            for (final f in fragen) {
              final schw = landByIso[f.laenderCode]?.schwierigkeit;
              if (schw == null) continue;
              (i < mitte ? fruehWerte : spaetWerte).add(schw);
            }
          }
        }
      }
    }

    final schnittFrueh = fruehWerte.reduce((a, b) => a + b) / fruehWerte.length;
    final schnittSpaet = spaetWerte.reduce((a, b) => a + b) / spaetWerte.length;

    expect(schnittSpaet, greaterThan(schnittFrueh),
        reason: 'Erwartet: spätere Stationen ziehen im Schnitt schwerere '
            'Länder als frühe. Früh: $schnittFrueh (n=${fruehWerte.length}), '
            'Spät: $schnittSpaet (n=${spaetWerte.length})');
  });

  test('15) Die feste, gewichtete Ziehreihenfolge wird nur EINMAL pro '
      'Welt/Modus berechnet und bleibt über mehrere Ziehungen hinweg '
      'unverändert (kein Neu-Würfeln pro Station)', () async {
    SharedPreferences.setMockInitialValues({});
    final a = abschnittById('europa_3')!;
    final station =
        a.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizBild);

    // Block-Kontinente scopen den Round-Robin-/Reihenfolge-Schlüssel pro
    // Abschnitt (siehe Teil 4: '${abschnittId}_${modusName}'), anders als
    // Welt, die weiterhin den reinen Modus-Namen nutzt.
    await FragenGenerator.generiereFragenFuerStation(station);
    final reihenfolge1 = await FortschrittService.ladeFesteReihenfolge(
        'europa', 'europa_3_flaggenQuizBild');
    expect(reihenfolge1, isNotNull);

    await FragenGenerator.generiereFragenFuerStation(station);
    final reihenfolge2 = await FortschrittService.ladeFesteReihenfolge(
        'europa', 'europa_3_flaggenQuizBild');

    expect(reihenfolge2, equals(reihenfolge1),
        reason: 'Die feste Reihenfolge wurde zwischen zwei Ziehungen neu '
            'berechnet, statt stabil zu bleiben');
  });

  test('16) KRITISCHER FIX: flaggenQuizBild und flaggenQuizMultiple haben '
      'VOLLSTÄNDIG UNABHÄNGIGE Round-Robin-Zyklen (weder gemeinsames '
      '"bereits gezogen"-Set noch gemeinsame feste Reihenfolge)', () async {
    SharedPreferences.setMockInitialValues({});
    final a = abschnittById('europa_3')!;
    final bildStation =
        a.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizBild);
    final multipleStation =
        a.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizMultiple);

    await FragenGenerator.generiereFragenFuerStation(bildStation);
    final reihenfolgeBild = await FortschrittService.ladeFesteReihenfolge(
        'europa', 'europa_3_flaggenQuizBild');
    final reihenfolgeMultipleVorher = await FortschrittService.ladeFesteReihenfolge(
        'europa', 'europa_3_flaggenQuizMultiple');
    expect(reihenfolgeBild, isNotNull);
    expect(reihenfolgeMultipleVorher, isNull,
        reason: 'flaggenQuizMultiple sollte noch keine eigene Reihenfolge '
            'haben, nur weil flaggenQuizBild gezogen hat');

    await FragenGenerator.generiereFragenFuerStation(multipleStation);
    final reihenfolgeMultiple = await FortschrittService.ladeFesteReihenfolge(
        'europa', 'europa_3_flaggenQuizMultiple');
    expect(reihenfolgeMultiple, isNotNull);
    expect(reihenfolgeMultiple, isNot(equals(reihenfolgeBild)),
        reason: 'flaggenQuizBild und flaggenQuizMultiple sollten getrennte, '
            'unabhängig gewürfelte Reihenfolgen haben, nicht dieselbe');
  });

  test('17) Feste Ziehreihenfolge: kein grober Rückwärts-Sprung von schwer '
      'zu leicht mittendrin (gleitender Schnitt steigt tendenziell an)', () async {
    // Prüft die tatsächlich gespeicherte feste Reihenfolge direkt (nicht nur
    // die Stations-Mittelwerte aus Test 11), aggregiert über mehrere
    // Abschnitte hinweg (ein einzelner Abschnitt mit z.B. nur 45-50
    // Ländern ist für eine Fünftel-Aufteilung zu klein, um bei einem
    // probabilistischen Verfahren rauschfrei zu sein — daher wie Test 11
    // über mehrere große Abschnitte gemittelt statt einzeln bewertet).
    const abschnittIds = ['afrika_4', 'asien_4', 'europa_4', 'welt_4'];
    final ersteFuenftelWerte = <int>[];
    final letzteFuenftelWerte = <int>[];

    for (final id in abschnittIds) {
      SharedPreferences.setMockInitialValues({});
      final a = abschnittById(id)!;
      final station =
          a.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizBild);
      final (welt, _, _) = stationKontext(station.id)!;
      // Block-Kontinente scopen den Schlüssel pro Abschnitt (Teil 4), Welt
      // nutzt weiterhin den reinen Modus-Namen (Teil 3, unverändert).
      final key = welt.id == 'welt' ? 'flaggenQuizBild' : '${id}_flaggenQuizBild';
      await FragenGenerator.generiereFragenFuerStation(station);
      final feste = await FortschrittService.ladeFesteReihenfolge(welt.id, key);
      if (feste == null || feste.length < 10) continue;

      final fuenftel = (feste.length / 5).ceil();
      final erstesFuenftel = feste.sublist(0, fuenftel.clamp(0, feste.length));
      final letztesFuenftel =
          feste.sublist((feste.length - fuenftel).clamp(0, feste.length));

      ersteFuenftelWerte.addAll(erstesFuenftel
          .map((iso) => landByIso[iso]?.schwierigkeit)
          .whereType<int>());
      letzteFuenftelWerte.addAll(letztesFuenftel
          .map((iso) => landByIso[iso]?.schwierigkeit)
          .whereType<int>());
    }

    final schnittErste =
        ersteFuenftelWerte.reduce((a, b) => a + b) / ersteFuenftelWerte.length;
    final schnittLetzte =
        letzteFuenftelWerte.reduce((a, b) => a + b) / letzteFuenftelWerte.length;

    expect(schnittLetzte, greaterThan(schnittErste),
        reason: 'Erstes Fünftel der festen Reihenfolge (Schnitt $schnittErste) '
            'sollte im Aggregat leichter sein als das letzte Fünftel '
            '(Schnitt $schnittLetzte)');
  });

  test('18) Pensionierung: sobald ein Modus den ganzen Block-Pool gezogen '
      'hat, weicht generiereFragenFuerStation auf einen anderen Modus aus', () async {
    SharedPreferences.setMockInitialValues({});
    final a = abschnittById('europa_3')!; // Block C: 15 Länder
    final station =
        a.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizBild);
    final vollerPool = station.laenderCodes.toSet();

    // 2 Züge (ceil(15/8)) decken Block C in flaggenQuizBild ab ->
    // danach ist der Modus für DIESEN Abschnitt pensioniert.
    for (int i = 0; i < 2; i++) {
      final fragen = await FragenGenerator.generiereFragenFuerStation(station);
      for (final f in fragen) {
        expect(f.modus, LernModus.flaggenQuizBild,
            reason: 'Zug ${i + 1}: sollte noch nicht pensioniert sein');
      }
    }

    // 3. Zug: flaggenQuizBild ist jetzt pensioniert -> Ersatz-Modus.
    final fragenNachPensionierung =
        await FragenGenerator.generiereFragenFuerStation(station);
    expect(fragenNachPensionierung, isNotEmpty,
        reason: 'Pensionierter Modus darf nicht zu 0 Fragen führen (kein Crash)');
    for (final f in fragenNachPensionierung) {
      expect(f.modus, isNot(LernModus.flaggenQuizBild),
          reason: '3. Zug sollte NICHT mehr flaggenQuizBild sein '
              '(pensioniert), sondern ein Ersatz-Modus');
    }
    // ignore: avoid_print
    print('Ersatz-Modus nach Pensionierung: ${fragenNachPensionierung.first.modus.name}');

    // vollerPool wurde tatsächlich komplett abgedeckt, bevor pensioniert wurde.
    final bereits = await FortschrittService.rrBereitsAbgefragt(
        'europa', 'europa_3_flaggenQuizBild');
    expect(bereits.containsAll(vollerPool), true,
        reason: 'Pensionierung griff, bevor wirklich alle Länder gezogen wurden');
  });

  test('19) Block-Kontinente (Teil 1/4/6): die drei Blöcke sind disjunkt, '
      'und der Round-Robin-Tracker wird an JEDER Block-Grenze '
      '(Abschnittswechsel) zurückgesetzt statt weltweit weiterzulaufen', () async {
    SharedPreferences.setMockInitialValues({});
    final a1 = abschnittById('europa_1')!;
    final a2 = abschnittById('europa_2')!;
    final a3 = abschnittById('europa_3')!;
    final blockA = a1.stationen.first.laenderCodes.toSet();
    final blockB = a2.stationen.first.laenderCodes.toSet();
    final blockC = a3.stationen.first.laenderCodes.toSet();

    expect(blockA.intersection(blockB), isEmpty, reason: 'Block A/B überlappen');
    expect(blockA.intersection(blockC), isEmpty, reason: 'Block A/C überlappen');
    expect(blockB.intersection(blockC), isEmpty, reason: 'Block B/C überlappen');
    expect(blockA.length + blockB.length + blockC.length, 46,
        reason: 'Die drei Blöcke müssen zusammen alle 46 Länder ergeben');

    final stationA1 =
        a1.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizBild);
    final stationA2 =
        a2.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizBild);

    await FragenGenerator.generiereFragenFuerStation(stationA1);

    // Abschnitt 2 hat einen komplett EIGENEN Schlüssel (Block-Grenze =
    // Reset) -> darf durch Abschnitt 1 nicht vorbelegt sein.
    final bereitsA2VorZug = await FortschrittService.rrBereitsAbgefragt(
        'europa', 'europa_2_flaggenQuizBild');
    expect(bereitsA2VorZug, isEmpty,
        reason: 'Abschnitt 2 sollte durch Abschnitt 1 nicht vorbelegt sein '
            '(Block-Grenze = Reset, siehe Teil 4)');

    // Und weil die Pools disjunkt sind, darf Abschnitt 2 sowieso nie ein
    // Land aus Block A ziehen.
    final fragenA2 = await FragenGenerator.generiereFragenFuerStation(stationA2);
    for (final f in fragenA2) {
      expect(blockA.contains(f.laenderCode), false,
          reason: '${f.id}: Block-Abschnitt 2 hat ein Land aus Block A '
              'gezogen (${f.laenderCode}) — Blöcke sind isoliert (Teil 1)');
    }
  });

  test('19b) Welt (Teil 3, unverändert): der Round-Robin-Tracker läuft '
      'weiterhin weltweit-kontinuierlich über Abschnittsgrenzen hinweg, '
      'OHNE Reset', () async {
    SharedPreferences.setMockInitialValues({});
    final a1 = abschnittById('welt_1')!;
    final a2 = abschnittById('welt_2')!; // Superset von welt_1
    final stationA1 =
        a1.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizBild);
    final stationA2 =
        a2.stationen.firstWhere((s) => s.modus == LernModus.flaggenQuizBild);
    final poolA1 = stationA1.laenderCodes.toSet();
    final poolA2 = stationA2.laenderCodes.toSet();
    expect(poolA1.difference(poolA2), isEmpty,
        reason: 'welt_2 sollte ein Superset von welt_1 sein');

    final fragenA1 = await FragenGenerator.generiereFragenFuerStation(stationA1);
    final gezogenA1 = fragenA1.map((f) => f.laenderCode).toSet();
    expect(gezogenA1.length, stationA1.fragenAnzahl);

    // Kein Reset -> Abschnitt 2 sieht direkt die von Abschnitt 1 bereits
    // gezogenen Länder im selben, welt-weiten Tracker.
    final bereitsVorA2 =
        await FortschrittService.rrBereitsAbgefragt('welt', 'flaggenQuizBild');
    expect(bereitsVorA2.containsAll(gezogenA1), true,
        reason: 'Welt sollte KEINEN Reset an der Abschnittsgrenze haben '
            '(Teil 3: weiterhin weltweit-kontinuierlicher Tracker)');

    final neueLaenderA2 = poolA2.difference(poolA1);
    final nochOffenAusA1 = poolA1.difference(gezogenA1);
    final neuKandidatenGesamt = nochOffenAusA1.length + neueLaenderA2.length;
    if (neuKandidatenGesamt >= stationA2.fragenAnzahl) {
      final fragenA2 = await FragenGenerator.generiereFragenFuerStation(stationA2);
      final wiederholungenAusA1 =
          fragenA2.map((f) => f.laenderCode).toSet().intersection(gezogenA1);
      expect(wiederholungenAusA1, isEmpty,
          reason: 'Bei genug frischen Kandidaten dürfte welt_2 keine '
              'Wiederholung aus welt_1 ziehen — Tracking scheint '
              'zurückgesetzt worden zu sein');
    }
  });

  test('20) Pensionierung ist PRO WELT (und PRO ABSCHNITT) unabhängig: '
      'Südamerika Block A (6 Länder, 6 Fragen/Station, pensioniert sofort) '
      'beeinflusst Europa nicht', () async {
    SharedPreferences.setMockInitialValues({});
    final suedamAbschnitt = abschnittById('suedamerika_1')!;
    final suedamStation = suedamAbschnitt.stationen
        .firstWhere((s) => s.modus == LernModus.flaggenQuizBild);

    // ceil(6/6) = 1 Zug reicht, um Südamerika Block A (6 Länder, 6 Fragen
    // pro Station) in flaggenQuizBild komplett zu pensionieren.
    await FragenGenerator.generiereFragenFuerStation(suedamStation);
    final suedamBereits = await FortschrittService.rrBereitsAbgefragt(
        'suedamerika', 'suedamerika_1_flaggenQuizBild');
    expect(suedamBereits.containsAll(suedamStation.laenderCodes.toSet()), true,
        reason: 'Südamerika Block A sollte nach 1 Zug komplett abgedeckt sein');

    // Europas eigener Tracker für denselben Modus darf davon NICHT betroffen sein.
    final europaBereits = await FortschrittService.rrBereitsAbgefragt(
        'europa', 'europa_1_flaggenQuizBild');
    expect(europaBereits, isEmpty,
        reason: 'Europas flaggenQuizBild-Tracker sollte von Südamerikas '
            'Zügen komplett unberührt sein (getrennt pro Welt UND Abschnitt)');

    final europaAbschnitt = abschnittById('europa_1')!;
    final europaStation = europaAbschnitt.stationen
        .firstWhere((s) => s.modus == LernModus.flaggenQuizBild);
    final fragenEuropa =
        await FragenGenerator.generiereFragenFuerStation(europaStation);
    for (final f in fragenEuropa) {
      expect(f.modus, LernModus.flaggenQuizBild,
          reason: 'Europa sollte trotz Südamerikas Pensionierung ganz normal '
              'flaggenQuizBild liefern');
    }
  });

  test('5) Fragen-Generierung crasht nie, liefert genug und nie doppelt',
      () async {
    // Vorher wurde hier exakt s.fragenAnzahl verlangt. Das ist zu streng:
    // die Modi in kOhneWiederholung dürfen innerhalb einer Station keine
    // Frage zweimal bringen, und in einem dünnen Länderblock geht ihnen der
    // Stoff aus. Sie brechen dann sauber ab, statt zu wiederholen — richtig
    // so, aber eben eine Frage weniger.
    //
    // Betroffen sind derzeit drei von 594 Stationen, alle in nordamerika_3
    // ("Die kleinen Karibikstaaten", der dünnste Block im Pfad):
    // nordamerika_3_01 und _18 (laenderRanking) sowie _14 (zweiWahrheiten),
    // je 7 statt 8 Fragen.
    //
    // Die Untergrenze existiert, damit aus "eine Frage weniger" nicht
    // unbemerkt "die halbe Station fehlt" wird. Fünf Fragen sind noch eine
    // Station; bei vier wäre etwas kaputt und niemand hätte es gemerkt.
    const kMindestFragen = 5;

    for (final welt in lernwelten) {
      for (final a in welt.abschnitte) {
        for (final s in a.stationen) {
          final fragen = await FragenGenerator.generiereFragenFuerStation(s);

          // Stationen mit eigener Obergrenze (sortierSpiel plant nur 3, siehe
          // kFragenObergrenze) dürfen nicht an der 5 scheitern — für sie gilt
          // ihre eigene Vorgabe als Untergrenze.
          final untergrenze =
              s.fragenAnzahl < kMindestFragen ? s.fragenAnzahl : kMindestFragen;

          expect(fragen.length, greaterThanOrEqualTo(untergrenze),
              reason: '${s.id} (${s.modus.name}) liefert nur ${fragen.length} '
                  'von ${s.fragenAnzahl} Fragen');
          expect(fragen.length, lessThanOrEqualTo(s.fragenAnzahl),
              reason: '${s.id} (${s.modus.name}) liefert ${fragen.length} '
                  'Fragen, geplant waren ${s.fragenAnzahl}');

          // Die eigentliche Zusicherung hinter der gelockerten Anzahl: lieber
          // eine Frage weniger als eine doppelt. Geprüft wird die ID, nicht
          // der Fragetext — Modi wie flaggenQuizBild stellen bei jeder Frage
          // dieselbe Frage zu einer anderen Flagge, doppelter TEXT ist dort
          // also normal und kein Fehler.
          final ids = fragen.map((f) => f.id).toList();
          expect(ids.toSet().length, ids.length,
              reason: '${s.id} (${s.modus.name}) hat doppelte Fragen');
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
