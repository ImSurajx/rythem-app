import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/core/theme/theme.dart';
import 'package:rythem_app/features/flow/flow_screen.dart';
import 'package:rythem_app/features/flow/create_custom_task_dialog.dart';
import 'package:rythem_app/core/update/app_update_manager.dart';
import 'package:rythem_app/features/explore/widgets/chapter_accordion.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DatabaseService dbService;
  late BeatRepository beatRepo;
  late BeatLogRepository beatLogRepo;

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
    beatRepo = BeatRepository(dbService: dbService);
    beatLogRepo = BeatLogRepository(dbService: dbService);
  });

  tearDown(() async {
    await db.close();
    dbService.setDatabaseForTesting(null);
  });

  group('Custom Task Appending & Streak Tests', () {
    test('insertCustomBeatAfterLastCompleted appends right after last completed beat and shifts subsequent beats', () async {
      final now = DateTime.now();

      // Seed roadmap and chapter
      await db.insert(DatabaseTables.roadmaps, {
        RoadmapColumns.id: 'rm1',
        RoadmapColumns.title: 'Algorithms 101',
        RoadmapColumns.createdAt: now.toIso8601String(),
        RoadmapColumns.updatedAt: now.toIso8601String(),
      });
      await db.insert(DatabaseTables.chapters, {
        ChapterColumns.id: 'ch1',
        ChapterColumns.roadmapId: 'rm1',
        ChapterColumns.title: 'Sorting',
        ChapterColumns.sortOrder: 0,
        ChapterColumns.createdAt: now.toIso8601String(),
        ChapterColumns.updatedAt: now.toIso8601String(),
      });

      // Insert Beat 1 (completed) and Beat 2 (incomplete)
      await db.insert(DatabaseTables.beats, {
        BeatColumns.id: 'b1',
        BeatColumns.chapterId: 'ch1',
        BeatColumns.roadmapId: 'rm1',
        BeatColumns.title: 'Bubble Sort',
        BeatColumns.effortWeight: 1.0,
        BeatColumns.sortOrder: 0,
        BeatColumns.isCompleted: 1,
        BeatColumns.completedAt: now.toIso8601String(),
        BeatColumns.createdAt: now.toIso8601String(),
        BeatColumns.updatedAt: now.toIso8601String(),
      });
      await db.insert(DatabaseTables.beats, {
        BeatColumns.id: 'b2',
        BeatColumns.chapterId: 'ch1',
        BeatColumns.roadmapId: 'rm1',
        BeatColumns.title: 'Merge Sort',
        BeatColumns.effortWeight: 2.0,
        BeatColumns.sortOrder: 1,
        BeatColumns.isCompleted: 0,
        BeatColumns.createdAt: now.toIso8601String(),
        BeatColumns.updatedAt: now.toIso8601String(),
      });

      // Insert Custom Task: Revision
      final customBeat = await beatRepo.insertCustomBeatAfterLastCompleted(
        roadmapId: 'rm1',
        title: 'Revise Sort Complexities',
        effortWeight: 1.5,
      );

      expect(customBeat.title, 'Revise Sort Complexities');
      expect(customBeat.effortWeight, 1.5);
      expect(customBeat.isCustomTask, isTrue);
      expect(customBeat.sortOrder, 1); // Placed right after b1 (which was order 0)

      // Verify Merge Sort was shifted to sortOrder 2
      final b2After = await beatRepo.getBeatById('b2');
      expect(b2After!.sortOrder, 2);

      // Verify sequential order from getBeatsByRoadmapId
      final allBeats = await beatRepo.getBeatsByRoadmapId('rm1');
      expect(allBeats.length, 3);
      expect(allBeats[0].id, 'b1');
      expect(allBeats[1].id, customBeat.id);
      expect(allBeats[2].id, 'b2');
    });

    test('insertCustomBeatAfterLastCompleted inserts at start when 0 beats completed', () async {
      final now = DateTime.now();

      await db.insert(DatabaseTables.roadmaps, {
        RoadmapColumns.id: 'rm2',
        RoadmapColumns.title: 'Backend Roadmap',
        RoadmapColumns.createdAt: now.toIso8601String(),
        RoadmapColumns.updatedAt: now.toIso8601String(),
      });
      await db.insert(DatabaseTables.chapters, {
        ChapterColumns.id: 'ch2',
        ChapterColumns.roadmapId: 'rm2',
        ChapterColumns.title: 'Databases',
        ChapterColumns.sortOrder: 0,
        ChapterColumns.createdAt: now.toIso8601String(),
        ChapterColumns.updatedAt: now.toIso8601String(),
      });

      await db.insert(DatabaseTables.beats, {
        BeatColumns.id: 'b_existing',
        BeatColumns.chapterId: 'ch2',
        BeatColumns.roadmapId: 'rm2',
        BeatColumns.title: 'SQL Basics',
        BeatColumns.effortWeight: 1.0,
        BeatColumns.sortOrder: 0,
        BeatColumns.isCompleted: 0,
        BeatColumns.createdAt: now.toIso8601String(),
        BeatColumns.updatedAt: now.toIso8601String(),
      });

      final customBeat = await beatRepo.insertCustomBeatAfterLastCompleted(
        roadmapId: 'rm2',
        title: 'Install PostgreSQL & Setup GUI',
        effortWeight: 0.5,
      );

      expect(customBeat.sortOrder, 0);
      final existingAfter = await beatRepo.getBeatById('b_existing');
      expect(existingAfter!.sortOrder, 1);
    });

    test('completing custom task writes beat_logs and updates current streak', () async {
      final now = DateTime.now();
      await db.insert(DatabaseTables.roadmaps, {
        RoadmapColumns.id: 'rm3',
        RoadmapColumns.title: 'Daily Practice',
        RoadmapColumns.createdAt: now.toIso8601String(),
        RoadmapColumns.updatedAt: now.toIso8601String(),
      });
      await db.insert(DatabaseTables.chapters, {
        ChapterColumns.id: 'ch3',
        ChapterColumns.roadmapId: 'rm3',
        ChapterColumns.title: 'General',
        ChapterColumns.sortOrder: 0,
        ChapterColumns.createdAt: now.toIso8601String(),
        ChapterColumns.updatedAt: now.toIso8601String(),
      });

      final customBeat = await beatRepo.insertCustomBeatAfterLastCompleted(
        roadmapId: 'rm3',
        title: 'Revise Recursion',
        effortWeight: 2.0,
      );

      expect(await beatLogRepo.getCurrentStreak(), 0);

      // Toggle completion to true
      await beatRepo.toggleBeatCompletion(customBeat.id, isCompleted: true);

      final streak = await beatLogRepo.getCurrentStreak();
      expect(streak, 1);

      final todayStr = now.toIso8601String().substring(0, 10);
      final logs = await beatLogRepo.getLogsForDate(todayStr);
      expect(logs.length, 1);
      expect(logs.first.beatId, customBeat.id);
    });

    test('deleting uncompleted custom task cleans it up from tracker', () async {
      final now = DateTime.now();
      await db.insert(DatabaseTables.roadmaps, {
        RoadmapColumns.id: 'rm4',
        RoadmapColumns.title: 'Web Dev',
        RoadmapColumns.createdAt: now.toIso8601String(),
        RoadmapColumns.updatedAt: now.toIso8601String(),
      });
      await db.insert(DatabaseTables.chapters, {
        ChapterColumns.id: 'ch4',
        ChapterColumns.roadmapId: 'rm4',
        ChapterColumns.title: 'HTML',
        ChapterColumns.sortOrder: 0,
        ChapterColumns.createdAt: now.toIso8601String(),
        ChapterColumns.updatedAt: now.toIso8601String(),
      });

      final customBeat = await beatRepo.insertCustomBeatAfterLastCompleted(
        roadmapId: 'rm4',
        title: 'Read MDN docs',
        effortWeight: 1.0,
      );

      expect(await beatRepo.getBeatById(customBeat.id), isNotNull);
      await beatRepo.deleteBeat(customBeat.id);
      expect(await beatRepo.getBeatById(customBeat.id), isNull);
    });
  });

  group('CreateCustomTaskDialog Widget Tests', () {
    testWidgets('renders inputs, effort presets, and triggers onTaskCreated with selected effort', (tester) async {
      final testRoadmap = RoadmapEntity(
        id: 'rm_ui',
        title: 'System Design Track',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      String? createdTitle;
      double? createdEffort;
      String? createdUrl;
      String? createdCategory;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  CreateCustomTaskDialog.show(
                    context,
                    roadmap: testRoadmap,
                    onTaskCreated: (title, effort, url, category) {
                      createdTitle = title;
                      createdEffort = effort;
                      createdUrl = url;
                      createdCategory = category;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Custom Task'), findsOneWidget);
      expect(find.text('System Design Track'), findsOneWidget);
      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.text('TASK TITLE / TOPIC'), findsOneWidget);
      expect(find.text('DURATION'), findsOneWidget);

      // Select category 'Practice'
      await tester.tap(find.text('Practice'));
      await tester.pump();

      // Select preset 30m (30 min / 10 = 3.0 effort points)
      await tester.tap(find.text('30m'));
      await tester.pump();
      expect(find.text('30 min • ⚡ 3.0 beats'), findsOneWidget);

      // Enter task title
      await tester.enterText(find.byType(TextField).first, 'Revise Distributed Caching');
      await tester.pump();

      // Submit
      await tester.ensureVisible(find.text('Add Task'));
      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 11));

      expect(createdTitle, 'Revise Distributed Caching');
      expect(createdEffort, 3.0);
      expect(createdUrl, isNull);
      expect(createdCategory, 'Practice');
    });
  });

  group('FlowScreen Dual Actions & Custom Task Integration Tests', () {
    testWidgets('shows both Pull Next Topic and Custom Task buttons when focus is empty', (tester) async {
      final now = DateTime.now();
      final roadmap = RoadmapEntity(
        id: 'rm_flow',
        title: 'Fullstack Track',
        createdAt: now,
        updatedAt: now,
      );
      final chapter = ChapterEntity(
        id: 'ch_flow',
        roadmapId: 'rm_flow',
        title: 'Frontend Basics',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      final beat = BeatEntity(
        id: 'b_flow',
        chapterId: 'ch_flow',
        roadmapId: 'rm_flow',
        title: 'CSS Grid & Flexbox',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      );

      bool pullCalled = false;
      bool customCalled = false;
      String? customCat;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: roadmap,
              allRoadmaps: [roadmap],
              chapters: [chapter],
              allBeats: [beat],
              pacingBudget: null,
              streakDays: 3,
              onSwitchRoadmap: () {},
              onBeatToggled: (_, __) async {},
              onPullNextTopic: (_) => pullCalled = true,
              onCreateCustomTask: (rm, title, effort, url, category) {
                customCalled = true;
                customCat = category;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.drag(find.byType(FlowScreen), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Pull Next Topic'), findsOneWidget);
      expect(find.text('Custom Task'), findsOneWidget);

      await tester.tap(find.text('Pull Next Topic'));
      expect(pullCalled, isTrue);

      await tester.tap(find.text('Custom Task'));
      await tester.pumpAndSettle();
      expect(find.text('Custom Task'), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).first, 'Flexbox Froggy');
      await tester.pump();
      await tester.ensureVisible(find.text('Add Task'));
      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 11));
      expect(customCalled, isTrue);
      expect(customCat, 'Revision'); // default category
    });

    testWidgets('Open Lab renders only single prominent Log Task button without Pull Next Topic', (tester) async {
      final now = DateTime.now();
      final openLabRoadmap = RoadmapEntity(
        id: RoadmapEntity.openLabId,
        title: 'Open Lab',
        description: 'Universal workspace for personal projects and unguided practice',
        createdAt: now,
        updatedAt: now,
      );
      expect(openLabRoadmap.isOpenLab, isTrue);

      final openLabChapter = ChapterEntity(
        id: ChapterEntity.openLabChapterId,
        roadmapId: RoadmapEntity.openLabId,
        title: 'Activity Log',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );

      bool customCalled = false;
      String? customTitle;
      double? customEffort;
      String? customCategory;

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: FlowScreen(
              activeRoadmap: openLabRoadmap,
              allRoadmaps: [openLabRoadmap],
              chapters: [openLabChapter],
              allBeats: const [],
              pacingBudget: null,
              streakDays: 5,
              onSwitchRoadmap: () {},
              onBeatToggled: (_, __) async {},
              onPullNextTopic: (_) {},
              onCreateCustomTask: (rm, title, effort, url, category) {
                customCalled = true;
                customTitle = title;
                customEffort = effort;
                customCategory = category;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.drag(find.byType(FlowScreen), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Open Lab header and empty state
      expect(find.text('Open Lab'), findsOneWidget);
      expect(find.text('No active task'), findsOneWidget);

      // Verify "Pull Next Topic" is NOT present, only single button is present
      expect(find.text('Pull Next Topic'), findsNothing);
      expect(find.text('Log Task'), findsOneWidget);

      // Tap button to open Open Lab dialog
      await tester.tap(find.text('Log Task'));
      await tester.pumpAndSettle();

      // Verify Open Lab dialog styling and title (card button + dialog title + dialog button)
      expect(find.text('Log Task'), findsNWidgets(3));
      expect(find.text('Open Lab'), findsWidgets);

      // Select preset 1h (1 hour -> 6 effort points)
      await tester.tap(find.text('1h'));
      await tester.pump();
      expect(find.text('1 hr • ⚡ 6.0 beats'), findsOneWidget);

      // Add a dynamic category: "Open Source"
      await tester.tap(find.text('+ Add Category'));
      await tester.pumpAndSettle();

      final categoryField = find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.hintText?.contains('Anatomy') ?? false),
      );
      await tester.enterText(categoryField, 'Open Source');
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Open Source'), findsOneWidget);

      // Enter task title
      final titleField = find.byWidgetPredicate(
        (w) => w is TextField && (w.decoration?.hintText?.contains('Robbins') ?? false),
      );
      await tester.enterText(titleField, 'PR to Flutter repository');
      await tester.pump();

      // Submit
      final submitButton = find.text('Log Task').last;
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 11));

      expect(customCalled, isTrue);
      expect(customTitle, 'PR to Flutter repository');
      expect(customEffort, 6.0);
      expect(customCategory, 'Open Source');
    });
  });

  group('BeatEntity Category & AppUpdateManager Semver Tests', () {
    test('BeatEntity parses custom task category correctly', () {
      final now = DateTime.now();
      final standardCustomBeat = BeatEntity(
        id: 'b_custom_1',
        chapterId: 'ch1',
        roadmapId: 'rm1',
        title: 'Leetcode 75',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: false,
        syllabusTopicId: 'custom:Practice',
        createdAt: now,
        updatedAt: now,
      );
      expect(standardCustomBeat.isCustomTask, isTrue);
      expect(standardCustomBeat.customTaskCategory, 'Practice');

      final legacyCustomBeat = BeatEntity(
        id: 'b_custom_2',
        chapterId: 'ch1',
        roadmapId: 'rm1',
        title: 'Legacy Custom Task',
        effortWeight: 1.0,
        sortOrder: 1,
        isCompleted: false,
        syllabusTopicId: 'custom_task',
        createdAt: now,
        updatedAt: now,
      );
      expect(legacyCustomBeat.isCustomTask, isTrue);
      expect(legacyCustomBeat.customTaskCategory, 'Revision');

      final curriculumBeat = BeatEntity(
        id: 'b_normal',
        chapterId: 'ch1',
        roadmapId: 'rm1',
        title: 'Curriculum Beat',
        effortWeight: 1.0,
        sortOrder: 2,
        isCompleted: false,
        syllabusTopicId: 'topic_graphs_bfs',
        createdAt: now,
        updatedAt: now,
      );
      expect(curriculumBeat.isCustomTask, isFalse);
    });

    test('AppUpdateManager semver comparison correctly identifies newer versions', () {
      expect(AppUpdateManager.isNewerVersion('v1.2.0', 'v1.1.0-Stable'), isTrue);
      expect(AppUpdateManager.isNewerVersion('v1.1.3', 'v1.1.2-preview'), isTrue);
      expect(AppUpdateManager.isNewerVersion('v1.1.2-preview', 'v1.1.0-Stable'), isTrue);
      expect(AppUpdateManager.isNewerVersion('v1.1.2-preview', 'v1.1.1-preview'), isTrue);
      expect(AppUpdateManager.isNewerVersion('v2.0.0', 'v1.1.0-Stable'), isTrue);
      expect(AppUpdateManager.isNewerVersion('v1.1.1', 'v1.1.0-Stable'), isTrue);
      expect(AppUpdateManager.isNewerVersion('v1.1.0', 'v1.1.0-Stable'), isFalse);
      expect(AppUpdateManager.isNewerVersion('v1.0.9', 'v1.1.0-Stable'), isFalse);
      expect(AppUpdateManager.isNewerVersion('1.0.0', '1.1.0'), isFalse);
      expect(AppUpdateManager.isNewerVersion('invalid', '1.1.0'), isFalse);
    });

    testWidgets('Custom tasks render grouped under category header with clean title and no mentor tags', (tester) async {
      final now = DateTime.now();
      final chapter = ChapterEntity(
        id: 'ch_test',
        roadmapId: 'rm_test',
        title: 'Algorithms',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      );
      final beats = [
        BeatEntity(
          id: 'b_custom_rev',
          chapterId: 'ch_test',
          roadmapId: 'rm_test',
          title: 'Review Dijkstra Proof',
          effortWeight: 1.5,
          sortOrder: 0,
          isCompleted: false,
          isMentorExtra: false,
          syllabusTopicId: 'custom:Revision',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: RythemTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChapterAccordion(
                chapter: chapter,
                beats: beats,
                initialExpanded: true,
                onBeatToggled: (_, __) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top-left category header badge
      expect(find.text('⚡ REVISION'), findsOneWidget);
      // Clean task title
      expect(find.text('Review Dijkstra Proof'), findsOneWidget);
      // No inline mentor extra or resource tags
      expect(find.text('MENTOR EXTRA'), findsNothing);
      expect(find.text('RESOURCE 1'), findsNothing);
      // Effort and duration display
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('15m'), findsOneWidget);
    });
  });
}
