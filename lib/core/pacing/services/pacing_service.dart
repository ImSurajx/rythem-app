import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../database/database.dart';
import '../models/pacing_budget.dart';
import '../models/pacing_decision.dart';
import '../models/study_intensity.dart';
import 'pacing_calculator.dart';

/// Orchestrates the Pacing Engine across database entities and repositories.
/// 
/// Runs constantly on app launch and beat mutation events.
/// Pure local math, 0 AI latency, 0 cloud dependencies.
class PacingService {
  final RoadmapRepository _roadmapRepo;
  final ChapterRepository _chapterRepo;
  final BeatRepository _beatRepo;
  final BeatLogRepository _beatLogRepo;
  final AppSettingsRepository _settingsRepo;
  final DatabaseEventBus _eventBus;

  PacingService({
    RoadmapRepository? roadmapRepo,
    ChapterRepository? chapterRepo,
    BeatRepository? beatRepo,
    BeatLogRepository? beatLogRepo,
    AppSettingsRepository? settingsRepo,
    DatabaseEventBus? eventBus,
  })  : _roadmapRepo = roadmapRepo ?? RoadmapRepository(),
        _chapterRepo = chapterRepo ?? ChapterRepository(),
        _beatRepo = beatRepo ?? BeatRepository(),
        _beatLogRepo = beatLogRepo ?? BeatLogRepository(),
        _settingsRepo = settingsRepo ?? AppSettingsRepository(),
        _eventBus = eventBus ?? DatabaseEventBus.instance;

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

    final chapters = await _chapterRepo.getChaptersByRoadmapId(roadmapId);
    final chapterOrderMap = {for (final c in chapters) c.id: c.sortOrder};

    final allBeats = await _beatRepo.getBeatsByRoadmapId(roadmapId);
    final pendingBeats = allBeats.where((b) => !b.isCompleted).toList();
    final completedBeats = allBeats.where((b) => b.isCompleted).toList();

    final isRoadmapCompleted = allBeats.isNotEmpty && pendingBeats.isEmpty;

    // 1. Calculate remaining effort across incomplete beats
    final remainingEffort = PacingCalculator.calculateRemainingEffort(pendingBeats);

    // 2. Fetch 7-day weekly study schedule to determine today's intensity and target effort
    final now = simulatedNow ?? DateTime.now();
    String? scheduleJson;
    try {
      scheduleJson = await _settingsRepo.getSetting('study_intensity_schedule');
    } catch (_) {}

    // Days left derived from roadmap target or weekly pacing velocity
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

    // 4. Check beats completed today
    final todayStart = DateTime(now.year, now.month, now.day);
    final beatsCompletedToday = completedBeats.where((b) {
      if (b.completedAt == null) return false;
      return b.completedAt!.isAfter(todayStart);
    }).toList();

    // 5. Daily Mission Persistence & Strikethrough Stability
    // Locks today's mission beat IDs for today's date so completing task #1 never causes task #2 or #3 to vanish.
    final todayDateStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final missionKey = 'daily_mission_beats_${roadmapId}_$todayDateStr';

    List<BeatEntity> todaysBeats;
    String? lockedMissionJson;
    try {
      lockedMissionJson = await _settingsRepo.getSetting(missionKey);
    } catch (_) {}

    if (lockedMissionJson != null && lockedMissionJson.isNotEmpty) {
      List<dynamic> rawIds = [];
      try {
        rawIds = jsonDecode(lockedMissionJson) as List<dynamic>;
      } catch (_) {}

      final lockedIds = rawIds.map((e) => e.toString()).toSet();
      final allMissionIds = <String>{...lockedIds, ...beatsCompletedToday.map((b) => b.id)};

      // Preserve strict sequential chapter-first ordering from allBeats
      todaysBeats = allBeats.where((b) => allMissionIds.contains(b.id)).toList();

      // If all locked mission beats are completed, mission is 100% complete for the day.
      // No surprise bumps or moving goalposts: respects Evening Unlock rest state.
    } else {
      // First calculation of the day: walk sequential pending queue to establish today's mission
      final plannedBeats = PacingCalculator.walkQueueToFillBudget(
        pendingBeats: pendingBeats,
        targetBudget: todayEffortShare > 0 ? todayEffortShare : 1.0,
        chapterOrderMap: chapterOrderMap,
      );

      final missionIds = <String>{...beatsCompletedToday.map((b) => b.id), ...plannedBeats.map((b) => b.id)};
      todaysBeats = allBeats.where((b) => missionIds.contains(b.id)).toList();

      if (missionIds.isNotEmpty) {
        unawaited(_settingsRepo.setSetting(missionKey, jsonEncode(missionIds.toList())));
      }
    }

