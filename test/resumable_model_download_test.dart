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
    tempDir = await Directory.systemTemp.createTemp('rythem_resumable_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    await testDb.close();
  });

  group('Resumable Model Downloads & App Closure Recovery', () {
    test('Interrupted download preserves .part file and resumes from offset with HTTP Range', () async {
      final finalPath = '${tempDir.path}/qwen2.5-0.5b-instruct-q4_k_m.gguf';
      final partFile = File('$finalPath.part');

      // Pre-seed 5 MB of mock partial data representing interrupted download
      const existingBytesCount = 5 * 1024 * 1024;
      final initialChunk = List<int>.filled(existingBytesCount, 1);
      await partFile.writeAsBytes(initialChunk);

      // Remaining 10 MB to complete 15 MB file
      const remainingBytesCount = 10 * 1024 * 1024;
      final remainingChunk = List<int>.filled(remainingBytesCount, 2);

      String? recordedRangeHeader;

      final mockClient = MockClient.streaming((request, bodyStream) async {
        recordedRangeHeader = request.headers['Range'];

        // Respond with HTTP 206 (Partial Content)
        return http.StreamedResponse(
          Stream.value(remainingChunk),
          206,
          contentLength: remainingChunk.length,
          headers: {
            'content-type': 'application/octet-stream',
            'content-range': 'bytes $existingBytesCount-15728639/15728640',
          },
        );
      });

      final manager = ModelDownloadManager(
        settingsRepo: settingsRepo,
        client: mockClient,
        overrideModelsDir: tempDir.path,
      );

      final updates = <DownloadProgress>[];
      await manager.downloadModel(
        ModelTier.compact,
        onProgress: (p) => updates.add(p),
      );

      // Verify that Range header was sent requesting bytes from offset
      expect(recordedRangeHeader, equals('bytes=$existingBytesCount-'));

      // Verify final file was assembled and has full 15 MB
      final finalFile = File(finalPath);
      expect(finalFile.existsSync(), isTrue);
      expect(await finalFile.length(), equals(existingBytesCount + remainingBytesCount));

      // Verify .part file was cleaned up on completion
      expect(partFile.existsSync(), isFalse);

      // Verify pending checkpoint was cleared in AppSettings
      expect(await settingsRepo.getSetting('model_download_pending_tier'), isNull);
    });

    test('resumePendingDownload automatically resumes incomplete download recorded in settings', () async {
      await settingsRepo.setSetting('model_download_pending_tier', ModelTier.compact.name);
      await settingsRepo.setSetting('model_download_bytes', '1048576');

      final mockData = List<int>.filled(12 * 1024 * 1024, 7);
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

      expect(await manager.getPendingDownloadTier(), ModelTier.compact);

      await manager.resumePendingDownload();

      expect(await manager.isModelDownloaded(ModelTier.compact), isTrue);
      expect(await manager.getPendingDownloadTier(), isNull);
    });

    test('downloadModel returns immediately without network calls if model is already downloaded', () async {
      final compactInfo = ModelInfo.forTier(ModelTier.compact);
      final finalFile = File('${tempDir.path}/${compactInfo.filename}');
      final raf = await finalFile.open(mode: FileMode.write);
      await raf.truncate(15 * 1024 * 1024);
      await raf.close();

      int clientCallCount = 0;
      final mockClient = MockClient((request) async {
        clientCallCount++;
        return http.Response('should not be called', 500);
      });

      final manager = ModelDownloadManager(
        settingsRepo: settingsRepo,
        client: mockClient,
        overrideModelsDir: tempDir.path,
      );

      expect(await manager.isModelDownloaded(ModelTier.compact), isTrue);

      await manager.downloadModel(ModelTier.compact);

      // Verify no network calls were made and model remains active
      expect(clientCallCount, equals(0));
      expect(await manager.getActiveTier(), equals(ModelTier.compact));
      expect(manager.downloadProgressNotifier.value?.isCompleted, isTrue);
    });

    test('resumePendingDownload executes safely with mutex guard against concurrent calls', () async {
      await settingsRepo.setSetting('preferred_model_tier', ModelTier.compact.name);

      final mockData = List<int>.filled(12 * 1024 * 1024, 7);
      int networkInvocations = 0;
      final mockClient = MockClient.streaming((request, bodyStream) async {
        networkInvocations++;
        // Small delay to allow concurrent call to arrive
        await Future.delayed(const Duration(milliseconds: 50));
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

      // Fire two resumes concurrently
      final f1 = manager.resumePendingDownload();
      final f2 = manager.resumePendingDownload();
      await Future.wait([f1, f2]);

      expect(networkInvocations, equals(1));
      expect(await manager.isModelDownloaded(ModelTier.compact), isTrue);
    });
  });
}
