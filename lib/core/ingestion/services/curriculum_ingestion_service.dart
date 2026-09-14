import 'package:flutter/foundation.dart';
import '../../database/database.dart';
import '../../ai/services/local_inference_service.dart';
import '../../ai/models/curriculum_audit_result.dart';
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
  final LocalInferenceService _inferenceService;

  CurriculumIngestionService({
    IYoutubeClient? youtubeClient,
    SyllabusMatcherService? matcherService,
    RoadmapRepository? roadmapRepo,
    ChapterRepository? chapterRepo,
    BeatRepository? beatRepo,
    LocalInferenceService? inferenceService,
  })  : _youtubeClient = youtubeClient ?? YoutubeExtractorService(),
        _matcherService = matcherService ?? SyllabusMatcherService(),
        _roadmapRepo = roadmapRepo ?? RoadmapRepository(),
        _chapterRepo = chapterRepo ?? ChapterRepository(),
        _beatRepo = beatRepo ?? BeatRepository(),
        _inferenceService = inferenceService ?? LocalInferenceService();

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

    int finalBeatsCount = beatEntities.length;
    double finalEffort = totalEffort;
    int mentorExtras = 0;

    final cleanResource = resourceUrl?.trim();
    if (cleanResource != null && cleanResource.isNotEmpty) {
      final audit = await attachResourceToRoadmap(
        roadmapId: roadmapId,
        resourceUrl: cleanResource,
      );
      if (audit != null) {
        final updatedBeats = await _beatRepo.getBeatsByRoadmapId(roadmapId);
        finalBeatsCount = updatedBeats.length;
        finalEffort = updatedBeats.fold(0.0, (acc, b) => acc + b.effortWeight);
        mentorExtras = audit.mentorExtras.length;
      }
    }

    return IngestionResult(
      roadmapId: roadmapId,
      roadmapTitle: title,
      chaptersCount: chapterEntities.length,
      beatsCount: finalBeatsCount,
      totalEffort: double.parse(finalEffort.toStringAsFixed(1)),
      mentorExtraCount: mentorExtras,
      unconfirmedMatchesCount: 0,
      chapterTitles: chapterTitles,
    );
  }

  /// Attaches a resource (YouTube playlist/video or generic link) to a specific Subject / Chapter.
  /// 
  /// Guarantees:
  /// - Macro subjects and other chapters in the track are NEVER modified or deleted.
  /// - 100% of playlist videos are preserved in exact 0..N-1 mentor sequence.
  /// - Local AI inference audits coverage, re-sequences syllabus topics according to the mentor's
  ///   teaching flow, flags uncovered gaps at the end, and marks bonus videos as mentor extras.
  /// - Returns a structured [CurriculumAuditResult] with AI Markdown narrative.
  Future<CurriculumAuditResult?> attachResourceToSubject({
    required String roadmapId,
    required String chapterId,
    required String resourceUrl,
  }) async {
    final cleanUrl = resourceUrl.trim();
    if (cleanUrl.isEmpty) return null;

    final existingRoadmap = await _roadmapRepo.getRoadmapById(roadmapId);
    if (existingRoadmap == null) return null;

    final chapters = await _chapterRepo.getChaptersByRoadmapId(roadmapId);
    final targetChapter = chapters.where((c) => c.id == chapterId).firstOrNull;
    if (targetChapter == null) return null;

    final existingBeats = await _beatRepo.getBeatsByChapterId(chapterId);

    ExtractedResource extracted;
    final isYoutube = YoutubeExtractorService.parsePlaylistId(cleanUrl) != null ||
        YoutubeExtractorService.parseVideoId(cleanUrl) != null;

    if (isYoutube) {
      extracted = await _youtubeClient.extractResource(cleanUrl);
    } else {
      extracted = ExtractedResource(
        title: targetChapter.title,
        description: cleanUrl,
        author: 'Resource Provider',
        sourceUrl: cleanUrl,
        resourceType: ExtractedResourceType.singleVideo,
        items: [
          RawResourceItem(
            title: targetChapter.title,
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

    // Benchmark topics: existing beats before attachment
    final isInitialPlaceholder = existingBeats.length == 1 &&
        (existingBeats.first.title.toLowerCase().contains('initial orientation') ||
            existingBeats.first.title.toLowerCase().contains('core foundations'));

    final syllabusTopicTitles = isInitialPlaceholder
        ? <String>[targetChapter.title]
        : existingBeats.map((b) => b.title).toList();

    final videoTitles = extracted.items.map((i) => i.title).toList();

    // 1. First-Priority AI Coverage & Sequence Audit
    final audit = await _inferenceService.auditSubjectResource(
      subjectTitle: targetChapter.title,
      syllabusTopics: syllabusTopicTitles,
      videoTitles: videoTitles,
    );

    // 2. Prepare replacement beats for this chapter
    final now = DateTime.now();
    final newBeats = <BeatEntity>[];
    int sortIndex = 0;

    // A. Videos in exact original mentor order (0..N-1)
    for (int i = 0; i < extracted.items.length; i++) {
      final rawItem = extracted.items[i];
      final effort = EffortWeightCalculator.calculate(rawItem.durationSeconds);
      final mapping = (i < audit.mappings.length) ? audit.mappings[i] : null;

      final prevCompleted = existingBeats.any((b) =>
          (b.sourceUrl == rawItem.sourceUrl || b.title == rawItem.title) && b.isCompleted);

      newBeats.add(BeatEntity(
        id: '${chapterId}_v_$i',
        chapterId: chapterId,
        roadmapId: roadmapId,
        title: rawItem.title,
        sourceUrl: rawItem.sourceUrl,
        timestampSeconds: rawItem.timestampSeconds,
        effortWeight: effort,
        sortOrder: sortIndex++,
        isCompleted: prevCompleted,
        isMentorExtra: mapping?.isMentorExtra ?? false,
        matchConfidence: mapping?.confidence,
        syllabusTopicId: mapping?.matchedTopicId,
        createdAt: now,
        updatedAt: now,
      ));
    }

    // B. Uncovered syllabus benchmark gaps placed at the end of the chapter
    for (int g = 0; g < audit.uncoveredGaps.length; g++) {
      final gapTitle = audit.uncoveredGaps[g];
      newBeats.add(BeatEntity(
        id: '${chapterId}_gap_$g',
        chapterId: chapterId,
        roadmapId: roadmapId,
        title: gapTitle,
        sourceUrl: null,
        timestampSeconds: null,
        effortWeight: 1.0,
        sortOrder: sortIndex++,
        isCompleted: false,
        isMentorExtra: false,
        syllabusTopicId: gapTitle,
        createdAt: now,
        updatedAt: now,
      ));
    }

    // 3. Atomically replace ONLY this chapter's beats.
    // Fixed macro subject structure is preserved without touching other chapters.
    await _beatRepo.deleteBeatsByChapterId(chapterId);
    await _beatRepo.createBeatsBatch(newBeats);

    DatabaseEventBus.instance.emit(DatabaseEvent(
      type: DatabaseEventType.roadmapUpdated,
      roadmapId: roadmapId,
    ));

    return audit;
  }

  /// Attaches a resource to a roadmap by automatically matching the resource's title
  /// to the most relevant Subject / Chapter in the roadmap, or defaulting to the first.
  Future<CurriculumAuditResult?> attachResourceToRoadmap({
    required String roadmapId,
    required String resourceUrl,
    String? preferredChapterId,
  }) async {
    final cleanUrl = resourceUrl.trim();
    if (cleanUrl.isEmpty) return null;

    final chapters = await _chapterRepo.getChaptersByRoadmapId(roadmapId);
    if (chapters.isEmpty) return null;

    if (preferredChapterId != null) {
      final found = chapters.where((c) => c.id == preferredChapterId).firstOrNull;
      if (found != null) {
        return await attachResourceToSubject(
          roadmapId: roadmapId,
          chapterId: found.id,
          resourceUrl: cleanUrl,
        );
      }
    }

    // Auto-match playlist title to candidate subject
    ChapterEntity targetChapter = chapters.first;
    double highestScore = -1.0;

    String extractedTitle = '';
    try {
      final isYoutube = YoutubeExtractorService.parsePlaylistId(cleanUrl) != null ||
          YoutubeExtractorService.parseVideoId(cleanUrl) != null;
      if (isYoutube) {
        final extracted = await _youtubeClient.extractResource(cleanUrl);
        extractedTitle = extracted.title;
      }
    } catch (_) {}

    if (extractedTitle.isNotEmpty) {
      for (final ch in chapters) {
        final score = _matcherService.calculateSimilarity(extractedTitle, ch.title);
        if (score > highestScore) {
          highestScore = score;
          targetChapter = ch;
        }
      }
    }

    return await attachResourceToSubject(
      roadmapId: roadmapId,
      chapterId: targetChapter.id,
      resourceUrl: cleanUrl,
    );
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
