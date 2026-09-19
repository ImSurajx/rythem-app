import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/backup/services/auto_backup_manager.dart';
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
  late AppSettingsRepository settingsRepo;
  late AutoBackupManager autoBackupManager;

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
    settingsRepo = AppSettingsRepository();
    tempDir = await Directory.systemTemp.createTemp('rythem_autobackup_test_');

    autoBackupManager = AutoBackupManager(
      backupService: backupService,
      settingsRepo: settingsRepo,
      overrideDir: tempDir,
    );

    // Seed sample roadmap, chapter, and beat
    final now = DateTime.now().toIso8601String();
    await testDb.insert('roadmaps', {
      'id': 'rm_algo',
      'title': 'Algorithms & Data Structures',
      'description': 'Mastering algorithms',
      'status': 'active',
      'is_primary': 1,
      'created_at': now,
      'updated_at': now,
    });
    await testDb.insert('chapters', {
      'id': 'ch_binary_search',
      'roadmap_id': 'rm_algo',
      'title': 'Binary Search',
      'sort_order': 0,
      'created_at': now,
      'updated_at': now,
    });
    await testDb.insert('beats', {
      'id': 'beat_bs_basics',
      'chapter_id': 'ch_binary_search',
      'roadmap_id': 'rm_algo',
      'title': 'Binary Search Basics',
      'effort_weight': 1.0,
      'sort_order': 0,
      'is_completed': 1,
      'completed_at': now,
      'created_at': now,
      'updated_at': now,
    });
    await testDb.insert('beat_logs', {
      'id': 'log_1',
      'beat_id': 'beat_bs_basics',
      'roadmap_id': 'rm_algo',
      'completed_date': '2026-09-19',
      'created_at': now,
    });
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
    await testDb.close();
  });

  test('creates latest and date-stamped backup snapshots on daily trigger', () async {
    final today = DateTime(2026, 9, 19);
    final snapshot = await autoBackupManager.checkAndPerformDailyBackup(currentDate: today);

    expect(snapshot, isNotNull);
    expect(snapshot!.fileName, AutoBackupManager.latestBackupFileName);
    expect(snapshot.displayTitle, 'Latest Snapshot');
    expect(snapshot.roadmapsCount, 1);
    expect(snapshot.chaptersCount, 1);
    expect(snapshot.beatsCount, 1);
    expect(snapshot.logsCount, 1);

    final latestFile = File('${tempDir.path}/${AutoBackupManager.latestBackupFileName}');
    final dailyFile = File('${tempDir.path}/rythem_autobackup_2026-09-19.json');

    expect(latestFile.existsSync(), isTrue);
    expect(dailyFile.existsSync(), isTrue);

    final backups = await autoBackupManager.listAvailableBackups();
    final dailySnapshot = backups.firstWhere((b) => b.fileName == 'rythem_autobackup_2026-09-19.json');
    expect(dailySnapshot.displayTitle, '2026-09-19');

    final locationDesc = await autoBackupManager.getStorageLocationDescription();
    expect(locationDesc, isNotEmpty);

    // Verify app_settings recorded last backup date
    final recordedDate = await settingsRepo.getSetting('last_auto_backup_date');
    expect(recordedDate, '2026-09-19');
  });

  test('skips daily backup on same date unless force is true', () async {
    final today = DateTime(2026, 9, 19);
    // First run
    await autoBackupManager.checkAndPerformDailyBackup(currentDate: today);

    // Insert a second roadmap
    final now = DateTime.now().toIso8601String();
    await testDb.insert('roadmaps', {
      'id': 'rm_system_design',
      'title': 'System Design',
      'status': 'active',
      'is_primary': 0,
      'created_at': now,
      'updated_at': now,
    });

    // Run again without force -> should skip update and return existing snapshot
    final skippedSnapshot = await autoBackupManager.checkAndPerformDailyBackup(currentDate: today);
    expect(skippedSnapshot?.roadmapsCount, 1); // Not updated yet

    // Run again with force: true -> should update snapshot to include the 2nd roadmap
    final forcedSnapshot = await autoBackupManager.checkAndPerformDailyBackup(force: true, currentDate: today);
    expect(forcedSnapshot?.roadmapsCount, 2);
  });

  test('prunes old snapshots exceeding maximum retention limit', () async {
    // Generate 10 consecutive daily snapshots
    for (int day = 1; day <= 10; day++) {
      final date = DateTime(2026, 9, day);
      await autoBackupManager.checkAndPerformDailyBackup(force: true, currentDate: date);
    }

    final backups = await autoBackupManager.listAvailableBackups();
    // Daily snapshots should be pruned to 7 + 1 latest pointer = at most 8 files
    final dailySnapshots = backups.where((b) => b.fileName != AutoBackupManager.latestBackupFileName).toList();
    expect(dailySnapshots.length, lessThanOrEqualTo(AutoBackupManager.maxRetainedDailySnapshots));

    // The oldest snapshots (days 1, 2, 3) should have been pruned
    final fileNames = dailySnapshots.map((b) => b.fileName).toList();
    expect(fileNames.contains('rythem_autobackup_2026-09-01.json'), isFalse);
    expect(fileNames.contains('rythem_autobackup_2026-09-10.json'), isTrue);
  });

  test('disaster recovery detects available backup when active database is wiped', () async {
    // 1. Create a valid auto backup
    await autoBackupManager.checkAndPerformDailyBackup(force: true);

    // 2. Simulate database wipe (user cleared app data)
    await testDb.delete('beats');
    await testDb.delete('chapters');
    await testDb.delete('roadmaps');
    await testDb.delete('beat_logs');

    // Verify DB is empty
    final roadmapsBefore = await testDb.query('roadmaps');
    expect(roadmapsBefore.isEmpty, isTrue);

    // 3. Check for disaster recovery
    final disasterBackup = await autoBackupManager.checkForDisasterRecovery();
    expect(disasterBackup, isNotNull);
    expect(disasterBackup!.roadmapsCount, 1);
    expect(disasterBackup.beatsCount, 1);

    // 4. Restore snapshot
    final restoreResult = await autoBackupManager.restoreSnapshot(disasterBackup.file);
    expect(restoreResult['roadmaps'], 1);
    expect(restoreResult['chapters'], 1);
    expect(restoreResult['beats'], 1);

    // 5. Verify database is fully restored
    final roadmapsAfter = await testDb.query('roadmaps');
    expect(roadmapsAfter.length, 1);
    expect(roadmapsAfter.first['title'], 'Algorithms & Data Structures');
  });

  test('disaster recovery returns null when database already contains roadmaps', () async {
    await autoBackupManager.checkAndPerformDailyBackup(force: true);
    final recovery = await autoBackupManager.checkForDisasterRecovery();
    expect(recovery, isNull);
  });
}
