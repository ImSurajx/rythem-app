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

  /// Ground Truth: Mentor's flow is king. Always returned in chronological chapter-first sequence.
  Future<List<BeatEntity>> getBeatsByRoadmapId(String roadmapId) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT b.* FROM ${DatabaseTables.beats} b
      LEFT JOIN ${DatabaseTables.chapters} c ON b.${BeatColumns.chapterId} = c.${ChapterColumns.id}
      WHERE b.${BeatColumns.roadmapId} = ?
      ORDER BY COALESCE(c.${ChapterColumns.sortOrder}, 0) ASC, b.${BeatColumns.sortOrder} ASC, b.${BeatColumns.createdAt} ASC
    ''', [roadmapId]);
    return results.map(BeatEntity.fromMap).toList();
  }

  /// Fetches pending incomplete beats from the front of the queue in chapter-first sequence.
  Future<List<BeatEntity>> getPendingBeats(String roadmapId, {int? limit}) async {
    final db = await _db;
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final results = await db.rawQuery('''
      SELECT b.* FROM ${DatabaseTables.beats} b
      LEFT JOIN ${DatabaseTables.chapters} c ON b.${BeatColumns.chapterId} = c.${ChapterColumns.id}
      WHERE b.${BeatColumns.roadmapId} = ? AND b.${BeatColumns.isCompleted} = 0
      ORDER BY COALESCE(c.${ChapterColumns.sortOrder}, 0) ASC, b.${BeatColumns.sortOrder} ASC, b.${BeatColumns.createdAt} ASC
      $limitClause
    ''', [roadmapId]);
    return results.map(BeatEntity.fromMap).toList();
  }

  /// Toggles a beat's completion status and logs activity into [beat_logs].
  /// Emits [DatabaseEventType.beatToggled] to trigger instantaneous reactive loop.
  Future<BeatEntity?> toggleBeatCompletion(
    String beatId, {
    required bool isCompleted,
    DateTime? completedAt,
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
      final now = completedAt ?? DateTime.now();
      final todayDateStr = now.toIso8601String().substring(0, 10); // YYYY-MM-DD

      final updatedValues = {
        BeatColumns.isCompleted: isCompleted ? 1 : 0,
        BeatColumns.completedParts: isCompleted ? current.totalParts : 0,
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
        completedParts: isCompleted ? current.totalParts : 0,
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

  /// Updates the total number of parts for a beat (enables "Complete in Parts").
  Future<BeatEntity?> updateBeatParts(
    String beatId,
    int totalParts,
  ) async {
    final db = await _db;
    final clampedTotal = totalParts.clamp(1, 20);
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
      final newCompletedParts = current.completedParts.clamp(0, clampedTotal);
      final isNowCompleted = newCompletedParts >= clampedTotal;
      final now = DateTime.now();

      final updatedValues = {
        BeatColumns.totalParts: clampedTotal,
        BeatColumns.completedParts: newCompletedParts,
        BeatColumns.isCompleted: isNowCompleted ? 1 : 0,
        BeatColumns.completedAt: isNowCompleted
            ? (current.completedAt?.toIso8601String() ?? now.toIso8601String())
            : null,
        BeatColumns.updatedAt: now.toIso8601String(),
      };

      await txn.update(
        DatabaseTables.beats,
        updatedValues,
        where: '${BeatColumns.id} = ?',
        whereArgs: [beatId],
      );

      updatedBeat = current.copyWith(
        totalParts: clampedTotal,
        completedParts: newCompletedParts,
        isCompleted: isNowCompleted,
        completedAt: isNowCompleted ? (current.completedAt ?? now) : null,
        clearCompletedAt: !isNowCompleted,
        updatedAt: now,
      );
    });

    if (updatedBeat != null) {
      _eventBus.emit(DatabaseEvent(
        type: DatabaseEventType.beatUpdated,
        entityId: beatId,
        roadmapId: updatedBeat!.roadmapId,
      ));
    }

    return updatedBeat;
  }

  /// Increments the completed parts count by 1 and registers study activity in beat_logs for today's streak.
  Future<BeatEntity?> incrementBeatPart(
    String beatId, {
    DateTime? completedAt,
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
      final newCompletedParts = (current.completedParts + 1).clamp(0, current.totalParts);
      final isNowCompleted = newCompletedParts >= current.totalParts;
      final now = completedAt ?? DateTime.now();
      final todayDateStr = now.toIso8601String().substring(0, 10);

      final updatedValues = {
        BeatColumns.completedParts: newCompletedParts,
        BeatColumns.isCompleted: isNowCompleted ? 1 : 0,
        BeatColumns.completedAt: isNowCompleted ? now.toIso8601String() : null,
        BeatColumns.updatedAt: now.toIso8601String(),
      };

      await txn.update(
        DatabaseTables.beats,
        updatedValues,
        where: '${BeatColumns.id} = ?',
        whereArgs: [beatId],
      );

      // Log study activity into beat_logs to preserve and advance user's streak!
      await txn.insert(
        DatabaseTables.beatLogs,
        {
          BeatLogColumns.id: '${beatId}_part_${newCompletedParts}_${now.millisecondsSinceEpoch}',
          BeatLogColumns.beatId: beatId,
          BeatLogColumns.roadmapId: current.roadmapId,
          BeatLogColumns.completedDate: todayDateStr,
          BeatLogColumns.createdAt: now.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      updatedBeat = current.copyWith(
        completedParts: newCompletedParts,
        isCompleted: isNowCompleted,
        completedAt: isNowCompleted ? now : null,
        clearCompletedAt: !isNowCompleted,
        updatedAt: now,
      );
    });

    if (updatedBeat != null) {
      _eventBus.emit(DatabaseEvent(
        type: DatabaseEventType.beatToggled,
        entityId: beatId,
        roadmapId: updatedBeat!.roadmapId,
        metadata: {
          'isCompleted': updatedBeat!.isCompleted,
          'completedParts': updatedBeat!.completedParts,
          'totalParts': updatedBeat!.totalParts,
        },
      ));
    }

    return updatedBeat;
  }

  /// Decrements the completed parts count by 1.
  Future<BeatEntity?> decrementBeatPart(String beatId) async {
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
      if (current.completedParts <= 0) {
        updatedBeat = current;
        return;
      }

      final prevPartIndex = current.completedParts;
      final newCompletedParts = (current.completedParts - 1).clamp(0, current.totalParts);
      final now = DateTime.now();

      final updatedValues = {
        BeatColumns.completedParts: newCompletedParts,
        BeatColumns.isCompleted: 0,
        BeatColumns.completedAt: null,
        BeatColumns.updatedAt: now.toIso8601String(),
      };

      await txn.update(
        DatabaseTables.beats,
        updatedValues,
        where: '${BeatColumns.id} = ?',
        whereArgs: [beatId],
      );

      // Remove the log for this part
      await txn.delete(
        DatabaseTables.beatLogs,
        where: '${BeatLogColumns.id} LIKE ?',
        whereArgs: ['${beatId}_part_${prevPartIndex}_%'],
      );

      updatedBeat = current.copyWith(
        completedParts: newCompletedParts,
        isCompleted: false,
        clearCompletedAt: true,
        updatedAt: now,
      );
    });

    if (updatedBeat != null) {
      _eventBus.emit(DatabaseEvent(
        type: DatabaseEventType.beatToggled,
        entityId: beatId,
        roadmapId: updatedBeat!.roadmapId,
        metadata: {
          'isCompleted': false,
          'completedParts': updatedBeat!.completedParts,
          'totalParts': updatedBeat!.totalParts,
        },
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

  Future<void> updateBeat(BeatEntity beat) async {
    final db = await _db;
    await db.update(
      DatabaseTables.beats,
      beat.toMap(),
      where: '${BeatColumns.id} = ?',
      whereArgs: [beat.id],
    );
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.beatToggled,
      entityId: beat.id,
      roadmapId: beat.roadmapId,
    ));
  }

  Future<void> updateBeatEffortWeight(String beatId, double newWeight) async {
    final db = await _db;
    await db.update(
      DatabaseTables.beats,
      {
        BeatColumns.effortWeight: newWeight,
        BeatColumns.updatedAt: DateTime.now().toIso8601String(),
      },
      where: '${BeatColumns.id} = ?',
      whereArgs: [beatId],
    );
  }

  Future<void> deleteBeatsByRoadmapId(String roadmapId) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.beats,
      where: '${BeatColumns.roadmapId} = ?',
      whereArgs: [roadmapId],
    );
  }

  Future<void> deleteBeatsByChapterId(String chapterId) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.beats,
      where: '${BeatColumns.chapterId} = ?',
      whereArgs: [chapterId],
    );
  }

  /// Computes the next sequential sortOrder for a new beat in [chapterId],
  /// guaranteeing placement strictly at the bottom of the chapter.
  Future<int> getNextSortOrderForChapter(String chapterId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT MAX(${BeatColumns.sortOrder}) as max_sort FROM ${DatabaseTables.beats} WHERE ${BeatColumns.chapterId} = ?',
      [chapterId],
    );
    final maxSort = result.first['max_sort'] as int?;
    return (maxSort ?? -1) + 1;
  }

  Future<void> deleteBeat(String id) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.beats,
      where: '${BeatColumns.id} = ?',
      whereArgs: [id],
    );
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.beatDeleted,
      entityId: id,
    ));
  }
}
