import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/ai/ai.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Fall Behind Math Engine (PacingCalculator)', () {
    test('Scheduled rest days are mathematically excluded from lag streaks and penalty', () {
      final now = DateTime(2026, 9, 15);

      // Past 5 days records:
      // Day 1 (yesterday, Monday): 0 effort on study day -> Lagging
      // Day 2 (Sunday): Rest Day -> Must be ignored, no lag increment
      // Day 3 (Saturday): Rest Day -> Must be ignored, no lag increment
      // Day 4 (Friday): 0 effort on study day -> Lagging
      // Day 5 (Thursday): 0 effort on study day -> Lagging
      final records = [
        DailyPacingRecord(
          date: now.subtract(const Duration(days: 1)),
          completedEffort: 0.0,
          targetEffort: 3.0,
          isRestDay: false,
        ),
        DailyPacingRecord(
          date: now.subtract(const Duration(days: 2)),
          completedEffort: 0.0,
          targetEffort: 0.0,
          isRestDay: true,
        ),
        DailyPacingRecord(
          date: now.subtract(const Duration(days: 3)),
          completedEffort: 0.0,
          targetEffort: 0.0,
          isRestDay: true,
        ),
        DailyPacingRecord(
          date: now.subtract(const Duration(days: 4)),
          completedEffort: 0.0,
          targetEffort: 3.0,
          isRestDay: false,
        ),
        DailyPacingRecord(
          date: now.subtract(const Duration(days: 5)),
          completedEffort: 0.0,
          targetEffort: 3.0,
          isRestDay: false,
        ),
      ];

      final evaluation = PacingCalculator.evaluateShortfallWithSchedule(
        pastDaysRecords: records,
        baseDailyBudget: 3.0,
        lagThresholdDays: 3,
      );

      // 3 active lagging days (rest days were skipped without breaking lag streak or contributing artificial debt)
      expect(evaluation.lagDaysCount, 3);
      expect(evaluation.isSustainedLag, isTrue);
      expect(evaluation.shortfallDebt, 9.0);
      expect(evaluation.velocityDeficit, 3.0);
    });

    test('Healthy study day halts consecutive lag streak', () {
      final now = DateTime(2026, 9, 15);

      // Yesterday had 3.5 effort completed out of 3.0 target -> Healthy day
      final records = [
        DailyPacingRecord(
          date: now.subtract(const Duration(days: 1)),
          completedEffort: 3.5,
          targetEffort: 3.0,
          isRestDay: false,
        ),
        DailyPacingRecord(
          date: now.subtract(const Duration(days: 2)),
          completedEffort: 0.2,
          targetEffort: 3.0,
          isRestDay: false,
        ),
        DailyPacingRecord(
          date: now.subtract(const Duration(days: 3)),
          completedEffort: 0.1,
          targetEffort: 3.0,
          isRestDay: false,
        ),
      ];

      final evaluation = PacingCalculator.evaluateShortfallWithSchedule(
        pastDaysRecords: records,
        baseDailyBudget: 3.0,
      );

      expect(evaluation.lagDaysCount, 0);
      expect(evaluation.isSustainedLag, isFalse);
    });
  });

  group('Fall Behind AI Mentor Diagnosis (LocalInferenceService)', () {
    late Database testDb;
    late RoadmapRepository roadmapRepo;
    late BeatRepository beatRepo;
    late AppSettingsRepository settingsRepo;
    late Directory tempDir;

    setUp(() async {
      testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await testDb.execute('''
        CREATE TABLE roadmaps (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          target_completion_date TEXT,
          status TEXT NOT NULL,
          is_primary INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      await testDb.execute('''
        CREATE TABLE chapters (
          id TEXT PRIMARY KEY,
          roadmap_id TEXT NOT NULL,
          title TEXT NOT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      await testDb.execute('''
        CREATE TABLE beats (
          id TEXT PRIMARY KEY,
          chapter_id TEXT NOT NULL,
          roadmap_id TEXT NOT NULL,
          title TEXT NOT NULL,
          source_url TEXT,
          timestamp_seconds INTEGER,
          effort_weight REAL NOT NULL,
          sort_order INTEGER NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          is_mentor_extra INTEGER NOT NULL DEFAULT 0,
          completed_at TEXT,
          match_confidence REAL,
          syllabus_topic_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      await testDb.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      await testDb.execute('''
        CREATE TABLE daily_missions (
          id TEXT PRIMARY KEY,
          roadmap_id TEXT NOT NULL,
          date TEXT NOT NULL,
          beat_id TEXT NOT NULL,
          sort_index INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (beat_id) REFERENCES beats (id) ON DELETE CASCADE,
          FOREIGN KEY (roadmap_id) REFERENCES roadmaps (id) ON DELETE CASCADE
        );
      ''');

      DatabaseService.instance.setDatabaseForTesting(testDb);
      roadmapRepo = RoadmapRepository(dbService: DatabaseService.instance);
      beatRepo = BeatRepository(dbService: DatabaseService.instance);
      settingsRepo = AppSettingsRepository(dbService: DatabaseService.instance);
      tempDir = await Directory.systemTemp.createTemp('rythem_ai_diag_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
      await testDb.close();
    });

    test('Generates personalized diagnosis, mathematical extension days, and core focus beats', () async {
      final now = DateTime.now();
      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_diag',
        title: 'Quantum Computing Foundations',
        targetCompletionDate: now.add(const Duration(days: 10)),
        createdAt: now,
        updatedAt: now,
      ));

      await beatRepo.createBeat(BeatEntity(
        id: 'b1',
        chapterId: 'c1',
        roadmapId: 'rm_diag',
        title: 'Qubit Superposition',
        effortWeight: 1.5,
        sortOrder: 0,
        isCompleted: false,
        isMentorExtra: false,
        createdAt: now,
        updatedAt: now,
      ));

      await beatRepo.createBeat(BeatEntity(
        id: 'b2',
        chapterId: 'c1',
        roadmapId: 'rm_diag',
        title: 'Quantum Entanglement',
        effortWeight: 1.8,
        sortOrder: 1,
        isCompleted: false,
        isMentorExtra: false,
        createdAt: now,
        updatedAt: now,
      ));

      await beatRepo.createBeat(BeatEntity(
        id: 'b3',
        chapterId: 'c1',
        roadmapId: 'rm_diag',
        title: 'Bloch Sphere Visualization Bonus',
        effortWeight: 0.8,
        sortOrder: 2,
        isCompleted: false,
        isMentorExtra: true,
        createdAt: now,
        updatedAt: now,
      ));

      final downloadManager = ModelDownloadManager(
        settingsRepo: settingsRepo,
        overrideModelsDir: tempDir.path,
      );

      final inferenceService = LocalInferenceService(
        downloadManager: downloadManager,
        roadmapRepo: roadmapRepo,
        beatRepo: beatRepo,
      );

      const budget = PacingBudget(
        roadmapId: 'rm_diag',
        remainingEffort: 4.1,
        daysLeft: 5,
        todayEffortShare: 1.2,
        todaysBeats: [],
        todaysSelectedEffort: 1.5,
        isSustainedLag: true,
        lagStreakDays: 3,
        shortfallDebt: 4.8,
        velocityDeficit: 0.9,
      );

      final diagnosis = await inferenceService.diagnoseShortfallAndRecommend(
        roadmapId: 'rm_diag',
        budget: budget,
      );

      expect(diagnosis.recommendedExtensionDays, greaterThanOrEqualTo(5));
      expect(diagnosis.coreBeatsToFocus, contains('Qubit Superposition'));
      expect(diagnosis.optionalBeatsToDefer, contains('Bloch Sphere Visualization Bonus'));
      expect(diagnosis.diagnosis, contains('debt of 4.8 effort units'));
      expect(diagnosis.rootCause, isNotEmpty);
      expect(diagnosis.encouragement, contains('penalty-free'));
    });

    test('Brand new track created today is never flagged with sustained lag', () async {
      final now = DateTime.now();
      final roadmapRepo = RoadmapRepository();
      final beatRepo = BeatRepository();
      final beatLogRepo = BeatLogRepository();
      final settingsRepo = AppSettingsRepository();
      final pacingService = PacingService(
        roadmapRepo: roadmapRepo,
        beatRepo: beatRepo,
        beatLogRepo: beatLogRepo,
        settingsRepo: settingsRepo,
      );

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_fresh',
        title: 'Brand New Track',
        targetCompletionDate: now.add(const Duration(days: 14)),
        createdAt: now,
        updatedAt: now,
      ));

      await beatRepo.createBeat(BeatEntity(
        id: 'b_fresh_1',
        chapterId: 'c1',
        roadmapId: 'rm_fresh',
        title: 'Fresh Topic',
        effortWeight: 1.0,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      final budget = await pacingService.computePacingBudget('rm_fresh');

      // Must be false because no study days have elapsed since creation!
      expect(budget.isSustainedLag, isFalse);
      expect(budget.lagStreakDays, equals(0));
      expect(budget.shortfallDebt, equals(0.0));
    });

    test('applyPacingDecision saves recalibration timestamp and executes database changes', () async {
      final now = DateTime.now();
      final roadmapRepo = RoadmapRepository();
      final beatRepo = BeatRepository();
      final beatLogRepo = BeatLogRepository();
      final settingsRepo = AppSettingsRepository();
      final pacingService = PacingService(
        roadmapRepo: roadmapRepo,
        beatRepo: beatRepo,
        beatLogRepo: beatLogRepo,
        settingsRepo: settingsRepo,
      );

      final initialTarget = now.add(const Duration(days: 10));
      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_recal',
        title: 'Track To Recalibrate',
        targetCompletionDate: initialTarget,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      ));

      await beatRepo.createBeat(BeatEntity(
        id: 'b_recal_mentor',
        chapterId: 'c1',
        roadmapId: 'rm_recal',
        title: 'Mentor Optional Topic',
        effortWeight: 2.0,
        sortOrder: 0,
        isMentorExtra: true,
        createdAt: now,
        updatedAt: now,
      ));

      // Apply extend target date decision
      await pacingService.applyPacingDecision('rm_recal', const PacingDecision.extendDate(7));

      final updatedRoadmap = await roadmapRepo.getRoadmapById('rm_recal');
      expect(updatedRoadmap!.targetCompletionDate!.difference(initialTarget).inDays, equals(7));

      final recalibratedTimestamp = await settingsRepo.getSetting('last_recalibrated_rm_recal');
      expect(recalibratedTimestamp, isNotNull);

      // Apply trimToCore decision
      await pacingService.applyPacingDecision('rm_recal', const PacingDecision.trimCore());
      final updatedBeat = await beatRepo.getBeatById('b_recal_mentor');
      expect(updatedBeat!.effortWeight, equals(0.0));
    });

    test('ModelInfo formattedSize accurately displays compact ~468.6 MB and balanced ~1.04 GB', () {
      expect(ModelInfo.compact.formattedSize, equals('468.6 MB'));
      expect(ModelInfo.balanced.formattedSize, equals('1.04 GB'));
    });
  });
}
