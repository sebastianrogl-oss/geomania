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
      'Löschen nicht möglich — bitte später noch einmal versuchen.',
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
    for (final s in ['Konto löschen?', 'Endgültig löschen', 'Bitte neu anmelden']) {
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
    final quelle = File('lib/services/auth_service.dart').readAsStringSync();
    final ab = quelle.indexOf('static Future<KontoLoeschErgebnis> kontoLoeschen');
    expect(ab, greaterThan(0));
    final rumpf = quelle.substring(ab, ab + 2000);
    expect(rumpf.contains("collection('stand')"), isTrue,
        reason: 'Der Cloud-Spielstand wird beim Löschen nicht mit entfernt');

    // Und die Reihenfolge: Unterkollektion vor Elterndokument vor Auth-Konto.
    final stand = rumpf.indexOf("collection('stand')");
    final spieler = rumpf.indexOf("collection('spieler').doc(u.uid).delete()");
    final konto = rumpf.indexOf('u.delete()');
    expect(stand, lessThan(spieler),
        reason: 'Unterkollektion muss vor dem Elterndokument weg');
    expect(spieler, lessThan(konto),
        reason: 'Nach u.delete() ist niemand mehr angemeldet — die Regeln '
            'liessen das Aufräumen dann nicht mehr zu');
  });
}
