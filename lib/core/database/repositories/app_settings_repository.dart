import 'dart:convert';
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

  static const List<String> defaultStarterCategories = [
    'Revision',
    'Practice',
    'Reading',
    'Project',
    'General',
  ];

  static List<String>? _cachedCategories;

  static List<String> get currentCategories =>
      _cachedCategories != null ? List.unmodifiable(_cachedCategories!) : defaultStarterCategories;

  Future<List<String>> getCustomTaskCategories() async {
    if (_cachedCategories != null) {
      return List.from(_cachedCategories!);
    }
    final raw = await getSetting('custom_task_categories');
    if (raw == null || raw.trim().isEmpty) {
      _cachedCategories = List.from(defaultStarterCategories);
      return List.from(_cachedCategories!);
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      _cachedCategories = list.isNotEmpty ? list : List.from(defaultStarterCategories);
      return List.from(_cachedCategories!);
    } catch (_) {
      _cachedCategories = List.from(defaultStarterCategories);
      return List.from(_cachedCategories!);
    }
  }

  Future<void> saveCustomTaskCategory(String category) async {
    final clean = category.trim();
    if (clean.isEmpty) return;
    _cachedCategories ??= List.from(defaultStarterCategories);
    if (!_cachedCategories!.any((c) => c.toLowerCase() == clean.toLowerCase())) {
      _cachedCategories!.add(clean);
      try {
        await setSetting('custom_task_categories', jsonEncode(_cachedCategories));
      } catch (_) {}
    }
  }
}

