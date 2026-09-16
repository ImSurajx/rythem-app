import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/revision/models/revision_item.dart';
import 'package:rythem_app/core/revision/services/revision_service.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/core/widgets/glass_toast.dart';
import 'package:rythem_app/core/widgets/markdown_content_view.dart';
import 'package:rythem_app/features/flow/flow_screen.dart';
import 'package:rythem_app/features/flow/widgets/daily_revision_board.dart';
import 'package:rythem_app/core/ai/services/local_inference_service.dart';
import 'package:rythem_app/core/pacing/models/pacing_budget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Revision System Mathematical Engine Tests', () {
    test('Calculates forgetting curve decay and prioritizes flagged weak concepts', () async {
      final service = RevisionService();
      await service.init();

      final now = DateTime.now();
      final roadmap = RoadmapEntity(
        id: 'rm_rev_test',
        title: 'Deep Learning & Neural Flow',
        targetCompletionDate: now.add(const Duration(days: 30)),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now,
      );

      final beatNormal = BeatEntity(
        id: 'beat_normal_rev',
        chapterId: 'ch_1',
        roadmapId: roadmap.id,
        title: 'Linear Regression Basics',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: true,
        completedAt: now.subtract(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 5)),
      );

      final beatWeak = BeatEntity(
        id: 'beat_weak_rev',
        chapterId: 'ch_1',
        roadmapId: roadmap.id,
        title: 'Backpropagation Vector Tensor Chain Rule',
        effortWeight: 2.0,
        sortOrder: 1,
        isCompleted: true,
        completedAt: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      // Flag beatWeak as weak concept
      await service.flagTopicForRevision(
        beat: beatWeak,
        roadmapTitle: roadmap.title,
        note: 'Matrix tensor calculus difficulty',
        isWeak: true,
      );

      final recommendations = await service.getDailyRevisionRecommendations(
        roadmaps: [roadmap],
        beatsByRoadmap: {
          roadmap.id: [beatNormal, beatWeak],
        },
        referenceDate: now,
      );

      expect(recommendations.isNotEmpty, isTrue);
      // Weak concept should be top prioritized
      final firstRec = recommendations.first;
      expect(firstRec.beatId, 'beat_weak_rev');
      expect(firstRec.isFlaggedWeak, isTrue);
      expect(firstRec.suggestedReason, contains('Matrix tensor calculus'));

      // Mark beatWeak as revised
      final revised = await service.markTopicRevised(beatWeak, roadmapTitle: roadmap.title);
      expect(revised.revisionCount, greaterThanOrEqualTo(1));
      expect(revised.isFlaggedWeak, isFalse);
    });
  });

  group('Liquid Glass Notifications & Markdown Compiled Renderer Tests', () {
    testWidgets('showGlassToast displays liquid glass floating notification', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showGlassToast(
                    context,
                    'Deleted "Deep Learning Track"',
                    icon: Icons.delete_outline_rounded,
                    accentColor: Colors.redAccent,
                  );
                },
                child: const Text('TRIGGER TOAST'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('TRIGGER TOAST'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(GlassToast), findsOneWidget);
      expect(find.text('Deleted "Deep Learning Track"'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('MarkdownContentView renders headers, bold tokens, and inline code tags', (tester) async {
      const markdown = '''
# AI Mentor Report
## Core Concepts
Here is **Gradient Descent** with `learning_rate = 0.01`.
• Step 1: Compute gradients
• Step 2: Update weights
> Key insight: momentum prevents local minima trapping.
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownContentView(
              content: markdown,
              isDark: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Mentor Report'), findsOneWidget);
      expect(find.text('Core Concepts'), findsOneWidget);
      expect(find.text('learning_rate = 0.01'), findsOneWidget);
      expect(find.byType(MarkdownContentView), findsOneWidget);
    });
  });

  group('DailyRevisionBoard & Backlog Simulator in FlowScreen Tests', () {
    testWidgets('DailyRevisionBoard renders items and allows quick breakdown', (tester) async {
      final sampleItem = RevisionItem(
        beatId: 'beat_sample',
        roadmapId: 'rm_test',
        roadmapTitle: 'Neural Flow',
        title: 'Loss Surfaces & Hessian Matrices',
        isFlaggedWeak: true,
        suggestedReason: 'Flagged Weak Concept',
        lastRevisedAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      RevisionItem? revisedItem;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyRevisionBoard(
                revisionItems: [sampleItem],
                onMarkRevised: (item) {
                  revisedItem = item;
                },
                inferenceService: LocalInferenceService(),
                themeColors: RythemColors.dark,
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Board header visible
      expect(find.text("TODAY'S REVISION"), findsOneWidget);
      expect(find.text('1 SUGGESTED'), findsOneWidget);
      expect(find.text('Loss Surfaces & Hessian Matrices'), findsOneWidget);
      expect(find.text('Flagged Weak Concept'), findsOneWidget);

      // Verify AI breakdown button has been removed from the board
      expect(find.text('Quick Breakdown from AI Mentor'), findsNothing);

      // Tap Mark Revised check button
      final checkButton = find.byKey(const Key('revision_check_button_beat_sample'));
      expect(checkButton, findsOneWidget);
      await tester.tap(checkButton);
      await tester.pump();

      expect(revisedItem?.beatId, 'beat_sample');
    });

    testWidgets('FlowScreen TEST BACKLOG toggle summons Sustained Lag banner for testing', (tester) async {
      final now = DateTime.now();
      final testRoadmap = RoadmapEntity(
        id: 'rm_flow_test',
        title: 'Deep Learning Flow',
        targetCompletionDate: now.add(const Duration(days: 14)),
        createdAt: now,
        updatedAt: now,
      );

      final testBeat = BeatEntity(
        id: 'beat_flow_1',
        chapterId: 'ch_1',
        roadmapId: 'rm_flow_test',
        title: 'Backpropagation Vector Calculus',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: const [],
              allBeats: [testBeat],
              pacingBudget: const PacingBudget(
                roadmapId: 'rm_flow_test',
                todayEffortShare: 2.0,
                todaysSelectedEffort: 2.0,
                remainingEffort: 4.0,
                daysLeft: 14,
                todaysBeats: [],
              ),
              streakDays: 3,
              onSwitchRoadmap: () {},
              onBeatToggled: (b, val) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find TEST BACKLOG pill
      final testBacklogPill = find.text('TEST BACKLOG');
      expect(testBacklogPill, findsOneWidget);

      // Tap to activate lag simulation
      await tester.tap(testBacklogPill);
      await tester.pumpAndSettle();

      // The sustained lag recalibration banner should now appear!
      expect(find.text("You're falling behind"), findsOneWidget);
      expect(find.text('Review plan'), findsOneWidget);
    });

    testWidgets('DailyRevisionBoard renders empty (SizedBox.shrink) when no topics are due', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: DailyRevisionBoard(
              revisionItems: const [],
              onMarkRevised: (_) {},
              inferenceService: LocalInferenceService(),
              themeColors: RythemColors.dark,
              isDark: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("TODAY'S REVISION"), findsNothing);
      expect(find.byType(DailyRevisionBoard), findsOneWidget);
    });

    testWidgets('DailyRevisionBoard retains completed item with strikethrough, checkmark, and beat points badge', (tester) async {
      final completedItem = RevisionItem(
        beatId: 'beat_completed_1',
        roadmapId: 'rm_test',
        roadmapTitle: 'Neural Networks',
        title: 'Activation Functions & Sigmoids',
        isCompleted: true,
        beatPoints: 1.0,
        microRecallPrompt: 'What is the vanishing gradient problem in deep sigmoids?',
        suggestedReason: 'Prerequisite for today\'s Backpropagation',
        lastRevisedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyRevisionBoard(
                revisionItems: [completedItem],
                onMarkRevised: (_) {},
                inferenceService: LocalInferenceService(),
                themeColors: RythemColors.dark,
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Board header visible with ALL REVISED badge
      expect(find.text("TODAY'S REVISION"), findsOneWidget);
      expect(find.text('ALL REVISED'), findsOneWidget);

      // Topic title rendered with strikethrough
      final textFinder = find.text('Activation Functions & Sigmoids');
      expect(textFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.decoration, TextDecoration.lineThrough);

      // Points badge and prompt rendered
      expect(find.text('+1.0 pts'), findsOneWidget);
      expect(find.text('What is the vanishing gradient problem in deep sigmoids?'), findsOneWidget);

      // Done checkmark icon visible
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    test('RevisionService enforces dynamic 1-topic cap for heavy days and bridges prerequisites via AI', () async {
      final service = RevisionService();
      await service.init();
      final ai = LocalInferenceService();
      final now = DateTime.now();

      final roadmap = RoadmapEntity(
        id: 'rm_cap_test',
        title: 'Deep Learning Track',
        targetCompletionDate: now.add(const Duration(days: 30)),
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
      );

      // 4 completed beats in the past
      final completedBeats = List.generate(4, (i) => BeatEntity(
        id: 'past_beat_$i',
        chapterId: 'ch_1',
        roadmapId: roadmap.id,
        title: i == 0 ? 'Weight Initialization He Xavier' : 'Gradient Descent Step $i',
        effortWeight: 1.0,
        sortOrder: i,
        isCompleted: true,
        completedAt: now.subtract(Duration(days: 3 * (i + 1))),
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(Duration(days: 3 * (i + 1))),
      ));

      final upcomingBeat = BeatEntity(
        id: 'upcoming_1',
        chapterId: 'ch_2',
        roadmapId: roadmap.id,
        title: 'Deep Weight Initialization & Residual Scaling',
        effortWeight: 3.0, // heavy
        sortOrder: 10,
        isCompleted: false,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now,
      );

      // Heavy day: todayEffortBudget = 3.0 -> strictly 1 topic cap
      final recommendationsHeavy = await service.getDailyRevisionRecommendations(
        roadmaps: [roadmap],
        beatsByRoadmap: {roadmap.id: [...completedBeats, upcomingBeat]},
        upcomingFocusBeats: [upcomingBeat],
        todayEffortBudget: 3.0,
        inferenceService: ai,
        referenceDate: now,
      );

      expect(recommendationsHeavy.length, 1);
      expect(recommendationsHeavy.first.beatPoints, greaterThan(0));

      // Light day: todayEffortBudget = 1.5 -> max 2 topics cap
      final recommendationsLight = await service.getDailyRevisionRecommendations(
        roadmaps: [roadmap],
        beatsByRoadmap: {roadmap.id: [...completedBeats, upcomingBeat]},
        upcomingFocusBeats: [upcomingBeat],
        todayEffortBudget: 1.5,
        inferenceService: ai,
        referenceDate: now,
      );

      expect(recommendationsLight.length, inInclusiveRange(1, 2));
    });
  });
}


