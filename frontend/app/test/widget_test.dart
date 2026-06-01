import 'package:flutter_test/flutter_test.dart';
import 'package:lungo_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LungoApp());
    expect(find.byType(LungoApp), findsOneWidget);
  });
}
