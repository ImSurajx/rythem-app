import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/flow/checkpoint_dialog.dart';
import 'package:rythem_app/features/flow/confusing_beat_dialog.dart';

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
      expect(find.text('Topic Beats: 2.0 beats'), findsOneWidget);

      // Stepper: tap +10%
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('30%'), findsOneWidget);
      // Earned points: 2.0 * (30 - 20) / 100 = +0.20 beats
      expect(find.text('+0.20 beats earned'), findsOneWidget);

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
      // Earned points: 2.0 * (100 - 50) / 100 = +1.00 beats
      expect(find.text('+1.00 beats earned'), findsOneWidget);

      // Tap Complete Topic
      await tester.tap(find.text('Complete Topic (100%)'));
      await tester.pumpAndSettle();

      expect(savedPercentage, 100);
      expect(savedNotes, '');
    });

    testWidgets('Clear Note button in CheckpointDialog clears practice notes', (tester) async {
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
                    initialPercent: 40,
                    initialNotes: 'Existing reflection note',
                    onSaveCheckpoint: (_, __) {},
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

      expect(find.text('Clear Note'), findsOneWidget);
      expect(find.text('Existing reflection note'), findsOneWidget);

      await tester.tap(find.text('Clear Note'));
      await tester.pumpAndSettle();

      expect(find.text('Existing reflection note'), findsNothing);
      expect(find.text('Clear Note'), findsNothing);
    });
  });

  group('ConfusingBeatDialog Delete Flag Tests', () {
    final testBeat = BeatEntity(
      id: 'beat_flag_del_test',
      chapterId: 'ch_test',
      roadmapId: 'rm_test',
      title: 'Backpropagation on Computation Graphs',
      effortWeight: 1.5,
      sortOrder: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('renders Remove Flag button when initialNote is present and triggers onDelete', (tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ConfusingBeatDialog.show(
                    context,
                    beat: testBeat,
                    initialNote: 'Got stuck on chain rule application',
                    onDelete: () {
                      deleteCalled = true;
                    },
                    onFlagSaved: (_) {},
                  );
                },
                child: const Text('Open Flag Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Flag Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('FLAG FRICTION / CONFUSION'), findsOneWidget);
      expect(find.text('Remove Flag'), findsOneWidget);

      await tester.tap(find.text('Remove Flag'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
      expect(find.text('FLAG FRICTION / CONFUSION'), findsNothing);
    });
  });
}