    double todaysSelectedEffort = 0.0;
    for (final b in todaysBeats) {
      todaysSelectedEffort += b.effortWeight;
    }
    todaysSelectedEffort = double.parse(todaysSelectedEffort.toStringAsFixed(2));

    final completedInMission = todaysBeats.where((b) => b.isCompleted).toList();
    final isDailyQuotaCompleted = isRoadmapCompleted ||
        (todaysBeats.isNotEmpty && completedInMission.length >= todaysBeats.length);


    // 6. Trend Analysis over the past 7 completed days using math & weekly schedule
    final schedule = await _getWeeklySchedule();
    final pastRecords = await _getRecentDailyRecords(roadmapId, now, schedule, todayEffortShare);

    final trend = PacingCalculator.evaluateShortfallWithSchedule(
      pastDaysRecords: pastRecords,
      baseDailyBudget: todayEffortShare,
    );

    final recentCompletedEfforts = pastRecords.map((r) => r.completedEffort).toList();
    final velocity = PacingCalculator.calculateVelocity(recentCompletedEfforts);

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
      shortfallDebt: trend.shortfallDebt,
      velocityDeficit: trend.velocityDeficit,
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
        // Lower effort weight of non-completed mentor extra beats to ease cognitive load
        final allBeats = await _beatRepo.getBeatsByRoadmapId(roadmapId);
        final pendingMentorExtras = allBeats.where((b) => b.isMentorExtra && !b.isCompleted);
        for (final b in pendingMentorExtras) {
          await _beatRepo.updateBeatEffortWeight(b.id, 0.0);
        }
        debugPrint('Applied PacingDecision: trimmed track focus to core beats.');
        break;

      case PacingDecisionType.borrowSlack:
        // Extend target date by 4 days to absorb borrowed slack across tracks
        final baseDate = roadmap.targetCompletionDate ?? DateTime.now();
        final newTarget = baseDate.add(const Duration(days: 4));
        await _roadmapRepo.updateRoadmapTargetDate(roadmapId, newTarget);
        debugPrint('Applied PacingDecision: borrowed slack from ${decision.borrowFromRoadmapId}.');
        break;

