import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
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

  group('Feature 1: Pure User-Driven Focus Tests', () {
    test('Zero tasks auto-spawn on launch or rollover (Clean Slate guarantee)', () async {
      final now = DateTime(2026, 9, 24, 10, 0);
      final target = now.add(const Duration(days: 7));

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_clean_slate',
        title: 'User Focus Track',
        startDate: now,
        targetCompletionDate: target,
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_1',
        roadmapId: 'rm_clean_slate',
        title: 'Chapter 1',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      final beats = List.generate(
        10,
        (i) => BeatEntity(
          id: 'beat_$i',
          chapterId: 'ch_1',
          roadmapId: 'rm_clean_slate',
          title: 'Lesson $i',
          effortWeight: 1.0,
          sortOrder: i,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await beatRepo.createBeatsBatch(beats);

      // 1. Initial compute on launch
      final budget = await pacingService.computePacingBudget(
        'rm_clean_slate',
        simulatedNow: now,
      );

      // Verify ZERO tasks auto-spawned into todaysBeats
      expect(budget.todaysBeats, isEmpty,
          reason: 'App must never auto-inject tasks into Today\'s Focus on launch.');
      expect(budget.isDailyQuotaCompleted, isFalse);
      expect(budget.remainingEffort, 10.0);
      expect(budget.todayEffortShare, greaterThan(0.0));

      // Verify SQLite daily_missions table is completely empty for today
      const todayDateStr = '2026-09-24';
      final locked = await dailyMissionRepo.getMissionBeatsForDate('rm_clean_slate', todayDateStr);
      expect(locked, isEmpty,
          reason: 'Database daily_missions table must remain pristine until user queues a task.');
    });

    test('1-tap "Queue Next Lesson" pulls exactly one sequential beat in mentor order', () async {
      final now = DateTime(2026, 9, 24, 10, 0);
      final target = now.add(const Duration(days: 7));

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_queue_test',
        title: 'Sequential Queue Track',
        startDate: now,
        targetCompletionDate: target,
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_1',
        roadmapId: 'rm_queue_test',
        title: 'Chapter 1',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      final beats = List.generate(
        5,
        (i) => BeatEntity(
          id: 'seq_beat_$i',
          chapterId: 'ch_1',
          roadmapId: 'rm_queue_test',
          title: 'Sequential Beat $i',
          effortWeight: 1.0,
          sortOrder: i,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await beatRepo.createBeatsBatch(beats);

      // User taps "Queue Next Lesson"
      final queued1 = await pacingService.queueNextBeatIntoTodayFocus('rm_queue_test', simulatedNow: now);
      expect(queued1, isNotNull);
      expect(queued1!.id, 'seq_beat_0');

      // Check budget
      var budget = await pacingService.computePacingBudget('rm_queue_test', simulatedNow: now);
      expect(budget.todaysBeats.length, 1);
      expect(budget.todaysBeats[0].id, 'seq_beat_0');

      // User taps "Queue Next Lesson" again
      final queued2 = await pacingService.queueNextBeatIntoTodayFocus('rm_queue_test', simulatedNow: now);
      expect(queued2, isNotNull);
      expect(queued2!.id, 'seq_beat_1');

      budget = await pacingService.computePacingBudget('rm_queue_test', simulatedNow: now);
      expect(budget.todaysBeats.length, 2);
      expect(budget.todaysBeats[0].id, 'seq_beat_0');
      expect(budget.todaysBeats[1].id, 'seq_beat_1');
    });

    test('User can add and remove specific beats directly via addBeatToTodayFocus & removeBeatFromTodayFocus', () async {
      final now = DateTime(2026, 9, 24, 10, 0);

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_manual_focus',
        title: 'Manual Focus Track',
        targetCompletionDate: now.add(const Duration(days: 5)),
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_intro',
        roadmapId: 'rm_manual_focus',
        title: 'Intro',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      final beats = [
        BeatEntity(
          id: 'custom_b1',
          chapterId: 'ch_intro',
          roadmapId: 'rm_manual_focus',
          title: 'Custom Topic 1',
          effortWeight: 1.0,
          sortOrder: 0,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'custom_b2',
          chapterId: 'ch_intro',
          roadmapId: 'rm_manual_focus',
          title: 'Custom Topic 2',
          effortWeight: 1.0,
          sortOrder: 1,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      await beatRepo.createBeatsBatch(beats);

      // 1. Add custom_b2 first (user chooses what to study today)
      await pacingService.addBeatToTodayFocus('rm_manual_focus', 'custom_b2', simulatedNow: now);

      var budget = await pacingService.computePacingBudget('rm_manual_focus', simulatedNow: now);
      expect(budget.todaysBeats.length, 1);
      expect(budget.todaysBeats[0].id, 'custom_b2');

      // 2. Add custom_b1
      await pacingService.addBeatToTodayFocus('rm_manual_focus', 'custom_b1', simulatedNow: now);

      budget = await pacingService.computePacingBudget('rm_manual_focus', simulatedNow: now);
      expect(budget.todaysBeats.length, 2);
      expect(budget.todaysBeats.map((b) => b.id).toList(), ['custom_b2', 'custom_b1']);

      // 3. Remove custom_b2 from today's focus
      await pacingService.removeBeatFromTodayFocus('rm_manual_focus', 'custom_b2', simulatedNow: now);

      budget = await pacingService.computePacingBudget('rm_manual_focus', simulatedNow: now);
      expect(budget.todaysBeats.length, 1);
      expect(budget.todaysBeats[0].id, 'custom_b1');

      // Verify custom_b2 is still intact in the database as an incomplete beat
      final b2 = await beatRepo.getBeatById('custom_b2');
      expect(b2, isNotNull);
      expect(b2!.isCompleted, isFalse);
    });

    test('Completing all queued beats marks isDailyQuotaCompleted without auto-spawning more tasks', () async {
      final now = DateTime(2026, 9, 24, 10, 0);

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_quota_test',
        title: 'Quota Track',
        targetCompletionDate: now.add(const Duration(days: 3)),
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_quota',
        roadmapId: 'rm_quota_test',
        title: 'Quota Chapter',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      final beats = List.generate(
        5,
        (i) => BeatEntity(
          id: 'q_beat_$i',
          chapterId: 'ch_quota',
          roadmapId: 'rm_quota_test',
          title: 'Quota Beat $i',
          effortWeight: 1.0,
          sortOrder: i,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await beatRepo.createBeatsBatch(beats);

      // User selects 2 beats for today
      await pacingService.addBeatToTodayFocus('rm_quota_test', 'q_beat_0', simulatedNow: now);
      await pacingService.addBeatToTodayFocus('rm_quota_test', 'q_beat_1', simulatedNow: now);

      // User completes first beat
      await beatRepo.toggleBeatCompletion('q_beat_0', isCompleted: true);
      var budget = await pacingService.computePacingBudget('rm_quota_test', simulatedNow: now);
      expect(budget.todaysBeats.length, 2);
      expect(budget.isDailyQuotaCompleted, isFalse);

      // User completes second beat
      await beatRepo.toggleBeatCompletion('q_beat_1', isCompleted: true);
      budget = await pacingService.computePacingBudget('rm_quota_test', simulatedNow: now);
      expect(budget.todaysBeats.length, 2);
      expect(budget.isDailyQuotaCompleted, isTrue);

      // CRITICAL: The engine must NOT automatically pull q_beat_2
      expect(budget.todaysBeats.map((b) => b.id).toList(), ['q_beat_0', 'q_beat_1']);

      // But user can voluntarily queue another lesson if they want to keep going
      final queuedMore = await pacingService.queueNextBeatIntoTodayFocus('rm_quota_test', simulatedNow: now);
      expect(queuedMore, isNotNull);
      expect(queuedMore!.id, 'q_beat_2');

      budget = await pacingService.computePacingBudget('rm_quota_test', simulatedNow: now);
      expect(budget.todaysBeats.length, 3);
      expect(budget.isDailyQuotaCompleted, isFalse,
          reason: 'Now user has 1 incomplete beat queued voluntarily.');
    });
  });
}
