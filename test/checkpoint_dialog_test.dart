import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/flow/checkpoint_dialog.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('CheckpointDialog Tests', () {
    final testBeat = BeatEntity(
      id: 'beat_cp_test',
      chapterId: 'ch_test',
      roadmapId: 'rm_test',
      title: 'Multivariable Gradient Descent Optimization',
      effortWeight: 2.0,
      sortOrder: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('renders CheckpointDialog with live effort point calculations and notes input', (tester) async {
      int? savedPercentage;
      String? savedNotes;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CheckpointDialog.show(
                    context,
                    beat: testBeat,
                    initialPercent: 20,
                    initialNotes: 'Watched initial 15 mins',
                    onSaveCheckpoint: (percent, notes) {
                      savedPercentage = percent;
                      savedNotes = notes;
                    },
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

      // Check header and topic title
      expect(find.text('Study Checkpoint'), findsOneWidget);
      expect(find.text('Multivariable Gradient Descent Optimization'), findsOneWidget);

      // Check initial percentage
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('Topic Effort: 2.0 pts'), findsOneWidget);

      // Stepper: tap +10%
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('30%'), findsOneWidget);
      // Earned points: 2.0 * (30 - 20) / 100 = +0.20 pts
      expect(find.text('+0.20 pts earned'), findsOneWidget);

      // Enter notes
      await tester.enterText(
        find.widgetWithText(TextField, 'Watched initial 15 mins'),
        'Completed 3 practice problems and derived Jacobian',
      );
      await tester.pumpAndSettle();

      // Tap Save Checkpoint
      await tester.tap(find.text('Save Checkpoint (30%)'));
      await tester.pumpAndSettle();

      // Verify callback was invoked with updated values
      expect(savedPercentage, 30);
      expect(savedNotes, 'Completed 3 practice problems and derived Jacobian');
      // Dialog dismissed
      expect(find.text('Study Checkpoint'), findsNothing);
    });

    testWidgets('entering 100% switches button to Complete Topic (100%)', (tester) async {
      int? savedPercentage;
      String? savedNotes;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CheckpointDialog.show(
                    context,
                    beat: testBeat,
                    initialPercent: 50,
                    onSaveCheckpoint: (percent, notes) {
                      savedPercentage = percent;
                      savedNotes = notes;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter 100 in the percentage field
      await tester.enterText(find.widgetWithText(TextField, 'Enter 0 - 100'), '100');
      await tester.pumpAndSettle();

      expect(find.text('Complete Topic (100%)'), findsOneWidget);
      // Earned points: 2.0 * (100 - 50) / 100 = +1.00 pts
      expect(find.text('+1.00 pts earned'), findsOneWidget);

      // Tap Complete Topic
      await tester.tap(find.text('Complete Topic (100%)'));
      await tester.pumpAndSettle();

      expect(savedPercentage, 100);
      expect(savedNotes, '');
    });
  });
}
