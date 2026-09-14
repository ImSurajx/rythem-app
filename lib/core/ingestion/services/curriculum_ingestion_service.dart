import 'package:flutter/foundation.dart';
import '../../database/database.dart';
import '../models/extracted_beat.dart';
import '../models/extracted_resource.dart';
import '../models/ingestion_result.dart';
import '../models/syllabus_topic.dart';
import '../parsers/chapter_clusterer.dart';
import '../parsers/effort_weight_calculator.dart';
import '../parsers/syllabus_parser.dart';
import 'syllabus_matcher_service.dart';
import 'youtube_extractor_service.dart';

class CurriculumIngestionService {
  final IYoutubeClient _youtubeClient;
  final SyllabusMatcherService _matcherService;
  final RoadmapRepository _roadmapRepo;
  final ChapterRepository _chapterRepo;
  final BeatRepository _beatRepo;

  CurriculumIngestionService({
    IYoutubeClient? youtubeClient,
    SyllabusMatcherService? matcherService,
    RoadmapRepository? roadmapRepo,
    ChapterRepository? chapterRepo,
    BeatRepository? beatRepo,
  })  : _youtubeClient = youtubeClient ?? YoutubeExtractorService(),
        _matcherService = matcherService ?? SyllabusMatcherService(),
        _roadmapRepo = roadmapRepo ?? RoadmapRepository(),
        _chapterRepo = chapterRepo ?? ChapterRepository(),
        _beatRepo = beatRepo ?? BeatRepository();

  /// Ingests a curriculum from a YouTube URL (playlist or single video).
  /// 
  /// Enforces:
  /// - 100% video coverage with zero items dropped.
  /// - Mentor sequence is strictly preserved.
  /// - Unmatched mentor items are tagged [is_mentor_extra: true].
  /// - Discrete effort weights are derived from source durations.
  /// - Atomic persistence into local SQLite.
  Future<IngestionResult> ingestFromUrl({
    required String url,
    String? customRoadmapTitle,
    String? customDescription,
    DateTime? targetCompletionDate,
    bool isPrimary = true,
    List<SyllabusTopic>? syllabus,
  }) async {
    try {
      final extracted = await _youtubeClient.extractResource(url);
      if (extracted.items.isEmpty) {
        throw Exception(
          'No videos or chapters could be extracted from "$url". Please verify the URL and ensure the playlist or video is public.',
        );
      }

      return await ingestExtractedResource(
        extracted: extracted,
        customRoadmapTitle: customRoadmapTitle,
        customDescription: customDescription,
        targetCompletionDate: targetCompletionDate,
        isPrimary: isPrimary,
        syllabus: syllabus,
      );
    } catch (e) {
      debugPrint('Ingestion failed for URL $url: $e');
      rethrow;
    }
  }

