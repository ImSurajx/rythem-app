import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../database/database_service.dart';
import '../../database/repositories/app_settings_repository.dart';
import 'backup_service.dart';

/// Metadata summary of a local auto-backup snapshot without full database deserialization.
class BackupSnapshotInfo {
  final File file;
  final String fileName;
  final DateTime timestamp;
  final int roadmapsCount;
  final int chaptersCount;
  final int beatsCount;
  final int logsCount;
  final int sizeBytes;

  const BackupSnapshotInfo({
    required this.file,
    required this.fileName,
    required this.timestamp,
    required this.roadmapsCount,
    required this.chaptersCount,
    required this.beatsCount,
    required this.logsCount,
    required this.sizeBytes,
  });

  String get displayTitle {
    if (fileName == AutoBackupManager.latestBackupFileName) {
      return 'Latest Snapshot';
    }
    if (fileName == AutoBackupManager.masterBackupFileName) {
      return 'Manual Backup';
    }
    final match = RegExp(r'rythem_(?:auto)?backup_(\d{4}-\d{2}-\d{2}[^\.]*)\.json').firstMatch(fileName);
    if (match != null) {
      return match.group(1)!;
    }
    if (fileName.startsWith('rythem_autobackup_')) {
      return fileName.replaceFirst('rythem_autobackup_', '').replaceFirst('.json', '');
    }
    if (fileName.startsWith('rythem_backup_')) {
      return fileName.replaceFirst('rythem_backup_', '').replaceFirst('.json', '');
    }
    return fileName;
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  String get relativeTimeDescription {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

/// Ambient on-device backup manager (WhatsApp-style local storage architecture).
/// 
/// Core responsibilities:
/// 1. Resilient Local Storage: Writes to persistent storage directory that survives app data clears.
/// 2. Daily Automatic Cadence: Silently runs once per day during active sessions.
/// 3. Snapshot Rotation: Keeps `rythem_autobackup_latest.json` + rolling daily history (up to 7 days).
/// 4. Disaster Recovery: Detects existing backups when app data is wiped or database is empty.
class AutoBackupManager {
  static const String _prefLastAutoBackupDateKey = 'last_auto_backup_date';
  static const String masterBackupFileName = 'rythem_backup.json';
  static const String latestBackupFileName = 'rythem_autobackup_latest.json';
  static const String snapshotsDirName = 'snapshots';
  static const String manualBackupDirName = 'manual';
  static const int maxRetainedDailySnapshots = 7;

  final BackupService _backupService;
  final AppSettingsRepository _settingsRepo;
  final Directory? _overrideDir;

  AutoBackupManager({
    BackupService? backupService,
    AppSettingsRepository? settingsRepo,
    Directory? overrideDir,
  })  : _backupService = backupService ?? BackupService(),
        _settingsRepo = settingsRepo ?? AppSettingsRepository(),
        _overrideDir = overrideDir;

  /// Resolves the dedicated directory for automatic snapshots: `<backupDir>/snapshots`.
  Future<Directory> getSnapshotsDirectory() async {
    final baseDir = await getResilientBackupDirectory();
    final snapshotsDir = Directory(p.join(baseDir.path, snapshotsDirName));
    if (!snapshotsDir.existsSync()) {
      await snapshotsDir.create(recursive: true);
    }
    return snapshotsDir;
  }

  /// Resolves the dedicated directory for manual user backups: `<backupDir>/manual`.
  Future<Directory> getManualBackupDirectory() async {
    final baseDir = await getResilientBackupDirectory();
    final manualDir = Directory(p.join(baseDir.path, manualBackupDirName));
    if (!manualDir.existsSync()) {
      await manualDir.create(recursive: true);
    }
    return manualDir;
  }

  /// Resolves the user-visible storage location label for UI display.
  Future<String> getStorageLocationDescription() async {
    try {
      final dir = await getResilientBackupDirectory();
      final p = dir.path;
      if (p.contains('/storage/emulated/0/Documents')) {
        return 'Documents > Rythem > Backups';
      } else if (p.contains('/storage/emulated/0/Download')) {
        return 'Download > Rythem > Backups';
      } else if (p.contains('/Documents')) {
        return 'Documents/Rythem/Backups';
      }
      final parts = p.split('/').where((s) => s.isNotEmpty).toList();
      return parts.length >= 3 ? parts.sublist(parts.length - 3).join('/') : p;
    } catch (_) {
      return 'Documents/Rythem/Backups';
    }
  }

  /// Resolves all candidate directories where backups may reside (for cross-directory recovery).
  Future<List<Directory>> getCandidateBackupDirectories() async {
    final dirs = <Directory>[];
    if (_overrideDir != null) {
      dirs.add(_overrideDir);
      return dirs;
    }

    if (Platform.isAndroid) {
      dirs.add(Directory('/storage/emulated/0/Documents/Rythem/Backups'));
      dirs.add(Directory('/storage/emulated/0/Download/Rythem/Backups'));
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          dirs.add(Directory('${ext.path}/Rythem/Backups'));
        }
      } catch (_) {}
    }

    // App documents directory (fallback or desktop/sandbox)
    try {
      final docDir = await getApplicationDocumentsDirectory();
      dirs.add(Directory('${docDir.path}/Rythem/Backups'));
    } catch (_) {}

    return dirs;
  }

  /// Resolves the most resilient and user-accessible storage directory available on the host OS.
  /// Prioritizes user-visible public storage (`Documents/Rythem/Backups`) on Android so users
  /// can find it in their file manager and it survives app data clearing.
  Future<Directory> getResilientBackupDirectory() async {
    if (_overrideDir != null) {
      if (!_overrideDir.existsSync()) {
        await _overrideDir.create(recursive: true);
      }
      _migrateExistingBackupsIfNeeded(_overrideDir);
      return _overrideDir;
    }

    if (Platform.isAndroid) {
      // 1. Primary: Public Documents directory (visible in Files / My Files under Documents)
      final publicDoc = Directory('/storage/emulated/0/Documents/Rythem/Backups');
      if (_canWriteTo(publicDoc)) {
        _migrateExistingBackupsIfNeeded(publicDoc);
        return publicDoc;
      }

      // 2. Secondary: Public Download directory (visible in Files under Downloads)
      final publicDownload = Directory('/storage/emulated/0/Download/Rythem/Backups');
      if (_canWriteTo(publicDownload)) {
        _migrateExistingBackupsIfNeeded(publicDownload);
        return publicDownload;
      }

      // 3. Tertiary: External storage directory (visible on PC / file browsers under Android/data)
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final extBackup = Directory('${extDir.path}/Rythem/Backups');
          if (_canWriteTo(extBackup)) {
            _migrateExistingBackupsIfNeeded(extBackup);
            return extBackup;
          }
        }
      } catch (_) {}
    }

