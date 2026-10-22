import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/ingestion/models/extracted_resource.dart';
import 'package:rythem_app/core/ingestion/parsers/syllabus_parser.dart';
import 'package:rythem_app/core/ingestion/services/curriculum_ingestion_service.dart';
import 'package:rythem_app/core/ingestion/services/youtube_extractor_service.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockTestYoutubeClient implements IYoutubeClient {
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
      title: 'Algorithms Playlist',
      description: 'Test Playlist',
      author: 'Test Instructor',
      sourceUrl: 'https://youtube.com/playlist?list=algo_test',
      resourceType: ExtractedResourceType.playlist,
      items: [
        RawResourceItem(
          title: 'Bit Manipulation Deep Dive',
          sourceUrl: 'https://youtube.com/watch?v=algo_vid1',
          durationSeconds: 1200, // 20 mins -> 2.0 effort
          index: 0,
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

  group('SyllabusParser Tests', () {
    test('parses bulleted and plain line topics into default chapter', () {
      const input = '''
- Arrays and Strings
* Two Sum
1. Sliding Window
Binary Search
''';
      final parsed = SyllabusParser.parse(input, defaultTitle: 'DSA Track');
      expect(parsed.title, 'DSA Track');
      expect(parsed.allTopics.length, 4);
      expect(parsed.allTopics[0].title, 'Arrays and Strings');
      expect(parsed.allTopics[1].title, 'Two Sum');
      expect(parsed.allTopics[2].title, 'Sliding Window');
      expect(parsed.allTopics[3].title, 'Binary Search');
    });

    test('parses markdown topics with brackets, parentheses, pipes, prefixes into clean titles and effort points', () {
      const input = '''
# Module 1: Core Algorithms
- Arrays & Strings [2.5]
- Two Pointers (1.5 beats)
- Sliding Window [effort: 3.0]
- Prefix Sum | 2.0 pts
- Binary Search: 2.5 beats
- [3.0 beats] Dynamic Programming
- Plain Graph Traversal
''';
      final parsed = SyllabusParser.parse(input);
      expect(parsed.chapters.length, 1);
      final topics = parsed.chapters[0].topics;
      expect(topics.length, 7);

      expect(topics[0].title, 'Arrays & Strings');
      expect(topics[0].effortPoints, 2.5);

      expect(topics[1].title, 'Two Pointers');
      expect(topics[1].effortPoints, 1.5);

      expect(topics[2].title, 'Sliding Window');
      expect(topics[2].effortPoints, 3.0);

      expect(topics[3].title, 'Prefix Sum');
      expect(topics[3].effortPoints, 2.0);

      expect(topics[4].title, 'Binary Search');
      expect(topics[4].effortPoints, 2.5);

      expect(topics[5].title, 'Dynamic Programming');
      expect(topics[5].effortPoints, 3.0);

      expect(topics[6].title, 'Plain Graph Traversal');
      expect(topics[6].effortPoints, isNull);
    });

    test('parses modular section headers into structured chapters', () {
      const input = '''
Module 1: Linear Structures
- Arrays
- Linked Lists

Module 2: Non-Linear Structures
- Binary Trees
- Graphs
''';
      final parsed = SyllabusParser.parse(input);
      expect(parsed.chapters.length, 2);
      expect(parsed.chapters[0].chapterTitle, contains('Linear Structures'));
      expect(parsed.chapters[0].topics.length, 2);
      expect(parsed.chapters[1].chapterTitle, contains('Non-Linear Structures'));
      expect(parsed.chapters[1].topics.length, 2);
    });

    test('parses JSON format syllabus with explicit effort fields and embedded titles', () {
      const input = '''
[
  {"title": "Hash Maps", "effort": 2.5, "description": "Collision resolution"},
  {"title": "Heaps and Priority Queues [3.0 beats]"},
  {"title": "Trie Structures", "points": 1.5}
]
''';
      final parsed = SyllabusParser.parse(input);
      expect(parsed.allTopics.length, 3);
      expect(parsed.allTopics[0].title, 'Hash Maps');
      expect(parsed.allTopics[0].effortPoints, 2.5);
      expect(parsed.allTopics[0].description, 'Collision resolution');

      expect(parsed.allTopics[1].title, 'Heaps and Priority Queues');
      expect(parsed.allTopics[1].effortPoints, 3.0);

      expect(parsed.allTopics[2].title, 'Trie Structures');
      expect(parsed.allTopics[2].effortPoints, 1.5);
    });
  });

  group('CurriculumIngestionService - Syllabus Import Tests', () {
    test('creates independent syllabus track preserving user effort points when no resource is attached', () async {
      await DatabaseService.instance.resetDatabase();

      final ingestionService = CurriculumIngestionService();
      const rawSyllabus = '''
Phase 1: Foundations
- Bit Manipulation [2.0]
- Two Pointers (1.5 beats)
Phase 2: Advanced
- Dynamic Programming [3.5]
- Graph Theory
''';
      final parsed = SyllabusParser.parse(rawSyllabus, defaultTitle: 'Advanced Algorithms');

      final result = await ingestionService.ingestFromSyllabus(
        title: 'Advanced Algorithms',
        category: 'Computer Science',
        targetDate: DateTime.now().add(const Duration(days: 30)),
        syllabus: parsed,
      );

      expect(result.roadmapTitle, 'Advanced Algorithms');
      expect(result.chaptersCount, 2);
      expect(result.beatsCount, 4);
      // 2.0 + 1.5 + 3.5 + 1.0 (default for plain topic) = 8.0
      expect(result.totalEffort, 8.0);

      final beatRepo = BeatRepository();
      final beats = await beatRepo.getBeatsByRoadmapId(result.roadmapId);
      expect(beats.length, 4);

      // Verify unlinked status & retained user effort weights
      expect(beats[0].sourceUrl, isNull);
      expect(beats[0].title, 'Bit Manipulation');
      expect(beats[0].effortWeight, 2.0);

      expect(beats[1].title, 'Two Pointers');
      expect(beats[1].effortWeight, 1.5);

      expect(beats[2].title, 'Dynamic Programming');
      expect(beats[2].effortWeight, 3.5);

      expect(beats[3].title, 'Graph Theory');
      expect(beats[3].effortWeight, 1.0);
    });

    test('resource attachment replaces covered beats with video duration but preserves uncovered gap user effort points', () async {
      await DatabaseService.instance.resetDatabase();

      final mockClient = MockTestYoutubeClient();
      final ingestionService = CurriculumIngestionService(youtubeClient: mockClient);

      const rawSyllabus = '''
Phase 1: Foundations
- Bit Manipulation [3.0]
- Custom Gap Topic (4.5 beats)
''';
      final parsed = SyllabusParser.parse(rawSyllabus, defaultTitle: 'Target Track');

      final result = await ingestionService.ingestFromSyllabus(
        title: 'Target Track',
        category: 'Engineering',
        targetDate: DateTime.now().add(const Duration(days: 30)),
        syllabus: parsed,
      );

      final chapterRepo = ChapterRepository();
      final chapters = await chapterRepo.getChaptersByRoadmapId(result.roadmapId);
      expect(chapters.isNotEmpty, isTrue);

      // Attach mock resource to Phase 1 chapter
      await ingestionService.attachResourceToSubject(
        roadmapId: result.roadmapId,
        chapterId: chapters[0].id,
        resourceUrl: 'https://youtube.com/playlist?list=algo_test',
      );

      final beatRepo = BeatRepository();
      final updatedBeats = await beatRepo.getBeatsByRoadmapId(result.roadmapId);

      // We should have 1 video beat from resource (replaced effort) + 1 gap beat (Custom Gap Topic with preserved 4.5 effort)
      final videoBeat = updatedBeats.firstWhere((b) => b.sourceUrl != null);
      final gapBeat = updatedBeats.firstWhere((b) => b.sourceUrl == null);

      // Video beat: duration 1200s -> 2.0 effort (replacing topic effort)
      expect(videoBeat.effortWeight, 2.0);
      expect(videoBeat.title, 'Bit Manipulation Deep Dive');

      // Uncovered gap beat: preserved its original 4.5 effort
      expect(gapBeat.title, 'Custom Gap Topic');
      expect(gapBeat.effortWeight, 4.5);
    });
  });
}
