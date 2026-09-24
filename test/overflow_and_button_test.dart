import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:rythem_app/features/flow/flow_screen.dart';
import 'package:rythem_app/features/explore/widgets/chapter_accordion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testRoadmap = RoadmapEntity(
    id: 'rm_overflow',
    title: 'Advanced Mathematics & Computer Science Track',
    description: 'Mathematics',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testChapterLong = ChapterEntity(
    id: 'ch_long',
    roadmapId: 'rm_overflow',
    title: 'Chapter 1: Extremely Comprehensive Introduction to Advanced Precalculus & Multivariable Differential Equations',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final testBeatLong = BeatEntity(
    id: 'b_long',
    chapterId: 'ch_long',
    roadmapId: 'rm_overflow',
    title: 'Fundamental Theorem of Calculus and Vector Field Transformations Under Non-Euclidean Metrics',
    sourceUrl: 'https://www.youtube.com/watch?v=extremely_long_video_id_with_parameters&t=3600s',
    effortWeight: 2.5,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('Flow & Chapter Card Text Overflow Tests', () {
    testWidgets('Flow screen renders long chapter title and resource without overflowing', (tester) async {
      // Use constrained width phone viewport (375x667)
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: [testChapterLong],
              allBeats: [testBeatLong],
              pacingBudget: PacingBudget(
                roadmapId: testRoadmap.id,
                todaysBeats: [testBeatLong],
                todayEffortShare: 2.5,
                todaysSelectedEffort: 2.5,
                remainingEffort: 2.5,
                daysLeft: 1,
                isRoadmapCompleted: false,
                isDailyQuotaCompleted: false,
              ),
              chaptersByRoadmap: {
                testRoadmap.id: [testChapterLong],
              },
              beatsByRoadmap: {
                testRoadmap.id: [testBeatLong],
              },
              streakDays: 5,
              onSwitchRoadmap: () {},
              onBeatToggled: (_, __) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify text is present and does not trigger Flutter overflow error
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Fundamental Theorem'), findsOneWidget);
      expect(find.textContaining('video'), findsOneWidget);
      expect(find.textContaining('2.5 effort'), findsOneWidget);
    });

    testWidgets('ChapterAccordion renders long chapter title and long beat metadata without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: ChapterAccordion(
              chapter: testChapterLong,
              beats: [testBeatLong],
              initialExpanded: true,
              onBeatToggled: (_, __) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Fundamental Theorem'), findsOneWidget);
      expect(find.textContaining('video'), findsOneWidget);
      expect(find.textContaining('2.5 effort'), findsOneWidget);
    });

    testWidgets('Completed task in Flow retains visibility and applies strike-through decoration', (tester) async {
      final completedBeat = testBeatLong.copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: [testChapterLong],
              allBeats: [completedBeat],
              pacingBudget: null,
              chaptersByRoadmap: {
                testRoadmap.id: [testChapterLong],
              },
              beatsByRoadmap: {
                testRoadmap.id: [completedBeat],
              },
              streakDays: 5,
              onSwitchRoadmap: () {},
              onBeatToggled: (_, __) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify completed task is still visible
      final titleFinder = find.textContaining('Fundamental Theorem');
      expect(titleFinder, findsOneWidget);

      // Verify lineThrough decoration is applied
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.style?.decoration, TextDecoration.lineThrough);

      // Verify MISSION badge is not present
      expect(find.text('MISSION'), findsNothing);
    });
  });

  group('GlassButton Hierarchy & Material Tests', () {
    testWidgets('GlassButton primary and secondary variants render floating frosted glass', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: [
                GlassButton(
                  label: 'New Track',
                  icon: Icons.add_rounded,
                  variant: GlassButtonVariant.primary,
                  onPressed: () {},
                ),
                GlassButton(
                  label: 'Attach Resource',
                  icon: Icons.link_rounded,
                  variant: GlassButtonVariant.primary,
                  onPressed: () {},
                ),
                GlassButton(
                  label: 'Ingest Resource',
                  icon: Icons.link_rounded,
                  variant: GlassButtonVariant.secondary,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Track'), findsOneWidget);
      expect(find.text('Attach Resource'), findsOneWidget);
      expect(find.text('Ingest Resource'), findsOneWidget);

      // Verify all buttons are GlassButtons with floating BackdropFilter
      expect(find.byType(BackdropFilter), findsNWidgets(3));
    });
  });
}
