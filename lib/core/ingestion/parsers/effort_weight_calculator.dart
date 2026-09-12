class EffortWeightCalculator {
  EffortWeightCalculator._();

  /// Baseline standard beat duration in seconds (15 minutes = 1.0 effort weight).
  static const double baselineSeconds = 900.0;

  /// Minimum effort weight for any discrete beat.
  static const double minWeight = 0.5;

  /// Maximum effort weight capped for a single beat to prevent overwhelming single-day budgets.
  static const double maxWeight = 5.0;

  /// Calculates an invisible, non-clock effort weight from duration in seconds.
  /// 
  /// Examples:
  /// - 5 minutes (300s) -> ~0.6
  /// - 15 minutes (900s) -> 1.0 (baseline unit)
  /// - 30 minutes (1800s) -> 1.6
  /// - 60 minutes (3600s) -> 2.5
  static double calculate(int durationSeconds) {
    if (durationSeconds <= 0) {
      return 1.0;
    }

    // Square root dampening prevents multi-hour monolithic videos from exploding the daily budget
    final ratio = durationSeconds / baselineSeconds;
    final weight = ratio <= 1.0 
        ? (0.5 + (0.5 * ratio))
        : (1.0 + 0.8 * (ratio - 1.0).clamp(0.0, 5.0));

    // Round to 1 decimal place for clean relational arithmetic
    final clamped = weight.clamp(minWeight, maxWeight);
    return double.parse(clamped.toStringAsFixed(1));
  }
}
