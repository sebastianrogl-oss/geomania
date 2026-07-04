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
      final weltFrei = true; // alle Welten freigeschaltet
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

  static Future<void> allesDatenZuruecksetzen() async {
    final prefs = await SharedPreferences.getInstance();
    final toRemove = prefs.getKeys().where((k) =>
        k.startsWith('lp_') ||
        k.startsWith('ch_rekord_') ||
        k.startsWith('ch_heute_') ||
        k.startsWith('daily_') ||
        k.startsWith('pf_')).toList();
    for (final k in toRemove) {
      await prefs.remove(k);
    }
    resetSignal.value++;
  }

  // ── Länder-Round-Robin (Kern-Modi: Flaggen/Hauptstädte/Umriss) ────────────
  //
  // Pro (Welt, Abschnitt, Thema) merkt sich ein Set von ISO2-Codes, welche
  // Länder in diesem Thema bereits gezogen wurden — damit kein Land ein
  // zweites Mal drankommt, bevor nicht der ganze Länderpool des Abschnitts
  // einmal durch war. Wird automatisch mit allesDatenZuruecksetzen() /
  // allesFreischalten()-Reset gelöscht (Präfix 'lp_').

  static String _rrKey(String weltId, String abschnittId, String thema) =>
      '$_rrPrefix${weltId}_${abschnittId}_$thema';

  static Future<Set<String>> rrBereitsAbgefragt(
      String weltId, String abschnittId, String thema) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_rrKey(weltId, abschnittId, thema));
    if (raw == null) return {};
    return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
  }

  static Future<void> rrSpeichern(String weltId, String abschnittId,
      String thema, Set<String> abgefragt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _rrKey(weltId, abschnittId, thema), jsonEncode(abgefragt.toList()));
  }

  // ── Test-Modus: alles freischalten ────────────────────────────────────────

  /// Schaltet jeden Abschnitt und jede Station in jeder Welt frei (markiert
  /// sie als abgeschlossen, damit sie sofort anklickbar UND beliebig oft neu
  /// spielbar sind) — nur zum Durchtesten aller Quiz-Modi, kein normaler
  /// Spielfortschritt. Mit "Fortschritt zurücksetzen" wieder rückgängig.
  static Future<void> allesFreischalten() async {
    final prefs = await SharedPreferences.getInstance();
    for (final w in lernwelten) {
      for (final a in w.abschnitte) {
        await prefs.setBool('$_aFrei${a.id}', true);
        for (final s in a.stationen) {
          await prefs.setBool('$_sDone${s.id}', true);
        }
      }
    }
    resetSignal.value++;
  }
}
