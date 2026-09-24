import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/ingestion/ingestion.dart';

class MockNotFoundHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{}')),
      404,
    );
  }
}

class MockYoutubeClient implements IYoutubeClient {
  final ExtractedResource mockResource;

  MockYoutubeClient(this.mockResource);

  @override
  Future<ExtractedResource> extractResource(String url) async => mockResource;

  @override
  Future<ExtractedResource> extractPlaylist(String playlistUrl) async => mockResource;

  @override
  Future<ExtractedResource> extractVideo(String videoUrl) async => mockResource;

  @override
  void close() {}
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Feature 6: TimestampParser Regex & Inline Delimiters', () {
    test('parses timestamps at start of line with brackets and markdown', () {
      const desc = '''
Course Outline:
* [00:00] - Introduction to Rust
* [05:30] - Memory Safety & Ownership
* [18:45] - Borrowing and Lifetimes
* [01:12:00] - Concurrency & Threads
''';

      final segments = TimestampParser.parseDescription(
        desc,
        totalVideoDurationSeconds: 6000,
      );

      expect(segments.length, 4);
      expect(segments[0].startSeconds, 0);
      expect(segments[0].title, 'Introduction to Rust');
      expect(segments[1].startSeconds, 330);
      expect(segments[1].title, 'Memory Safety & Ownership');
      expect(segments[2].startSeconds, 1125);
      expect(segments[3].startSeconds, 4320); // 1h 12m = 4320s
      expect(segments[3].durationSeconds, 6000 - 4320);
    });

    test('parses timestamps at end of lines or after titles', () {
      const desc = '''
Chapter timestamps:
Introduction: 00:00
Architecture Overview: 08:30
Implementation Phase: 25:10
Summary & Next Steps: 50:00
''';

      final segments = TimestampParser.parseDescription(
        desc,
        totalVideoDurationSeconds: 3600,
      );

      expect(segments.length, 4);
      expect(segments[0].startSeconds, 0);
      expect(segments[0].title, 'Introduction');
      expect(segments[1].startSeconds, 510);
      expect(segments[1].title, 'Architecture Overview');
      expect(segments[2].startSeconds, 1510);
      expect(segments[2].title, 'Implementation Phase');
      expect(segments[3].startSeconds, 3000);
      expect(segments[3].title, 'Summary & Next Steps');
    });

    test('parses single-line inline timestamps separated by bullet delimiters', () {
      const desc = '00:00 Intro • 03:45 Fundamentals | 12:30 Advanced Patterns ~ 28:00 Conclusion';

      final segments = TimestampParser.parseDescription(
        desc,
        totalVideoDurationSeconds: 2400,
      );

      expect(segments.length, 4);
      expect(segments[0].startSeconds, 0);
      expect(segments[0].title, 'Intro');
      expect(segments[1].startSeconds, 225);
      expect(segments[1].title, 'Fundamentals');
      expect(segments[2].startSeconds, 750);
      expect(segments[2].title, 'Advanced Patterns');
      expect(segments[3].startSeconds, 1680);
      expect(segments[3].title, 'Conclusion');
    });

