import 'package:sqflite/sqflite.dart';
import '../database_event_bus.dart';
import '../database_service.dart';
import '../models/beat_entity.dart';
import '../tables.dart';

class DailyMissionRepository {
  final DatabaseService _dbService;
  final DatabaseEventBus _eventBus;

  DailyMissionRepository({
    DatabaseService? dbService,
    DatabaseEventBus? eventBus,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _eventBus = eventBus ?? DatabaseEventBus.instance;

  Future<Database> get _db => _dbService.database;

  /// Retrieves the locked mission beats for [roadmapId] on [date] (YYYY-MM-DD).
  ///
  /// Inner joins with [DatabaseTables.beats] so deleted beats are cleanly omitted,
  /// and beats are ordered by [DailyMissionColumns.sortIndex].
  Future<List<BeatEntity>> getMissionBeatsForDate(
    String roadmapId,
    String date,
  ) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT b.*
      FROM ${DatabaseTables.dailyMissions} dm
      INNER JOIN ${DatabaseTables.beats} b ON dm.${DailyMissionColumns.beatId} = b.${BeatColumns.id}
      WHERE dm.${DailyMissionColumns.roadmapId} = ?
        AND dm.${DailyMissionColumns.date} = ?
      ORDER BY dm.${DailyMissionColumns.sortIndex} ASC
    ''', [roadmapId, date]);

    return results.map((map) => BeatEntity.fromMap(map)).toList();
  }

  /// Sets/locks the mission beats for [roadmapId] on [date].
  Future<void> setDailyMission({
    required String roadmapId,
    required String date,
    required List<String> beatIds,
  }) async {
    if (beatIds.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        DatabaseTables.dailyMissions,
        where: '${DailyMissionColumns.roadmapId} = ? AND ${DailyMissionColumns.date} = ?',
        whereArgs: [roadmapId, date],
      );

      final batch = txn.batch();
      for (int i = 0; i < beatIds.length; i++) {
        batch.insert(DatabaseTables.dailyMissions, {
          DailyMissionColumns.id: '${roadmapId}_${date}_$i',
          DailyMissionColumns.roadmapId: roadmapId,
          DailyMissionColumns.date: date,
          DailyMissionColumns.beatId: beatIds[i],
          DailyMissionColumns.sortIndex: i,
          DailyMissionColumns.createdAt: now,
        });
      }
      await batch.commit(noResult: true);
    });

    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.roadmapUpdated,
      roadmapId: roadmapId,
    ));
  }

  /// Deletes mission entries for a given roadmap and optional date.
  Future<void> clearDailyMissions(String roadmapId, {String? date}) async {
    final db = await _db;
    if (date != null) {
      await db.delete(
        DatabaseTables.dailyMissions,
        where: '${DailyMissionColumns.roadmapId} = ? AND ${DailyMissionColumns.date} = ?',
        whereArgs: [roadmapId, date],
      );
    } else {
      await db.delete(
        DatabaseTables.dailyMissions,
        where: '${DailyMissionColumns.roadmapId} = ?',
        whereArgs: [roadmapId],
      );
    }
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.roadmapUpdated,
      roadmapId: roadmapId,
    ));
  }
}
