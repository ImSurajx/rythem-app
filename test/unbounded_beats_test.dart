import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/ingestion/models/extracted_resource.dart';
import 'package:rythem_app/core/ingestion/parsers/chapter_clusterer.dart';
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

  group('Unbounded Items / Beats Support (No 100-item limit)', () {
    test('ChapterClusterer handles 100, 200, and 500+ items without dropping or capping', () {
      for (final count in [100, 200, 350, 520]) {
        final items = List.generate(
          count,
          (i) => RawResourceItem(
            title: 'Video Lesson $i: Topic $i',
            sourceUrl: 'https://youtube.com/watch?v=item_$i',
            durationSeconds: 900,
            index: i,
          ),
        );

        final chapters = ChapterClusterer.cluster(items, roadmapTitle: 'Massive Course');
        
        // Ensure 100% video coverage: total beats across all chapters must equal count
        final totalBeats = chapters.fold<int>(0, (sum, ch) => sum + ch.beats.length);
        expect(totalBeats, count, reason: 'Failed for item count $count: some items were dropped');

        // Verify chapter titles and sort orders are sequential
        for (int c = 0; c < chapters.length; c++) {
          expect(chapters[c].sortOrder, c);
          expect(chapters[c].beats.isNotEmpty, isTrue);
        }

        // Check reasonable dynamic chapter scaling (not artificially stuck at 8)
        if (count > 100) {
          expect(chapters.length, greaterThan(8), reason: 'Chapter count should dynamically scale above 8');
        }
      }
    });

    test('ChapterClusterer with explicit sections preserves 100% of videos', () {
      final items = <RawResourceItem>[];
      for (int m = 1; m <= 5; m++) {
        for (int v = 1; v <= 15; v++) {
          items.add(
            RawResourceItem(
              title: 'Module $m: Part $v - Advanced Concept',
              sourceUrl: 'https://youtube.com/watch?v=m${m}_v$v',
              durationSeconds: 600,
              index: items.length,
            ),
          );
        }
      }

      final chapters = ChapterClusterer.cluster(items, roadmapTitle: 'Modular Course');
      final totalBeats = chapters.fold<int>(0, (sum, ch) => sum + ch.beats.length);
      expect(totalBeats, items.length);
      expect(chapters.length, 5);
      for (final ch in chapters) {
        expect(ch.beats.length, 15);
      }
    });

    test('Syllabus parser and database ingestion supports 300+ topics dynamically', () async {
      const topicCount = 320;
      final lines = StringBuffer();
      for (int i = 1; i <= topicCount; i++) {
        lines.writeln('- Syllabus Topic $i: Mastering Concept $i');
      }

      final parsed = SyllabusParser.parse(lines.toString(), defaultTitle: 'Comprehensive 300+ Syllabus');
      expect(parsed.allTopics.length, topicCount);

      final ingestionService = CurriculumIngestionService();
      final result = await ingestionService.ingestFromSyllabus(
        title: 'Comprehensive 300+ Syllabus',
        category: 'Deep Study',
        targetDate: DateTime.now().add(const Duration(days: 90)),
        syllabus: parsed,
      );

      expect(result.beatsCount, topicCount);

      final beatRepo = BeatRepository();
      final beatsInDb = await beatRepo.getBeatsByRoadmapId(result.roadmapId);
      expect(beatsInDb.length, topicCount);
      expect(beatsInDb.last.sortOrder, topicCount - 1);
    });
  });
}
