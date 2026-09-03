import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:geomania/l10n/uebersetzungen.dart';

/// Der Link zur Datenschutzerklärung in den Einstellungen.
///
/// Google Play verlangt ihn nicht nur im Store-Eintrag, sondern auch IN der
/// App, sobald personenbezogene Daten verarbeitet werden. Fehlt er oder zeigt
/// er ins Leere, ist das ein Befund im Review — und ein toter Link fällt
/// niemandem auf, der ihn nicht anklickt.
void main() {
  final quelle = File('lib/screens/settings_screen.dart').readAsStringSync();

  test('Beide Sprachfassungen sind hinterlegt', () {
    // Die Dateinamen stehen so auch im Repository unter docs/ — wer eine
    // davon umbenennt, muss hier vorbeikommen.
    expect(quelle.contains('geomania/datenschutz.html'), isTrue,
        reason: 'Deutsche Fassung fehlt');
    expect(quelle.contains('geomania/privacy.html'), isTrue,
        reason: 'Englische Fassung fehlt');
  });

  test('Die verlinkten Seiten liegen wirklich im Repository', () {
    // Die Gegenprobe: Ein Link auf eine Seite, die es nicht gibt, wäre auf
    // GitHub Pages eine 404 — und genau das soll hier auffallen, bevor es
    // jemand im Store sieht.
    expect(File('docs/datenschutz.html').existsSync(), isTrue);
    expect(File('docs/privacy.html').existsSync(), isTrue);
  });

  test('Die Sprache entscheidet, welche Fassung geöffnet wird', () {
    // Massgeblich ist die in der App gewählte Sprache. Ohne diese Weiche
    // bekäme ein englischer Nutzer die deutsche Erklärung — formal
    // vorhanden, praktisch unlesbar.
    expect(quelle.contains('LocaleService.istEnglisch ? _kDatenschutzEn'),
        isTrue,
        reason: 'Die Sprachweiche im Datenschutz-Link fehlt');
  });

  test('Der Eintrag steht in den Einstellungen und ist übersetzt', () {
    expect(quelle.contains("t('Datenschutzerklärung')"), isTrue,
        reason: 'Der Eintrag fehlt in der Liste');
    for (final s in ['Datenschutzerklärung', 'Kein Browser gefunden']) {
      expect(uebersetzungen.containsKey(s), isTrue,
          reason: 'Ohne Übersetzung steht hier in der englischen App Deutsch: '
              '"$s"');
    }
  });

  test('Die beiden Seiten verlinken sich gegenseitig', () {
    // Wer auf der falschen Sprachfassung landet — etwa über einen geteilten
    // Link — muss ohne Umweg zur anderen kommen.
    final de = File('docs/datenschutz.html').readAsStringSync();
    final en = File('docs/privacy.html').readAsStringSync();
    expect(de.contains('href="privacy.html"'), isTrue,
        reason: 'Deutsche Seite verlinkt die englische nicht');
    expect(en.contains('href="datenschutz.html"'), isTrue,
        reason: 'Englische Seite verlinkt die deutsche nicht');
  });

  test('Beide Seiten nennen die Kontolöschung', () {
    // Der Abschnitt, den Apple 5.1.1(v) und Google Play sehen wollen.
    expect(File('docs/datenschutz.html').readAsStringSync().contains('Konto löschen'),
        isTrue);
    expect(File('docs/privacy.html').readAsStringSync().contains('Deleting your account'),
        isTrue);
  });
}
