import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/features/explore/roadmap_detail_screen.dart';
import 'package:rythem_app/features/explore/widgets/chapter_accordion.dart';
import 'package:rythem_app/features/onboarding/onboarding_wizard_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late Database testDb;
  late BeatRepository beatRepo;
  late RoadmapRepository roadmapRepo;
  late ChapterRepository chapterRepo;

  setUp(() async {
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await testDb.execute('''
      CREATE TABLE ${DatabaseTables.roadmaps} (
        ${RoadmapColumns.id} TEXT PRIMARY KEY,
        ${RoadmapColumns.title} TEXT NOT NULL,
        ${RoadmapColumns.description} TEXT NOT NULL,
        ${RoadmapColumns.startDate} TEXT,
        ${RoadmapColumns.targetCompletionDate} TEXT,
        ${RoadmapColumns.status} TEXT NOT NULL DEFAULT 'active',
        ${RoadmapColumns.isPrimary} INTEGER NOT NULL DEFAULT 0,
        ${RoadmapColumns.createdAt} TEXT NOT NULL,
        ${RoadmapColumns.updatedAt} TEXT NOT NULL
      );
    ''');
    await testDb.execute('''
      CREATE TABLE ${DatabaseTables.chapters} (
        ${ChapterColumns.id} TEXT PRIMARY KEY,
        ${ChapterColumns.roadmapId} TEXT NOT NULL,
        ${ChapterColumns.title} TEXT NOT NULL,
        ${ChapterColumns.sortOrder} INTEGER NOT NULL DEFAULT 0,
        ${ChapterColumns.createdAt} TEXT NOT NULL,
        ${ChapterColumns.updatedAt} TEXT NOT NULL
      );
    ''');
    await testDb.execute('''
      CREATE TABLE ${DatabaseTables.beats} (
        ${BeatColumns.id} TEXT PRIMARY KEY,
        ${BeatColumns.chapterId} TEXT NOT NULL,
        ${BeatColumns.roadmapId} TEXT NOT NULL,
        ${BeatColumns.title} TEXT NOT NULL,
        ${BeatColumns.sourceUrl} TEXT,
        ${BeatColumns.timestampSeconds} INTEGER,
        ${BeatColumns.effortWeight} REAL NOT NULL DEFAULT 1.0,
        ${BeatColumns.sortOrder} INTEGER NOT NULL DEFAULT 0,
        ${BeatColumns.isCompleted} INTEGER NOT NULL DEFAULT 0,
        ${BeatColumns.completedAt} TEXT,
        ${BeatColumns.isMentorExtra} INTEGER NOT NULL DEFAULT 0,
        ${BeatColumns.matchConfidence} REAL,
        ${BeatColumns.syllabusTopicId} TEXT,
        ${BeatColumns.totalParts} INTEGER NOT NULL DEFAULT 1,
        ${BeatColumns.completedParts} INTEGER NOT NULL DEFAULT 0,
        ${BeatColumns.createdAt} TEXT NOT NULL,
        ${BeatColumns.updatedAt} TEXT NOT NULL
      );
    ''');
    await testDb.execute('''
      CREATE TABLE ${DatabaseTables.beatLogs} (
        ${BeatLogColumns.id} TEXT PRIMARY KEY,
        ${BeatLogColumns.beatId} TEXT NOT NULL,
        ${BeatLogColumns.roadmapId} TEXT NOT NULL,
        ${BeatLogColumns.completedDate} TEXT NOT NULL,
        ${BeatLogColumns.createdAt} TEXT NOT NULL
      );
    ''');
    await testDb.execute('''
      CREATE TABLE ${DatabaseTables.appSettings} (
        ${AppSettingsColumns.key} TEXT PRIMARY KEY,
        ${AppSettingsColumns.value} TEXT NOT NULL,
        ${AppSettingsColumns.updatedAt} TEXT NOT NULL
      );
    ''');
    DatabaseService.instance.setDatabaseForTesting(testDb);
    beatRepo = BeatRepository();
    roadmapRepo = RoadmapRepository();
    chapterRepo = ChapterRepository();
  });

  tearDown(() async {
    DatabaseService.instance.setDatabaseForTesting(null);
    await testDb.close();
  });

  group('Todo & Tracker Synchronization Tests', () {
    test('Rapid consecutive toggles of 3 tasks in SQLite sync properly across BeatRepository', () async {
      final now = DateTime.now();
      final rm = RoadmapEntity(
        id: 'rm_sync',
        title: 'Deep Learning',
        description: 'AI & Math',
        createdAt: now,
        updatedAt: now,
      );
      await roadmapRepo.createRoadmap(rm);

      final ch = ChapterEntity(
        id: 'ch_sync',
        roadmapId: 'rm_sync',
        title: 'Neural Foundations',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      await chapterRepo.createChapter(ch);

      for (int i = 1; i <= 5; i++) {
        await beatRepo.createBeat(BeatEntity(
          id: 'beat_$i',
          chapterId: 'ch_sync',
          roadmapId: 'rm_sync',
          title: 'Topic #$i',
          sortOrder: i,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ));
      }

      // Simulate rapid toggling of 3 beats in quick succession
      final future1 = beatRepo.toggleBeatCompletion('beat_1', isCompleted: true);
      final future2 = beatRepo.toggleBeatCompletion('beat_2', isCompleted: true);
      final future3 = beatRepo.toggleBeatCompletion('beat_3', isCompleted: true);

      await Future.wait([future1, future2, future3]);

      // Query database directly
      final allBeats = await beatRepo.getBeatsByRoadmapId('rm_sync');
      final completedBeats = allBeats.where((b) => b.isCompleted).map((b) => b.id).toSet();

      expect(completedBeats, containsAll(['beat_1', 'beat_2', 'beat_3']));
      expect(completedBeats.length, 3);
    });

    testWidgets('RoadmapDetailScreen reflects toggled beats accurately and syncs state', (tester) async {
      final now = DateTime.now();
      final rm = RoadmapEntity(
        id: 'rm_sync_ui',
        title: 'System Design Track',
        description: 'Distributed Architecture',
        createdAt: now,
        updatedAt: now,
      );

      final ch = ChapterEntity(
        id: 'ch_sync_ui',
        roadmapId: 'rm_sync_ui',
        title: 'Chapter 1: Storage',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      final initialBeats = <BeatEntity>[
        BeatEntity(
          id: 'b_sync_1',
          chapterId: 'ch_sync_ui',
          roadmapId: 'rm_sync_ui',
          title: 'Distributed Logs & WAL',
          sortOrder: 1,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'b_sync_2',
          chapterId: 'ch_sync_ui',
          roadmapId: 'rm_sync_ui',
          title: 'LSM Trees & SSTables',
          sortOrder: 2,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final toggledEvents = <String, bool>{};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoadmapDetailScreen(
              roadmap: rm,
              chapters: [ch],
              beats: initialBeats,
              onBeatToggled: (beat, isComp) async {
                toggledEvents[beat.id] = isComp;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First chapter is expanded by default, beats should be visible
      expect(find.text('Distributed Logs & WAL'), findsOneWidget);
      expect(find.text('LSM Trees & SSTables'), findsOneWidget);

      // Tap the first beat's checkbox inside runAsync to handle async DB reload
      await tester.runAsync(() async {
        final beatTile = find.byType(BeatTile).first;
        final checkbox = find.descendant(of: beatTile, matching: find.byType(GestureDetector)).first;
        await tester.tap(checkbox);
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(toggledEvents.containsKey('b_sync_1'), isTrue);
      expect(toggledEvents['b_sync_1'], isTrue);
    });
  });

  group('Onboarding Setup Model Auto-Download Tests', () {
    testWidgets('Model cards allow selection without displaying a manual Download button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingWizardScreen(
            onFinished: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Page 1 -> Page 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Page 2 -> Page 3 (Local On-Device AI)
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify we are on the AI model page
      expect(find.text('LOCAL ON-DEVICE AI'), findsOneWidget);
      expect(find.text('Compact Mentor'), findsOneWidget);
      expect(find.text('Balanced Mentor'), findsOneWidget);

      // CRITICAL REQUIREMENT: Manual "Download" button must NOT be present on model cards!
      expect(find.text('Download'), findsNothing);

      // Verify tapping Balanced Mentor card selects it
      await tester.tap(find.text('Balanced Mentor'));
      await tester.pumpAndSettle();

      // Tap Continue to advance to Step 4 (Rhythm calibration)
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('SET YOUR WEEKLY RHYTHM'), findsOneWidget);
    });
  });
}

