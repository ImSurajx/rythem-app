import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/ingestion/parsers/syllabus_parser.dart';
import 'package:rythem_app/core/ingestion/services/curriculum_ingestion_service.dart';
import 'package:rythem_app/core/pacing/pacing.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService dbService;
  late RoadmapRepository roadmapRepo;
  late ChapterRepository chapterRepo;
  late BeatRepository beatRepo;
  late BeatLogRepository beatLogRepo;
  late AppSettingsRepository settingsRepo;
  late DailyMissionRepository dailyMissionRepo;
  late PacingService pacingService;

  setUp(() async {
    dbService = DatabaseService.instance;
    await dbService.initInMemoryForTesting();
    roadmapRepo = RoadmapRepository(dbService: dbService);
    chapterRepo = ChapterRepository(dbService: dbService);
    beatRepo = BeatRepository(dbService: dbService);
    beatLogRepo = BeatLogRepository(dbService: dbService);
    settingsRepo = AppSettingsRepository(dbService: dbService);
    dailyMissionRepo = DailyMissionRepository(dbService: dbService);

    pacingService = PacingService(
      roadmapRepo: roadmapRepo,
      chapterRepo: chapterRepo,
      beatRepo: beatRepo,
      beatLogRepo: beatLogRepo,
      settingsRepo: settingsRepo,
      dailyMissionRepo: dailyMissionRepo,
    );
  });

  tearDown(() async {
    await dbService.close();
  });

  group('Roadmap Entity & Schema v2 Tests', () {
    test('Roadmap supports startDate and targetCompletionDate', () async {
      final now = DateTime(2026, 9, 19, 10, 0);
      final target = now.add(const Duration(days: 30));

      final roadmap = RoadmapEntity(
        id: 'rm_v2_test',
        title: 'Python Mastery',
        startDate: now,
        targetCompletionDate: target,
        createdAt: now,
        updatedAt: now,
      );

      await roadmapRepo.createRoadmap(roadmap);
      final retrieved = await roadmapRepo.getRoadmapById('rm_v2_test');

      expect(retrieved, isNotNull);
      expect(retrieved!.startDate, now);
      expect(retrieved.targetCompletionDate, target);
    });

    test('CurriculumIngestionService persists custom startDate on created roadmap', () async {
      final ingestionService = CurriculumIngestionService(
        roadmapRepo: roadmapRepo,
        chapterRepo: chapterRepo,
        beatRepo: beatRepo,
        dailyMissionRepo: dailyMissionRepo,
      );

      final startDate = DateTime(2026, 10, 1);
      final targetDate = DateTime(2026, 11, 15);
      final parsed = SyllabusParser.parse(
        'Module 1: Basics\n- Topic A\n- Topic B',
        defaultTitle: 'Custom Start Track',
      );

      final res = await ingestionService.ingestFromSyllabus(
        title: 'Custom Start Track',
        category: 'Engineering',
        startDate: startDate,
        targetDate: targetDate,
        syllabus: parsed,
      );

      final retrieved = await roadmapRepo.getRoadmapById(res.roadmapId);
      expect(retrieved, isNotNull);
      expect(retrieved!.startDate, startDate);
      expect(retrieved.targetCompletionDate, targetDate);
    });
  });

  group('Active-Chapter Linear Queue Walker Tests', () {
    test('Exhausts Chapter 1 completely before Chapter 2; never interleaves beats', () {
      final now = DateTime.now();

      // Chapter 1 has 3 beats
      final ch1Beats = List.generate(
        3,
        (i) => BeatEntity(
          id: 'ch1_beat_$i',
          chapterId: 'ch_1',
          roadmapId: 'rm_track',
          title: 'Chapter 1 Video $i',
          effortWeight: 1.0,
          sortOrder: i,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Chapter 2 has 3 beats
      final ch2Beats = List.generate(
        3,
        (i) => BeatEntity(
          id: 'ch2_beat_$i',
          chapterId: 'ch_2',
          roadmapId: 'rm_track',
          title: 'Chapter 2 Video $i',
          effortWeight: 1.0,
          sortOrder: i,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Mix them randomly in pending list
      final mixedPending = [...ch2Beats, ...ch1Beats];

      // Walk budget for 3 beats (target effort 3.0)
      final selected = PacingCalculator.walkQueueToFillBudget(
        pendingBeats: mixedPending,
        targetBudget: 3.0,
        chapterOrderMap: {'ch_1': 0, 'ch_2': 1},
        orderedChapterIds: ['ch_1', 'ch_2'],
      );

      expect(selected.length, 3);
      // All selected beats must be strictly from Chapter 1 in exact order
      expect(selected[0].id, 'ch1_beat_0');
      expect(selected[1].id, 'ch1_beat_1');
      expect(selected[2].id, 'ch1_beat_2');

      // Even if chapterOrderMap had tied sortOrder (e.g. both 0), orderedChapterIds guarantees Chapter 1 first
      final selectedTied = PacingCalculator.walkQueueToFillBudget(
        pendingBeats: mixedPending,
        targetBudget: 3.0,
        chapterOrderMap: {'ch_1': 0, 'ch_2': 0},
        orderedChapterIds: ['ch_1', 'ch_2'],
      );

      expect(selectedTied.length, 3);
      expect(selectedTied[0].id, 'ch1_beat_0');
      expect(selectedTied[1].id, 'ch1_beat_1');
      expect(selectedTied[2].id, 'ch1_beat_2');
    });
  });

  group('Daily Mission Persistence & Strikethrough Stability Tests', () {
    test('Completing 1 beat retains all 3 mission beats and prevents premature Evening Unlock', () async {
      final now = DateTime(2026, 9, 19, 9, 0);
      final target = now.add(const Duration(days: 3)); // 3 days left

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_daily_flow',
        title: 'DSA Flow Test',
        startDate: now,
        targetCompletionDate: target,
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_intro',
        roadmapId: 'rm_daily_flow',
        title: 'Arrays & Hashing',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      // 9 beats * 1.0 = 9.0 effort. 9.0 ÷ 3 days = 3.0 effort/day -> 3 beats/day
      final beats = List.generate(
        9,
        (i) => BeatEntity(
          id: 'arr_beat_$i',
          chapterId: 'ch_intro',
          roadmapId: 'rm_daily_flow',
          title: 'Array Problem $i',
          effortWeight: 1.0,
          sortOrder: i,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await beatRepo.createBeatsBatch(beats);

      // 1. Initial computation on launch -> locks 3 beats into SQLite daily_missions
      final initialBudget = await pacingService.computePacingBudget(
        'rm_daily_flow',
        simulatedNow: now,
      );

      expect(initialBudget.todaysBeats.length, 3);
      expect(initialBudget.todaysBeats.map((b) => b.id).toList(), [
        'arr_beat_0',
        'arr_beat_1',
        'arr_beat_2',
      ]);
      expect(initialBudget.isDailyQuotaCompleted, false);

      // Verify records are saved in daily_missions table
      const todayDateStr = '2026-09-19';
      final locked = await dailyMissionRepo.getMissionBeatsForDate('rm_daily_flow', todayDateStr);
      expect(locked.length, 3);
      expect(locked.map((b) => b.id).toList(), ['arr_beat_0', 'arr_beat_1', 'arr_beat_2']);

      // 2. User completes the FIRST beat (arr_beat_0)
      await beatRepo.toggleBeatCompletion('arr_beat_0', isCompleted: true);

      // 3. Recompute budget after completing 1 beat
      final budgetAfterOne = await pacingService.computePacingBudget(
        'rm_daily_flow',
        simulatedNow: now,
      );

      // The other two beats MUST NOT vanish! All 3 beats remain in today's mission.
      expect(budgetAfterOne.todaysBeats.length, 3);
      expect(budgetAfterOne.todaysBeats[0].id, 'arr_beat_0');
      expect(budgetAfterOne.todaysBeats[0].isCompleted, true); // Strikethrough

      expect(budgetAfterOne.todaysBeats[1].id, 'arr_beat_1');
      expect(budgetAfterOne.todaysBeats[1].isCompleted, false); // Still visible!

      expect(budgetAfterOne.todaysBeats[2].id, 'arr_beat_2');
      expect(budgetAfterOne.todaysBeats[2].isCompleted, false); // Still visible!

      // CRITICAL: Evening Unlock must NOT trigger prematurely!
      expect(budgetAfterOne.isDailyQuotaCompleted, false);

      // 4. User completes the SECOND beat
      await beatRepo.toggleBeatCompletion('arr_beat_1', isCompleted: true);
      final budgetAfterTwo = await pacingService.computePacingBudget(
        'rm_daily_flow',
        simulatedNow: now,
      );
      expect(budgetAfterTwo.todaysBeats.length, 3);
      expect(budgetAfterTwo.isDailyQuotaCompleted, false);

      // 5. User completes the THIRD beat (100% of today's mission complete)
      await beatRepo.toggleBeatCompletion('arr_beat_2', isCompleted: true);
      final budgetAfterAllThree = await pacingService.computePacingBudget(
        'rm_daily_flow',
        simulatedNow: now,
      );
      expect(budgetAfterAllThree.todaysBeats.length, 3);
      expect(budgetAfterAllThree.todaysBeats.every((b) => b.isCompleted), true);
      // Evening Unlock triggers ONLY now!
      expect(budgetAfterAllThree.isDailyQuotaCompleted, true);
    });

    test('SQLite ON DELETE CASCADE purges deleted beats from daily_missions automatically', () async {
      final now = DateTime(2026, 9, 19);

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_cascade',
        title: 'Cascade Test',
        targetCompletionDate: now.add(const Duration(days: 5)),
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_cascade',
        roadmapId: 'rm_cascade',
        title: 'Chapter Cascade',
        createdAt: now,
        updatedAt: now,
      ));

      await beatRepo.createBeat(BeatEntity(
        id: 'beat_c1',
        chapterId: 'ch_cascade',
        roadmapId: 'rm_cascade',
        title: 'To Be Deleted',
        createdAt: now,
        updatedAt: now,
      ));

      await dailyMissionRepo.setDailyMission(
        roadmapId: 'rm_cascade',
        date: '2026-09-19',
        beatIds: ['beat_c1'],
      );

      var missionBeats = await dailyMissionRepo.getMissionBeatsForDate('rm_cascade', '2026-09-19');
      expect(missionBeats.length, 1);

      // Delete chapter's beats
      await beatRepo.deleteBeatsByChapterId('ch_cascade');

      missionBeats = await dailyMissionRepo.getMissionBeatsForDate('rm_cascade', '2026-09-19');
      expect(missionBeats.isEmpty, true);
    });
  });
}
