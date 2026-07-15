import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/lernpfad_data.dart';

// ── Snapshot-Klassen ──────────────────────────────────────────────────────────

class StationDetails {
  final bool istAbgeschlossen;
  final bool istFreigeschaltet;
  final bool istGestartet;           // Session läuft, aber noch nicht fertig
  final int aktuellerFragenIndex;    // Für Fortschrittsanzeige
  final int richtigeAntworten;
  final int falscheAntworten;
  final DateTime? letzteGespielt;

  const StationDetails({
    required this.istAbgeschlossen,
    required this.istFreigeschaltet,
    this.istGestartet = false,
    this.aktuellerFragenIndex = 0,
    required this.richtigeAntworten,
    required this.falscheAntworten,
    required this.letzteGespielt,
  });
}

class LernpfadSnapshot {
  final Set<String> freieWelten;
  final Set<String> freieAbschnitte;
  /// Abschnitte bei denen Stationen + Wiederholung abgeschlossen sind.
  final Set<String> abgeschlosseneAbschnitte;
  final Map<String, StationDetails> stationen;
  final int streak;
  final int gesamtRichtig;

  const LernpfadSnapshot({
    required this.freieWelten,
    required this.freieAbschnitte,
    required this.abgeschlosseneAbschnitte,
    required this.stationen,
    required this.streak,
    required this.gesamtRichtig,
  });

  StationDetails detailsFor(String id) =>
      stationen[id] ??
      const StationDetails(
        istAbgeschlossen: false,
        istFreigeschaltet: false,
        richtigeAntworten: 0,
        falscheAntworten: 0,
        letzteGespielt: null,
      );

  bool istWeltFrei(String weltId) => freieWelten.contains(weltId);
  bool istAbschnittFrei(String abschnittId) =>
      freieAbschnitte.contains(abschnittId);
  bool istAbschnittAbgeschlossen(String abschnittId) =>
      abgeschlosseneAbschnitte.contains(abschnittId);

  double weltFortschritt(String weltId) {
    final welt = weltById(weltId);
    if (welt == null) return 0.0;
    int done = 0, total = 0;
    for (final a in welt.abschnitte) {
      for (final s in a.stationen) {
        total++;
        if (stationen[s.id]?.istAbgeschlossen ?? false) done++;
      }
    }
    return total == 0 ? 0.0 : done / total;
  }

  double abschnittFortschritt(String abschnittId) {
    final a = abschnittById(abschnittId);
    if (a == null) return 0.0;
    final done =
        a.stationen.where((s) => stationen[s.id]?.istAbgeschlossen ?? false).length;
    return done / a.stationen.length;
  }

  /// Fortschritt (0.0-1.0) über ALLE Stationen des gesamten Lernpfads, deren
  /// Modus zu [thema] gehört (siehe lernModusThema()) — z.B. 'flaggen' für
  /// alle drei Flaggen-Varianten zusammen, über jeden Kontinent hinweg.
  double themaFortschritt(String thema) {
    int done = 0, total = 0;
    for (final w in lernwelten) {
      for (final a in w.abschnitte) {
        for (final s in a.stationen) {
          if (lernModusThema(s.modus) != thema) continue;
          total++;
          if (stationen[s.id]?.istAbgeschlossen ?? false) done++;
        }
      }
    }
    return total == 0 ? 0.0 : done / total;
  }

  /// Fortschritt (0.0-1.0) über ALLE Stationen des gesamten Lernpfads, deren
  /// Modus in [modi] enthalten ist — für Profil-Kategorien, die mehrere
  /// LernModus-Werte zu einer Anzeige zusammenfassen (z.B. "Länder-Daten &
  /// Rekorde" aus preisSchaetzen+extremFrage+wirtschaftssektoren+...).
  double modiFortschritt(Set<LernModus> modi) {
    int done = 0, total = 0;
    for (final w in lernwelten) {
      for (final a in w.abschnitte) {
        for (final s in a.stationen) {
          if (!modi.contains(s.modus)) continue;
          total++;
          if (stationen[s.id]?.istAbgeschlossen ?? false) done++;
        }
      }
    }
    return total == 0 ? 0.0 : done / total;
  }

  int get abgeschlosseneStationenAnzahl =>
      stationen.values.where((d) => d.istAbgeschlossen).length;

