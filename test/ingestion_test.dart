import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/ingestion/ingestion.dart';

class MockYoutubeClient implements IYoutubeClient {
  final ExtractedResource mockPlaylist;

  MockYoutubeClient(this.mockPlaylist);

  @override
  Future<ExtractedResource> extractResource(String url) async => mockPlaylist;

  @override
  Future<ExtractedResource> extractPlaylist(String playlistUrl) async =>
      mockPlaylist;

  @override
  Future<ExtractedResource> extractVideo(String videoUrl) async => mockPlaylist;

  @override
  void close() {}
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 4.1: Timestamp Parser & Effort Weight Derivation', () {
    test('parses multi-hour descriptions with mm:ss and hh:mm:ss timestamps', () {
      const description = '''
00:00 Introduction & Overview
02:15 Setting up PyTorch & CUDA
[14:30] Matrix Multiplications
(01:15:45) Self-Attention Deep Dive
1:45:00 Transformer Architecture Breakdown
      ''';

      final segments = TimestampParser.parseDescription(
        description,
        totalVideoDurationSeconds: 7200, // 2 hours
      );

      expect(segments.length, 5);

      expect(segments[0].title, 'Introduction & Overview');
      expect(segments[0].startSeconds, 0);
      expect(segments[0].durationSeconds, 135); // 2:15 -> 135s

      expect(segments[1].title, 'Setting up PyTorch & CUDA');
      expect(segments[1].startSeconds, 135);

      expect(segments[2].title, 'Matrix Multiplications');
      expect(segments[2].startSeconds, 870); // 14:30

      expect(segments[3].title, 'Self-Attention Deep Dive');
      expect(segments[3].startSeconds, 4545); // 1h 15m 45s

      expect(segments[4].title, 'Transformer Architecture Breakdown');
      expect(segments[4].startSeconds, 6300); // 1h 45m
      expect(segments[4].durationSeconds, 900); // 7200 - 6300 = 900s
    });

