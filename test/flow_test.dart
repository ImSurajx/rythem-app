import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/core/widgets/glass_bottom_dock.dart';
import 'package:rythem_app/features/flow/flow_screen.dart';
import 'package:rythem_app/features/flow/session_detail_screen.dart';

void main() {
  final testNow = DateTime(2026, 9, 12, 10, 0);

  final testRoadmap = RoadmapEntity(
    id: 'rm_test',
    title: 'Test Engineering Track',
    targetCompletionDate: testNow.add(const Duration(days: 7)),
    createdAt: testNow,
    updatedAt: testNow,
  );

  final testChapters = [
    ChapterEntity(
      id: 'ch_1',
      roadmapId: 'rm_test',
      title: 'Foundation Concepts',
      sortOrder: 0,
      createdAt: testNow,
      updatedAt: testNow,
    ),
  ];

  final testBeats = [
    BeatEntity(
      id: 'b1',
      chapterId: 'ch_1',
      roadmapId: 'rm_test',
      title: 'First Beat Title',
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
      title: 'Second Beat Title',
      effortWeight: 1.5,
      sortOrder: 1,
      isCompleted: false,
      createdAt: testNow,
      updatedAt: testNow,
    ),
  ];

  group('GlassBottomDock Architecture Tests', () {
    testWidgets('renders exactly 4 navigation items with zero badges', (tester) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            bottomNavigationBar: GlassBottomDock(
              selectedIndex: selected,
              onItemSelected: (idx) => selected = idx,
            ),
          ),
        ),
      );

      // 4 exact labels
      expect(find.text('Flow'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Metrics'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify tapping changes selection
      await tester.tap(find.text('Metrics'));
      await tester.pump();
      expect(selected, 2);
    });
  });

  group('FlowScreen Core Habit Loop Tests', () {
    testWidgets('renders streak, date, and allocated mission beats', (tester) async {
      final budget = PacingBudget(
        roadmapId: 'rm_test',
        todayEffortShare: 2.5,
        todaysSelectedEffort: 2.5,
        remainingEffort: 2.5,
        daysLeft: 7,
        todaysBeats: testBeats,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: testBeats,
              pacingBudget: budget,
              streakDays: 5,
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {},
            ),
          ),
        ),
      );

      // Streak indicator removed from top header; exists in weekly calendar
      expect(find.text('5 Day Streak'), findsNothing);
      expect(find.text('5 days active'), findsOneWidget);

      // Roadmap title (in header and track todo card)
      expect(find.text('Test Engineering Track'), findsWidgets);

      // Today's beats
      expect(find.text('First Beat Title'), findsOneWidget);
      expect(find.text('Second Beat Title'), findsOneWidget);

      // Tap options menu and select Ask Mentor to Explain (flag)
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.help_outline_rounded).first);
      await tester.pumpAndSettle();

      // Confusing beat dialog opened
      expect(find.text('FLAG FRICTION / CONFUSION'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders Streak Calendar with glass circular cells and zero locked states', (tester) async {
      final completedBeats = testBeats.map((b) => b.copyWith(isCompleted: true)).toList();
      final budget = PacingBudget(
        roadmapId: 'rm_test',
        todayEffortShare: 2.5,
        todaysSelectedEffort: 2.5,
        remainingEffort: 0.0,
        daysLeft: 7,
        todaysBeats: completedBeats,
        isDailyQuotaCompleted: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: completedBeats,
              pacingBudget: budget,
              streakDays: 6,
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {},
            ),
          ),
        ),
      );

      // Streak Calendar verification
      expect(find.text('STREAK CALENDAR'), findsOneWidget);
      expect(find.text('6 days active'), findsOneWidget);
      // Zero locked text
      expect(find.text('Evening locked'), findsNothing);
      expect(find.text('Evening unlocked'), findsNothing);
    });
  });

  group('SessionDetailScreen Focus Mode Tests', () {
    testWidgets('focus mode displays sequence and advances on Complete & Advance', (tester) async {
      BeatEntity? lastToggledBeat;
      bool? lastToggledValue;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: SessionDetailScreen(
            roadmapTitle: 'Active Roadmap',
            chapterTitle: 'Core Mathematics',
            beats: testBeats,
            initialBeatId: 'b1',
            onBeatToggled: (beat, isCompleted) async {
              lastToggledBeat = beat;
              lastToggledValue = isCompleted;
            },
          ),
        ),
      );

      // Focus headers
      expect(find.text('ACTIVE ROADMAP'), findsOneWidget);
      expect(find.text('Core Mathematics'), findsOneWidget);
      expect(find.text('0 of 2'), findsOneWidget);

      // Beat sequence (appears in list and active bottom bar)
      expect(find.text('First Beat Title'), findsWidgets);
      expect(find.text('Second Beat Title'), findsOneWidget);
      expect(find.text('IN FOCUS'), findsOneWidget);

      // Tap Complete & Advance
      final completeButton = find.text('Complete & Advance');
      expect(completeButton, findsOneWidget);
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      // Verify onBeatToggled callback was invoked on first beat
      expect(lastToggledBeat?.id, 'b1');
      expect(lastToggledValue, true);
    });
  });
}
