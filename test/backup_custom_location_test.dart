import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/backup/services/backup_service.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;
  late Directory tempDir;
  late BackupService backupService;

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
        total_parts INTEGER NOT NULL DEFAULT 1,
        completed_parts INTEGER NOT NULL DEFAULT 0,
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
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    DatabaseService.instance.setDatabaseForTesting(testDb);
    backupService = BackupService(dbService: DatabaseService.instance);
    tempDir = await Directory.systemTemp.createTemp('rythem_backup_loc_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    await testDb.close();
  });

  group('Custom Backup Export Location', () {
    test('exportToFile saves backup at user specified custom path', () async {
      final customPath = '${tempDir.path}/my_custom_folder/custom_rythem_backup.json';

      final exportedFile = await backupService.exportToFile(customPath: customPath);

      expect(exportedFile, isNotNull);
      expect(exportedFile!.existsSync(), isTrue);
      expect(exportedFile.path, equals(customPath));

      final contents = await exportedFile.readAsString();
      expect(contents, contains('"version": 1'));
      expect(contents, contains('"roadmaps"'));
      expect(contents, contains('"chapters"'));
      expect(contents, contains('"beats"'));
      expect(contents, contains('"app_settings"'));
    });
  });
}
