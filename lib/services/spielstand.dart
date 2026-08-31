/// Der Spielstand als übertragbarer Datensatz — und die Regeln, nach denen
/// zwei Stände zusammengeführt werden.
///
/// ══ WARUM ZUSAMMENFÜHREN UND NICHT "DER NEUERE GEWINNT" ══════════════════
///
/// Fast alles am Fortschritt ist einbahnig: Eine abgeschlossene Station wird
/// nie wieder unabgeschlossen, ein Abzeichen nie zurückgegeben, ein Rekord
/// nie kleiner. Genau daraus folgt die Regel je Art — ODER, Maximum,
/// Vereinigung. Und daraus wiederum folgt die wichtigste Eigenschaft:
///
///   EIN LEERER STAND KANN NICHTS LÖSCHEN.
///
/// Zusammenführen von "Gerät voll" mit "Cloud leer" ergibt "voll". Das ist
/// der Fall beim ersten Anmelden nach einem Update — mit "der Neuere
/// gewinnt" hätte genau der den Fortschritt vernichtet.
///
/// Es gibt zwei Ausnahmen, bei denen ein Wert auch FALLEN kann. Sie tragen
/// deshalb ihren eigenen Zeitstempel und werden als Einheit übernommen:
/// die Tages-Serie (mit `lp_letzte_akt`) und das Portfolio-Kapital (mit
/// `pf_letzter_spieltag`).
///
/// ══ WAS NICHT ÜBERTRAGEN WIRD ════════════════════════════════════════════
///
/// Bewusst NICHT übertragen wird alles, was ans Gerät gehört (Ton,
/// Vibration, Sprache, Erinnerungen, Werbetakt, Einwilligung) und alles
/// Flüchtige: angefangene Stationen, die Wiederholungs-Fragenlisten und die
/// Statistik je Station (wie oft richtig/falsch, zuletzt gespielt). Letztere
/// ist reine Anzeige und macht drei Viertel der Datenmenge aus.
///
/// Welcher Schlüssel wohin gehört, steht in [syncPraefixe] und
/// [nurGeraetPraefixe] — und spielstand_abdeckung_test.dart prüft, dass kein
/// Schlüssel der App in keiner der beiden Listen steht.
library;

/// Formatversion des Datensatzes. Erhöhen, wenn sich der Aufbau ändert —
/// dann weiss ein späterer Migrationsschritt, was er vor sich hat.
const int kSpielstandVersion = 1;

// ── Die Schlüssel, die in die Cloud gehen ───────────────────────────────────
//
// Als Präfixe, weil die meisten je Station/Abschnitt/Welt/Challenge einen
// eigenen Schlüssel haben. Die Reihenfolge ist egal, die Zuordnung nicht.

/// Wahrheitswerte, die nur von false auf true gehen: Fortschritt und
/// Freischaltungen. Regel: ODER.
const List<String> kOderPraefixe = [
  'lp_s_done_',
  'lp_a_done_',
  'lp_a_frei_',
  'lp_a_wdh_',
  'lp_w_done_',
  'lp_w_frei_',
  'kontinent_werbungen_',
  'profilbild_freigeschaltet_',
  'onboarding_willkommen',
  'onboarding_modus_',
];

/// Zahlen, die nur wachsen: Sterne, Rekorde, Zähler, Summen.
/// Regel: das grössere gewinnt.
const List<String> kMaxPraefixe = [
  'lp_gesamt_richtig',
  'sterne_ausgegeben',
  'ch_rekord_',
  'ch_rekord_prozent_',
  'streak_',
  'besteStreak_',
  'anzahlGespielt_',
  'summePunkte_',
  'letzterSpieltag_',
  'pf_rekord_kapital',
  'pf_streak',
  'pf_stil_',
  'streak_ziel_stationen',
  // Das zuletzt gefeierte Streak-Ziel. Der generische 'streak_'-Präfix oben
  // würde es mit erfassen — hier trotzdem beim Namen genannt, weil das
  // Zusammenspiel sonst reiner Zufall wäre: Das grössere gewinnt, damit ein
  // auf einem Gerät bereits gefeiertes Ziel auf dem anderen nicht ein zweites
  // Mal gefeiert wird.
  'streak_ziel_gefeiert',
  'erinnerung_stationen',
];

