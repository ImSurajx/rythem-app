import 'package:sqflite/sqflite.dart';
import '../database_event_bus.dart';
import '../database_service.dart';
import '../models/roadmap_entity.dart';
import '../tables.dart';

class RoadmapProgress {
  final int completedBeats;
  final int totalBeats;
  final double completedEffort;
  final double totalEffort;

  const RoadmapProgress({
    required this.completedBeats,
    required this.totalBeats,
    required this.completedEffort,
    required this.totalEffort,
  });

  double get beatRatio => totalBeats > 0 ? completedBeats / totalBeats : 0.0;
  double get effortRatio => totalEffort > 0 ? completedEffort / totalEffort : 0.0;
}

class RoadmapRepository {
  final DatabaseService _dbService;
  final DatabaseEventBus _eventBus;

  RoadmapRepository({
    DatabaseService? dbService,
    DatabaseEventBus? eventBus,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _eventBus = eventBus ?? DatabaseEventBus.instance;

  Future<Database> get _db => _dbService.database;

  Future<void> createRoadmap(RoadmapEntity roadmap) async {
    final db = await _db;
    await db.insert(
      DatabaseTables.roadmaps,
      roadmap.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.roadmapCreated,
      entityId: roadmap.id,
      roadmapId: roadmap.id,
    ));
  }

  Future<void> updateRoadmap(RoadmapEntity roadmap) async {
    final db = await _db;
    await db.update(
      DatabaseTables.roadmaps,
      roadmap.toMap(),
      where: '${RoadmapColumns.id} = ?',
      whereArgs: [roadmap.id],
    );
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.roadmapUpdated,
      entityId: roadmap.id,
      roadmapId: roadmap.id,
    ));
  }

  Future<void> updateRoadmapTargetDate(String id, DateTime newTarget) async {
    final db = await _db;
    await db.update(
      DatabaseTables.roadmaps,
      {
        RoadmapColumns.targetCompletionDate: newTarget.toIso8601String(),
        RoadmapColumns.updatedAt: DateTime.now().toIso8601String(),
      },
      where: '${RoadmapColumns.id} = ?',
      whereArgs: [id],
    );
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.roadmapUpdated,
      entityId: id,
      roadmapId: id,
    ));
  }

  Future<RoadmapEntity?> getRoadmapById(String id) async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.roadmaps,
      where: '${RoadmapColumns.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return RoadmapEntity.fromMap(results.first);
  }

  Future<List<RoadmapEntity>> getAllRoadmaps() async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.roadmaps,
      orderBy: '${RoadmapColumns.createdAt} DESC',
    );
    return results.map(RoadmapEntity.fromMap).toList();
  }

  Future<List<RoadmapEntity>> getActiveRoadmaps() async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.roadmaps,
      where: '${RoadmapColumns.status} = ?',
      whereArgs: ['active'],
      orderBy: '${RoadmapColumns.isPrimary} DESC, ${RoadmapColumns.createdAt} DESC',
    );
    return results.map(RoadmapEntity.fromMap).toList();
  }

  Future<RoadmapEntity?> getPrimaryRoadmap() async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.roadmaps,
      where: '${RoadmapColumns.status} = ? AND ${RoadmapColumns.isPrimary} = 1',
      whereArgs: ['active'],
      limit: 1,
    );
    if (results.isEmpty) {
      final active = await getActiveRoadmaps();
      return active.isNotEmpty ? active.first : null;
    }
    return RoadmapEntity.fromMap(results.first);
  }

  Future<void> setPrimaryRoadmap(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      // Clear primary flag on all
      await txn.update(
        DatabaseTables.roadmaps,
        {RoadmapColumns.isPrimary: 0},
      );
      // Set primary flag on chosen id
      await txn.update(
        DatabaseTables.roadmaps,
        {RoadmapColumns.isPrimary: 1},
        where: '${RoadmapColumns.id} = ?',
        whereArgs: [id],
      );
    });
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.roadmapUpdated,
      entityId: id,
      roadmapId: id,
    ));
  }

  Future<void> deleteRoadmap(String id) async {
    final db = await _db;
    final existingTables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    )).map((r) => r['name'] as String).toSet();

    final batch = db.batch();
    if (existingTables.contains(DatabaseTables.dailyMissions)) {
      batch.delete(
        DatabaseTables.dailyMissions,
        where: '${DailyMissionColumns.roadmapId} = ?',
        whereArgs: [id],
      );
    }
    if (existingTables.contains(DatabaseTables.beatLogs)) {
      batch.delete(
        DatabaseTables.beatLogs,
        where: '${BeatLogColumns.roadmapId} = ?',
        whereArgs: [id],
      );
    }
    if (existingTables.contains(DatabaseTables.beats)) {
      batch.delete(
        DatabaseTables.beats,
        where: '${BeatColumns.roadmapId} = ?',
        whereArgs: [id],
      );
    }
    if (existingTables.contains(DatabaseTables.chapters)) {
      batch.delete(
        DatabaseTables.chapters,
        where: '${ChapterColumns.roadmapId} = ?',
        whereArgs: [id],
      );
    }
    if (existingTables.contains(DatabaseTables.roadmaps)) {
      batch.delete(
        DatabaseTables.roadmaps,
        where: '${RoadmapColumns.id} = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.roadmapDeleted,
      entityId: id,
      roadmapId: id,
    ));
  }

  Future<RoadmapProgress> getRoadmapProgress(String roadmapId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_beats,
        SUM(CASE WHEN ${BeatColumns.isCompleted} = 1 THEN 1 ELSE 0 END) as completed_beats,
        TOTAL(${BeatColumns.effortWeight}) as total_effort,
        TOTAL(CASE WHEN ${BeatColumns.isCompleted} = 1 THEN ${BeatColumns.effortWeight} ELSE 0 END) as completed_effort
      FROM ${DatabaseTables.beats}
      WHERE ${BeatColumns.roadmapId} = ?
    ''', [roadmapId]);

    if (results.isEmpty) {
      return const RoadmapProgress(
        completedBeats: 0,
        totalBeats: 0,
        completedEffort: 0.0,
        totalEffort: 0.0,
      );
    }

    final row = results.first;
    return RoadmapProgress(
      completedBeats: (row['completed_beats'] as num?)?.toInt() ?? 0,
      totalBeats: (row['total_beats'] as num?)?.toInt() ?? 0,
      completedEffort: (row['completed_effort'] as num?)?.toDouble() ?? 0.0,
      totalEffort: (row['total_effort'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
