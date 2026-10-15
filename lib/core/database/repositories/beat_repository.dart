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

  Future<void> deleteBeat(String beatId) async {
    final db = await _db;
    final beat = await getBeatById(beatId);
    if (beat == null) return;
    await db.delete(
      DatabaseTables.beats,
      where: '${BeatColumns.id} = ?',
      whereArgs: [beatId],
    );
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.beatToggled,
      entityId: beatId,
      roadmapId: beat.roadmapId,
    ));
  }

  /// Inserts a user-created custom study beat directly into the tracker.
  /// If completed beats exist in the roadmap, it is inserted immediately after
  /// the last completed beat in that chapter (shifting subsequent beats).
  /// If no beats are completed yet, it is inserted at the start of the first chapter.
  /// If no chapters exist, a default chapter is created.
  Future<BeatEntity> insertCustomBeatAfterLastCompleted({
    required String roadmapId,
    required String title,
    required double effortWeight,
    String? sourceUrl,
    String category = 'Revision',
    bool isCompleted = false,
  }) async {
    final db = await _db;
    return await db.transaction((txn) async {
      // 1. Get all beats for roadmap in sequence
      final beatRows = await txn.rawQuery('''
        SELECT b.* FROM ${DatabaseTables.beats} b
        LEFT JOIN ${DatabaseTables.chapters} c ON b.${BeatColumns.chapterId} = c.${ChapterColumns.id}
        WHERE b.${BeatColumns.roadmapId} = ?
        ORDER BY COALESCE(c.${ChapterColumns.sortOrder}, 0) ASC, b.${BeatColumns.sortOrder} ASC, b.${BeatColumns.createdAt} ASC
      ''', [roadmapId]);
      final existingBeats = beatRows.map(BeatEntity.fromMap).toList();

      final completedBeats = existingBeats.where((b) => b.isCompleted).toList();
      String targetChapterId;
      int targetSortOrder;

      if (completedBeats.isNotEmpty) {
        final lastCompleted = completedBeats.last;
        targetChapterId = lastCompleted.chapterId;
        targetSortOrder = lastCompleted.sortOrder + 1;

        // Shift subsequent beats in this chapter
        await txn.rawUpdate('''
          UPDATE ${DatabaseTables.beats}
          SET ${BeatColumns.sortOrder} = ${BeatColumns.sortOrder} + 1
          WHERE ${BeatColumns.chapterId} = ? AND ${BeatColumns.sortOrder} >= ?
        ''', [targetChapterId, targetSortOrder]);
      } else {
        // Find first chapter
        final chapterRows = await txn.query(
          DatabaseTables.chapters,
          where: '${ChapterColumns.roadmapId} = ?',
          whereArgs: [roadmapId],
          orderBy: '${ChapterColumns.sortOrder} ASC',
          limit: 1,
        );

        if (chapterRows.isNotEmpty) {
          targetChapterId = chapterRows.first[ChapterColumns.id] as String;
          targetSortOrder = 0;
          await txn.rawUpdate('''
            UPDATE ${DatabaseTables.beats}
            SET ${BeatColumns.sortOrder} = ${BeatColumns.sortOrder} + 1
            WHERE ${BeatColumns.chapterId} = ? AND ${BeatColumns.sortOrder} >= 0
          ''', [targetChapterId]);
        } else {
          // Create default chapter
          final now = DateTime.now();
          targetChapterId = 'ch_default_${now.millisecondsSinceEpoch}';
          targetSortOrder = 0;
          await txn.insert(
            DatabaseTables.chapters,
            {
              ChapterColumns.id: targetChapterId,
              ChapterColumns.roadmapId: roadmapId,
              ChapterColumns.title: 'General',
              ChapterColumns.sortOrder: 0,
              ChapterColumns.createdAt: now.toIso8601String(),
              ChapterColumns.updatedAt: now.toIso8601String(),
            },
          );
        }
      }

      final now = DateTime.now();
      final newBeatId = 'beat_custom_${now.millisecondsSinceEpoch}';
      final newBeat = BeatEntity(
        id: newBeatId,
        chapterId: targetChapterId,
        roadmapId: roadmapId,
        title: title.trim(),
        sourceUrl: sourceUrl?.trim().isNotEmpty == true ? sourceUrl!.trim() : null,
        effortWeight: effortWeight,
        sortOrder: targetSortOrder,
        isCompleted: isCompleted,
        completedAt: isCompleted ? now : null,
        isMentorExtra: false,
        syllabusTopicId: 'custom:${category.trim().isEmpty ? 'Revision' : category.trim()}',
        createdAt: now,
        updatedAt: now,
      );

      await txn.insert(
        DatabaseTables.beats,
        newBeat.toMap(),
      );

      if (isCompleted) {
        final todayStr = now.toIso8601String().substring(0, 10);
        await txn.insert(
          DatabaseTables.beatLogs,
          {
            BeatLogColumns.id: '${newBeatId}_${now.millisecondsSinceEpoch}',
            BeatLogColumns.beatId: newBeatId,
            BeatLogColumns.roadmapId: roadmapId,
            BeatLogColumns.completedDate: todayStr,
            BeatLogColumns.createdAt: now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      return newBeat;
    }).then((created) {
      _eventBus.emit(DatabaseEvent(
        type: DatabaseEventType.beatCreated,
        entityId: created.id,
        roadmapId: roadmapId,
      ));
      return created;
    });
  }
}