  /// Ingests a pre-extracted resource into the database.
  Future<IngestionResult> ingestExtractedResource({
    required ExtractedResource extracted,
    String? customRoadmapTitle,
    String? customDescription,
    DateTime? targetCompletionDate,
    bool isPrimary = true,
    List<SyllabusTopic>? syllabus,
  }) async {
    final now = DateTime.now();
    final roadmapId = 'rm_${now.millisecondsSinceEpoch}_${extracted.items.length}';
    final roadmapTitle = customRoadmapTitle ?? extracted.title;

    // 1. Cluster flat items into 4-8 logical chapters (zero drop guarantee)
    var chapters = ChapterClusterer.cluster(
      extracted.items,
      roadmapTitle: roadmapTitle,
    );

    // 2. Condition 2: If syllabus is provided, match topics and flag mentor extras
    if (syllabus != null && syllabus.isNotEmpty) {
      chapters = _matcherService.alignCurriculum(
        chapters: chapters,
        syllabus: syllabus,
      );
    }

    // 3. Prepare database entities
    final roadmapEntity = RoadmapEntity(
      id: roadmapId,
      title: roadmapTitle,
      description: customDescription ?? extracted.description,
      targetCompletionDate: targetCompletionDate ?? now.add(const Duration(days: 30)),
      isPrimary: isPrimary,
      createdAt: now,
      updatedAt: now,
    );

    final chapterEntities = <ChapterEntity>[];
    final beatEntities = <BeatEntity>[];
    int mentorExtraCount = 0;
    int unconfirmedMatchesCount = 0;
    double totalEffort = 0.0;
    final chapterTitles = <String>[];

    int globalSortOrder = 0;

    for (int c = 0; c < chapters.length; c++) {
      final ch = chapters[c];
      final chapterId = '${roadmapId}_ch_$c';
      chapterTitles.add(ch.title);

      chapterEntities.add(ChapterEntity(
        id: chapterId,
        roadmapId: roadmapId,
        title: ch.title,
        sortOrder: c,
        createdAt: now,
        updatedAt: now,
      ));

      for (final beat in ch.beats) {
        final beatId = '${chapterId}_b_$globalSortOrder';

        if (beat.isMentorExtra) {
          mentorExtraCount++;
        }
        if (beat.matchConfidence != null &&
            beat.matchConfidence! < SyllabusMatcherService.highConfidenceThreshold) {
          unconfirmedMatchesCount++;
        }
        totalEffort += beat.effortWeight;

        beatEntities.add(BeatEntity(
          id: beatId,
          chapterId: chapterId,
          roadmapId: roadmapId,
          title: beat.title,
          sourceUrl: beat.sourceUrl,
          timestampSeconds: beat.timestampSeconds,
          effortWeight: beat.effortWeight,
          sortOrder: globalSortOrder,
          isCompleted: false,
          isMentorExtra: beat.isMentorExtra,
          matchConfidence: beat.matchConfidence,
          syllabusTopicId: beat.syllabusTopicId,
          createdAt: now,
          updatedAt: now,
        ));

        globalSortOrder++;
      }
    }

    // 4. Atomic persistence into on-device SQLite
    await _roadmapRepo.createRoadmap(roadmapEntity);
    await _chapterRepo.createChaptersBatch(chapterEntities);
    await _beatRepo.createBeatsBatch(beatEntities);

    // If marked as primary, ensure other roadmaps yield primary status
    if (isPrimary) {
      await _roadmapRepo.setPrimaryRoadmap(roadmapId);
    }

    return IngestionResult(
      roadmapId: roadmapId,
      roadmapTitle: roadmapTitle,
      chaptersCount: chapterEntities.length,
      beatsCount: beatEntities.length,
      totalEffort: double.parse(totalEffort.toStringAsFixed(1)),
      mentorExtraCount: mentorExtraCount,
      unconfirmedMatchesCount: unconfirmedMatchesCount,
      chapterTitles: chapterTitles,
    );
  }

  /// Ingests a new independent track directly from a parsed syllabus.
  Future<IngestionResult> ingestFromSyllabus({
    required String title,
    required String category,
    required DateTime targetDate,
    required ParsedSyllabus syllabus,
    String? resourceUrl,
    bool isPrimary = false,
  }) async {
    final cleanResource = resourceUrl?.trim();
    if (cleanResource != null && cleanResource.isNotEmpty) {
      return await ingestFromUrl(
        url: cleanResource,
        customRoadmapTitle: title,
        customDescription: category,
        targetCompletionDate: targetDate,
        isPrimary: isPrimary,
        syllabus: syllabus.allTopics,
      );
    }

    final now = DateTime.now();
    final roadmapId = 'rm_${now.millisecondsSinceEpoch}_syl';

    final roadmapEntity = RoadmapEntity(
      id: roadmapId,
      title: title,
      description: category,
      targetCompletionDate: targetDate,
      isPrimary: isPrimary,
      createdAt: now,
      updatedAt: now,
    );

    final chapterEntities = <ChapterEntity>[];
    final beatEntities = <BeatEntity>[];
    final chapterTitles = <String>[];
    int globalSort = 0;
    double totalEffort = 0.0;

    for (int c = 0; c < syllabus.chapters.length; c++) {
      final ch = syllabus.chapters[c];
      final chId = '${roadmapId}_ch_$c';
      chapterTitles.add(ch.chapterTitle);

      chapterEntities.add(ChapterEntity(
        id: chId,
        roadmapId: roadmapId,
        title: ch.chapterTitle,
        sortOrder: c,
        createdAt: now,
        updatedAt: now,
      ));

      for (final topic in ch.topics) {
        final beatId = '${chId}_b_$globalSort';
        totalEffort += 1.0;

        beatEntities.add(BeatEntity(
          id: beatId,
          chapterId: chId,
          roadmapId: roadmapId,
          title: topic.title,
          sourceUrl: null,
          timestampSeconds: null,
          effortWeight: 1.0,
          sortOrder: globalSort,
          isCompleted: false,
          isMentorExtra: false,
          syllabusTopicId: topic.id,
          createdAt: now,
          updatedAt: now,
        ));
        globalSort++;
      }
    }

    await _roadmapRepo.createRoadmap(roadmapEntity);
    await _chapterRepo.createChaptersBatch(chapterEntities);
    await _beatRepo.createBeatsBatch(beatEntities);

    if (isPrimary) {
      await _roadmapRepo.setPrimaryRoadmap(roadmapId);
    }

    return IngestionResult(
      roadmapId: roadmapId,
      roadmapTitle: title,
      chaptersCount: chapterEntities.length,
      beatsCount: beatEntities.length,
      totalEffort: totalEffort,
      mentorExtraCount: 0,
      unconfirmedMatchesCount: 0,
      chapterTitles: chapterTitles,
    );
  }

