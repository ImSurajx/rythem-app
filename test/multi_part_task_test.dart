import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/pacing/services/pacing_calculator.dart';

void main() {
  // Initialize FFI for headless SQLite testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Feature 2: Multi-Part Task Splitting & Part Completion Unit Tests', () {
    test('BeatEntity model handles totalParts and completedParts correctly', () {
      final now = DateTime.now();
      final defaultBeat = BeatEntity(
        id: 'b1',
        chapterId: 'c1',
        roadmapId: 'r1',
        title: '2-hour Neural Networks Lecture',
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      );

      expect(defaultBeat.totalParts, 1);
      expect(defaultBeat.completedParts, 0);
      expect(defaultBeat.isMultiPart, isFalse);
      expect(defaultBeat.partProgress, 0.0);
      expect(defaultBeat.remainingParts, 1);

      // Split into 4 parts with 1 completed
      final splitBeat = defaultBeat.copyWith(
        totalParts: 4,
        completedParts: 1,
      );

      expect(splitBeat.isMultiPart, isTrue);
      expect(splitBeat.totalParts, 4);
      expect(splitBeat.completedParts, 1);
      expect(splitBeat.partProgress, 0.25);
      expect(splitBeat.remainingParts, 3);

      // Serialization round-trip
      final map = splitBeat.toMap();
      expect(map[BeatColumns.totalParts], 4);
      expect(map[BeatColumns.completedParts], 1);

      final fromMapBeat = BeatEntity.fromMap(map);
      expect(fromMapBeat.totalParts, 4);
      expect(fromMapBeat.completedParts, 1);
      expect(fromMapBeat.isMultiPart, isTrue);
    });

    test('PacingCalculator scales remaining effort proportionally for multi-part tasks', () {
      final now = DateTime.now();
      final baseBeat = BeatEntity(
        id: 'b1',
        chapterId: 'c1',
        roadmapId: 'r1',
        title: 'Deep Learning Specialization Video',
        effortWeight: 4.0, // e.g. 4-hour extensive module
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      );

      // 1. Single task (1 part, 0 completed): 4.0 effort
      expect(PacingCalculator.calculateRemainingEffort([baseBeat]), 4.0);

      // 2. Single task completed: 0.0 effort
      expect(PacingCalculator.calculateRemainingEffort([baseBeat.copyWith(isCompleted: true)]), 0.0);

      // 3. Multi-part: 4 parts, 0 completed: 4.0 effort
      final p0 = baseBeat.copyWith(totalParts: 4, completedParts: 0);
      expect(PacingCalculator.calculateRemainingEffort([p0]), 4.0);

      // 4. Multi-part: 1 part completed -> 3/4 remaining -> 3.0 effort
      final p1 = baseBeat.copyWith(totalParts: 4, completedParts: 1);
      expect(PacingCalculator.calculateRemainingEffort([p1]), 3.0);

      // 5. Multi-part: 2 parts completed -> 2/4 remaining -> 2.0 effort
      final p2 = baseBeat.copyWith(totalParts: 4, completedParts: 2);
      expect(PacingCalculator.calculateRemainingEffort([p2]), 2.0);

      // 6. Multi-part: 3 parts completed -> 1/4 remaining -> 1.0 effort
      final p3 = baseBeat.copyWith(totalParts: 4, completedParts: 3);
      expect(PacingCalculator.calculateRemainingEffort([p3]), 1.0);

      // 7. Multi-part: 4 parts completed -> isCompleted true -> 0.0 effort
      final p4 = baseBeat.copyWith(totalParts: 4, completedParts: 4, isCompleted: true);
      expect(PacingCalculator.calculateRemainingEffort([p4]), 0.0);
    });
  });

  group('Feature 2: Multi-Part Task Database & Streak Integration Tests', () {
    late Database db;
    late DatabaseService dbService;
    late RoadmapRepository roadmapRepo;
    late ChapterRepository chapterRepo;
    late BeatRepository beatRepo;
    late BeatLogRepository beatLogRepo;

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
              CREATE TABLE ${DatabaseTables.appSettings} (
                ${AppSettingsColumns.key} TEXT PRIMARY KEY,
                ${AppSettingsColumns.value} TEXT NOT NULL,
                ${AppSettingsColumns.updatedAt} TEXT NOT NULL
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

      // Seed initial roadmap and chapter
      final now = DateTime.now();
      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm-multi',
        title: 'Deep Systems & Compiler Design',
        createdAt: now,
        updatedAt: now,
      ));
      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch-comp',
        roadmapId: 'rm-multi',
        title: 'Chapter 1: Lexing and Parsing',
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ));
    });

    tearDown(() async {
      await db.close();
      dbService.setDatabaseForTesting(null);
    });

    test('Splitting a beat updates totalParts and retains completion state', () async {
      final now = DateTime.now();
      await beatRepo.createBeat(BeatEntity(
        id: 'beat-project',
        chapterId: 'ch-comp',
        roadmapId: 'rm-multi',
        title: 'Build AST Parser Generator',
        effortWeight: 3.0,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ));

      // 1. Initial state
      var beat = await beatRepo.getBeatById('beat-project');
      expect(beat, isNotNull);
      expect(beat!.totalParts, 1);
      expect(beat.completedParts, 0);
      expect(beat.isMultiPart, isFalse);

      // 2. Split task into 3 parts
      await beatRepo.updateBeatParts('beat-project', 3);
      beat = await beatRepo.getBeatById('beat-project');
      expect(beat!.totalParts, 3);
      expect(beat.completedParts, 0);
      expect(beat.isMultiPart, isTrue);
      expect(beat.isCompleted, isFalse);

      // 3. Reset task to 1 part
      await beatRepo.updateBeatParts('beat-project', 1);
      beat = await beatRepo.getBeatById('beat-project');
      expect(beat!.totalParts, 1);
      expect(beat.completedParts, 0);
      expect(beat.isMultiPart, isFalse);
    });

    test('Incrementing a part logs activity, counts towards daily streak, and completes on last part', () async {
      final now = DateTime.now();
      await beatRepo.createBeat(BeatEntity(
        id: 'beat-video',
        chapterId: 'ch-comp',
        roadmapId: 'rm-multi',
        title: '2-hour LLVM Backend Architecture',
        effortWeight: 2.0,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ));

      // Initial streak should be 0
      var streak = await beatLogRepo.getCurrentStreak();
      expect(streak, 0);

      // Split into 2 parts (e.g. 1 hour today, 1 hour tomorrow)
      await beatRepo.updateBeatParts('beat-video', 2);

      // Increment part 1
      final part1Result = await beatRepo.incrementBeatPart('beat-video');
      expect(part1Result, isNotNull);
      expect(part1Result!.completedParts, 1);
      expect(part1Result.totalParts, 2);
      expect(part1Result.isCompleted, isFalse);
      expect(part1Result.completedAt, isNull);

      // Verify that completing part 1 registered a log entry in beat_logs for today!
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final logs = await beatLogRepo.getLogsForDate(todayStr);
      expect(logs.length, 1);
      expect(logs.first.beatId, 'beat-video');

      // Crucial: User's streak is preserved/advanced by completing even 1 part!
      streak = await beatLogRepo.getCurrentStreak();
      expect(streak, greaterThanOrEqualTo(1));

      // Remaining effort is now 1.0 instead of 2.0
      var remaining = PacingCalculator.calculateRemainingEffort([part1Result]);
      expect(remaining, 1.0);

      // Increment part 2 (final part)
      final part2Result = await beatRepo.incrementBeatPart('beat-video');
      expect(part2Result, isNotNull);
      expect(part2Result!.completedParts, 2);
      expect(part2Result.totalParts, 2);
      expect(part2Result.isCompleted, isTrue);
      expect(part2Result.completedAt, isNotNull);

      // Remaining effort is now 0.0
      remaining = PacingCalculator.calculateRemainingEffort([part2Result]);
      expect(remaining, 0.0);

      // Decrement part: reverts from completed to in-progress (1/2)
      final decResult = await beatRepo.decrementBeatPart('beat-video');
      expect(decResult, isNotNull);
      expect(decResult!.completedParts, 1);
      expect(decResult.isCompleted, isFalse);
      expect(decResult.completedAt, isNull);
    });

    test('Direct checkbox toggle sets all parts when checked and resets parts when unchecked', () async {
      final now = DateTime.now();
      await beatRepo.createBeat(BeatEntity(
        id: 'beat-toggle-test',
        chapterId: 'ch-comp',
        roadmapId: 'rm-multi',
        title: 'Type Inference Engine',
        sortOrder: 1,
        totalParts: 4,
        completedParts: 1,
        createdAt: now,
        updatedAt: now,
      ));

      // Toggle complete: completedParts must become 4
      await beatRepo.toggleBeatCompletion('beat-toggle-test', isCompleted: true);
      var beat = await beatRepo.getBeatById('beat-toggle-test');
      expect(beat!.isCompleted, isTrue);
      expect(beat.completedParts, 4);
      expect(beat.totalParts, 4);

      // Toggle uncomplete: completedParts must become 0
      await beatRepo.toggleBeatCompletion('beat-toggle-test', isCompleted: false);
      beat = await beatRepo.getBeatById('beat-toggle-test');
      expect(beat!.isCompleted, isFalse);
      expect(beat.completedParts, 0);
      expect(beat.totalParts, 4);
    });
  });
}
