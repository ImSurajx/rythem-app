import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/database/repositories/beat_log_repository.dart';
import 'package:rythem_app/core/pacing/models/pacing_budget.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/flow/flow_screen.dart';
import 'package:rythem_app/features/metrics/metrics_screen.dart';
import 'package:rythem_app/features/metrics/widgets/full_month_streak_calendar.dart';
import 'package:rythem_app/features/metrics/widgets/performance_graphs_card.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Full Month Streak Calendar & Dual Performance Graphs Tests', () {
    final now = DateTime.now();

    final testRoadmap = RoadmapEntity(
      id: 'rm_metrics_test',
      title: 'Advanced Machine Learning',
      description: 'Curriculum track',
      targetCompletionDate: now.add(const Duration(days: 30)),
      createdAt: now,
      updatedAt: now,
    );

    final testBeats = [
      BeatEntity(
        id: 'beat_1',
        chapterId: 'ch_1',
        roadmapId: 'rm_metrics_test',
        title: 'Linear Regression & Cost',
        effortWeight: 1.0,
        isCompleted: true,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      BeatEntity(
        id: 'beat_delayed_test',
        chapterId: 'ch_1',
        roadmapId: 'rm_metrics_test',
        title: 'Backpropagation Vector Calculus (Delayed Task)',
        effortWeight: 2.0,
        isCompleted: false,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];

    const testBudget = PacingBudget(
      roadmapId: 'rm_metrics_test',
      todayEffortShare: 2.0,
      todaysSelectedEffort: 2.0,
      remainingEffort: 4.0,
      daysLeft: 30,
      todaysBeats: [],
    );

    const recent7Days = [
      DailyBeatCount(date: '2026-09-09', count: 1),
      DailyBeatCount(date: '2026-09-10', count: 2),
      DailyBeatCount(date: '2026-09-11', count: 0),
      DailyBeatCount(date: '2026-09-12', count: 4),
      DailyBeatCount(date: '2026-09-13', count: 3),
      DailyBeatCount(date: '2026-09-14', count: 5),
      DailyBeatCount(date: '2026-09-15', count: 2),
    ];

    testWidgets('MetricsScreen displays FullMonthStreakCalendar at top before completed beats', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: MetricsScreen(
              roadmaps: [testRoadmap],
              beatsByRoadmap: {'rm_metrics_test': testBeats},
              activeBudget: testBudget,
              currentStreak: 7,
              recentActivity: recent7Days,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Full Month Streak Calendar exists
      expect(find.byType(FullMonthStreakCalendar), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsWidgets);

      // Scroll down to Performance Graphs card
      await tester.scrollUntilVisible(
        find.byType(PerformanceGraphsCard),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Verify Dual Performance Graphs card exists
      expect(find.byType(PerformanceGraphsCard), findsOneWidget);
      expect(find.text('MONTHLY PERFORMANCE'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('Lifetime Stars'), findsOneWidget);

      // Verify toggling to Lifetime Stars works
      await tester.tap(find.text('Lifetime Stars'));
      await tester.pumpAndSettle();

      expect(find.text('LIFETIME STAR GROWTH'), findsOneWidget);
      expect(find.text('TOTAL STARS'), findsOneWidget);
    });

    testWidgets('FullMonthStreakCalendar supports navigating previous and next months', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: FullMonthStreakCalendar(
                themeColors: RythemColors.dark,
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show calendar icon
      expect(find.byType(FullMonthStreakCalendar), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);

      // Tap next month icon
      final nextButton = find.byIcon(Icons.chevron_right_rounded);
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Tap TODAY shortcut to jump back
      final todayButton = find.text('TODAY');
      expect(todayButton, findsOneWidget);
      await tester.tap(todayButton);
      await tester.pumpAndSettle();
    });
  });

  group('Task Delay Workflow in FlowScreen Tests', () {
    final testNow = DateTime.now();

    final testRoadmap = RoadmapEntity(
      id: 'rm_flow_test',
      title: 'Deep Learning & Neural Flow',
      targetCompletionDate: testNow.add(const Duration(days: 14)),
      createdAt: testNow,
      updatedAt: testNow,
    );

    final testChapters = [
      ChapterEntity(
        id: 'ch_1',
        roadmapId: 'rm_flow_test',
        title: 'Mathematical Foundations',
        sortOrder: 0,
        createdAt: testNow,
        updatedAt: testNow,
      ),
    ];

    final testBeats = [
      BeatEntity(
        id: 'beat_normal',
        chapterId: 'ch_1',
        roadmapId: 'rm_flow_test',
        title: 'Gradient Descent Basics',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: false,
        createdAt: testNow,
        updatedAt: testNow,
      ),
      BeatEntity(
        id: 'beat_delayed_sample',
        chapterId: 'ch_1',
        roadmapId: 'rm_flow_test',
        title: 'Backpropagation Vector Calculus (Delayed Task)',
        effortWeight: 2.0,
        sortOrder: 1,
        isCompleted: false,
        createdAt: testNow.subtract(const Duration(days: 2)),
        updatedAt: testNow.subtract(const Duration(days: 2)),
      ),
    ];

    testWidgets('FlowScreen renders delayed task with DELAYED badge and allows toggling delay', (tester) async {
      BeatEntity? delayedToggledBeat;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: testBeats,
              pacingBudget: const PacingBudget(
                roadmapId: 'rm_flow_test',
                todayEffortShare: 2.0,
                todaysSelectedEffort: 2.0,
                remainingEffort: 3.0,
                daysLeft: 14,
                todaysBeats: [],
              ),
              chaptersByRoadmap: {'rm_flow_test': testChapters},
              beatsByRoadmap: {'rm_flow_test': testBeats},
              streakDays: 4,
              delayedBeatIds: const {'beat_delayed_sample'},
              onToggleDelay: (beat) {
                delayedToggledBeat = beat;
              },
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, isCompleted) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the delayed task is visible
      expect(find.text('Backpropagation Vector Calculus (Delayed Task)'), findsOneWidget);

      // Verify DELAYED • LATER badge is displayed on the delayed task
      expect(find.text('DELAYED • LATER'), findsOneWidget);

      // Find and tap the restore/delay button on the beat
      final restoreButton = find.byIcon(Icons.restore_rounded);
      expect(restoreButton, findsOneWidget);
      await tester.tap(restoreButton);
      await tester.pump();

      expect(delayedToggledBeat?.id, 'beat_delayed_sample');
    });
  });
}
