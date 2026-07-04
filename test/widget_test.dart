import 'package:flutter_test/flutter_test.dart';
import 'package:geomania/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GeoManiaApp());
    expect(find.text('Home'), findsOneWidget);
  });
}
