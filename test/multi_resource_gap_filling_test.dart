import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/ingestion/models/extracted_resource.dart';
import 'package:rythem_app/core/ingestion/parsers/syllabus_parser.dart';
import 'package:rythem_app/core/ingestion/services/curriculum_ingestion_service.dart';
import 'package:rythem_app/core/ingestion/services/youtube_extractor_service.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/explore/widgets/chapter_accordion.dart';

class MultiResourceMockYoutubeClient implements IYoutubeClient {
  @override
  void close() {}

  @override
  Future<ExtractedResource> extractPlaylist(String playlistUrl) async =>
      extractResource(playlistUrl);

  @override
  Future<ExtractedResource> extractVideo(String videoUrl) async =>
      extractResource(videoUrl);

  @override
  Future<ExtractedResource> extractResource(String url) async {
    if (url.contains('res1')) {
      return const ExtractedResource(
        title: 'Resource 1: Fundamentals',
        description: 'First playlist',
        author: 'Mentor Alpha',
        sourceUrl: 'https://youtube.com/playlist?list=res1',
        resourceType: ExtractedResourceType.playlist,
        items: [
          RawResourceItem(
            title: 'Topic 1: Arrays & Dynamic Lists Explained',
            sourceUrl: 'https://youtube.com/watch?v=res1_v1',
            durationSeconds: 1200,
            index: 0,
          ),
          RawResourceItem(
            title: 'Topic 2: Hash Tables & Collisions Deep Dive',
            sourceUrl: 'https://youtube.com/watch?v=res1_v2',
            durationSeconds: 1500,
            index: 1,
          ),
          RawResourceItem(
            title: 'Mentor Extra: Setting up Development Environment',
            sourceUrl: 'https://youtube.com/watch?v=res1_v3',
            durationSeconds: 600,
            index: 2,
          ),
        ],
      );
    } else if (url.contains('res2')) {
      return const ExtractedResource(
        title: 'Resource 2: Trees & Advanced Data Structures',
        description: 'Second playlist to fill gap',
        author: 'Mentor Beta',
        sourceUrl: 'https://youtube.com/playlist?list=res2',
        resourceType: ExtractedResourceType.playlist,
        items: [
          RawResourceItem(
            title: 'Topic 3: Binary Search Trees in Depth',
            sourceUrl: 'https://youtube.com/watch?v=res2_v1',
            durationSeconds: 1800,
            index: 0,
          ),
          RawResourceItem(
            title: 'Bonus Lab: Setting up Docker Container',
            sourceUrl: 'https://youtube.com/watch?v=res2_v2',
            durationSeconds: 1100,
            index: 1,
          ),
        ],
      );
    } else {
      // Resource 3
      return const ExtractedResource(
        title: 'Resource 3: Graphs Specialization',
        description: 'Final gap filler',
        author: 'Mentor Gamma',
        sourceUrl: 'https://youtube.com/playlist?list=res3',
        resourceType: ExtractedResourceType.playlist,
        items: [
          RawResourceItem(
            title: 'Topic 4: Graph Traversals DFS & BFS Complete Guide',
            sourceUrl: 'https://youtube.com/watch?v=res3_v1',
            durationSeconds: 2400,
            index: 0,
          ),
        ],
      );
    }
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    await DatabaseService.instance.initInMemoryForTesting();
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  group('Multi-Resource Sequential Stacking & Gap-Filling Pipeline Tests', () {
    const syllabusMarkdown = '''
# Module 1: Data Structures
- Topic 1: Arrays & Dynamic Lists
- Topic 2: Hash Tables & Collisions
- Topic 3: Binary Search Trees
- Topic 4: Graph Traversals DFS & BFS
''';

    test('Sequential stacking: Resource 1 -> Resource 2 -> Resource 3 fills gaps one-by-one and preserves mentor order', () async {
      final mockClient = MultiResourceMockYoutubeClient();
      final ingestionService = CurriculumIngestionService(youtubeClient: mockClient);
      final chapterRepo = ChapterRepository();
      final beatRepo = BeatRepository();

      // Step 1: Create initial track from syllabus with 4 syllabus topics
      final parsed = SyllabusParser.parse(syllabusMarkdown, defaultTitle: 'Data Structures');
      final creationResult = await ingestionService.ingestFromSyllabus(
        title: 'Data Structures',
        category: 'Computer Science',
        targetDate: DateTime.now().add(const Duration(days: 60)),
        syllabus: parsed,
      );

      final roadmapId = creationResult.roadmapId;
      final chapters = await chapterRepo.getChaptersByRoadmapId(roadmapId);
      expect(chapters.length, 1);
      final chapterId = chapters.first.id;

      // Initial state: 4 gap beats representing syllabus topics
      final initialBeats = await beatRepo.getBeatsByChapterId(chapterId);
      expect(initialBeats.length, 4);
      expect(initialBeats.every((b) => b.sourceUrl == null), isTrue);

      // Step 2: Attach Resource 1
      final audit1 = await ingestionService.attachResourceToSubject(
        roadmapId: roadmapId,
        chapterId: chapterId,
        resourceUrl: 'https://youtube.com/playlist?list=res1',
      );

      expect(audit1, isNotNull);
      final afterRes1Beats = await beatRepo.getBeatsByChapterId(chapterId);
      // Resource 1 has 3 videos, plus 2 remaining uncovered gap topics (Topic 3 & Topic 4) = 5 total beats
      expect(afterRes1Beats.length, 5);

      final r1VideoBeats = afterRes1Beats.where((b) => b.sourceUrl != null).toList();
      final r1GapBeats = afterRes1Beats.where((b) => b.sourceUrl == null).toList();

      expect(r1VideoBeats.length, 3);
      expect(r1GapBeats.length, 2);

      // Verify mentor order of Resource 1: sortOrder 0, 1, 2
      expect(r1VideoBeats[0].title, contains('Arrays & Dynamic Lists'));
      expect(r1VideoBeats[0].sortOrder, 0);
      expect(r1VideoBeats[1].title, contains('Hash Tables & Collisions'));
      expect(r1VideoBeats[1].sortOrder, 1);
      expect(r1VideoBeats[2].title, contains('Mentor Extra'));
      expect(r1VideoBeats[2].sortOrder, 2);
      expect(r1VideoBeats[2].isMentorExtra, isTrue);

      // Remaining gap topics are placed at the bottom: sortOrder 3, 4
      expect(r1GapBeats[0].sortOrder, 3);
      expect(r1GapBeats[0].title, contains('Binary Search Trees'));
      expect(r1GapBeats[1].sortOrder, 4);
      expect(r1GapBeats[1].title, contains('Graph Traversals'));

      // Step 3: User completes first video of Resource 1
      final completedBeat1 = r1VideoBeats[0].copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );
      await beatRepo.updateBeat(completedBeat1);

      // Step 4: Attach Resource 2 (stacked on same chapter to fill remaining gap)
      final audit2 = await ingestionService.attachResourceToSubject(
        roadmapId: roadmapId,
        chapterId: chapterId,
        resourceUrl: 'https://youtube.com/playlist?list=res2',
      );

      expect(audit2, isNotNull);
      final afterRes2Beats = await beatRepo.getBeatsByChapterId(chapterId);
      // Res 1 (3 videos) + Res 2 (2 videos) + Remaining Gap (1 topic: Graph Traversals) = 6 beats
      expect(afterRes2Beats.length, 6);

      // Verify Resource 1 progress was 100% PRESERVED!
      expect(afterRes2Beats[0].id, r1VideoBeats[0].id);
      expect(afterRes2Beats[0].isCompleted, isTrue);
      expect(afterRes2Beats[0].sortOrder, 0);

      expect(afterRes2Beats[1].id, r1VideoBeats[1].id);
      expect(afterRes2Beats[1].isCompleted, isFalse);
      expect(afterRes2Beats[1].sortOrder, 1);

      expect(afterRes2Beats[2].id, r1VideoBeats[2].id);
      expect(afterRes2Beats[2].sortOrder, 2);

      // Verify Resource 2 was stacked immediately after Resource 1 in exact mentor order:
      final r2Video1 = afterRes2Beats[3];
      final r2Video2 = afterRes2Beats[4];
      expect(r2Video1.id, contains('_r2_v_0'));
      expect(r2Video1.sortOrder, 3);
      expect(r2Video1.title, contains('Binary Search Trees'));

      expect(r2Video2.id, contains('_r2_v_1'));
      expect(r2Video2.sortOrder, 4);
      expect(r2Video2.title, contains('Docker Container'));
      expect(r2Video2.isMentorExtra, isTrue);

      // Verify only 1 gap beat remains at the very bottom:
      final remainingGap = afterRes2Beats[5];
      expect(remainingGap.sourceUrl, isNull);
      expect(remainingGap.sortOrder, 5);
      expect(remainingGap.title, contains('Graph Traversals'));

      // Step 5: Attach Resource 3 to fill the final gap
      await ingestionService.attachResourceToSubject(
        roadmapId: roadmapId,
        chapterId: chapterId,
        resourceUrl: 'https://youtube.com/playlist?list=res3',
      );

      final finalBeats = await beatRepo.getBeatsByChapterId(chapterId);
      // All 6 video beats present, 0 gaps remaining!
      expect(finalBeats.length, 6);
      expect(finalBeats.every((b) => b.sourceUrl != null), isTrue);

      // Verify final video is from Resource 3:
      final r3Video = finalBeats[5];
      expect(r3Video.id, contains('_r3_v_0'));
      expect(r3Video.sortOrder, 5);
      expect(r3Video.title, contains('Graph Traversals'));

      // Continuous strictly ascending sort orders 0..5:
      for (int i = 0; i < finalBeats.length; i++) {
        expect(finalBeats[i].sortOrder, i);
      }
    });

    test('PacingQueueWalker serves beats in strict sequential order across stacked resources', () {
      final now = DateTime.now();

      final stackedBeats = [
        // Resource 1
        BeatEntity(
          id: 'ch1_v_0',
          chapterId: 'ch_1',
          roadmapId: 'rm_test',
          title: 'Res 1 Video 1',
          sortOrder: 0,
          isCompleted: true,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'ch1_v_1',
          chapterId: 'ch_1',
          roadmapId: 'rm_test',
          title: 'Res 1 Video 2',
          sortOrder: 1,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        // Resource 2
        BeatEntity(
          id: 'ch1_r2_v_0',
          chapterId: 'ch_1',
          roadmapId: 'rm_test',
          title: 'Res 2 Video 1',
          sortOrder: 2,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Walking budget for effort = 1.0 pulls the next incomplete beat from Resource 1 first!
      final selection = PacingCalculator.walkQueueToFillBudget(
        pendingBeats: stackedBeats.where((b) => !b.isCompleted).toList(),
        targetBudget: 1.0,
      );

      expect(selection.length, 1);
      expect(selection.first.id, 'ch1_v_1');
      expect(selection.first.title, 'Res 1 Video 2');
    });
  });

  group('ChapterAccordion Multi-Resource UI Tests', () {
    testWidgets('ChapterAccordion renders Fill Gap button and RESOURCE 2 badge', (tester) async {
      final now = DateTime.now();
      final testChapter = ChapterEntity(
        id: 'ch_test',
        roadmapId: 'rm_test',
        title: 'Systems & Algorithms',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      final testBeats = [
        BeatEntity(
          id: 'ch_test_v_0',
          chapterId: 'ch_test',
          roadmapId: 'rm_test',
          title: 'Resource 1 Core Video',
          sourceUrl: 'https://youtube.com/watch?v=res1',
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'ch_test_r2_v_0',
          chapterId: 'ch_test',
          roadmapId: 'rm_test',
          title: 'Resource 2 Stacked Video',
          sourceUrl: 'https://youtube.com/watch?v=res2',
          sortOrder: 1,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'ch_test_gap_0',
          chapterId: 'ch_test',
          roadmapId: 'rm_test',
          title: 'Uncovered Syllabus Topic Gap',
          sourceUrl: null,
          sortOrder: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      bool fillGapTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChapterAccordion(
                chapter: testChapter,
                beats: testBeats,
                initialExpanded: true,
                onBeatToggled: (_, __) async {},
                onAttachResourceToChapter: (ch) {
                  fillGapTapped = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Chapter and beats
      expect(find.text('Systems & Algorithms'), findsOneWidget);
      expect(find.text('Resource 1 Core Video'), findsOneWidget);
      expect(find.text('Resource 2 Stacked Video'), findsOneWidget);

      // Verify RESOURCE 2 badge rendered on stacked beat
      expect(find.text('RESOURCE 2'), findsOneWidget);

      // Verify Uncovered Syllabus Gaps section and Fill Gap button
      expect(find.text('⚠️ Uncovered Syllabus Gaps'), findsOneWidget);
      expect(find.text('Fill Gap'), findsOneWidget);

      // Tap Fill Gap button
      await tester.tap(find.text('Fill Gap'));
      await tester.pumpAndSettle();

      expect(fillGapTapped, isTrue);
    });
  });
}
