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
  });

  tearDown(() {
    DatabaseService.instance.setDatabaseForTesting(null);
  });

  testWidgets('Design system showcase renders brand and liquid glass widgets', (WidgetTester tester) async {
    await tester.pumpWidget(const RythemApp());
    await tester.pump();

    // Allow real SQLite async database initialization and seeding to settle
    for (int i = 0; i < 30; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      if (find.text('Calculus & Gradient Vectors').evaluate().isNotEmpty) {
        break;
      }
    }

    // Verify brand typography & persistent dock
    expect(find.text('RYTHEM'), findsOneWidget);
    expect(find.text('beats over clocks • felt, not measured'), findsOneWidget);
    expect(find.byType(GlassBottomDock), findsOneWidget);

    // Switch to Explore tab
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    // Verify glass components
    expect(find.byType(GlassContainer), findsWidgets);
    expect(find.byType(GlassCard), findsWidgets);
    expect(find.byType(GlassButton), findsWidgets);
    expect(find.byType(GlassProgressBar), findsWidgets);

    // Verify theme toggle from Dark to Light Apple Control Center Glass
    expect(find.text('MONOCHROME LIQUID GLASS (DARK)'), findsOneWidget);
    final lightModeToggle = find.byIcon(Icons.light_mode_outlined);
    expect(lightModeToggle, findsOneWidget);
    await tester.tap(lightModeToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Light Glass mode activated
    expect(find.text('APPLE CONTROL CENTER GLASS (LIGHT)'), findsOneWidget);
    expect(find.text('LIGHT GLASS'), findsOneWidget);

    // Toggle back to Dark Glass
    final darkModeToggle = find.byIcon(Icons.dark_mode_outlined);
    expect(darkModeToggle, findsOneWidget);
    await tester.tap(darkModeToggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('MONOCHROME LIQUID GLASS (DARK)'), findsOneWidget);

    // Verify interactive beat advance button
    final advanceButton = find.text('Advance Beat');
    expect(advanceButton, findsOneWidget);

    await tester.ensureVisible(advanceButton);
    await tester.pump();
    await tester.tap(advanceButton);
    
    // Allow real async database operations to finish and rebuild UI
    for (int i = 0; i < 30; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      if (find.text('4 of 7 beats completed').evaluate().isNotEmpty) {
        break;
      }
    }

    // Verify progress updated
    expect(find.text('4 of 7 beats completed'), findsOneWidget);
  });
}
