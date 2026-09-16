import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/pacing/models/pacing_budget.dart';
import 'package:rythem_app/core/pacing/models/pacing_decision.dart';
import 'package:rythem_app/features/flow/widgets/backlog_decision_sheet.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('BacklogDecisionSheet Tests', () {
    final testRoadmap = RoadmapEntity(
      id: 'rm_test',
      title: 'Advanced Robotics',
      description: 'Autonomous navigation',
      targetCompletionDate: DateTime.now().add(const Duration(days: 10)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    const testBudget = PacingBudget(
      roadmapId: 'rm_test',
      remainingEffort: 15.0,
      daysLeft: 10,
      todayEffortShare: 1.5,
      todaysBeats: [],
      todaysSelectedEffort: 0.0,
      isRoadmapCompleted: false,
      isDailyQuotaCompleted: false,
      isSustainedLag: true,
      lagStreakDays: 3,
      recentVelocity: 0.8,
    );

    testWidgets('renders all 4 non-punitive adaptation options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BacklogDecisionSheet(
              roadmap: testRoadmap,
              pacingBudget: testBudget,
              onDecisionSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BACKLOG RECALIBRATION'), findsOneWidget);
      expect(find.textContaining('Push Target Date'), findsOneWidget);
      expect(find.text('Trim to Core Must-Do Beats'), findsOneWidget);
      expect(find.text('Accept & Keep Pace'), findsOneWidget);
    });

    testWidgets('selecting push target date fires extendTargetDate decision', (tester) async {
      PacingDecision? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BacklogDecisionSheet(
              roadmap: testRoadmap,
              pacingBudget: testBudget,
              onDecisionSelected: (d) => selected = d,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pushOption = find.textContaining('Push Target Date');
      expect(pushOption, findsOneWidget);

      await tester.tap(pushOption);
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.type, PacingDecisionType.extendTargetDate);
      expect(selected!.extensionDays, greaterThan(0));
    });

    testWidgets('selecting trim to core fires trimToCore decision', (tester) async {
      PacingDecision? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BacklogDecisionSheet(
              roadmap: testRoadmap,
              pacingBudget: testBudget,
              onDecisionSelected: (d) => selected = d,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trimOption = find.text('Trim to Core Must-Do Beats');
      await tester.tap(trimOption);
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.type, PacingDecisionType.trimToCore);
    });

    testWidgets('selecting keep pace fires acceptAndContinue decision', (tester) async {
      PacingDecision? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BacklogDecisionSheet(
              roadmap: testRoadmap,
              pacingBudget: testBudget,
              onDecisionSelected: (d) => selected = d,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final keepOption = find.text('Accept & Keep Pace');
      await tester.tap(keepOption);
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.type, PacingDecisionType.acceptAndContinue);
    });
  });
}
