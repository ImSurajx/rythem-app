import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'tables.dart';

class DatabaseService {
  static const String _databaseName = 'rythem.db';
  static const int _databaseVersion = 3;

  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  /// Optional injector for test environments (e.g., in-memory SQLite FFI).
  void setDatabaseForTesting(Database? db) {
    _db = db;
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enforce foreign key constraints across all relationships
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Roadmaps Table
    batch.execute('''
      CREATE TABLE ${DatabaseTables.roadmaps} (
        ${RoadmapColumns.id} TEXT PRIMARY KEY,
        ${RoadmapColumns.title} TEXT NOT NULL,
        ${RoadmapColumns.description} TEXT,
        ${RoadmapColumns.startDate} TEXT,
        ${RoadmapColumns.targetCompletionDate} TEXT,
        ${RoadmapColumns.status} TEXT NOT NULL DEFAULT 'active',
        ${RoadmapColumns.isPrimary} INTEGER NOT NULL DEFAULT 0,
        ${RoadmapColumns.createdAt} TEXT NOT NULL,
        ${RoadmapColumns.updatedAt} TEXT NOT NULL
      );
    ''');

    // 2. Chapters Table
    batch.execute('''
      CREATE TABLE ${DatabaseTables.chapters} (
        ${ChapterColumns.id} TEXT PRIMARY KEY,
        ${ChapterColumns.roadmapId} TEXT NOT NULL,
        ${ChapterColumns.title} TEXT NOT NULL,
        ${ChapterColumns.sortOrder} INTEGER NOT NULL DEFAULT 0,
        ${ChapterColumns.createdAt} TEXT NOT NULL,
        ${ChapterColumns.updatedAt} TEXT NOT NULL,
        FOREIGN KEY (${ChapterColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
      );
    ''');
    batch.execute('''
      CREATE INDEX idx_chapters_roadmap ON ${DatabaseTables.chapters} (
        ${ChapterColumns.roadmapId},
        ${ChapterColumns.sortOrder}
      );
    ''');

    // 3. Beats Table
    batch.execute('''
      CREATE TABLE ${DatabaseTables.beats} (
        ${BeatColumns.id} TEXT PRIMARY KEY,
        ${BeatColumns.chapterId} TEXT NOT NULL,
        ${BeatColumns.roadmapId} TEXT NOT NULL,
        ${BeatColumns.title} TEXT NOT NULL,
        ${BeatColumns.sourceUrl} TEXT,
        ${BeatColumns.timestampSeconds} INTEGER,
        ${BeatColumns.effortWeight} REAL NOT NULL DEFAULT 1.0,
        ${BeatColumns.sortOrder} INTEGER NOT NULL DEFAULT 0,
        ${BeatColumns.isCompleted} INTEGER NOT NULL DEFAULT 0,
        ${BeatColumns.completedAt} TEXT,
        ${BeatColumns.isMentorExtra} INTEGER NOT NULL DEFAULT 0,
        ${BeatColumns.matchConfidence} REAL,
        ${BeatColumns.syllabusTopicId} TEXT,
        ${BeatColumns.totalParts} INTEGER NOT NULL DEFAULT 1,
        ${BeatColumns.completedParts} INTEGER NOT NULL DEFAULT 0,
        ${BeatColumns.createdAt} TEXT NOT NULL,
        ${BeatColumns.updatedAt} TEXT NOT NULL,
        FOREIGN KEY (${BeatColumns.chapterId}) REFERENCES ${DatabaseTables.chapters} (${ChapterColumns.id}) ON DELETE CASCADE,
        FOREIGN KEY (${BeatColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
      );
    ''');
    batch.execute('''
      CREATE INDEX idx_beats_chapter ON ${DatabaseTables.beats} (
        ${BeatColumns.chapterId},
        ${BeatColumns.sortOrder}
      );
    ''');
    batch.execute('''
      CREATE INDEX idx_beats_roadmap_pending ON ${DatabaseTables.beats} (
        ${BeatColumns.roadmapId},
        ${BeatColumns.isCompleted},
        ${BeatColumns.sortOrder}
      );
    ''');

    // 4. Beat Logs Table
    batch.execute('''
      CREATE TABLE ${DatabaseTables.beatLogs} (
        ${BeatLogColumns.id} TEXT PRIMARY KEY,
        ${BeatLogColumns.beatId} TEXT NOT NULL,
        ${BeatLogColumns.roadmapId} TEXT NOT NULL,
        ${BeatLogColumns.completedDate} TEXT NOT NULL,
        ${BeatLogColumns.createdAt} TEXT NOT NULL,
        FOREIGN KEY (${BeatLogColumns.beatId}) REFERENCES ${DatabaseTables.beats} (${BeatColumns.id}) ON DELETE CASCADE,
        FOREIGN KEY (${BeatLogColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
      );
    ''');
    batch.execute('''
      CREATE INDEX idx_beat_logs_date ON ${DatabaseTables.beatLogs} (
        ${BeatLogColumns.completedDate}
      );
    ''');
    batch.execute('''
      CREATE INDEX idx_beat_logs_roadmap ON ${DatabaseTables.beatLogs} (
        ${BeatLogColumns.roadmapId},
        ${BeatLogColumns.completedDate}
      );
    ''');

    // 5. App Settings Table
    batch.execute('''
      CREATE TABLE ${DatabaseTables.appSettings} (
        ${AppSettingsColumns.key} TEXT PRIMARY KEY,
        ${AppSettingsColumns.value} TEXT NOT NULL,
        ${AppSettingsColumns.updatedAt} TEXT NOT NULL
      );
    ''');

    // 6. Daily Missions Table
    batch.execute('''
      CREATE TABLE ${DatabaseTables.dailyMissions} (
        ${DailyMissionColumns.id} TEXT PRIMARY KEY,
        ${DailyMissionColumns.roadmapId} TEXT NOT NULL,
        ${DailyMissionColumns.date} TEXT NOT NULL,
        ${DailyMissionColumns.beatId} TEXT NOT NULL,
        ${DailyMissionColumns.sortIndex} INTEGER NOT NULL,
        ${DailyMissionColumns.createdAt} TEXT NOT NULL,
        FOREIGN KEY (${DailyMissionColumns.beatId}) REFERENCES ${DatabaseTables.beats} (${BeatColumns.id}) ON DELETE CASCADE,
        FOREIGN KEY (${DailyMissionColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
      );
    ''');
    batch.execute('''
      CREATE INDEX idx_daily_missions_date ON ${DatabaseTables.dailyMissions} (
        ${DailyMissionColumns.roadmapId},
        ${DailyMissionColumns.date}
      );
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.roadmaps}
        ADD COLUMN ${RoadmapColumns.startDate} TEXT;
      ''');

      await db.execute('''
        CREATE TABLE ${DatabaseTables.dailyMissions} (
          ${DailyMissionColumns.id} TEXT PRIMARY KEY,
          ${DailyMissionColumns.roadmapId} TEXT NOT NULL,
          ${DailyMissionColumns.date} TEXT NOT NULL,
          ${DailyMissionColumns.beatId} TEXT NOT NULL,
          ${DailyMissionColumns.sortIndex} INTEGER NOT NULL,
          ${DailyMissionColumns.createdAt} TEXT NOT NULL,
          FOREIGN KEY (${DailyMissionColumns.beatId}) REFERENCES ${DatabaseTables.beats} (${BeatColumns.id}) ON DELETE CASCADE,
          FOREIGN KEY (${DailyMissionColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
        );
      ''');

      await db.execute('''
        CREATE INDEX idx_daily_missions_date ON ${DatabaseTables.dailyMissions} (
          ${DailyMissionColumns.roadmapId},
          ${DailyMissionColumns.date}
        );
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.beats}
        ADD COLUMN ${BeatColumns.totalParts} INTEGER NOT NULL DEFAULT 1;
      ''');
      await db.execute('''
        ALTER TABLE ${DatabaseTables.beats}
        ADD COLUMN ${BeatColumns.completedParts} INTEGER NOT NULL DEFAULT 0;
      ''');
    }
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  Future<void> initInMemoryForTesting() async {
    await close();
    final inMemoryDb = await openDatabase(
      inMemoryDatabasePath,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    setDatabaseForTesting(inMemoryDb);
  }

  Future<void> deleteDatabaseFile() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await deleteDatabase(path);
  }

  Future<void> resetDatabase() async {
    if (_db != null && _db!.path == inMemoryDatabasePath) {
      await initInMemoryForTesting();
    } else {
      await deleteDatabaseFile();
    }
  }
}