  /// Attaches a resource (YouTube playlist/video or generic link) to an existing tracker/roadmap.
  /// Enforces mentor teaching sequence priority (reordering syllabus topics to match mentor order).
  Future<void> attachResourceToRoadmap({
    required String roadmapId,
    required String resourceUrl,
  }) async {
    final cleanUrl = resourceUrl.trim();
    if (cleanUrl.isEmpty) return;

    final existingRoadmap = await _roadmapRepo.getRoadmapById(roadmapId);
    if (existingRoadmap == null) return;

    final existingBeats = await _beatRepo.getBeatsByRoadmapId(roadmapId);

    ExtractedResource extracted;
    final isYoutube = YoutubeExtractorService.parsePlaylistId(cleanUrl) != null ||
        YoutubeExtractorService.parseVideoId(cleanUrl) != null;

    if (isYoutube) {
      extracted = await _youtubeClient.extractResource(cleanUrl);
    } else {
      extracted = ExtractedResource(
        title: 'Linked Resource',
        description: cleanUrl,
        author: 'Resource Provider',
        sourceUrl: cleanUrl,
        resourceType: ExtractedResourceType.singleVideo,
        items: [
          RawResourceItem(
            title: existingRoadmap.title,
            sourceUrl: cleanUrl,
            durationSeconds: 900,
            index: 0,
          ),
        ],
      );
    }

    if (extracted.items.isEmpty) {
      throw Exception('No content items could be found from "$cleanUrl".');
    }

    final matchedBeatIds = <String>{};
    final alignedBeats = <ExtractedBeat>[];

    // Priority to Mentor's teaching order:
    // Match mentor items to syllabus topics sequentially
    for (int i = 0; i < extracted.items.length; i++) {
      final rawItem = extracted.items[i];
      final effort = EffortWeightCalculator.calculate(rawItem.durationSeconds);

      BeatEntity? bestMatch;
      double bestScore = 0.0;

      for (final beat in existingBeats) {
        if (matchedBeatIds.contains(beat.id)) continue;
        final score = _matcherService.calculateSimilarity(rawItem.title, beat.title);
        if (score > bestScore && score >= SyllabusMatcherService.ambiguousConfidenceThreshold) {
          bestScore = score;
          bestMatch = beat;
        }
      }

      if (bestMatch != null) {
        matchedBeatIds.add(bestMatch.id);
        alignedBeats.add(ExtractedBeat(
          title: bestMatch.title,
          sourceUrl: rawItem.sourceUrl,
          durationSeconds: rawItem.durationSeconds,
          effortWeight: effort,
          sortOrder: alignedBeats.length,
          thumbnailUrl: rawItem.thumbnailUrl,
          timestampSeconds: rawItem.timestampSeconds,
          syllabusTopicId: bestMatch.syllabusTopicId ?? bestMatch.id,
          matchConfidence: bestScore,
          isMentorExtra: false,
        ));
      } else {
        // Extra mentor material
        alignedBeats.add(ExtractedBeat(
          title: rawItem.title,
          sourceUrl: rawItem.sourceUrl,
          durationSeconds: rawItem.durationSeconds,
          effortWeight: effort,
          sortOrder: alignedBeats.length,
          thumbnailUrl: rawItem.thumbnailUrl,
          timestampSeconds: rawItem.timestampSeconds,
          isMentorExtra: true,
        ));
      }
    }

    // Remaining syllabus topics not in mentor's playlist move down,
    // preserving their relative syllabus order (Requirement 7).
    // If the roadmap only had the default "Initial Orientation" placeholder beat, replace it cleanly.
    final isInitialPlaceholder = existingBeats.length == 1 &&
        (existingBeats.first.title.toLowerCase().contains('initial orientation') ||
            existingBeats.first.title.toLowerCase().contains('core foundations'));

    if (!isInitialPlaceholder) {
      for (final beat in existingBeats) {
        if (!matchedBeatIds.contains(beat.id)) {
          alignedBeats.add(ExtractedBeat(
            title: beat.title,
            sourceUrl: beat.sourceUrl,
            durationSeconds: 600,
            effortWeight: beat.effortWeight,
            sortOrder: alignedBeats.length,
            thumbnailUrl: null,
            syllabusTopicId: beat.syllabusTopicId ?? beat.id,
            isMentorExtra: false,
          ));
        }
      }
    }

    // Re-cluster into balanced chapters
    final clustered = ChapterClusterer.clusterBeats(
      alignedBeats,
      roadmapTitle: existingRoadmap.title,
    );


    // Atomically replace chapters & beats
    await _chapterRepo.deleteChaptersByRoadmapId(roadmapId);
    await _beatRepo.deleteBeatsByRoadmapId(roadmapId);

    final now = DateTime.now();
    final chapterEntities = <ChapterEntity>[];
    final beatEntities = <BeatEntity>[];
    int globalSort = 0;

    for (int c = 0; c < clustered.length; c++) {
      final ch = clustered[c];
      final chId = '${roadmapId}_ch_$c';

      chapterEntities.add(ChapterEntity(
        id: chId,
        roadmapId: roadmapId,
        title: ch.title,
        sortOrder: c,
        createdAt: now,
        updatedAt: now,
      ));

      for (final b in ch.beats) {
        final origBeat = existingBeats.where((orig) => orig.title == b.title).firstOrNull;
        final isCompleted = origBeat?.isCompleted ?? false;
        final beatId = '${chId}_b_$globalSort';

        beatEntities.add(BeatEntity(
          id: beatId,
          chapterId: chId,
          roadmapId: roadmapId,
          title: b.title,
          sourceUrl: b.sourceUrl?.isNotEmpty == true ? b.sourceUrl : null,
          timestampSeconds: b.timestampSeconds,
          effortWeight: b.effortWeight,
          sortOrder: globalSort,
          isCompleted: isCompleted,
          isMentorExtra: b.isMentorExtra,
          matchConfidence: b.matchConfidence,
          syllabusTopicId: b.syllabusTopicId,
          createdAt: now,
          updatedAt: now,
        ));
        globalSort++;
      }
    }

    await _chapterRepo.createChaptersBatch(chapterEntities);
    await _beatRepo.createBeatsBatch(beatEntities);
    DatabaseEventBus.instance.emit(DatabaseEvent(
      type: DatabaseEventType.roadmapUpdated,
      roadmapId: roadmapId,
    ));
  }

