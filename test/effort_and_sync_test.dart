import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rythem_app/core/database/database_service.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/database/repositories/beat_repository.dart';
import 'package:rythem_app/core/database/repositories/chapter_repository.dart';
import 'package:rythem_app/core/database/repositories/roadmap_repository.dart';
import 'package:rythem_app/core/ingestion/models/extracted_resource.dart';
import 'package:rythem_app/core/ingestion/parsers/effort_weight_calculator.dart';
import 'package:rythem_app/core/ingestion/services/curriculum_ingestion_service.dart';
import 'package:rythem_app/core/ingestion/services/youtube_extractor_service.dart';
import 'package:rythem_app/core/database/repositories/app_settings_repository.dart';
import 'package:rythem_app/core/backup/services/backup_service.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/explore/roadmap_detail_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MockYoutubeClient implements IYoutubeClient {
  final Map<String, ExtractedResource> playlistResponses = {};

  @override
  Future<ExtractedResource> extractPlaylist(String playlistUrl) async {
    if (playlistResponses.containsKey(playlistUrl)) {
      return playlistResponses[playlistUrl]!;
    }
    return ExtractedResource(
      title: 'Empty Playlist',
      sourceUrl: playlistUrl,
      resourceType: ExtractedResourceType.playlist,
      items: const [],
    );
  }

  @override
  Future<ExtractedResource> extractResource(String url) async => extractPlaylist(url);

  @override
  Future<ExtractedResource> extractVideo(String videoUrl) async {
    return ExtractedResource(
      title: 'Video',
      sourceUrl: videoUrl,
      resourceType: ExtractedResourceType.singleVideo,
      items: const [],
    );
  }

  @override
  void close() {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('10-Minute Video Effort Calculation Engine Tests', () {
    test('calculates 10-minute video as exactly 1.0 effort point', () {
      expect(EffortWeightCalculator.calculate(600), 1.0);
    });

    test('calculates 14-minute video as 1.4 effort points (10 min = 1.0 + 4 min = 0.4)', () {
      // 14 mins * 60 = 840 seconds
      expect(EffortWeightCalculator.calculate(840), 1.4);
    });

    test('calculates 25-minute video as 2.5 effort points', () {
      // 25 mins * 60 = 1500 seconds
      expect(EffortWeightCalculator.calculate(1500), 2.5);
    });

    test('calculates 5-minute video as 0.5 effort points', () {
      // 5 mins * 60 = 300 seconds
      expect(EffortWeightCalculator.calculate(300), 0.5);
    });

    test('calculates 1-minute video as 0.1 effort points', () {
      // 1 min * 60 = 60 seconds
      expect(EffortWeightCalculator.calculate(60), 0.1);
    });

    test('calculates short sub-minute clip clamped to minimum 0.1 effort point', () {
      expect(EffortWeightCalculator.calculate(25), 0.1);
    });

    test('calculates long video clamped to maximum 50.0 effort points', () {
      // 10 hours = 36000 seconds -> 60.0 -> clamped to 50.0
      expect(EffortWeightCalculator.calculate(36000), 50.0);
    });

    test('calculateForTimestampDelta calculates accurate effort for chaptered timestamps', () {
      // 10 min chapter (600s) = 1.0 pt
      expect(EffortWeightCalculator.calculateForTimestampDelta(0, 600), 1.0);
      // 14 min chapter (840s) = 1.4 pts
      expect(EffortWeightCalculator.calculateForTimestampDelta(120, 960), 1.4);
      // fallback without next timestamp defaults to 1.0 pt
      expect(EffortWeightCalculator.calculateForTimestampDelta(0, null), 1.0);
    });
  });

  group('Refetch, Sync & Exact Video ID Remapping Tests', () {
    late DatabaseService dbService;
    late RoadmapRepository roadmapRepo;
    late ChapterRepository chapterRepo;
    late BeatRepository beatRepo;
    late _MockYoutubeClient mockYt;
    late CurriculumIngestionService ingestionService;

    setUp(() async {
      await DatabaseService.instance.initInMemoryForTesting();
      dbService = DatabaseService.instance;
      roadmapRepo = RoadmapRepository(dbService: dbService);
      chapterRepo = ChapterRepository(dbService: dbService);
      beatRepo = BeatRepository(dbService: dbService);
      mockYt = _MockYoutubeClient();

      ingestionService = CurriculumIngestionService(
        youtubeClient: mockYt,
        roadmapRepo: roadmapRepo,
        chapterRepo: chapterRepo,
        beatRepo: beatRepo,
      );
    });

    tearDown(() async {
      await dbService.close();
    });

    test('syncAndRemapRoadmapResources maps 10-min effort by video ID, appends new videos, and preserves completion', () async {
      final now = DateTime.now();
      const rmId = 'rm_sync_test';
      const chId = 'ch_sync_1';
      const playlistUrl = 'https://www.youtube.com/playlist?list=PL_TEST_SYNC';

      await roadmapRepo.createRoadmap(RoadmapEntity(
        id: rmId,
        title: 'Linear Algebra & Dynamic Systems',
        createdAt: now,
        updatedAt: now,
      ));

      await chapterRepo.createChapter(ChapterEntity(
        id: chId,
        roadmapId: rmId,
        title: 'Matrix Transformations',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      // Initial beat 1: was created with old 1.0 effort, already marked completed by user
      final initialBeat1 = BeatEntity(
        id: 'beat_v1',
        chapterId: chId,
        roadmapId: rmId,
        title: 'Video 1 Old Title',
        sourceUrl: 'https://www.youtube.com/watch?v=VIDEO_1_ID&list=PL_TEST_SYNC',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: true,
        completedAt: now.subtract(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );

      // Initial beat 2: was created with 2.0 effort, not completed
      final initialBeat2 = BeatEntity(
        id: 'beat_v2',
        chapterId: chId,
        roadmapId: rmId,
        title: 'Video 2 Old Title',
        sourceUrl: 'https://www.youtube.com/watch?v=VIDEO_2_ID&list=PL_TEST_SYNC',
        effortWeight: 2.0,
        sortOrder: 1,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      );

      await beatRepo.createBeatsBatch([initialBeat1, initialBeat2]);

      // Mock playlist returns:
      // Video 1: 14 mins (840s) -> should remap to 1.4 effort
      // Video 2: 25 mins (1500s) -> should remap to 2.5 effort
      // Video 3: 10 mins (600s) -> brand new video uploaded by creator!
      mockYt.playlistResponses[playlistUrl] = const ExtractedResource(
        title: 'Linear Algebra Playlist',
        sourceUrl: playlistUrl,
        resourceType: ExtractedResourceType.playlist,
        items: [
          RawResourceItem(
            title: 'Vector Dot Product and Projections',
            sourceUrl: 'https://www.youtube.com/watch?v=VIDEO_1_ID',
            durationSeconds: 840, // 14 mins -> 1.4 pts
            index: 0,
          ),
          RawResourceItem(
            title: 'Determinants and Inverses',
            sourceUrl: 'https://www.youtube.com/watch?v=VIDEO_2_ID',
            durationSeconds: 1500, // 25 mins -> 2.5 pts
            index: 1,
          ),
          RawResourceItem(
            title: 'Eigenvalues and Eigenvectors (New Episode)',
            sourceUrl: 'https://www.youtube.com/watch?v=VIDEO_3_ID',
            durationSeconds: 600, // 10 mins -> 1.0 pt
            index: 2,
          ),
        ],
      );

      // Run sync
      final result = await ingestionService.syncAndRemapRoadmapResources(rmId);

      expect(result.updatedTopicsCount, 2);
      expect(result.newTopicsAddedCount, 1);
      // Total effort: 1.4 + 2.5 + 1.0 = 4.9 pts
      expect(result.totalEffortPoints, 4.9);

      // Verify Video 1: completion strictly preserved, effort updated to 1.4
      final reloadedBeat1 = await beatRepo.getBeatById('beat_v1');
      expect(reloadedBeat1, isNotNull);
      expect(reloadedBeat1!.isCompleted, isTrue);
      expect(reloadedBeat1.completedAt, isNotNull);
      expect(reloadedBeat1.effortWeight, 1.4);
      expect(reloadedBeat1.title, 'Vector Dot Product and Projections');

      // Verify Video 2: uncompleted, effort updated to 2.5
      final reloadedBeat2 = await beatRepo.getBeatById('beat_v2');
      expect(reloadedBeat2, isNotNull);
      expect(reloadedBeat2!.isCompleted, isFalse);
      expect(reloadedBeat2.effortWeight, 2.5);
      expect(reloadedBeat2.title, 'Determinants and Inverses');

      // Verify Video 3: appended cleanly
      final allBeats = await beatRepo.getBeatsByChapterId(chId);
      expect(allBeats.length, 3);
      final newBeat = allBeats.firstWhere((b) => b.sourceUrl!.contains('VIDEO_3_ID'));
      expect(newBeat.title, 'Eigenvalues and Eigenvectors (New Episode)');
      expect(newBeat.effortWeight, 1.0);
      expect(newBeat.isCompleted, isFalse);
    });
  });

  group('Round Icon-Only Action Buttons in RoadmapDetailScreen Tests', () {
    final now = DateTime.now();

    final testRoadmap = RoadmapEntity(
      id: 'rm_ui_test',
      title: 'Neural Architecture Search',
      createdAt: now,
      updatedAt: now,
    );

    final testChapter = ChapterEntity(
      id: 'ch_ui_1',
      roadmapId: 'rm_ui_test',
      title: 'Differentiable Search Space',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );

    final testBeat = BeatEntity(
      id: 'beat_ui_1',
      chapterId: 'ch_ui_1',
      roadmapId: 'rm_ui_test',
      title: 'DARTS Framework Implementation',
      sourceUrl: 'https://www.youtube.com/watch?v=TEST_DARTS',
      effortWeight: 1.4,
      sortOrder: 0,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    );

    testWidgets('renders round Sync button and round Play button without Add or Watch text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: RoadmapDetailScreen(
              roadmap: testRoadmap,
              chapters: [testChapter],
              beats: [testBeat],
              onBeatToggled: (_, __) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify redundant "Add" text button was removed
      expect(find.text('Add'), findsNothing);

      // Verify round Sync button exists in top bar
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

      // Verify redundant "Watch" text button was replaced by round Play icon
      expect(find.text('Watch'), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsAtLeastNWidgets(1));

      // Verify energy symbol (Icons.bolt_rounded) is used instead of "video" or "effort" text
      expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
      expect(find.text('video'), findsNothing);
      expect(find.text('linked'), findsNothing);
      expect(find.text('1.4 effort'), findsNothing);

      // Verify EFFORT stats chip exists in header
      expect(find.text('EFFORT'), findsOneWidget);
    });
  });

  group('Automatic Effort Normalization on Backup Import Tests', () {
    test('importBackupJson normalizes effort weights to 10-minute system and preserves integrity', () async {
      await DatabaseService.instance.initInMemoryForTesting();
      final dbService = DatabaseService.instance;
      final backupService = BackupService(dbService: dbService);
      final beatRepo = BeatRepository(dbService: dbService);

      final now = DateTime.now().toIso8601String();
      final backupPayload = '''
      {
        "app": "rythem",
        "version": 1,
        "exported_at": "$now",
        "tables": {
          "roadmaps": [
            {
              "id": "rm_import_test",
              "title": "Algorithms & Systems",
              "status": "active",
              "is_primary": 1,
              "created_at": "$now",
              "updated_at": "$now"
            }
          ],
          "chapters": [
            {
              "id": "ch_import_1",
              "roadmap_id": "rm_import_test",
              "title": "Core Module",
              "sort_order": 0,
              "created_at": "$now",
              "updated_at": "$now"
            }
          ],
          "beats": [
            {
              "id": "beat_imp_1",
              "chapter_id": "ch_import_1",
              "roadmap_id": "rm_import_test",
              "title": "Topic 1 with 0 effort",
              "source_url": "https://www.youtube.com/watch?v=TEST_VID_1",
              "effort_weight": 0.0,
              "sort_order": 0,
              "is_completed": 0,
              "created_at": "$now",
              "updated_at": "$now"
            },
            {
              "id": "beat_imp_2",
              "chapter_id": "ch_import_1",
              "roadmap_id": "rm_import_test",
              "title": "Topic 2 with 1.4 effort",
              "source_url": "https://www.youtube.com/watch?v=TEST_VID_2",
              "effort_weight": 1.4,
              "sort_order": 1,
              "is_completed": 1,
              "created_at": "$now",
              "updated_at": "$now"
            }
          ],
          "beat_logs": [],
          "app_settings": []
        }
      }
      ''';

      final result = await backupService.importBackupJson(backupPayload);
      expect(result['roadmaps'], 1);
      expect(result['beats'], 2);

      // Verify beat 1 effort weight was normalized from 0.0 to 1.0
      final b1 = await beatRepo.getBeatById('beat_imp_1');
      expect(b1, isNotNull);
      expect(b1!.effortWeight, 1.0);

      // Verify beat 2 preserved 1.4 effort weight
      final b2 = await beatRepo.getBeatById('beat_imp_2');
      expect(b2, isNotNull);
      expect(b2!.effortWeight, 1.4);
      expect(b2.isCompleted, isTrue);

      await dbService.close();
    });
  });

  group('Fast Sync & Playlist Remapping Tests', () {
    test('syncAndRemapRoadmapResources uses stored parent playlist URL to remap beats', () async {
      await DatabaseService.instance.initInMemoryForTesting();
      final dbService = DatabaseService.instance;
      final mockYt = _MockYoutubeClient();

      mockYt.playlistResponses['https://www.youtube.com/playlist?list=PL_TEST_SYNC'] = const ExtractedResource(
        title: 'Fast Sync Playlist',
        sourceUrl: 'https://www.youtube.com/playlist?list=PL_TEST_SYNC',
        resourceType: ExtractedResourceType.playlist,
        items: [
          RawResourceItem(
            title: 'Video 1 Updated Title',
            sourceUrl: 'https://www.youtube.com/watch?v=SYNC_VID_1',
            durationSeconds: 900, // 15 mins = 1.5 effort
            index: 0,
          ),
          RawResourceItem(
            title: 'Video 2 Updated Title',
            sourceUrl: 'https://www.youtube.com/watch?v=SYNC_VID_2',
            durationSeconds: 1500, // 25 mins = 2.5 effort
            index: 1,
          ),
        ],
      );

      final ingestionService = CurriculumIngestionService(
        youtubeClient: mockYt,
        roadmapRepo: RoadmapRepository(dbService: dbService),
        chapterRepo: ChapterRepository(dbService: dbService),
        beatRepo: BeatRepository(dbService: dbService),
        settingsRepo: AppSettingsRepository(dbService: dbService),
      );

      final now = DateTime.now();
      final roadmap = RoadmapEntity(
        id: 'rm_fast_sync',
        title: 'Fast Sync Track',
        createdAt: now,
        updatedAt: now,
      );
      final chapter = ChapterEntity(
        id: 'ch_fast_sync',
        roadmapId: 'rm_fast_sync',
        title: 'Chapter 1',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      final beats = [
        BeatEntity(
          id: 'b_sync_1',
          chapterId: 'ch_fast_sync',
          roadmapId: 'rm_fast_sync',
          title: 'Old Title 1',
          sourceUrl: 'https://www.youtube.com/watch?v=SYNC_VID_1',
          effortWeight: 1.0,
          sortOrder: 0,
          isCompleted: false,
          createdAt: now,
          updatedAt: now,
        ),
        BeatEntity(
          id: 'b_sync_2',
          chapterId: 'ch_fast_sync',
          roadmapId: 'rm_fast_sync',
          title: 'Old Title 2',
          sourceUrl: 'https://www.youtube.com/watch?v=SYNC_VID_2',
          effortWeight: 1.0,
          sortOrder: 1,
          isCompleted: true, // Should preserve completion!
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await RoadmapRepository(dbService: dbService).createRoadmap(roadmap);
      await ChapterRepository(dbService: dbService).createChaptersBatch([chapter]);
      await BeatRepository(dbService: dbService).createBeatsBatch(beats);
      await AppSettingsRepository(dbService: dbService)
          .setSetting('roadmap_source_url_rm_fast_sync', 'https://www.youtube.com/playlist?list=PL_TEST_SYNC');

      final result = await ingestionService.syncAndRemapRoadmapResources('rm_fast_sync');
      expect(result.updatedTopicsCount, 2);
      expect(result.totalEffortPoints, 4.0); // 1.5 + 2.5 = 4.0

      final beatRepo = BeatRepository(dbService: dbService);
      final b1 = await beatRepo.getBeatById('b_sync_1');
      expect(b1!.title, 'Video 1 Updated Title');
      expect(b1.effortWeight, 1.5);

      final b2 = await beatRepo.getBeatById('b_sync_2');
      expect(b2!.title, 'Video 2 Updated Title');
      expect(b2.effortWeight, 2.5);
      expect(b2.isCompleted, isTrue); // Preserved!

      await dbService.close();
    });
  });
}