      case PacingDecisionType.acceptAndContinue:
        debugPrint('Applied PacingDecision: accepted current pace without alterations.');
        break;
    }

    // Save recalibration timestamp so past shortfall days don't penalize the user
    await _settingsRepo.setSetting('last_recalibrated_$roadmapId', DateTime.now().toIso8601String());
    // Invalidate cached daily mission so the new recalibrated pace takes effect immediately
    await _settingsRepo.removeSettingsStartingWith('daily_mission_beats_${roadmapId}_');

    // Emit event to update UI and stream listeners
    _eventBus.emit(DatabaseEvent(
      type: DatabaseEventType.roadmapUpdated,
      entityId: roadmapId,
      roadmapId: roadmapId,
    ));

  }

  /// Voluntarily pulls the next sequential beat from the track queue into today's mission
  /// when the user chooses to "Study Ahead" without forced surprise bumps.
  Future<BeatEntity?> pullNextBeatIntoMission(String roadmapId, {DateTime? simulatedNow}) async {
    final now = simulatedNow ?? DateTime.now();
    final todayDateStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final missionKey = 'daily_mission_beats_${roadmapId}_$todayDateStr';

    final allBeats = await _beatRepo.getBeatsByRoadmapId(roadmapId);
    final pendingBeats = allBeats.where((b) => !b.isCompleted).toList();
    if (pendingBeats.isEmpty) return null;

    final chapters = await _chapterRepo.getChaptersByRoadmapId(roadmapId);
    final chapterOrderMap = {for (final c in chapters) c.id: c.sortOrder};

    String? lockedMissionJson;
    try {
      lockedMissionJson = await _settingsRepo.getSetting(missionKey);
    } catch (_) {}

    final currentIds = <String>{};
    if (lockedMissionJson != null && lockedMissionJson.isNotEmpty) {
      try {
        final list = jsonDecode(lockedMissionJson) as List<dynamic>;
        currentIds.addAll(list.map((e) => e.toString()));
      } catch (_) {}
    }

    final candidates = PacingCalculator.walkQueueToFillBudget(
      pendingBeats: pendingBeats.where((b) => !currentIds.contains(b.id)).toList(),
      targetBudget: 0.1, // Pull exactly 1 beat
      chapterOrderMap: chapterOrderMap,
    );

    if (candidates.isNotEmpty) {
      currentIds.add(candidates.first.id);
      await _settingsRepo.setSetting(missionKey, jsonEncode(currentIds.toList()));
      _eventBus.emit(DatabaseEvent(
        type: DatabaseEventType.roadmapUpdated,
        roadmapId: roadmapId,
      ));
      return candidates.first;
    }
    return null;
  }

  Future<WeeklyStudySchedule> _getWeeklySchedule() async {
    try {
      final raw = await _settingsRepo.getSetting('study_intensity_schedule');
      if (raw == null || raw.isEmpty) {
        return WeeklyStudySchedule.defaultSchedule();
      }
      return WeeklyStudySchedule.decode(raw);
    } catch (_) {
      return WeeklyStudySchedule.defaultSchedule();
    }
  }

  /// Collects daily completed effort and target records across the past 7 completed days (yesterday backwards).
  /// Excludes days prior to roadmap creation and days on/prior to user's last recalibration.
  Future<List<DailyPacingRecord>> _getRecentDailyRecords(
    String roadmapId,
    DateTime currentDay,
    WeeklyStudySchedule schedule,
    double baseDailyBudget,
  ) async {
    final roadmap = await _roadmapRepo.getRoadmapById(roadmapId);
    if (roadmap == null) return [];

    final trackStart = DateTime(roadmap.createdAt.year, roadmap.createdAt.month, roadmap.createdAt.day);

    DateTime? recalibratedDate;
    try {
      final recalibratedStr = await _settingsRepo.getSetting('last_recalibrated_$roadmapId');
      if (recalibratedStr != null && recalibratedStr.isNotEmpty) {
        final parsed = DateTime.tryParse(recalibratedStr);
        if (parsed != null) {
          recalibratedDate = DateTime(parsed.year, parsed.month, parsed.day);
        }
      }
    } catch (_) {}

    final records = <DailyPacingRecord>[];

    // Evaluate strictly past completed days: i = 1 (yesterday) to 7 (7 days ago)
    for (int i = 1; i <= 7; i++) {
      final date = currentDay.subtract(Duration(days: i));
      final dayNormalized = DateTime(date.year, date.month, date.day);

      // Never count days before the roadmap was created!
      if (dayNormalized.isBefore(trackStart)) {
        continue;
      }

      // If user recalibrated, skip days on or prior to the recalibration date!
      if (recalibratedDate != null && !dayNormalized.isAfter(recalibratedDate)) {
        continue;
      }

      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final logs = await _beatLogRepo.getLogsForRoadmapOnDate(roadmapId, dateStr);

      double dayEffort = 0.0;
      for (final log in logs) {
        final beat = await _beatRepo.getBeatById(log.beatId);
        if (beat != null) {
          dayEffort += beat.effortWeight;
        }
      }

      final intensity = schedule.getIntensity(date.weekday);
      final isRest = intensity == StudyIntensity.rest;
      // Daily target scaled to intensity (normal = 1.0x baseline, light = 0.5x, intense = 1.5x)
      final targetEffort = isRest ? 0.0 : (baseDailyBudget * (intensity.targetEffort / 4.0)).clamp(0.5, 12.0);

      records.add(DailyPacingRecord(
        date: date,
        completedEffort: double.parse(dayEffort.toStringAsFixed(2)),
        targetEffort: double.parse(targetEffort.toStringAsFixed(2)),
        isRestDay: isRest,
      ));
    }

    return records;
  }
}
