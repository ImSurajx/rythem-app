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
      expect(find.text('DAILY REVISION BOARD'), findsOneWidget);
      expect(find.text('1 DUE'), findsOneWidget);
      expect(find.text('Loss Surfaces & Hessian Matrices'), findsOneWidget);
      expect(find.text('Flagged Weak Concept'), findsOneWidget);

      // Tap Mark Revised check button
      final checkButton = find.byKey(const Key('revision_check_button_beat_sample'));
      expect(checkButton, findsOneWidget);
      await tester.tap(checkButton);
      await tester.pump();

      expect(revisedItem?.beatId, 'beat_sample');

      // Tap Quick Breakdown from AI Mentor button
      final breakdownButton = find.text('Quick Breakdown from AI Mentor');
      await tester.tap(breakdownButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('AI Mentor Concept Breakdown'), findsOneWidget);
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
  });
}
