import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/services/streak_ziel_service.dart';

/// Wann gilt ein Streak-Ziel als erreicht — und vor allem: wann NICHT MEHR.
///
/// Der zweite Teil ist der wichtigere. Ein Ziel bleibt erreicht, sobald es
/// erreicht ist; ohne Gedächtnis käme die Feier ab dann jeden einzelnen Tag
/// wieder und würde aus einem Moment eine Belästigung.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Erreicht oder nicht', () {
    test('ohne gesetztes Ziel passiert nichts', () async {
      expect(await StreakZielService.zielGeradeErreicht(99), isNull);
    });

    test('unter dem Ziel passiert nichts', () async {
      await StreakZielService.setzeZiel(14);
      expect(await StreakZielService.zielGeradeErreicht(13), isNull);
    });

    test('genau auf dem Ziel zählt', () async {
      await StreakZielService.setzeZiel(14);
      expect(await StreakZielService.zielGeradeErreicht(14), 14);
    });

    test('darüber zählt auch', () async {
      // Wer sein 7-Tage-Ziel gesetzt hat und erst bei 9 wieder eine Station
      // abschliesst, hat es trotzdem geschafft. Ein Vergleich auf Gleichheit
      // würde diesen Spieler stillschweigend übergehen.
      await StreakZielService.setzeZiel(7);
      expect(await StreakZielService.zielGeradeErreicht(9), 7);
    });
  });

  group('Nur einmal feiern', () {
    test('nach dem Feiern kommt es nicht wieder', () async {
      await StreakZielService.setzeZiel(7);
      final ersteMal = await StreakZielService.zielGeradeErreicht(7);
      expect(ersteMal, 7);

      await StreakZielService.merkeZielGefeiert(ersteMal!);

      // Tag 8, Tag 9, Tag 40 — alles kein Anlass mehr.
      expect(await StreakZielService.zielGeradeErreicht(8), isNull);
      expect(await StreakZielService.zielGeradeErreicht(40), isNull);
    });

    test('ein neues, höheres Ziel wird wieder gefeiert', () async {
      await StreakZielService.setzeZiel(7);
      await StreakZielService.merkeZielGefeiert(7);

      // Der Spieler nimmt sich in der Feier 30 Tage vor.
      await StreakZielService.setzeZiel(30);

      expect(await StreakZielService.zielGeradeErreicht(20), isNull);
      expect(await StreakZielService.zielGeradeErreicht(30), 30);
    });

    test('Zurücksetzen vergisst auch das Gefeierte', () async {
      await StreakZielService.setzeZiel(7);
      await StreakZielService.merkeZielGefeiert(7);
      await StreakZielService.zuruecksetzen();

      expect(await StreakZielService.gefeiertesZiel(), isNull);
      expect(await StreakZielService.ziel(), isNull);
    });
  });

  group('Die Anschlussziele', () {
    test('nur echte Steigerungen, höchstens drei', () {
      expect(StreakZielService.naechsteZiele(7), [14, 30, 60]);
      expect(StreakZielService.naechsteZiele(30), [60, 100, 180]);
    });

    test('am oberen Ende gibt es nichts mehr', () {
      // Kein ausgedachtes Ziel über 365 — dort bleibt es bei der Feier.
      expect(StreakZielService.naechsteZiele(365), isEmpty);
    });

    test('jedes Angebot liegt wirklich über dem Erreichten', () {
      for (final erreicht in StreakZielService.zielLeiter) {
        for (final angebot in StreakZielService.naechsteZiele(erreicht)) {
          expect(angebot, greaterThan(erreicht));
        }
      }
    });

    test('die Erstauswahl ist der Anfang der Leiter', () {
      // Sonst könnte jemand ein Ziel wählen, das gar nicht auf der Leiter
      // steht — die Anschlussfrage fände dann keine passende Sprosse.
      expect(
        StreakZielService.zielLeiter
            .take(StreakZielService.zielTage.length)
            .toList(),
        StreakZielService.zielTage,
      );
    });
  });
}