  // Rückwärts-Kompatibilität
  int get abgeschlosseneStationen => abgeschlosseneStationenAnzahl;
}

// ── Service ───────────────────────────────────────────────────────────────────

class FortschrittService {
  static final resetSignal = ValueNotifier<int>(0);

  // Station
  static const _sDone      = 'lp_s_done_';
  static const _sRichtig   = 'lp_s_richtig_';
  static const _sFalsch    = 'lp_s_falsch_';
  static const _sGespielt  = 'lp_s_gespielt_';
  static const _sGestartet = 'lp_s_gestartet_';
  static const _sIdx       = 'lp_s_idx_';
  static const _sAktive    = 'lp_s_aktive_';    // JSON für Fortsetzung
  static const _sFalsche   = 'lp_s_falsche_';   // JSON falsche Fragen → Section-Pool

  // Abschnitt
  static const _aFrei    = 'lp_a_frei_';
  static const _aDone    = 'lp_a_done_';   // Stationen + Wiederholung fertig
  static const _aWdh     = 'lp_a_wdh_';   // wiederholungAbgeschlossen

  // Welt
  static const _wFrei  = 'lp_w_frei_';
  static const _wDone  = 'lp_w_done_';

  // Global
  static const _kStreak       = 'lp_streak';
  static const _kLetzteAkt    = 'lp_letzte_akt';
  static const _kGesamtRichtig = 'lp_gesamt_richtig';
  static const _kAbzeichen    = 'lp_abzeichen';

  // Länder-Round-Robin (pro Welt+Abschnitt+Kernthema)
  static const _rrPrefix = 'lp_rr_';

  // ── Station abschließen ────────────────────────────────────────────────────

  /// Markiert Station als abgeschlossen. [falscheFragenJson] ist eine
  /// JSON-Liste von Fragen-IDs die der Section-Pool erhält.
  static Future<void> stationAbschliessen(
    String stationId,
    int richtig,
    int falsch, {
    String? falscheFragenJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_sDone$stationId', true);
    await prefs.remove('$_sGestartet$stationId');
    await prefs.remove('$_sIdx$stationId');
    await prefs.remove('$_sAktive$stationId');

    final prevR = prefs.getInt('$_sRichtig$stationId') ?? 0;
    final prevF = prefs.getInt('$_sFalsch$stationId') ?? 0;
    await prefs.setInt('$_sRichtig$stationId', prevR + richtig);
    await prefs.setInt('$_sFalsch$stationId', prevF + falsch);
    await prefs.setString('$_sGespielt$stationId', DateTime.now().toIso8601String());

    if (falscheFragenJson != null && falscheFragenJson.isNotEmpty) {
      await prefs.setString('$_sFalsche$stationId', falscheFragenJson);
    }

    final prevGesamt = prefs.getInt(_kGesamtRichtig) ?? 0;
    await prefs.setInt(_kGesamtRichtig, prevGesamt + richtig);
    await prefs.setString(_kLetzteAkt, DateTime.now().toIso8601String());
  }

  // ── Continuation: Station-Fortschritt speichern/laden ─────────────────────

  /// Speichert den laufenden Stand einer Station (für Fortsetzen bei Abbruch).
  static Future<void> stationFortschrittSpeichern(
    String stationId, {
    required int aktuellerIndex,
    required String aktiveFragenJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_sGestartet$stationId', true);
    await prefs.setInt('$_sIdx$stationId', aktuellerIndex);
    await prefs.setString('$_sAktive$stationId', aktiveFragenJson);
  }

  /// Gibt {idx, aktivJson} zurück wenn Station läuft, sonst null.
  static Future<Map<String, dynamic>?> ladeStationFortschritt(
      String stationId) async {
    final prefs = await SharedPreferences.getInstance();
    final gestartet = prefs.getBool('$_sGestartet$stationId') ?? false;
    final done      = prefs.getBool('$_sDone$stationId') ?? false;
    if (!gestartet || done) return null;
    final idx  = prefs.getInt('$_sIdx$stationId') ?? 0;
    final json = prefs.getString('$_sAktive$stationId') ?? '[]';
    return {'idx': idx, 'aktivJson': json};
  }

  /// Ist [stationId] bereits abgeschlossen? Genutzt von
  /// FragenGenerator.ermittleTatsaechlichenModus(), damit ein Replay einer
  /// bereits abgeschlossenen Station immer ihren ursprünglich zugewiesenen
  /// Modus behält, statt bei ausgeschöpftem Pool zu variieren (Pensionierung
  /// bleibt weiterhin aktiv für den ERSTEN, noch nicht abgeschlossenen Zug).
  static Future<bool> istStationAbgeschlossen(String stationId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_sDone$stationId') ?? false;
  }

  /// Löscht den Zwischen-Stand (z.B. wenn Station neu gestartet wird).
  static Future<void> stationZuruecksetzen(String stationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_sGestartet$stationId');
    await prefs.remove('$_sIdx$stationId');
    await prefs.remove('$_sAktive$stationId');
  }

  // ── Abschnitts-Wiederholung ────────────────────────────────────────────────

  /// Gibt true zurück wenn [stationId] die letzte Station im Abschnitt ist.
  static bool istLetzteStationImAbschnitt(String stationId) {
    final kontext = stationKontext(stationId);
    if (kontext == null) return false;
    final (_, abschnitt, _) = kontext;
    return abschnitt.stationen.last.id == stationId;
  }

  /// Sammelt alle gespeicherten falschen Fragen aller Stationen eines
  /// Abschnitts, dedupliziert und begrenzt auf maxWiederholungen.
  /// Gibt eine JSON-Liste zurück (Liste von Fragen-Dicts oder IDs).
  static Future<String> sammelFalscheFragenFuerAbschnitt(
      String abschnittId) async {
    final abschnitt = abschnittById(abschnittId);
    if (abschnitt == null) return '[]';
    final prefs = await SharedPreferences.getInstance();

    // Map: fragenId → häufigkeit (für Priorisierung der am häufigsten falschen)
    final Map<String, int> haeufigkeit = {};
    final Map<String, dynamic> fragenDaten = {};

    for (final s in abschnitt.stationen) {
      final raw = prefs.getString('$_sFalsche${s.id}');
      if (raw == null || raw.isEmpty) continue;
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String? ?? '';
            if (id.isEmpty) continue;
            haeufigkeit[id] = (haeufigkeit[id] ?? 0) + 1;
            fragenDaten[id] = item;
          }
        }
      } catch (_) {}
    }

