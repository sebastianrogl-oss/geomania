import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/services/spielstand.dart';

/// ── Kein Schlüssel darf durch die Ritzen fallen ─────────────────────────────
///
/// Die Synchronisierung kennt zwei Listen: was in die Cloud geht
/// ([syncPraefixe]) und was bewusst am Gerät bleibt ([nurGeraetPraefixe]).
/// Ein neuer Speicher-Schlüssel, der in keiner von beiden steht, wäre der
/// heimtückischste Fehler dieses Umbaus: Er würde stillschweigend nicht
/// übertragen, und es fiele erst auf, wenn jemand das Gerät wechselt und
/// etwas fehlt.
///
/// Deshalb liest dieser Test den Quelltext und sucht die ECHTEN
/// Speicherzugriffe — `prefs.getX(...)`, `setX(...)`, `remove(...)`. Das
/// Argument wird aufgelöst: eine Konstante über ihren Wert, ein
/// Schlüssel-Bauer über den festen Anfang seines Rückgabewerts. Aus
/// `'${_rrPrefix}ord_${weltId}_$modusKey'` wird so `lp_rr_ord_`.
///
/// Ein früherer Entwurf sammelte einfach alle `static const`-Zeichenketten.
/// Der fand prompt eine Android-Kanal-Kennung, die nie in den Prefs landet —
/// darum jetzt der Umweg über die Aufrufe.
///
/// Schlägt der Test fehl, ist das eine Frage, keine Panne: Gehört der neue
/// Wert zum Konto oder zum Gerät? Raten wäre hier das Schlimmste.
void main() {
  test('Jeder Speicher-Schlüssel ist eingeordnet', () {
    final gefunden = _speicherSchluesselAusQuelltext();

    expect(gefunden, isNotEmpty,
        reason: 'Der Test findet gar keine Schlüssel mehr — dann passen die '
            'Muster nicht mehr zum Quelltext und er prüft nichts');

    final offen = <String>[];
    gefunden.forEach((schluessel, datei) {
      final abgedeckt = [...syncPraefixe, ...nurGeraetPraefixe]
          .any((p) => schluessel.startsWith(p));
      if (!abgedeckt) offen.add('  $schluessel   (aus $datei)');
    });

    expect(offen, isEmpty,
        reason: 'Diese Schlüssel stehen weder in syncPraefixe noch in '
            'nurGeraetPraefixe:\n${offen.join('\n')}\n\n'
            'Gehört der Wert zum Konto (dann in die passende Regel-Liste) '
            'oder zum Gerät (dann nach nurGeraetPraefixe)?');
  });

  test('Keine Doppelnennung zwischen Cloud und Gerät', () {
    // Ein Schlüssel in beiden Listen hätte zwei Regeln — welche gilt,
    // entschiede die Reihenfolge im Code. Das wäre stiller Zufall.
    final doppelt =
        syncPraefixe.where((s) => nurGeraetPraefixe.contains(s)).toList();
    expect(doppelt, isEmpty, reason: 'Doppelt eingeordnet: $doppelt');
  });

  test('Kein Präfix zeigt ins Leere', () {
    // Die Gegenrichtung: Ein Präfix, den es im Quelltext gar nicht gibt, ist
    // ein Tippfehler — und ein Tippfehler in nurGeraetPraefixe wäre besonders
    // tückisch, weil er wie eine bewusste Entscheidung aussieht, aber nichts
    // abdeckt. (Genau so ein Fall, `daily_resume_` statt `ch_resume_`, ist
    // hier tatsächlich aufgeflogen.)
    //
    // Geprüft wird gegen den ROHEN Quelltext, nicht gegen die aufgelösten
    // Schlüssel: Manche Schlüssel erreichen die Prefs über einen Parameter
    // (`_zieheTexte(_kBeutelTaeglich, ...)`) und lassen sich statisch nicht
    // bis zum Aufruf verfolgen. Ihr Name steht aber im Quelltext.
    final quelle = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('spielstand'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final tote = [...syncPraefixe, ...nurGeraetPraefixe]
        .where((p) => !quelle.contains(p))
        .toList();
    expect(tote, isEmpty,
        reason: 'Diese Präfixe kommen im Quelltext nicht vor — Tippfehler '
            'oder Überbleibsel?\n$tote');
  });
}

// ── Quelltext lesen ─────────────────────────────────────────────────────────

/// Alle Schlüssel (bzw. deren fester Anfang) mitsamt Fundstelle.
Map<String, String> _speicherSchluesselAusQuelltext() {
  final raus = <String, String>{};

  for (final datei in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    // Der Sync-Dienst führt die Listen; seine eigenen Zugriffe laufen über
    // Variablen und sind hier nichts als Rauschen.
    if (datei.path.contains('spielstand')) continue;
    final inhalt = datei.readAsStringSync();
    if (!inhalt.contains('SharedPreferences')) continue;

    final konstanten = _konstanten(inhalt);
    final bauer = _schluesselBauer(inhalt, konstanten);
    final name = datei.uri.pathSegments.last;

    for (final m in _prefsAufruf.allMatches(inhalt)) {
      final literal = m.group(1);
      final bezeichner = m.group(2);
      final istAufruf = m.group(3) != null;

      String? schluessel;
      if (literal != null) {
        schluessel = _festerAnfang(literal, konstanten);
      } else if (bezeichner != null) {
        final wert = istAufruf ? bauer[bezeichner] : konstanten[bezeichner];
        // Auch hier auflösen: Eine Zwischenvariable trägt oft selbst noch
        // einen Platzhalter (`final key = 'dc_$kategorie';`).
        schluessel = wert == null ? null : _festerAnfang(wert, konstanten);
      }
      if (schluessel != null && schluessel.isNotEmpty) {
        raus.putIfAbsent(schluessel, () => name);
      }
    }
  }
  return raus;
}

/// `prefs.getString('x')`, `prefs.setBool(_kFoo, ...)`, `prefs.remove(_key(id))`
final _prefsAufruf = RegExp(
    r"\.(?:getString|getInt|getBool|getDouble|getStringList"
    r"|setString|setInt|setBool|setDouble|setStringList"
    r"|remove|containsKey)"
    r"\(\s*(?:'([^']*)'|([A-Za-z_]\w*)\s*(\()?)");

/// `static const _kFoo = 'wert';` und lokale `final key = 'wert';`
Map<String, String> _konstanten(String inhalt) {
  final raus = <String, String>{};
  for (final m in RegExp(r"static const(?:\s+String)?\s+(_\w+)\s*=\s*'([^']*)'")
      .allMatches(inhalt)) {
    raus[m.group(1)!] = m.group(2)!;
  }
  // Lokale Zwischenvariablen: `final key = 'lernen_days_$cat';`
  for (final m
      in RegExp(r"final\s+(\w+)\s*=\s*'([^']*)'\s*;").allMatches(inhalt)) {
    raus.putIfAbsent(m.group(1)!, () => m.group(2)!);
  }
  return raus;
}

/// `static String _fooKey(...) => 'ch_rekord_$id';` — mit und ohne Rumpf.
Map<String, String> _schluesselBauer(
    String inhalt, Map<String, String> konstanten) {
  final raus = <String, String>{};
  for (final m in RegExp(r"static String (_\w+)\([^)]*\)\s*=>\s*'([^']*)'")
      .allMatches(inhalt)) {
    raus[m.group(1)!] = _festerAnfang(m.group(2)!, konstanten);
  }
  // Mit Rumpf: der erste `return '...'` nach dem Kopf.
  for (final m
      in RegExp(r"static String (_\w+)\([^)]*\)\s*\{").allMatches(inhalt)) {
    final rest = inhalt.substring(m.end);
    final r = RegExp(r"return\s+'([^']*)'").firstMatch(rest);
    if (r != null) {
      raus.putIfAbsent(m.group(1)!, () => _festerAnfang(r.group(1)!, konstanten));
    }
  }
  return raus;
}

/// Der feste Anfang einer Zeichenkette mit Platzhaltern.
///
/// Läuft von links und sammelt, was sicher im Schlüssel steht. Eine
/// eingesetzte Konstante zählt zum festen Teil, eine Variable beendet ihn —
/// ab dort ist der Rest zur Laufzeit beliebig.
String _festerAnfang(String literal, Map<String, String> konstanten) {
  final b = StringBuffer();
  var i = 0;
  while (i < literal.length) {
    final z = literal[i];
    if (z != r'$') {
      b.write(z);
      i++;
      continue;
    }
    // Platzhalter: `$name` oder `${name}`
    i++;
    var name = '';
    if (i < literal.length && literal[i] == '{') {
      final zu = literal.indexOf('}', i);
      if (zu < 0) break;
      name = literal.substring(i + 1, zu);
      i = zu + 1;
    } else {
      final start = i;
      while (i < literal.length && RegExp(r'\w').hasMatch(literal[i])) {
        i++;
      }
      name = literal.substring(start, i);
    }
    final wert = konstanten[name];
    if (wert == null) break; // Variable — hier endet der feste Teil.
    b.write(wert);
  }
  return b.toString();
}
