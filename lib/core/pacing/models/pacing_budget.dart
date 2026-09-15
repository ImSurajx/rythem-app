import '../../database/database.dart';

/// Represents the calculated daily pacing budget derived strictly from math.
/// 
/// Enforces:
/// - Zero clock-time counting (efforts, not minutes/seconds).
/// - Today's beats are selected from the front of the pending queue in mentor order.
/// - Backlog dilution is calculated fresh daily without punishment or compounding.
class PacingBudget {
  /// The roadmap identifier this budget was computed for.
  final String roadmapId;

  /// Sum of effort weights across all remaining incomplete beats.
  final double remainingEffort;

  /// Calendar days remaining until target completion date (min 1).
  final int daysLeft;

  /// Today's calculated effort share (remainingEffort ÷ daysLeft).
  final double todayEffortShare;

  /// The specific beats selected to fulfill today's effort budget.
  /// Preserves strict mentor chronological queue order.
  final List<BeatEntity> todaysBeats;

  /// Combined effort weight of the beats selected for today.
  final double todaysSelectedEffort;

  /// True if all beats in the roadmap are completed.
  final bool isRoadmapCompleted;

  /// True if today's assigned beats are all completed.
  final bool isDailyQuotaCompleted;

  /// Indicates sustained lag (e.g. 3+ consecutive days of shortfall).
  final bool isSustainedLag;

  /// Number of consecutive days the user has fallen short of daily budget.
  final int lagStreakDays;

  /// Average completed effort per day over recent activity window.
  final double recentVelocity;

  /// Total unabsorbed effort debt accumulated across recent lagging days.
  final double shortfallDebt;

  /// Required velocity minus actual recent velocity.
  final double velocityDeficit;

  const PacingBudget({
    required this.roadmapId,
    required this.remainingEffort,
    required this.daysLeft,
    required this.todayEffortShare,
    required this.todaysBeats,
    required this.todaysSelectedEffort,
    this.isRoadmapCompleted = false,
    this.isDailyQuotaCompleted = false,
    this.isSustainedLag = false,
    this.lagStreakDays = 0,
    this.recentVelocity = 0.0,
    this.shortfallDebt = 0.0,
    this.velocityDeficit = 0.0,
  });

  /// Ratio of completed beats today vs total assigned for today.
  double get dailyCompletionRatio {
    if (todaysBeats.isEmpty) return 1.0;
    final completed = todaysBeats.where((b) => b.isCompleted).length;
    return completed / todaysBeats.length;
  }

  /// Formatted readable effort string (e.g. "2.5 effort units").
  String get formattedBudget => todayEffortShare.toStringAsFixed(1);
}
