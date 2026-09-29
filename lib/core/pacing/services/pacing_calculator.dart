import 'dart:math' as math;
import '../../database/database.dart';
import '../models/study_intensity.dart';

/// Pure deterministic mathematical calculations for the Pacing Engine.
/// 
/// Enforces:
/// - 0 clock time (no minutes/hours exposed).
/// - Exact effort budget distribution.
class PacingCalculator {
  PacingCalculator._();

  /// Calculates the number of calendar days left until [targetDate].
  /// 
  /// Guaranteed to return at least 1 to prevent division by zero.
  static int calculateDaysLeft(DateTime targetDate, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);

    final differenceInDays = target.difference(today).inDays;
    return math.max(1, differenceInDays);
  }

  /// Calculates total remaining effort across all incomplete beats.
  static double calculateRemainingEffort(List<BeatEntity> incompleteBeats) {
    if (incompleteBeats.isEmpty) return 0.0;
    double sum = 0.0;
    for (final b in incompleteBeats) {
      if (!b.isCompleted) {
        sum += b.effortWeight;
      }
    }
    return double.parse(sum.toStringAsFixed(2));
  }

  /// Derives today's effort share = remaining effort ÷ days left.
  static double calculateDailyEffortShare({
    required double remainingEffort,
    required int daysLeft,
  }) {
    if (remainingEffort <= 0.0) return 0.0;
    final validDays = math.max(1, daysLeft);
    final share = remainingEffort / validDays;
    return double.parse(share.toStringAsFixed(2));
  }

  /// Derives today's effort share based on remaining days until target date,
  /// modulated by the 7-day study intensity rhythm.
  static double calculateRhythmAdjustedDailyShare({
    required double remainingEffort,
    required int daysLeft,
    required StudyIntensity intensity,
  }) {
    if (remainingEffort <= 0.0) return 0.0;
    if (intensity == StudyIntensity.rest) return 0.0;

    final baseDailyEffort = calculateDailyEffortShare(
      remainingEffort: remainingEffort,
      daysLeft: daysLeft,
    );

    final double multiplier;
    switch (intensity) {
      case StudyIntensity.rest:
        return 0.0;
      case StudyIntensity.light:
        multiplier = 0.6;
        break;
      case StudyIntensity.normal:
        multiplier = 1.0;
        break;
      case StudyIntensity.intense:
        multiplier = 1.4;
        break;
    }

    final adjusted = baseDailyEffort * multiplier;
    final clamped = adjusted.clamp(0.5, remainingEffort);
    return double.parse(clamped.toStringAsFixed(2));
  }
}
