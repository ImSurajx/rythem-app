class SyncResult {
  final int updatedTopicsCount;
  final int newTopicsAddedCount;
  final double totalEffortPoints;

  const SyncResult({
    required this.updatedTopicsCount,
    required this.newTopicsAddedCount,
    required this.totalEffortPoints,
  });

  @override
  String toString() =>
      'SyncResult(updated: $updatedTopicsCount, new: $newTopicsAddedCount, totalEffort: $totalEffortPoints)';
}
