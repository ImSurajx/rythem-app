import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../models/beat_log_entity.dart';
import '../tables.dart';

class DailyBeatCount {
  final String date;
  final int count;
  final double? _effort;

  const DailyBeatCount({
    required this.date,
    required this.count,
    double? effort,
  }) : _effort = effort;

  double get effort => _effort ?? count.toDouble();
}

class BeatLogRepository {
  final DatabaseService _dbService;

  BeatLogRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  Future<Database> get _db => _dbService.database;

  Future<void> logBeatCompletion({
    required String beatId,
    required String roadmapId,
    required String completedDate,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    await db.insert(
      DatabaseTables.beatLogs,
      {
        BeatLogColumns.id: '${beatId}_${now.millisecondsSinceEpoch}',
        BeatLogColumns.beatId: beatId,
        BeatLogColumns.roadmapId: roadmapId,
        BeatLogColumns.completedDate: completedDate,
        BeatLogColumns.createdAt: now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeBeatCompletion({
    required String beatId,
    required String completedDate,
  }) async {
    final db = await _db;
    await db.delete(
      DatabaseTables.beatLogs,
      where: '${BeatLogColumns.beatId} = ? AND ${BeatLogColumns.completedDate} = ?',
      whereArgs: [beatId, completedDate],
    );
  }

  Future<List<BeatLogEntity>> getLogsForDate(String dateStr) async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.beatLogs,
      where: '${BeatLogColumns.completedDate} = ?',
      whereArgs: [dateStr],
    );
    return results.map(BeatLogEntity.fromMap).toList();
  }

  Future<List<BeatLogEntity>> getLogsForRoadmapOnDate(String roadmapId, String dateStr) async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.beatLogs,
      where: '${BeatLogColumns.roadmapId} = ? AND ${BeatLogColumns.completedDate} = ?',
      whereArgs: [roadmapId, dateStr],
    );
    return results.map(BeatLogEntity.fromMap).toList();
  }

