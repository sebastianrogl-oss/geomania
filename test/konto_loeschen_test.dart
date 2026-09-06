import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/l10n/uebersetzungen.dart';
import 'package:geomania/services/auth_service.dart';

/// Die Kontolöschung ist keine Bequemlichkeitsfunktion, sondern eine Auflage:
/// Apple verlangt sie in Guideline 5.1.1(v), Google Play in den Vorgaben zur
/// Datenlöschung. Fehlt sie oder ist sie halb übersetzt, wird die App
/// abgelehnt — und das merkt man erst nach der Einreichung.
void main() {
  test('Der Fall "erneut anmelden" hat einen eigenen Ausgang', () {
    // Firebase verlangt für das Löschen eine frische Anmeldung
    // ('requires-recent-login'). Würde das als gewöhnlicher Fehler
    // durchgereicht, sähe der Nutzer "hat nicht geklappt" und wüsste nicht,
    // dass er nur einmal ab- und wieder anmelden muss.
    expect(KontoLoeschErgebnis.values, hasLength(3));
    expect(KontoLoeschErgebnis.values, contains(KontoLoeschErgebnis.erneutAnmelden));
  });

  test('Alle Texte der Kontolöschung sind auf Englisch hinterlegt', () {
    // Die Texte stehen hier ausgeschrieben und nicht aus dem Screen gelesen:
    // Wer einen davon ändert, soll den Test anfassen müssen — genau dann ist
    // nämlich auch die Übersetzung fällig.
    const texte = [
      'Konto löschen',
      'Konto löschen?',
      'Dein Konto wird endgültig gelöscht: dein Name, dein Platz in den '
          'Ranglisten und dein in der Cloud gesicherter Spielstand. Das lässt '
          'sich nicht rückgängig machen.',
      'Dein Fortschritt auf diesem Gerät bleibt erhalten. Alles in der Cloud — '
          'Konto, Name und Rangliste — ist danach unwiderruflich weg.',
      'Endgültig löschen',
      'Bitte neu anmelden',
      'Aus Sicherheitsgründen ist das Löschen nur kurz nach einer Anmeldung '
          'möglich. Melde dich einmal ab und wieder an, dann klappt es.',
      'Löschen fehlgeschlagen',
      'Löschen nicht möglich — bitte später noch einmal versuchen.',
      'Das meldet das Gerät:',
    ];

    final fehlend = texte.where((s) => !uebersetzungen.containsKey(s)).toList();
    expect(fehlend, isEmpty,
        reason: 'Ohne Übersetzung zeigt die englische App hier Deutsch:\n'
            '${fehlend.join('\n')}');
  });

  test('Der Screen benutzt genau diese Texte', () {
    // Die Gegenprobe zum Test darüber: Er prüft, dass die Liste übersetzt
    // ist — aber nicht, dass sie noch zum Screen passt. Ein umformulierter
    // Dialogtext wäre sonst unübersetzt, und der Test bliebe grün.
    final quelle = File('lib/screens/settings_screen.dart').readAsStringSync();
    for (final s in [
      'Konto löschen?',
      'Endgültig löschen',
      'Bitte neu anmelden',
      'Löschen fehlgeschlagen',
      'Das meldet das Gerät:',
    ]) {
      expect(quelle.contains(s), isTrue,
          reason: 'Der Text "$s" steht nicht mehr im Screen — dann stimmt die '
              'Liste in diesem Test nicht mehr');
    }
  });

  test('Die Löschung räumt auch die Unterkollektion weg', () {
    // Ein Firestore-Dokument zu löschen entfernt seine Unterkollektionen
    // NICHT. Ohne den ausdrücklichen Griff nach spieler/{uid}/stand/aktuell
    // bliebe der Cloud-Spielstand als verwaister Datenmüll liegen — den
    // niemand mehr wegbekommt, weil die Regeln dafür ein angemeldetes Konto
    // verlangen, das es dann nicht mehr gibt.
    final rumpf = _rumpf('static Future<KontoLoeschAusgang> kontoLoeschen');
    expect(rumpf.contains("collection('stand')"), isTrue,
        reason: 'Der Cloud-Spielstand wird beim Löschen nicht mit entfernt');

    // Und die Reihenfolge: Unterkollektion vor Elterndokument vor Auth-Konto.
    final stand = rumpf.indexOf('KontoLoeschSchritt.spielstand');
    final spieler = rumpf.indexOf('KontoLoeschSchritt.spielerDokument');
    final konto = rumpf.indexOf('KontoLoeschSchritt.konto');
    expect(stand, greaterThan(0));
    expect(stand, lessThan(spieler),
        reason: 'Unterkollektion muss vor dem Elterndokument weg');
    expect(spieler, lessThan(konto),
        reason: 'Nach u.delete() ist niemand mehr angemeldet — die Regeln '
            'liessen das Aufräumen dann nicht mehr zu');
  });

  // ── Sichtbare Fehler ──────────────────────────────────────────────────────
  //
  // Aus dem TestFlight-Test (Build 18): "Beide Rückfragen lassen sich
  // durchdrücken, danach passiert nichts." Kein Anmelde-Screen, kein Konto
  // weg, keine Meldung. Ein Fehlschlag, den man nicht sieht, ist aus der
  // Ferne nicht zu finden — die Prüfungen hier halten fest, was dagegen
  // gebaut wurde.

  test('Jeder Schritt hat ein Zeitlimit', () {
    // OHNE DAS PASSIERT BEI EINEM FEHLSCHLAG BUCHSTÄBLICH NICHTS: Firestore
    // löst ein Schreib-Future erst auf, wenn der Server bestätigt hat. Ohne
    // tragfähige Verbindung wartet es unbegrenzt — kein Fehler, keine
    // Ausnahme, nie eine Antwort. Genau das Bild, das gemeldet wurde.
    final rumpf = _rumpf('static Future<KontoLoeschAusgang?> _loeschSchritt');
    expect(rumpf.contains('.timeout(_kSchrittZeitlimit)'), isTrue,
        reason: 'Ein hängender Schritt bliebe unsichtbar');
  });

  test('Jeder Ausgang trägt Stufe und Fehlercode', () {
    // Ein blosses "hat nicht geklappt" hat die letzte Runde gekostet: Es
    // deckt Regelverstoss, Verbindungsabbruch und "die Anmeldung ist zu
    // lange her" gleichermassen ab.
    const a = KontoLoeschAusgang(KontoLoeschErgebnis.fehler,
        schritt: KontoLoeschSchritt.spielstand,
        befund: 'firestore/permission-denied');
    expect(a.technischerText, '2 Cloud-Spielstand · firestore/permission-denied');

    // Und bei Erfolg steht nichts da, was niemand braucht.
    expect(KontoLoeschAusgang.erfolgreich.technischerText, isEmpty);
  });

  test('Die Stufen sind in der Reihenfolge der Kette nummeriert', () {
    // Die Nummer im Text ist die Stelle in der Kette. Wer eine Stufe
    // einschiebt und die Nummern vergisst, macht den Befund unlesbar.
    final stufen = KontoLoeschSchritt.values;
    for (var i = 0; i < stufen.length; i++) {
      expect(stufen[i].bezeichnung.startsWith('${i + 1} '), isTrue,
          reason: '${stufen[i].name} heisst "${stufen[i].bezeichnung}"');
    }
  });

  test('Die Namens-Reservierung hält die Kette nicht auf', () {
    // Apple 5.1.1(v) lässt keinen Fall zu, in dem ein Konto unlöschbar ist.
    // Ein liegen gebliebener reservierter Name ist ärgerlich — ein Konto,
    // das sich nicht löschen lässt, kostet die Freigabe.
    final rumpf = _rumpf('static Future<KontoLoeschAusgang> kontoLoeschen');
    final reservierung = rumpf.indexOf('KontoLoeschSchritt.reservierung');
    final abbruch = rumpf.indexOf('if (stand != null) return stand;');
    expect(reservierung, greaterThan(0));
    expect(abbruch, greaterThan(reservierung),
        reason: 'Der erste Schritt darf nicht mit return abbrechen');
    // Zwischen Schritt 1 und dem ersten Abbruch steht KEIN return.
    expect(rumpf.substring(reservierung, abbruch).contains('return '), isFalse,
        reason: 'Ein Fehlschlag bei der Reservierung bricht die Löschung ab');
  });

  test('Die Reservierung wird erst gelesen, dann gelöscht', () {
    // firestore.rules erlauben delete nur mit
    // `resource.data.uid == request.auth.uid`. Auf ein Dokument, das es gar
    // nicht gibt, ist `resource` null — der Löschversuch scheitert dann mit
    // permission-denied, obwohl nichts aufzuräumen war. Dieselbe Falle hat
    // schon einmal die Namensvergabe zerlegt.
    final rumpf = _rumpf('static Future<void> _reservierungFreigeben');
    final lesen = rumpf.indexOf('ref.get()');
    final loeschen = rumpf.indexOf('ref.delete()');
    expect(lesen, greaterThan(0), reason: 'Es wird blind gelöscht');
    expect(lesen, lessThan(loeschen));
    expect(rumpf.contains("vorhanden.data()?['uid'] == u.uid"), isTrue,
        reason: 'Eine fremde Reservierung darf nicht gelöscht werden');
  });
}

/// Liest den Rumpf einer Methode aus auth_service.dart — von ihrer Signatur
/// bis zur nächsten Methode.
///
/// Vorher stand hier ein fester Ausschnitt von 2000 Zeichen. Der reicht
/// genau so lange, bis jemand einen Kommentar ergänzt: Dann rutschen die
/// gesuchten Zeilen aus dem Fenster, und der Test wird grün, ohne noch etwas
/// zu prüfen.
String _rumpf(String signatur) {
  final quelle = File('lib/services/auth_service.dart').readAsStringSync();
  final ab = quelle.indexOf(signatur);
  if (ab < 0) throw StateError('Nicht gefunden: $signatur');
  final bis = quelle.indexOf('\n  static ', ab + signatur.length);
  return quelle.substring(ab, bis < 0 ? quelle.length : bis);
}
