import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:geomania/widgets/maskottchen_animation.dart';

/// Die Lottie-Leinwand (720 × 405) ist breiter als der Kreis, in dem sie
/// sitzt. Zweimal stand die Münze deshalb schon schief im Rahmen:
///
///  1. Mit einem Transform.translate um FESTE -75 Pixel — nach Augenmass für
///     den Anzeigename-Screen (200) gesetzt, bei kleineren Kreisen daneben.
///  2. Nach dessen Entfernung durch BoxFit.cover, das Lottie nicht richtig
///     umsetzt: der berechnete Ausschnitt wird beim Zeichnen ignoriert, die
///     Leinwand landet linksbündig, die Münze rutscht rechts aus dem Kreis.
///
/// Beide Male fiel es erst auf dem Gerät auf. Der Test prüft darum das eine,
/// was in beiden Fällen verletzt war: die Leinwand liegt waagerecht MITTIG
/// über dem Kreis, und zwar bei jeder tatsächlich genutzten Grösse.
void main() {
  const groessen = [96.0, 120.0, 170.0, 200.0];

  for (final g in groessen) {
    testWidgets('Leinwand sitzt mittig im Kreis (Grösse $g)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: MaskottchenAnimation(groesse: g)),
          ),
        ),
      );

      final rahmen = find.byType(MaskottchenAnimation);
      final leinwand = find.byType(LottieBuilder);

      expect(tester.getSize(rahmen), Size(g, g), reason: 'Kreis bleibt rund');

      // Volle Leinwandbreite, nichts von Lottie selbst beschnitten — sonst
      // greift wieder dessen kaputter cover-Pfad.
      expect(
        tester.getSize(leinwand).width,
        moreOrLessEquals(g * 720 / 405, epsilon: 0.5),
        reason: 'Leinwand behält ihr Seitenverhältnis',
      );
      expect(tester.getSize(leinwand).height, moreOrLessEquals(g, epsilon: 0.5));

      // Der eigentliche Punkt: gleich viel Überstand links wie rechts.
      expect(
        tester.getCenter(leinwand).dx,
        moreOrLessEquals(tester.getCenter(rahmen).dx, epsilon: 0.5),
        reason: 'Leinwand mittig über dem Kreis',
      );
    });
  }
}
