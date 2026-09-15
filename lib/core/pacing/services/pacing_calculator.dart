import 'dart:math' as math;
import '../../database/database.dart';

class DailyPacingRecord {
  final DateTime date;
  final double completedEffort;
  final double targetEffort;
  final bool isRestDay;

  const DailyPacingRecord({
    required this.date,
    required this.completedEffort,
    required this.targetEffort,
    this.isRestDay = false,
  });
}

/// Pure deterministic mathematical calculations for the Pacing Engine.
/// 
/// Enforces:
/// - 0 clock time (no minutes/hours exposed).
/// - Exact effort budget distribution.
/// - Smooth backlog dilution without compounding penalties.
/// - Strict mentor order preservation in beat queue walking.
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

  /// Walks the pending beats queue in strict mentor chronological order
  /// and selects beats until their combined effort satisfies [targetBudget].
  /// 
  /// Guarantees:
  /// - Order is never reshuffled or prioritized out of sequence.
  /// - At least 1 beat is selected if pending beats exist.
  /// - Halts immediately once target effort is fulfilled to prevent overload.
  static List<BeatEntity> walkQueueToFillBudget({
    required List<BeatEntity> pendingBeats,
    required double targetBudget,
  }) {
    if (pendingBeats.isEmpty) return [];

    // Sort by mentor order (sortOrder 0..N) to ensure deterministic sequence
    final sorted = List<BeatEntity>.from(pendingBeats)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final selected = <BeatEntity>[];
    double accumulatedEffort = 0.0;

    for (final beat in sorted) {
      selected.add(beat);
      accumulatedEffort += beat.effortWeight;

      // Stop once we meet or exceed today's budget
      if (accumulatedEffort >= targetBudget) {
        break;
      }
    }

    return selected;
  }

  /// Detects whether the user is experiencing sustained shortfall (3+ consecutive lagging days).
  /// 
  /// Ground truths:
  /// - A single off-day is absorbed silently (returns isSustainedLag: false).
  /// - 3 or more consecutive days of shortfall triggers [isSustainedLag: true].
  static ({bool isSustainedLag, int lagDaysCount}) detectShortfallTrend({
    required List<double> recentDailyEfforts,
    required double expectedDailyBudget,
    int lagThresholdDays = 3,
  }) {
    if (recentDailyEfforts.isEmpty || expectedDailyBudget <= 0.0) {
      return (isSustainedLag: false, lagDaysCount: 0);
    }

    int consecutiveLagDays = 0;
    // Walk recent daily efforts from most recent day backwards
    final reversed = recentDailyEfforts.reversed.toList();

    for (final effort in reversed) {
      // Lag if less than 30% of daily effort budget was completed
      if (effort < (expectedDailyBudget * 0.30)) {
        consecutiveLagDays++;
      } else {
        break; // Streak of lag broken
      }
    }

    final isLagging = consecutiveLagDays >= lagThresholdDays;
    return (
      isSustainedLag: isLagging,
      lagDaysCount: consecutiveLagDays,
    );
  }

  /// Mathematically evaluates past completed days against configured daily study intensity.
  /// 
  /// Enforces:
  /// - Excludes today (in-progress) from lag streak evaluations.
  /// - Excludes scheduled rest days without penalizing or breaking streaks.
  /// - Calculates cumulative shortfall debt and velocity deficit.
  static ({
    bool isSustainedLag,
    int lagDaysCount,
    double shortfallDebt,
    double velocityDeficit,
  }) evaluateShortfallWithSchedule({
    required List<DailyPacingRecord> pastDaysRecords,
    required double baseDailyBudget,
    int lagThresholdDays = 3,
  }) {
    if (pastDaysRecords.isEmpty) {
      return (
        isSustainedLag: false,
        lagDaysCount: 0,
        shortfallDebt: 0.0,
        velocityDeficit: 0.0,
      );
    }

    int consecutiveLagDays = 0;
    double totalShortfallDebt = 0.0;
    double totalCompleted = 0.0;
    double totalTarget = 0.0;

    // pastDaysRecords are evaluated from newest (yesterday) backwards
    for (final record in pastDaysRecords) {
      if (record.isRestDay) {
        // Scheduled rest days are never penalized
        continue;
      }

      totalCompleted += record.completedEffort;
      totalTarget += record.targetEffort;

      final dayDeficit = math.max(0.0, record.targetEffort - record.completedEffort);
      totalShortfallDebt += dayDeficit;

      // Completed less than 35% of target on an assigned study day
      if (record.completedEffort < (record.targetEffort * 0.35)) {
        consecutiveLagDays++;
      } else if (record.completedEffort >= (record.targetEffort * 0.70)) {
        // Healthy study day breaks the consecutive lag streak
        break;
      }
    }

    final activeRecords = pastDaysRecords.where((r) => !r.isRestDay).toList();
    final actualVelocity = activeRecords.isEmpty ? 0.0 : (totalCompleted / activeRecords.length);
    final requiredVelocity = activeRecords.isEmpty ? baseDailyBudget : (totalTarget / activeRecords.length);
    final velocityDeficit = math.max(0.0, requiredVelocity - actualVelocity);

    final isSustainedLag = consecutiveLagDays >= lagThresholdDays ||
        (consecutiveLagDays >= 2 && totalShortfallDebt >= (baseDailyBudget * 1.5));

    return (
      isSustainedLag: isSustainedLag,
      lagDaysCount: consecutiveLagDays,
      shortfallDebt: double.parse(totalShortfallDebt.toStringAsFixed(2)),
      velocityDeficit: double.parse(velocityDeficit.toStringAsFixed(2)),
    );
  }

  /// Calculates the user's velocity (average effort completed per active day).
  static double calculateVelocity(List<double> dailyEfforts) {
    if (dailyEfforts.isEmpty) return 0.0;
    final activeDays = dailyEfforts.where((e) => e > 0.0).toList();
    if (activeDays.isEmpty) return 0.0;

    final total = activeDays.fold(0.0, (sum, e) => sum + e);
    return double.parse((total / activeDays.length).toStringAsFixed(2));
  }
}
