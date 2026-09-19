import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rythem_app/core/ai/ai.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:rythem_app/core/revision/services/revision_service.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/features/explore/roadmap_detail_screen.dart';
import 'package:rythem_app/features/flow/widgets/backlog_decision_sheet.dart';
import 'package:rythem_app/features/flow/widgets/daily_revision_board.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late Database testDb;
  late Directory tempDir;
  late AppSettingsRepository settingsRepo;
  late RoadmapRepository roadmapRepo;
  late ChapterRepository chapterRepo;
  late BeatRepository beatRepo;
  late BeatLogRepository beatLogRepo;
  late PacingService pacingService;
  late LocalInferenceService inferenceService;
  late RevisionService revisionService;

  setUp(() async {
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await testDb.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await testDb.execute('''
      CREATE TABLE roadmaps (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        start_date TEXT,
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
        effort_weight REAL NOT NULL DEFAULT 1.0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        is_mentor_extra INTEGER NOT NULL DEFAULT 0,
        match_confidence REAL,
        syllabus_topic_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await testDb.execute('''
      CREATE TABLE beat_logs (
        id TEXT PRIMARY KEY,
        beat_id TEXT NOT NULL,
        roadmap_id TEXT NOT NULL,
        completed_date TEXT NOT NULL,
        created_at TEXT NOT NULL
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
    settingsRepo = AppSettingsRepository(dbService: DatabaseService.instance);
    roadmapRepo = RoadmapRepository(dbService: DatabaseService.instance);
    chapterRepo = ChapterRepository(dbService: DatabaseService.instance);
    beatRepo = BeatRepository(dbService: DatabaseService.instance);
    beatLogRepo = BeatLogRepository(dbService: DatabaseService.instance);
    pacingService = PacingService(
      roadmapRepo: roadmapRepo,
      beatRepo: beatRepo,
      beatLogRepo: beatLogRepo,
      settingsRepo: settingsRepo,
    );

    tempDir = await Directory.systemTemp.createTemp('rythem_backlog_ai_test_');
    final downloadManager = ModelDownloadManager(
      settingsRepo: settingsRepo,
      overrideModelsDir: tempDir.path,
    );
    inferenceService = LocalInferenceService(
      downloadManager: downloadManager,
      roadmapRepo: roadmapRepo,
      beatRepo: beatRepo,
      pacingService: pacingService,
    );
    revisionService = RevisionService(settingsRepo: settingsRepo);
  });

  tearDown(() async {
    DatabaseService.instance.setDatabaseForTesting(null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    await testDb.close();
  });

  group('Backlog AI Model Execution Tests', () {
    test('AI Model runs diagnosis on real database roadblock and calculates pace dilution', () async {
      final now = DateTime.now();
      const roadmapId = 'rm_deep_learning';

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: roadmapId,
        title: 'Deep Learning Mastery',
        isPrimary: true,
        targetCompletionDate: now.add(const Duration(days: 10)),
        createdAt: now.subtract(const Duration(days: 14)),
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_1',
        roadmapId: roadmapId,
        title: 'Neural Networks Foundations',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      // Create foundational beats: 2 completed, 1 steep roadblock beat, 2 pending
      await beatRepo.createBeat(BeatEntity(
        id: 'b1',
        chapterId: 'ch_1',
        roadmapId: roadmapId,
        title: 'Linear Algebra Tensors',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: true,
        completedAt: now.subtract(const Duration(days: 6)),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 6)),
      ));
      await beatRepo.createBeat(BeatEntity(
        id: 'b2',
        chapterId: 'ch_1',
        roadmapId: roadmapId,
        title: 'Multivariable Derivatives',
        effortWeight: 1.0,
        sortOrder: 1,
        isCompleted: true,
        completedAt: now.subtract(const Duration(days: 4)),
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ));
      await beatRepo.createBeat(BeatEntity(
        id: 'b3',
        chapterId: 'ch_1',
        roadmapId: roadmapId,
        title: 'Backpropagation Vector Tensor Calculus',
        effortWeight: 2.5,
        sortOrder: 2,
        isCompleted: false,
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now,
      ));
      await beatRepo.createBeat(BeatEntity(
        id: 'b4',
        chapterId: 'ch_1',
        roadmapId: roadmapId,
        title: 'Matrix Factorization in CUDA',
        effortWeight: 1.5,
        sortOrder: 3,
        isCompleted: false,
        isMentorExtra: true,
        createdAt: now,
        updatedAt: now,
      ));
      await beatRepo.createBeat(BeatEntity(
        id: 'b5',
        chapterId: 'ch_1',
        roadmapId: roadmapId,
        title: 'Gradient Descent Optimization',
        effortWeight: 1.2,
        sortOrder: 4,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ));

      // Simulate sustained lag
      const laggingBudget = PacingBudget(
        roadmapId: roadmapId,
        todayEffortShare: 2.2,
        todaysBeats: [],
        todaysSelectedEffort: 0.0,
        remainingEffort: 5.2,
        daysLeft: 6,
        isSustainedLag: true,
        lagStreakDays: 4,
        shortfallDebt: 4.8,
        velocityDeficit: 1.2,
        recentVelocity: 0.8,
      );

      final diagnosis = await inferenceService.diagnoseShortfallAndRecommend(
        roadmapId: roadmapId,
        budget: laggingBudget,
      );

      // Verify AI model specifically identified the stalled beat
      expect(diagnosis.bottleneckBeatTitle, 'Backpropagation Vector Tensor Calculus');
      expect(diagnosis.pedagogicalRemedy, contains('Decompress roadblock beat'));
      expect(diagnosis.recommendedExtensionDays, greaterThanOrEqualTo(2));
      expect(diagnosis.recommendedExtensionDays, lessThanOrEqualTo(14));
      expect(diagnosis.calculatedDailyPace, lessThan(laggingBudget.todayEffortShare));
      expect(diagnosis.optionalBeatsToDefer, contains('Matrix Factorization in CUDA'));
      expect(diagnosis.coreBeatsToFocus, contains('Backpropagation Vector Tensor Calculus'));
      expect(diagnosis.diagnosis, contains('Backpropagation Vector Tensor Calculus'));
    });

    test('Applying AI PacingDecision updates target completion date in SQLite database', () async {
      final now = DateTime.now();
      const roadmapId = 'rm_apply_test';

      final roadmap = RoadmapEntity(
        id: roadmapId,
        title: 'Algorithms in Go',
        isPrimary: true,
        targetCompletionDate: now.add(const Duration(days: 7)),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
      );
      await roadmapRepo.createRoadmap(roadmap);

      const decision = PacingDecision(
        type: PacingDecisionType.extendTargetDate,
        extensionDays: 5,
      );

      await pacingService.applyPacingDecision(roadmapId, decision);

      final updatedRoadmap = await roadmapRepo.getRoadmapById(roadmapId);
      expect(updatedRoadmap, isNotNull);
      final difference = updatedRoadmap!.targetCompletionDate!.difference(roadmap.targetCompletionDate!).inDays;
      expect(difference, 5);
    });

    testWidgets('BacklogDecisionSheet displays AI diagnosis and selects PacingDecision', (tester) async {
      final now = DateTime.now();
      const roadmapId = 'rm_dsa_ui';

      final roadmap = RoadmapEntity(
        id: roadmapId,
        title: 'DSA with Python',
        isPrimary: true,
        targetCompletionDate: now.add(const Duration(days: 8)),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now,
      );

      const budget = PacingBudget(
        roadmapId: roadmapId,
        todayEffortShare: 2.5,
        todaysBeats: [],
        todaysSelectedEffort: 0.0,
        remainingEffort: 6.0,
        daysLeft: 5,
        isSustainedLag: true,
        lagStreakDays: 3,
        shortfallDebt: 3.5,
        velocityDeficit: 0.9,
        recentVelocity: 0.7,
      );

      const mockDiag = ShortfallDiagnosis(
        diagnosis: 'AI diagnosed momentum friction at roadblock topic "0/1 Knapsack Dynamic Programming".',
        rootCause: 'Stalled on "0/1 Knapsack Dynamic Programming" causing 3.5 debt units.',
        recommendedExtensionDays: 4,
        coreBeatsToFocus: ['0/1 Knapsack Dynamic Programming'],
        optionalBeatsToDefer: [],
        encouragement: 'Rhythm shifts are natural.',
        shortfallDebt: 3.5,
        velocityDeficit: 0.9,
        bottleneckBeatTitle: '0/1 Knapsack Dynamic Programming',
        pedagogicalRemedy: 'Decompress roadblock beat into micro-sessions',
        calculatedDailyPace: 1.3,
      );

      final mockInference = _MockDiagnosisInferenceService(mockDiag);
      PacingDecision? selectedDecision;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BacklogDecisionSheet(
              roadmap: roadmap,
              pacingBudget: budget,
              inferenceService: mockInference,
              onDecisionSelected: (d) => selectedDecision = d,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('AI MENTOR DIAGNOSIS'), findsOneWidget);
      expect(find.textContaining('0/1 Knapsack Dynamic Programming'), findsWidgets);
      expect(find.textContaining('Push Target Date'), findsOneWidget);

      await tester.tap(find.textContaining('Push Target Date'), warnIfMissed: false);
      await tester.pump();

      expect(selectedDecision, isNotNull);
      expect(selectedDecision!.type, PacingDecisionType.extendTargetDate);
      expect(selectedDecision!.extensionDays, greaterThanOrEqualTo(2));
    });
  });

  group('Todo Outer-Inner Synchronization Tests', () {
    test('Completing 5 beats outside updates SQLite and maintains synchronized state', () async {
      final now = DateTime.now();
      const roadmapId = 'rm_sync_test';

      final roadmap = RoadmapEntity(
        id: roadmapId,
        title: 'Full Stack Flutter',
        isPrimary: true,
        targetCompletionDate: now.add(const Duration(days: 14)),
        createdAt: now,
        updatedAt: now,
      );
      await roadmapRepo.createRoadmap(roadmap);

      final chapter = ChapterEntity(
        id: 'ch_sync',
        roadmapId: roadmapId,
        title: 'State Architecture',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      await chapterRepo.createChapter(chapter);

      final createdBeats = <BeatEntity>[];
      for (int i = 1; i <= 5; i++) {
        final beat = BeatEntity(
          id: 'beat_task_$i',
          chapterId: 'ch_sync',
          roadmapId: roadmapId,
          title: 'Architectural Step $i',
          effortWeight: 1.0,
          sortOrder: i,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        );
        await beatRepo.createBeat(beat);
        createdBeats.add(beat);
      }

      // User taps 5 items outside
      for (final b in createdBeats) {
        await beatRepo.toggleBeatCompletion(b.id, isCompleted: true);
      }

      // In SQLite, exactly 5 of 5 beats must be marked complete
      final dbBeats = await beatRepo.getBeatsByRoadmapId(roadmapId);
      expect(dbBeats.length, 5);
      expect(dbBeats.where((b) => b.isCompleted).length, 5);
    });

    testWidgets('RoadmapDetailScreen displays 5 of 5 beats completed when loaded', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      const roadmapId = 'rm_detail_ui';

      final roadmap = RoadmapEntity(
        id: roadmapId,
        title: 'Full Stack Flutter',
        isPrimary: true,
        targetCompletionDate: now.add(const Duration(days: 14)),
        createdAt: now,
        updatedAt: now,
      );

      final chapter = ChapterEntity(
        id: 'ch_sync',
        roadmapId: roadmapId,
        title: 'State Architecture',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      final completedBeats = List.generate(
        5,
        (i) => BeatEntity(
          id: 'beat_completed_$i',
          chapterId: 'ch_sync',
          roadmapId: roadmapId,
          title: 'Completed Step ${i + 1}',
          effortWeight: 1.0,
          sortOrder: i,
          isCompleted: true,
          completedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RoadmapDetailScreen(
              roadmap: roadmap,
              chapters: [chapter],
              beats: completedBeats,
              onBeatToggled: (_, __) async {},
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('5 of 5 beats completed'), findsOneWidget);
    });
  });

  group('On-Demand Revision Tests', () {
    test('Beats completed today are NOT queued for same-day revision unless flagged weak', () async {
      final now = DateTime.now();
      const roadmapId = 'rm_rev_test';

      final roadmap = RoadmapEntity(
        id: roadmapId,
        title: 'DSA Python',
        isPrimary: true,
        targetCompletionDate: now.add(const Duration(days: 14)),
        createdAt: now,
        updatedAt: now,
      );

      // Beat finished 5 minutes ago today
      final beatJustCompletedToday = BeatEntity(
        id: 'b_today_finished',
        chapterId: 'c1',
        roadmapId: roadmapId,
        title: 'Sliding Window Fixed Length',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: true,
        completedAt: now.subtract(const Duration(minutes: 5)),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );

      // Beat finished 8 days ago (due for revision via Ebbinghaus curve)
      final beatFromLastWeek = BeatEntity(
        id: 'b_last_week',
        chapterId: 'c1',
        roadmapId: roadmapId,
        title: 'Binary Search Left Bound',
        effortWeight: 1.0,
        sortOrder: 1,
        isCompleted: true,
        completedAt: now.subtract(const Duration(days: 8)),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 8)),
      );

      final recommendations = await revisionService.getDailyRevisionRecommendations(
        roadmaps: [roadmap],
        beatsByRoadmap: {
          roadmapId: [beatJustCompletedToday, beatFromLastWeek],
        },
        inferenceService: inferenceService,
      );

      // The beat completed today must NOT be in the recommendations
      expect(recommendations.any((r) => r.beatId == 'b_today_finished'), isFalse);
      // The beat completed 8 days ago should be recommended
      expect(recommendations.any((r) => r.beatId == 'b_last_week'), isTrue);
    });

    testWidgets('DailyRevisionBoard renders On-Demand Ask AI card when items are empty', (tester) async {
      bool requestCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyRevisionBoard(
              revisionItems: const [],
              onMarkRevised: (_) {},
              onRequestRecommendations: () => requestCalled = true,
              themeColors: RythemColors.dark,
              isDark: true,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('AI REVISION MENTOR'), findsOneWidget);
      expect(find.text('See What to Revise'), findsOneWidget);

      await tester.tap(find.text('See What to Revise'));
      await tester.pump();

      expect(requestCalled, isTrue);
    });
  });
}

class _MockDiagnosisInferenceService extends LocalInferenceService {
  final ShortfallDiagnosis mockDiag;

  _MockDiagnosisInferenceService(this.mockDiag);

  @override
  bool get isModelDownloading => false;

  @override
  Future<ShortfallDiagnosis> diagnoseShortfallAndRecommend({
    required String roadmapId,
    required PacingBudget budget,
  }) async {
    return mockDiag;
  }
}
