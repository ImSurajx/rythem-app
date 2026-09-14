import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/database/repositories/beat_log_repository.dart';
import 'package:rythem_app/core/pacing/models/pacing_budget.dart';
import 'package:rythem_app/features/metrics/metrics_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('MetricsScreen Tests', () {
    final roadmap1 = RoadmapEntity(
      id: 'rm_1',
      title: 'Neural Networks',
      description: 'Foundations of deep learning',
      targetCompletionDate: DateTime.now().add(const Duration(days: 20)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final beats1 = [
      BeatEntity(
        id: 'b1',
        chapterId: 'c1',
        roadmapId: 'rm_1',
        title: 'Perceptrons',
        effortWeight: 2.0,
        isCompleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      BeatEntity(
        id: 'b2',
        chapterId: 'c1',
        roadmapId: 'rm_1',
        title: 'Backpropagation',
        effortWeight: 3.0,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    const testBudget = PacingBudget(
      roadmapId: 'rm_1',
      remainingEffort: 3.0,
      daysLeft: 20,
      todayEffortShare: 1.0,
      todaysBeats: [],
      todaysSelectedEffort: 0.0,
      isRoadmapCompleted: false,
      isDailyQuotaCompleted: false,
      isSustainedLag: false,
      lagStreakDays: 0,
      recentVelocity: 1.5,
    );

    final activity = [
      const DailyBeatCount(date: '2026-09-08', count: 1),
      const DailyBeatCount(date: '2026-09-09', count: 2),
      const DailyBeatCount(date: '2026-09-10', count: 0),
      const DailyBeatCount(date: '2026-09-11', count: 3),
      const DailyBeatCount(date: '2026-09-12', count: 1),
      const DailyBeatCount(date: '2026-09-13', count: 4),
      const DailyBeatCount(date: '2026-09-14', count: 2),
    ];

    testWidgets('renders lifetime counters, streak, and velocity', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricsScreen(
              roadmaps: [roadmap1],
              beatsByRoadmap: {'rm_1': beats1},
              activeBudget: testBudget,
              currentStreak: 5,
              recentActivity: activity,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RHYTHM & METRICS'), findsOneWidget);
      expect(find.text('Pacing & Velocity'), findsOneWidget);
      expect(find.text('COMPLETED BEATS'), findsNWidgets(2));
      expect(find.text('1'), findsWidgets); // 1 completed beat
      expect(find.text('FLOW STREAK'), findsOneWidget);
      expect(find.text('5 Days'), findsOneWidget);
      expect(find.text('7-DAY ACTIVITY'), findsOneWidget);
      expect(find.text('Neural Networks'), findsOneWidget);
    });

    testWidgets('tapping active track overview card calls onOpenRoadmapDetail', (tester) async {
      RoadmapEntity? tappedRoadmap;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricsScreen(
              roadmaps: [roadmap1],
              beatsByRoadmap: {'rm_1': beats1},
              activeBudget: testBudget,
              currentStreak: 5,
              recentActivity: activity,
              onOpenRoadmapDetail: (rm) => tappedRoadmap = rm,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trackFinder = find.text('Neural Networks');
      await tester.ensureVisible(trackFinder);
      await tester.tap(trackFinder);
      await tester.pumpAndSettle();

      expect(tappedRoadmap, isNotNull);
      expect(tappedRoadmap!.id, 'rm_1');
    });

    testWidgets('pacing simulator expander opens and reveals preset actions', (tester) async {
      bool simulatedMissedDay = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricsScreen(
              roadmaps: [roadmap1],
              beatsByRoadmap: {'rm_1': beats1},
              activeBudget: testBudget,
              currentStreak: 5,
              recentActivity: activity,
              onSimulateMissedDay: () => simulatedMissedDay = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PACING SIMULATOR & ENGINE'), findsOneWidget);
      expect(find.text('+1 Missed Day (Dilution)'), findsNothing);

      // Tap expander
      await tester.ensureVisible(find.text('PACING SIMULATOR & ENGINE'));
      await tester.tap(find.text('PACING SIMULATOR & ENGINE'));
      await tester.pumpAndSettle();

      final chipFinder = find.text('+1 Missed Day (Dilution)');
      expect(chipFinder, findsOneWidget);
      await tester.ensureVisible(chipFinder);
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      expect(simulatedMissedDay, isTrue);
    });
  });
}
