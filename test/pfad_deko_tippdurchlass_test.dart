import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/widgets/pfad_deko_layer.dart';
import 'package:geomania/widgets/pfad_maskottchen.dart';

// ── Die Deko des Lernpfads darf keine Tipps abfangen ─────────────────────────
//
// HINTERGRUND: Coiny und Globus hängen ZULETZT im Stack des Lernpfads, und
// zuletzt gezeichnet heisst in Flutter zuerst getroffen. Ihr Kasten ist
// quadratisch und so gross wie die längste Kante der Bilddatei — bei Coiny
// 264,6 dp, wovon die Figur nur einen Bruchteil einnimmt. Der Rest ist
// durchsichtig, wird aber von RenderImage trotzdem als Treffer gemeldet.
//
// Dadurch lag eine unsichtbare tote Zone über den Stationsbuttons neben der
// Figur: Am Gerät waren rund 40 % des Buttons eine Position über dem Anker
// nicht mehr antippbar. Für den Spieler sah das aus wie "der Button reagiert
// oft erst beim zweiten Tippen".
//
// Der Test prüft die Eigenschaft, an der es lag, nicht die Stapelreihenfolge:
// Ein Tipp mitten auf die Deko muss bei dem ankommen, was darunter liegt.
// Damit greift er auch dann noch, wenn der Pfad seine Overlays später anders
// anordnet.

void main() {
  const schirmBreite = 384.0;
  const schirmHoehe = 800.0;

  /// Baut die Deko über eine bildschirmfüllende Tippfläche und meldet, ob ein
  /// Tipp an [stelle] unten ankommt.
  Future<bool> kommtDurch(
    WidgetTester tester,
    List<Widget> deko,
    Offset stelle,
  ) async {
    var angekommen = false;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: schirmBreite,
          height: schirmHoehe,
          child: Stack(
            children: [
              // Steht für den Stationsbutton: nimmt jeden Tipp an, der ihn
              // erreicht.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => angekommen = true,
                ),
              ),
              // ... und darüber die Deko, genau wie im Lernpfad.
              ...deko,
            ],
          ),
        ),
      ),
    ));
    await tester.tapAt(stelle);
    await tester.pump();
    return angekommen;
  }

  /// Die Stellen, an denen geprüft wird: die Mitte des Deko-Kastens und seine
  /// vier Ecken (leicht nach innen versetzt). Die Mitte liegt auf der Figur
  /// selbst, die Ecken im durchsichtigen Rand — beides muss durchfallen.
  ///
  /// Was ausserhalb des Schirms liegt, fällt weg: Coiny hängt bewusst über den
  /// Rand hinaus (siehe _kCoinyNachAussen), und dorthin kann niemand tippen.
  List<Offset> stellen(Rect kasten) {
    const schirm = Rect.fromLTWH(0, 0, schirmBreite, schirmHoehe);
    return [
      kasten.center,
      kasten.topLeft + const Offset(6, 6),
      kasten.topRight + const Offset(-6, 6),
      kasten.bottomLeft + const Offset(6, -6),
      kasten.bottomRight + const Offset(-6, -6),
    ].where(schirm.contains).toList();
  }

  Rect kastenVon(WidgetTester tester) {
    final bild = find.byType(Image).first;
    return Rect.fromLTWH(
      tester.getTopLeft(bild).dx,
      tester.getTopLeft(bild).dy,
      tester.getSize(bild).width,
      tester.getSize(bild).height,
    );
  }

  group('Coiny lässt Tipps durch', () {
    testWidgets('an jeder Stelle seines Kastens', (tester) async {
      tester.view.physicalSize = const Size(schirmBreite, schirmHoehe);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final deko = pfadMaskottchenOverlays(
        abschnitte: [(pos: const Offset(100, 400), stufe: 1)],
        screenWidth: schirmBreite,
      );
      expect(deko, hasLength(1));

      await kommtDurch(tester, deko, Offset.zero);
      final kasten = kastenVon(tester);
      // Der Kasten muss gross genug sein, um Nachbarn zu überdecken — sonst
      // prüfte der Test etwas Harmloses.
      expect(kasten.width, greaterThan(200));

      for (final stelle in stellen(kasten)) {
        expect(
          await kommtDurch(tester, deko, stelle),
          isTrue,
          reason: 'Coiny fängt den Tipp bei $stelle ab',
        );
      }
    });
  });

  group('Globus lässt Tipps durch', () {
    testWidgets('an jeder Stelle seines Kastens', (tester) async {
      tester.view.physicalSize = const Size(schirmBreite, schirmHoehe);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final deko = pfadGlobusOverlays(
        abschnitte: [(pos: const Offset(280, 400), stufe: 1)],
        screenWidth: schirmBreite,
      );
      expect(deko, hasLength(1));

      await kommtDurch(tester, deko, Offset.zero);
      final kasten = kastenVon(tester);
      expect(kasten.width, greaterThan(200));

      for (final stelle in stellen(kasten)) {
        expect(
          await kommtDurch(tester, deko, stelle),
          isTrue,
          reason: 'Globus fängt den Tipp bei $stelle ab',
        );
      }
    });
  });

  group('Wahrzeichen lassen Tipps durch', () {
    // Die Wahrzeichen liegen im Lernpfad UNTER den Buttons und waren nie das
    // Problem. Geprüft werden sie trotzdem: Damit bleibt die Aussage "Deko
    // fängt nichts ab" vollständig, auch wenn die Stapelreihenfolge sich
    // einmal ändert.
    testWidgets('über die ganze Fläche', (tester) async {
      tester.view.physicalSize = const Size(schirmBreite, schirmHoehe);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final deko = pfadDekoOverlays(
        kontinentId: 'europa',
        allePositionen: [
          for (var i = 0; i < 12; i++) Offset(i.isEven ? 120 : 264, 80.0 * i),
        ],
        stationenProAbschnitt: [
          [
            for (var i = 0; i < 12; i++)
              Offset(i.isEven ? 120 : 264, 80.0 * i),
          ],
        ],
        screenWidth: schirmBreite,
      );
      if (deko.isEmpty) return; // keine Wahrzeichen für diese Lage

      await kommtDurch(tester, deko, Offset.zero);
      for (final bild in find.byType(Image).evaluate()) {
        final kasten = Rect.fromLTWH(
          tester.getTopLeft(find.byWidget(bild.widget)).dx,
          tester.getTopLeft(find.byWidget(bild.widget)).dy,
          tester.getSize(find.byWidget(bild.widget)).width,
          tester.getSize(find.byWidget(bild.widget)).height,
        );
        expect(
          await kommtDurch(tester, deko, kasten.center),
          isTrue,
          reason: 'Ein Wahrzeichen fängt den Tipp bei ${kasten.center} ab',
        );
      }
    });
  });
}
