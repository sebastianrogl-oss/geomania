import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/services/daily_challenge.dart';
import 'package:geomania/services/fortschritt_service.dart';

/// Der App-Streak zählt jede Aktivität, nicht nur den Lernpfad.
///
/// Die Flamme steht für "heute gespielt". Wer nur eine Tages-Challenge macht,
/// hat den Tag genauso bespielt — bekam bis zu diesem Fix aber keinen
/// Streak-Tag, weil der App-Streak ausschliesslich am Stationsabschluss hing.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<int> streak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('lp_streak') ?? 0;
  }

  /// Setzt die letzte Aktivität auf einen Tag in der Vergangenheit, damit
  /// sich ein neuer Tag simulieren lässt.
  Future<void> letzteAktivitaetVor(int tage, {int streakStand = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lp_streak', streakStand);
    await prefs.setString('lp_letzte_akt',
        DateTime.now().subtract(Duration(days: tage)).toIso8601String());
  }

  test('Eine Challenge an einem neuen Tag erhöht den Streak um 1', () async {
    await letzteAktivitaetVor(1, streakStand: 4);
    await DailyChallenge.markDone('preis');
    expect(await streak(), 5);
  });

  test('Die allererste Challenge startet den Streak bei 1', () async {
    expect(await streak(), 0);
    await DailyChallenge.markDone('preis');
    expect(await streak(), 1);
  });

  test('Station UND Challenge am selben Tag zählen nur einmal', () async {
    // Der Kernfall. Die Tageslogik steckt in streakAktualisieren selbst
    // (`if (diff == 0) return`) — nachgebaut wird sie nirgends, sonst liefen
    // die beiden Wege irgendwann auseinander.
    await letzteAktivitaetVor(1, streakStand: 7);

    await FortschrittService.streakAktualisieren(); // Stationsabschluss
    expect(await streak(), 8);

    await DailyChallenge.markDone('higher_lower'); // gleicher Tag
    expect(await streak(), 8, reason: 'Der Tag wurde doppelt gezählt');
  });

  test('Mehrere Challenges am selben Tag zählen ebenfalls nur einmal',
      () async {
    await letzteAktivitaetVor(1, streakStand: 2);
    for (final id in ['preis', 'higher_lower', 'ranking_game', 'portfolio']) {
      await DailyChallenge.markDone(id);
    }
    expect(await streak(), 3);
  });

  test('Nach einer Lücke fängt der Streak wieder bei 1 an', () async {
    await letzteAktivitaetVor(3, streakStand: 12);
    await DailyChallenge.markDone('portfolio');
    expect(await streak(), 1,
        reason: 'Drei Tage Pause reissen die Serie — auch über eine '
            'Challenge');
  });

  test('Alle vier Challenges gehen denselben Weg', () async {
    // markDone ist der einzige Aufrufpunkt für alle vier. Käme eine davon
    // auf einem eigenen Weg an, fehlte ihr der Streak-Tag.
    for (final id in ['preis', 'higher_lower', 'ranking_game', 'portfolio']) {
      SharedPreferences.setMockInitialValues({});
      await letzteAktivitaetVor(1, streakStand: 1);
      await DailyChallenge.markDone(id);
      expect(await streak(), 2, reason: '$id hat den Streak nicht erhöht');
    }
  });

  test('Der Serien-Zähler der Challenge bleibt davon getrennt', () async {
    // streak_<id> und lp_streak sind zwei verschiedene Werte mit zwei
    // verschiedenen Bedeutungen.
    await letzteAktivitaetVor(1, streakStand: 5);
    await DailyChallenge.markDone('preis');

    final prefs = await SharedPreferences.getInstance();
    expect(await streak(), 6, reason: 'App-Streak');
    expect(prefs.getInt('streak_preis'), 1,
        reason: 'Der eigene Zähler der Challenge fängt unabhängig an');
  });
}
