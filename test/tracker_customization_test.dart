import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/pacing/services/pacing_calculator.dart';

void main() {
  // Initialize FFI for headless SQLite testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Feature 3: Dynamic Tracker Customization & Strict Mentor-Order Append Tests', () {
    late Database db;
    late DatabaseService dbService;
    late RoadmapRepository roadmapRepo;
    late ChapterRepository chapterRepo;
    late BeatRepository beatRepo;
    late BeatLogRepository beatLogRepo;
    late DailyMissionRepository missionRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: (db, version) async {
            final batch = db.batch();
            batch.execute('''
              CREATE TABLE ${DatabaseTables.roadmaps} (
                ${RoadmapColumns.id} TEXT PRIMARY KEY,
                ${RoadmapColumns.title} TEXT NOT NULL,
                ${RoadmapColumns.description} TEXT,
                ${RoadmapColumns.startDate} TEXT,
                ${RoadmapColumns.targetCompletionDate} TEXT,
                ${RoadmapColumns.status} TEXT NOT NULL DEFAULT 'active',
                ${RoadmapColumns.isPrimary} INTEGER NOT NULL DEFAULT 0,
                ${RoadmapColumns.createdAt} TEXT NOT NULL,
                ${RoadmapColumns.updatedAt} TEXT NOT NULL
              );
            ''');
            batch.execute('''
              CREATE TABLE ${DatabaseTables.chapters} (
                ${ChapterColumns.id} TEXT PRIMARY KEY,
                ${ChapterColumns.roadmapId} TEXT NOT NULL,
                ${ChapterColumns.title} TEXT NOT NULL,
                ${ChapterColumns.sortOrder} INTEGER NOT NULL DEFAULT 0,
                ${ChapterColumns.createdAt} TEXT NOT NULL,
                ${ChapterColumns.updatedAt} TEXT NOT NULL,
                FOREIGN KEY (${ChapterColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
              );
            ''');
            batch.execute('''
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
                ${BeatColumns.updatedAt} TEXT NOT NULL,
                FOREIGN KEY (${BeatColumns.chapterId}) REFERENCES ${DatabaseTables.chapters} (${ChapterColumns.id}) ON DELETE CASCADE,
                FOREIGN KEY (${BeatColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
              );
            ''');
            batch.execute('''
              CREATE TABLE ${DatabaseTables.beatLogs} (
                ${BeatLogColumns.id} TEXT PRIMARY KEY,
                ${BeatLogColumns.beatId} TEXT NOT NULL,
                ${BeatLogColumns.roadmapId} TEXT NOT NULL,
                ${BeatLogColumns.completedDate} TEXT NOT NULL,
                ${BeatLogColumns.createdAt} TEXT NOT NULL,
                FOREIGN KEY (${BeatLogColumns.beatId}) REFERENCES ${DatabaseTables.beats} (${BeatColumns.id}) ON DELETE CASCADE,
                FOREIGN KEY (${BeatLogColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
              );
            ''');
            batch.execute('''
              CREATE TABLE ${DatabaseTables.dailyMissions} (
                ${DailyMissionColumns.id} TEXT PRIMARY KEY,
                ${DailyMissionColumns.roadmapId} TEXT NOT NULL,
                ${DailyMissionColumns.date} TEXT NOT NULL,
                ${DailyMissionColumns.beatId} TEXT NOT NULL,
                ${DailyMissionColumns.sortIndex} INTEGER NOT NULL,
                ${DailyMissionColumns.createdAt} TEXT NOT NULL,
                FOREIGN KEY (${DailyMissionColumns.beatId}) REFERENCES ${DatabaseTables.beats} (${BeatColumns.id}) ON DELETE CASCADE,
                FOREIGN KEY (${DailyMissionColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
              );
            ''');
            await batch.commit(noResult: true);
          },
        ),
      );

      dbService = DatabaseService.instance;
      dbService.setDatabaseForTesting(db);

      roadmapRepo = RoadmapRepository(dbService: dbService);
      chapterRepo = ChapterRepository(dbService: dbService);
      beatRepo = BeatRepository(dbService: dbService);
      beatLogRepo = BeatLogRepository(dbService: dbService);
      missionRepo = DailyMissionRepository(dbService: dbService);

      // Seed initial subject and chapter
      final now = DateTime.now();
      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm-custom-test',
        title: 'Full Stack Systems & React Architecture',
        createdAt: now,
        updatedAt: now,
      ));
      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch-mentor-1',
        roadmapId: 'rm-custom-test',
        title: 'Chapter 1: React Internals & Fiber Engine',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));
    });

    tearDown(() async {
      await db.close();
      dbService.setDatabaseForTesting(null);
    });

    test('Strict Mentor Order: User topics append to bottom in sequential order (mentor, 1, 2, 3)', () async {
      final now = DateTime.now();
      // 1. Seed 3 mentor beats (sortOrder 0, 1, 2)
      await beatRepo.createBeat(BeatEntity(
        id: 'mentor-beat-0',
        chapterId: 'ch-mentor-1',
        roadmapId: 'rm-custom-test',
        title: 'Lesson 1: Virtual DOM Reconciliation',
        sortOrder: 0,
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now,
      ));
      await beatRepo.createBeat(BeatEntity(
        id: 'mentor-beat-1',
        chapterId: 'ch-mentor-1',
        roadmapId: 'rm-custom-test',
        title: 'Lesson 2: Fiber WorkLoop & Lanes',
        sortOrder: 1,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now,
      ));
      await beatRepo.createBeat(BeatEntity(
        id: 'mentor-beat-2',
        chapterId: 'ch-mentor-1',
        roadmapId: 'rm-custom-test',
        title: 'Lesson 3: Concurrent Mode Scheduling',
        sortOrder: 2,
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now,
      ));

      // 2. User adds custom topic 1
      final sort1 = await beatRepo.getNextSortOrderForChapter('ch-mentor-1');
      expect(sort1, 3);
      await beatRepo.createBeat(BeatEntity(
        id: 'user-topic-1',
        chapterId: 'ch-mentor-1',
        roadmapId: 'rm-custom-test',
        title: 'Custom Topic 1: Offscreen Rendering Deep Dive',
        sortOrder: sort1,
        isMentorExtra: true,
        createdAt: now,
        updatedAt: now,
      ));

      // 3. User adds custom topic 2
      final sort2 = await beatRepo.getNextSortOrderForChapter('ch-mentor-1');
      expect(sort2, 4);
      await beatRepo.createBeat(BeatEntity(
        id: 'user-topic-2',
        chapterId: 'ch-mentor-1',
        roadmapId: 'rm-custom-test',
        title: 'Custom Topic 2: Web Workers Hydration',
        sortOrder: sort2,
        isMentorExtra: true,
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now,
      ));

      // 4. User adds custom topic 3
      final sort3 = await beatRepo.getNextSortOrderForChapter('ch-mentor-1');
      expect(sort3, 5);
      await beatRepo.createBeat(BeatEntity(
        id: 'user-topic-3',
        chapterId: 'ch-mentor-1',
        roadmapId: 'rm-custom-test',
        title: 'Custom Topic 3: Profiling with React DevTools Trace',
        sortOrder: sort3,
        isMentorExtra: true,
        createdAt: now.add(const Duration(seconds: 2)),
        updatedAt: now,
      ));

      // 5. Query all beats from the database
      final allBeats = await beatRepo.getBeatsByChapterId('ch-mentor-1');
      expect(allBeats.length, 6);

      // Strict validation of the invariant:
      // [mentor_0, mentor_1, mentor_2, user_1, user_2, user_3]
      final orderedIds = allBeats.map((b) => b.id).toList();
      expect(orderedIds, [
        'mentor-beat-0',
        'mentor-beat-1',
        'mentor-beat-2',
        'user-topic-1',
        'user-topic-2',
        'user-topic-3',
      ]);
    });

    test('Custom chapters append strictly to the end of the subject', () async {
      final now = DateTime.now();
      // Initially, roadmap has 1 chapter with sortOrder 0
      final sort1 = await chapterRepo.getNextSortOrder('rm-custom-test');
      expect(sort1, 1);

      // Create Custom Chapter 2
      await chapterRepo.createChapter(ChapterEntity(
        id: 'user-ch-2',
        roadmapId: 'rm-custom-test',
        title: 'Chapter 2: Micro-Frontends & Module Federation',
        sortOrder: sort1,
        createdAt: now,
        updatedAt: now,
      ));

      // Next sort order should now be 2
      final sort2 = await chapterRepo.getNextSortOrder('rm-custom-test');
      expect(sort2, 2);

      // Create Custom Chapter 3
      await chapterRepo.createChapter(ChapterEntity(
        id: 'user-ch-3',
        roadmapId: 'rm-custom-test',
        title: 'Chapter 3: Edge Rendering & Streaming SSR',
        sortOrder: sort2,
        createdAt: now.add(const Duration(seconds: 1)),
        updatedAt: now,
      ));

      // Query chapters in order
      final chapters = await chapterRepo.getChaptersByRoadmapId('rm-custom-test');
      expect(chapters.length, 3);
      expect(chapters[0].id, 'ch-mentor-1');
      expect(chapters[1].id, 'user-ch-2');
      expect(chapters[2].id, 'user-ch-3');
    });

    test('User-added topics integrate with pacing calculations', () async {
      final now = DateTime.now();
      final baseBeats = [
        BeatEntity(
          id: 'b1',
          chapterId: 'ch-mentor-1',
          roadmapId: 'rm-custom-test',
          title: 'Lesson 1',
          effortWeight: 1.0,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      expect(PacingCalculator.calculateRemainingEffort(baseBeats), 1.0);

      // Add custom topic with 2.5 effort weight
      final customBeat = BeatEntity(
        id: 'user-custom-beat',
        chapterId: 'ch-mentor-1',
        roadmapId: 'rm-custom-test',
        title: 'Building a Custom React Renderer',
        effortWeight: 2.5,
        sortOrder: 1,
        isMentorExtra: true,
        createdAt: now,
        updatedAt: now,
      );

      final combined = [...baseBeats, customBeat];
      expect(PacingCalculator.calculateRemainingEffort(combined), 3.5);
    });

    test('User-added topics can be queued into Today Focus and completed in parts', () async {
      final now = DateTime.now();
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // 1. Create a custom topic split into 3 parts
      await beatRepo.createBeat(BeatEntity(
        id: 'user-project',
        chapterId: 'ch-mentor-1',
        roadmapId: 'rm-custom-test',
        title: 'Build WebGL Canvas Canvas Bridge',
        effortWeight: 3.0,
        sortOrder: 1,
        totalParts: 3,
        completedParts: 0,
        isMentorExtra: true,
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Queue into Today's Focus (Feature 1)
      await missionRepo.addBeatToTodayMission(
        roadmapId: 'rm-custom-test',
        date: todayStr,
        beatId: 'user-project',
      );
      final mission = await missionRepo.getMissionBeatsForDate('rm-custom-test', todayStr);
      expect(mission.length, 1);
      expect(mission.first.id, 'user-project');

      // 3. Complete Part 1 (Feature 2)
      final part1 = await beatRepo.incrementBeatPart('user-project');
      expect(part1!.completedParts, 1);
      expect(part1.isCompleted, isFalse);

      // Verify streak recorded for today
      final streak = await beatLogRepo.getCurrentStreak();
      expect(streak, greaterThanOrEqualTo(1));

      // 4. Complete Part 2 and Part 3
      await beatRepo.incrementBeatPart('user-project');
      final finalPart = await beatRepo.incrementBeatPart('user-project');
      expect(finalPart!.completedParts, 3);
      expect(finalPart.isCompleted, isTrue);
    });

    test('Editing and deleting custom topics and chapters works correctly', () async {
      final now = DateTime.now();
      // Create custom chapter and beat
      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch-editable',
        roadmapId: 'rm-custom-test',
        title: 'Original Chapter Title',
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ));
      await beatRepo.createBeat(BeatEntity(
        id: 'beat-editable',
        chapterId: 'ch-editable',
        roadmapId: 'rm-custom-test',
        title: 'Original Beat Title',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      // 1. Rename chapter
      final chapter = await chapterRepo.getChaptersByRoadmapId('rm-custom-test');
      final targetCh = chapter.firstWhere((c) => c.id == 'ch-editable');
      await chapterRepo.updateChapter(targetCh.copyWith(title: 'Renamed Chapter Title'));

      var updatedCh = (await chapterRepo.getChaptersByRoadmapId('rm-custom-test'))
          .firstWhere((c) => c.id == 'ch-editable');
      expect(updatedCh.title, 'Renamed Chapter Title');

      // 2. Edit beat title and resource URL
      final beat = await beatRepo.getBeatById('beat-editable');
      await beatRepo.updateBeat(beat!.copyWith(
        title: 'Renamed Beat Title',
        sourceUrl: 'https://docs.react.dev',
      ));

      var updatedBeat = await beatRepo.getBeatById('beat-editable');
      expect(updatedBeat!.title, 'Renamed Beat Title');
      expect(updatedBeat.sourceUrl, 'https://docs.react.dev');

      // 3. Delete beat
      await beatRepo.deleteBeat('beat-editable');
      expect(await beatRepo.getBeatById('beat-editable'), isNull);

      // 4. Delete chapter
      await chapterRepo.deleteChapter('ch-editable');
      final remainingChapters = await chapterRepo.getChaptersByRoadmapId('rm-custom-test');
      expect(remainingChapters.any((c) => c.id == 'ch-editable'), isFalse);
    });
  });
}
