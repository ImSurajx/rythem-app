import 'package:sqflite/sqflite.dart';
import '../database_service.dart';
import '../models/beat_log_entity.dart';
import '../tables.dart';

class DailyBeatCount {
  final String date;
  final int count;

  const DailyBeatCount({required this.date, required this.count});
}

class BeatLogRepository {
  final DatabaseService _dbService;

  BeatLogRepository({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  Future<Database> get _db => _dbService.database;

  Future<List<BeatLogEntity>> getLogsForDate(String dateStr) async {
    final db = await _db;
    final results = await db.query(
      DatabaseTables.beatLogs,
      where: '${BeatLogColumns.completedDate} = ?',
      whereArgs: [dateStr],
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

  /// Fetches daily counts for the last [daysCount] days (default 7 days for flow metrics).
  Future<List<DailyBeatCount>> getRecentActivity({int daysCount = 7}) async {
    final db = await _db;
    final now = DateTime.now();
    final startDate = now
        .subtract(Duration(days: daysCount - 1))
        .toIso8601String()
        .substring(0, 10);

    final results = await db.rawQuery('''
      SELECT 
        ${BeatLogColumns.completedDate} as date,
        COUNT(*) as count
      FROM ${DatabaseTables.beatLogs}
      WHERE ${BeatLogColumns.completedDate} >= ?
      GROUP BY ${BeatLogColumns.completedDate}
      ORDER BY ${BeatLogColumns.completedDate} ASC
    ''', [startDate]);

    final Map<String, int> countsByDate = {
      for (final row in results)
        row['date'] as String: (row['count'] as num).toInt(),
    };

    final List<DailyBeatCount> fullSequence = [];
    for (int i = daysCount - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i)).toIso8601String().substring(0, 10);
      fullSequence.add(DailyBeatCount(
        date: d,
        count: countsByDate[d] ?? 0,
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
}
