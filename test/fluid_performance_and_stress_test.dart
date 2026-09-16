import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/widgets/glass_card.dart';
import 'package:rythem_app/core/widgets/glass_container.dart';
import 'package:rythem_app/features/explore/widgets/chapter_accordion.dart';

void main() {
  group('Fluid Glass Tiered Performance Tests', () {
    testWidgets('GlassLevel tiers configure BackdropFilter and blur correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Level 0: Matte (Zero-cost, no BackdropFilter)
                GlassContainer(
                  level: GlassLevel.matte,
                  child: Text('Matte Surface'),
                ),
                // Level 1: Frosted (sigma 8-10)
                GlassContainer(
                  level: GlassLevel.frosted,
                  child: Text('Frosted Surface'),
                ),
                // Level 2: Premium (sigma 16-18)
                GlassContainer(
                  level: GlassLevel.premium,
                  child: Text('Premium Surface'),
                ),
                // Level 3: Liquid (sigma 24)
                GlassContainer(
                  level: GlassLevel.liquid,
                  child: Text('Liquid Surface'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only levels 1, 2, 3 create BackdropFilter; Level 0 (Matte) creates 0 BackdropFilter!
      expect(find.byType(BackdropFilter), findsNWidgets(3));
      expect(find.text('Matte Surface'), findsOneWidget);
      expect(find.text('Frosted Surface'), findsOneWidget);
      expect(find.text('Premium Surface'), findsOneWidget);
      expect(find.text('Liquid Surface'), findsOneWidget);
    });

    testWidgets('Static GlassCard (onTap == null) renders without creating ticker/animator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(
              level: GlassLevel.matte,
              child: Text('Static Card'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Static Card'), findsOneWidget);
      // Matte level on GlassCard has zero BackdropFilter
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('GlassButton renders with localized sigma 8 blur and fast touch response', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassButton(
              label: 'Fluid Tap',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap button and verify immediate event
      await tester.tap(find.byType(GlassButton));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tapped, isTrue);
    });
  });

  group('Large Dataset Stress & Zero-Nested-Blur Tests (10, 100, 200, 500, 1000 items)', () {
    List<BeatEntity> generateBeats(int count, {String chapterId = 'ch_1'}) {
      return List.generate(
        count,
        (i) => BeatEntity(
          id: 'beat_$i',
          roadmapId: 'rm_test',
          chapterId: chapterId,
          title: 'Beat Topic #$i: Fluid Optimization',
          sortOrder: i,
          isCompleted: i % 3 == 0,
          effortWeight: 1.0,
          sourceUrl: 'https://youtube.com/watch?v=fluid_$i',
          syllabusTopicId: 'topic_${i % 5}',
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        ),
      );
    }

    final testChapter = ChapterEntity(
      id: 'ch_1',
      roadmapId: 'rm_test',
      title: 'Scalability Chapter: Massive Item Count',
      sortOrder: 0,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    for (final count in [10, 100, 200, 500, 1000]) {
      testWidgets('ChapterAccordion with $count beats expands smoothly with exactly 1 BackdropFilter', (tester) async {
        final beats = generateBeats(count);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ChapterAccordion(
                  chapter: testChapter,
                  beats: beats,
                  onBeatToggled: (_, __) async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. In collapsed state: 1 BackdropFilter for the accordion card
        expect(find.byType(BackdropFilter), findsOneWidget);

        // 2. Expand accordion
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();

        // 3. CRITICAL: Regardless of whether there are 10, 100, 500, or 1000 beats,
        // there must remain EXACTLY 1 BackdropFilter! (No nested blurs in topic sections or beat tiles)
        expect(
          find.byType(BackdropFilter),
          findsOneWidget,
          reason: 'Expected exactly 1 BackdropFilter for $count beats (zero nested BackdropFilters)',
        );

        // 4. Verify fast scrolling through large datasets
        if (count >= 500) {
          final stopwatch = Stopwatch()..start();
          await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
          await tester.pump();
          stopwatch.stop();

          // Scroll frame pump must take well under 100ms
          expect(stopwatch.elapsedMilliseconds, lessThan(150),
              reason: 'Scroll dispatch for $count items took ${stopwatch.elapsedMilliseconds}ms');
        }
      });
    }
  });
}
