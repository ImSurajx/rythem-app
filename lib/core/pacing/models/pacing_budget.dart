/// Represents the calculated pacing status and effort metrics for a roadmap.
class PacingBudget {
  /// The roadmap identifier this budget was computed for.
  final String roadmapId;

  /// Sum of effort weights across all remaining incomplete beats.
  final double remainingEffort;

  /// Calendar days remaining until target completion date (min 1).
  final int daysLeft;

  /// Today's calculated effort share (remainingEffort ÷ daysLeft).
  final double todayEffortShare;

  /// True if all beats in the roadmap are completed.
  final bool isRoadmapCompleted;

  /// Indicates if this track is scheduled to start in the future and has not yet kicked off.
  final bool isUpcoming;

  /// Number of days remaining until the scheduled kickoff date.
  final int daysUntilStart;

  const PacingBudget({
    required this.roadmapId,
    required this.remainingEffort,
    required this.daysLeft,
    required this.todayEffortShare,
    this.isRoadmapCompleted = false,
    this.isUpcoming = false,
    this.daysUntilStart = 0,
  });

  /// Formatted readable effort string (e.g. "2.5 effort units").
  String get formattedBudget => todayEffortShare.toStringAsFixed(1);

  PacingBudget copyWith({
    String? roadmapId,
    double? remainingEffort,
    int? daysLeft,
    double? todayEffortShare,
    bool? isRoadmapCompleted,
    bool? isUpcoming,
    int? daysUntilStart,
  }) {
    return PacingBudget(
      roadmapId: roadmapId ?? this.roadmapId,
      remainingEffort: remainingEffort ?? this.remainingEffort,
      daysLeft: daysLeft ?? this.daysLeft,
      todayEffortShare: todayEffortShare ?? this.todayEffortShare,
      isRoadmapCompleted: isRoadmapCompleted ?? this.isRoadmapCompleted,
      isUpcoming: isUpcoming ?? this.isUpcoming,
      daysUntilStart: daysUntilStart ?? this.daysUntilStart,
    );
  }
}
