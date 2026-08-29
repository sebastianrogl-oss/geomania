import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:geomania/services/challenge_ergebnis_service.dart';
import 'package:geomania/services/challenge_rekord_service.dart';
import 'package:geomania/services/daily_challenge.dart';
import 'package:geomania/services/daily_resume_service.dart';
import 'package:geomania/services/portfolio_service.dart';

/// Der Debug-Knopf "Tages-Challenges zurücksetzen" greift in gespeicherte
/// Spieldaten ein. Dieser Test hält fest, WAS er anfasst und was nicht —
/// beides ist gleich wichtig: Wer ihn versehentlich auf Rekorde oder Serien
/// ausweitet, zerstört damit echte Spielhistorie.
///
/// Nachgestellt wird der Knopf hier Schritt für Schritt, weil er im
/// Einstellungs-Screen sitzt und dort nur eine Aneinanderreihung dieser
/// Dienst-Aufrufe ist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ids = ['preis', 'higher_lower', 'ranking_game', 'portfolio'];

  Future<void> knopfDruecken() async {
    await DailyChallenge.debugHeuteLeeren();
    for (final id in ids) {
      await ChallengeRekordService.debugHeutigePunkteLoeschen(id);
      await ChallengeErgebnisService.debugLoeschen(id);
      await DailyResumeService.debugLoeschen(id);
    }
    await PortfolioService.debugHeuteZuruecksetzen();
  }

  /// Einen vollständig gespielten Tag herstellen.
  Future<void> tagSpielen() async {
    for (final id in ['preis', 'higher_lower', 'ranking_game']) {
      await DailyChallenge.markDone(id);
      await ChallengeRekordService.speichereHeutigePunkte(id, 250);
      await ChallengeRekordService.setzeFallsBesser(id, 250);
      await ChallengeErgebnisService.speichern(id, {'egal': 1});
      await DailyResumeService.speichern(id, {'idx': 2});
    }
    await PortfolioService.schliesseTagAb(
      neuesKapital: 1500,
      gewichtetesRisiko: 1,
      effektiveLaenderzahl: 3,
      newsTrefferAnzahl: 1,
      trendTrefferAnzahl: 1,
      anzahlLaender: 5,
    );
  }

  test('Der heutige Tag ist danach wieder spielbar', () async {
    SharedPreferences.setMockInitialValues({});
    await tagSpielen();

    expect((await DailyChallenge.completedToday()).length, 4,
        reason: 'Vorbedingung: alle vier gelten als erledigt');

    await knopfDruecken();

    expect(await DailyChallenge.completedToday(), isEmpty,
        reason: 'Die Erledigt-Marken müssen weg sein');
    for (final id in ids) {
      expect(await ChallengeRekordService.getHeutigePunkte(id), isNull,
          reason: '$id: heutige Punkte müssen weg sein');
      expect(await ChallengeErgebnisService.laden(id), isNull,
          reason: '$id: das gespeicherte Ergebnis muss weg sein');
      expect(await DailyResumeService.laden(id), isNull,
          reason: '$id: ein Zwischenstand muss weg sein');
    }

    final status = await PortfolioService.ladeStatus();
    expect(status.heuteGespielt, isFalse);
    expect(status.kapital, PortfolioService.kStartKapital,
        reason: 'Das Kapital muss auf dem Stand vor dem heutigen Tag liegen');
  });

  test('Rekorde und Serien bleiben stehen', () async {
    SharedPreferences.setMockInitialValues({});
    await tagSpielen();
    await knopfDruecken();

    for (final id in ['preis', 'higher_lower', 'ranking_game']) {
      expect(await ChallengeRekordService.getRekord(id), 250,
          reason: '$id: der Rekord gehört nicht zum heutigen Tag');
      expect(await ChallengeRekordService.getStreak(id), greaterThan(0),
          reason: '$id: die Serie gehört nicht zum heutigen Tag');
      expect(await ChallengeRekordService.getAnzahlGespielt(id), greaterThan(0),
          reason: '$id: der Spielzähler gehört nicht zum heutigen Tag');
    }
  });

  test('Zweimal drücken schadet nicht', () async {
    SharedPreferences.setMockInitialValues({});
    await tagSpielen();
    await knopfDruecken();
    final kapital = (await PortfolioService.ladeStatus()).kapital;
    await knopfDruecken();

    // Der zweite Druck darf das Kapital NICHT weiter zurückdrehen — sonst
    // fräse sich jeder weitere Druck durch den Verlauf.
    expect((await PortfolioService.ladeStatus()).kapital, kapital);
  });
}