    // Default fallback (macOS, Linux, iOS, or Android internal sandbox)
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.current;
    }

    final backupDir = Directory('${baseDir.path}/Rythem/Backups');
    if (!backupDir.existsSync()) {
      await backupDir.create(recursive: true);
    }
    _migrateExistingBackupsIfNeeded(backupDir);
    return backupDir;
  }

  bool _canWriteTo(Directory dir) {
    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final testFile = File('${dir.path}/.write_probe');
      testFile.writeAsStringSync('ok');
      testFile.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _getSafeFallbackDirectory() async {
    Directory baseDir;
    try {
      baseDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      baseDir = Directory.current;
    }
    final dir = Directory('${baseDir.path}/Rythem/Backups');
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return dir;
  }

  Future<Directory> _getSafeFallbackManualDirectory() async {
    final base = await _getSafeFallbackDirectory();
    final dir = Directory(p.join(base.path, manualBackupDirName));
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return dir;
  }

  Future<Directory> _getSafeFallbackSnapshotsDirectory() async {
    final base = await _getSafeFallbackDirectory();
    final dir = Directory(p.join(base.path, snapshotsDirName));
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (_) {}
    }
    return dir;
  }

  void _migrateExistingBackupsIfNeeded(Directory targetDir) {
    try {
      // 1. Move legacy root files in targetDir into manual/ and snapshots/ subdirectories
      _migrateDirectoryFilesToSubfolders(targetDir);

      // 2. Sync from other candidate directories if target subfolders are empty
      getCandidateBackupDirectories().then((dirs) {
        for (final dir in dirs) {
          if (dir.path == targetDir.path) continue;
          if (!dir.existsSync()) continue;
          try {
            _migrateDirectoryFilesToSubfolders(dir, destinationBaseDir: targetDir);
          } catch (_) {}
        }
      }).catchError((_) {});
    } catch (_) {}
  }

  void _migrateDirectoryFilesToSubfolders(Directory sourceDir, {Directory? destinationBaseDir}) {
    if (!sourceDir.existsSync()) return;
    final destBase = destinationBaseDir ?? sourceDir;
    final manualDir = Directory(p.join(destBase.path, manualBackupDirName));
    final snapshotsDir = Directory(p.join(destBase.path, snapshotsDirName));

    final entities = sourceDir.listSync();
    for (final entity in entities) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);

      if (name.startsWith('rythem_autobackup') && name.endsWith('.json')) {
        if (!snapshotsDir.existsSync()) {
          snapshotsDir.createSync(recursive: true);
        }
        final targetFile = File(p.join(snapshotsDir.path, name));
        if (!targetFile.existsSync()) {
          try {
            entity.copySync(targetFile.path);
            if (destinationBaseDir == null) {
              entity.deleteSync();
            }
          } catch (_) {}
        } else if (destinationBaseDir == null) {
          try {
            entity.deleteSync();
          } catch (_) {}
        }
      } else if (name.startsWith('rythem_backup') && name.endsWith('.json')) {
        if (!manualDir.existsSync()) {
          manualDir.createSync(recursive: true);
        }
        final targetFile = File(p.join(manualDir.path, name));
        if (!targetFile.existsSync()) {
          try {
            entity.copySync(targetFile.path);
            if (destinationBaseDir == null) {
              entity.deleteSync();
            }
          } catch (_) {}
        } else if (destinationBaseDir == null) {
          try {
            entity.deleteSync();
          } catch (_) {}
        }
      }
    }
  }

  /// Atomically writes content to [destination] by first writing to a `.tmp` file
  /// and replacing the destination in-place, preventing partial file corruption.
  Future<void> _atomicWriteFile(File destination, String content) async {
    final parent = destination.parent;
    if (!parent.existsSync()) {
      await parent.create(recursive: true);
    }
    final tmpFile = File('${destination.path}.tmp');
    try {
      await tmpFile.writeAsString(content, flush: true);
      if (destination.existsSync()) {
        try {
          await destination.delete();
        } catch (_) {}
      }
      await tmpFile.rename(destination.path);
    } catch (e) {
      // Direct write fallback
      await destination.writeAsString(content, flush: true);
      if (tmpFile.existsSync()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Removes older timestamped manual files (e.g. rythem_backup_2026-*.json)
  /// in the manual directory so that the single in-place master backup file is retained.
  Future<void> _cleanupOldTimestampedBackups(Directory dir) async {
    try {
      if (!dir.existsSync()) return;
      final files = dir.listSync().whereType<File>().toList();
      for (final f in files) {
        final name = p.basename(f.path);
        if (name != masterBackupFileName &&
            RegExp(r'^rythem_backup_\d{4}-\d{2}-\d{2}.*\.json$').hasMatch(name)) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Creates a manual on-demand backup, replacing the existing backup file
  /// in the dedicated `manual/` backup folder.
  Future<BackupSnapshotInfo?> createManualBackup() async {
    try {
      final jsonPayload = await _backupService.exportBackupJson();
      Directory manualDir;
      try {
        manualDir = await getManualBackupDirectory();
      } catch (_) {
        manualDir = await _getSafeFallbackManualDirectory();
      }

      if (!manualDir.existsSync()) {
        try {
          await manualDir.create(recursive: true);
        } catch (_) {
          manualDir = await _getSafeFallbackManualDirectory();
        }
      }

      // 1. Write the master backup file in-place inside the manual directory
      File masterFile = File(p.join(manualDir.path, masterBackupFileName));
      try {
        await _atomicWriteFile(masterFile, jsonPayload);
      } catch (writeErr) {
        debugPrint('AutoBackupManager: Primary manual backup write failed ($writeErr), falling back to safe local storage');
        manualDir = await _getSafeFallbackManualDirectory();
        masterFile = File(p.join(manualDir.path, masterBackupFileName));
        await _atomicWriteFile(masterFile, jsonPayload);
      }

      // 2. Clean up legacy timestamped manual backup files
      await _cleanupOldTimestampedBackups(manualDir);

      // 3. Update last backup date in settings
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      try {
        await _settingsRepo.setSetting(_prefLastAutoBackupDateKey, dateStr);
      } catch (_) {}

      return await parseSnapshotFile(masterFile);
    } catch (e) {
      debugPrint('AutoBackupManager: Manual backup failed: $e');
      rethrow;
    }
  }

  /// Checks if today's backup has already run. If not (or if [force] is true),
  /// executes an atomic export, saves latest + daily snapshot into `snapshots/`, and prunes old files.
  Future<BackupSnapshotInfo?> checkAndPerformDailyBackup({
    bool force = false,
    DateTime? currentDate,
  }) async {
    final now = currentDate ?? DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (!force) {
      final lastDate = await _settingsRepo.getSetting(_prefLastAutoBackupDateKey);
      if (lastDate == todayStr) {
        // Already backed up today
        return await getLatestAutoBackup();
      }
    }

    try {
      final jsonPayload = await _backupService.exportBackupJson();
      Directory snapshotsDir;
      try {
        snapshotsDir = await getSnapshotsDirectory();
      } catch (_) {
        snapshotsDir = await _getSafeFallbackSnapshotsDirectory();
      }

      if (!snapshotsDir.existsSync()) {
        try {
          await snapshotsDir.create(recursive: true);
        } catch (_) {
          snapshotsDir = await _getSafeFallbackSnapshotsDirectory();
        }
      }

      // 1. Write latest pointer backup inside snapshots folder (with safe fallback)
      File latestFile = File(p.join(snapshotsDir.path, latestBackupFileName));
      try {
        await _atomicWriteFile(latestFile, jsonPayload);
      } catch (writeErr) {
        debugPrint('AutoBackupManager: Daily backup primary write failed ($writeErr), falling back');
        snapshotsDir = await _getSafeFallbackSnapshotsDirectory();
        latestFile = File(p.join(snapshotsDir.path, latestBackupFileName));
        await _atomicWriteFile(latestFile, jsonPayload);
      }

      // 2. Write today's rolling snapshot inside snapshots folder
      try {
        final snapshotName = 'rythem_autobackup_$todayStr.json';
        final snapshotFile = File(p.join(snapshotsDir.path, snapshotName));
        await _atomicWriteFile(snapshotFile, jsonPayload);
      } catch (_) {}

      // 3. Mark last backup date in settings
      try {
        await _settingsRepo.setSetting(_prefLastAutoBackupDateKey, todayStr);
      } catch (_) {}

      // 4. Prune snapshots older than maxRetainedDailySnapshots
      await pruneOldSnapshots(keepCount: maxRetainedDailySnapshots);

      return await parseSnapshotFile(latestFile);
    } catch (e) {
      debugPrint('AutoBackupManager: Daily backup failed gracefully: $e');
      return null;
    }
  }

  /// Prunes daily snapshots older than [keepCount] in the `snapshots/` folder, preserving the latest file.
  Future<void> pruneOldSnapshots({int keepCount = maxRetainedDailySnapshots}) async {
    try {
      final dir = await getSnapshotsDirectory();
      if (!dir.existsSync()) return;
      final files = dir.listSync().whereType<File>().toList();

      final dailySnapshots = files.where((f) {
        final name = p.basename(f.path);
        return name.startsWith('rythem_autobackup_') &&
            name.endsWith('.json') &&
            name != latestBackupFileName;
      }).toList();

      // Sort oldest first
      dailySnapshots.sort((a, b) => a.path.compareTo(b.path));

      if (dailySnapshots.length > keepCount) {
        final toDelete = dailySnapshots.take(dailySnapshots.length - keepCount);
        for (final file in toDelete) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('AutoBackupManager: Pruning snapshots error: $e');
    }
  }

  /// Lists all available local auto-backups and exports from manual/, snapshots/, and legacy locations, sorted newest first.
  Future<List<BackupSnapshotInfo>> listAvailableBackups() async {
    final results = <BackupSnapshotInfo>[];
    final seenNames = <String>{};
    try {
      final dirs = await getCandidateBackupDirectories();
      for (final baseDir in dirs) {
        try {
          if (!baseDir.existsSync()) continue;
          final searchDirs = [
            Directory(p.join(baseDir.path, snapshotsDirName)),
            Directory(p.join(baseDir.path, 'snapshot')),
            Directory(p.join(baseDir.path, manualBackupDirName)),
            baseDir, // fallback for unmigrated root files
          ];

          for (final dir in searchDirs) {
            if (!dir.existsSync()) continue;
            final files = dir.listSync().whereType<File>().toList();
            for (final file in files) {
              final name = p.basename(file.path);
              if ((name.startsWith('rythem_autobackup') || name.startsWith('rythem_backup')) &&
                  name.endsWith('.json')) {
                if (seenNames.contains(name)) continue;
                final info = await parseSnapshotFile(file);
                if (info != null) {
                  seenNames.add(name);
                  results.add(info);
                }
              }
            }
          }
        } catch (dirError) {
          debugPrint('AutoBackupManager: Skipping inaccessible candidate backup dir ${baseDir.path}: $dirError');
        }
      }

      // Sort newest first
      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('AutoBackupManager: Error listing backups: $e');
    }
    return results;
  }

  /// Retrieves metadata of the most recent valid auto-backup snapshot.
  Future<BackupSnapshotInfo?> getLatestAutoBackup() async {
    final backups = await listAvailableBackups();
    if (backups.isEmpty) return null;

    // Prefer latestBackupFileName if valid, else newest timestamped snapshot
    final latestNamed = backups.where((b) => b.fileName == latestBackupFileName).firstOrNull;
    return latestNamed ?? backups.first;
  }

  /// Disaster Recovery Detector:
  /// Checks if the active database is completely empty (0 roadmaps), but a valid
  /// local auto-backup file exists with $\ge 1$ roadmaps ready to restore.
  Future<BackupSnapshotInfo?> checkForDisasterRecovery() async {
    try {
      final db = await DatabaseService.instance.database;
      final currentRoadmaps = await db.query('roadmaps');
      if (currentRoadmaps.isNotEmpty) {
        return null; // Database is healthy, not a disaster recovery scenario
      }

      final latestBackup = await getLatestAutoBackup();
      if (latestBackup != null && latestBackup.roadmapsCount > 0) {
        return latestBackup;
      }
    } catch (e) {
      debugPrint('AutoBackupManager: Disaster recovery check error: $e');
    }
    return null;
  }

  /// Restores database state atomically from a snapshot file.
  Future<Map<String, int>> restoreSnapshot(File snapshotFile) async {
    if (!snapshotFile.existsSync()) {
      throw FileSystemException('Snapshot file not found: ${snapshotFile.path}');
    }
    final content = await snapshotFile.readAsString();
    if (content.trim().isEmpty) {
      throw const FormatException('Snapshot file is empty');
    }
    return await _backupService.importBackupJson(content);
  }

  /// Reads and parses the header/stats of a backup JSON file.
  Future<BackupSnapshotInfo?> parseSnapshotFile(File file) async {
    try {
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic> || decoded['app'] != 'rythem') {
        return null;
      }

      final exportedAt = DateTime.tryParse(decoded['exported_at'] as String? ?? '') ??
          file.lastModifiedSync();

      final stats = decoded['stats'] as Map<String, dynamic>? ?? {};
      final tables = decoded['tables'] as Map<String, dynamic>? ?? {};

      final roadmapsCount = stats['roadmaps_count'] as int? ??
          (tables['roadmaps'] as List?)?.length ??
          0;
      final chaptersCount = stats['chapters_count'] as int? ??
          (tables['chapters'] as List?)?.length ??
          0;
      final beatsCount = stats['beats_count'] as int? ??
          (tables['beats'] as List?)?.length ??
          0;
      final logsCount = stats['logs_count'] as int? ??
          (tables['beat_logs'] as List?)?.length ??
          0;

      return BackupSnapshotInfo(
        file: file,
        fileName: p.basename(file.path),
        timestamp: exportedAt,
        roadmapsCount: roadmapsCount,
        chaptersCount: chaptersCount,
        beatsCount: beatsCount,
        logsCount: logsCount,
        sizeBytes: await file.length(),
      );
    } catch (_) {
      return null;
    }
  }
}
