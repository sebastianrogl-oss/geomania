import 'package:shared_preferences/shared_preferences.dart';
import '../data/abzeichen_data.dart';
import '../data/lernpfad_data.dart';
import 'challenge_rekord_service.dart';
import 'daily_challenge.dart';
import 'fortschritt_service.dart';

const _challengeIdsFuerAbzeichen = ['preis', 'higher_lower', 'ranking_game', 'portfolio'];

class AbzeichenService {
  static const _kFreigeschaltet = 'abzeichen_freigeschaltet';
  static const _kSwipeHinweisGezeigt = 'abzeichen_swipe_hinweis_gezeigt';

  static Future<Set<String>> getFreigeschaltete() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kFreigeschaltet) ?? []).toSet();
  }

  static Future<void> _speichern(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kFreigeschaltet, ids.toList());
  }

  /// Einmaliger Hinweis "Wische für dein Münzalbum" im Profilbild-Dialog —
  /// wird nach dem ersten Anzeigen gemerkt und danach nie wieder gezeigt.
  static Future<bool> wurdeSwipeHinweisGezeigt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSwipeHinweisGezeigt) ?? false;
  }

  static Future<void> setzeSwipeHinweisGezeigt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSwipeHinweisGezeigt, true);
  }

  /// Baut den Kontext frisch aus den bestehenden Datenquellen (Streak/
  /// Spieltage, Lernpfad-Streak, Kontinent-/Stationsfortschritt, Challenge-
  /// Rekorde) und prüft alle 30 Abzeichen-Bedingungen dagegen.
  /// [heutePerfekt]/[neuerRekordHeute] betreffen NUR die gerade
  /// abgeschlossene Challenge — bei jedem Challenge-Abschluss neu übergeben,
  /// bei einem reinen Lernpfad-Fortschritt bleiben sie false.
  static Future<AbzeichenKontext> _baueKontext({
    bool heutePerfekt = false,
    bool neuerRekordHeute = false,
  }) async {
    final streaks = <String, int>{
      for (final id in _challengeIdsFuerAbzeichen)
        id: await ChallengeRekordService.getStreak(id),
    };
    final rekorde = <String, int?>{
      for (final id in _challengeIdsFuerAbzeichen)
        id: await ChallengeRekordService.getRekord(id),
    };
    final heuteErledigt = await DailyChallenge.completedToday();
    final lpSnap = await FortschrittService.ladeSnapshot();
    final abgeschlosseneWelten = {
      for (final w in lernwelten)
        if (lpSnap.weltFortschritt(w.id) >= 1.0) w.id,
    };

    return AbzeichenKontext(
      streaksProChallenge: streaks,
      heutePerfekt: heutePerfekt,
      neuerRekordHeute: neuerRekordHeute,
      alleChallengesHeute: heuteErledigt.length >= 4,
      appStreak: lpSnap.streak,
      rekordProChallenge: rekorde,
      abgeschlosseneWelten: abgeschlosseneWelten,
      gesamtAbgeschlosseneStationen: lpSnap.abgeschlosseneStationenAnzahl,
    );
  }

  static Future<List<Abzeichen>> _pruefeUndSchalteFrei(
      AbzeichenKontext kontext) async {
    final bereitsFrei = await getFreigeschaltete();
    final aktuellFrei = Set<String>.from(bereitsFrei);
    final neu = <Abzeichen>[];
    for (final a in alleAbzeichen) {
      if (aktuellFrei.contains(a.id)) continue;
      if (a.istErreicht(kontext)) {
        aktuellFrei.add(a.id);
        neu.add(a);
      }
    }
    if (neu.isNotEmpty) await _speichern(aktuellFrei);
    return neu;
  }

  /// Gibt die NEU freigeschalteten Abzeichen zurück (leer wenn keine neuen).
  static Future<List<Abzeichen>> pruefeNachChallengeAbschluss({
    bool heutePerfekt = false,
    bool neuerRekordHeute = false,
  }) async {
    final kontext = await _baueKontext(
      heutePerfekt: heutePerfekt,
      neuerRekordHeute: neuerRekordHeute,
    );
    return _pruefeUndSchalteFrei(kontext);
  }

  /// Wie [pruefeNachChallengeAbschluss], aber für den Auslösepunkt nach
  /// einem abgeschlossenen Lernpfad-Station (Kontinent-/Meilenstein-
  /// Abzeichen sollen nicht erst beim nächsten Challenge-Spiel auffallen).
  static Future<List<Abzeichen>> pruefeNachLernpfadFortschritt() async {
    final kontext = await _baueKontext();
    return _pruefeUndSchalteFrei(kontext);
  }
}
