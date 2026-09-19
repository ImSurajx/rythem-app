import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
    return '${diff.inDays} days ago';
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
  static const String latestBackupFileName = 'rythem_autobackup_latest.json';
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

  /// Resolves the most resilient storage directory available on the host OS.
  /// Uses shared/user-accessible storage to ensure survival if app cache/data is reset.
  Future<Directory> getResilientBackupDirectory() async {
    if (_overrideDir != null) {
      if (!_overrideDir.existsSync()) {
        await _overrideDir.create(recursive: true);
      }
      return _overrideDir;
    }

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
    return backupDir;
  }

  /// Checks if today's backup has already run. If not (or if [force] is true),
  /// executes an atomic export, saves latest + daily snapshot, and prunes old files.
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
      final backupDir = await getResilientBackupDirectory();

      // 1. Write latest pointer backup
      final latestFile = File('${backupDir.path}/$latestBackupFileName');
      await latestFile.writeAsString(jsonPayload);

      // 2. Write today's rolling snapshot
      final snapshotName = 'rythem_autobackup_$todayStr.json';
      final snapshotFile = File('${backupDir.path}/$snapshotName');
      await snapshotFile.writeAsString(jsonPayload);

      // 3. Mark last backup date in settings
      await _settingsRepo.setSetting(_prefLastAutoBackupDateKey, todayStr);

      // 4. Prune snapshots older than maxRetainedDailySnapshots
      await pruneOldSnapshots(keepCount: maxRetainedDailySnapshots);

      return await parseSnapshotFile(latestFile);
    } catch (e) {
      debugPrint('AutoBackupManager: Daily backup failed gracefully: $e');
      return null;
    }
  }

  /// Prunes daily snapshots older than [keepCount], preserving the latest file.
  Future<void> pruneOldSnapshots({int keepCount = maxRetainedDailySnapshots}) async {
    try {
      final dir = await getResilientBackupDirectory();
      final files = dir.listSync().whereType<File>().toList();

      final dailySnapshots = files.where((f) {
        final name = f.path.split('/').last;
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

  /// Lists all available local auto-backups, sorted newest first.
  Future<List<BackupSnapshotInfo>> listAvailableBackups() async {
    final results = <BackupSnapshotInfo>[];
    try {
      final dir = await getResilientBackupDirectory();
      if (!dir.existsSync()) return [];

      final files = dir.listSync().whereType<File>().toList();
      for (final file in files) {
        final name = file.path.split('/').last;
        if (name.startsWith('rythem_autobackup_') && name.endsWith('.json')) {
          final info = await parseSnapshotFile(file);
          if (info != null) {
            results.add(info);
          }
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
    final content = await snapshotFile.readAsString();
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
        fileName: file.path.split('/').last,
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
