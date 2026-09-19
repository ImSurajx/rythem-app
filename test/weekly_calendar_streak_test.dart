import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/flow/flow_screen.dart';

class FakeBeatLogRepository extends BeatLogRepository {
  final Map<String, int> fakeActivity;

  FakeBeatLogRepository({this.fakeActivity = const {}});

  @override
  Future<Map<String, int>> getActivityForDateRange(String startStr, String endStr) async {
    return fakeActivity;
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('BeatLogRepository Date Range Queries (Unit Test)', () {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    late Database db;
    late BeatLogRepository beatLogRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
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
            await batch.commit();
          },
        ),
      );

      DatabaseService.instance.setDatabaseForTesting(db);
      beatLogRepo = BeatLogRepository();
    });

    tearDown(() async {
      DatabaseService.instance.setDatabaseForTesting(null);
      await db.close();
    });

    test('getActivityForDateRange returns correct counts per day', () async {
      // Seed roadmap and beat
      await db.insert(DatabaseTables.roadmaps, {
        RoadmapColumns.id: 'rm_test',
        RoadmapColumns.title: 'Test Track',
        RoadmapColumns.createdAt: '2026-09-01T00:00:00.000',
        RoadmapColumns.updatedAt: '2026-09-01T00:00:00.000',
      });
      await db.insert(DatabaseTables.chapters, {
        ChapterColumns.id: 'ch_1',
        ChapterColumns.roadmapId: 'rm_test',
        ChapterColumns.title: 'Chapter 1',
        ChapterColumns.sortOrder: 0,
        ChapterColumns.createdAt: '2026-09-01T00:00:00.000',
        ChapterColumns.updatedAt: '2026-09-01T00:00:00.000',
      });
      await db.insert(DatabaseTables.beats, {
        BeatColumns.id: 'b1',
        BeatColumns.chapterId: 'ch_1',
        BeatColumns.roadmapId: 'rm_test',
        BeatColumns.title: 'Beat 1',
        BeatColumns.createdAt: '2026-09-01T00:00:00.000',
        BeatColumns.updatedAt: '2026-09-01T00:00:00.000',
      });

      // Log beats on specific dates
      await beatLogRepo.logBeatCompletion(
        beatId: 'b1',
        roadmapId: 'rm_test',
        completedDate: '2026-09-14',
      );
      await beatLogRepo.logBeatCompletion(
        beatId: 'b1',
        roadmapId: 'rm_test',
        completedDate: '2026-09-15',
      );

      final activity = await beatLogRepo.getActivityForDateRange('2026-09-14', '2026-09-20');
      expect(activity['2026-09-14'], 1);
      expect(activity['2026-09-15'], 1);
      expect(activity['2026-09-16'], isNull);
    });
  });

  group('Flow Weekly Streak Calendar Navigation & Sync Tests (Widget)', () {
    final now = DateTime.now();
    final testRoadmap = RoadmapEntity(
      id: 'rm_test',
      title: 'Navigation Test Track',
      targetCompletionDate: now.add(const Duration(days: 14)),
      createdAt: now,
      updatedAt: now,
    );

    final testChapters = [
      ChapterEntity(
        id: 'ch_1',
        roadmapId: 'rm_test',
        title: 'Foundations',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final testBeats = [
      BeatEntity(
        id: 'b1',
        chapterId: 'ch_1',
        roadmapId: 'rm_test',
        title: 'Active Task Beat',
        effortWeight: 1.0,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    const testBudget = PacingBudget(
      roadmapId: 'rm_test',
      todayEffortShare: 1.0,
      todaysSelectedEffort: 1.0,
      remainingEffort: 1.0,
      daysLeft: 14,
      todaysBeats: [],
    );

    testWidgets('Fresh tracker initializes with 0 days active and STREAK CALENDAR title', (tester) async {
      final fakeRepo = FakeBeatLogRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: testBeats,
              pacingBudget: testBudget,
              streakDays: 0,
              beatLogRepo: fakeRepo,
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('STREAK CALENDAR'), findsOneWidget);
      expect(find.text('0 days active'), findsOneWidget);
      expect(find.text('0 Day Streak'), findsOneWidget);
      // Ensure no fake 3-day streak numbers exist
      expect(find.text('3 Day Streak'), findsNothing);
      expect(find.text('3 days active'), findsNothing);
    });

    testWidgets('Navigating to previous week updates title range and reveals TODAY jump button', (tester) async {
      final fakeRepo = FakeBeatLogRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: testBeats,
              pacingBudget: testBudget,
              streakDays: 0,
              beatLogRepo: fakeRepo,
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap left chevron to go back 1 week
      final leftChevron = find.byIcon(Icons.chevron_left_rounded);
      expect(leftChevron, findsOneWidget);
      await tester.tap(leftChevron);
      await tester.pumpAndSettle();

      // In previous week: STREAK CALENDAR title is replaced with the week range, and TODAY chip appears
      expect(find.text('STREAK CALENDAR'), findsNothing);
      expect(find.text('TODAY'), findsOneWidget);

      // Tap TODAY button to return to current week
      await tester.tap(find.text('TODAY'));
      await tester.pumpAndSettle();

      // Should be back at STREAK CALENDAR
      expect(find.text('STREAK CALENDAR'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
    });

    testWidgets('Swipe left/right gestures navigate between weeks', (tester) async {
      final fakeRepo = FakeBeatLogRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: testRoadmap,
              allRoadmaps: [testRoadmap],
              chapters: testChapters,
              allBeats: testBeats,
              pacingBudget: testBudget,
              streakDays: 0,
              beatLogRepo: fakeRepo,
              onSwitchRoadmap: () {},
              onBeatToggled: (beat, val) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fling right on the swipe detector to go to previous week
      await tester.fling(
        find.byKey(const Key('weekly_calendar_swipe_detector')),
        const Offset(400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('TODAY'), findsOneWidget);

      // Fling left on the swipe detector to return to current week
      await tester.fling(
        find.byKey(const Key('weekly_calendar_swipe_detector')),
        const Offset(-400, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('STREAK CALENDAR'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
    });
  });
}
