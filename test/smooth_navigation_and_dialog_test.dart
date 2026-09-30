import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/widgets/animated_indexed_stack.dart';
import 'package:rythem_app/core/widgets/smooth_dialog.dart';

void main() {
  group('Smooth Navigation & Dialog Tests', () {
    testWidgets('AnimatedIndexedStack switches between tabs and preserves state', (tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: AnimatedIndexedStack(
                  index: activeIndex,
                  children: const [
                    Text('Tab 0 Content'),
                    Text('Tab 1 Content'),
                    Text('Tab 2 Content'),
                  ],
                ),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      activeIndex = 1;
                    });
                  },
                  child: const Icon(Icons.arrow_forward),
                ),
              );
            },
          ),
        ),
      );

      // Initially Tab 0 is rendered
      expect(find.text('Tab 0 Content'), findsOneWidget);

      // Tap to switch to Tab 1
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Tab 1 is now active
      expect(find.text('Tab 1 Content'), findsOneWidget);
    });

    testWidgets('showSmoothDialog displays and closes cleanly returning value', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await showSmoothDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Smooth Dialog Title'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Smooth Dialog Title'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Smooth Dialog Title'), findsNothing);
      expect(dialogResult, isTrue);
    });
  });
}
