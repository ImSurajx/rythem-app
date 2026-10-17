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

    final latestFile = File('${tempDir.path}/snapshots/${AutoBackupManager.latestBackupFileName}');
    final dailyFile = File('${tempDir.path}/snapshots/rythem_autobackup_2026-09-19.json');

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

  test('createManualBackup saves to manual/ subfolder and replaces existing backup in-place', () async {
    // 1. First manual backup
    final firstBackup = await autoBackupManager.createManualBackup();
    expect(firstBackup, isNotNull);
    expect(firstBackup!.fileName, AutoBackupManager.masterBackupFileName);
    expect(firstBackup.displayTitle, 'Manual Backup');

    // 2. Insert new beat
    final now = DateTime.now().toIso8601String();
    await testDb.insert('beats', {
      'id': 'beat_bs_advanced',
      'chapter_id': 'ch_binary_search',
      'roadmap_id': 'rm_algo',
      'title': 'Binary Search Advanced',
      'effort_weight': 2.0,
      'sort_order': 1,
      'is_completed': 0,
      'created_at': now,
      'updated_at': now,
    });

    // 3. Second manual backup
    final secondBackup = await autoBackupManager.createManualBackup();
    expect(secondBackup, isNotNull);
    expect(secondBackup!.fileName, AutoBackupManager.masterBackupFileName);
    expect(secondBackup.beatsCount, 2);

    // 4. Verify in filesystem: master backup file is in manual/ folder
    final manualFile = File('${tempDir.path}/manual/${AutoBackupManager.masterBackupFileName}');
    expect(manualFile.existsSync(), isTrue);

    final allFiles = tempDir.listSync(recursive: true).whereType<File>().toList();
    final masterFiles = allFiles.where((f) => f.path.endsWith(AutoBackupManager.masterBackupFileName)).toList();
    expect(masterFiles.length, 1);
    expect(masterFiles.first.path, contains('/manual/'));

    // Verify snapshots/ does NOT contain rythem_backup.json
    final snapshotFiles = Directory('${tempDir.path}/snapshots').existsSync()
        ? Directory('${tempDir.path}/snapshots').listSync().whereType<File>().toList()
        : <File>[];
    expect(snapshotFiles.any((f) => f.path.endsWith(AutoBackupManager.masterBackupFileName)), isFalse);

    // Verify no timestamped rythem_backup_YYYY-MM-DD_HH-mm-ss.json files exist
    final timestampedFiles = allFiles.where((f) {
      final name = f.path.split('/').last;
      return RegExp(r'^rythem_backup_\d{4}-\d{2}-\d{2}.*\.json$').hasMatch(name);
    }).toList();
    expect(timestampedFiles, isEmpty);
  });

  test('snapshots and manual backups are cleanly separated into distinct folders', () async {
    // 1. Trigger daily snapshot
    await autoBackupManager.checkAndPerformDailyBackup(currentDate: DateTime(2026, 9, 19));
    // 2. Trigger manual backup
    await autoBackupManager.createManualBackup();

    final snapshotsDir = Directory('${tempDir.path}/snapshots');
    final manualDir = Directory('${tempDir.path}/manual');

    expect(snapshotsDir.existsSync(), isTrue);
    expect(manualDir.existsSync(), isTrue);

    final snapshotFiles = snapshotsDir.listSync().whereType<File>().map((f) => f.path.split('/').last).toList();
    final manualFiles = manualDir.listSync().whereType<File>().map((f) => f.path.split('/').last).toList();

    // Snapshots directory should contain latest snapshot and daily snapshot
    expect(snapshotFiles.contains(AutoBackupManager.latestBackupFileName), isTrue);
    expect(snapshotFiles.contains('rythem_autobackup_2026-09-19.json'), isTrue);
    expect(snapshotFiles.contains(AutoBackupManager.masterBackupFileName), isFalse);

    // Manual directory should only contain master backup file
    expect(manualFiles.contains(AutoBackupManager.masterBackupFileName), isTrue);
    expect(manualFiles.contains(AutoBackupManager.latestBackupFileName), isFalse);

    // Root folder should have no loose JSON files
    final rootFiles = tempDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
    expect(rootFiles, isEmpty);
  });

  test('migrates existing legacy root backups into separate subfolders automatically', () async {
    final migrationDir = await Directory.systemTemp.createTemp('rythem_migration_test_');
    try {
      // Place legacy files directly in root
      final legacyManual = File('${migrationDir.path}/${AutoBackupManager.masterBackupFileName}');
      final legacyLatest = File('${migrationDir.path}/${AutoBackupManager.latestBackupFileName}');
      final jsonPayload = await backupService.exportBackupJson();
      await legacyManual.writeAsString(jsonPayload);
      await legacyLatest.writeAsString(jsonPayload);

      final manager = AutoBackupManager(
        backupService: backupService,
        settingsRepo: settingsRepo,
        overrideDir: migrationDir,
      );

      // Accessing directory triggers migration
      await manager.getResilientBackupDirectory();

      final manualFile = File('${migrationDir.path}/manual/${AutoBackupManager.masterBackupFileName}');
      final snapshotFile = File('${migrationDir.path}/snapshots/${AutoBackupManager.latestBackupFileName}');

      expect(manualFile.existsSync(), isTrue);
      expect(snapshotFile.existsSync(), isTrue);

      // Legacy files at root should have been cleaned up
      expect(File('${migrationDir.path}/${AutoBackupManager.masterBackupFileName}').existsSync(), isFalse);
      expect(File('${migrationDir.path}/${AutoBackupManager.latestBackupFileName}').existsSync(), isFalse);
    } finally {
      if (migrationDir.existsSync()) {
        await migrationDir.delete(recursive: true);
      }
    }
  });
}