/// Listen, die nur wachsen: Abzeichen, gelernte Fakten, Spieltage, die
/// heute erledigten Challenges, die Rotations-Tracker der Fragenauswahl.
/// Regel: Vereinigung.
const List<String> kVereinigungPraefixe = [
  'abzeichen_freigeschaltet',
  'gelernt_fakten',
  'gelernt_laender',
  'spieltage_',
  'daily_',
];

/// Schlüssel, die als Einheit mit ihrem Zeitstempel übernommen werden —
/// hier kann ein Wert auch fallen.
const List<String> kEinheitStreak = ['lp_streak', 'lp_letzte_akt'];
const List<String> kEinheitPortfolio = [
  'pf_kapital',
  'pf_verlauf',
  'pf_letzter_spieltag',
];

/// Das Streak-Ziel. Kein Zeitstempel nötig: Der Stand selbst ist einbahnig
/// (offen → später → erledigt), und die weiter fortgeschrittene Seite bringt
/// ihre Zieltage mit.
const List<String> kEinheitZiel = ['streak_ziel_tage', 'streak_ziel_stand'];

/// Das gewählte Profilbild. Rein kosmetisch und ohne Zeitstempel — deshalb
/// gewinnt das Gerät, an dem gerade gespielt wird. Ein Bildwechsel auf dem
/// zweiten Gerät geht dabei verloren; das ist der Preis dafür, dass niemand
/// beim Anmelden plötzlich ein anderes Gesicht hat.
const String kProfilbild = 'profilbild_pfad';

/// Alle Präfixe, die übertragen werden — für die Abdeckungsprüfung.
List<String> get syncPraefixe => [
      ...kOderPraefixe,
      ...kMaxPraefixe,
      ...kVereinigungPraefixe,
      ...kEinheitStreak,
      ...kEinheitPortfolio,
      ...kEinheitZiel,
      kProfilbild,
    ];

/// Schlüssel, die BEWUSST am Gerät bleiben. Steht hier etwas drin, ist das
/// eine Entscheidung, kein Vergessen.
const List<String> nurGeraetPraefixe = [
  // Gerät, nicht Konto: Wer zu Hause mit Ton spielt und in der Bahn ohne,
  // will das nicht synchronisiert.
  'einstellung_sound',
  'einstellung_vibration',
  // Die Sprache ist gesetzt, bevor überhaupt jemand angemeldet ist — eine
  // Übertragung würde sie im ungünstigsten Moment umschalten.
  'einstellung_sprache',
  // Benachrichtigungen hängen an einer Geräte-Erlaubnis, der ermittelte
  // Spielrhythmus am jeweiligen Gerät.
  'erinnerung_aktiv',
  'erinnerung_streak_warnung',
  'erinnerung_erlaubnis_stand',
  'erinnerung_beutel_taeglich',
  'erinnerung_beutel_streak',
  'spielzeit_protokoll',
  'spielzeit_manuell',
  // Werbetakt und Einwilligung gehören ans Gerät.
  'letzte_ad_zeitpunkt',
  'stationen_seit_letzter_ad',
  'challenge_ad_marken',
  // Die Rotations-Tracker der Fragenauswahl. Sie SÄHEN aus wie Mengen, sind
  // aber JSON-Text in einem einzelnen Schlüssel — und bei der festen
  // Ziehreihenfolge (lp_rr_ord_*) zählt die Reihenfolge, sie trägt den
  // Schwierigkeits-Verlauf eines Zyklus. Eine Vereinigung würde genau das
  // zerstören.
  //
  // Sie bleiben deshalb am Gerät. Der Preis ist überschaubar: Auf einem neuen
  // Gerät beginnt die Rotation von vorn, es kommen also früher schon einmal
  // gestellte Fragen wieder. Fortschritt geht dabei nicht verloren.
  'lp_rr_',
  // Flüchtig: angefangene Stationen, Wiederholungslisten, Tages-Fortsetzung.
  'lp_s_gestartet_',
  'lp_s_idx_',
  'lp_s_aktive_',
  'lp_s_falsche_',
  // Die angefangene Tages-Challenge. Der Schlüssel heisst 'ch_resume_', nicht
  // 'daily_resume_' — der Abdeckungstest hat den Tippfehler gefunden, bevor
  // er etwas anrichten konnte.
  'ch_resume_',
  // Reine Anzeige je Station — drei Viertel der Datenmenge für Zahlen, die
  // nur im Stations-Blatt stehen.
  'lp_s_richtig_',
  'lp_s_falsch_',
  'lp_s_gespielt_',
  // Ergebnis-Ansichten der Tages-Challenges: neu spielbar, nicht übertragbar.
  'ch_ergebnis_',
  'ch_heute_',
  // Die Statistik der alten Einzel-Quiz (stats_service.dart). Sie wird nur
  // von Screens geschrieben, die in der App nicht mehr erreichbar sind —
  // flag_quiz, gdp_quiz und Verwandte hängen an keinem Einstieg mehr.
  // Übertragen würde also nichts als toter Ballast.
  //
  // Wird einer dieser Screens je wieder angeschlossen, gehören die drei hier
  // heraus und in die Cloud-Regeln.
  'dc_',
  'progress_',
  'lernen_days_',
  // Einmalige Oberflächen-Hinweise und Debug.
  'abzeichen_swipe_hinweis_gezeigt',
  'debug_alles_frei',
  'lp_abzeichen',
];

