import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/features/flow/widgets/pace_coach_card.dart';
import 'package:rythem_app/features/flow/widgets/timeline_adjuster_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Feature 4: Intelligent Pace Coach Math & Projections', () {
    test('Open pace mode calculates projected completion from velocity without deadline or debt', () {
      final now = DateTime(2026, 9, 24);
      final recentRecords = [
        DailyPacingRecord(date: now.subtract(const Duration(days: 1)), completedEffort: 2.0, targetEffort: 2.0),
        DailyPacingRecord(date: now.subtract(const Duration(days: 2)), completedEffort: 2.0, targetEffort: 2.0),
      ];

      final result = PacingCalculator.calculatePaceHealth(
        remainingEffort: 20.0,
        targetDate: null,
        pastDaysRecords: recentRecords,
        now: now,
      );

      expect(result.status, PaceStatus.openPace);
      expect(result.daysAheadOrBehind, 0);
      expect(result.currentVelocity, 2.0);
      // 20 remaining / 2.0 velocity = 10 days -> projected completion = Sept 24 + 10d = Oct 4
      expect(result.projectedCompletionDate, DateTime(2026, 10, 4));
      expect(result.guidelineMessage, contains('Self-paced learning'));
      expect(result.guidelineMessage, contains('~2.0 lessons/active day'));
    });

    test('On Track scenario correctly identifies velocity matching target deadline', () {
      final now = DateTime(2026, 9, 24);
      // Target is 10 days away (Oct 4)
      final targetDate = DateTime(2026, 10, 4);
      // 10 remaining effort, velocity = 1.0 -> takes 10 days -> finishes exactly on Oct 4
      final recentRecords = [
        DailyPacingRecord(date: now.subtract(const Duration(days: 1)), completedEffort: 1.0, targetEffort: 1.0),
        DailyPacingRecord(date: now.subtract(const Duration(days: 2)), completedEffort: 1.0, targetEffort: 1.0),
      ];

      final result = PacingCalculator.calculatePaceHealth(
        remainingEffort: 10.0,
        targetDate: targetDate,
        pastDaysRecords: recentRecords,
        now: now,
      );

      expect(result.status, PaceStatus.onTrack);
      expect(result.daysAheadOrBehind, 0);
      expect(result.projectedCompletionDate, DateTime(2026, 10, 4));
      expect(result.guidelineMessage, contains('On track'));
      expect(result.guidelineMessage, contains('1.0 lessons/day'));
    });

    test('Behind Schedule scenario computes GPS ETA delay and non-punitive guideline', () {
      final now = DateTime(2026, 9, 24);
      // Target is 5 days away (Sept 29)
      final targetDate = DateTime(2026, 9, 29);
      // 10 remaining effort, but velocity is only 1.0 -> will take 10 days (Oct 4), 5 days behind
      final recentRecords = [
        DailyPacingRecord(date: now.subtract(const Duration(days: 1)), completedEffort: 1.0, targetEffort: 2.0),
        DailyPacingRecord(date: now.subtract(const Duration(days: 2)), completedEffort: 1.0, targetEffort: 2.0),
      ];

      final result = PacingCalculator.calculatePaceHealth(
        remainingEffort: 10.0,
        targetDate: targetDate,
        pastDaysRecords: recentRecords,
        now: now,
      );

      expect(result.status, PaceStatus.behindSchedule);
      expect(result.daysAheadOrBehind, 5); // 5 days behind target
      expect(result.projectedCompletionDate, DateTime(2026, 10, 4));
      // Guideline must encourage adjustment without penalty language
      expect(result.guidelineMessage, contains('5 days behind target'));
      expect(result.guidelineMessage, isNot(contains('debt')));
      expect(result.guidelineMessage, isNot(contains('penalty')));
    });

    test('Fresh track with zero study history falls back to required pace smoothly without error', () {
      final now = DateTime(2026, 9, 24);
      final targetDate = DateTime(2026, 10, 24); // 30 days away

      final result = PacingCalculator.calculatePaceHealth(
        remainingEffort: 15.0,
        targetDate: targetDate,
        pastDaysRecords: const [],
        now: now,
      );

      expect(result.status, PaceStatus.onTrack);
      expect(result.projectedCompletionDate, isNotNull);
      expect(result.dailyEffortGuideline, closeTo(0.5, 0.01));
    });
  });

  group('Feature 4: PacingBudget Model & Invariants', () {
    test('PacingBudget getters accurately reflect PaceStatus', () {
      const onTrackBudget = PacingBudget(
        roadmapId: 'rm1',
        remainingEffort: 10,
        daysLeft: 10,
        todayEffortShare: 1.0,
        todaysBeats: [],
        todaysSelectedEffort: 0,
        isRoadmapCompleted: false,
        isDailyQuotaCompleted: false,
        paceStatus: PaceStatus.onTrack,
      );
      expect(onTrackBudget.isOnTrack, isTrue);
      expect(onTrackBudget.isBehindSchedule, isFalse);
      expect(onTrackBudget.isOpenPace, isFalse);

      const behindBudget = PacingBudget(
        roadmapId: 'rm1',
        remainingEffort: 10,
        daysLeft: 5,
        todayEffortShare: 2.0,
        todaysBeats: [],
        todaysSelectedEffort: 0,
        isRoadmapCompleted: false,
        isDailyQuotaCompleted: false,
        paceStatus: PaceStatus.behindSchedule,
      );
      expect(behindBudget.isOnTrack, isFalse);
      expect(behindBudget.isBehindSchedule, isTrue);
      expect(behindBudget.isOpenPace, isFalse);

      const openPaceBudget = PacingBudget(
        roadmapId: 'rm1',
        remainingEffort: 10,
        daysLeft: 30,
        todayEffortShare: 1.0,
        todaysBeats: [],
        todaysSelectedEffort: 0,
        isRoadmapCompleted: false,
        isDailyQuotaCompleted: false,
        paceStatus: PaceStatus.openPace,
      );
      expect(openPaceBudget.isOnTrack, isFalse);
      expect(openPaceBudget.isBehindSchedule, isFalse);
      expect(openPaceBudget.isOpenPace, isTrue);
    });

    test('PacingBudget copyWith preserves pace coach attributes', () {
      final budget = PacingBudget(
        roadmapId: 'rm1',
        remainingEffort: 12,
        daysLeft: 10,
        todayEffortShare: 1.2,
        todaysBeats: const [],
        todaysSelectedEffort: 0,
        isRoadmapCompleted: false,
        isDailyQuotaCompleted: false,
        paceStatus: PaceStatus.behindSchedule,
        projectedCompletionDate: DateTime(2026, 10, 5),
        daysAheadOrBehind: 2,
        dailyEffortGuideline: 1.5,
        guidelineMessage: 'Test guideline message',
        targetDate: DateTime(2026, 10, 3),
      );

      final updated = budget.copyWith(remainingEffort: 8);
      expect(updated.remainingEffort, 8);
      expect(updated.paceStatus, PaceStatus.behindSchedule);
      expect(updated.projectedCompletionDate, DateTime(2026, 10, 5));
      expect(updated.daysAheadOrBehind, 2);
      expect(updated.dailyEffortGuideline, 1.5);
      expect(updated.guidelineMessage, 'Test guideline message');
      expect(updated.targetDate, DateTime(2026, 10, 3));
    });
  });

  group('Feature 4: UI PaceCoachCard & TimelineAdjusterSheet', () {
    testWidgets('PaceCoachCard renders status pill, guideline, and action buttons', (tester) async {
      final now = DateTime(2026, 9, 24);
      final roadmap = RoadmapEntity(
        id: 'rm-pace',
        title: 'Distributed Systems',
        targetCompletionDate: DateTime(2026, 10, 15),
        createdAt: now,
        updatedAt: now,
      );

      final budget = PacingBudget(
        roadmapId: roadmap.id,
        remainingEffort: 14,
        daysLeft: 21,
        todayEffortShare: 0.67,
        todaysBeats: const [],
        todaysSelectedEffort: 0,
        isRoadmapCompleted: false,
        isDailyQuotaCompleted: false,
        paceStatus: PaceStatus.onTrack,
        projectedCompletionDate: DateTime(2026, 10, 12),
        daysAheadOrBehind: -3,
        dailyEffortGuideline: 0.7,
        guidelineMessage: 'On track! Aim for ~0.7 lessons/day to finish comfortably.',
        targetDate: roadmap.targetCompletionDate,
      );

      bool quickExtendCalled = false;
      bool adjusterOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: PaceCoachCard(
              roadmap: roadmap,
              pacingBudget: budget,
              themeColors: RythemColors.dark,
              isDark: true,
              onQuickExtendSevenDays: () => quickExtendCalled = true,
              onOpenTimelineAdjuster: () => adjusterOpened = true,
            ),
          ),
        ),
      );

      // Verify UI headers and status
      expect(find.text('PACE COACH'), findsOneWidget);
      expect(find.text('On Track'), findsOneWidget);
      expect(find.text('Target Date'), findsOneWidget);
      expect(find.text('Projected ETA'), findsOneWidget);
      expect(find.textContaining('On track! Aim for ~0.7 lessons/day'), findsOneWidget);

      // Tap +7 Days
      await tester.tap(find.text('+7 Days'));
      expect(quickExtendCalled, isTrue);

      // Tap Adjust Pace
      await tester.tap(find.text('Adjust Pace'));
      expect(adjusterOpened, isTrue);
    });

    testWidgets('TimelineAdjusterSheet displays quick extension options and Open Pace', (tester) async {
      final now = DateTime(2026, 9, 24);
      final roadmap = RoadmapEntity(
        id: 'rm-pace',
        title: 'Distributed Systems',
        targetCompletionDate: DateTime(2026, 10, 15),
        createdAt: now,
        updatedAt: now,
      );

      final budget = PacingBudget(
        roadmapId: roadmap.id,
        remainingEffort: 14,
        daysLeft: 21,
        todayEffortShare: 0.67,
        todaysBeats: const [],
        todaysSelectedEffort: 0,
        isRoadmapCompleted: false,
        isDailyQuotaCompleted: false,
        paceStatus: PaceStatus.behindSchedule,
        projectedCompletionDate: DateTime(2026, 10, 20),
        daysAheadOrBehind: 5,
        dailyEffortGuideline: 1.0,
        guidelineMessage: 'Currently ~5 days behind target pace.',
        targetDate: roadmap.targetCompletionDate,
      );

      DateTime? selectedTarget;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  TimelineAdjusterSheet.show(
                    ctx,
                    roadmap: roadmap,
                    pacingBudget: budget,
                    onTargetDateSelected: (date) => selectedTarget = date,
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('TIMELINE ADJUSTER'), findsOneWidget);
      expect(find.text('+7 Days Extension'), findsOneWidget);
      expect(find.text('+14 Days Extension'), findsOneWidget);
      expect(find.text('Pick Custom Calendar Date'), findsOneWidget);
      expect(find.text('Switch to Open Pace'), findsOneWidget);

      // Tap +7 Days Extension
      await tester.tap(find.text('+7 Days Extension'));
      await tester.pumpAndSettle();

      expect(selectedTarget, isNotNull);
      expect(selectedTarget, DateTime(2026, 10, 22)); // 15 + 7 = 22
    });
  });
}
