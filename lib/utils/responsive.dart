import 'package:flutter/widgets.dart';

/// Zentrales, bildschirmgrößen-abhängiges Skalierungssystem.
///
/// Wird SCHRITTWEISE auf einzelne Screens angewendet (siehe jeweilige
/// Kommentare an den Anwendungsstellen), nicht auf einmal auf die ganze App —
/// die meisten bestehenden Screens sind bewusst für eine feste Handy-Breite
/// kalibriert (siehe z.B. portfolio_investieren_screen.dart, wo eine frühere
/// breitere Spaltenzahl absichtlich auf 2 Spalten zurückgebaut wurde, weil der
/// Karteninhalt sonst überläuft) und dürfen nicht ungeprüft umgestellt
/// werden, nur weil dieses Utility existiert.
class Responsive {
  Responsive._();

  /// Referenz-Breite, für die die bisherigen festen Pixel-Werte in der App
  /// ursprünglich kalibriert wurden (Standard-Handy-Klasse, z.B. iPhone 14/
  /// Pixel). faktor() == 1.0 bei genau dieser Breite.
  static const double _referenzBreite = 390;

  // Verhindert, dass auf sehr großen Tablets alles absurd riesig wird, oder
  // auf sehr kleinen Geräten alles zu winzig/unlesbar.
  static const double _minSkalierung = 0.85;
  static const double _maxSkalierung = 1.4;

  /// Roher Skalierungsfaktor relativ zur Bildschirmbreite, geclamped auf
  /// [_minSkalierung, _maxSkalierung].
  static double faktor(BuildContext context) {
    final breite = MediaQuery.of(context).size.width;
    return (breite / _referenzBreite).clamp(_minSkalierung, _maxSkalierung);
  }

  /// Skaliert einen Pixel-Wert (Breiten, Höhen, Abstände, Radien) linear mit
  /// [faktor].
  static double px(BuildContext context, double basiswert) {
    return basiswert * faktor(context);
  }

  /// Skaliert Schriftgrößen — mit gedämpfter Kurve (nur 60% von [faktor]),
  /// da Text auf großen Bildschirmen nicht 1:1 wie Container-Breiten
  /// mitwachsen soll (sonst wirkt er auf Tablets unproportional riesig).
  static double schrift(BuildContext context, double basiswert) {
    final f = faktor(context);
    final gedaempft = 1.0 + (f - 1.0) * 0.6;
    return basiswert * gedaempft;
  }

  /// Schwelle für "breiteres Gerät" (Tablet-Klasse) — an Flutters eigener
  /// Konvention für den Material-Breakpoint orientiert.
  static bool istTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  /// Sinnvolle Grid-Spaltenzahl je nach Gerätebreite. NICHT blind für JEDES
  /// Grid verwenden: nur dort einsetzen, wo tatsächlich geprüft wurde, dass
  /// der Karteninhalt bei der höheren Spaltenzahl auch bei [tablet]-Breite
  /// nicht überläuft (siehe Klassenkommentar oben).
  static int gridSpalten(BuildContext context,
      {int standard = 2, int tablet = 4}) {
    return istTablet(context) ? tablet : standard;
  }
}

/// Kurzschreibweise für Responsive.px()/Responsive.schrift() — z.B.
/// `width: 78.rpx(context)` oder `fontSize: 16.rsp(context)`.
extension ResponsiveExtension on num {
  double rpx(BuildContext context) => Responsive.px(context, toDouble());
  double rsp(BuildContext context) => Responsive.schrift(context, toDouble());
}