/// Gehört dieser Speicher-Schlüssel in die Cloud?
///
/// Die eine Stelle, an der das entschieden wird. Alles, was nicht ausdrücklich
/// in [syncPraefixe] steht, bleibt am Gerät — im Zweifel wird also NICHT
/// übertragen. Das ist die richtige Richtung für den Zweifel: Ein
/// vergessener Schlüssel kostet Bequemlichkeit, ein falsch übertragener
/// könnte Daten überschreiben.
bool gehoertInDieCloud(String schluessel) => _passt(schluessel, syncPraefixe);

// ── Zusammenführen ──────────────────────────────────────────────────────────

/// Führt zwei Spielstände zusammen. Rein: keine Prefs, kein Firestore, keine
/// Uhr — damit vollständig prüfbar.
///
/// Beide Seiten sind gleichberechtigt; das Ergebnis ist unabhängig von der
/// Reihenfolge der Argumente (ausser bei [kProfilbild], siehe dort — dafür
/// gilt [a] als das Gerät).
Map<String, dynamic> spielstandZusammenfuehren(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final ergebnis = <String, dynamic>{'version': kSpielstandVersion};

  // Alle Schlüssel beider Seiten, ohne die Verwaltungsfelder.
  final alleSchluessel = <String>{...a.keys, ...b.keys}
    ..removeWhere((k) => k == 'version');

  for (final schluessel in alleSchluessel) {
    // Die Einheiten werden unten am Stück behandelt.
    if (kEinheitStreak.contains(schluessel) ||
        kEinheitPortfolio.contains(schluessel) ||
        kEinheitZiel.contains(schluessel)) {
      continue;
    }

    final wertA = a[schluessel];
    final wertB = b[schluessel];

    if (schluessel == kProfilbild) {
      ergebnis[schluessel] = wertA ?? wertB;
    } else if (_passt(schluessel, kOderPraefixe)) {
      ergebnis[schluessel] = (wertA == true) || (wertB == true);
    } else if (_passt(schluessel, kMaxPraefixe)) {
      ergebnis[schluessel] = _groesseres(wertA, wertB);
    } else if (_passt(schluessel, kVereinigungPraefixe)) {
      ergebnis[schluessel] = _vereinigt(wertA, wertB);
    } else {
      // Unbekannter Schlüssel: nicht wegwerfen, aber auch nicht raten — die
      // vorhandene Seite gewinnt. Auffallen soll das im Abdeckungstest, nicht
      // erst beim Spieler.
      ergebnis[schluessel] = wertA ?? wertB;
    }
  }

  _uebernimmStreak(a, b, ergebnis);
  _uebernimmPortfolio(a, b, ergebnis);
  _uebernimmZiel(a, b, ergebnis);

  return ergebnis;
}

bool _passt(String schluessel, List<String> praefixe) =>
    praefixe.any((p) => schluessel == p || schluessel.startsWith(p));

/// Das grössere zweier Zahlen; fehlt eine, gewinnt die vorhandene.
Object? _groesseres(Object? a, Object? b) {
  if (a == null) return b;
  if (b == null) return a;
  if (a is num && b is num) return a >= b ? a : b;
  // Kein Zahlenpaar (etwa ein Datum als Text bei letzterSpieltag_*): der
  // grössere Text gewinnt — bei ISO-Daten ist das zugleich der spätere.
  return a.toString().compareTo(b.toString()) >= 0 ? a : b;
}

