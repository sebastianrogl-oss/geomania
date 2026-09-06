import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/services/daily_challenge.dart';
import 'package:geomania/services/fortschritt_service.dart';
import 'package:geomania/widgets/challenge_fertig_button.dart';

/// Die Streak-Feier nach einer Tages-Challenge.
///
/// ══ WARUM ES DIESEN TEST GIBT ═══════════════════════════════════════════════
///
/// Seit Build 18 zählt [DailyChallenge.markDone] den Streak-Tag mit. Die Feier
/// blieb trotzdem dem Lernpfad vorbehalten — wer nur Challenges spielte, sah
/// seine Flamme wachsen, ohne je den Moment dazu zu bekommen.
///
/// Der Weg dahin hat zwei Enden, und beide müssen stimmen: markDone vermerkt,
/// dass gefeiert werden soll (es hat keinen BuildContext), und der
/// [ChallengeFertigButton] holt es beim Verlassen der Ergebnis-Ansicht nach.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Setzt die letzte Aktivität auf einen Tag in der Vergangenheit, damit sich
  /// ein neuer Tag simulieren lässt.
  Future<void> letzteAktivitaetVor(int tage, {int streakStand = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lp_streak', streakStand);
    await prefs.setString('lp_letzte_akt',
        DateTime.now().subtract(Duration(days: tage)).toIso8601String());
  }

  group('Der Vermerk', () {
    test('Eine Challenge an einem neuen Tag hinterlässt eine Feier', () async {
      await letzteAktivitaetVor(1, streakStand: 4);
      await DailyChallenge.markDone('preis');
      expect(await DailyChallenge.offeneStreakFeier(), (4, 5));
    });

    test('Station UND Challenge am selben Tag ergeben EINE Feier', () async {
      // Der Kernfall. Die Station feiert sofort (streakErhoehenUndFeiern) und
      // hinterlässt nichts; die Challenge findet danach denselben Tag vor,
      // erhöht nichts mehr und vermerkt deshalb auch nichts.
      await letzteAktivitaetVor(1, streakStand: 7);

      final (alt, neu) = await FortschrittService.streakAktualisieren();
      expect((alt, neu), (7, 8), reason: 'Der Stationsabschluss');
      expect(await DailyChallenge.offeneStreakFeier(), isNull,
          reason: 'Der Lernpfad feiert sofort und vermerkt nichts');

      await DailyChallenge.markDone('higher_lower');
      expect(await DailyChallenge.offeneStreakFeier(), isNull,
          reason: 'Zweite Feier am selben Tag');
    });

    test('Vier Challenges an einem Tag ergeben ebenfalls EINE Feier', () async {
      await letzteAktivitaetVor(1, streakStand: 2);
      for (final id in ['preis', 'higher_lower', 'ranking_game', 'portfolio']) {
        await DailyChallenge.markDone(id);
      }
      expect(await DailyChallenge.offeneStreakFeier(), (2, 3));
      expect(await DailyChallenge.offeneStreakFeier(), isNull,
          reason: 'Der Vermerk wird beim Lesen gestrichen');
    });

    test('Alle vier Challenges hinterlassen ihn', () async {
      for (final id in ['preis', 'higher_lower', 'ranking_game', 'portfolio']) {
        SharedPreferences.setMockInitialValues({});
        await letzteAktivitaetVor(1, streakStand: 1);
        await DailyChallenge.markDone(id);
        expect(await DailyChallenge.offeneStreakFeier(), (1, 2),
            reason: '$id hinterlässt keine Feier');
      }
    });

    test('Ein Vermerk von gestern verfällt', () async {
      // Wer die App zwischen Abschluss und "Fertig" schliesst, soll die Feier
      // nicht irgendwann nächste Woche bekommen.
      final gestern = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'dc_streak_feier_offen':
            'daily_${gestern.year}_${gestern.month.toString().padLeft(2, '0')}'
                '_${gestern.day.toString().padLeft(2, '0')}|4|5',
      });
      expect(await DailyChallenge.offeneStreakFeier(), isNull);
    });

    test('Ohne Streak-Anstieg steht nichts offen', () async {
      // Zweiter Abschluss am selben Tag.
      await letzteAktivitaetVor(0, streakStand: 3);
      await DailyChallenge.markDone('preis');
      expect(await DailyChallenge.offeneStreakFeier(), isNull);
    });
  });

  group('Der Fertig-Knopf holt sie nach', () {
    /// Baut den Knopf über einer echten Route — die Feier schiebt sich als
    /// Route darüber und beendet sich mit einem Navigator.pop().
    Future<void> tippen(WidgetTester tester, {VoidCallback? onTap}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: ChallengeFertigButton(onTap: onTap)),
        ),
      ));
      await tester.tap(find.text('Fertig'));
      // In Schritten statt in einem Sprung: Die Feier besteht aus mehreren
      // Future.delayed nacheinander, und ihre Lottie-Flamme läuft endlos —
      // pumpAndSettle liefe hier in sein Zeitlimit.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    testWidgets('Steht eine Feier offen, erscheint sie', (tester) async {
      await letzteAktivitaetVor(1, streakStand: 4);
      await DailyChallenge.markDone('preis');

      var weiter = false;
      await tippen(tester, onTap: () => weiter = true);

      expect(find.text('Tippen für weiter'), findsOneWidget,
          reason: 'Die Feier kommt nach der Challenge nicht');
      expect(weiter, isFalse,
          reason: 'Erst die Feier, dann zurück zum Panel — nicht andersherum');
    });

    testWidgets('Ohne offene Feier geht es sofort weiter', (tester) async {
      var weiter = false;
      await tippen(tester, onTap: () => weiter = true);

      expect(find.text('Tippen für weiter'), findsNothing);
      expect(weiter, isTrue);
    });
  });
}
