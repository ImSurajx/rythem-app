import 'dart:convert';

/// Represents study intensity and daily beat goal for a specific day of the week.
enum StudyIntensity {
  rest(
    key: 'rest',
    label: 'Rest',
    targetBeats: 0,
    targetEffort: 0.0,
    description: 'Recharge & buffer day',
  ),
  light(
    key: 'light',
    label: 'Light',
    targetBeats: 2,
    targetEffort: 2.0,
    description: 'Gentle review (~2 beats)',
  ),
  normal(
    key: 'normal',
    label: 'Normal',
    targetBeats: 4,
    targetEffort: 4.0,
    description: 'Steady progress (~4 beats)',
  ),
  intense(
    key: 'intense',
    label: 'Deep Focus',
    targetBeats: 6,
    targetEffort: 6.0,
    description: 'Maximum momentum (~6 beats)',
  );

  final String key;
  final String label;
  final int targetBeats;
  final double targetEffort;
  final String description;

  const StudyIntensity({
    required this.key,
    required this.label,
    required this.targetBeats,
    required this.targetEffort,
    required this.description,
  });

  static StudyIntensity fromKey(String? key) {
    return StudyIntensity.values.firstWhere(
      (e) => e.key == key,
      orElse: () => StudyIntensity.normal,
    );
  }

  /// Cycles to next intensity level: rest -> light -> normal -> intense -> rest
  StudyIntensity next() {
    final nextIndex = (index + 1) % StudyIntensity.values.length;
    return StudyIntensity.values[nextIndex];
  }
}

/// 7-day weekly schedule mapping each day of the week (1=Monday .. 7=Sunday)
/// to its configured study intensity and daily beat goal.
class WeeklyStudySchedule {
  final Map<int, StudyIntensity> days;

  const WeeklyStudySchedule({required this.days});

  factory WeeklyStudySchedule.custom({
    StudyIntensity? monday,
    StudyIntensity? tuesday,
    StudyIntensity? wednesday,
    StudyIntensity? thursday,
    StudyIntensity? friday,
    StudyIntensity? saturday,
    StudyIntensity? sunday,
  }) {
    return WeeklyStudySchedule(
      days: {
        DateTime.monday: monday ?? StudyIntensity.normal,
        DateTime.tuesday: tuesday ?? StudyIntensity.normal,
        DateTime.wednesday: wednesday ?? StudyIntensity.normal,
        DateTime.thursday: thursday ?? StudyIntensity.normal,
        DateTime.friday: friday ?? StudyIntensity.normal,
        DateTime.saturday: saturday ?? StudyIntensity.light,
        DateTime.sunday: sunday ?? StudyIntensity.rest,
      },
    );
  }

  /// Default balanced schedule: Mon-Fri Normal (4), Sat Light (2), Sun Rest (0) = 22 beats/wk
  factory WeeklyStudySchedule.defaultSchedule() {
    return const WeeklyStudySchedule(
      days: {
        DateTime.monday: StudyIntensity.normal,
        DateTime.tuesday: StudyIntensity.normal,
        DateTime.wednesday: StudyIntensity.normal,
        DateTime.thursday: StudyIntensity.normal,
        DateTime.friday: StudyIntensity.normal,
        DateTime.saturday: StudyIntensity.light,
        DateTime.sunday: StudyIntensity.rest,
      },
    );
  }

  StudyIntensity getIntensity(int weekday) {
    return days[weekday] ?? StudyIntensity.normal;
  }

  int getGoalForWeekday(int weekday) {
    return getIntensity(weekday).targetBeats;
  }

  StudyIntensity get todaysIntensity {
    return getIntensity(DateTime.now().weekday);
  }

  int get todaysGoal {
    return getGoalForWeekday(DateTime.now().weekday);
  }

  double get totalWeeklyTargetBeats {
    return days.values.fold<double>(0.0, (acc, cur) => acc + cur.targetBeats);
  }

  int get activeDaysCount {
    return days.values.where((e) => e != StudyIntensity.rest).length;
  }

  WeeklyStudySchedule copyWithDay(int weekday, StudyIntensity intensity) {
    final updated = Map<int, StudyIntensity>.from(days);
    updated[weekday] = intensity;
    return WeeklyStudySchedule(days: updated);
  }

  WeeklyStudySchedule withIntensity(int weekday, StudyIntensity intensity) {
    return copyWithDay(weekday, intensity);
  }

  static String dayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Day $weekday';
    }
  }

  Map<String, dynamic> toMap() {
    return days.map((key, value) => MapEntry(key.toString(), value.key));
  }

  factory WeeklyStudySchedule.fromMap(Map<String, dynamic> map) {
    final days = <int, StudyIntensity>{};
    for (int i = 1; i <= 7; i++) {
      final key = i.toString();
      if (map.containsKey(key)) {
        days[i] = StudyIntensity.fromKey(map[key]?.toString());
      } else {
        days[i] = i == DateTime.sunday ? StudyIntensity.rest : StudyIntensity.normal;
      }
    }
    return WeeklyStudySchedule(days: days);
  }

  String encode() => jsonEncode(toMap());

  factory WeeklyStudySchedule.decode(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return WeeklyStudySchedule.defaultSchedule();
    }
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return WeeklyStudySchedule.fromMap(decoded);
    } catch (_) {
      return WeeklyStudySchedule.defaultSchedule();
    }
  }
}
