import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../database/database_event_bus.dart';
import '../../database/models/beat_entity.dart';
import '../../database/models/chapter_entity.dart';
import '../../database/models/roadmap_entity.dart';
import '../../database/repositories/beat_repository.dart';
import '../../database/repositories/chapter_repository.dart';
import '../../database/repositories/roadmap_repository.dart';
import 'youtube_extractor_service.dart';

class ResourceSyncResult {
  final bool success;
  final String roadmapId;
  final String? roadmapTitle;
  final int updatedBeatsCount;
  final int newBeatsCount;
  final String? message;
  final String? discoveredUrl;

  const ResourceSyncResult({
    required this.success,
    required this.roadmapId,
    this.roadmapTitle,
    this.updatedBeatsCount = 0,
    this.newBeatsCount = 0,
    this.message,
    this.discoveredUrl,
  });

  @override
  String toString() =>
      'ResourceSyncResult(success: $success, roadmapId: $roadmapId, updated: $updatedBeatsCount, new: $newBeatsCount, msg: $message)';
}

/// Service to re-fetch live YouTube playlist and video metadata,
/// reconciling existing beats and appending newly published videos
/// while guaranteeing 0% data loss for completed status and progress.
class ResourceSyncService {
  final IYoutubeClient _youtubeClient;
  final RoadmapRepository _roadmapRepo;
  final ChapterRepository _chapterRepo;
  final BeatRepository _beatRepo;
  final DatabaseEventBus _eventBus;

  ResourceSyncService({
    IYoutubeClient? youtubeClient,
    RoadmapRepository? roadmapRepo,
    ChapterRepository? chapterRepo,
    BeatRepository? beatRepo,
    DatabaseEventBus? eventBus,
  })  : _youtubeClient = youtubeClient ?? YoutubeExtractorService(),
        _roadmapRepo = roadmapRepo ?? RoadmapRepository(),
        _chapterRepo = chapterRepo ?? ChapterRepository(),
        _beatRepo = beatRepo ?? BeatRepository(),
        _eventBus = eventBus ?? DatabaseEventBus.instance;

  /// Inspects roadmap metadata and beat source URLs to auto-discover
  /// the associated YouTube playlist or video URL.
  String? discoverResourceUrl({
    required RoadmapEntity roadmap,
    required List<BeatEntity> beats,
  }) {
    // 1. Check description or custom fields if they contain a URL
    if (roadmap.description != null && roadmap.description!.isNotEmpty) {
      final desc = roadmap.description!.trim();
      final pId = YoutubeExtractorService.parsePlaylistId(desc);
      if (pId != null) return 'https://www.youtube.com/playlist?list=$pId';
      final vId = YoutubeExtractorService.parseVideoId(desc);
      if (vId != null) return 'https://www.youtube.com/watch?v=$vId';
    }

    // 2. Check if any beat has a playlist ID in its URL
    for (final beat in beats) {
      if (beat.sourceUrl != null && beat.sourceUrl!.isNotEmpty) {
        final pId = YoutubeExtractorService.parsePlaylistId(beat.sourceUrl!);
        if (pId != null) {
          return 'https://www.youtube.com/playlist?list=$pId';
        }
      }
    }

    // 3. Check if beats share a common video ID (e.g. single-video crash course)
    final videoIds = <String>{};
    for (final beat in beats) {
      if (beat.sourceUrl != null && beat.sourceUrl!.isNotEmpty) {
        final vId = YoutubeExtractorService.parseVideoId(beat.sourceUrl!);
        if (vId != null) {
          videoIds.add(vId);
        }
      }
    }

    if (videoIds.length == 1) {
      return 'https://www.youtube.com/watch?v=${videoIds.first}';
    }

    // 4. If beats have multiple individual video URLs, return the first beat's video or playlist
    if (videoIds.isNotEmpty) {
      return 'https://www.youtube.com/watch?v=${videoIds.first}';
    }

    return null;
  }

