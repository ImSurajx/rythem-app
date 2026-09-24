import 'package:sqflite/sqflite.dart';
import '../database_event_bus.dart';
import '../database_service.dart';
import '../models/chapter_entity.dart';
import '../tables.dart';

class ChapterRepository {
  final DatabaseService _dbService;
  final DatabaseEventBus _eventBus;

  ChapterRepository({
    DatabaseService? dbService,
    DatabaseEventBus? eventBus,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _eventBus = eventBus ?? DatabaseEventBus.instance;

  Future<Database> get _db => _dbService.database;

  Future<void> createChapter(ChapterEntity chapter) async {
    final db = await _db;
    await db.insert(
      DatabaseTables.chapters,
      chapter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.chapterCreated,
      entityId: chapter.id,
      roadmapId: chapter.roadmapId,
    ));
  }

  Future<void> createChaptersBatch(List<ChapterEntity> chapters) async {
    if (chapters.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final chapter in chapters) {
      batch.insert(
        DatabaseTables.chapters,
        chapter.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.chapterCreated,
      roadmapId: chapters.first.roadmapId,
    ));
  }

  Future<List<ChapterEntity>> getChaptersByRoadmapId(String roadmapId) async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.chapters,
      where: '${ChapterColumns.roadmapId} = ?',
      whereArgs: [roadmapId],
      orderBy: '${ChapterColumns.sortOrder} ASC, ${ChapterColumns.createdAt} ASC',
    );
    return results.map(ChapterEntity.fromMap).toList();
  }

  /// Computes the next sequential sortOrder for a new chapter in [roadmapId],
  /// guaranteeing placement at the bottom of the subject chapter list.
  Future<int> getNextSortOrder(String roadmapId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT MAX(${ChapterColumns.sortOrder}) as max_sort FROM ${DatabaseTables.chapters} WHERE ${ChapterColumns.roadmapId} = ?',
      [roadmapId],
    );
    final maxSort = result.first['max_sort'] as int?;
    return (maxSort ?? -1) + 1;
  }

  Future<void> updateChapter(ChapterEntity chapter) async {
    final db = await _db;
    await db.update(
      DatabaseTables.chapters,
      chapter.toMap(),
      where: '${ChapterColumns.id} = ?',
      whereArgs: [chapter.id],
    );
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.chapterUpdated,
      entityId: chapter.id,
      roadmapId: chapter.roadmapId,
    ));
  }

  Future<void> deleteChapter(String id) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.chapters,
      where: '${ChapterColumns.id} = ?',
      whereArgs: [id],
    );
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.chapterDeleted,
      entityId: id,
    ));
  }

  Future<void> deleteChaptersByRoadmapId(String roadmapId) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.chapters,
      where: '${ChapterColumns.roadmapId} = ?',
      whereArgs: [roadmapId],
    );
  }
}
