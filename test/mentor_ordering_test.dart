import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/ingestion/models/extracted_resource.dart';
import 'package:rythem_app/core/ingestion/parsers/syllabus_parser.dart';
import 'package:rythem_app/core/ingestion/services/curriculum_ingestion_service.dart';
import 'package:rythem_app/core/ingestion/services/youtube_extractor_service.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockMentorYoutubeClient implements IYoutubeClient {
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
    // Mentor teaches in this exact sequence:
    // 1. Topic A (Arrays)
    // 2. Topic C (Sliding Window)
    // 3. Topic B (Two Sum)
    // 4. Topic E (Binary Search)
    // 5. Mentor Extra (Bonus Tips)
    return ExtractedResource(
      title: 'Mentor Masterclass Playlist',
      description: 'The definitive sequence',
      author: 'Master Mentor',
      sourceUrl: url,
      resourceType: ExtractedResourceType.playlist,
      items: const [
        RawResourceItem(
          title: 'Lecture 1: Arrays and Strings Deep Dive',
          sourceUrl: 'https://youtube.com/watch?v=vid1',
          durationSeconds: 1200,
          index: 0,
        ),
        RawResourceItem(
          title: 'Lecture 2: Mastering Sliding Window Technique',
          sourceUrl: 'https://youtube.com/watch?v=vid2',
          durationSeconds: 1500,
          index: 1,
        ),
        RawResourceItem(
          title: 'Lecture 3: Two Sum & Hash Mapping',
          sourceUrl: 'https://youtube.com/watch?v=vid3',
          durationSeconds: 1100,
          index: 2,
        ),
        RawResourceItem(
          title: 'Lecture 4: Binary Search & Invariants',
          sourceUrl: 'https://youtube.com/watch?v=vid4',
          durationSeconds: 1400,
          index: 3,
        ),
        RawResourceItem(
          title: 'Lecture 5: Bonus - Competitive Programming Tips',
          sourceUrl: 'https://youtube.com/watch?v=vid5',
          durationSeconds: 800,
          index: 4,
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

  test('YouTube teaching order takes priority and reorders syllabus topics', () async {


    final mockClient = MockMentorYoutubeClient();
    final ingestionService = CurriculumIngestionService(youtubeClient: mockClient);

    // 1. User creates syllabus track with standard academic order:
    // A: Arrays
    // B: Two Sum
    // C: Sliding Window
    // D: Graph Traversal (uncovered by mentor)
    // E: Binary Search
    const rawSyllabus = '''
- Arrays and Strings
- Two Sum
- Sliding Window
- Graph Traversal
- Binary Search
''';

    final parsed = SyllabusParser.parse(rawSyllabus, defaultTitle: 'Data Structures');
    final creationResult = await ingestionService.ingestFromSyllabus(
      title: 'Data Structures',
      category: 'Engineering',
      targetDate: DateTime.now().add(const Duration(days: 30)),
      syllabus: parsed,
    );

    final beatRepo = BeatRepository();
    final initialBeats = await beatRepo.getBeatsByRoadmapId(creationResult.roadmapId);
    expect(initialBeats.map((b) => b.title).toList(), [
      'Arrays and Strings',
      'Two Sum',
      'Sliding Window',
      'Graph Traversal',
      'Binary Search',
    ]);

    // 2. User attaches Mentor's YouTube playlist
    // Mentor's order is: Arrays -> Sliding Window -> Two Sum -> Binary Search -> Bonus Tips
    await ingestionService.attachResourceToRoadmap(
      roadmapId: creationResult.roadmapId,
      resourceUrl: 'https://youtube.com/playlist?list=mentor_flow',
    );

    final updatedBeats = await beatRepo.getBeatsByRoadmapId(creationResult.roadmapId);

    // Verify:
    // 1st: Arrays and Strings (matched Lecture 1)
    // 2nd: Sliding Window (matched Lecture 2)
    // 3rd: Two Sum (matched Lecture 3)
    // 4th: Binary Search (matched Lecture 4)
    // 5th: Mentor extra bonus tips
    // 6th: Graph Traversal (uncovered by mentor, pushed down while preserving syllabus existence)
    final updatedTitles = updatedBeats.map((b) => b.title).toList();

    expect(updatedTitles[0], 'Arrays and Strings');
    expect(updatedBeats[0].sourceUrl, contains('vid1'));

    expect(updatedTitles[1], 'Sliding Window');
    expect(updatedBeats[1].sourceUrl, contains('vid2'));

    expect(updatedTitles[2], 'Two Sum');
    expect(updatedBeats[2].sourceUrl, contains('vid3'));

    expect(updatedTitles[3], 'Binary Search');
    expect(updatedBeats[3].sourceUrl, contains('vid4'));

    expect(updatedTitles[4], contains('Bonus - Competitive Programming Tips'));
    expect(updatedBeats[4].isMentorExtra, isTrue);

    expect(updatedTitles[5], 'Graph Traversal');
    expect(updatedBeats[5].sourceUrl, isNull); // Remains unlinked
    expect(updatedBeats[5].isMentorExtra, isFalse);
  });
}
