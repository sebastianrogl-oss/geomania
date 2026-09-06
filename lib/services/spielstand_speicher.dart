import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'spielstand.dart';

/// Die Brücke zwischen den SharedPreferences und dem übertragbaren
/// Spielstand-Datensatz.
///
/// Bewusst getrennt von spielstand.dart: Dort stehen die REGELN, und die
/// bleiben rein — ohne Prefs, ohne Uhr, ohne Netz, damit sie vollständig
/// prüfbar sind. Hier steht das Lesen und Schreiben, und sonst nichts.
///
/// ══ WARUM DIE TYPEN HIER SO VIEL PLATZ BEKOMMEN ═════════════════════════
///
/// SharedPreferences ist streng typisiert: Wurde ein Schlüssel einmal mit
/// `setInt` geschrieben, wirft `getDouble` darauf eine Typausnahme — und zwar
/// nicht beim Schreiben, sondern irgendwann später beim Lesen, an einer ganz
/// anderen Stelle der App. Ein einziger als Ganzzahl zurückgekommener
/// Kapitalstand könnte das Portfolio dauerhaft unbenutzbar machen.
///
/// Deshalb gilt hier: Der am Gerät bereits vorhandene Typ hat immer recht.
/// Ist der Schlüssel neu, entscheidet der Typ des ankommenden Werts.
class SpielstandSpeicher {
  /// Liest alle Schlüssel, die in die Cloud gehören, aus den Prefs.
  ///
  /// Nur vorhandene Schlüssel — ein nie gesetzter Wert kommt nicht als `null`
  /// mit, sondern gar nicht. Das ist wichtig: Beim Zusammenführen bedeutet
  /// "fehlt" ausdrücklich etwas anderes als "ist leer".
  static Future<Map<String, dynamic>> lesen() async {
    final prefs = await SharedPreferences.getInstance();
    final raus = <String, dynamic>{'version': kSpielstandVersion};
    for (final schluessel in prefs.getKeys()) {
      if (!gehoertInDieCloud(schluessel)) continue;
      final wert = prefs.get(schluessel);
      if (wert == null) continue;
      raus[schluessel] = wert is List<String> ? List<String>.from(wert) : wert;
    }
    return raus;
  }

  /// Schreibt einen zusammengeführten Stand zurück in die Prefs.
  ///
  /// Schreibt nur, was sich tatsächlich unterscheidet. Das hält die Zahl der
  /// Plattform-Aufrufe klein und macht die Rückkehr aus der Cloud spürbar
  /// billiger, wenn sich — wie meistens — fast nichts geändert hat.
  ///
  /// Liefert die Zahl der geänderten Schlüssel; die Aufrufer nutzen sie, um
  /// zu entscheiden, ob die Oberfläche neu geladen werden muss.
  static Future<int> schreiben(Map<String, dynamic> stand) async {
    final prefs = await SharedPreferences.getInstance();
    var geaendert = 0;
    for (final eintrag in stand.entries) {
      final schluessel = eintrag.key;
      if (schluessel == 'version') continue;
      if (!gehoertInDieCloud(schluessel)) {
        // Ein Schlüssel, den diese Version nicht mehr überträgt — etwa weil
        // er seit dem letzten Update ans Gerät gehört. Er wird übergangen,
        // nicht geschrieben. Bewusst KEIN assert: Alte Cloud-Dokumente sind
        // ein normaler Zustand, kein Programmierfehler, und ein Debug-Build
        // soll daran nicht steckenbleiben.
        debugPrint('Spielstand: übergehe unbekannten Schlüssel $schluessel');
        continue;
      }
      if (await _schreibeEinen(prefs, schluessel, eintrag.value)) geaendert++;
    }
    return geaendert;
  }

