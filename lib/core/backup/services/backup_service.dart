import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../database/database_service.dart';
import '../../database/database_event_bus.dart';
import '../../database/tables.dart';

/// Service responsible for complete local database backup export and restoration.
/// 
/// Allows users to safely backup their entire study progress, streaks,
/// custom tracks, chapters, beats, and settings before clearing data.
class BackupService {
  final DatabaseService _dbService;
  final DatabaseEventBus _eventBus;

  BackupService({
    DatabaseService? dbService,
    DatabaseEventBus? eventBus,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _eventBus = eventBus ?? DatabaseEventBus.instance;

  /// Generates the complete backup payload as a pretty-printed JSON string.
  Future<String> exportBackupJson() async {
    final db = await _dbService.database;

    final roadmaps = await db.query(DatabaseTables.roadmaps);
    final chapters = await db.query(DatabaseTables.chapters);
    final beats = await db.query(DatabaseTables.beats);
    final beatLogs = await db.query(DatabaseTables.beatLogs);
    final appSettings = await db.query(DatabaseTables.appSettings);

    final payload = {
      'app': 'rythem',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': {
        DatabaseTables.roadmaps: roadmaps,
        DatabaseTables.chapters: chapters,
        DatabaseTables.beats: beats,
        DatabaseTables.beatLogs: beatLogs,
        DatabaseTables.appSettings: appSettings,
      },
      'stats': {
        'roadmaps_count': roadmaps.length,
        'chapters_count': chapters.length,
        'beats_count': beats.length,
        'logs_count': beatLogs.length,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Exports backup JSON to a file chosen by the user via native file picker dialog.
  /// If the user cancels the picker, returns null.
  Future<File?> exportToFile({String? customPath}) async {
    final jsonString = await exportBackupJson();
    final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final fileName = 'rythem_backup_$dateStr.json';

    if (customPath != null && customPath.isNotEmpty) {
      final target = customPath.endsWith('.json') ? customPath : '$customPath.json';
      final customFile = File(target);
      final parent = customFile.parent;
      if (!parent.existsSync()) {
        await parent.create(recursive: true);
      }
      await customFile.writeAsString(jsonString);
      return customFile;
    }

    // Prepare a safe fallback file in the app documents directory
    File? safeLocalFile;
    try {
      final directory = await getApplicationDocumentsDirectory();
      safeLocalFile = File('${directory.path}/$fileName');
      await safeLocalFile.writeAsString(jsonString);
    } catch (_) {
      // In testing environments or headless runners
    }

    try {
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      final pickedResult = await FilePicker.saveFile(
        dialogTitle: 'Select location to save backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (pickedResult == null) {
        // User explicitly cancelled the picker dialog
        return null;
      }

      // On Android SAF (Storage Access Framework), pickedResult has a 'content' scheme.
      // The bytes are already written directly to storage by the native platform plugin.
      // Attempting to write to a content:// path via dart:io File causes a Read-Only File System error.
      if (pickedResult.scheme == 'content') {
        return safeLocalFile ?? File(pickedResult.path);
      }

      // Regular filesystem path (Desktop / iOS / direct POSIX paths)
      String rawPath;
      try {
        rawPath = pickedResult.toFilePath();
      } catch (_) {
        rawPath = pickedResult.path;
      }
      final destPath = rawPath.endsWith('.json') ? rawPath : '$rawPath.json';
      final destFile = File(destPath);
      try {
        final parent = destFile.parent;
        if (!parent.existsSync()) {
          await parent.create(recursive: true);
        }
        if (!destFile.existsSync() || (await destFile.length()) == 0) {
          await destFile.writeAsString(jsonString);
        }
        return destFile;
      } catch (_) {
        return safeLocalFile ?? destFile;
      }
    } catch (e) {
      if (safeLocalFile != null && safeLocalFile.existsSync()) {
        return safeLocalFile;
      }
      rethrow;
    }
  }

  /// Validates and restores the entire database from a JSON backup string.
  /// 
  /// Runs inside an atomic SQLite transaction to prevent partial state corruption.
  Future<Map<String, int>> importBackupJson(String jsonString) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw const FormatException('Invalid JSON backup file format');
    }

    if (decoded is! Map<String, dynamic> || decoded['app'] != 'rythem') {
      throw const FormatException('File is not a valid Rythem backup payload');
    }

    final tables = decoded['tables'] as Map<String, dynamic>?;
    if (tables == null) {
      throw const FormatException('Backup contains no tables data');
    }

    final roadmaps = (tables[DatabaseTables.roadmaps] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final chapters = (tables[DatabaseTables.chapters] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final beats = (tables[DatabaseTables.beats] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final beatLogs = (tables[DatabaseTables.beatLogs] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final appSettings = (tables[DatabaseTables.appSettings] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final db = await _dbService.database;

    await db.transaction((txn) async {
      // 1. Wipe existing tables in child-to-parent order to respect foreign keys
      await txn.delete(DatabaseTables.beatLogs);
      await txn.delete(DatabaseTables.beats);
      await txn.delete(DatabaseTables.chapters);
      await txn.delete(DatabaseTables.roadmaps);
      await txn.delete(DatabaseTables.appSettings);

      // 2. Batch insert roadmaps
      for (final row in roadmaps) {
        await txn.insert(DatabaseTables.roadmaps, row);
      }

      // 3. Batch insert chapters
      for (final row in chapters) {
        await txn.insert(DatabaseTables.chapters, row);
      }

      // 4. Batch insert beats
      for (final row in beats) {
        await txn.insert(DatabaseTables.beats, row);
      }

      // 5. Batch insert beat logs (streak & history charts)
      for (final row in beatLogs) {
        await txn.insert(DatabaseTables.beatLogs, row);
      }

      // 6. Batch insert app settings
      for (final row in appSettings) {
        await txn.insert(DatabaseTables.appSettings, row);
      }
    });

    // Notify the entire app that the database was fully restored
    _eventBus.emit(const DatabaseEvent(
      type: DatabaseEventType.roadmapUpdated,
      roadmapId: 'all',
    ));

    return {
      'roadmaps': roadmaps.length,
      'chapters': chapters.length,
      'beats': beats.length,
      'beatLogs': beatLogs.length,
    };
  }

  /// Opens file picker, reads chosen backup JSON file, and restores the database.
  Future<Map<String, int>?> pickAndRestoreBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (file == null) {
      return null;
    }

    String? content;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        content = utf8.decode(bytes);
      }
    } catch (_) {}

    if ((content == null || content.isEmpty) && file.path != null) {
      content = await File(file.path!).readAsString();
    }

    if (content == null || content.isEmpty) {
      throw const FormatException('Could not read chosen backup file');
    }

    return await importBackupJson(content);
  }
}
