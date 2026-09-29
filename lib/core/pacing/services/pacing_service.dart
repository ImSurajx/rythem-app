import 'dart:async';
import '../../database/database.dart';
import '../models/pacing_budget.dart';
import '../models/study_intensity.dart';
import 'pacing_calculator.dart';

/// Orchestrates the Pacing Engine across database entities and repositories.
/// 
/// Runs on app launch and beat mutation events.
/// Pure local math, 0 AI latency, 0 cloud dependencies.
class PacingService {
  final RoadmapRepository _roadmapRepo;
  final BeatRepository _beatRepo;
  final AppSettingsRepository _settingsRepo;

  PacingService({
    RoadmapRepository? roadmapRepo,
    BeatRepository? beatRepo,
    AppSettingsRepository? settingsRepo,
  })  : _roadmapRepo = roadmapRepo ?? RoadmapRepository(),
        _beatRepo = beatRepo ?? BeatRepository(),
        _settingsRepo = settingsRepo ?? AppSettingsRepository();

  /// Computes today's pacing budget for [roadmapId].
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
    final isRoadmapCompleted = allBeats.isNotEmpty && pendingBeats.isEmpty;

    // 1. Calculate remaining effort across incomplete beats
    final remainingEffort = PacingCalculator.calculateRemainingEffort(pendingBeats);

    // 2. Determine schedule and track timeline
    final now = simulatedNow ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final trackStart = roadmap.startDate != null
        ? DateTime(roadmap.startDate!.year, roadmap.startDate!.month, roadmap.startDate!.day)
        : todayStart;
    final isUpcoming = todayStart.isBefore(trackStart);
    final daysUntilStart = isUpcoming ? trackStart.difference(todayStart).inDays : 0;

    if (isUpcoming) {
      final targetDate = roadmap.targetCompletionDate;
      final int daysLeft = targetDate != null
          ? PacingCalculator.calculateDaysLeft(targetDate, now: trackStart)
          : 30;

      return PacingBudget(
        roadmapId: roadmapId,
        remainingEffort: remainingEffort,
        daysLeft: daysLeft,
        todayEffortShare: 0.0,
        isRoadmapCompleted: false,
        isUpcoming: true,
        daysUntilStart: daysUntilStart,
      );
    }

    String? scheduleJson;
    try {
      scheduleJson = await _settingsRepo.getSetting('study_intensity_schedule');
    } catch (_) {}

    // Days left derived from roadmap target or default window
    final targetDate = roadmap.targetCompletionDate;
    final int daysLeft;
    if (targetDate != null) {
      daysLeft = PacingCalculator.calculateDaysLeft(targetDate, now: simulatedNow);
    } else {
      daysLeft = 30;
    }

    // 3. Derive today's effort share using goal date and study intensity schedule
    final double todayEffortShare;
    if (scheduleJson != null && scheduleJson.isNotEmpty) {
      final schedule = WeeklyStudySchedule.decode(scheduleJson);
      final todayIntensity = schedule.getIntensity(now.weekday);
      todayEffortShare = PacingCalculator.calculateRhythmAdjustedDailyShare(
        remainingEffort: remainingEffort,
        daysLeft: daysLeft,
        intensity: todayIntensity,
      );
    } else {
      todayEffortShare = PacingCalculator.calculateDailyEffortShare(
        remainingEffort: remainingEffort,
        daysLeft: daysLeft,
      );
    }

    return PacingBudget(
      roadmapId: roadmapId,
      remainingEffort: remainingEffort,
      daysLeft: daysLeft,
      todayEffortShare: todayEffortShare,
      isRoadmapCompleted: isRoadmapCompleted,
    );
  }
}
