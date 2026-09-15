import 'dart:convert';
import 'dart:math' as math;
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

  /// Marks a concept as revised today, updating its stability and repetition interval.
  Future<RevisionItem> markTopicRevised(BeatEntity beat, {required String roadmapTitle}) async {
    await init();

    final now = DateTime.now();
    final existing = _records[beat.id];
    final currentCount = existing?.revisionCount ?? 0;
    final nextCount = currentCount + 1;

    // Expand stability: S_new = S_prev * 1.9 (or reset if previously flagged weak)
    final prevStability = existing?.stabilityDays ?? 1.0;
    final newStability = (prevStability * 1.9).clamp(1.5, 60.0);

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
      suggestedReason: 'Mastered in Spaced Revision',
    );

    _records[beat.id] = updated;
    await _persist();
    return updated;
  }

  /// Calculates mathematically prioritized revision suggestions for today across all trackers.
  Future<List<RevisionItem>> getDailyRevisionRecommendations({
    required List<RoadmapEntity> roadmaps,
    required Map<String, List<BeatEntity>> beatsByRoadmap,
    DateTime? referenceDate,
  }) async {
    await init();

    final today = referenceDate ?? DateTime.now();
    final List<RevisionItem> candidates = [];
    final roadmapMap = {for (final r in roadmaps) r.id: r.title};

    // Evaluate all completed beats and explicitly flagged beats
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

        // Calculate time elapsed since last revision or completion
        final lastAnchor = record?.lastRevisedAt ?? beat.updatedAt;
        final daysElapsed = math.max(0.05, today.difference(lastAnchor).inHours / 24.0);

        final stability = record?.stabilityDays ?? 1.0;

        // Ebbinghaus forgetting curve: R = e^(-t / S)
        final retention = math.exp(-daysElapsed / stability).clamp(0.01, 1.0);

        // Reason determination
        String reason;
        if (isFlagged) {
          reason = record?.flagNote != null && record!.flagNote!.isNotEmpty
              ? 'Flagged: "${record.flagNote}"'
              : 'Flagged Weak Concept • Needs Attention';
        } else if (retention < 0.5) {
          reason = 'Forgetting Curve Decay (${(retention * 100).round()}% retention)';
        } else if (daysElapsed >= stability) {
          reason = 'Spaced Cadence Review (Day ${daysElapsed.round()})';
        } else {
          reason = 'Foundational Recall Refresh';
        }

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
          ),
        );
      }
    }

    if (candidates.isEmpty) {
      return [];
    }

    // Sort by mathematical urgency score:
    // 1. Flagged weak gets highest priority (+2.5)
    // 2. Lower retention gets higher urgency ((1 - R) * 2.0)
    // 3. Lower revision count gets slight priority
    candidates.sort((a, b) {
      double scoreA = (a.isFlaggedWeak ? 2.5 : 0.0) + (1.0 - a.retentionScore) * 2.0 + (0.4 / (a.revisionCount + 1));
      double scoreB = (b.isFlaggedWeak ? 2.5 : 0.0) + (1.0 - b.retentionScore) * 2.0 + (0.4 / (b.revisionCount + 1));
      return scoreB.compareTo(scoreA);
    });

    // Return top high-yield recommendations (max 4 to keep focus sharp)
    // Only return items that actually need review (flagged OR retention < 0.85 OR daysElapsed >= stability)
    final filtered = candidates.where((item) {
      if (item.isFlaggedWeak) return true;
      if (item.retentionScore < 0.85) return true;
      final lastDate = item.lastRevisedAt;
      if (lastDate == null) return true; // never revised yet
      return today.difference(lastDate).inHours >= 18; // at least next day or spaced
    }).toList();

    return filtered.take(4).toList();
  }

  /// Helper to check if a specific beat is flagged as weak
  bool isBeatFlagged(String beatId) {
    return _records[beatId]?.isFlaggedWeak ?? false;
  }
}