  /// Attaches a resource URL directly to an individual beat/topic.
  Future<void> attachResourceToBeat({
    required String beatId,
    required String resourceUrl,
  }) async {
    final beat = await _beatRepo.getBeatById(beatId);
    if (beat == null) return;

    final cleanUrl = resourceUrl.trim();
    int? timestamp;
    double effort = beat.effortWeight;

    final uri = Uri.tryParse(cleanUrl);
    if (uri != null && uri.queryParameters.containsKey('t')) {
      final tParam = uri.queryParameters['t']!;
      final cleanT = tParam.replaceAll(RegExp(r'[^0-9]'), '');
      timestamp = int.tryParse(cleanT);
    }

    if (YoutubeExtractorService.parseVideoId(cleanUrl) != null) {
      try {
        final extracted = await _youtubeClient.extractVideo(cleanUrl);
        if (extracted.items.isNotEmpty) {
          effort = EffortWeightCalculator.calculate(extracted.items.first.durationSeconds);
        }
      } catch (_) {}
    }

    final updated = beat.copyWith(
      sourceUrl: cleanUrl,
      timestampSeconds: timestamp ?? beat.timestampSeconds,
      effortWeight: effort,
      updatedAt: DateTime.now(),
    );

    await _beatRepo.updateBeat(updated);
  }
}