  /// Schreibt einen einzelnen Wert typrichtig. Liefert true, wenn sich etwas
  /// geändert hat.
  static Future<bool> _schreibeEinen(
    SharedPreferences prefs,
    String schluessel,
    Object? wert,
  ) async {
    if (wert == null) return false;
    final alt = prefs.get(schluessel);

    // Der vorhandene Typ gewinnt: Ein Wert, der als Ganzzahl aus der Cloud
    // kommt, obwohl er hier eine Kommazahl ist, wird angepasst statt
    // umgeschrieben.
    if (alt is double && wert is num) {
      final neu = wert.toDouble();
      if (alt == neu) return false;
      await prefs.setDouble(schluessel, neu);
      return true;
    }
    if (alt is int && wert is num && wert is! double) {
      final neu = wert.toInt();
      if (alt == neu) return false;
      await prefs.setInt(schluessel, neu);
      return true;
    }

    if (wert is bool) {
      if (alt == wert) return false;
      await prefs.setBool(schluessel, wert);
      return true;
    }
    if (wert is int) {
      if (alt == wert) return false;
      await prefs.setInt(schluessel, wert);
      return true;
    }
    if (wert is double) {
      if (alt == wert) return false;
      await prefs.setDouble(schluessel, wert);
      return true;
    }
    if (wert is String) {
      if (alt == wert) return false;
      await prefs.setString(schluessel, wert);
      return true;
    }
    if (wert is List) {
      final neu = wert.map((e) => e.toString()).toList();
      if (alt is List && listEquals(alt.cast<String>(), neu)) return false;
      await prefs.setStringList(schluessel, neu);
      return true;
    }

    // Ein Typ, den die Prefs nicht kennen. Nichts tun ist hier richtiger als
    // etwas zu erfinden.
    assert(false, 'Unbekannter Typ für $schluessel: ${wert.runtimeType}');
    return false;
  }

  /// Präfix der Rotations-Tracker der Fragenauswahl.
  ///
  /// Dieselbe Zeichenkette wie [FortschrittService._rrPrefix]; hier
  /// wiederholt, weil dieser Dienst bewusst nichts aus dem Fortschritt
  /// importiert. Ein Test hält beide Seiten zusammen.
  static const _kRotationsPraefix = 'lp_rr_';

  /// Löscht alles, was in die Cloud gehört — für "Fortschritt zurücksetzen".
  ///
  /// Ton, Sprache und Erinnerungen überleben es: Sie gehören ans Gerät.
  ///
  /// ══ UND DIE ROTATIONS-TRACKER, OBWOHL SIE ANS GERÄT GEHÖREN ═════════════
  ///
  /// `lp_rr_*` merkt sich, welche Länder je Welt und Modus schon abgefragt
  /// wurden. Beim GERÄTEWECHSEL bleiben diese Schlüssel zu Recht liegen
  /// (siehe [geraeteSchluessel] in spielstand.dart) — sie sind JSON-Text, den
  /// eine Vereinigung zerstören würde, und ein neu begonnener Zyklus kostet
  /// nichts.
  ///
  /// Beim LÖSCHEN ist das anders, und das war ein echter Fehler: Ein Zeiger
  /// auf einen abgearbeiteten Zyklus ohne den zugehörigen Fortschritt ist ein
  /// Widerspruch. Und er bleibt nicht folgenlos — sobald ein Kern-Modus
  /// (Flagge, Umriss, Hauptstadt) laut Tracker jedes Land des Pools schon
  /// gebracht hat, gilt er als pensioniert, und
  /// [FragenGenerator.ermittleTatsaechlichenModus] ersetzt ihn zur
  /// Spielzeit durch einen Unterhaltungs-Modus.
  ///
  /// Am Gerät gesehen: Nach dem einmaligen Neustart stand als erste Station
  /// des Lernpfads ein Nachbarland-Quiz statt des angepinnten Flaggen-Quiz.
  /// Der Pfad selbst war unverändert — nur der stehen gebliebene Tracker
  /// sagte weiterhin "Europa Block A, Flaggen: alles durch".
  ///
  /// `allesDatenZuruecksetzen()` räumte sie schon immer mit weg (es geht über
  /// das `lp_`-Präfix). Der Neustart und die Kontolöschung tun es jetzt auch.
  static Future<void> loescheSyncSchluessel() async {
    final prefs = await SharedPreferences.getInstance();
    for (final schluessel in prefs.getKeys().toList()) {
      if (gehoertInDieCloud(schluessel) ||
          schluessel.startsWith(_kRotationsPraefix)) {
        await prefs.remove(schluessel);
      }
    }
  }
}
