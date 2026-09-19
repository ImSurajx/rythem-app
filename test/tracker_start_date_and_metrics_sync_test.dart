import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/flow/flow_screen.dart';
import 'package:rythem_app/features/metrics/widgets/full_month_streak_calendar.dart';
import 'package:rythem_app/features/metrics/widgets/performance_graphs_card.dart';

class FakeBeatLogRepository extends BeatLogRepository {
  Map<String, int> fakeMonthActivity;
  List<DailyBeatCount> fakeRecentActivity;
  int fakeStreak;
  int fakeTotal;

  FakeBeatLogRepository({
    this.fakeMonthActivity = const {},
    this.fakeRecentActivity = const [],
    this.fakeStreak = 0,
    this.fakeTotal = 0,
  });

  @override
  Future<Map<String, int>> getActivityForMonth(int year, int month) async {
    return fakeMonthActivity;
  }

  @override
  Future<List<DailyBeatCount>> getRecentActivity({int daysCount = 7}) async {
    return fakeRecentActivity;
  }

  @override
  Future<List<DailyBeatCount>> getAllDailyActivity() async {
    return fakeRecentActivity;
  }

  @override
  Future<Map<String, int>> getActivityForDateRange(String startStr, String endStr) async {
    return fakeMonthActivity;
  }

  @override
  Future<int> getCurrentStreak() async {
    return fakeStreak;
  }

  @override
  Future<int> getTotalBeatsCompleted() async {
    return fakeTotal;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Pacing Budget & Tracker Start Date (Unit Tests)', () {
    setUp(() async {
      await DatabaseService.instance.initInMemoryForTesting();
    });

    tearDown(() async {
      await DatabaseService.instance.close();
    });

    test('Tracker with future startDate returns isUpcoming=true and does not suggest beats today', () async {
      final roadmapRepo = RoadmapRepository();
      final chapterRepo = ChapterRepository();
      final beatRepo = BeatRepository();
      final pacingService = PacingService();

      final now = DateTime.now();
      final futureStart = now.add(const Duration(days: 5));
      final targetDate = now.add(const Duration(days: 30));

      final rm = RoadmapEntity(
        id: 'future_rm_1',
        title: 'Future Machine Learning Track',
        startDate: futureStart,
        targetCompletionDate: targetDate,
        createdAt: now,
        updatedAt: now,
      );
      await roadmapRepo.createRoadmap(rm);

      final ch = ChapterEntity(
        id: 'ch_future_1',
        roadmapId: rm.id,
        title: 'Linear Algebra',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      await chapterRepo.createChapter(ch);

      for (int i = 0; i < 3; i++) {
        await beatRepo.createBeat(BeatEntity(
          id: 'future_beat_$i',
          chapterId: ch.id,
          roadmapId: rm.id,
          title: 'Topic $i',
          effortWeight: 1.0,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        ));
      }

      final budget = await pacingService.computePacingBudget(rm.id);

      expect(budget.isUpcoming, isTrue);
      expect(budget.todaysBeats, isEmpty);
      expect(budget.todayEffortShare, 0.0);
      expect(budget.daysUntilStart, greaterThanOrEqualTo(4));
    });

    test('Deleting a roadmap explicitly purges daily_missions and beat_logs from SQLite', () async {
      final roadmapRepo = RoadmapRepository();
      final chapterRepo = ChapterRepository();
      final beatRepo = BeatRepository();
      final missionRepo = DailyMissionRepository();
      final beatLogRepo = BeatLogRepository();

      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);

      final rm = RoadmapEntity(
        id: 'rm_to_purge',
        title: 'Purge Track',
        createdAt: now,
        updatedAt: now,
      );
      await roadmapRepo.createRoadmap(rm);

      final ch = ChapterEntity(
        id: 'ch_purge',
        roadmapId: rm.id,
        title: 'Purge Chapter',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      await chapterRepo.createChapter(ch);

      final beat = BeatEntity(
        id: 'b_purge_1',
        chapterId: ch.id,
        roadmapId: rm.id,
        title: 'Beat to Purge',
        createdAt: now,
        updatedAt: now,
      );
      await beatRepo.createBeat(beat);

      // Create a daily mission
      await missionRepo.setDailyMission(
        roadmapId: rm.id,
        date: todayStr,
        beatIds: [beat.id],
      );

      // Create a beat log
      await beatLogRepo.logBeatCompletion(
        beatId: beat.id,
        roadmapId: rm.id,
        completedDate: todayStr,
      );

      // Verify records exist before deletion
      expect(await roadmapRepo.getRoadmapById(rm.id), isNotNull);
      expect(await chapterRepo.getChaptersByRoadmapId(rm.id), hasLength(1));
      expect(await beatRepo.getBeatsByRoadmapId(rm.id), hasLength(1));
      expect(await beatLogRepo.getTotalBeatsCompleted(), 1);
      expect(await missionRepo.getMissionBeatsForDate(rm.id, todayStr), hasLength(1));

      // Now call deleteRoadmap
      await roadmapRepo.deleteRoadmap(rm.id);

      // Verify that the roadmap and ALL dependent records are completely purged
      expect(await roadmapRepo.getRoadmapById(rm.id), isNull);
      expect(await chapterRepo.getChaptersByRoadmapId(rm.id), isEmpty);
      expect(await beatRepo.getBeatsByRoadmapId(rm.id), isEmpty);
      expect(await beatLogRepo.getTotalBeatsCompleted(), 0);
      expect(await missionRepo.getMissionBeatsForDate(rm.id, todayStr), isEmpty);
    });
  });

