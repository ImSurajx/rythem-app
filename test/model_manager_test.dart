import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rythem_app/core/ai/ai.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;
  late Directory tempDir;
  late AppSettingsRepository settingsRepo;

  setUp(() async {
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await testDb.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    DatabaseService.instance.setDatabaseForTesting(testDb);
    settingsRepo = AppSettingsRepository(dbService: DatabaseService.instance);

    tempDir = await Directory.systemTemp.createTemp('rythem_model_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    await testDb.close();
  });

  group('ModelTier and ModelInfo', () {
    test('Correct metadata for compact and balanced tiers', () {
      final compact = ModelInfo.forTier(ModelTier.compact);
      expect(compact.tier, ModelTier.compact);
      expect(compact.filename, 'qwen2.5-0.5b-instruct-q4_k_m.gguf');
      expect(compact.downloadUrl.contains('ImSurajx/rythem-app/releases'), isTrue);
      expect(compact.formattedSize, contains('MB'));
      expect(compact.targetRamMb, 600);

      final balanced = ModelInfo.forTier(ModelTier.balanced);
      expect(balanced.tier, ModelTier.balanced);
      expect(balanced.filename, 'qwen2.5-1.5b-instruct-q4_k_m.gguf');
      expect(balanced.downloadUrl.contains('ImSurajx/rythem-app/releases'), isTrue);
      expect(balanced.formattedSize, contains('GB'));
      expect(balanced.targetRamMb, 1350);

      final fallback = ModelInfo.forTier(ModelTier.fallback);
      expect(fallback.tier, ModelTier.fallback);
      expect(fallback.formattedSize, contains('0 MB'));
    });
  });

  group('ModelDownloadManager', () {
    test('Default tier is fallback', () async {
      final manager = ModelDownloadManager(
        settingsRepo: settingsRepo,
        overrideModelsDir: tempDir.path,
      );

      expect(await manager.getActiveTier(), ModelTier.fallback);
      expect(await manager.isModelDownloaded(ModelTier.fallback), isTrue);
      expect(await manager.isModelDownloaded(ModelTier.compact), isFalse);
    });

    test('Downloads model with streaming progress and marks downloaded', () async {
      // Create mock HTTP client that streams 15MB of mock binary chunks
      final mockData = List<int>.filled(15 * 1024 * 1024, 42);

      final mockClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(mockData),
          200,
          contentLength: mockData.length,
          headers: {'content-type': 'application/octet-stream'},
        );
      });

      final manager = ModelDownloadManager(
        settingsRepo: settingsRepo,
        client: mockClient,
        overrideModelsDir: tempDir.path,
      );

      final progressUpdates = <DownloadProgress>[];
      await manager.downloadModel(
        ModelTier.compact,
        onProgress: (p) => progressUpdates.add(p),
      );

      expect(progressUpdates.isNotEmpty, isTrue);
      expect(progressUpdates.last.isCompleted, isTrue);
      expect(progressUpdates.last.progress, 1.0);

      final isDownloaded = await manager.isModelDownloaded(ModelTier.compact);
      expect(isDownloaded, isTrue);

      // Successfully activated
      expect(await manager.getActiveTier(), ModelTier.compact);

      // Test delete
      await manager.deleteModel(ModelTier.compact);
      expect(await manager.isModelDownloaded(ModelTier.compact), isFalse);
      expect(await manager.getActiveTier(), ModelTier.fallback);
    });

    test('Singleton returns identical instance when constructed without parameters', () {
      final a = ModelDownloadManager();
      final b = ModelDownloadManager();
      expect(identical(a, b), isTrue);
      expect(identical(a, ModelDownloadManager.instance), isTrue);
    });

    test('clearDownloadError clears error in progress notifier', () {
      final manager = ModelDownloadManager(
        settingsRepo: settingsRepo,
        overrideModelsDir: tempDir.path,
      );

      manager.downloadProgressNotifier.value = const DownloadProgress(
        tier: ModelTier.compact,
        receivedBytes: 100,
        totalBytes: 1000,
        progress: 0.1,
        isCompleted: false,
        error: 'Network disconnected',
      );
      expect(manager.downloadProgressNotifier.value?.error, 'Network disconnected');

      manager.clearDownloadError();
      expect(manager.downloadProgressNotifier.value?.error, isNull);
    });

    test('getActiveTier automatically promotes from fallback to downloaded tier', () async {
      // Create a dummy model file for compact tier in tempDir (> 10MB)
      final compactInfo = ModelInfo.forTier(ModelTier.compact);
      final modelFile = File('${tempDir.path}/${compactInfo.filename}');
      final raf = await modelFile.open(mode: FileMode.write);
      await raf.truncate(15 * 1024 * 1024);
      await raf.close();

      // Active tier in DB is fallback
      await settingsRepo.setSetting('active_model_tier', ModelTier.fallback.name);

      final manager = ModelDownloadManager(
        settingsRepo: settingsRepo,
        overrideModelsDir: tempDir.path,
      );

      // Should automatically detect compact model and activate it
      final active = await manager.getActiveTier();
      expect(active, ModelTier.compact);

      final savedSetting = await settingsRepo.getSetting('active_model_tier');
      expect(savedSetting, ModelTier.compact.name);
    });
  });

  group('LocalInferenceService', () {
    test('Generates structured offline explanations for both fallback and local model', () async {
      final manager = ModelDownloadManager(
        settingsRepo: settingsRepo,
        overrideModelsDir: tempDir.path,
      );
      final inference = LocalInferenceService(downloadManager: manager);

      final explanationFallback = await inference.explainConfusingBeat(
        beatTitle: '05 • Two Pointers Technique',
        roadmapTitle: 'DSA with Python',
      );

      expect(explanationFallback, contains('Core Concept'));
      expect(explanationFallback, contains('Two Pointers Technique'));

      final score = await inference.scoreTopicSimilarity(
        '05 • BFS Level Order Traversal',
        'Breadth First Search',
      );
      expect(score, greaterThan(0.5));
    });

    test('Explains programming concept: what is test case in programming with concrete structure and code', () async {
      final manager = ModelDownloadManager(
        settingsRepo: settingsRepo,
        overrideModelsDir: tempDir.path,
      );
      final inference = LocalInferenceService(downloadManager: manager);

      final explanation = await inference.answerQuery(
        prompt: 'what is test case in programming',
      );

      expect(explanation, contains('Test Case in Programming'));
      expect(explanation, contains('Preconditions'));
      expect(explanation, contains('Expected Result'));
      expect(explanation, contains('Happy Path'));
      expect(explanation, contains('Boundary & Edge Cases'));
      expect(explanation, contains('test('));
    });

    test('Answers tracker queries with real days, completed beats, and pacing from database', () async {
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

      final roadmapRepo = RoadmapRepository(dbService: DatabaseService.instance);
      final beatRepo = BeatRepository(dbService: DatabaseService.instance);
      final now = DateTime.now();

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_dsa',
        title: 'DSA with Python',
        isPrimary: true,
        createdAt: now.subtract(const Duration(days: 12)),
        targetCompletionDate: now.add(const Duration(days: 18)),
        status: 'active',
        updatedAt: now,
      ));

      await beatRepo.createBeat(BeatEntity(
        id: 'b1',
        chapterId: 'c1',
        roadmapId: 'rm_dsa',
        title: 'Two Sum',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: true,
        createdAt: now,
        updatedAt: now,
      ));
      await beatRepo.createBeat(BeatEntity(
        id: 'b2',
        chapterId: 'c1',
        roadmapId: 'rm_dsa',
        title: 'Three Sum',
        effortWeight: 1.5,
        sortOrder: 1,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ));

      final manager = ModelDownloadManager(
        settingsRepo: settingsRepo,
        overrideModelsDir: tempDir.path,
      );
      final inference = LocalInferenceService(
        downloadManager: manager,
        roadmapRepo: roadmapRepo,
        beatRepo: beatRepo,
      );

      final response = await inference.answerQuery(
        prompt: 'look for this tracker & tell me how many days it took me to complete',
        roadmapId: 'rm_dsa',
      );

      expect(response, contains('Tracker Status & Timeline Analysis'));
      expect(response, contains('DSA with Python'));
      expect(response, contains('1 of 2 beats completed'));
      expect(response, contains('days'));
      expect(response, contains('beats/day'));
    });
  });
}