    if (haeufigkeit.isEmpty) return '[]';

    // Sortiere nach Häufigkeit absteigend, begrenzen auf maxWiederholungen
    final sorted = haeufigkeit.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final limit = abschnitt.maxWiederholungen;
    final top = sorted.take(limit).map((e) => fragenDaten[e.key]).toList();

    return jsonEncode(top);
  }

  /// Markiert die Wiederholung eines Abschnitts als abgeschlossen und
  /// schaltet den nächsten Abschnitt / die nächste Welt frei.
  static Future<void> wiederholungAbschliessen(String abschnittId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_aWdh$abschnittId', true);
    await prefs.setBool('$_aDone$abschnittId', true);
    await naechstenAbschnittFreischalten(abschnittId, prefs: prefs);
  }

  /// Gibt true zurück wenn der Abschnitt falsche Fragen für eine
  /// Wiederholungsrunde hat.
  static Future<bool> wiederholungNoetig(String abschnittId) async {
    final json = await sammelFalscheFragenFuerAbschnitt(abschnittId);
    final list = jsonDecode(json) as List<dynamic>;
    return list.isNotEmpty;
  }

  // ── Nächste Station / Abschnitt / Welt freischalten ───────────────────────

  /// Prüft nach stationAbschliessen ob der Abschnitt-Abschluss ausgelöst
  /// werden soll. Wird vom UI aufgerufen — der Service entscheidet NICHT
  /// selbst über die Wiederholung (das macht der Screen).
  static Future<void> naechsteStationFreischalten(
      String aktuelleStationId) async {
    // Stationen werden dynamisch als "frei" berechnet (vorherige done = frei).
    // Bei letzter Station: nichts tun — UI löst sammelFalscheFragen() aus.
    // (Kein automatisches Abschnitt-Freischalten mehr hier.)
  }

  static Future<void> naechstenAbschnittFreischalten(
    String abschnittId, {
    SharedPreferences? prefs,
  }) async {
    prefs ??= await SharedPreferences.getInstance();
    for (final w in lernwelten) {
      final idx = w.abschnitte.indexWhere((a) => a.id == abschnittId);
      if (idx < 0) continue;
      if (idx < w.abschnitte.length - 1) {
        await prefs.setBool('$_aFrei${w.abschnitte[idx + 1].id}', true);
      } else {
        // Letzter Abschnitt der Welt → prüfen ob Welt fertig
        final allDone = await _alleAbschnitteAbgeschlossen(w.id, prefs);
        if (allDone) {
          await prefs.setBool('$_wDone${w.id}', true);
          await naechsteWeltFreischalten(w.id, prefs: prefs);
        }
      }
      return;
    }
  }

  static Future<bool> _alleAbschnitteAbgeschlossen(
      String weltId, SharedPreferences prefs) async {
    final w = weltById(weltId);
    if (w == null) return false;
    return w.abschnitte.every(
        (a) => prefs.getBool('$_aDone${a.id}') ?? false);
  }

  static Future<void> naechsteWeltFreischalten(
    String weltId, {
    SharedPreferences? prefs,
  }) async {
    prefs ??= await SharedPreferences.getInstance();
    final welt = weltById(weltId);
    if (welt == null) return;
    final next =
        lernwelten.where((w) => w.reihenfolge == welt.reihenfolge + 1);
    if (next.isEmpty) return;
    await prefs.setBool('$_wFrei${next.first.id}', true);
  }

  // ── Werbe-Freischaltung (AdService) ────────────────────────────────────────
  //
  // Alternativer Freischalt-Weg neben der normalen, fortschritts-basierten
  // Reihenfolge (naechsteWeltFreischalten): schaltet die ANGEGEBENE Welt
  // direkt frei, unabhängig davon, ob die vorherige Welt schon fertig ist —
  // nötig, damit man z.B. Nordamerika direkt per Werbung freischalten kann,
  // ohne erst Südamerika durchspielen zu müssen.

  static const _wWerbung = 'kontinent_werbungen_';

  static Future<int> kontinentWerbungenAngesehen(String weltId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_wWerbung$weltId') ?? 0;
  }

  /// Erhöht den Werbe-Zähler einer Welt um 1 und schaltet sie bei Erreichen
  /// von [kontinentWerbungenNoetig] direkt frei. Gibt den neuen Zählerstand
  /// zurück.
  static const kontinentWerbungenNoetig = 3;

  static Future<int> kontinentWerbungErhoehen(String weltId) async {
    final prefs = await SharedPreferences.getInstance();
    final neuerStand =
        (prefs.getInt('$_wWerbung$weltId') ?? 0).clamp(0, kontinentWerbungenNoetig) + 1;
    await prefs.setInt('$_wWerbung$weltId', neuerStand);
    if (neuerStand >= kontinentWerbungenNoetig) {
      await prefs.setBool('$_wFrei$weltId', true);
    }
    return neuerStand;
  }

  // ── Einzel-Abfragen ───────────────────────────────────────────────────────

  static Future<bool> istStationFreigeschaltet(String stationId) async {
    final kontext = stationKontext(stationId);
    if (kontext == null) return false;
    final (_, abschnitt, _) = kontext;
    if (!await istAbschnittFreigeschaltet(abschnitt.id)) return false;
    final idx = abschnitt.stationen.indexWhere((s) => s.id == stationId);
    if (idx == 0) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_sDone${abschnitt.stationen[idx - 1].id}') ?? false;
  }

  static Future<bool> istAbschnittFreigeschaltet(String abschnittId) async {
    for (final w in lernwelten) {
      final idx = w.abschnitte.indexWhere((a) => a.id == abschnittId);
      if (idx < 0) continue;
      if (!await istWeltFreigeschaltet(w.id)) return false;
      if (idx == 0) return true;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_aFrei$abschnittId') ?? false;
    }
    return false;
  }

  static Future<bool> istWeltFreigeschaltet(String weltId) async {
    final welt = weltById(weltId);
    if (welt == null) return false;
    if (welt.reihenfolge == 1) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_wFrei$weltId') ?? false;
  }

  static Future<bool> abschnittStationenAbgeschlossen(
      String abschnittId) async {
    final a = abschnittById(abschnittId);
    if (a == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return a.stationen.every((s) => prefs.getBool('$_sDone${s.id}') ?? false);
  }

  /// Vollständig abgeschlossen = Stationen PLUS Wiederholung fertig.
  static Future<bool> abschnittAbgeschlossen(String abschnittId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_aDone$abschnittId') ?? false;
  }

  static Future<bool> wiederholungAbgeschlossen(String abschnittId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_aWdh$abschnittId') ?? false;
  }

  static Future<bool> weltAbgeschlossen(String weltId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_wDone$weltId') ?? false;
  }

  // ── Streak ─────────────────────────────────────────────────────────────────

  static Future<void> streakAktualisieren() async {
    final prefs = await SharedPreferences.getInstance();
    final letzteStr = prefs.getString(_kLetzteAkt);
    final heute = DateTime.now();
    int streak = prefs.getInt(_kStreak) ?? 0;

    if (letzteStr != null) {
      final letzte = DateTime.parse(letzteStr);
      final diff =
          DateTime(heute.year, heute.month, heute.day)
              .difference(DateTime(letzte.year, letzte.month, letzte.day))
              .inDays;
      if (diff == 0) return;
      streak = diff == 1 ? streak + 1 : 1;
    } else {
      streak = 1;
    }

    await prefs.setInt(_kStreak, streak);
    await prefs.setString(_kLetzteAkt, heute.toIso8601String());
  }

  // ── Abzeichen ─────────────────────────────────────────────────────────────

  static Future<List<String>> getAbzeichen() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAbzeichen) ?? '[]';
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  static Future<void> abzeichenFreischalten(String abzeichenId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAbzeichen();
    if (list.contains(abzeichenId)) return;
    list.add(abzeichenId);
    await prefs.setString(_kAbzeichen, jsonEncode(list));
  }

  // ── Gesamtfortschritt ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> gesamtFortschritt() async {
    final prefs = await SharedPreferences.getInstance();
    int abgeschlossen = 0, gesamt = 0, freiWelten = 0;

    for (final w in lernwelten) {
      final frei =
          w.reihenfolge == 1 || (prefs.getBool('$_wFrei${w.id}') ?? false);
      if (frei) freiWelten++;
      for (final a in w.abschnitte) {
        for (final s in a.stationen) {
          gesamt++;
          if (prefs.getBool('$_sDone${s.id}') ?? false) abgeschlossen++;
        }
      }
    }

    return {
      'abgeschlosseneStationen': abgeschlossen,
      'gesamtStationen': gesamt,
      'streak': prefs.getInt(_kStreak) ?? 0,
      'gesamtRichtig': prefs.getInt(_kGesamtRichtig) ?? 0,
      'freigeschalteteWelten': freiWelten,
    };
  }

  // ── Snapshot ──────────────────────────────────────────────────────────────

  static Future<LernpfadSnapshot> ladeSnapshot() async {
    final prefs = await SharedPreferences.getInstance();

    final freieWelten       = <String>{};
    final freieAbschnitte   = <String>{};
    final abgAbschnitte     = <String>{};
    final statusMap         = <String, StationDetails>{};

    for (final welt in lernwelten) {
      final weltFrei =
          welt.reihenfolge == 1 || (prefs.getBool('$_wFrei${welt.id}') ?? false);
      if (weltFrei) freieWelten.add(welt.id);

      for (int ai = 0; ai < welt.abschnitte.length; ai++) {
        final abschnitt = welt.abschnitte[ai];
        final abschnittFrei = weltFrei &&
            (ai == 0 || (prefs.getBool('$_aFrei${abschnitt.id}') ?? false));
        if (abschnittFrei) freieAbschnitte.add(abschnitt.id);

        if (prefs.getBool('$_aDone${abschnitt.id}') ?? false) {
          abgAbschnitte.add(abschnitt.id);
        }

        for (int si = 0; si < abschnitt.stationen.length; si++) {
          final station = abschnitt.stationen[si];
          final done = prefs.getBool('$_sDone${station.id}') ?? false;
          final stationFrei = abschnittFrei &&
              (si == 0 ||
                  (prefs.getBool(
                          '$_sDone${abschnitt.stationen[si - 1].id}') ??
                      false));
          final gestartet =
              prefs.getBool('$_sGestartet${station.id}') ?? false;
          final idx = prefs.getInt('$_sIdx${station.id}') ?? 0;
          final gespielt = prefs.getString('$_sGespielt${station.id}');

          statusMap[station.id] = StationDetails(
            istAbgeschlossen:    done,
            istFreigeschaltet:   stationFrei,
            istGestartet:        gestartet && !done,
            aktuellerFragenIndex: idx,
            richtigeAntworten:   prefs.getInt('$_sRichtig${station.id}') ?? 0,
            falscheAntworten:    prefs.getInt('$_sFalsch${station.id}') ?? 0,
            letzteGespielt:
                gespielt != null ? DateTime.parse(gespielt) : null,
          );
        }
      }
    }

    return LernpfadSnapshot(
      freieWelten:              freieWelten,
      freieAbschnitte:          freieAbschnitte,
      abgeschlosseneAbschnitte: abgAbschnitte,
      stationen:                statusMap,
      streak:                   prefs.getInt(_kStreak) ?? 0,
      gesamtRichtig:            prefs.getInt(_kGesamtRichtig) ?? 0,
    );
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  // "Alles zurücksetzen" betrifft NUR den Lernpfad (Stationen, Abschnitte,
  // Welten, Round-Robin-Tracker, per Werbung freigeschaltete Kontinente) —
  // Tages-Challenge-Statistiken (Rekorde, Streaks, "heute gespielt",
  // Anzahl/Ø-Werte, Portfolio-Kapital/-Verlauf) bleiben davon bewusst
  // unberührt (siehe Einstellungen-Screen). Frühere Fassungen löschten hier
  // zusätzlich 'ch_rekord_', 'ch_heute_', 'ch_resume_', 'daily_', 'pf_',
  // 'streak_', 'letzterSpieltag_', 'spieltage_', 'anzahlGespielt_',
  // 'summePunkte_' und 'besteStreak_' — das war zu breit gefasst und hat
  // Tages-Challenge-Daten mitgelöscht, obwohl der dafür zuständige
  // Firestore-Aufruf (RanglisteService.loescheEigeneRanglistendaten())
  // bereits an anderer Stelle entfernt wurde.
  static Future<void> allesDatenZuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    // 'abzeichen_freigeschaltet' bewusst NICHT mit gelöscht: Abzeichen können
    // sowohl durch Lernpfad-Fortschritt als auch durch Challenge-Statistiken
    // (Streak, Rekord, ...) ausgelöst werden — Letztere bleiben beim Reset
    // erhalten, ein bereits verdientes Abzeichen darf also nicht verschwinden.
    // Ein rein Lernpfad-bedingtes Abzeichen (z.B. "Kontinent abgeschlossen")
    // würde ohnehin erst wieder freigeschaltet, sobald sein Kontext erneut
    // zutrifft — bis dahin bleibt es einfach bestehen.
    final toRemove = prefs.getKeys().where((k) =>
        k.startsWith('lp_') ||
        // Werbe-Fortschritt fürs Kontinent-Freischalten (siehe AdService/
        // _KontinentFreischaltenDialog) — eigenes Präfix, nicht 'lp_', sonst
        // bleiben die "X von 3 angesehen"-Punkte nach einem Reset stehen,
        // obwohl der Kontinent selbst wieder gesperrt ist.
        k.startsWith('kontinent_werbungen_')).toList();
    for (final k in toRemove) {
      await prefs.remove(k);
    }
    resetSignal.value++;
  }

  /// Setzt NUR einen einzelnen Kontinenten zurück: alle Stationen/Abschnitte/
  /// Welt-Freischaltungen DIESES Kontinents sowie alle zugehörigen Round-
  /// Robin-Tracker (inkl. der festen Ziehreihenfolge) — beide Schlüssel-
  /// Formate aus dem Block-Umbau (welt-weit für "Welt" bzw. abschnitts-
  /// gescoped für die 6 Block-Kontinente, siehe station_session_service.dart
  /// _rrModusKey()). Andere Kontinente UND globale Werte (Streak,
  /// Gesamtpunkte) bleiben unberührt.
  static Future<void> kontinentZuruecksetzen(String weltId) async {
    final welt = weltById(weltId);
    if (welt == null) return;
    final prefs = await SharedPreferences.getInstance();

    final toRemove = <String>{
      '$_wFrei$weltId',
      '$_wDone$weltId',
      '$_wWerbung$weltId',
    };
    for (final a in welt.abschnitte) {
      toRemove.addAll({'$_aFrei${a.id}', '$_aDone${a.id}', '$_aWdh${a.id}'});
      for (final s in a.stationen) {
        toRemove.addAll({
          '$_sDone${s.id}',
          '$_sRichtig${s.id}',
          '$_sFalsch${s.id}',
          '$_sGespielt${s.id}',
          '$_sGestartet${s.id}',
          '$_sIdx${s.id}',
          '$_sAktive${s.id}',
          '$_sFalsche${s.id}',
        });
      }
    }

    // Round-Robin + feste Reihenfolge: zwei Schlüssel-Formen möglich
    // (siehe Kommentar oben), beide beginnen mit 'lp_rr_' bzw. 'lp_rr_ord_'
    // gefolgt direkt von der weltId.
    final rrPrefix = '$_rrPrefix${weltId}_';
    final rrOrdPrefix = '${_rrPrefix}ord_${weltId}_';
    toRemove.addAll(prefs
        .getKeys()
        .where((k) => k.startsWith(rrPrefix) || k.startsWith(rrOrdPrefix)));

    for (final k in toRemove) {
      await prefs.remove(k);
    }
    resetSignal.value++;
  }

  /// Der Kontinent, den der Spieler aktuell aktiv bespielt: der erste, noch
  /// nicht zu 100% abgeschlossene (in Reihenfolge Europa → Welt), sonst der
  /// letzte. Dieselbe Logik wie die Auto-Auswahl im Home-Screen, aber
  /// eigenständig berechnet (kein Zugriff auf dessen privaten State nötig).
  static Future<LernWelt> aktuelleWelt() async {
    final snap = await ladeSnapshot();
    var aktiv = lernwelten.first;
    for (final w in lernwelten) {
      aktiv = w;
      if (snap.weltFortschritt(w.id) < 1.0) break;
    }
    return aktiv;
  }

  // ── Länder-Round-Robin (Kern-/Eingabe-Modi) ────────────────────────────────
  //
  // Pro (Welt, Modus) merkt sich ein Set von ISO2-Codes, welche Länder in
  // genau diesem Modus für genau diese Welt bereits gezogen wurden — DURCH-
  // GÄNGIG über alle Abschnitte dieser Welt hinweg, OHNE Reset beim
  // Abschnittswechsel (nur wenn der Zyklus komplett durch ist, beginnt eine
  // neue Runde). Wird automatisch mit allesDatenZuruecksetzen() /
  // allesFreischalten()-Reset gelöscht (Präfix 'lp_').

  static String _rrKey(String weltId, String modusKey) =>
      '$_rrPrefix${weltId}_$modusKey';

  static Future<Set<String>> rrBereitsAbgefragt(
      String weltId, String modusKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rrKey(weltId, modusKey));
    if (raw == null) return {};
    return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
  }

  static Future<void> rrSpeichern(
      String weltId, String modusKey, Set<String> abgefragt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rrKey(weltId, modusKey), jsonEncode(abgefragt.toList()));
  }

  // ── Feste, gewichtete Ziehreihenfolge (graduelle Schwierigkeits-Einmischung) ──
  //
  // Pro (Welt, Modus) wird die nach Schwierigkeit gewichtete Ziehreihenfolge
  // über den aktuell freigeschalteten Länderpool berechnet und dauerhaft
  // gespeichert, damit die Tendenz "leicht am Anfang, schwerer zum Ende"
  // über den gesamten Round-Robin-Zyklus DIESES EINEN Modus konsistent
  // bleibt, statt bei jeder Station neu (und damit unzusammenhängend)
  // gewürfelt zu werden. Wächst der freigeschaltete Pool (Abschnittswechsel)
  // oder läuft der Zyklus komplett durch, wird sie neu berechnet.

  static String _ordKey(String weltId, String modusKey) =>
      '${_rrPrefix}ord_${weltId}_$modusKey';

  static Future<List<String>?> ladeFesteReihenfolge(
      String weltId, String modusKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ordKey(weltId, modusKey));
    if (raw == null) return null;
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  static Future<void> speichereFesteReihenfolge(
      String weltId, String modusKey, List<String> reihenfolge) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ordKey(weltId, modusKey), jsonEncode(reihenfolge));
  }

  static Future<void> loescheFesteReihenfolge(String weltId, String modusKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ordKey(weltId, modusKey));
  }

}