  group('Flow & Metrics UI Synchronization (Widget Tests)', () {
    testWidgets('FlowScreen renders scheduled start card and does not show beats when track is upcoming',
        (tester) async {
      final now = DateTime.now();
      final futureStart = now.add(const Duration(days: 3));
      final targetDate = now.add(const Duration(days: 20));

      final rm = RoadmapEntity(
        id: 'upcoming_ui_rm',
        title: 'Upcoming Go Track',
        startDate: futureStart,
        targetCompletionDate: targetDate,
        createdAt: now,
        updatedAt: now,
      );

      final ch = ChapterEntity(
        id: 'ch_upcoming',
        roadmapId: rm.id,
        title: 'Go Basics',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      final beats = List.generate(
        3,
        (i) => BeatEntity(
          id: 'up_beat_$i',
          chapterId: ch.id,
          roadmapId: rm.id,
          title: 'Go Goroutines $i',
          effortWeight: 1.0,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        ),
      );

      const budget = PacingBudget(
        roadmapId: 'upcoming_ui_rm',
        remainingEffort: 3.0,
        daysLeft: 20,
        todayEffortShare: 0.0,
        todaysBeats: [],
        todaysSelectedEffort: 0.0,
        isUpcoming: true,
        daysUntilStart: 3,
      );

      bool startEarlyCalled = false;
      final fakeRepo = FakeBeatLogRepository();

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: rm,
              allRoadmaps: [rm],
              chapters: [ch],
              allBeats: beats,
              pacingBudget: budget,
              chaptersByRoadmap: {rm.id: [ch]},
              beatsByRoadmap: {rm.id: beats},
              budgetsByRoadmap: {rm.id: budget},
              streakDays: 0,
              beatLogRepo: fakeRepo,
              onSwitchRoadmap: () {},
              onBeatToggled: (_, __) async {},
              onStartEarly: (track) async {
                startEarlyCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that no beat checkboxes/titles are suggested for today
      expect(find.text('Go Goroutines 0'), findsNothing);
      expect(find.text('Go Goroutines 1'), findsNothing);

      // Verify scheduled kickoff card is rendered
      expect(find.textContaining('KICKOFF'), findsOneWidget);
      expect(find.textContaining('Track Scheduled for'), findsOneWidget);
      expect(find.text('Start Today Early'), findsOneWidget);

      // Tap "Start Today Early"
      await tester.tap(find.text('Start Today Early'));
      await tester.pump();
      expect(startEarlyCalled, isTrue);
    });

    testWidgets('FullMonthStreakCalendar and PerformanceGraphsCard refresh via DatabaseEventBus on deletion',
        (tester) async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);

      final fakeRepo = FakeBeatLogRepository(
        fakeMonthActivity: {todayStr: 1},
        fakeRecentActivity: [DailyBeatCount(date: todayStr, count: 1)],
        fakeStreak: 1,
        fakeTotal: 1,
      );

      const themeColors = RythemColors.dark;

      // Mount FullMonthStreakCalendar
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FullMonthStreakCalendar(
                beatLogRepo: fakeRepo,
                themeColors: themeColors,
                isDark: true,
                streakDays: 1,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('1 beats • 1 active days'), findsOneWidget);

      // Mount PerformanceGraphsCard
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PerformanceGraphsCard(
                beatLogRepo: fakeRepo,
                recentActivity: fakeRepo.fakeRecentActivity,
                themeColors: themeColors,
                isDark: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('1'), findsWidgets);

      // Simulate roadmap deletion: clear fake repo activity and emit DatabaseEvent
      fakeRepo.fakeMonthActivity = {};
      fakeRepo.fakeRecentActivity = [];
      fakeRepo.fakeStreak = 0;
      fakeRepo.fakeTotal = 0;

      DatabaseEventBus.instance.emit(const DatabaseEvent(
        type: DatabaseEventType.roadmapDeleted,
        entityId: 'rm_live_1',
        roadmapId: 'rm_live_1',
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check FullMonthStreakCalendar refreshed to 0
      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FullMonthStreakCalendar(
                beatLogRepo: fakeRepo,
                themeColors: themeColors,
                isDark: true,
                streakDays: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('0 beats • 0 active days'), findsOneWidget);
    });
  });
}
