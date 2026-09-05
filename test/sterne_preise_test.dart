import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/data/lernpfad_data.dart';
import 'package:geomania/services/profilbild_service.dart';

// ── Die Sterne-Preise gegen die erreichbare Sternsumme ───────────────────────
//
// Die vier Profilbilder der dritten Reihe kosten Sterne. Ihre Preise sind
// ANTEILE der Gesamtsumme, keine absoluten Zahlen: Das teuerste Bild soll rund
// die Hälfte aller je erreichbaren Sterne kosten, alle vier zusammen rund 85 %.
//
// Die Gesamtsumme hängt an drei Stellen in lernpfad_data.dart — fragenProStation
// je Welt, kFragenObergrenze je Modus und der Modus-Verteilung. Wer dort etwas
// ändert, verschiebt die Preise, ohne sie anzufassen. Genau das ist zweimal
// passiert: Die Staffel rutschte einmal auf 94 %, und beim Kürzen der
// Spiel-Modi wäre sie auf 95 % gelaufen.
//
// Dieser Test ist die Bremse dafür. Schlägt er an, ist nichts kaputt — es
// müssen nur die Preise nachgezogen werden.

void main() {
  final preise = ProfilbildService.sternePreise.values.toList()..sort();
  final summe = preise.fold(0, (a, b) => a + b);

  test('Die Sternsumme ist die erwartete', () {
    // Reine Absicherung der Rechengrundlage: Ändert sie sich, sollen die
    // Anteils-Prüfungen unten nicht stillschweigend gegen eine andere Basis
    // laufen.
    // 3988 vor der Europa-Erweiterung: Der Meister-Abschnitt wuchs von 25 auf
    // 29 Stationen und brachte 26 Sterne mit.
    // 4014 davor: Seit die erste Station JEDER Welt fest ein Flaggen-Quiz ist
    // (statt nur die allererste des Pfads), verschob sich die Modus-Verteilung
    // um zwei Sterne nach unten. Die Anteils-Prüfungen darunter blieben dabei
    // im Rahmen — nachgezogen wird deshalb nur die Rechengrundlage.
    expect(kErreichbareSterne, 4012,
        reason: 'Die erreichbaren Sterne haben sich geändert — Preise prüfen');
  });

  test('Das teuerste Bild kostet rund die Hälfte aller Sterne', () {
    final anteil = preise.last / kErreichbareSterne;
    expect(anteil, closeTo(0.49, 0.03),
        reason: 'teuerstes Bild: ${(anteil * 100).toStringAsFixed(1)} % '
            'von $kErreichbareSterne');
  });

  test('Alle vier zusammen kosten rund 85 % aller Sterne', () {
    final anteil = summe / kErreichbareSterne;
    expect(anteil, closeTo(0.85, 0.03),
        reason: 'alle vier: ${(anteil * 100).toStringAsFixed(1)} % '
            'von $kErreichbareSterne');
  });

  test('Die Staffel steigt', () {
    // Vier Preise, die sich deutlich unterscheiden — sonst wäre die Reihe
    // keine Staffel, sondern vier fast gleich teure Bilder.
    for (var i = 1; i < preise.length; i++) {
      expect(preise[i], greaterThan(preise[i - 1] * 1.5),
          reason: 'Stufe $i ist kaum teurer als die davor: $preise');
    }
  });

  test('Das erste Bild ist früh erreichbar', () {
    // Es soll motivieren, nicht am Ende stehen: unter 5 % der Gesamtsumme,
    // also nach gut zwanzig Stationen.
    expect(preise.first / kErreichbareSterne, lessThan(0.05));
  });
}
