import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/database/repositories/app_settings_repository.dart';
import 'package:rythem_app/core/revision/models/revision_item.dart';
import 'package:rythem_app/core/revision/services/revision_service.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/features/explore/widgets/chapter_accordion.dart';
import 'package:rythem_app/features/flow/widgets/daily_revision_board.dart';
import 'package:rythem_app/features/flow/widgets/mark_revision_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Clean Revision Shelf (Feature 5) Mathematical & Service Tests', () {
    late RevisionService revisionService;
    late AppSettingsRepository settingsRepo;

    setUp(() async {
      settingsRepo = AppSettingsRepository();
      revisionService = RevisionService(settingsRepo: settingsRepo);
      await revisionService.init();
    });

    final testBeat = BeatEntity(
      id: 'beat_linear_algebra_01',
      chapterId: 'ch_01',
      roadmapId: 'track_ml',
      title: 'Eigenvalues & Eigenvectors',
      effortWeight: 1.0,
      sortOrder: 1,
      isCompleted: true,
      completedAt: DateTime.now().subtract(const Duration(days: 4)),
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 4)),
    );

    test('Adding to Revision Shelf with 3-day preset calculates scheduledReviewDate accurately', () async {
      final now = DateTime.now();
      final item = await revisionService.addToRevisionShelf(
        beat: testBeat,
        roadmapTitle: 'Machine Learning Track',
        intervalDays: 3,
        note: 'Remember geometric intuition of rotation and scaling',
      );

      expect(item.beatId, equals(testBeat.id));
      expect(item.intervalDays, equals(3));
      expect(item.scheduledReviewDate, isNotNull);
      expect(item.scheduledReviewDate!.day, equals(now.add(const Duration(days: 3)).day));
      expect(item.flagNote, equals('Remember geometric intuition of rotation and scaling'));
      expect(item.isDueToday, isFalse);
      expect(revisionService.isInRevisionShelf(testBeat.id), isTrue);
    });

    test('Adding to Revision Shelf with 1-week preset calculates scheduledReviewDate accurately', () async {
      final now = DateTime.now();
      final item = await revisionService.addToRevisionShelf(
        beat: testBeat,
        roadmapTitle: 'Machine Learning Track',
        intervalDays: 7,
      );

      expect(item.intervalDays, equals(7));
      expect(item.scheduledReviewDate, isNotNull);
      expect(item.scheduledReviewDate!.day, equals(now.add(const Duration(days: 7)).day));
      expect(item.isDueToday, isFalse);
    });

    test('Adding to Revision Shelf on demand (null interval) keeps indefinite shelf status', () async {
      final item = await revisionService.addToRevisionShelf(
        beat: testBeat,
        roadmapTitle: 'Machine Learning Track',
        intervalDays: null,
      );

      expect(item.intervalDays, isNull);
      expect(item.scheduledReviewDate, isNull);
      expect(item.isDueToday, isTrue); // Ready anytime on demand
    });

    test('Future scheduled topics do not force phantom tasks into today recommendation queue', () async {
      // Schedule beat for 5 days in the future
      await revisionService.addToRevisionShelf(
        beat: testBeat,
        roadmapTitle: 'Machine Learning Track',
        intervalDays: 5,
      );

      final roadmaps = [
        RoadmapEntity(
          id: 'track_ml',
          title: 'Machine Learning Track',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      final beatsByRoadmap = {
        'track_ml': [testBeat],
      };

      final recs = await revisionService.getDailyRevisionRecommendations(
        roadmaps: roadmaps,
        beatsByRoadmap: beatsByRoadmap,
      );

      // Must be empty today since it is scheduled for day +5
      expect(recs.where((r) => r.beatId == testBeat.id).isEmpty, isTrue);
    });

    test('Marking topic revised updates count, stability, and retains scheduled review metadata', () async {
      await revisionService.addToRevisionShelf(
        beat: testBeat,
        roadmapTitle: 'Machine Learning Track',
        intervalDays: 3,
      );

      final revised = await revisionService.markTopicRevised(
        testBeat,
        roadmapTitle: 'Machine Learning Track',
      );

      expect(revised.revisionCount, equals(1));
      expect(revised.stabilityDays, greaterThan(1.5));
      expect(revised.isCompleted, isTrue);
      expect(revised.intervalDays, equals(3));
      expect(revised.scheduledReviewDate, isNotNull);
    });

    test('Removing from Revision Shelf completely purges item', () async {
      await revisionService.addToRevisionShelf(
        beat: testBeat,
        roadmapTitle: 'Machine Learning Track',
        intervalDays: 3,
      );
      expect(revisionService.isInRevisionShelf(testBeat.id), isTrue);

      await revisionService.removeFromRevisionShelf(testBeat.id);
      expect(revisionService.isInRevisionShelf(testBeat.id), isFalse);

      final shelf = await revisionService.getRevisionShelfItems();
      expect(shelf.any((i) => i.beatId == testBeat.id), isFalse);
    });
  });

  group('Clean Revision Shelf UI & Widget Tests', () {
    final sampleBeat = BeatEntity(
      id: 'beat_calculus_gradient',
      chapterId: 'ch_calc',
      roadmapId: 'math_track',
      title: 'Gradient Descent & Convex Functions',
      effortWeight: 1.0,
      sortOrder: 1,
      isCompleted: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('MarkRevisionSheet renders preset cards and handles schedule selection', (tester) async {
      int? savedDays;
      String? savedNote;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: MarkRevisionSheet(
              beat: sampleBeat,
              roadmapTitle: 'Advanced Mathematics',
              isInShelf: false,
              onSave: (days, note) async {
                savedDays = days;
                savedNote = note;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SPACED REVISION SHELF'), findsOneWidget);
      expect(find.text('Mark for Spaced Revision'), findsOneWidget);
      expect(find.text('Gradient Descent & Convex Functions'), findsOneWidget);
      expect(find.text('In 3 Days'), findsOneWidget);
      expect(find.text('In 1 Week'), findsOneWidget);
      expect(find.text('Keep in Shelf (On Demand)'), findsOneWidget);

      // Select 'In 1 Week'
      await tester.tap(find.text('In 1 Week'));
      await tester.pumpAndSettle();

      // Enter note
      await tester.enterText(find.byType(TextField), 'Review Hessian matrix derivation');
      await tester.pumpAndSettle();

      // Tap 'Add to Revision Shelf'
      await tester.tap(find.text('Add to Revision Shelf'));
      await tester.pumpAndSettle();

      expect(savedDays, equals(7));
      expect(savedNote, equals('Review Hessian matrix derivation'));
    });

    testWidgets('MarkRevisionSheet shows Unshelf button when topic is already in shelf', (tester) async {
      bool removeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: MarkRevisionSheet(
              beat: sampleBeat,
              roadmapTitle: 'Advanced Mathematics',
              isInShelf: true,
              currentIntervalDays: 3,
              currentNote: 'Previous note',
              onSave: (_, __) async {},
              onRemove: () => removeCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update Revision Interval'), findsOneWidget);
      expect(find.text('Unshelf'), findsOneWidget);

      await tester.tap(find.text('Unshelf'));
      await tester.pumpAndSettle();

      expect(removeCalled, isTrue);
    });

    testWidgets('BeatTile surfaces bookmark button on completed beats', (tester) async {
      bool bookmarkTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: BeatTile(
              beat: sampleBeat,
              themeColors: RythemColors.dark,
              isDark: true,
              onToggle: (_) {},
              onOpenResource: () {},
              isInRevisionShelf: false,
              onMarkForRevision: () => bookmarkTapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bookmarkButton = find.byTooltip('Mark for Revision');
      expect(bookmarkButton, findsOneWidget);

      await tester.tap(bookmarkButton);
      await tester.pump();

      expect(bookmarkTapped, isTrue);
    });

    testWidgets('DailyRevisionBoard renders segmented toggle when shelf contains future topics', (tester) async {
      final dueItem = RevisionItem(
        beatId: 'b_01',
        roadmapId: 'track_1',
        roadmapTitle: 'Deep Learning',
        title: 'Backpropagation Algorithm',
        suggestedReason: 'Due for recall today',
        isCompleted: false,
        scheduledReviewDate: DateTime.now(),
        intervalDays: 3,
      );

      final futureItem = RevisionItem(
        beatId: 'b_02',
        roadmapId: 'track_1',
        roadmapTitle: 'Deep Learning',
        title: 'Transformer Attention Mechanism',
        suggestedReason: 'Scheduled review',
        isCompleted: false,
        scheduledReviewDate: DateTime.now().add(const Duration(days: 4)),
        intervalDays: 7,
      );

      RevisionItem? markedItem;
      RevisionItem? unshelvedItem;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: DailyRevisionBoard(
              revisionItems: [dueItem],
              allShelfItems: [dueItem, futureItem],
              onMarkRevised: (item) => markedItem = item,
              onUnshelf: (item) => unshelvedItem = item,
              themeColors: RythemColors.dark,
              isDark: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and segmented tabs
      expect(find.text("TODAY'S REVISION"), findsOneWidget);
      expect(find.text('DUE TODAY (1)'), findsOneWidget);
      expect(find.text('ALL IN SHELF (2)'), findsOneWidget);

      // Default tab: Due item is visible
      expect(find.text('Backpropagation Algorithm'), findsOneWidget);
      expect(find.text('DUE TODAY'), findsOneWidget);

      // Tap on checkmark
      await tester.tap(find.byKey(const Key('revision_check_button_b_01')));
      await tester.pump();
      expect(markedItem?.beatId, equals('b_01'));

      // Switch to 'ALL IN SHELF (2)' tab
      await tester.tap(find.text('ALL IN SHELF (2)'));
      await tester.pumpAndSettle();

      // Future item is now visible with 'IN 4D' pill
      expect(find.text('Transformer Attention Mechanism'), findsOneWidget);
      expect(find.text('IN 4D'), findsOneWidget);

      // Tap unshelf icon on b_02
      final unshelfIcons = find.byIcon(Icons.bookmark_remove_outlined);
      expect(unshelfIcons, findsNWidgets(2));
      await tester.tap(unshelfIcons.last);
      await tester.pump();

      expect(unshelvedItem?.beatId, equals('b_02'));
    });
  });
}
