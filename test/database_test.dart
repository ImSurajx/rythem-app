import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';

void main() {
  // Initialize FFI for headless SQLite testing on desktop/CI
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseService dbService;
  late RoadmapRepository roadmapRepo;
  late ChapterRepository chapterRepo;
  late BeatRepository beatRepo;
  late BeatLogRepository beatLogRepo;

  setUp(() async {
    // Open a fresh in-memory database for each test
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          // Re-use standard schema creation from DatabaseService
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
            CREATE TABLE ${DatabaseTables.appSettings} (
              ${AppSettingsColumns.key} TEXT PRIMARY KEY,
              ${AppSettingsColumns.value} TEXT NOT NULL,
              ${AppSettingsColumns.updatedAt} TEXT NOT NULL
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
  });

  tearDown(() async {
    await db.close();
    dbService.setDatabaseForTesting(null);
  });

  group('Database Architecture & Foreign Keys', () {
    test('enforces foreign key cascade deletion across roadmap -> chapter -> beats', () async {
      final now = DateTime.now();
      final roadmap = RoadmapEntity(
        id: 'rm_1',
        title: 'Deep Learning Foundation',
        createdAt: now,
        updatedAt: now,
      );
      await roadmapRepo.createRoadmap(roadmap);

      final chapter = ChapterEntity(
        id: 'ch_1',
        roadmapId: 'rm_1',
        title: 'Neural Networks Basics',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      await chapterRepo.createChapter(chapter);

      final beat = BeatEntity(
        id: 'beat_1',
        chapterId: 'ch_1',
        roadmapId: 'rm_1',
        title: 'Forward & Backpropagation',
        effortWeight: 1.5,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      await beatRepo.createBeat(beat);

      // Verify existence
      expect(await roadmapRepo.getRoadmapById('rm_1'), isNotNull);
      expect((await chapterRepo.getChaptersByRoadmapId('rm_1')).length, 1);
      expect((await beatRepo.getBeatsByRoadmapId('rm_1')).length, 1);

      // Delete roadmap -> Cascades to chapters and beats
      await roadmapRepo.deleteRoadmap('rm_1');

      expect(await roadmapRepo.getRoadmapById('rm_1'), isNull);
      expect((await chapterRepo.getChaptersByRoadmapId('rm_1')).length, 0);
      expect((await beatRepo.getBeatsByRoadmapId('rm_1')).length, 0);
    });
  });

  group('Mentor Flow & Effort Weight Ground Truths', () {
    test('preserves mentor chronological sort order and calculates remaining effort', () async {
      final now = DateTime.now();
      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_python',
        title: 'Modern Python',
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_intro',
        roadmapId: 'rm_python',
        title: 'Getting Started',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      // Ingest beats with different sort orders and mentor extra tags
      final beats = [
        BeatEntity(
          id: 'b3',
          chapterId: 'ch_intro',
          roadmapId: 'rm_python',
          title: 'Advanced Generators (Mentor Extra)',
          effortWeight: 2.0,
          sortOrder: 2,
          isMentorExtra: true,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'b1',
          chapterId: 'ch_intro',
          roadmapId: 'rm_python',
          title: 'Syntax & Types',
          effortWeight: 1.0,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'b2',
          chapterId: 'ch_intro',
          roadmapId: 'rm_python',
          title: 'Control Flow',
          effortWeight: 1.5,
          sortOrder: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await beatRepo.createBeatsBatch(beats);

      // Mentor flow check: Returned strictly ordered by sort_order (b1, b2, b3)
      final orderedBeats = await beatRepo.getBeatsByRoadmapId('rm_python');
      expect(orderedBeats.length, 3);
      expect(orderedBeats[0].id, 'b1');
      expect(orderedBeats[1].id, 'b2');
      expect(orderedBeats[2].id, 'b3');
      expect(orderedBeats[2].isMentorExtra, isTrue);

      // Remaining effort before any completion
      final totalEffort = await beatRepo.getRemainingEffort('rm_python');
      expect(totalEffort, 4.5); // 1.0 + 1.5 + 2.0

      // Progress aggregation
      final progressBefore = await roadmapRepo.getRoadmapProgress('rm_python');
      expect(progressBefore.completedBeats, 0);
      expect(progressBefore.totalBeats, 3);
      expect(progressBefore.completedEffort, 0.0);
      expect(progressBefore.totalEffort, 4.5);
    });
  });

  group('Reactive Beat Completion & Activity Logging', () {
    test('toggling beat triggers event bus, logs completion, and updates streak', () async {
      final now = DateTime.now();
      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_flow',
        title: 'Flow Roadmap',
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_flow',
        roadmapId: 'rm_flow',
        title: 'Core Chapter',
        createdAt: now,
        updatedAt: now,
      ));

      await beatRepo.createBeat(BeatEntity(
        id: 'beat_active',
        chapterId: 'ch_flow',
        roadmapId: 'rm_flow',
        title: 'The First Beat',
        effortWeight: 1.0,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      // Listen for reactive event emission
      final events = <DatabaseEvent>[];
      final subscription = DatabaseEventBus.instance.stream.listen(events.add);

      // Complete beat
      final updated = await beatRepo.toggleBeatCompletion('beat_active', isCompleted: true);
      expect(updated!.isCompleted, isTrue);
      expect(updated.completedAt, isNotNull);

      // Allow microtask stream event delivery
      await pumpEventQueue();

      // Check event emitted
      expect(events.isNotEmpty, isTrue);
      expect(events.last.type, DatabaseEventType.beatToggled);
      expect(events.last.entityId, 'beat_active');

      // Check activity logged
      final todayCount = await beatLogRepo.getBeatsCompletedToday();
      expect(todayCount, 1);

      final streak = await beatLogRepo.getCurrentStreak();
      expect(streak, 1);

      // Verify pending beats queue is now empty
      final pending = await beatRepo.getPendingBeats('rm_flow');
      expect(pending.isEmpty, isTrue);

      // Toggle back to incomplete
      final reverted = await beatRepo.toggleBeatCompletion('beat_active', isCompleted: false);
      expect(reverted!.isCompleted, isFalse);
      expect(reverted.completedAt, isNull);

      final todayAfterRevert = await beatLogRepo.getBeatsCompletedToday();
      expect(todayAfterRevert, 0);

      await subscription.cancel();
    });
  });
}
