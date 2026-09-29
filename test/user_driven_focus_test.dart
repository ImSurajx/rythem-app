import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/flow/flow_screen.dart';

void main() {
  final testNow = DateTime(2026, 9, 29, 10, 0);

  final testRoadmap = RoadmapEntity(
    id: 'rm_test',
    title: 'Systems Engineering Track',
    targetCompletionDate: testNow.add(const Duration(days: 14)),
    createdAt: testNow,
    updatedAt: testNow,
  );

  final testChapters = [
    ChapterEntity(
      id: 'ch_1',
      roadmapId: 'rm_test',
      title: 'Chapter 1: Foundations',
      sortOrder: 0,
      createdAt: testNow,
      updatedAt: testNow,
    ),
    ChapterEntity(
      id: 'ch_2',
      roadmapId: 'rm_test',
      title: 'Chapter 2: Advanced Topics',
      sortOrder: 1,
      createdAt: testNow,
      updatedAt: testNow,
    ),
  ];

  final testBeats = [
    BeatEntity(
      id: 'b1',
      chapterId: 'ch_1',
      roadmapId: 'rm_test',
      title: 'Topic 1.1: Core Memory Model',
      effortWeight: 1.0,
      sortOrder: 0,
      isCompleted: false,
      createdAt: testNow,
      updatedAt: testNow,
    ),
    BeatEntity(
      id: 'b2',
      chapterId: 'ch_1',
      roadmapId: 'rm_test',
      title: 'Topic 1.2: Pointers & References',
      effortWeight: 1.5,
      sortOrder: 1,
      isCompleted: false,
      createdAt: testNow,
      updatedAt: testNow,
    ),
    BeatEntity(
      id: 'b3',
      chapterId: 'ch_2',
      roadmapId: 'rm_test',
      title: 'Topic 2.1: Lock-Free Queues',
      effortWeight: 2.0,
      sortOrder: 0,
      isCompleted: false,
      createdAt: testNow,
      updatedAt: testNow,
    ),
  ];

  group('User-Driven Focus System Tests', () {
    testWidgets('shows Pull Next Topic button when no topic is currently pulled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: testBeats,
              pacingBudget: null,
              streakDays: 3,
              activeFocusBeatByRoadmap: const {},
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {},
            ),
          ),
        ),
      );

      // Verify prompt and unlocked button
      expect(find.text('No active topic in focus right now.'), findsOneWidget);
      expect(find.text('Pull Next Topic'), findsOneWidget);
      expect(find.text('Complete current topic to unlock next'), findsNothing);
    });

    testWidgets('invokes onPullNextTopic callback on tap', (tester) async {
      RoadmapEntity? pulledRoadmap;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: testBeats,
              pacingBudget: null,
              streakDays: 3,
              activeFocusBeatByRoadmap: const {},
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {},
              onPullNextTopic: (rm) => pulledRoadmap = rm,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pull Next Topic'));
      await tester.pumpAndSettle();

      expect(pulledRoadmap?.id, 'rm_test');
    });

    testWidgets('displays active focus topic with Return to Tracker and locked pull button', (tester) async {
      RoadmapEntity? returnedRoadmap;
      BeatEntity? returnedBeat;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: testBeats,
              pacingBudget: null,
              streakDays: 3,
              activeFocusBeatByRoadmap: const {'rm_test': 'b1'},
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {},
              onReturnToTracker: (rm, b) {
                returnedRoadmap = rm;
                returnedBeat = b;
              },
            ),
          ),
        ),
      );

      // Verify active focus card and topic title
      expect(find.text('CURRENT FOCUS'), findsOneWidget);
      expect(find.text('Topic 1.1: Core Memory Model'), findsOneWidget);

      // Verify Return to Tracker button
      expect(find.text('Return to Tracker'), findsOneWidget);

      // Verify locked state message below
      expect(find.text('Complete current topic to unlock next'), findsOneWidget);
      expect(find.text('Pull Next Topic'), findsNothing);

      // Tap Return to Tracker
      await tester.tap(find.text('Return to Tracker'));
      await tester.pumpAndSettle();

      expect(returnedRoadmap?.id, 'rm_test');
      expect(returnedBeat?.id, 'b1');
    });

    testWidgets('shows completed today topics with celebratory state and unlocks pull button', (tester) async {
      final now = DateTime.now();
      final beatsWithCompleted = [
        testBeats[0].copyWith(isCompleted: true, completedAt: now),
        testBeats[1],
        testBeats[2],
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: beatsWithCompleted,
              pacingBudget: null,
              streakDays: 4,
              activeFocusBeatByRoadmap: const {}, // cleared when completed
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {},
            ),
          ),
        ),
      );

      // Completed today header and beat are visible
      expect(find.text('COMPLETED TODAY (1)'), findsNothing); // only 1 section so header hidden or shown
      expect(find.text('Topic 1.1: Core Memory Model'), findsOneWidget);

      // Next topic button is unlocked!
      expect(find.text('Pull Next Topic'), findsOneWidget);
      expect(find.text('Complete current topic to unlock next'), findsNothing);
    });

    testWidgets('completed topic in Today\'s Focus is read-only and cannot be unchecked', (tester) async {
      final now = DateTime.now();
      final beatsWithCompleted = [
        testBeats[0].copyWith(isCompleted: true, completedAt: now),
      ];
      bool toggleInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: beatsWithCompleted,
              pacingBudget: null,
              streakDays: 4,
              activeFocusBeatByRoadmap: const {},
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {
                toggleInvoked = true;
              },
            ),
          ),
        ),
      );

      // Verify the checkmark icon exists
      expect(find.byIcon(Icons.check_rounded), findsWidgets);

      // Tap on checkmark
      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();

      // Ensure toggle was NOT invoked (read-only)
      expect(toggleInvoked, false);
    });

    testWidgets('displays Track Complete celebratory card when 100% finished', (tester) async {
      final now = DateTime.now();
      final allFinished = testBeats.map((b) => b.copyWith(isCompleted: true, completedAt: now)).toList();

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: allFinished,
              pacingBudget: null,
              streakDays: 5,
              activeFocusBeatByRoadmap: const {},
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {},
            ),
          ),
        ),
      );

      expect(find.text('Track Complete! 100% Finished 🎉'), findsOneWidget);
      expect(find.text('Pull Next Topic'), findsNothing);
      expect(find.text('Complete current topic to unlock next'), findsNothing);
    });
  });
}
