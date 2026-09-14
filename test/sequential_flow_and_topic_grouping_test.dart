import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/explore/widgets/chapter_accordion.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService.instance.initInMemoryForTesting();
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  test('BeatRepository returns beats ordered strictly by chapter sequence then beat sort order', () async {
    final roadmapRepo = RoadmapRepository();
    final chapterRepo = ChapterRepository();
    final beatRepo = BeatRepository();

    final rm = RoadmapEntity(
      id: 'rm_sequential_test',
      title: 'Sequential Test Roadmap',
      description: 'Testing chapter sequence priority',
      targetCompletionDate: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await roadmapRepo.createRoadmap(rm);

    // Create 2 chapters with sortOrder 0 and 1
    final ch1 = ChapterEntity(
      id: 'ch_0',
      roadmapId: rm.id,
      title: 'Chapter 1: Algebra',
      sortOrder: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final ch2 = ChapterEntity(
      id: 'ch_1',
      roadmapId: rm.id,
      title: 'Chapter 2: Calculus',
      sortOrder: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await chapterRepo.createChaptersBatch([ch1, ch2]);

    // Insert beats where ch2 beats happen to have lower or overlapping sortOrders
    final beats = [
      BeatEntity(
        id: 'b_ch2_0',
        chapterId: ch2.id,
        roadmapId: rm.id,
        title: 'Calculus Lecture 1',
        sortOrder: 0, // Colliding sortOrder 0 in chapter 2
        effortWeight: 1.0,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      BeatEntity(
        id: 'b_ch1_0',
        chapterId: ch1.id,
        roadmapId: rm.id,
        title: 'Algebra Lecture 1',
        sortOrder: 0, // SortOrder 0 in chapter 1
        effortWeight: 1.0,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      BeatEntity(
        id: 'b_ch1_1',
        chapterId: ch1.id,
        roadmapId: rm.id,
        title: 'Algebra Lecture 2',
        sortOrder: 1, // SortOrder 1 in chapter 1
        effortWeight: 1.0,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];
    await beatRepo.createBeatsBatch(beats);

    // Fetch beats by roadmap id
    final orderedBeats = await beatRepo.getBeatsByRoadmapId(rm.id);

    // Ground Truth: Chapter 1 beats MUST come before Chapter 2 beats!
    expect(orderedBeats[0].title, 'Algebra Lecture 1');
    expect(orderedBeats[1].title, 'Algebra Lecture 2');
    expect(orderedBeats[2].title, 'Calculus Lecture 1');
  });

  testWidgets('ChapterAccordion groups beats into categorized topic sections with sub-headers', (tester) async {
    final chapter = ChapterEntity(
      id: 'ch_test',
      roadmapId: 'rm_test',
      title: 'Chapter 1: Precalculus',
      sortOrder: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final beats = [
      // Topic 1
      BeatEntity(
        id: 'b1',
        chapterId: chapter.id,
        roadmapId: 'rm_test',
        title: 'Functions: Lecture 1',
        sourceUrl: 'https://youtube.com/watch?v=1',
        syllabusTopicId: 'Functions and Graphs',
        sortOrder: 0,
        effortWeight: 1.0,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      // Topic 2
      BeatEntity(
        id: 'b2',
        chapterId: chapter.id,
        roadmapId: 'rm_test',
        title: 'Polynomials: Lecture 1',
        sourceUrl: 'https://youtube.com/watch?v=2',
        syllabusTopicId: 'Polynomial Functions',
        sortOrder: 1,
        effortWeight: 1.0,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      // Mentor Extra
      BeatEntity(
        id: 'b3',
        chapterId: chapter.id,
        roadmapId: 'rm_test',
        title: 'Bonus: Calculator Shortcuts',
        sourceUrl: 'https://youtube.com/watch?v=3',
        isMentorExtra: true,
        sortOrder: 2,
        effortWeight: 1.0,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      // Gap topic
      BeatEntity(
        id: 'b4',
        chapterId: chapter.id,
        roadmapId: 'rm_test',
        title: 'Conic Sections',
        sourceUrl: null, // Gap
        isMentorExtra: false,
        syllabusTopicId: 'Conic Sections',
        sortOrder: 3,
        effortWeight: 1.0,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: RythemTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChapterAccordion(
              chapter: chapter,
              beats: beats,
              initialExpanded: true,
              onBeatToggled: (_, __) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify categorized topic section headers are rendered
    expect(find.text('Topic 1: Functions and Graphs'), findsOneWidget);
    expect(find.text('Topic 2: Polynomial Functions'), findsOneWidget);
    expect(find.text('✦ Bonus & Enrichment'), findsOneWidget);
    expect(find.text('⚠️ Uncovered Syllabus Gaps'), findsOneWidget);
  });
}