  Future<int> getBeatsCompletedToday() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final logs = await getLogsForDate(today);
    return logs.length;
  }

  Future<int> getTotalBeatsCompleted() async {
    final db = await _db;
    final results = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseTables.beatLogs}',
    );
    if (results.isEmpty) return 0;
    return (results.first['count'] as num?)?.toInt() ?? 0;
  }

  /// Fetches daily counts and effort points for the last [daysCount] days (default 7 days for flow metrics).
  Future<List<DailyBeatCount>> getRecentActivity({int daysCount = 7}) async {
    final db = await _db;
    final now = DateTime.now();
    final startDate = now
        .subtract(Duration(days: daysCount - 1))
        .toIso8601String()
        .substring(0, 10);

    final results = await db.rawQuery('''
      SELECT 
        bl.${BeatLogColumns.completedDate} as date,
        COUNT(bl.${BeatLogColumns.id}) as count,
        COALESCE(SUM(CASE WHEN b.${BeatColumns.effortWeight} IS NOT NULL AND b.${BeatColumns.effortWeight} > 0 THEN b.${BeatColumns.effortWeight} ELSE 1.0 END), 0.0) as effort
      FROM ${DatabaseTables.beatLogs} bl
      LEFT JOIN ${DatabaseTables.beats} b ON bl.${BeatLogColumns.beatId} = b.${BeatColumns.id}
      WHERE bl.${BeatLogColumns.completedDate} >= ?
      GROUP BY bl.${BeatLogColumns.completedDate}
      ORDER BY bl.${BeatLogColumns.completedDate} ASC
    ''', [startDate]);

    final Map<String, int> countsByDate = {};
    final Map<String, double> effortsByDate = {};
    for (final row in results) {
      final d = row['date'] as String;
      countsByDate[d] = (row['count'] as num).toInt();
      effortsByDate[d] = (row['effort'] as num).toDouble();
    }

    final List<DailyBeatCount> fullSequence = [];
    for (int i = daysCount - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i)).toIso8601String().substring(0, 10);
      fullSequence.add(DailyBeatCount(
        date: d,
        count: countsByDate[d] ?? 0,
        effort: effortsByDate[d] ?? 0.0,
      ));
    }

    return fullSequence;
  }

  /// Computes the current consecutive-day streak of completed beats.
  Future<int> getCurrentStreak() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT DISTINCT ${BeatLogColumns.completedDate} as date
      FROM ${DatabaseTables.beatLogs}
      ORDER BY ${BeatLogColumns.completedDate} DESC
    ''');

    if (results.isEmpty) return 0;

    final dates = results.map((r) => r['date'] as String).toSet();
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    final yesterday =
        now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    // Streak can continue from today or yesterday
    String currentCheck;
    if (dates.contains(today)) {
      currentCheck = today;
    } else if (dates.contains(yesterday)) {
      currentCheck = yesterday;
    } else {
      return 0; // No activity today or yesterday
    }

    int streak = 0;
    var checkDate = DateTime.parse(currentCheck);

    while (dates.contains(checkDate.toIso8601String().substring(0, 10))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Fetches daily effort points for an entire calendar month [year]-[month].
  /// Returns a map of 'YYYY-MM-DD' -> effort points.
  Future<Map<String, double>> getActivityForMonth(int year, int month) async {
    final db = await _db;
    final startStr = '$year-${month.toString().padLeft(2, '0')}-01';
    final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final endStr = nextMonth.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    final results = await db.rawQuery('''
      SELECT 
        bl.${BeatLogColumns.completedDate} as date,
        COALESCE(SUM(CASE WHEN b.${BeatColumns.effortWeight} IS NOT NULL AND b.${BeatColumns.effortWeight} > 0 THEN b.${BeatColumns.effortWeight} ELSE 1.0 END), 0.0) as effort
      FROM ${DatabaseTables.beatLogs} bl
      LEFT JOIN ${DatabaseTables.beats} b ON bl.${BeatLogColumns.beatId} = b.${BeatColumns.id}
      WHERE bl.${BeatLogColumns.completedDate} >= ? AND bl.${BeatLogColumns.completedDate} <= ?
      GROUP BY bl.${BeatLogColumns.completedDate}
      ORDER BY bl.${BeatLogColumns.completedDate} ASC
    ''', [startStr, endStr]);

    return {
      for (final row in results)
        row['date'] as String: (row['effort'] as num).toDouble(),
    };
  }

  /// Fetches daily effort points between [startStr] and [endStr] (inclusive).
  /// Returns a map of 'YYYY-MM-DD' -> effort points.
  Future<Map<String, double>> getActivityForDateRange(String startStr, String endStr) async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT 
        bl.${BeatLogColumns.completedDate} as date,
        COALESCE(SUM(CASE WHEN b.${BeatColumns.effortWeight} IS NOT NULL AND b.${BeatColumns.effortWeight} > 0 THEN b.${BeatColumns.effortWeight} ELSE 1.0 END), 0.0) as effort
      FROM ${DatabaseTables.beatLogs} bl
      LEFT JOIN ${DatabaseTables.beats} b ON bl.${BeatLogColumns.beatId} = b.${BeatColumns.id}
      WHERE bl.${BeatLogColumns.completedDate} >= ? AND bl.${BeatLogColumns.completedDate} <= ?
      GROUP BY bl.${BeatLogColumns.completedDate}
      ORDER BY bl.${BeatLogColumns.completedDate} ASC
    ''', [startStr, endStr]);

    return {
      for (final row in results)
        row['date'] as String: (row['effort'] as num).toDouble(),
    };
  }

  /// Fetches all daily completion aggregates with effort points across lifetime for growth curves.
  Future<List<DailyBeatCount>> getAllDailyActivity() async {
    final db = await _db;
    final results = await db.rawQuery('''
      SELECT 
        bl.${BeatLogColumns.completedDate} as date,
        COUNT(bl.${BeatLogColumns.id}) as count,
        COALESCE(SUM(CASE WHEN b.${BeatColumns.effortWeight} IS NOT NULL AND b.${BeatColumns.effortWeight} > 0 THEN b.${BeatColumns.effortWeight} ELSE 1.0 END), 0.0) as effort
      FROM ${DatabaseTables.beatLogs} bl
      LEFT JOIN ${DatabaseTables.beats} b ON bl.${BeatLogColumns.beatId} = b.${BeatColumns.id}
      GROUP BY bl.${BeatLogColumns.completedDate}
      ORDER BY bl.${BeatLogColumns.completedDate} ASC
    ''');

    return results
        .map((r) => DailyBeatCount(
              date: r['date'] as String,
              count: (r['count'] as num).toInt(),
              effort: (r['effort'] as num).toDouble(),
            ))
        .toList();
  }
}
