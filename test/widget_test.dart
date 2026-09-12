import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/main.dart';

void main() {
  testWidgets('Smoke test builds Rythem baseline screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RythemApp());
    expect(find.text('RYTHEM'), findsOneWidget);
  });
}
