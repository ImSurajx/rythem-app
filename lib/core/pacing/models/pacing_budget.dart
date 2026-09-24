import '../../database/models/beat_entity.dart';

enum PaceStatus {
  onTrack,
  behindSchedule,
  openPace,
}

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

  /// Indicates if this track is scheduled to start in the future and has not yet kicked off.
  final bool isUpcoming;

  /// Number of days remaining until the scheduled kickoff date.
  final int daysUntilStart;

  /// High-level navigation status (onTrack, behindSchedule, openPace).
  final PaceStatus paceStatus;

  /// Projected calendar completion date based on actual user velocity.
  final DateTime? projectedCompletionDate;

  /// Difference in calendar days between projected completion and target date.
  /// Positive means behind target (e.g. +4 = 4 days behind).
  /// Negative or zero means ahead or on time (e.g. -2 = 2 days ahead).
  final int daysAheadOrBehind;

  /// Informational recommended lessons/day to hit target date.
  final double dailyEffortGuideline;

  /// Non-intrusive advisory coaching message.
  final String guidelineMessage;

  /// Target completion date if set.
  final DateTime? targetDate;

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
    this.isUpcoming = false,
    this.daysUntilStart = 0,
    this.paceStatus = PaceStatus.openPace,
    this.projectedCompletionDate,
    this.daysAheadOrBehind = 0,
    this.dailyEffortGuideline = 1.0,
    this.guidelineMessage = '',
    this.targetDate,
  });

  bool get isOnTrack => paceStatus == PaceStatus.onTrack;
  bool get isBehindSchedule => paceStatus == PaceStatus.behindSchedule;
  bool get isOpenPace => paceStatus == PaceStatus.openPace;

  /// Ratio of completed beats today vs total assigned for today.
  double get dailyCompletionRatio {
    if (isUpcoming) return 0.0;
    if (todaysBeats.isEmpty) return isRoadmapCompleted ? 1.0 : 0.0;
    final completed = todaysBeats.where((b) => b.isCompleted).length;
    return completed / todaysBeats.length;
  }

  /// Formatted readable effort string (e.g. "2.5 effort units").
  String get formattedBudget => todayEffortShare.toStringAsFixed(1);

  PacingBudget copyWith({
    String? roadmapId,
    double? remainingEffort,
    int? daysLeft,
    double? todayEffortShare,
    List<BeatEntity>? todaysBeats,
    double? todaysSelectedEffort,
    bool? isRoadmapCompleted,
    bool? isDailyQuotaCompleted,
    bool? isSustainedLag,
    int? lagStreakDays,
    double? recentVelocity,
    double? shortfallDebt,
    double? velocityDeficit,
    bool? isUpcoming,
    int? daysUntilStart,
    PaceStatus? paceStatus,
    DateTime? projectedCompletionDate,
    int? daysAheadOrBehind,
    double? dailyEffortGuideline,
    String? guidelineMessage,
    DateTime? targetDate,
  }) {
    return PacingBudget(
      roadmapId: roadmapId ?? this.roadmapId,
      remainingEffort: remainingEffort ?? this.remainingEffort,
      daysLeft: daysLeft ?? this.daysLeft,
      todayEffortShare: todayEffortShare ?? this.todayEffortShare,
      todaysBeats: todaysBeats ?? this.todaysBeats,
      todaysSelectedEffort: todaysSelectedEffort ?? this.todaysSelectedEffort,
      isRoadmapCompleted: isRoadmapCompleted ?? this.isRoadmapCompleted,
      isDailyQuotaCompleted: isDailyQuotaCompleted ?? this.isDailyQuotaCompleted,
      isSustainedLag: isSustainedLag ?? this.isSustainedLag,
      lagStreakDays: lagStreakDays ?? this.lagStreakDays,
      recentVelocity: recentVelocity ?? this.recentVelocity,
      shortfallDebt: shortfallDebt ?? this.shortfallDebt,
      velocityDeficit: velocityDeficit ?? this.velocityDeficit,
      isUpcoming: isUpcoming ?? this.isUpcoming,
      daysUntilStart: daysUntilStart ?? this.daysUntilStart,
      paceStatus: paceStatus ?? this.paceStatus,
      projectedCompletionDate: projectedCompletionDate ?? this.projectedCompletionDate,
      daysAheadOrBehind: daysAheadOrBehind ?? this.daysAheadOrBehind,
      dailyEffortGuideline: dailyEffortGuideline ?? this.dailyEffortGuideline,
      guidelineMessage: guidelineMessage ?? this.guidelineMessage,
      targetDate: targetDate ?? this.targetDate,
    );
  }
}
