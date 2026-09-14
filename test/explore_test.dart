import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/explore/explore_screen.dart';
import 'package:rythem_app/features/explore/new_track_modal.dart';
import 'package:rythem_app/features/explore/roadmap_detail_screen.dart';
import 'package:rythem_app/features/explore/widgets/chapter_accordion.dart';

void main() {
  final now = DateTime(2026, 9, 13, 10, 0);

  final testRoadmap1 = RoadmapEntity(
    id: 'rm_1',
    title: 'Distributed Systems Architecture',
    description: 'Engineering',
    targetCompletionDate: now.add(const Duration(days: 14)),
    status: 'active',
    createdAt: now,
    updatedAt: now,
  );

  final testRoadmap2 = RoadmapEntity(
    id: 'rm_2',
    title: 'Linear Algebra & Tensors',
    description: 'Mathematics',
    targetCompletionDate: now.add(const Duration(days: 21)),
    status: 'active',
    createdAt: now,
    updatedAt: now,
  );

  final testChapter1 = ChapterEntity(
    id: 'ch_1',
    roadmapId: 'rm_1',
    title: 'Consensus & Raft Protocol',
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );

  final testChapter2 = ChapterEntity(
    id: 'ch_2',
    roadmapId: 'rm_1',
    title: 'Vector Clocks & Causality',
    sortOrder: 1,
    createdAt: now,
    updatedAt: now,
  );

  final testBeats = [
    BeatEntity(
      id: 'b1',
      chapterId: 'ch_1',
      roadmapId: 'rm_1',
      title: 'State Machine Replication',
      effortWeight: 1.0,
      sortOrder: 0,
      isCompleted: true,
      createdAt: now,
      updatedAt: now,
    ),
    BeatEntity(
      id: 'b2',
      chapterId: 'ch_1',
      roadmapId: 'rm_1',
      title: 'Leader Election Dynamics',
      effortWeight: 1.5,
      sortOrder: 1,
      isCompleted: false,
      isMentorExtra: true, // Mentor Extra test beat
      createdAt: now,
      updatedAt: now,
    ),
    BeatEntity(
      id: 'b3',
      chapterId: 'ch_2',
      roadmapId: 'rm_1',
      title: 'Happens-Before Relationship',
      effortWeight: 1.0,
      sortOrder: 0,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  group('ExploreScreen Catalog Tests', () {
    testWidgets('renders all roadmap cards with categories and beat ratios', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: ExploreScreen(
              roadmaps: [testRoadmap1, testRoadmap2],
              chaptersByRoadmap: {
                'rm_1': [testChapter1, testChapter2],
                'rm_2': const [],
              },
              beatsByRoadmap: {
                'rm_1': testBeats,
                'rm_2': const [],
              },
              onBeatToggled: (_, __) async {},
              onCreateTrack: ({
                required String title,
                required String category,
                required DateTime targetDate,
                String? resourceUrl,
                String? syllabusText,
              }) async {},
            ),
          ),
        ),
      );

      // Verify Header & New Track Button
      expect(find.text('EXPLORE'), findsOneWidget);
      expect(find.text('All Tracks'), findsOneWidget);
      expect(find.text('New Track'), findsOneWidget);

      // Verify Roadmap Cards
      expect(find.text('Distributed Systems Architecture'), findsOneWidget);
      expect(find.text('Linear Algebra & Tensors'), findsOneWidget);
      expect(find.text('ENGINEERING'), findsOneWidget);
      expect(find.text('MATHEMATICS'), findsOneWidget);
      expect(find.text('1 of 3 beats'), findsOneWidget);
    });

    testWidgets('filters roadmap cards in real time via search field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: ExploreScreen(
              roadmaps: [testRoadmap1, testRoadmap2],
              chaptersByRoadmap: {'rm_1': [testChapter1], 'rm_2': const []},
              beatsByRoadmap: {'rm_1': testBeats, 'rm_2': const []},
              onBeatToggled: (_, __) async {},
              onCreateTrack: ({
                required String title,
                required String category,
                required DateTime targetDate,
                String? resourceUrl,
                String? syllabusText,
              }) async {},
            ),
          ),
        ),
      );

      // Search for "Tensors"
      await tester.enterText(find.byType(TextField), 'Tensors');
      await tester.pumpAndSettle();

      // Only Roadmap 2 should be visible
      expect(find.text('Linear Algebra & Tensors'), findsOneWidget);
      expect(find.text('Distributed Systems Architecture'), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('Distributed Systems Architecture'), findsOneWidget);
      expect(find.text('Linear Algebra & Tensors'), findsOneWidget);
    });
  });

  group('NewTrackModal Creation Tests', () {
    testWidgets('submits new track with title and selected category', (tester) async {
      String? createdTitle;
      String? createdCategory;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    NewTrackModal.show(
                      ctx,
                      onCreateTrack: ({
                        required String title,
                        required String category,
                        required DateTime targetDate,
                        String? resourceUrl,
                        String? syllabusText,
                      }) async {
                        createdTitle = title;
                        createdCategory = category;
                      },
                    );
                  },
                  child: const Text('Open Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open Modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE NEW TRACK'), findsOneWidget);

      // Enter track title
      await tester.enterText(find.byType(TextField).first, 'Quantum Computing Basics');
      await tester.pump();

      // Select Mathematics category
      await tester.tap(find.text('Mathematics'));
      await tester.pump();

      // Tap Create Track
      await tester.tap(find.text('Create Track'));
      await tester.pumpAndSettle();

      expect(createdTitle, 'Quantum Computing Basics');
      expect(createdCategory, 'Mathematics');
    });
  });

  group('RoadmapDetailScreen & ChapterAccordion Tests', () {
    testWidgets('renders chapters with first chapter expanded and mentor extra badge', (tester) async {
      BeatEntity? toggledBeat;
      bool? toggledVal;
      RoadmapEntity? archivedRm;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: RoadmapDetailScreen(
            roadmap: testRoadmap1,
            chapters: [testChapter1, testChapter2],
            beats: testBeats,
            onBeatToggled: (beat, val) async {
              toggledBeat = beat;
              toggledVal = val;
            },
            onArchiveRoadmap: (rm) async {
              archivedRm = rm;
            },
          ),
        ),
      );

      // Header info
      expect(find.text('Distributed Systems Architecture'), findsWidgets);
      expect(find.text('ENGINEERING'), findsOneWidget);
      expect(find.text('1 of 3 beats completed'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);

      // Chapter 1 beats visible (first chapter expanded by default)
      expect(find.text('Consensus & Raft Protocol'), findsOneWidget);
      expect(find.text('State Machine Replication'), findsOneWidget);
      expect(find.text('Leader Election Dynamics'), findsOneWidget);

      // Mentor extra badge rendered on unaligned beat b2
      expect(find.text('MENTOR EXTRA'), findsOneWidget);

      // Toggle a beat checkbox
      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pump();

      expect(toggledBeat?.id, 'b1');
      expect(toggledVal, false);

      // Test Archive Track button
      final archiveBtn = find.byIcon(Icons.archive_outlined);
      expect(archiveBtn, findsOneWidget);
      await tester.tap(archiveBtn);
      await tester.pump();

      expect(archivedRm?.id, 'rm_1');
    });

    testWidgets('chapter accordion expands and collapses on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: ChapterAccordion(
              chapter: testChapter2,
              beats: [testBeats[2]],
              initialExpanded: false, // collapsed initially
              onBeatToggled: (_, __) async {},
              onBeatTapped: (_) {},
            ),
          ),
        ),
      );

      // Chapter header visible
      expect(find.text('Vector Clocks & Causality'), findsOneWidget);

      // Tap header to expand
      await tester.tap(find.text('Vector Clocks & Causality'));
      await tester.pumpAndSettle();

      // Beat should now be visible
      expect(find.text('Happens-Before Relationship'), findsOneWidget);

      // Tap header again to collapse
      await tester.tap(find.text('Vector Clocks & Causality'));
      await tester.pumpAndSettle();
    });
  });
}