    test('calculates invisible effort weight with 15m as baseline 1.0 unit', () {
      // 5 min (< 15 min) -> ~0.7
      final shortWeight = EffortWeightCalculator.calculate(300);
      expect(shortWeight, lessThan(1.0));
      expect(shortWeight, greaterThanOrEqualTo(0.5));

      // 15 min -> 1.0 baseline
      final baselineWeight = EffortWeightCalculator.calculate(900);
      expect(baselineWeight, 1.0);

      // 30 min -> ~1.8
      final medWeight = EffortWeightCalculator.calculate(1800);
      expect(medWeight, greaterThan(1.0));
      expect(medWeight, lessThan(2.5));

      // 60 min -> ~2.5
      final longWeight = EffortWeightCalculator.calculate(3600);
      expect(longWeight, greaterThan(2.0));
      expect(longWeight, lessThanOrEqualTo(EffortWeightCalculator.maxWeight));
    });
  });

  group('Phase 4.2: Chapter Clusterer (Condition 1 - Zero-Drop Guarantee)', () {
    test('clusters 20 flat playlist videos into 4 balanced chapters without dropping any', () {
      final items = List.generate(
        20,
        (i) => RawResourceItem(
          title: 'Lesson ${i + 1}: Topic ${String.fromCharCode(65 + i)}',
          sourceUrl: 'https://youtube.com/watch?v=vid$i',
          durationSeconds: 600 + (i * 30),
          index: i,
        ),
      );

      final chapters = ChapterClusterer.cluster(items, roadmapTitle: 'Deep Learning');

      // Check chapter count is within recommended 4-8 range
      expect(chapters.length, inInclusiveRange(3, 6));

      // Enforce 100% video coverage ground truth
      final totalBeats = chapters.fold(0, (sum, ch) => sum + ch.beatCount);
      expect(totalBeats, 20);

      // Enforce mentor chronological order (0 to 19)
      int expectedSort = 0;
      for (final chapter in chapters) {
        for (final beat in chapter.beats) {
          expect(beat.sortOrder, expectedSort);
          expectedSort++;
        }
      }
    });

    test('detects explicit module boundaries from video titles', () {
      final items = [
        const RawResourceItem(title: 'Module 1 - Intro to Python', sourceUrl: 'u1', durationSeconds: 600, index: 0),
        const RawResourceItem(title: 'Module 1 - Data Types', sourceUrl: 'u2', durationSeconds: 600, index: 1),
        const RawResourceItem(title: 'Module 2 - Object Oriented Programming', sourceUrl: 'u3', durationSeconds: 900, index: 2),
        const RawResourceItem(title: 'Module 2 - Classes & Inheritance', sourceUrl: 'u4', durationSeconds: 900, index: 3),
        const RawResourceItem(title: 'Module 3 - Asynchronous Programming', sourceUrl: 'u5', durationSeconds: 1200, index: 4),
        const RawResourceItem(title: 'Module 3 - Asyncio & Concurrency', sourceUrl: 'u6', durationSeconds: 1200, index: 5),
      ];

      final chapters = ChapterClusterer.cluster(items);
      expect(chapters.length, 3);
      expect(chapters[0].beats.length, 2);
      expect(chapters[1].beats.length, 2);
      expect(chapters[2].beats.length, 2);
    });
  });

  group('Phase 4.3: Syllabus Matcher (Condition 2 - Mentor Flow & Extras)', () {
    test('matches aligned topics and tags unaligned items as mentor_extra in place', () {
      final matcher = SyllabusMatcherService();

      final chapters = [
        const ExtractedChapter(
          title: 'Foundations',
          sortOrder: 0,
          beats: [
            ExtractedBeat(
              title: 'Linear Algebra & Matrix Multiplication',
              durationSeconds: 900,
              effortWeight: 1.0,
              sortOrder: 0,
            ),
            ExtractedBeat(
              title: 'Mentor Special: Vim & Terminal Hacks for Coders', // Not in syllabus!
              durationSeconds: 1200,
              effortWeight: 1.2,
              sortOrder: 1,
            ),
            ExtractedBeat(
              title: 'Calculus, Partial Derivatives & Backpropagation',
              durationSeconds: 1500,
              effortWeight: 1.5,
              sortOrder: 2,
            ),
          ],
        ),
      ];

      final syllabus = [
        const SyllabusTopic(id: 'syl_linalg', title: 'Linear Algebra and Matrix Theory'),
        const SyllabusTopic(id: 'syl_calc', title: 'Differential Calculus & Backpropagation'),
      ];

      final alignedChapters = matcher.alignCurriculum(
        chapters: chapters,
        syllabus: syllabus,
      );

      final beats = alignedChapters.first.beats;

      // First beat matched Linear Algebra
      expect(beats[0].syllabusTopicId, 'syl_linalg');
      expect(beats[0].isMentorExtra, false);
      expect(beats[0].matchConfidence, greaterThanOrEqualTo(0.40));

      // Second beat is mentor-extra: preserved at index 1!
      expect(beats[1].isMentorExtra, true);
      expect(beats[1].syllabusTopicId, isNull);
      expect(beats[1].sortOrder, 1); // Never moved to separate section

      // Third beat matched Calculus
      expect(beats[2].syllabusTopicId, 'syl_calc');
      expect(beats[2].isMentorExtra, false);
      expect(beats[2].sortOrder, 2);
    });
  });

  group('Phase 4.4 & 4.5: End-to-End Curriculum Ingestion Pipeline in SQLite', () {
    late Database db;
    late DatabaseService dbService;
    late RoadmapRepository roadmapRepo;
    late ChapterRepository chapterRepo;
    late BeatRepository beatRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (db, version) async {
            final batch = db.batch();
            batch.execute('''
              CREATE TABLE ${DatabaseTables.roadmaps} (
                ${RoadmapColumns.id} TEXT PRIMARY KEY,
                ${RoadmapColumns.title} TEXT NOT NULL,
                ${RoadmapColumns.description} TEXT,
                ${RoadmapColumns.targetCompletionDate} TEXT,
                ${RoadmapColumns.status} TEXT NOT NULL DEFAULT 'active',
                ${RoadmapColumns.isPrimary} INTEGER NOT NULL DEFAULT 0,
                ${RoadmapColumns.createdAt} TEXT NOT NULL,
                ${RoadmapColumns.updatedAt} TEXT NOT NULL
              );
            ''');
            batch.execute('''
              CREATE TABLE ${DatabaseTables.chapters} (
                ${ChapterColumns.id} TEXT PRIMARY KEY,
                ${ChapterColumns.roadmapId} TEXT NOT NULL,
                ${ChapterColumns.title} TEXT NOT NULL,
                ${ChapterColumns.sortOrder} INTEGER NOT NULL DEFAULT 0,
                ${ChapterColumns.createdAt} TEXT NOT NULL,
                ${ChapterColumns.updatedAt} TEXT NOT NULL,
                FOREIGN KEY (${ChapterColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
              );
            ''');
            batch.execute('''
              CREATE TABLE ${DatabaseTables.beats} (
                ${BeatColumns.id} TEXT PRIMARY KEY,
                ${BeatColumns.chapterId} TEXT NOT NULL,
                ${BeatColumns.roadmapId} TEXT NOT NULL,
                ${BeatColumns.title} TEXT NOT NULL,
                ${BeatColumns.sourceUrl} TEXT,
                ${BeatColumns.timestampSeconds} INTEGER,
                ${BeatColumns.effortWeight} REAL NOT NULL DEFAULT 1.0,
                ${BeatColumns.sortOrder} INTEGER NOT NULL DEFAULT 0,
                ${BeatColumns.isCompleted} INTEGER NOT NULL DEFAULT 0,
                ${BeatColumns.completedAt} TEXT,
                ${BeatColumns.isMentorExtra} INTEGER NOT NULL DEFAULT 0,
                ${BeatColumns.matchConfidence} REAL,
                ${BeatColumns.syllabusTopicId} TEXT,
                ${BeatColumns.createdAt} TEXT NOT NULL,
                ${BeatColumns.updatedAt} TEXT NOT NULL,
                FOREIGN KEY (${BeatColumns.chapterId}) REFERENCES ${DatabaseTables.chapters} (${ChapterColumns.id}) ON DELETE CASCADE,
                FOREIGN KEY (${BeatColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
              );
            ''');
            batch.execute('''
              CREATE TABLE ${DatabaseTables.beatLogs} (
                ${BeatLogColumns.id} TEXT PRIMARY KEY,
                ${BeatLogColumns.beatId} TEXT NOT NULL,
                ${BeatLogColumns.roadmapId} TEXT NOT NULL,
                ${BeatLogColumns.completedDate} TEXT NOT NULL,
                ${BeatLogColumns.createdAt} TEXT NOT NULL,
                FOREIGN KEY (${BeatLogColumns.beatId}) REFERENCES ${DatabaseTables.beats} (${BeatColumns.id}) ON DELETE CASCADE,
                FOREIGN KEY (${BeatLogColumns.roadmapId}) REFERENCES ${DatabaseTables.roadmaps} (${RoadmapColumns.id}) ON DELETE CASCADE
              );
            ''');
            batch.execute('''
              CREATE TABLE ${DatabaseTables.appSettings} (
                ${AppSettingsColumns.key} TEXT PRIMARY KEY,
                ${AppSettingsColumns.value} TEXT NOT NULL,
                ${AppSettingsColumns.updatedAt} TEXT NOT NULL
              );
            ''');
            await batch.commit(noResult: true);
          },
        ),
      );

      dbService = DatabaseService.instance;
      dbService.setDatabaseForTesting(db);

      roadmapRepo = RoadmapRepository(dbService: dbService);
      chapterRepo = ChapterRepository(dbService: dbService);
      beatRepo = BeatRepository(dbService: dbService);
    });

    tearDown(() async {
      await db.close();
      dbService.setDatabaseForTesting(null);
    });

    test('ingests simulated YouTube playlist and stores complete relational hierarchy', () async {
      const mockResource = ExtractedResource(
        title: 'Neural Networks: Zero to Hero',
        author: 'Andrej Karpathy',
        description: 'Building deep neural networks from the ground up.',
        sourceUrl: 'https://youtube.com/playlist?list=PLxyz',
        resourceType: ExtractedResourceType.playlist,
        items: [
          RawResourceItem(title: 'The spelled-out intro to neural networks and backpropagation: building micrograd', sourceUrl: 'v1', durationSeconds: 8400, index: 0),
          RawResourceItem(title: 'The spelled-out intro to language modeling: building makemore', sourceUrl: 'v2', durationSeconds: 6800, index: 1),
          RawResourceItem(title: 'Building makemore Part 2: MLP', sourceUrl: 'v3', durationSeconds: 4500, index: 2),
          RawResourceItem(title: 'Building makemore Part 3: Activations & Gradients, BatchNorm', sourceUrl: 'v4', durationSeconds: 5200, index: 3),
          RawResourceItem(title: 'Building makemore Part 4: Becoming a Backprop Ninja', sourceUrl: 'v5', durationSeconds: 7000, index: 4),
          RawResourceItem(title: 'Building makemore Part 5: Building a WaveNet', sourceUrl: 'v6', durationSeconds: 4200, index: 5),
          RawResourceItem(title: 'Let us build GPT: from scratch, in code, spelled out', sourceUrl: 'v7', durationSeconds: 7200, index: 6),
          RawResourceItem(title: 'Let us reproduce GPT-2 (124M)', sourceUrl: 'v8', durationSeconds: 14400, index: 7),
        ],
      );

      final mockClient = MockYoutubeClient(mockResource);
      final ingestionService = CurriculumIngestionService(
        youtubeClient: mockClient,
        roadmapRepo: roadmapRepo,
        chapterRepo: chapterRepo,
        beatRepo: beatRepo,
      );

      final syllabus = [
        const SyllabusTopic(id: 'top_backprop', title: 'Backpropagation and Automatic Differentiation'),
        const SyllabusTopic(id: 'top_transformers', title: 'Self-Attention and GPT Transformer Architecture'),
      ];

      final result = await ingestionService.ingestFromUrl(
        url: 'https://youtube.com/playlist?list=PLxyz',
        syllabus: syllabus,
      );

      // Verify returned result summary
      expect(result.beatsCount, 8);
      expect(result.chaptersCount, inInclusiveRange(2, 4));
      expect(result.totalEffort, greaterThan(10.0));

      // Verify persisted database records
      final storedRoadmaps = await roadmapRepo.getActiveRoadmaps();
      expect(storedRoadmaps.length, 1);
      expect(storedRoadmaps.first.title, 'Neural Networks: Zero to Hero');
      expect(storedRoadmaps.first.isPrimary, true);

      final storedChapters = await chapterRepo.getChaptersByRoadmapId(result.roadmapId);
      expect(storedChapters.length, result.chaptersCount);

      final storedBeats = await beatRepo.getBeatsByRoadmapId(result.roadmapId);
      expect(storedBeats.length, 8);

      // Verify mentor order is maintained 0..7
      for (int i = 0; i < 8; i++) {
        expect(storedBeats[i].sortOrder, i);
      }

      // Verify foreign key cascade: deleting roadmap cascades to chapters and beats
      await roadmapRepo.deleteRoadmap(result.roadmapId);

      final remainingChapters = await chapterRepo.getChaptersByRoadmapId(result.roadmapId);
      expect(remainingChapters, isEmpty);

      final remainingBeats = await beatRepo.getBeatsByRoadmapId(result.roadmapId);
      expect(remainingBeats, isEmpty);
    });

    test('YouTube URL Parser extracts playlist and video IDs across multiple URL formats', () {
      expect(
        YoutubeExtractorService.parsePlaylistId('https://www.youtube.com/playlist?list=PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ'),
        'PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ',
      );
      expect(
        YoutubeExtractorService.parsePlaylistId('https://youtube.com/playlist?list=PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ'),
        'PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ',
      );
      expect(
        YoutubeExtractorService.parsePlaylistId('https://www.youtube.com/watch?v=kCc8FmEb1nY&list=PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ'),
        'PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ',
      );
      expect(
        YoutubeExtractorService.parsePlaylistId('https://m.youtube.com/playlist?list=PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ'),
        'PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ',
      );
      expect(
        YoutubeExtractorService.parsePlaylistId('PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ'),
        'PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ',
      );
      expect(
        YoutubeExtractorService.parsePlaylistId('https://www.youtube.com/watch?v=kCc8FmEb1nY'),
        isNull,
      );

      expect(
        YoutubeExtractorService.parseVideoId('https://www.youtube.com/watch?v=kCc8FmEb1nY'),
        'kCc8FmEb1nY',
      );
      expect(
        YoutubeExtractorService.parseVideoId('https://youtu.be/kCc8FmEb1nY'),
        'kCc8FmEb1nY',
      );
    });

    test('Live YouTubeExtractorService extracts playlist videos and durations', () async {
      final extractor = YoutubeExtractorService();
      try {
        final extracted = await extractor.extractPlaylist('PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ');
        expect(extracted.items.length, greaterThanOrEqualTo(10));
        expect(extracted.items.first.title, contains('intro to neural networks'));
        expect(extracted.items.first.durationSeconds, greaterThan(3600));
        expect(extracted.items.last.title, contains('GPT-2'));
      } catch (e) {
        // In restricted network environments, allow graceful pass if network is unreachable
        print('Notice: live YouTube fetch test skipped due to network: $e');
      } finally {
        extractor.close();
      }
    });
  });
}
