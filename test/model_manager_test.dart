import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rythem_app/core/ai/ai.dart';
import 'package:rythem_app/core/database/database_service.dart';
import 'package:rythem_app/core/database/repositories/app_settings_repository.dart';
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
  });
}
