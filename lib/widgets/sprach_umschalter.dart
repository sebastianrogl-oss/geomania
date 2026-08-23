import 'package:flutter/material.dart';

import '../services/locale_service.dart';

// ── Sprachumschalter für den ersten Start ────────────────────────────────────
//
// Zwei Felder, "DE" und "EN", das aktive grün gefüllt. Bewusst KEINE Flaggen:
// In einer Geografie-App bedeutet eine Flagge "hier geht es um dieses Land" —
// zwei Flaggen oben rechts auf dem allerersten Bildschirm lesen sich wie ein
// Spielelement, nicht wie eine Einstellung. Dazu kommt, dass die Flagge des
// Vereinigten Königreichs für "Englisch" ohnehin eine Hilfskonstruktion ist:
// Englisch ist nicht auf ein Land festgelegt. Buchstaben sagen
// unmissverständlich, worum es geht.
//
// Die Optik folgt dem 3D-Muster der App (dunkler Rand, harter Schatten ohne
// Weichzeichnung), nur zurückgenommen — graue Fläche statt farbiger, damit es
// den Blick nicht vom Namensfeld zieht.

const _kRahmen = Color(0xFF1A1A1A);
const _kAktiv = Color(0xFF4A9E4A);
const _kFlaeche = Color(0xFFEAEAE5);
const _kInaktiveSchrift = Color(0xFF888888);

/// Leitgröße: die Höhe. Alles andere ist ein Verhältnis dazu, damit eine
/// Änderung nicht Schrift, Rundung und Innenabstand einzeln nachzieht.
///
/// 44 statt kleiner, weil das zugleich die Mindest-Tippfläche ist. Ein
/// flacherer Knopf mit unsichtbar vergrößerter Trefferfläche wäre die
/// Alternative gewesen — hier ist der Knopf selbst die Fläche, das ist
/// ehrlicher und spart eine Schicht.
const double _kHoehe = 44;
const double _kFeldBreite = _kHoehe * 1.18;
const double _kSchrift = _kHoehe * 0.32;
const double _kRadius = _kHoehe * 0.27;
const double _kRandStaerke = 2;
const double _kSchattenVersatz = 3;

/// Gesamtbreite — vom Aufrufer gebraucht, um den Platz daneben zu berechnen.
const double sprachUmschalterBreite = _kFeldBreite * 2 + _kRandStaerke * 3;

class SprachUmschalter extends StatelessWidget {
  const SprachUmschalter({super.key});

  @override
  Widget build(BuildContext context) {
    // Hört selbst auf die Sprache, statt sich auf einen Rebuild von aussen zu
    // verlassen: so ist der Umschalter überall einsetzbar und zeigt immer den
    // tatsächlich gespeicherten Stand.
    return ValueListenableBuilder<String>(
      valueListenable: LocaleService.sprache,
      builder: (context, aktuell, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: _kFlaeche,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: _kRahmen, width: _kRandStaerke),
            boxShadow: const [
              BoxShadow(
                color: _kRahmen,
                offset: Offset(0, _kSchattenVersatz),
                blurRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            // Innen um die Randstärke kleiner, sonst schaut die grüne Fläche
            // an den Ecken über den Rahmen hinaus.
            borderRadius: BorderRadius.circular(_kRadius - _kRandStaerke),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Feld(
                  kuerzel: 'DE',
                  aktiv: aktuell == 'de',
                  onTap: () => LocaleService.setzeSprache('de'),
                ),
                const SizedBox(
                  width: _kRandStaerke,
                  height: _kHoehe,
                  child: ColoredBox(color: _kRahmen),
                ),
                _Feld(
                  kuerzel: 'EN',
                  aktiv: aktuell == 'en',
                  onTap: () => LocaleService.setzeSprache('en'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Feld extends StatelessWidget {
  final String kuerzel;
  final bool aktiv;
  final VoidCallback onTap;

  const _Feld({
    required this.kuerzel,
    required this.aktiv,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Das bereits aktive Feld ist bewusst tot: ein erneutes setzeSprache()
      // würde denselben Wert schreiben und die ganze App neu bauen lassen.
      onTap: aktiv ? null : onTap,
      child: Container(
        width: _kFeldBreite,
        height: _kHoehe,
        color: aktiv ? _kAktiv : _kFlaeche,
        alignment: Alignment.center,
        child: Text(
          kuerzel,
          // Die Kürzel sind keine übersetzbaren Texte, sondern feste Marken —
          // sie heissen in beiden Sprachen gleich. Ohne Skalierung, weil der
          // Knopf sonst bei grosser Systemschrift den halben Kopfbereich
          // einnähme; zwei Buchstaben bleiben auch unskaliert gut lesbar.
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: _kSchrift,
            fontWeight: FontWeight.w800,
            color: aktiv ? Colors.white : _kInaktiveSchrift,
          ),
        ),
      ),
    );
  }
}
