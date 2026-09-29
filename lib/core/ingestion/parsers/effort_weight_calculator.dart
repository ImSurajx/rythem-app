class EffortWeightCalculator {
  EffortWeightCalculator._();

  /// Baseline standard video duration in seconds: 10 minutes (600 seconds) = 1.0 effort point.
  static const double secondsPerEffortPoint = 600.0;

  /// Minimum effort point for any very short video/clip (e.g. 1 minute or less).
  static const double minWeight = 0.1;

  /// Maximum effort points capped for a single monolithic video or full-course upload.
  static const double maxWeight = 50.0;

  /// Calculates effort points according to resource duration length:
  /// Each 10 minutes of video counts as 1.0 effort point.
  /// 
  /// Formula: durationSeconds / 600.0
  /// 
  /// Examples:
  /// - 1 minute (60s) -> 0.1 effort
  /// - 5 minutes (300s) -> 0.5 effort
  /// - 10 minutes (600s) -> 1.0 effort
  /// - 14 minutes (840s) -> 1.4 effort (10 + 4 = 1.0 + 0.4)
  /// - 25 minutes (1500s) -> 2.5 effort
  /// - 60 minutes (3600s) -> 6.0 effort
  static double calculate(int durationSeconds) {
    if (durationSeconds <= 0) {
      return 1.0;
    }

    final rawEffort = durationSeconds / secondsPerEffortPoint;
    final clamped = rawEffort.clamp(minWeight, maxWeight);

    // Round to 1 decimal place (e.g. 1.4, 2.5)
    return double.parse(clamped.toStringAsFixed(1));
  }

  /// Calculates effort for chaptered video sections bounded by timestamp deltas.
  static double calculateForTimestampDelta(int startSeconds, int? nextStartSeconds) {
    if (nextStartSeconds == null || nextStartSeconds <= startSeconds) {
      return 1.0;
    }
    return calculate(nextStartSeconds - startSeconds);
  }
}
