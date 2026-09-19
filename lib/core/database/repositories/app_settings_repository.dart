import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../tables.dart';

class AppSettingsRepository {
  final DatabaseService _dbService;

  AppSettingsRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  Future<String?> getSetting(String key) async {
    final db = await _dbService.database;
    final results = await db.query(
      DatabaseTables.appSettings,
      columns: [AppSettingsColumns.value],
      where: '${AppSettingsColumns.key} = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first[AppSettingsColumns.value] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _dbService.database;
    final now = DateTime.now().toIso8601String();

    await db.insert(
      DatabaseTables.appSettings,
      {
        AppSettingsColumns.key: key,
        AppSettingsColumns.value: value,
        AppSettingsColumns.updatedAt: now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeSetting(String key) async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseTables.appSettings,
      where: '${AppSettingsColumns.key} = ?',
      whereArgs: [key],
    );
  }

  Future<void> removeSettingsStartingWith(String prefix) async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseTables.appSettings,
      where: '${AppSettingsColumns.key} LIKE ?',
      whereArgs: ['$prefix%'],
    );
  }
}

