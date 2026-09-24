import 'dart:convert';
import 'dart:math' as math;
import '../../ai/services/local_inference_service.dart';
import '../../database/models/beat_entity.dart';
import '../../database/models/roadmap_entity.dart';
import '../../database/repositories/app_settings_repository.dart';
import '../models/revision_item.dart';

/// Spaced-Repetition Revision Service powered by Ebbinghaus Forgetting Curve mathematics
/// and on-device concept difficulty flagging.
class RevisionService {
  static const String _settingsKey = 'revision_system_records';

  final AppSettingsRepository _settingsRepo;
  Map<String, RevisionItem> _records = {};
  bool _isLoaded = false;

  RevisionService({AppSettingsRepository? settingsRepo})
      : _settingsRepo = settingsRepo ?? AppSettingsRepository();

  /// Loads stored revision metadata from SQLite.
  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final raw = await _settingsRepo.getSetting(_settingsKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(raw) as Map<String, dynamic>;
        _records = decoded.map(
          (key, value) => MapEntry(key, RevisionItem.fromMap(value as Map<String, dynamic>)),
        );
      }
    } catch (_) {}
    _isLoaded = true;
  }

  /// Persists revision records to SQLite app_settings.
  Future<void> _persist() async {
    try {
      final map = _records.map((k, v) => MapEntry(k, v.toMap()));
      await _settingsRepo.setSetting(_settingsKey, json.encode(map));
    } catch (_) {}
  }

  /// Flags a beat/topic for attention or revision with an optional friction note.
  Future<void> flagTopicForRevision({
    required BeatEntity beat,
    required String roadmapTitle,
    String? note,
    bool isWeak = true,
  }) async {
    await init();

    final existing = _records[beat.id];
    final updated = RevisionItem(
      beatId: beat.id,
      roadmapId: beat.roadmapId,
      roadmapTitle: roadmapTitle,
      title: beat.title,
      isFlaggedWeak: isWeak,
      flagNote: note ?? existing?.flagNote,
      lastRevisedAt: existing?.lastRevisedAt,
      revisionCount: existing?.revisionCount ?? 0,
      stabilityDays: isWeak ? 0.75 : (existing?.stabilityDays ?? 1.0),
      retentionScore: 0.25,
      suggestedReason: isWeak ? 'Flagged Weak Concept' : 'Flagged for Review',
    );

    _records[beat.id] = updated;
    await _persist();
  }

  /// Removes a flag from a topic.
  Future<void> unflagTopic(String beatId) async {
    await init();
    if (_records.containsKey(beatId)) {
      final existing = _records[beatId]!;
      _records[beatId] = existing.copyWith(isFlaggedWeak: false);
      await _persist();
    }
  }

  /// Adds or updates a topic on the Spaced Revision Shelf with an optional spaced interval.
  Future<RevisionItem> addToRevisionShelf({
    required BeatEntity beat,
    required String roadmapTitle,
    int? intervalDays,
    String? note,
  }) async {
    await init();

    final now = DateTime.now();
    final scheduledDate = intervalDays != null
        ? DateTime(now.year, now.month, now.day).add(Duration(days: intervalDays))
        : null;

    final existing = _records[beat.id];
    final updated = RevisionItem(
      beatId: beat.id,
      roadmapId: beat.roadmapId,
      roadmapTitle: roadmapTitle,
      title: beat.title,
      isFlaggedWeak: existing?.isFlaggedWeak ?? false,
      flagNote: note ?? existing?.flagNote,
      lastRevisedAt: existing?.lastRevisedAt,
      revisionCount: existing?.revisionCount ?? 0,
      stabilityDays: existing?.stabilityDays ?? (intervalDays != null ? intervalDays.toDouble() : 1.0),
      retentionScore: existing?.retentionScore ?? 1.0,
      suggestedReason: intervalDays != null
          ? 'Scheduled review in $intervalDays days'
          : 'Saved in shelf for on-demand practice',
      isCompleted: false,
      scheduledReviewDate: scheduledDate,
      intervalDays: intervalDays,
    );

    _records[beat.id] = updated;
    await _persist();
    return updated;
  }

  /// Removes a topic completely from the Revision Shelf.
  Future<void> removeFromRevisionShelf(String beatId) async {
    await init();
    if (_records.containsKey(beatId)) {
      _records.remove(beatId);
      await _persist();
    }
  }

  /// Retrieves all items currently stored in the revision shelf.
  Future<List<RevisionItem>> getRevisionShelfItems() async {
    await init();
    final list = _records.values.toList();
    list.sort((a, b) {
      if (a.isDueToday && !b.isDueToday) return -1;
      if (!a.isDueToday && b.isDueToday) return 1;
      if (a.scheduledReviewDate != null && b.scheduledReviewDate != null) {
        return a.scheduledReviewDate!.compareTo(b.scheduledReviewDate!);
      }
      if (a.scheduledReviewDate != null) return -1;
      if (b.scheduledReviewDate != null) return 1;
      return a.title.compareTo(b.title);
    });
    return list;
  }

  /// Checks if a beat is currently stored in the revision shelf.
  bool isInRevisionShelf(String beatId) {
    return _records.containsKey(beatId);
  }

  /// Marks a concept as revised today, updating its stability and repetition interval.
  Future<RevisionItem> markTopicRevised(BeatEntity beat, {required String roadmapTitle}) async {
    await init();

    final now = DateTime.now();
    final existing = _records[beat.id];
    final currentCount = existing?.revisionCount ?? 0;
    final nextCount = currentCount + 1;

    // Expand stability: S_new = S_prev * 2.2
    final prevStability = existing?.stabilityDays ?? 1.0;
    final newStability = (prevStability * 2.2).clamp(1.5, 90.0);

    final reason = nextCount >= 3
        ? 'Strongest Mastery Achieved'
        : (nextCount == 2
            ? 'Strengthened (2x Revised)'
            : 'Strengthening (1x Revised)');

    final updated = RevisionItem(
      beatId: beat.id,
      roadmapId: beat.roadmapId,
      roadmapTitle: roadmapTitle,
      title: beat.title,
      isFlaggedWeak: false, // successfully revised
      flagNote: existing?.flagNote,
      lastRevisedAt: now,
      revisionCount: nextCount,
      stabilityDays: newStability,
      retentionScore: 1.0,
      suggestedReason: reason,
      isCompleted: true,
      scheduledReviewDate: existing?.scheduledReviewDate,
      intervalDays: existing?.intervalDays,
    );

    _records[beat.id] = updated;
    await _persist();
    return updated;
  }

  /// Reverts a topic's revision state if toggled off.
  Future<RevisionItem?> unmarkTopicRevised(BeatEntity beat, {required String roadmapTitle}) async {
    await init();
    final existing = _records[beat.id];
    if (existing != null) {
      final prevCount = math.max(0, existing.revisionCount - 1);
      final prevStability = (existing.stabilityDays / 2.2).clamp(1.0, 90.0);
      final wasWeak = existing.flagNote != null && existing.flagNote!.isNotEmpty;
      final updated = existing.copyWith(
        lastRevisedAt: null,
        revisionCount: prevCount,
        stabilityDays: prevStability,
        retentionScore: 0.60,
        suggestedReason: wasWeak ? 'Flagged: "${existing.flagNote}"' : 'Scheduled Review',
        isFlaggedWeak: wasWeak,
        isCompleted: false,
      );
      _records[beat.id] = updated;
      await _persist();
      return updated;
    }
    return null;
  }

  /// Calculates AI-First + Mathematically governed revision suggestions for today across all trackers.
  Future<List<RevisionItem>> getDailyRevisionRecommendations({
    required List<RoadmapEntity> roadmaps,
    required Map<String, List<BeatEntity>> beatsByRoadmap,
    List<BeatEntity>? upcomingFocusBeats,
    double? todayEffortBudget,
    LocalInferenceService? inferenceService,
    DateTime? referenceDate,
  }) async {
    await init();

    final today = referenceDate ?? DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final List<RevisionItem> candidates = [];
    final List<RevisionItem> completedTodayItems = [];
    final roadmapMap = {for (final r in roadmaps) r.id: r.title};

    // 1. AI-First Analysis Stage:
    // Gather all completed past beats and weak concept notes across roadmaps
    final allCompletedBeats = <BeatEntity>[];
    for (final beats in beatsByRoadmap.values) {
      allCompletedBeats.addAll(beats.where((b) => b.isCompleted));
    }

    final weakNotes = <String, String>{};
    for (final entry in _records.entries) {
      if (entry.value.flagNote != null && entry.value.flagNote!.isNotEmpty) {
        weakNotes[entry.key] = entry.value.flagNote!;
      }
    }

    final aiService = inferenceService ?? LocalInferenceService();
    final aiEvaluations = await aiService.rankRevisionCandidatesAI(
      upcomingFocusBeats: upcomingFocusBeats ?? [],
      completedCandidates: allCompletedBeats,
      weakNotesByBeatId: weakNotes,
    );
    final aiEvalMap = {for (final eval in aiEvaluations) eval.beatId: eval};

    // 2. Mathematical Spaced-Repetition Governor Stage:
    // Evaluate memory decay, stability multipliers, and time elapsed
    for (final entry in beatsByRoadmap.entries) {
      final roadmapId = entry.key;
      final roadmapTitle = roadmapMap[roadmapId] ?? 'Active Tracker';
      final beats = entry.value;

      for (final beat in beats) {
        final record = _records[beat.id];
        final isCompleted = beat.isCompleted;
        final isFlagged = record?.isFlaggedWeak ?? false;

        // Candidate must be completed OR explicitly flagged
        if (!isCompleted && !isFlagged) continue;

        // If explicitly scheduled for a future date, do not recommend today
        if (record?.scheduledReviewDate != null && !record!.isDueToday) {
          continue;
        }

        // Topics completed today do not need same-day revision unless explicitly flagged weak
        if (!isFlagged && beat.completedAt != null && beat.completedAt!.isAfter(todayStart) && record?.lastRevisedAt == null) {
          continue;
        }

        // Check if revised today: retain on board with completed/strikethrough state
        if (!isFlagged && record?.lastRevisedAt != null && record!.lastRevisedAt!.isAfter(todayStart)) {
          final aiEval = aiEvalMap[beat.id];
          completedTodayItems.add(
            RevisionItem(
              beatId: beat.id,
              roadmapId: roadmapId,
              roadmapTitle: roadmapTitle,
              title: beat.title,
              isFlaggedWeak: false,
              flagNote: record.flagNote,
              lastRevisedAt: record.lastRevisedAt,
              revisionCount: record.revisionCount,
              stabilityDays: record.stabilityDays,
              retentionScore: 1.0,
              suggestedReason: record.revisionCount >= 3
                  ? 'Mastered Concept (Revised Today)'
                  : 'Strengthened (Revised Today)',
              microRecallPrompt: aiEval?.microRecallPrompt,
              prerequisiteTargetTitle: aiEval?.prerequisiteForTitle,
              beatPoints: (aiEval?.isPrerequisite == true || isFlagged) ? 1.0 : 0.5,
              isCompleted: true,
              scheduledReviewDate: record.scheduledReviewDate,
              intervalDays: record.intervalDays,
            ),
          );
          continue;
        }

        // Calculate time elapsed since last revision or completion
        final lastAnchor = record?.lastRevisedAt ?? beat.completedAt ?? beat.updatedAt;
        final daysElapsed = math.max(0.05, today.difference(lastAnchor).inHours / 24.0);
        final stability = record?.stabilityDays ?? 1.0;

        // Ebbinghaus forgetting curve: R = e^(-t / S)
        final retention = math.exp(-daysElapsed / stability).clamp(0.01, 1.0);

        final aiEval = aiEvalMap[beat.id];
        final isDirectPrereq = aiEval?.isPrerequisite ?? false;

        // Filter: Must be flagged, low retention (< 0.85), direct prerequisite to today, or spaced >= 2.5 days
        if (!isFlagged && !isDirectPrereq && retention >= 0.85 && daysElapsed < 2.5 && record?.isCompleted != false) {
          continue;
        }

        final reason = isFlagged
            ? (record?.flagNote != null && record!.flagNote!.isNotEmpty
                ? 'Flagged: "${record.flagNote}"'
                : 'Flagged topic • Needs review')
            : (aiEval?.contextualReason ??
                (daysElapsed >= 14
                    ? 'Studied 2+ weeks ago • Refresh so you don\'t forget'
                    : (daysElapsed >= 6
                        ? 'Studied last week • High-impact review'
                        : 'Studied ${daysElapsed.round()} days ago • Quick recall')));

        final prompt = aiEval?.microRecallPrompt ??
            'Memory Refresh: 30-second mental recap of "${beat.title}".';

        final points = (isDirectPrereq || isFlagged) ? 1.0 : 0.5;

        candidates.add(
          RevisionItem(
            beatId: beat.id,
            roadmapId: roadmapId,
            roadmapTitle: roadmapTitle,
            title: beat.title,
            isFlaggedWeak: isFlagged,
            flagNote: record?.flagNote,
            lastRevisedAt: record?.lastRevisedAt,
            revisionCount: record?.revisionCount ?? 0,
            stabilityDays: stability,
            retentionScore: retention,
            suggestedReason: reason,
            microRecallPrompt: prompt,
            prerequisiteTargetTitle: aiEval?.prerequisiteForTitle,
            beatPoints: points,
            isCompleted: false,
            scheduledReviewDate: record?.scheduledReviewDate,
            intervalDays: record?.intervalDays,
          ),
        );
      }
    }

    if (candidates.isEmpty && completedTodayItems.isEmpty) {
      return [];
    }

    // 3. Unified AI-First + Mathematical Ranking:
    // AI semantic prerequisite score is the primary driver (weight 3.5),
    // boosted by flagged weaknesses (+2.5) and memory decay (+2.0)
    candidates.sort((a, b) {
      final aiA = aiEvalMap[a.beatId]?.aiScore ?? 0.2;
      final aiB = aiEvalMap[b.beatId]?.aiScore ?? 0.2;

      final scoreA = (aiA * 3.5) +
          (a.isFlaggedWeak ? 2.5 : 0.0) +
          (1.0 - a.retentionScore) * 2.0 +
          (0.4 / (a.revisionCount + 1));

      final scoreB = (aiB * 3.5) +
          (b.isFlaggedWeak ? 2.5 : 0.0) +
          (1.0 - b.retentionScore) * 2.0 +
          (0.4 / (b.revisionCount + 1));

      return scoreB.compareTo(scoreA);
    });

    // 4. Mathematical Guardrails: Dynamic Energy Budget
    // Heavy study day (>= 2.5 effort units) -> strictly 1 topic (5 mins max)
    // Light study day (< 2.5 effort units) -> max 2 topics (10 mins max)
    final maxSuggestions = (todayEffortBudget != null && todayEffortBudget >= 2.5) ? 1 : 2;
    final remainingSlots = math.max(0, maxSuggestions - completedTodayItems.length);
    final pendingToTake = candidates.take(remainingSlots).toList();

    return [...completedTodayItems, ...pendingToTake];
  }

  /// Helper to check if a specific beat is flagged as weak
  bool isBeatFlagged(String beatId) {
    return _records[beatId]?.isFlaggedWeak ?? false;
  }
}
