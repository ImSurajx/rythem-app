import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/ingestion/models/extracted_resource.dart';
import 'package:rythem_app/core/ingestion/parsers/syllabus_parser.dart';
import 'package:rythem_app/core/ingestion/services/curriculum_ingestion_service.dart';
import 'package:rythem_app/core/ingestion/services/youtube_extractor_service.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockPrecalcYoutubeClient implements IYoutubeClient {
  @override
  void close() {}

  @override
  Future<ExtractedResource> extractPlaylist(String playlistUrl) async =>
      extractResource(playlistUrl);

  @override
  Future<ExtractedResource> extractVideo(String videoUrl) async =>
      extractResource(videoUrl);

  @override
  Future<ExtractedResource> extractResource(String url) async {
    return const ExtractedResource(
      title: 'Professor Leonard - Precalculus College Algebra',
      description: 'Full course lectures',
      author: 'Professor Leonard',
      sourceUrl: 'https://youtube.com/playlist?list=precalc_full',
      resourceType: ExtractedResourceType.playlist,
      items: [
        RawResourceItem(
          title: 'Lecture 1: Functions and Domain Analysis',
          sourceUrl: 'https://youtube.com/watch?v=pc_vid1',
          durationSeconds: 1800,
          index: 0,
        ),
        RawResourceItem(
          title: 'Lecture 2: Polynomial and Rational Functions',
          sourceUrl: 'https://youtube.com/watch?v=pc_vid2',
          durationSeconds: 2100,
          index: 1,
        ),
        RawResourceItem(
          title: 'Lecture 3: Trigonometric Identities and Equations',
          sourceUrl: 'https://youtube.com/watch?v=pc_vid3',
          durationSeconds: 2400,
          index: 2,
        ),
        RawResourceItem(
          title: 'Lecture 4: Bonus - Graphing Calculator Speed Hacks',
          sourceUrl: 'https://youtube.com/watch?v=pc_vid4',
          durationSeconds: 900,
          index: 3,
        ),
      ],
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseService.instance.initInMemoryForTesting();
  });

  tearDown(() async {
    await DatabaseService.instance.close();
  });

  test('Multi-subject track preserves subjects and attaches playlist strictly to matched subject', () async {
    final mockClient = MockPrecalcYoutubeClient();
    final ingestionService = CurriculumIngestionService(youtubeClient: mockClient);

    const multiSubjectSyllabus = '''
# Module 1: Algebra & Precalculus
- Functions and Domain Analysis
- Polynomial and Rational Functions
- Trigonometric Identities and Equations
- Conic Sections and Analytic Geometry

# Module 2: Linear Algebra
- Vectors and Vector Spaces
- Matrix Operations and Inverses
- Eigenvalues and Eigenvectors

# Module 3: Multivariate Calculus
- Partial Derivatives and Gradients
- Multiple Integrals
''';

    final parsed = SyllabusParser.parse(multiSubjectSyllabus, defaultTitle: 'Math for ML Track');
    expect(parsed.chapters.length, 3);

    // 1. Create multi-subject track from syllabus
    final creationResult = await ingestionService.ingestFromSyllabus(
      title: 'Math for Machine Learning',
      category: 'Mathematics',
      targetDate: DateTime.now().add(const Duration(days: 90)),
      syllabus: parsed,
    );

    final roadmapRepo = RoadmapRepository();
    final chapterRepo = ChapterRepository();
    final beatRepo = BeatRepository();

    final roadmap = await roadmapRepo.getRoadmapById(creationResult.roadmapId);
    expect(roadmap, isNotNull);

    final initialChapters = await chapterRepo.getChaptersByRoadmapId(creationResult.roadmapId);
    expect(initialChapters.length, 3);
    expect(initialChapters[0].title, contains('Algebra & Precalculus'));
    expect(initialChapters[1].title, contains('Linear Algebra'));
    expect(initialChapters[2].title, contains('Multivariate Calculus'));

    final precalcChapter = initialChapters[0];
    final linalgChapter = initialChapters[1];
    final calcChapter = initialChapters[2];

    final initialPrecalcBeats = await beatRepo.getBeatsByChapterId(precalcChapter.id);
    expect(initialPrecalcBeats.length, 4); // 4 benchmark topics in precalc

    // 2. Attach Precalculus playlist to the track (auto-matches Algebra & Precalculus)
    final auditResult = await ingestionService.attachResourceToRoadmap(
      roadmapId: creationResult.roadmapId,
      resourceUrl: 'https://youtube.com/playlist?list=precalc_full',
    );

    expect(auditResult, isNotNull);
    expect(auditResult!.subjectTitle, contains('Algebra & Precalculus'));
    expect(auditResult.coveredTopics.length, 3);
    expect(auditResult.uncoveredGaps, contains('Conic Sections and Analytic Geometry'));
    expect(auditResult.mentorExtras, contains('Lecture 4: Bonus - Graphing Calculator Speed Hacks'));

    // 3. Verify Subject 1 (Algebra & Precalculus) beats:
    final updatedPrecalcBeats = await beatRepo.getBeatsByChapterId(precalcChapter.id);
    expect(updatedPrecalcBeats.length, 5); // 4 videos + 1 gap topic

    // Videos are in exact 0..3 order
    expect(updatedPrecalcBeats[0].title, 'Lecture 1: Functions and Domain Analysis');
    expect(updatedPrecalcBeats[0].sourceUrl, contains('pc_vid1'));
    expect(updatedPrecalcBeats[0].syllabusTopicId, 'Functions and Domain Analysis');

    expect(updatedPrecalcBeats[1].title, 'Lecture 2: Polynomial and Rational Functions');
    expect(updatedPrecalcBeats[1].sourceUrl, contains('pc_vid2'));

    expect(updatedPrecalcBeats[2].title, 'Lecture 3: Trigonometric Identities and Equations');
    expect(updatedPrecalcBeats[2].sourceUrl, contains('pc_vid3'));

    expect(updatedPrecalcBeats[3].title, 'Lecture 4: Bonus - Graphing Calculator Speed Hacks');
    expect(updatedPrecalcBeats[3].isMentorExtra, isTrue);

    // 5th beat is the uncovered gap
    expect(updatedPrecalcBeats[4].title, 'Conic Sections and Analytic Geometry');
    expect(updatedPrecalcBeats[4].sourceUrl, isNull);
    expect(updatedPrecalcBeats[4].isMentorExtra, isFalse);

    // 4. CRUCIAL GUARANTEE: Verify Subject 2 & Subject 3 were completely UNTOUCHED
    final updatedChapters = await chapterRepo.getChaptersByRoadmapId(creationResult.roadmapId);
    expect(updatedChapters.length, 3);
    expect(updatedChapters[1].title, contains('Linear Algebra'));
    expect(updatedChapters[2].title, contains('Multivariate Calculus'));

    final linalgBeats = await beatRepo.getBeatsByChapterId(linalgChapter.id);
    expect(linalgBeats.length, 3);
    expect(linalgBeats[0].title, 'Vectors and Vector Spaces');
    expect(linalgBeats[1].title, 'Matrix Operations and Inverses');
    expect(linalgBeats[2].title, 'Eigenvalues and Eigenvectors');

    final calcBeats = await beatRepo.getBeatsByChapterId(calcChapter.id);
    expect(calcBeats.length, 2);
    expect(calcBeats[0].title, 'Partial Derivatives and Gradients');
    expect(calcBeats[1].title, 'Multiple Integrals');
  });
}