/// Vereinigung zweier Listen, ohne Duplikate und SORTIERT.
///
/// Sortiert, weil alle Listen hier Mengen sind — Abzeichen, Spieltage,
/// gelernte Fakten. Ohne die Sortierung hinge die Reihenfolge davon ab, wer
/// gerade Gerät und wer Cloud ist; das Ergebnis wäre nicht mehr unabhängig
/// von der Reihenfolge der Argumente, und jedes Zusammenführen erzeugte einen
/// neuen Schreibvorgang, obwohl sich inhaltlich nichts geändert hat.
///
/// Listen, in denen die Reihenfolge etwas bedeutet (der Portfolio-Verlauf,
/// die feste Ziehreihenfolge), laufen bewusst NICHT über diese Regel.
List<String> _vereinigt(Object? a, Object? b) {
  final raus = <String>{};
  for (final quelle in [a, b]) {
    if (quelle is List) {
      for (final e in quelle) {
        raus.add(e.toString());
      }
    }
  }
  return raus.toList()..sort();
}

/// Serie und letzte Aktivität gehören zusammen: Die Serie kann reissen, also
/// zählt nicht die grössere Zahl, sondern die JÜNGERE Aktivität. Bei
/// gleichem Datum gewinnt die grössere Serie.
void _uebernimmStreak(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
  Map<String, dynamic> ergebnis,
) {
  final datumA = a['lp_letzte_akt'] as String?;
  final datumB = b['lp_letzte_akt'] as String?;
  final Map<String, dynamic> gewinner;
  if (datumA == null) {
    gewinner = b;
  } else if (datumB == null) {
    gewinner = a;
  } else {
    final vergleich = datumA.compareTo(datumB);
    if (vergleich == 0) {
      gewinner = ((a['lp_streak'] as num?) ?? 0) >= ((b['lp_streak'] as num?) ?? 0) ? a : b;
    } else {
      gewinner = vergleich > 0 ? a : b;
    }
  }
  for (final k in kEinheitStreak) {
    if (gewinner.containsKey(k)) ergebnis[k] = gewinner[k];
  }
}

/// Kapital und Verlauf gehören zusammen und können fallen — es zählt der
/// jüngere Spieltag. Der REKORD ist davon unberührt, er läuft oben über die
/// Maximum-Regel.
void _uebernimmPortfolio(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
  Map<String, dynamic> ergebnis,
) {
  final tagA = a['pf_letzter_spieltag'] as String?;
  final tagB = b['pf_letzter_spieltag'] as String?;
  final Map<String, dynamic> gewinner;
  if (tagA == null) {
    gewinner = b;
  } else if (tagB == null) {
    gewinner = a;
  } else {
    gewinner = tagA.compareTo(tagB) >= 0 ? a : b;
  }
  for (final k in kEinheitPortfolio) {
    if (gewinner.containsKey(k)) ergebnis[k] = gewinner[k];
  }
}

/// Reihenfolge des Ziel-Stands — er geht nur vorwärts.
const List<String> _zielStandFolge = ['offen', 'spaeter', 'erledigt'];

/// Die weiter fortgeschrittene Seite bringt ihre Zieltage mit. Sind beide
/// gleich weit, gewinnt das grössere Ziel — wer sich auf zwei Geräten
/// unterschiedlich viel vornimmt, soll nicht heruntergestuft werden.
void _uebernimmZiel(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
  Map<String, dynamic> ergebnis,
) {
  int rang(Map<String, dynamic> m) {
    final stand = m['streak_ziel_stand'] as String?;
    if (stand == null) return -1;
    final i = _zielStandFolge.indexOf(stand);
    return i < 0 ? -1 : i;
  }

  final rangA = rang(a);
  final rangB = rang(b);
  final Map<String, dynamic> gewinner;
  if (rangA > rangB) {
    gewinner = a;
  } else if (rangB > rangA) {
    gewinner = b;
  } else {
    gewinner =
        ((a['streak_ziel_tage'] as num?) ?? 0) >= ((b['streak_ziel_tage'] as num?) ?? 0)
            ? a
            : b;
  }
  for (final k in kEinheitZiel) {
    if (gewinner.containsKey(k)) ergebnis[k] = gewinner[k];
  }
}
