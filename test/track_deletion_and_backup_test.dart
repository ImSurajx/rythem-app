import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/backup/services/backup_service.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Track Deletion & Backup Export/Import Tests', () {
    test('Deleting a roadmap deletes the track from database', () async {
      await DatabaseService.instance.initInMemoryForTesting();

      final roadmapRepo = RoadmapRepository();
      final chapterRepo = ChapterRepository();
      final beatRepo = BeatRepository();

      final now = DateTime.now();
      final rm = RoadmapEntity(
        id: 'rm_to_delete',
        title: 'Delete Me Track',
        description: 'Test deletion',
        createdAt: now,
        updatedAt: now,
      );
      await roadmapRepo.createRoadmap(rm);

      final ch = ChapterEntity(
        id: 'ch_del_1',
        roadmapId: rm.id,
        title: 'Chapter to Delete',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      await chapterRepo.createChapter(ch);

      final beat = BeatEntity(
        id: 'beat_del_1',
        chapterId: ch.id,
        roadmapId: rm.id,
        title: 'Beat to Delete',
        effortWeight: 1.0,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      await beatRepo.createBeat(beat);

      expect(await roadmapRepo.getRoadmapById('rm_to_delete'), isNotNull);

      // Perform deletion
      await roadmapRepo.deleteRoadmap('rm_to_delete');

      // Verify deletion
      expect(await roadmapRepo.getRoadmapById('rm_to_delete'), isNull);

      await DatabaseService.instance.close();
    });

    test('Backup export generates complete JSON and import restores full state', () async {
      await DatabaseService.instance.initInMemoryForTesting();

      final roadmapRepo = RoadmapRepository();
      final chapterRepo = ChapterRepository();
      final beatRepo = BeatRepository();
      final settingsRepo = AppSettingsRepository();
      final backupService = BackupService();

      final now = DateTime.now();
      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: 'rm_backup_1',
        title: 'Backup & Restore Track',
        description: 'Testing full portability',
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_backup_1',
        roadmapId: 'rm_backup_1',
        title: 'Backup Chapter',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      await beatRepo.createBeat(BeatEntity(
        id: 'beat_backup_1',
        chapterId: 'ch_backup_1',
        roadmapId: 'rm_backup_1',
        title: 'Backup Beat 1',
        effortWeight: 2.0,
        isCompleted: false,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      await beatRepo.toggleBeatCompletion('beat_backup_1', isCompleted: true);
      await settingsRepo.setSetting('app_theme_mode', 'dark');

      // 1. Export backup JSON
      final exportedJson = await backupService.exportBackupJson();
      expect(exportedJson.isNotEmpty, isTrue);

      final parsed = jsonDecode(exportedJson) as Map<String, dynamic>;
      final tables = parsed['tables'] as Map<String, dynamic>;
      expect((tables[DatabaseTables.roadmaps] as List).length, 1);
      expect((tables[DatabaseTables.chapters] as List).length, 1);
      expect((tables[DatabaseTables.beats] as List).length, 1);
      expect((tables[DatabaseTables.beatLogs] as List).length, 1);

      // 2. Clear database / simulate app reset
      await roadmapRepo.deleteRoadmap('rm_backup_1');
      await settingsRepo.setSetting('app_theme_mode', 'light');

      expect(await roadmapRepo.getRoadmapById('rm_backup_1'), isNull);
      expect(await settingsRepo.getSetting('app_theme_mode'), 'light');

      // 3. Restore backup JSON
      final restoreSuccess = await backupService.importBackupJson(exportedJson);
      expect(restoreSuccess, isNotNull);
      expect(restoreSuccess['roadmaps'], 1);

      // 4. Verify restored state
      final restoredRm = await roadmapRepo.getRoadmapById('rm_backup_1');
      expect(restoredRm, isNotNull);
      expect(restoredRm!.title, 'Backup & Restore Track');

      final restoredBeats = await beatRepo.getBeatsByRoadmapId('rm_backup_1');
      expect(restoredBeats.length, 1);
      expect(restoredBeats.first.title, 'Backup Beat 1');
      expect(restoredBeats.first.isCompleted, isTrue);

      final restoredSetting = await settingsRepo.getSetting('app_theme_mode');
      expect(restoredSetting, 'dark');

      await DatabaseService.instance.close();
    });
  });
}
