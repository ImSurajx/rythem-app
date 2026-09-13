import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/ingestion/parsers/syllabus_parser.dart';
import 'package:rythem_app/core/ingestion/services/curriculum_ingestion_service.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

    test('parses JSON format syllabus correctly', () {
      const input = '''
[
  {"title": "Hash Maps", "description": "Collision resolution"},
  {"title": "Heaps and Priority Queues"}
]
''';
      final parsed = SyllabusParser.parse(input);
      expect(parsed.allTopics.length, 2);
      expect(parsed.allTopics[0].title, 'Hash Maps');
      expect(parsed.allTopics[0].description, 'Collision resolution');
      expect(parsed.allTopics[1].title, 'Heaps and Priority Queues');
    });
  });

  group('CurriculumIngestionService - Syllabus Import Tests', () {
    test('creates independent syllabus track with unlinked topics', () async {
      await DatabaseService.instance.resetDatabase();

      final ingestionService = CurriculumIngestionService();
      const rawSyllabus = '''
Phase 1: Foundations
- Bit Manipulation
- Two Pointers
Phase 2: Advanced
- Dynamic Programming
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
      expect(result.beatsCount, 3);

      final beatRepo = BeatRepository();
      final beats = await beatRepo.getBeatsByRoadmapId(result.roadmapId);
      expect(beats.length, 3);

      // Verify unlinked status (no resource linked yet)
      expect(beats[0].sourceUrl, isNull);
      expect(beats[0].title, 'Bit Manipulation');
      expect(beats[1].title, 'Two Pointers');
      expect(beats[2].title, 'Dynamic Programming');
    });
  });
}
