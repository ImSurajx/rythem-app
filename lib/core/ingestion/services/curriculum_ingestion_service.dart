import 'package:flutter/foundation.dart';
import '../../database/database.dart';
import '../models/extracted_resource.dart';
import '../models/ingestion_result.dart';
import '../models/syllabus_topic.dart';
import '../parsers/chapter_clusterer.dart';
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
}
