import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/ingestion/models/extracted_resource.dart';
import 'package:rythem_app/core/ingestion/services/resource_sync_service.dart';
import 'package:rythem_app/core/ingestion/services/youtube_extractor_service.dart';

class MockYoutubeClient implements IYoutubeClient {
  final Map<String, ExtractedResource> urlToResource;

  MockYoutubeClient(this.urlToResource);

  @override
  Future<ExtractedResource> extractResource(String url) async {
    if (urlToResource.containsKey(url)) {
      return urlToResource[url]!;
    }
    for (final entry in urlToResource.entries) {
      if (url.contains(entry.key) || entry.key.contains(url)) {
        return entry.value;
      }
    }
    throw Exception('Resource not found in mock for $url');
  }

  @override
  Future<ExtractedResource> extractPlaylist(String playlistUrl) =>
      extractResource(playlistUrl);

  @override
  Future<ExtractedResource> extractVideo(String videoUrl) =>
      extractResource(videoUrl);

  @override
  void close() {}
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

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
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
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
  });

  group('ResourceSyncService Tests', () {
    test('discoverResourceUrl correctly detects playlist and video URLs', () {
      final now = DateTime.now();
      final syncService = ResourceSyncService();

      // Case 1: Discovered from beat sourceUrl with list parameter
      final beatWithPlaylist = BeatEntity(
        id: 'beat-1',
        chapterId: 'ch-1',
        roadmapId: 'rm-1',
        title: 'Video 1',
        sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLlaN88a76b-sample-list',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      final roadmap1 = RoadmapEntity(
        id: 'rm-1',
        title: 'Track 1',
        description: 'Just a normal track',
        createdAt: now,
        updatedAt: now,
      );

      final discovered1 = syncService.discoverResourceUrl(
        roadmap: roadmap1,
        beats: [beatWithPlaylist],
      );
      expect(discovered1, contains('list=PLlaN88a76b-sample-list'));

      // Case 2: Discovered from roadmap description
      final roadmap2 = RoadmapEntity(
        id: 'rm-2',
        title: 'Track 2',
        description: 'Full course here: https://www.youtube.com/playlist?list=PLmock12345',
        createdAt: now,
        updatedAt: now,
      );
      final discovered2 = syncService.discoverResourceUrl(
        roadmap: roadmap2,
        beats: [],
      );
      expect(discovered2, 'https://www.youtube.com/playlist?list=PLmock12345');

      // Case 3: Discovered single video URL
      final beatVideoOnly = BeatEntity(
        id: 'beat-2',
        chapterId: 'ch-1',
        roadmapId: 'rm-1',
        title: 'Standalone Video',
        sourceUrl: 'https://youtu.be/sampleVideoId',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      final discovered3 = syncService.discoverResourceUrl(
        roadmap: roadmap1,
        beats: [beatVideoOnly],
      );
      expect(discovered3, contains('sampleVideo'));

      // Case 4: No URL present
      final discovered4 = syncService.discoverResourceUrl(
        roadmap: roadmap1,
        beats: [
          BeatEntity(
            id: 'beat-3',
            chapterId: 'ch-1',
            roadmapId: 'rm-1',
            title: 'Offline reading',
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          )
        ],
      );
      expect(discovered4, isNull);
    });

    test('syncRoadmapResource refreshes titles & durations while preserving completion status', () async {
      final now = DateTime.now();
      final roadmap = RoadmapEntity(
        id: 'rm-sync-1',
        title: 'Flutter Full Course',
        description: 'https://www.youtube.com/playlist?list=PLflutter_master',
        createdAt: now,
        updatedAt: now,
      );
      await roadmapRepo.createRoadmap(roadmap);

      final chapter = ChapterEntity(
        id: 'ch-sync-1',
        roadmapId: roadmap.id,
        title: 'Module 1',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      await chapterRepo.createChapter(chapter);

      // Existing beat with user completion progress and multi-part state
      final completedBeat = BeatEntity(
        id: 'beat-existing-1',
        chapterId: chapter.id,
        roadmapId: roadmap.id,
        title: 'Old Title: Intro to Flutter',
        sourceUrl: 'https://www.youtube.com/watch?v=vid1&list=PLflutter_master',
        effortWeight: 1.0,
        isCompleted: true,
        completedAt: now.subtract(const Duration(days: 1)),
        completedParts: 2,
        totalParts: 2,
        timestampSeconds: 0,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      await beatRepo.createBeat(completedBeat);

      // Mock fresh playlist from YouTube with updated title, new duration, and a NEW second video
      const mockResource = ExtractedResource(
        title: 'Flutter Full Course 2026',
        description: 'Complete updated flutter syllabus',
        sourceUrl: 'https://www.youtube.com/playlist?list=PLflutter_master',
        resourceType: ExtractedResourceType.playlist,
        items: [
          RawResourceItem(
            title: 'Updated Title: 01 - Flutter Fundamentals (2026 Edition)',
            sourceUrl: 'https://www.youtube.com/watch?v=vid1&list=PLflutter_master',
            durationSeconds: 1800, // 30 min -> ~1.5 effortWeight
            timestampSeconds: 15,
            index: 0,
          ),
          RawResourceItem(
            title: '02 - State Management with Riverpod & Signals',
            sourceUrl: 'https://www.youtube.com/watch?v=vid2&list=PLflutter_master',
            durationSeconds: 3600, // 60 min -> 3.0 effortWeight
            timestampSeconds: 0,
            index: 1,
          ),
        ],
      );

      final mockClient = MockYoutubeClient({
        'PLflutter_master': mockResource,
      });

      final syncService = ResourceSyncService(
        youtubeClient: mockClient,
        roadmapRepo: roadmapRepo,
        chapterRepo: chapterRepo,
        beatRepo: beatRepo,
      );

      final result = await syncService.syncRoadmapResource(roadmap: roadmap);

      expect(result.success, isTrue);
      expect(result.updatedBeatsCount, 1);
      expect(result.newBeatsCount, 1);

      // Verify that existing completed beat has updated metadata but PRESERVED completion state
      final updatedExisting = await beatRepo.getBeatById('beat-existing-1');
      expect(updatedExisting, isNotNull);
      expect(updatedExisting!.title, 'Updated Title: 01 - Flutter Fundamentals (2026 Edition)');
      expect(updatedExisting.effortWeight, 0.5); // 1800s / 3600 = 0.5
      expect(updatedExisting.timestampSeconds, 15);
      // IMMUTABLE COMPLETION CHECKS:
      expect(updatedExisting.isCompleted, isTrue);
      expect(updatedExisting.completedAt, isNotNull);
      expect(updatedExisting.completedParts, 2);
      expect(updatedExisting.totalParts, 2);

      // Verify that new video was appended as a new beat
      final allBeats = await beatRepo.getBeatsByChapterId(chapter.id);
      expect(allBeats.length, 2);

      final newBeat = allBeats.firstWhere((b) => b.id != 'beat-existing-1');
      expect(newBeat.title, '02 - State Management with Riverpod & Signals');
      expect(newBeat.sourceUrl, contains('vid2'));
      expect(newBeat.effortWeight, 1.0); // 3600s / 3600 = 1.0
      expect(newBeat.isCompleted, isFalse);
      expect(newBeat.sortOrder, 1);
    });

    test('syncAllRoadmaps processes all roadmaps without crashing on failed tracks', () async {
      final now = DateTime.now();
      final roadmap1 = RoadmapEntity(
        id: 'rm-batch-1',
        title: 'Track A',
        description: 'https://www.youtube.com/playlist?list=PLvalid',
        createdAt: now,
        updatedAt: now,
      );
      final roadmap2 = RoadmapEntity(
        id: 'rm-batch-2',
        title: 'Track B without URL',
        description: 'Offline track',
        createdAt: now,
        updatedAt: now,
      );
      await roadmapRepo.createRoadmap(roadmap1);
      await roadmapRepo.createRoadmap(roadmap2);

      const mockResource = ExtractedResource(
        title: 'Track A Playlist',
        description: 'Track A Description',
        sourceUrl: 'https://www.youtube.com/playlist?list=PLvalid',
        resourceType: ExtractedResourceType.playlist,
        items: [],
      );

      final mockClient = MockYoutubeClient({
        'PLvalid': mockResource,
      });

      final syncService = ResourceSyncService(
        youtubeClient: mockClient,
        roadmapRepo: roadmapRepo,
        chapterRepo: chapterRepo,
        beatRepo: beatRepo,
      );

      final results = await syncService.syncAllRoadmaps();
      expect(results.length, 2);

      final result1 = results.firstWhere((r) => r.roadmapId == 'rm-batch-1');
      expect(result1.success, isFalse); // empty items
      expect(result1.message, contains('No lessons found'));

      final result2 = results.firstWhere((r) => r.roadmapId == 'rm-batch-2');
      expect(result2.success, isFalse);
      expect(result2.message, contains('No YouTube playlist or video URL'));
    });
  });
}