  /// Synchronizes an existing roadmap against live YouTube data.
  /// 
  /// Guarantees:
  /// - `isCompleted`, `completedAt`, `completedParts`, and notes are NEVER overwritten.
  /// - Modified titles and fresh timestamps/durations are updated in SQLite.
  /// - Any newly uploaded videos in the playlist are appended to the curriculum.
  Future<ResourceSyncResult> syncRoadmapResource({
    required RoadmapEntity roadmap,
    String? overrideUrl,
  }) async {
    try {
      final existingBeats = await _beatRepo.getBeatsByRoadmapId(roadmap.id);
      final existingChapters = await _chapterRepo.getChaptersByRoadmapId(roadmap.id);

      final url = overrideUrl?.trim().isNotEmpty == true
          ? overrideUrl!.trim()
          : discoverResourceUrl(roadmap: roadmap, beats: existingBeats);

      if (url == null || url.isEmpty) {
        return ResourceSyncResult(
          success: false,
          roadmapId: roadmap.id,
          roadmapTitle: roadmap.title,
          message: 'No YouTube playlist or video URL could be detected for this track.',
        );
      }

      // Fetch live resource from YouTube
      final extracted = await _youtubeClient.extractResource(url);
      if (extracted.items.isEmpty) {
        return ResourceSyncResult(
          success: false,
          roadmapId: roadmap.id,
          roadmapTitle: roadmap.title,
          discoveredUrl: url,
          message: 'No lessons found at "$url". Verify URL accessibility.',
        );
      }

      int updatedBeatsCount = 0;
      int newBeatsCount = 0;

      // Index existing beats by Video ID + timestamp
      final existingByVideoKey = <String, BeatEntity>{};
      final existingByIndex = <int, BeatEntity>{};

      for (final beat in existingBeats) {
        if (beat.sourceUrl != null) {
          final vId = YoutubeExtractorService.parseVideoId(beat.sourceUrl!);
          if (vId != null) {
            existingByVideoKey[vId] ??= beat;
            if (beat.timestampSeconds != null) {
              existingByVideoKey['${vId}_${beat.timestampSeconds}'] = beat;
            }
          }
        }
        existingByIndex[beat.sortOrder] = beat;
      }

      // Ensure at least one chapter exists for new additions
      ChapterEntity targetChapter;
      if (existingChapters.isNotEmpty) {
        targetChapter = existingChapters.last;
      } else {
        targetChapter = ChapterEntity(
          id: '${roadmap.id}_ch_sync_1',
          roadmapId: roadmap.id,
          title: 'Curriculum',
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _chapterRepo.createChapter(targetChapter);
      }

      for (int i = 0; i < extracted.items.length; i++) {
        final item = extracted.items[i];
        final itemId = YoutubeExtractorService.parseVideoId(item.sourceUrl);
        final itemKey = (itemId != null && item.timestampSeconds != null)
            ? '${itemId}_${item.timestampSeconds}'
            : (itemId ?? '');

        // 1. Try to find existing beat by video key
        BeatEntity? matchedBeat = itemKey.isNotEmpty ? existingByVideoKey[itemKey] : null;

        // 2. If not matched, try matching by clean video ID
        if (matchedBeat == null && itemId != null) {
          matchedBeat = existingByVideoKey[itemId];
        }

        // 3. If single video course with timestamps, try index matching
        if (matchedBeat == null && extracted.items.length == existingBeats.length) {
          matchedBeat = existingByIndex[i];
        }

        if (matchedBeat != null) {
          // Reconcile: update title, duration, and timestamp if changed
          final newDurationEffort = item.durationSeconds > 0
              ? double.parse((item.durationSeconds / 3600.0).toStringAsFixed(1))
              : matchedBeat.effortWeight;
          final cleanTitle = item.title.trim();

          final bool titleChanged = cleanTitle.isNotEmpty && cleanTitle != matchedBeat.title;
          final bool timestampChanged = item.timestampSeconds != null &&
              item.timestampSeconds != matchedBeat.timestampSeconds;
          final bool effortChanged = newDurationEffort > 0 &&
              (newDurationEffort - matchedBeat.effortWeight).abs() > 0.05;

          if (titleChanged || timestampChanged || effortChanged) {
            final updated = matchedBeat.copyWith(
              title: cleanTitle.isNotEmpty ? cleanTitle : matchedBeat.title,
              timestampSeconds: item.timestampSeconds ?? matchedBeat.timestampSeconds,
              effortWeight: newDurationEffort > 0 ? newDurationEffort : matchedBeat.effortWeight,
              updatedAt: DateTime.now(),
              // CRITICAL: isCompleted, completedAt, completedParts are preserved!
            );
            await _beatRepo.updateBeat(updated);
            updatedBeatsCount++;
          }
        } else {
          // Newly published video detected in playlist -> Append to curriculum
          final newEffort = item.durationSeconds > 0
              ? double.parse((item.durationSeconds / 3600.0).toStringAsFixed(1))
              : 1.0;

          final newBeat = BeatEntity(
            id: '${roadmap.id}_sync_b_${i}_${DateTime.now().millisecondsSinceEpoch}',
            chapterId: targetChapter.id,
            roadmapId: roadmap.id,
            title: item.title.trim().isNotEmpty ? item.title.trim() : 'Lesson ${i + 1}',
            sourceUrl: item.sourceUrl,
            timestampSeconds: item.timestampSeconds,
            effortWeight: newEffort > 0 ? newEffort : 1.0,
            sortOrder: existingBeats.length + newBeatsCount,
            isCompleted: false,
            isMentorExtra: true, // Tag newly added playlist video as mentor extra
            totalParts: 1,
            completedParts: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _beatRepo.createBeat(newBeat);
          newBeatsCount++;
        }
      }

      // Notify database event bus so all screens update in real-time
      _eventBus.emit(DatabaseEvent(
        type: DatabaseEventType.roadmapUpdated,
        roadmapId: roadmap.id,
      ));

      return ResourceSyncResult(
        success: true,
        roadmapId: roadmap.id,
        roadmapTitle: roadmap.title,
        updatedBeatsCount: updatedBeatsCount,
        newBeatsCount: newBeatsCount,
        discoveredUrl: url,
        message: 'Synced with YouTube: updated $updatedBeatsCount topics'
            '${newBeatsCount > 0 ? ', added $newBeatsCount new lessons' : ''}',
      );
    } catch (e) {
      debugPrint('ResourceSyncService failed for roadmap ${roadmap.id}: $e');
      return ResourceSyncResult(
        success: false,
        roadmapId: roadmap.id,
        roadmapTitle: roadmap.title,
        message: 'Sync error: $e',
      );
    }
  }

  /// Batch syncs all provided roadmaps (e.g. post-backup enrichment).
  Future<List<ResourceSyncResult>> syncAllRoadmaps({
    List<RoadmapEntity>? roadmaps,
  }) async {
    final effectiveRoadmaps = roadmaps ?? await _roadmapRepo.getAllRoadmaps();
    final results = <ResourceSyncResult>[];

    for (final rm in effectiveRoadmaps) {
      try {
        final res = await syncRoadmapResource(roadmap: rm);
        results.add(res);
      } catch (e) {
        debugPrint('Batch sync skipped for roadmap ${rm.id}: $e');
      }
    }

    return results;
  }
}
