import 'package:sqflite/sqflite.dart';
import '../database_event_bus.dart';
import '../database_service.dart';
import '../models/beat_entity.dart';
import '../tables.dart';

class BeatRepository {
  final DatabaseService _dbService;
  final DatabaseEventBus _eventBus;

  BeatRepository({
    DatabaseService? dbService,
    DatabaseEventBus? eventBus,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _eventBus = eventBus ?? DatabaseEventBus.instance;

  Future<Database> get _db => _dbService.database;

  Future<void> createBeat(BeatEntity beat) async {
    final db = await _db;
    await db.insert(
      DatabaseTables.beats,
      beat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.beatCreated,
      entityId: beat.id,
      roadmapId: beat.roadmapId,
    ));
  }

  Future<void> createBeatsBatch(List<BeatEntity> beats) async {
    if (beats.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final beat in beats) {
      batch.insert(
        DatabaseTables.beats,
        beat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.beatCreated,
      roadmapId: beats.first.roadmapId,
    ));
  }

  Future<BeatEntity?> getBeatById(String id) async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.beats,
      where: '${BeatColumns.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return BeatEntity.fromMap(results.first);
  }

  Future<List<BeatEntity>> getBeatsByChapterId(String chapterId) async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.beats,
      where: '${BeatColumns.chapterId} = ?',
      whereArgs: [chapterId],
      orderBy: '${BeatColumns.sortOrder} ASC, ${BeatColumns.createdAt} ASC',
    );
    return results.map(BeatEntity.fromMap).toList();
  }

  /// Ground Truth: Mentor's flow is king. Always returned in chronological sort order.
  Future<List<BeatEntity>> getBeatsByRoadmapId(String roadmapId) async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.beats,
      where: '${BeatColumns.roadmapId} = ?',
      whereArgs: [roadmapId],
      orderBy: '${BeatColumns.sortOrder} ASC, ${BeatColumns.createdAt} ASC',
    );
    return results.map(BeatEntity.fromMap).toList();
  }

  /// Fetches pending incomplete beats from the front of the queue in mentor order.
  Future<List<BeatEntity>> getPendingBeats(String roadmapId, {int? limit}) async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.beats,
      where: '${BeatColumns.roadmapId} = ? AND ${BeatColumns.isCompleted} = 0',
      whereArgs: [roadmapId],
      orderBy: '${BeatColumns.sortOrder} ASC, ${BeatColumns.createdAt} ASC',
      limit: limit,
    );
    return results.map(BeatEntity.fromMap).toList();
  }

  /// Toggles a beat's completion status and logs activity into [beat_logs].
  /// Emits [DatabaseEventType.beatToggled] to trigger instantaneous reactive loop.
  Future<BeatEntity?> toggleBeatCompletion(
    String beatId, {
    required bool isCompleted,
  }) async {
    final db = await _db;
    BeatEntity? updatedBeat;

    await db.transaction((txn) async {
      final beatQuery = await txn.query(
        DatabaseTables.beats,
        where: '${BeatColumns.id} = ?',
        whereArgs: [beatId],
        limit: 1,
      );
      if (beatQuery.isEmpty) return;

      final current = BeatEntity.fromMap(beatQuery.first);
      final now = DateTime.now();
      final todayDateStr = now.toIso8601String().substring(0, 10); // YYYY-MM-DD

      final updatedValues = {
        BeatColumns.isCompleted: isCompleted ? 1 : 0,
        BeatColumns.completedAt: isCompleted ? now.toIso8601String() : null,
        BeatColumns.updatedAt: now.toIso8601String(),
      };

      await txn.update(
        DatabaseTables.beats,
        updatedValues,
        where: '${BeatColumns.id} = ?',
        whereArgs: [beatId],
      );

      // Manage beat_logs entry
      if (isCompleted) {
        await txn.insert(
          DatabaseTables.beatLogs,
          {
            BeatLogColumns.id: '${beatId}_${now.millisecondsSinceEpoch}',
            BeatLogColumns.beatId: beatId,
            BeatLogColumns.roadmapId: current.roadmapId,
            BeatLogColumns.completedDate: todayDateStr,
            BeatLogColumns.createdAt: now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await txn.delete(
          DatabaseTables.beatLogs,
          where: '${BeatLogColumns.beatId} = ?',
          whereArgs: [beatId],
        );
      }

      updatedBeat = current.copyWith(
        isCompleted: isCompleted,
        completedAt: isCompleted ? now : null,
        clearCompletedAt: !isCompleted,
        updatedAt: now,
      );
    });

    if (updatedBeat != null) {
      _eventBus.emit(DatabaseEvent(
        type: DatabaseEventType.beatToggled,
        entityId: beatId,
        roadmapId: updatedBeat!.roadmapId,
        metadata: {'isCompleted': isCompleted},
      ));
    }

    return updatedBeat;
  }

  /// Computes remaining effort weight across incomplete beats.
  Future<double> getRemainingEffort(String roadmapId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT TOTAL(${BeatColumns.effortWeight}) as remaining_effort
      FROM ${DatabaseTables.beats}
      WHERE ${BeatColumns.roadmapId} = ? AND ${BeatColumns.isCompleted} = 0
    ''', [roadmapId]);

    if (results.isEmpty) return 0.0;
    return (results.first['remaining_effort'] as num?)?.toDouble() ?? 0.0;
  }
}