    test('guarantees first chapter starts at 0 if first timestamp is early intro', () {
      const desc = '''
00:15 Welcome to the masterclass
05:00 Setup & Tooling
15:00 First Project
''';

      final segments = TimestampParser.parseDescription(
        desc,
        totalVideoDurationSeconds: 1800,
      );

      expect(segments.first.startSeconds, 0);
      expect(segments.first.title, 'Welcome to the masterclass');
    });
  });

  group('Feature 6: Community Comments Chapter Extraction', () {
    test('extracts chapters from pinned community comment among conversational noise', () {
      final comments = [
        'Awesome video, thanks for explaining everything so clearly!',
        'Can someone explain why line 45 has a borrow error?',
        '''
TIMESTAMPS for everyone studying this course:
00:00 Intro & Roadmap
06:20 Setting up Docker & Postgres
22:15 Database Schema & Migrations
45:00 API Endpoints & Routing
01:30:00 Authentication with JWT
02:15:30 Deployment to Production
        ''',
        'Loved the part at 22:15, so helpful!',
      ];

      final segments = TimestampParser.parseComments(
        comments,
        totalVideoDurationSeconds: 10000,
      );

      expect(segments.length, 6);
      expect(segments[0].startSeconds, 0);
      expect(segments[0].title, 'Intro & Roadmap');
      expect(segments[1].startSeconds, 380);
      expect(segments[1].title, 'Setting up Docker & Postgres');
      expect(segments[2].startSeconds, 1335);
      expect(segments[4].startSeconds, 5400); // 1h 30m
      expect(segments[5].startSeconds, 8130); // 2h 15m 30s
    });

    test('chooses the comment with best coverage when multiple timestamp comments exist', () {
      final comments = [
        '''
Short summary:
00:00 Start
10:00 Middle
        ''',
        '''
Full comprehensive table of contents:
00:00 Module 1: Basics
08:15 Module 2: State Management
20:30 Module 3: Networking & HTTP
38:00 Module 4: Persistence
55:00 Module 5: Testing
01:10:00 Module 6: Release
        ''',
      ];

      final segments = TimestampParser.parseComments(
        comments,
        totalVideoDurationSeconds: 5000,
      );

      expect(segments.length, 6);
      expect(segments[0].title, 'Module 1: Basics');
      expect(segments[5].title, 'Module 6: Release');
    });

    test('returns empty if comments have no valid chapter breakdowns (< 2 timestamps)', () {
      final comments = [
        'Great video!',
        'Check out 04:30',
        'Subscribed!',
      ];

      final segments = TimestampParser.parseComments(comments);
      expect(segments.isEmpty, isTrue);
    });
  });

  group('Feature 6: YoutubeExtractorService with Comments Fallback', () {
    test('extracts singleVideoWithTimestamps using customCommentsProvider when description has no timestamps', () async {
      const testVideoId = 'AbCdEfGhIjK';
      final extractor = YoutubeExtractorService(
        httpClient: MockNotFoundHttpClient(),
        customCommentsProvider: (videoId) async {
          if (videoId == testVideoId) {
            return [
              '''
📌 Pinned by Instructor:
00:00 Course Architecture & Objectives
12:30 Core Data Structures
34:00 Algorithm Complexity & Big-O
01:05:00 Dynamic Programming Strategies
01:45:00 Graph Traversal (BFS & DFS)
02:30:00 Mock Interview Walkthrough
              ''',
            ];
          }
          return [];
        },
      );

      try {
        final resource = await extractor.extractVideo('https://www.youtube.com/watch?v=$testVideoId');

        expect(resource.resourceType, ExtractedResourceType.singleVideoWithTimestamps);
        expect(resource.items.length, 6);

        // Verify deep-link start offsets and titles
        expect(resource.items[0].title, 'Course Architecture & Objectives');
        expect(resource.items[0].sourceUrl, contains('&t=0s'));
        expect(resource.items[0].timestampSeconds, 0);

        expect(resource.items[1].title, 'Core Data Structures');
        expect(resource.items[1].sourceUrl, contains('&t=750s'));
        expect(resource.items[1].timestampSeconds, 750);

        expect(resource.items[4].title, 'Graph Traversal (BFS & DFS)');
        expect(resource.items[4].sourceUrl, contains('&t=6300s')); // 1h 45m
        expect(resource.items[4].timestampSeconds, 6300);

        expect(resource.items[5].title, 'Mock Interview Walkthrough');
        expect(resource.items[5].sourceUrl, contains('&t=9000s')); // 2h 30m
        expect(resource.items[5].timestampSeconds, 9000);
      } finally {
        extractor.close();
      }
    });
  });

  group('Feature 6: End-to-End Curriculum Ingestion of Single Video with Timestamps', () {
    late Database db;
    late DatabaseService dbService;
    late RoadmapRepository roadmapRepo;
    late ChapterRepository chapterRepo;
    late BeatRepository beatRepo;
    late CurriculumIngestionService ingestionService;

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
                ${RoadmapColumns.startDate} TEXT,
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
                ${BeatColumns.totalParts} INTEGER NOT NULL DEFAULT 1,
                ${BeatColumns.completedParts} INTEGER NOT NULL DEFAULT 0,
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

      // Create an IYoutubeClient mock that returns singleVideoWithTimestamps extracted from comments
      final mockExtractor = MockYoutubeClient(
        const ExtractedResource(
          title: 'Complete Distributed Systems Masterclass (12 Hours)',
          description: 'A 12-hour comprehensive engineering course.',
          author: 'Systems Architect',
          sourceUrl: 'https://www.youtube.com/watch?v=mockDistSys1',
          resourceType: ExtractedResourceType.singleVideoWithTimestamps,
          items: [
            RawResourceItem(
              title: 'Introduction & Distributed Basics',
              sourceUrl: 'https://www.youtube.com/watch?v=mockDistSys1&t=0s',
              timestampSeconds: 0,
              durationSeconds: 1800, // 30 mins
              index: 0,
            ),
            RawResourceItem(
              title: 'RPC and Network Fallacies',
              sourceUrl: 'https://www.youtube.com/watch?v=mockDistSys1&t=1800s',
              timestampSeconds: 1800,
              durationSeconds: 2700, // 45 mins
              index: 1,
            ),
            RawResourceItem(
              title: 'Consensus: Paxos and Raft',
              sourceUrl: 'https://www.youtube.com/watch?v=mockDistSys1&t=4500s',
              timestampSeconds: 4500,
              durationSeconds: 4200, // 70 mins
              index: 2,
            ),
            RawResourceItem(
              title: 'Distributed Transactions & 2PC',
              sourceUrl: 'https://www.youtube.com/watch?v=mockDistSys1&t=8700s',
              timestampSeconds: 8700,
              durationSeconds: 3600, // 60 mins
              index: 3,
            ),
            RawResourceItem(
              title: 'Event-Driven Architectures with Kafka',
              sourceUrl: 'https://www.youtube.com/watch?v=mockDistSys1&t=12300s',
              timestampSeconds: 12300,
              durationSeconds: 4800, // 80 mins
              index: 4,
            ),
            RawResourceItem(
              title: 'CAP Theorem & Dynamo Partitioning',
              sourceUrl: 'https://www.youtube.com/watch?v=mockDistSys1&t=17100s',
              timestampSeconds: 17100,
              durationSeconds: 3000, // 50 mins
              index: 5,
            ),
            RawResourceItem(
              title: 'Observability & Distributed Tracing',
              sourceUrl: 'https://www.youtube.com/watch?v=mockDistSys1&t=20100s',
              timestampSeconds: 20100,
              durationSeconds: 2400, // 40 mins
              index: 6,
            ),
            RawResourceItem(
              title: 'Production Incident Post-Mortems',
              sourceUrl: 'https://www.youtube.com/watch?v=mockDistSys1&t=22500s',
              timestampSeconds: 22500,
              durationSeconds: 2700, // 45 mins
              index: 7,
            ),
          ],
        ),
      );

      ingestionService = CurriculumIngestionService(
        youtubeClient: mockExtractor,
        roadmapRepo: roadmapRepo,
        chapterRepo: chapterRepo,
        beatRepo: beatRepo,
      );
    });

    tearDown(() async {
      await db.close();
      dbService.setDatabaseForTesting(null);
    });

    test('ingests multi-hour single video chapters with zero drops and deep links', () async {
      final result = await ingestionService.ingestFromUrl(
        url: 'https://www.youtube.com/watch?v=mockDistSys1',
      );

      expect(result.roadmapId.isNotEmpty, isTrue);
      expect(result.beatsCount, 8); // Zero drop guarantee: exactly 8 beats
      expect(result.chaptersCount, inInclusiveRange(2, 6));

      // Verify database records
      final allRoadmaps = await roadmapRepo.getActiveRoadmaps();
      expect(allRoadmaps.length, 1);
      final roadmap = allRoadmaps.first;
      expect(roadmap.title, 'Complete Distributed Systems Masterclass (12 Hours)');

      final chapters = await chapterRepo.getChaptersByRoadmapId(roadmap.id);
      expect(chapters.isNotEmpty, isTrue);

      final allBeats = await beatRepo.getBeatsByRoadmapId(roadmap.id);
      expect(allBeats.length, 8);

      // Verify each beat has deep link URL and effort weight derived
      for (final beat in allBeats) {
        expect(beat.sourceUrl, contains('&t='));
        expect(beat.effortWeight, greaterThan(0));
      }

      // Check first and last beats
      expect(allBeats.first.title, 'Introduction & Distributed Basics');
      expect(allBeats.first.sourceUrl, 'https://www.youtube.com/watch?v=mockDistSys1&t=0s');

      expect(allBeats[2].title, 'Consensus: Paxos and Raft');
      expect(allBeats[2].sourceUrl, 'https://www.youtube.com/watch?v=mockDistSys1&t=4500s');

      expect(allBeats.last.title, 'Production Incident Post-Mortems');
      expect(allBeats.last.sourceUrl, 'https://www.youtube.com/watch?v=mockDistSys1&t=22500s');
    });
  });
}
