import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/features/explore/widgets/chapter_accordion.dart';

void main() {
  testWidgets('ChapterAccordion renders inline confirm/reject prompt for ambiguous matches',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final chapter = ChapterEntity(
      id: 'ch_1',
      roadmapId: 'rm_1',
      title: 'Chapter 1: Algorithms',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );

    // Ambiguous match (confidence 0.55 between 0.40 and 0.70)
    final ambiguousBeat = BeatEntity(
      id: 'beat_ambiguous',
      chapterId: 'ch_1',
      roadmapId: 'rm_1',
      title: 'Subarray Sum Equals K Tutorial',
      sortOrder: 0,
      matchConfidence: 0.55,
      syllabusTopicId: 'Sliding Window',
      isMentorExtra: false,
      createdAt: now,
      updatedAt: now,
    );

    // High confidence match (confidence 0.95)
    final confidentBeat = BeatEntity(
      id: 'beat_confident',
      chapterId: 'ch_1',
      roadmapId: 'rm_1',
      title: 'Binary Search Basics',
      sortOrder: 1,
      matchConfidence: 0.95,
      syllabusTopicId: 'Binary Search',
      isMentorExtra: false,
      createdAt: now,
      updatedAt: now,
    );

    bool confirmCalled = false;
    bool rejectCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChapterAccordion(
              chapter: chapter,
              beats: [ambiguousBeat, confidentBeat],
              initialExpanded: true,
              onBeatToggled: (_, __) async {},
              onBeatTapped: (_) {},
              onConfirmMatch: (b) async {
                confirmCalled = true;
              },
              onRejectMatch: (b) async {
                rejectCalled = true;
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify ambiguous beat shows the confirmation prompt
    expect(find.text('Looks related to "Sliding Window" — confirm?'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);

    // Verify confident beat does NOT show a prompt
    expect(find.text('Looks related to "Binary Search" — confirm?'), findsNothing);

    // Tap Confirm
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(confirmCalled, isTrue);

    // Tap Reject
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(rejectCalled, isTrue);
  });
}
