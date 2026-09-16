import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/main.dart';
import 'package:rythem_app/core/widgets/widgets.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    final db = await databaseFactoryFfi.openDatabase(
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
    DatabaseService.instance.setDatabaseForTesting(db);
    await db.insert(
      DatabaseTables.appSettings,
      {
        AppSettingsColumns.key: 'has_completed_onboarding',
        AppSettingsColumns.value: 'true',
        AppSettingsColumns.updatedAt: DateTime.now().toIso8601String(),
      },
    );
  });

  tearDown(() {
    DatabaseService.instance.setDatabaseForTesting(null);
  });

  testWidgets('Design system showcase renders brand and liquid glass widgets', (WidgetTester tester) async {
    await tester.pumpWidget(const RythemApp());
    await tester.pump();

    // Allow real SQLite async database initialization to settle
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    // Verify brand typography, clean state, immediate stack & persistent dock
    expect(find.text('RYTHEM'), findsOneWidget);
    expect(find.text('No Learning Tracks Yet'), findsOneWidget);
    expect(find.byType(IndexedStack), findsWidgets);
    expect(find.byType(GlassBottomDock), findsOneWidget);

    // Switch to Explore tab
    await tester.tap(find.text('Explore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify glass components
    expect(find.byType(GlassContainer), findsWidgets);
    expect(find.byType(GlassCard), findsWidgets);
    expect(find.byType(GlassButton), findsWidgets);

    // Verify Explore screen structure
    expect(find.text('EXPLORE'), findsOneWidget);
    expect(find.text('All Tracks'), findsOneWidget);
    expect(find.text('New Track'), findsOneWidget);

    // Switch to Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Settings & 7-Day Study Intensity & Backup
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('7-DAY STUDY INTENSITY & DAILY GOALS'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('DATA BACKUP & RESTORE'), findsOneWidget);
    expect(find.text('Weekly Study Rhythm'), findsOneWidget);

    for (int i = 0; i < 20; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  });
}
