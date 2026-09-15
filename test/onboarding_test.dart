import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:rythem_app/features/onboarding/onboarding_wizard_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late Database testDb;

  setUp(() async {
    testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await testDb.execute('''
      CREATE TABLE ${DatabaseTables.appSettings} (
        ${AppSettingsColumns.key} TEXT PRIMARY KEY,
        ${AppSettingsColumns.value} TEXT NOT NULL,
        ${AppSettingsColumns.updatedAt} TEXT NOT NULL
      );
    ''');
    DatabaseService.instance.setDatabaseForTesting(testDb);
  });

  tearDown(() async {
    DatabaseService.instance.setDatabaseForTesting(null);
    await testDb.close();
  });

  group('AppSettingsRepository Direct', () {
    test('writes and reads setting', () async {
      final repo = AppSettingsRepository();
      await repo.setSetting('test_key', 'test_val');
      final res = await repo.getSetting('test_key');
      expect(res, 'test_val');
    });
  });

  group('OnboardingWizardScreen Tests', () {
    testWidgets('renders philosophy step first', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingWizardScreen(
            onFinished: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BEATS OVER CLOCKS'), findsOneWidget);
      expect(find.text('Mastery is felt,\nnot measured.'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('navigates through steps to calibration and completes', (tester) async {
      bool finishedCalled = false;
      final settingsRepo = AppSettingsRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingWizardScreen(
            onFinished: () => finishedCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('AUTOMATIC PACING DILUTION'), findsOneWidget);

      // Step 2 -> Step 3
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('LOCAL ON-DEVICE AI'), findsOneWidget);

      // Step 3 -> Step 4
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('SET YOUR WEEKLY RHYTHM'), findsOneWidget);
      expect(find.text('Enter Daily Flow'), findsOneWidget);

      // Select Accelerated Rhythm option
      await tester.tap(find.text('Accelerated Rhythm'));
      await tester.pumpAndSettle();

      // Finish Onboarding
      await tester.tap(find.text('Enter Daily Flow'));
      await tester.pump();
      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (finishedCalled) break;
      }

      expect(finishedCalled, isTrue);

      String? hasCompleted;
      String? schedule;
      await tester.runAsync(() async {
        hasCompleted = await settingsRepo.getSetting('has_completed_onboarding');
        schedule = await settingsRepo.getSetting('study_intensity_schedule');
      });
      expect(hasCompleted, 'true');
      expect(schedule, isNotNull);
    });

    testWidgets('skip button completes onboarding immediately', (tester) async {
      bool finishedCalled = false;
      final settingsRepo = AppSettingsRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingWizardScreen(
            onFinished: () => finishedCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pump();
      for (int i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (finishedCalled) break;
      }

      expect(finishedCalled, isTrue);

      String? hasCompleted;
      await tester.runAsync(() async {
        hasCompleted = await settingsRepo.getSetting('has_completed_onboarding');
      });
      expect(hasCompleted, 'true');
    });
  });
}
