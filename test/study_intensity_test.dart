import 'package:flutter_test/flutter_test.dart';
import 'package:rythem_app/core/pacing/models/study_intensity.dart';
import 'package:rythem_app/core/pacing/services/pacing_service.dart';
import 'package:rythem_app/core/database/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('StudyIntensity & WeeklyStudySchedule Model Tests', () {
    test('default schedule has 22 total weekly target beats', () {
      final schedule = WeeklyStudySchedule.defaultSchedule();
      expect(schedule.totalWeeklyTargetBeats, 22.0); // 5*4 + 2 + 0 = 22
      expect(schedule.activeDaysCount, 6);
      expect(schedule.getIntensity(DateTime.monday), StudyIntensity.normal);
      expect(schedule.getIntensity(DateTime.saturday), StudyIntensity.light);
      expect(schedule.getIntensity(DateTime.sunday), StudyIntensity.rest);
    });

    test('intensity target beats match specification', () {
      expect(StudyIntensity.rest.targetBeats, 0);
      expect(StudyIntensity.light.targetBeats, 2);
      expect(StudyIntensity.normal.targetBeats, 4);
      expect(StudyIntensity.intense.targetBeats, 6);
    });

    test('encode and decode roundtrip preserves schedule', () {
      var schedule = WeeklyStudySchedule.defaultSchedule();
      schedule = schedule.withIntensity(DateTime.sunday, StudyIntensity.intense);
      schedule = schedule.withIntensity(DateTime.wednesday, StudyIntensity.rest);

      final jsonStr = schedule.encode();
      final restored = WeeklyStudySchedule.decode(jsonStr);

      expect(restored.getIntensity(DateTime.sunday), StudyIntensity.intense);
      expect(restored.getIntensity(DateTime.wednesday), StudyIntensity.rest);
      expect(restored.getIntensity(DateTime.monday), StudyIntensity.normal);
    });

    test('PacingService uses today intensity to scale effort share', () async {
      await DatabaseService.instance.initInMemoryForTesting();

      final roadmapRepo = RoadmapRepository();
      final chapterRepo = ChapterRepository();
      final beatRepo = BeatRepository();
      final beatLogRepo = BeatLogRepository();
      final settingsRepo = AppSettingsRepository();

      final now = DateTime.now();
      final rm = RoadmapEntity(
        id: 'rm_test_intensity',
        title: 'Study Intensity Test',
        description: 'Testing dynamic weekly cadence',
        targetCompletionDate: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );
      await roadmapRepo.createRoadmap(rm);

      await chapterRepo.createChapter(ChapterEntity(
        id: 'ch_1',
        roadmapId: rm.id,
        title: 'Chapter 1',
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ));

      // Create 5 beats with 2.0 effort each (total remaining = 10.0)
      final beats = List.generate(
        5,
        (i) => BeatEntity(
          id: 'b_$i',
          chapterId: 'ch_1',
          roadmapId: rm.id,
          title: 'Beat $i',
          effortWeight: 2.0,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await beatRepo.createBeatsBatch(beats);

      // Configure a schedule where Monday is Intense (6b) and Tuesday is Rest (0b)
      final customSchedule = WeeklyStudySchedule.custom(
        monday: StudyIntensity.intense,
        tuesday: StudyIntensity.rest,
        wednesday: StudyIntensity.normal,
        thursday: StudyIntensity.normal,
        friday: StudyIntensity.normal,
        saturday: StudyIntensity.light,
        sunday: StudyIntensity.rest,
      );
      await settingsRepo.setSetting('study_intensity_schedule', customSchedule.encode());

      final pacingService = PacingService(
        roadmapRepo: roadmapRepo,
        beatRepo: beatRepo,
        beatLogRepo: beatLogRepo,
        settingsRepo: settingsRepo,
      );

      // On Monday (intense, 6 beats quota), today's effort share should be positive
      final mondayDate = DateTime(2026, 9, 14); // Monday
      final mondayBudget = await pacingService.computePacingBudget(
        rm.id,
        simulatedNow: mondayDate,
      );
      expect(mondayBudget.todayEffortShare, greaterThan(0.0));

      // On Tuesday (rest, 0 beats quota), today's effort share should be 0.0
      final tuesdayDate = DateTime(2026, 9, 15); // Tuesday
      final tuesdayBudget = await pacingService.computePacingBudget(
        rm.id,
        simulatedNow: tuesdayDate,
      );
      expect(tuesdayBudget.todayEffortShare, 0.0);

      await DatabaseService.instance.close();
    });
  });
}
