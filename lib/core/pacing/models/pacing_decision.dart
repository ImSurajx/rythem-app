/// The 4 non-punitive options presented when sustained lag is detected.
enum PacingDecisionType {
  /// Push the roadmap's target date out by a specified number of days.
  extendTargetDate,

  /// Focus on must-do/core beats only (exclude non-essential extras).
  trimToCore,

  /// Rebalance effort by borrowing slack from another roadmap that is ahead of pace.
  borrowSlack,

  /// Consciously accept current pace and continue without adjusting schedule.
  acceptAndContinue,
}

class PacingDecision {
  final PacingDecisionType type;

  /// Additional days to extend target completion date (for [PacingDecisionType.extendTargetDate]).
  final int? extensionDays;

  /// Source roadmap ID to borrow slack from (for [PacingDecisionType.borrowSlack]).
  final String? borrowFromRoadmapId;

  const PacingDecision({
    required this.type,
    this.extensionDays,
    this.borrowFromRoadmapId,
  });

  const PacingDecision.extendDate(int days)
      : type = PacingDecisionType.extendTargetDate,
        extensionDays = days,
        borrowFromRoadmapId = null;

  const PacingDecision.trimCore()
      : type = PacingDecisionType.trimToCore,
        extensionDays = null,
        borrowFromRoadmapId = null;

  const PacingDecision.borrow(String sourceRoadmapId)
      : type = PacingDecisionType.borrowSlack,
        extensionDays = null,
        borrowFromRoadmapId = sourceRoadmapId;

  const PacingDecision.accept()
      : type = PacingDecisionType.acceptAndContinue,
        extensionDays = null,
        borrowFromRoadmapId = null;
}
