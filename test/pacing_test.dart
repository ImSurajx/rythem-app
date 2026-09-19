import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/pacing/pacing.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('PacingCalculator Pure Math Operations', () {
    test('calculateDaysLeft accurately measures calendar days with min 1 floor', () {
      final now = DateTime(2026, 9, 12, 10, 0);

      // Same day -> minimum 1
      expect(PacingCalculator.calculateDaysLeft(DateTime(2026, 9, 12, 23, 59), now: now), 1);

      // Past date -> minimum 1
      expect(PacingCalculator.calculateDaysLeft(DateTime(2026, 9, 10), now: now), 1);

      // 10 days out
      expect(PacingCalculator.calculateDaysLeft(DateTime(2026, 9, 22), now: now), 10);
    });

    test('calculateRemainingEffort sums only incomplete beats', () {
      final now = DateTime.now();
      final beats = [
        BeatEntity(
          id: 'b1',
          chapterId: 'c1',
          roadmapId: 'r1',
          title: 'Beat 1',
          effortWeight: 1.5,
          sortOrder: 0,
          isCompleted: true,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'b2',
          chapterId: 'c1',
          roadmapId: 'r1',
          title: 'Beat 2',
          effortWeight: 2.0,
          sortOrder: 1,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'b3',
          chapterId: 'c1',
          roadmapId: 'r1',
          title: 'Beat 3',
          effortWeight: 1.2,
          sortOrder: 2,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final remaining = PacingCalculator.calculateRemainingEffort(beats);
      expect(remaining, 3.2); // 2.0 + 1.2
    });

    test('calculateDailyEffortShare derives remaining ÷ days left without clock time', () {
      // 20 effort across 10 days = 2.0/day
      expect(
        PacingCalculator.calculateDailyEffortShare(remainingEffort: 20.0, daysLeft: 10),
        2.0,
      );

      // 15 effort across 4 days = 3.75/day
      expect(
        PacingCalculator.calculateDailyEffortShare(remainingEffort: 15.0, daysLeft: 4),
        3.75,
      );

      // Completed curriculum = 0.0
      expect(
        PacingCalculator.calculateDailyEffortShare(remainingEffort: 0.0, daysLeft: 5),
        0.0,
      );
    });

    test('walkQueueToFillBudget strictly preserves mentor order and halts on target', () {
      final now = DateTime.now();
      final beats = List.generate(
        6,
        (i) => BeatEntity(
          id: 'b_$i',
          chapterId: 'c1',
          roadmapId: 'r1',
          title: 'Lesson ${i + 1}',
          effortWeight: 1.0,
          sortOrder: i, // 0..5
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Budget 2.5 effort units -> should select beats 0, 1, 2 (accumulated effort = 3.0 >= 2.5)
      final selected = PacingCalculator.walkQueueToFillBudget(
        pendingBeats: beats,
        targetBudget: 2.5,
      );

      expect(selected.length, 3);
      expect(selected[0].title, 'Lesson 1');
      expect(selected[1].title, 'Lesson 2');
      expect(selected[2].title, 'Lesson 3');
      expect(selected.map((b) => b.sortOrder), [0, 1, 2]);
    });

    test('walkQueueToFillBudget strictly enforces chapter sequence with overlapping sortOrders', () {
      final now = DateTime.now();
      final beats = [
        BeatEntity(
          id: 'b_ch2_0',
          chapterId: 'ch2',
          roadmapId: 'r1',
          title: 'Chapter 2 Intro',
          effortWeight: 1.0,
          sortOrder: 0,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'b_ch1_0',
          chapterId: 'ch1',
          roadmapId: 'r1',
          title: 'Chapter 1 Intro',
          effortWeight: 1.0,
          sortOrder: 0,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'b_ch1_1',
          chapterId: 'ch1',
          roadmapId: 'r1',
          title: 'Chapter 1 Core',
          effortWeight: 1.0,
          sortOrder: 1,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'b_ch2_1',
          chapterId: 'ch2',
          roadmapId: 'r1',
          title: 'Chapter 2 Core',
          effortWeight: 1.0,
          sortOrder: 1,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final chapterOrderMap = {'ch1': 0, 'ch2': 1};

      // Budget 2.0 -> Must select Chapter 1 Intro and Chapter 1 Core, NEVER Chapter 2 Intro!
      final selected = PacingCalculator.walkQueueToFillBudget(
        pendingBeats: beats,
        targetBudget: 2.0,
        chapterOrderMap: chapterOrderMap,
      );

      expect(selected.length, 2);
      expect(selected[0].title, 'Chapter 1 Intro');
      expect(selected[1].title, 'Chapter 1 Core');
      expect(selected[0].chapterId, 'ch1');
      expect(selected[1].chapterId, 'ch1');
    });

    test('calculateRhythmAdjustedDailyShare respects goal date pace and weekly rhythm multipliers', () {
      const remainingEffort = 20.0;
      const daysLeft = 10;
      // base daily pace = 20.0 / 10 = 2.0/day

      // Rest Day -> 0.0
      expect(
        PacingCalculator.calculateRhythmAdjustedDailyShare(
          remainingEffort: remainingEffort,
          daysLeft: daysLeft,
          intensity: StudyIntensity.rest,
        ),
        0.0,
      );

      // Light Day -> 2.0 * 0.6 = 1.2
      expect(
        PacingCalculator.calculateRhythmAdjustedDailyShare(
          remainingEffort: remainingEffort,
          daysLeft: daysLeft,
          intensity: StudyIntensity.light,
        ),
        1.2,
      );

      // Normal Day -> 2.0 * 1.0 = 2.0
      expect(
        PacingCalculator.calculateRhythmAdjustedDailyShare(
          remainingEffort: remainingEffort,
          daysLeft: daysLeft,
          intensity: StudyIntensity.normal,
        ),
        2.0,
      );

      // Deep/Intense Day -> 2.0 * 1.4 = 2.8
      expect(
        PacingCalculator.calculateRhythmAdjustedDailyShare(
          remainingEffort: remainingEffort,
          daysLeft: daysLeft,
          intensity: StudyIntensity.intense,
        ),
        2.8,
      );
    });

    test('Smooth Backlog Dilution spreads missed days without compounding spike', () {

      const initialEffort = 30.0;
      const initialDays = 10;

      // Day 1: 30 / 10 = 3.0/day
      final day1Budget = PacingCalculator.calculateDailyEffortShare(
        remainingEffort: initialEffort,
        daysLeft: initialDays,
      );
      expect(day1Budget, 3.0);

      // User has an off-day (0 effort completed). Day 2: 30 effort left across 9 days
      final day2Budget = PacingCalculator.calculateDailyEffortShare(
        remainingEffort: initialEffort,
        daysLeft: 9,
      );
      // Nudges smoothly from 3.0 to 3.33 (+0.33), NEVER doubles to 6.0!
      expect(day2Budget, 3.33);

      // Another off-day. Day 3: 30 effort left across 8 days
      final day3Budget = PacingCalculator.calculateDailyEffortShare(
        remainingEffort: initialEffort,
        daysLeft: 8,
      );
      expect(day3Budget, 3.75);
    });

    test('Shortfall trend detector absorbs single off-days and flags sustained 3-day lag', () {
      const expectedBudget = 3.0;

      // Single off-day: [3.0, 3.0, 0.0] -> absorbed silently
      final singleOff = PacingCalculator.detectShortfallTrend(
        recentDailyEfforts: [3.0, 3.0, 0.0],
        expectedDailyBudget: expectedBudget,
      );
      expect(singleOff.isSustainedLag, false);
      expect(singleOff.lagDaysCount, 1);

      // Two off-days: [3.0, 0.0, 0.5] -> still absorbed silently
      final twoOff = PacingCalculator.detectShortfallTrend(
        recentDailyEfforts: [3.0, 0.0, 0.5],
        expectedDailyBudget: expectedBudget,
      );
      expect(twoOff.isSustainedLag, false);
      expect(twoOff.lagDaysCount, 2);

      // Three consecutive lagging days: [3.0, 0.2, 0.0, 0.4] -> triggers sustained lag
      final threeOff = PacingCalculator.detectShortfallTrend(
        recentDailyEfforts: [3.0, 0.2, 0.0, 0.4],
        expectedDailyBudget: expectedBudget,
      );
      expect(threeOff.isSustainedLag, true);
      expect(threeOff.lagDaysCount, 3);
    });
  });

  group('PacingService SQLite Integration', () {
    late Database testDb;
    late RoadmapRepository roadmapRepo;
    late ChapterRepository chapterRepo;
    late BeatRepository beatRepo;
    late BeatLogRepository beatLogRepo;
    late PacingService pacingService;

    setUp(() async {
      testDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
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
                ${ChapterColumns.updatedAt} TEXT NOT NULL
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
                ${BeatColumns.updatedAt} TEXT NOT NULL
              );
            ''');
            batch.execute('''
              CREATE TABLE ${DatabaseTables.beatLogs} (
                ${BeatLogColumns.id} TEXT PRIMARY KEY,
                ${BeatLogColumns.beatId} TEXT NOT NULL,
                ${BeatLogColumns.roadmapId} TEXT NOT NULL,
                ${BeatLogColumns.completedDate} TEXT NOT NULL,
                ${BeatLogColumns.createdAt} TEXT NOT NULL
              );
            ''');
            batch.execute('''
              CREATE TABLE ${DatabaseTables.appSettings} (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
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

      DatabaseService.instance.setDatabaseForTesting(testDb);
      roadmapRepo = RoadmapRepository();
      chapterRepo = ChapterRepository();
      beatRepo = BeatRepository();
      beatLogRepo = BeatLogRepository();
      pacingService = PacingService(
        roadmapRepo: roadmapRepo,
        beatRepo: beatRepo,
        beatLogRepo: beatLogRepo,
      );
    });

    tearDown(() async {
      await testDb.close();
      DatabaseService.instance.setDatabaseForTesting(null);
    });

    test('computes daily pacing budget and walks queue from SQLite', () async {
      final now = DateTime(2026, 9, 12);
      final target = now.add(const Duration(days: 5)); // 5 days left

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_pacing_test',
        title: 'Deep Learning Pacing Track',
        targetCompletionDate: target,
        isPrimary: true,
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_1',
        roadmapId: 'rm_pacing_test',
        title: 'Chapter 1',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      final testBeats = List.generate(
        10,
        (i) => BeatEntity(
          id: 'b_$i',
          chapterId: 'ch_1',
          roadmapId: 'rm_pacing_test',
          title: 'Beat ${i + 1}',
          effortWeight: 1.0, // 10.0 total effort
          sortOrder: i,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await beatRepo.createBeatsBatch(testBeats);

      // 10 effort ÷ 5 days = 2.0 effort share per day
      final budget = await pacingService.computePacingBudget(
        'rm_pacing_test',
        simulatedNow: now,
      );

      expect(budget.remainingEffort, 10.0);
      expect(budget.daysLeft, 5);
      expect(budget.todayEffortShare, 2.0);
      expect(budget.todaysBeats.length, 2); // 2 beats * 1.0 = 2.0 effort
      expect(budget.todaysBeats[0].id, 'b_0');
      expect(budget.todaysBeats[1].id, 'b_1');
      expect(budget.isRoadmapCompleted, false);

      // Apply decision: extend target date by 5 days (now 10 days left)
      await pacingService.applyPacingDecision(
        'rm_pacing_test',
        const PacingDecision.extendDate(5),
      );

      final updatedBudget = await pacingService.computePacingBudget(
        'rm_pacing_test',
        simulatedNow: now,
      );
      expect(updatedBudget.daysLeft, 10);
      expect(updatedBudget.todayEffortShare, 1.0); // 10 / 10 = 1.0/day
      expect(updatedBudget.todaysBeats.length, 1); // 1 beat * 1.0 = 1.0 effort
    });
  });
}
