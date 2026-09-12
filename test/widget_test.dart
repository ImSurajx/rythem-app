import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/main.dart';
import 'package:rythem_app/core/widgets/widgets.dart';

void main() {
  testWidgets('Design system showcase renders brand and liquid glass widgets', (WidgetTester tester) async {
    await tester.pumpWidget(const RythemApp());
    await tester.pump();

    // Verify brand typography
    expect(find.text('RYTHEM'), findsOneWidget);
    expect(find.text('beats over clocks • felt, not measured'), findsOneWidget);

    // Verify glass components
    expect(find.byType(GlassContainer), findsWidgets);
    expect(find.byType(GlassCard), findsWidgets);
    expect(find.byType(GlassButton), findsWidgets);
    expect(find.byType(GlassProgressBar), findsOneWidget);

    // Verify interactive beat advance button
    final advanceButton = find.text('Advance Beat');
    expect(advanceButton, findsOneWidget);

    await tester.ensureVisible(advanceButton);
    await tester.pumpAndSettle();
    await tester.tap(advanceButton);
    await tester.pumpAndSettle();

    // Verify progress updated
    expect(find.text('4 of 7 beats completed'), findsOneWidget);
  });
}
