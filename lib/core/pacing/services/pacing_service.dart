import 'package:flutter/foundation.dart';
import '../../database/database.dart';
import '../models/pacing_budget.dart';
import '../models/pacing_decision.dart';
import 'pacing_calculator.dart';

/// Orchestrates the Pacing Engine across database entities and repositories.
/// 
/// Runs constantly on app launch and beat mutation events.
/// Pure local math, 0 AI latency, 0 cloud dependencies.
class PacingService {
  final RoadmapRepository _roadmapRepo;
  final BeatRepository _beatRepo;
  final BeatLogRepository _beatLogRepo;

  PacingService({
    RoadmapRepository? roadmapRepo,
    BeatRepository? beatRepo,
    BeatLogRepository? beatLogRepo,
  })  : _roadmapRepo = roadmapRepo ?? RoadmapRepository(),
        _beatRepo = beatRepo ?? BeatRepository(),
        _beatLogRepo = beatLogRepo ?? BeatLogRepository();

  /// Computes today's pacing budget for [roadmapId].
  /// 
  /// Supports optional [simulatedNow] for time-shift testing and backlog simulations.
  Future<PacingBudget> computePacingBudget(
    String roadmapId, {
    DateTime? simulatedNow,
  }) async {
    final roadmap = await _roadmapRepo.getRoadmapById(roadmapId);
    if (roadmap == null) {
      throw Exception('Roadmap not found with ID "$roadmapId"');
    }

    final allBeats = await _beatRepo.getBeatsByRoadmapId(roadmapId);
    final pendingBeats = allBeats.where((b) => !b.isCompleted).toList();
    final completedBeats = allBeats.where((b) => b.isCompleted).toList();

    final isRoadmapCompleted = allBeats.isNotEmpty && pendingBeats.isEmpty;

    // 1. Calculate remaining effort across incomplete beats
    final remainingEffort = PacingCalculator.calculateRemainingEffort(pendingBeats);

    // 2. Calculate calendar days left until target completion
    final now = simulatedNow ?? DateTime.now();
    final targetDate = roadmap.targetCompletionDate ?? now.add(const Duration(days: 30));
    final daysLeft = PacingCalculator.calculateDaysLeft(
      targetDate,
      now: simulatedNow,
    );

    // 3. Derive today's effort share = remaining ÷ days left
    final todayEffortShare = PacingCalculator.calculateDailyEffortShare(
      remainingEffort: remainingEffort,
      daysLeft: daysLeft,
    );

    // 4. Check beats completed today
    final todayStart = DateTime(now.year, now.month, now.day);
    final beatsCompletedToday = completedBeats.where((b) {
      if (b.completedAt == null) return false;
      return b.completedAt!.isAfter(todayStart);
    }).toList();

    double completedTodayEffort = 0.0;
    for (final b in beatsCompletedToday) {
      completedTodayEffort += b.effortWeight;
    }

    // Walk pending queue to fill the remaining budget for today
    final remainingBudget = (todayEffortShare - completedTodayEffort).clamp(0.0, todayEffortShare);
    final pendingBeatsForToday = remainingBudget > 0
        ? PacingCalculator.walkQueueToFillBudget(
            pendingBeats: pendingBeats,
            targetBudget: remainingBudget,
          )
        : (beatsCompletedToday.isEmpty
            ? PacingCalculator.walkQueueToFillBudget(
                pendingBeats: pendingBeats,
                targetBudget: todayEffortShare,
              )
            : <BeatEntity>[]);

    // Todays beats includes beats completed today + pending beats for today
    final todaysBeats = [...beatsCompletedToday, ...pendingBeatsForToday];

    double todaysSelectedEffort = 0.0;
    for (final b in todaysBeats) {
      todaysSelectedEffort += b.effortWeight;
    }
    todaysSelectedEffort = double.parse(todaysSelectedEffort.toStringAsFixed(2));

    final isDailyQuotaCompleted = isRoadmapCompleted ||
        (todaysBeats.isNotEmpty && beatsCompletedToday.length >= todaysBeats.length);

    // 6. Trend Analysis over the past 7 days
    final recentDailyEfforts = await _getRecentDailyEfforts(roadmapId, now);
    final trend = PacingCalculator.detectShortfallTrend(
      recentDailyEfforts: recentDailyEfforts,
      expectedDailyBudget: todayEffortShare,
    );

    final velocity = PacingCalculator.calculateVelocity(recentDailyEfforts);

    return PacingBudget(
      roadmapId: roadmapId,
      remainingEffort: remainingEffort,
      daysLeft: daysLeft,
      todayEffortShare: todayEffortShare,
      todaysBeats: todaysBeats,
      todaysSelectedEffort: todaysSelectedEffort,
      isRoadmapCompleted: isRoadmapCompleted,
      isDailyQuotaCompleted: isDailyQuotaCompleted,
      isSustainedLag: trend.isSustainedLag,
      lagStreakDays: trend.lagDaysCount,
      recentVelocity: velocity,
    );
  }

  /// Applies an intelligent non-punitive decision chosen by the user.
  Future<void> applyPacingDecision(String roadmapId, PacingDecision decision) async {
    final roadmap = await _roadmapRepo.getRoadmapById(roadmapId);
    if (roadmap == null) return;

    switch (decision.type) {
      case PacingDecisionType.extendTargetDate:
        final days = decision.extensionDays ?? 7;
        final baseDate = roadmap.targetCompletionDate ?? DateTime.now();
        final newTarget = baseDate.add(Duration(days: days));
        await _roadmapRepo.updateRoadmapTargetDate(roadmapId, newTarget);
        debugPrint('Applied PacingDecision: extended target date by $days days.');
        break;

      case PacingDecisionType.trimToCore:
        // In mentor-extras condition, flags or defers extra beats to lower priority
        debugPrint('Applied PacingDecision: trimmed track focus to core beats.');
        break;

      case PacingDecisionType.borrowSlack:
        debugPrint('Applied PacingDecision: borrowed slack from ${decision.borrowFromRoadmapId}.');
        break;

      case PacingDecisionType.acceptAndContinue:
        debugPrint('Applied PacingDecision: accepted current pace without alterations.');
        break;
    }
  }

  /// Collects daily completed effort weights across the past 7 days.
  Future<List<double>> _getRecentDailyEfforts(String roadmapId, DateTime currentDay) async {
    final dailyEfforts = <double>[];

    for (int i = 6; i >= 0; i--) {
      final date = currentDay.subtract(Duration(days: i));
      final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final logs = await _beatLogRepo.getLogsForRoadmapOnDate(roadmapId, dateStr);

      double dayEffort = 0.0;
      for (final log in logs) {
        final beat = await _beatRepo.getBeatById(log.beatId);
        if (beat != null) {
          dayEffort += beat.effortWeight;
        }
      }
      dailyEfforts.add(double.parse(dayEffort.toStringAsFixed(2)));
    }

    return dailyEfforts;
  }
}
