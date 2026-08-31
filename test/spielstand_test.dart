import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/services/spielstand.dart';

/// Die Zusammenführ-Regeln — das Stück, bei dem ein Fehler Spielfortschritt
/// kostet. Deshalb hier zuerst geprüft, lange bevor Firestore ins Spiel kommt:
/// Die Funktion ist rein, sie braucht weder Netz noch Uhr noch Prefs.
void main() {
  group('Ein leerer Stand kann nichts löschen', () {
    // Der wichtigste Fall überhaupt: das erste Anmelden nach einem Update.
    // Lokal liegt ein voller Spielstand, in der Cloud noch gar nichts.
    final voll = <String, dynamic>{
      'lp_s_done_europa_1_01': true,
      'lp_gesamt_richtig': 128,
      'abzeichen_freigeschaltet': ['streak_3', 'streak_7'],
      'lp_streak': 12,
      'lp_letzte_akt': '2026-08-30T10:00:00.000',
      'pf_kapital': 1450.0,
      'pf_letzter_spieltag': '2026-08-30',
    };

    test('Gerät voll, Cloud leer', () {
      final raus = spielstandZusammenfuehren(voll, {});
      expect(raus['lp_s_done_europa_1_01'], true);
      expect(raus['lp_gesamt_richtig'], 128);
      expect(raus['abzeichen_freigeschaltet'], ['streak_3', 'streak_7']);
      expect(raus['lp_streak'], 12);
      expect(raus['pf_kapital'], 1450.0);
    });

    test('Cloud voll, Gerät leer — dieselbe Antwort', () {
      final raus = spielstandZusammenfuehren({}, voll);
      expect(raus['lp_s_done_europa_1_01'], true);
      expect(raus['lp_gesamt_richtig'], 128);
      expect(raus['lp_streak'], 12);
      expect(raus['pf_kapital'], 1450.0);
    });

    test('Zwei leere Stände ergeben einen leeren Stand', () {
      final raus = spielstandZusammenfuehren({}, {});
      expect(raus.keys, ['version']);
    });
  });

  group('ODER: Fortschritt geht nie zurück', () {
    test('true auf einer Seite genügt', () {
      final raus = spielstandZusammenfuehren(
        {'lp_s_done_a': true, 'lp_w_frei_europa': false},
        {'lp_s_done_a': false, 'lp_w_frei_europa': true},
      );
      expect(raus['lp_s_done_a'], true);
      expect(raus['lp_w_frei_europa'], true);
    });

    test('false bleibt false, wenn beide false sind', () {
      final raus = spielstandZusammenfuehren(
        {'lp_a_done_europa_1': false},
        {'lp_a_done_europa_1': false},
      );
      expect(raus['lp_a_done_europa_1'], false);
    });

    test('gilt auch für Onboarding und Profilbilder', () {
      final raus = spielstandZusammenfuehren(
        {'onboarding_willkommen': true},
        {'profilbild_freigeschaltet_x': true},
      );
      expect(raus['onboarding_willkommen'], true);
      expect(raus['profilbild_freigeschaltet_x'], true);
    });
  });

  group('MAXIMUM: Zähler und Rekorde', () {
    test('die grössere Zahl gewinnt, in beide Richtungen', () {
      expect(
          spielstandZusammenfuehren(
              {'lp_gesamt_richtig': 300}, {'lp_gesamt_richtig': 128})['lp_gesamt_richtig'],
          300);
      expect(
          spielstandZusammenfuehren(
              {'lp_gesamt_richtig': 128}, {'lp_gesamt_richtig': 300})['lp_gesamt_richtig'],
          300);
    });

    test('Kommazahlen ebenso', () {
      final raus = spielstandZusammenfuehren(
        {'summePunkte_preis': 1234.5},
        {'summePunkte_preis': 999.0},
      );
      expect(raus['summePunkte_preis'], 1234.5);
    });

    test('Datums-Text: der spätere gewinnt', () {
      final raus = spielstandZusammenfuehren(
        {'letzterSpieltag_preis': '2026-08-30'},
        {'letzterSpieltag_preis': '2026-08-12'},
      );
      expect(raus['letzterSpieltag_preis'], '2026-08-30');
    });

    test('fehlt eine Seite, gewinnt die vorhandene', () {
      expect(
          spielstandZusammenfuehren({}, {'ch_rekord_preis': 42})['ch_rekord_preis'], 42);
    });
  });

  group('VEREINIGUNG: Listen wachsen nur', () {
    test('beide Seiten kommen zusammen, ohne Duplikate', () {
      final raus = spielstandZusammenfuehren(
        {'abzeichen_freigeschaltet': ['a', 'b']},
        {'abzeichen_freigeschaltet': ['b', 'c']},
      );
      expect(raus['abzeichen_freigeschaltet'], ['a', 'b', 'c']);
    });

    test('gilt auch für Spieltage und heutige Challenges', () {
      final raus = spielstandZusammenfuehren(
        {'spieltage_preis': ['2026-08-29'], 'daily_2026_08_30': ['preis']},
        {'spieltage_preis': ['2026-08-30'], 'daily_2026_08_30': ['ranking_game']},
      );
      expect(raus['spieltage_preis'], ['2026-08-29', '2026-08-30']);
      expect(raus['daily_2026_08_30'], ['preis', 'ranking_game']);
    });
  });

  group('SERIE: der jüngere Tag zählt, nicht die grössere Zahl', () {
    // Die Serie ist der einzige Zähler, der auch reissen kann. Ein altes
    // Gerät mit Serie 40 darf ein aktuelles mit Serie 3 nicht überschreiben.
    test('jüngere Aktivität gewinnt, auch mit kleinerer Serie', () {
      final raus = spielstandZusammenfuehren(
        {'lp_streak': 40, 'lp_letzte_akt': '2026-06-01T10:00:00.000'},
        {'lp_streak': 3, 'lp_letzte_akt': '2026-08-30T10:00:00.000'},
      );
      expect(raus['lp_streak'], 3);
      expect(raus['lp_letzte_akt'], '2026-08-30T10:00:00.000');
    });

    test('bei gleichem Tag gewinnt die grössere Serie', () {
      final raus = spielstandZusammenfuehren(
        {'lp_streak': 5, 'lp_letzte_akt': '2026-08-30T09:00:00.000'},
        {'lp_streak': 9, 'lp_letzte_akt': '2026-08-30T09:00:00.000'},
      );
      expect(raus['lp_streak'], 9);
    });

    test('fehlt eine Seite ganz, gewinnt die vorhandene', () {
      final raus = spielstandZusammenfuehren(
        {},
        {'lp_streak': 7, 'lp_letzte_akt': '2026-08-30T09:00:00.000'},
      );
      expect(raus['lp_streak'], 7);
    });
  });

  group('PORTFOLIO: Kapital folgt dem jüngeren Spieltag', () {
    test('das Kapital des jüngeren Tages gewinnt, auch wenn es kleiner ist', () {
      final raus = spielstandZusammenfuehren(
        {'pf_kapital': 5000.0, 'pf_verlauf': ['1000', '5000'], 'pf_letzter_spieltag': '2026-07-01'},
        {'pf_kapital': 900.0, 'pf_verlauf': ['1000', '900'], 'pf_letzter_spieltag': '2026-08-30'},
      );
      expect(raus['pf_kapital'], 900.0);
      expect(raus['pf_verlauf'], ['1000', '900']);
    });

    test('der Rekord bleibt davon unberührt — er läuft über das Maximum', () {
      final raus = spielstandZusammenfuehren(
        {'pf_rekord_kapital': 5000.0, 'pf_letzter_spieltag': '2026-07-01'},
        {'pf_rekord_kapital': 1200.0, 'pf_letzter_spieltag': '2026-08-30'},
      );
      expect(raus['pf_rekord_kapital'], 5000.0);
    });
  });

  group('STREAK-ZIEL: der weiter fortgeschrittene Stand gewinnt', () {
    test('erledigt schlägt offen — samt der Zieltage', () {
      final raus = spielstandZusammenfuehren(
        {'streak_ziel_stand': 'offen'},
        {'streak_ziel_stand': 'erledigt', 'streak_ziel_tage': 30},
      );
      expect(raus['streak_ziel_stand'], 'erledigt');
      expect(raus['streak_ziel_tage'], 30);
    });

    test('erledigt schlägt später', () {
      final raus = spielstandZusammenfuehren(
        {'streak_ziel_stand': 'erledigt', 'streak_ziel_tage': 7},
        {'streak_ziel_stand': 'spaeter'},
      );
      expect(raus['streak_ziel_stand'], 'erledigt');
      expect(raus['streak_ziel_tage'], 7);
    });

    test('gleich weit: das grössere Ziel gewinnt', () {
      final raus = spielstandZusammenfuehren(
        {'streak_ziel_stand': 'erledigt', 'streak_ziel_tage': 7},
        {'streak_ziel_stand': 'erledigt', 'streak_ziel_tage': 30},
      );
      expect(raus['streak_ziel_tage'], 30);
    });
  });

  group('Eigenschaften, die für ALLE Regeln gelten müssen', () {
    final a = <String, dynamic>{
      'lp_s_done_x': true,
      'lp_gesamt_richtig': 10,
      'abzeichen_freigeschaltet': ['a'],
      'lp_streak': 4,
      'lp_letzte_akt': '2026-08-30T10:00:00.000',
      'pf_kapital': 1100.0,
      'pf_letzter_spieltag': '2026-08-30',
      'streak_ziel_stand': 'erledigt',
      'streak_ziel_tage': 14,
    };
    final b = <String, dynamic>{
      'lp_s_done_y': true,
      'lp_gesamt_richtig': 99,
      'abzeichen_freigeschaltet': ['b'],
      'lp_streak': 2,
      'lp_letzte_akt': '2026-08-28T10:00:00.000',
      'pf_kapital': 800.0,
      'pf_letzter_spieltag': '2026-08-28',
      'streak_ziel_stand': 'spaeter',
    };

    test('Reihenfolge egal: a+b ergibt dasselbe wie b+a', () {
      final einweg = spielstandZusammenfuehren(a, b);
      final andersrum = spielstandZusammenfuehren(b, a);
      for (final k in einweg.keys) {
        expect(andersrum[k], einweg[k], reason: 'Schlüssel $k');
      }
      expect(andersrum.keys.length, einweg.keys.length);
    });

    test('Zweimal zusammenführen ändert nichts mehr', () {
      final einmal = spielstandZusammenfuehren(a, b);
      final zweimal = spielstandZusammenfuehren(einmal, b);
      for (final k in einmal.keys) {
        expect(zweimal[k], einmal[k], reason: 'Schlüssel $k');
      }
    });

    test('Das Ergebnis trägt die Formatversion', () {
      expect(spielstandZusammenfuehren(a, b)['version'], kSpielstandVersion);
    });
  });

  test('Ein unbekannter Schlüssel geht nicht verloren', () {
    // Kein Raten: Die vorhandene Seite gewinnt. Auffallen soll so etwas im
    // Abdeckungstest, nicht beim Spieler.
    final raus = spielstandZusammenfuehren({'irgendwas_neues': 5}, {});
    expect(raus['irgendwas_neues'], 5);
  });
}
